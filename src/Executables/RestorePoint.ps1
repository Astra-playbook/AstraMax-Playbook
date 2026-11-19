# Windows PowerShell 5.1. Only an explicit -Create may request a restore point.
# Never enables protection, changes quotas, or bypasses Windows creation frequency limits.
[CmdletBinding()]
param([switch]$Create)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

function Test-RestoreAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    try {
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } finally { $identity.Dispose() }
}

function Get-AstraRestorePoints {
    $records = @(Get-CimInstance -Namespace 'root/default' -ClassName 'SystemRestore' -OperationTimeoutSec 8 -ErrorAction Stop -WarningAction Continue 3>&1)
    $warnings = @($records | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
    if ($warnings.Count) { throw ('Restore history provider warning: ' + ($warnings.Message -join '; ')) }
    $records
}

function Convert-RestoreCreationTime {
    param($Value)
    if ($null -eq $Value) { return 'Unknown/unavailable' }
    try {
        if ($Value -is [datetime]) { return $Value.ToString('o') }
        if ([string]$Value -match '^\d{14}\.\d{6}[+-]\d{3}$') {
            return [System.Management.ManagementDateTimeConverter]::ToDateTime([string]$Value).ToString('o')
        }
        $parsed = [datetime]::MinValue
        if ([datetime]::TryParse([string]$Value, [ref]$parsed)) { return $parsed.ToString('o') }
    } catch { }
    return 'Unknown/unavailable'
}

function New-RestoreResponse {
    param([bool]$Success, [bool]$Created, [string]$Message, [string]$Name,
        $SequenceNumber = $null, [string]$CreationTime = 'Unknown/unavailable',
        [bool]$RequiresAdmin = $false, [string[]]$Issues = @())
    [pscustomobject]@{
        success = $Success
        created = $Created
        name = $Name
        description = $Name
        creationTime = $CreationTime
        sequenceNumber = $SequenceNumber
        message = $Message
        requiresAdmin = $RequiresAdmin
        protectionSettings = 'SystemPropertiesProtection.exe'
        issues = @($Issues)
    }
}

function Invoke-AstraRestorePoint {
    param([switch]$Create)
    $reminder = 'A Windows restore point is a system-state recovery aid, not a full backup of your personal files.'
    $guidance = 'Open System Protection (SystemPropertiesProtection.exe) to check protection manually. Windows may enforce its restore-point creation frequency limit; this helper never overrides it.'

    if (-not $Create) {
        try {
            $latest = @(Get-AstraRestorePoints | Sort-Object SequenceNumber -Descending | Select-Object -First 1)
            if ($latest.Count -gt 0 -and $null -ne $latest[0]) {
                return New-RestoreResponse -Success $true -Created $false -Name $latest[0].Description -SequenceNumber $latest[0].SequenceNumber -CreationTime (Convert-RestoreCreationTime $latest[0].CreationTime) -Message ('Information only: no restore point was created. Latest visible point shown; history does not prove protection is enabled. Use explicit -Create from an elevated process to request creation. ' + $reminder)
            }
            return New-RestoreResponse -Success $true -Created $false -Message ('Information only: no existing restore points were reported and nothing was changed. Use explicit -Create from an elevated process. ' + $guidance + ' ' + $reminder)
        } catch {
            return New-RestoreResponse -Success $false -Created $false -Message ('Information only: restore-point history is unavailable or protected; nothing was changed. ' + $guidance) -Issues @($_.Exception.Message)
        }
    }

    # Runtime checks are unconditional; there is no fixture mode or bypass flag.
    try {
        if (-not (Test-RestoreAdministrator)) {
            return New-RestoreResponse -Success $false -Created $false -RequiresAdmin $true -Message ('Administrator elevation is required for -Create. No creation was attempted. ' + $guidance)
        }
    } catch {
        return New-RestoreResponse -Success $false -Created $false -RequiresAdmin $true -Message 'Unable to verify administrator elevation; no creation was attempted.' -Issues @($_.Exception.Message)
    }

    $name = 'Astra Toolbox - {0} UTC - {1}' -f [datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss'), [guid]::NewGuid().ToString('N').Substring(0, 8)
    try {
        # A successful baseline query is required, even if there are currently no points.
        $before = @(Get-AstraRestorePoints | Where-Object { $null -ne $_ })
        $beforeSequence = [long]-1
        foreach ($point in $before) {
            if ($null -eq $point.SequenceNumber) { throw 'Baseline restore-point sequence number is unavailable.' }
            $sequence = [long]$point.SequenceNumber
            if ($sequence -gt $beforeSequence) { $beforeSequence = $sequence }
        }
    } catch {
        return New-RestoreResponse -Success $false -Created $false -Name $name -Message ('Could not read the existing restore-point sequence; no creation was attempted. ' + $guidance) -Issues @($_.Exception.Message)
    }

    try {
        $methodRecords = @(Invoke-CimMethod -Namespace 'root/default' -ClassName 'SystemRestore' -MethodName 'CreateRestorePoint' -Arguments @{
            Description = $name
            RestorePointType = [uint32]12 # MODIFY_SETTINGS
            EventType = [uint32]100 # BEGIN_SYSTEM_CHANGE
        } -OperationTimeoutSec 120 -ErrorAction Stop -WarningAction Continue 3>&1)
        $methodWarnings = @($methodRecords | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
        if ($methodWarnings.Count) { throw ('Creation provider warning: ' + ($methodWarnings.Message -join '; ')) }
        if ($methodRecords.Count -ne 1) { throw 'Windows returned an unexpected number of restore-point creation statuses.' }
        $method = $methodRecords[0]
        if ($null -eq $method -or $null -eq $method.ReturnValue) { throw 'Windows returned no restore-point creation status.' }
        if ([uint32]$method.ReturnValue -ne 0) {
            return New-RestoreResponse -Success $false -Created $false -Name $name -Message ('Windows CreateRestorePoint returned error {0}; creation was not confirmed. {1}' -f $method.ReturnValue, $guidance)
        }
    } catch {
        return New-RestoreResponse -Success $false -Created $false -Name $name -Message ('The Windows restore-point request failed or timed out; creation is not confirmed. Check history before retrying because Windows may still complete a timed-out request. ' + $guidance) -Issues @($_.Exception.Message)
    }

    $verificationIssues = New-Object 'System.Collections.Generic.List[string]'
    # A zero provider result alone is NOT success: frequency limits can silently suppress creation.
    # Bounded visibility wait: four queries and at most three two-second delays.
    for ($attempt = 0; $attempt -lt 4; $attempt++) {
        if ($attempt -gt 0) { Start-Sleep -Seconds 2 }
        try {
            $after = @(Get-AstraRestorePoints | Where-Object { $null -ne $_ })
            $newPoint = @($after | Where-Object {
                $null -ne $_.SequenceNumber -and [long]$_.SequenceNumber -gt $beforeSequence -and $_.Description -ceq $name
            } | Sort-Object SequenceNumber -Descending | Select-Object -First 1)
            if ($newPoint.Count -eq 1) {
                return New-RestoreResponse -Success $true -Created $true -Name $newPoint[0].Description -SequenceNumber ([long]$newPoint[0].SequenceNumber) -CreationTime (Convert-RestoreCreationTime $newPoint[0].CreationTime) -Message ('Created and verified a new Astra Toolbox restore point. ' + $reminder) -Issues @($verificationIssues.ToArray())
            }
        } catch { $verificationIssues.Add($_.Exception.Message) }
    }
    return New-RestoreResponse -Success $false -Created $false -Name $name -Message ('Windows returned success, but no new matching restore point appeared after the bounded visibility wait. Creation is NOT confirmed. ' + $guidance) -Issues @($verificationIssues.ToArray())
}

try {
    $response = Invoke-AstraRestorePoint -Create:$Create
} catch {
    $response = New-RestoreResponse -Success $false -Created $false -Message 'Unexpected restore-point failure; creation is not confirmed. Check System Protection and Windows creation frequency limits before retrying.' -Issues @($_.Exception.Message)
}
$response | ConvertTo-Json -Depth 6 -Compress
if (-not $response.success) { exit 1 }
exit 0
