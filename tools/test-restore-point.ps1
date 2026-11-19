# Isolated function tests. NEVER execute the production entry point or a real restore request.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$path = Join-Path (Split-Path -Parent $PSScriptRoot) 'src\Executables\RestorePoint.ps1'
$text = [IO.File]::ReadAllText($path)
$tokens = $null; $parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
if (@([IO.File]::ReadAllBytes($path) | Where-Object { $_ -gt 127 }).Count) { throw 'Production restore helper must be ASCII.' }
if ($ast.ParamBlock.Parameters.Count -ne 1 -or $ast.ParamBlock.Parameters[0].Name.VariablePath.UserPath -ne 'Create') {
    throw 'Production entry point must expose only the explicit Create switch.'
}
function Assert-RestoreTest {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
foreach ($statement in $ast.EndBlock.Statements) {
    if ($statement -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
        . ([scriptblock]::Create($statement.Extent.Text))
    }
}
# All OS-facing functions are shadowed before invoking the tested workflow.
function Test-RestoreAdministrator {
    $script:AdminChecks++
    if ($script:Mode -eq 'AdminFailure') { throw 'Fixture elevation unavailable.' }
    return $script:IsAdministrator
}
function Start-Sleep { param($Seconds) Assert-RestoreTest ($Seconds -eq 2) 'Visibility wait must remain bounded.'; $script:SleepCalls++ }
function Enable-ComputerRestore { throw 'No protection changes permitted in tests.' }
function Checkpoint-Computer { throw 'No real restore requests permitted in tests.' }
function Set-ItemProperty { throw 'No registry writes permitted in tests.' }
function Get-CimInstance {
    param($Namespace, $ClassName, $OperationTimeoutSec, $ErrorAction, $WarningAction)
    Assert-RestoreTest ($Namespace -eq 'root/default' -and $ClassName -eq 'SystemRestore') 'Unexpected restore history probe.'
    Assert-RestoreTest ($OperationTimeoutSec -eq 8) 'History probe must have a bounded timeout.'
    $script:ReadCalls++
    if ($script:Mode -eq 'BaselineFailure' -and $script:ReadCalls -eq 1) { throw 'Fixture protected history.' }
    if ($script:Mode -eq 'HistoryWarning' -and $script:ReadCalls -eq 1) { Write-Warning 'Fixture history warning' }
    if ($script:Mode -eq 'VerificationFailure' -and $script:ReadCalls -gt 1) { throw 'Fixture verification unavailable.' }
    if ($script:Mode -eq 'TransientVerificationFailure' -and $script:ReadCalls -eq 2) { throw 'Fixture temporarily unavailable.' }
    if ($script:Mode -eq 'Empty') { return @() }
    $existing = [pscustomobject]@{ SequenceNumber = 10; Description = 'Existing fixture'; CreationTime = [datetime]'2026-01-01' }
    if ($script:ReadCalls -eq 1) { return $existing }
    switch ($script:Mode) {
        'NoNewPoint' { return $existing }
        'OtherPoint' { return @($existing, [pscustomobject]@{ SequenceNumber = 11; Description = 'Another application'; CreationTime = [datetime]::UtcNow }) }
        'StaleSequence' { return [pscustomobject]@{ SequenceNumber = 10; Description = $script:CreatedName; CreationTime = [datetime]::UtcNow } }
        'Delayed' { if ($script:ReadCalls -lt 4) { return $existing } }
    }
    return @($existing, [pscustomobject]@{ SequenceNumber = 11; Description = $script:CreatedName; CreationTime = [datetime]'2026-11-16T12:00:00Z' })
}
function Invoke-CimMethod {
    param($Namespace, $ClassName, $MethodName, $Arguments, $OperationTimeoutSec, $ErrorAction, $WarningAction)
    $script:MutationCalls++
    Assert-RestoreTest ($script:IsAdministrator -and $script:AdminChecks -eq 1) 'Runtime elevation must precede any request.'
    Assert-RestoreTest ($script:ReadCalls -eq 1) 'Baseline query must precede any request.'
    Assert-RestoreTest ($Namespace -eq 'root/default' -and $ClassName -eq 'SystemRestore' -and $MethodName -eq 'CreateRestorePoint') 'Only the Windows built-in SystemRestore method is allowed.'
    Assert-RestoreTest ($Arguments.RestorePointType -eq 12 -and $Arguments.EventType -eq 100) 'MODIFY_SETTINGS=12 and BEGIN_SYSTEM_CHANGE=100 are required.'
    Assert-RestoreTest ($Arguments.Description -match '^Astra Toolbox - \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC - [0-9a-f]{8}$') 'Description must have the fixed Astra Toolbox prefix and unique suffix.'
    Assert-RestoreTest ($Arguments.Count -eq 3 -and $OperationTimeoutSec -eq 120) 'Unexpected method arguments or unbounded timeout.'
    $script:CreatedName = $Arguments.Description
    switch ($script:Mode) {
        'Nonzero' { return [pscustomobject]@{ ReturnValue = [uint32]87 } }
        'MissingStatus' { return [pscustomobject]@{ Other = 0 } }
        'NullStatus' { return $null }
        'MethodFailure' { throw 'Fixture provider request failed.' }
        'MethodWarning' { Write-Warning 'Fixture creation warning' }
    }
    return [pscustomobject]@{ ReturnValue = [uint32]0 }
}
function Reset-RestoreFixture {
    param([string]$Mode = 'Success', [bool]$Admin = $true)
    $script:Mode = $Mode; $script:IsAdministrator = $Admin
    $script:ReadCalls = 0; $script:MutationCalls = 0; $script:AdminChecks = 0; $script:SleepCalls = 0; $script:CreatedName = $null
}
Reset-RestoreFixture
$info = Invoke-AstraRestorePoint
Assert-RestoreTest ($info.success -and -not $info.created -and $info.sequenceNumber -eq 10) 'Without Create, only latest-point information is allowed.'
Assert-RestoreTest ($script:MutationCalls -eq 0 -and $script:AdminChecks -eq 0) 'Dry-run must not mutate or require elevation.'
Reset-RestoreFixture 'Empty'
$info = Invoke-AstraRestorePoint
Assert-RestoreTest ($info.success -and -not $info.created -and $script:MutationCalls -eq 0) 'Empty dry-run history must not mutate.'
Reset-RestoreFixture 'BaselineFailure'
$info = Invoke-AstraRestorePoint
Assert-RestoreTest (-not $info.success -and -not $info.created -and $script:MutationCalls -eq 0) 'Protected dry-run history must be reported unavailable.'
Reset-RestoreFixture -Admin $false
$denied = Invoke-AstraRestorePoint -Create
Assert-RestoreTest (-not $denied.success -and $denied.requiresAdmin -and $script:MutationCalls -eq 0 -and $script:ReadCalls -eq 0) 'Non-elevated creation must fail before any request.'
foreach ($mode in @('AdminFailure', 'BaselineFailure', 'HistoryWarning')) {
    Reset-RestoreFixture $mode
    $result = Invoke-AstraRestorePoint -Create
    Assert-RestoreTest (-not $result.success -and -not $result.created -and $script:MutationCalls -eq 0) "$mode must prevent creation."
}
foreach ($mode in @('Nonzero', 'MissingStatus', 'NullStatus', 'MethodFailure', 'MethodWarning')) {
    Reset-RestoreFixture $mode
    $result = Invoke-AstraRestorePoint -Create
    Assert-RestoreTest (-not $result.success -and -not $result.created -and $script:MutationCalls -eq 1) "$mode must not claim success."
    Assert-RestoreTest ($result.message -match 'System Protection' -and $result.message -match 'frequency limit') 'Creation failures must explain protection/frequency restrictions.'
}
foreach ($mode in @('NoNewPoint', 'OtherPoint', 'StaleSequence', 'VerificationFailure')) {
    Reset-RestoreFixture $mode
    $result = Invoke-AstraRestorePoint -Create
    Assert-RestoreTest (-not $result.success -and -not $result.created) "$mode must not verify a new matching point."
    Assert-RestoreTest ($script:ReadCalls -eq 5 -and $script:SleepCalls -eq 3) 'Visibility wait must stop after four queries/three mocked delays.'
    Assert-RestoreTest ($result.message -match 'NOT confirmed' -and $result.message -match 'frequency limit') 'A zero result without a verified new point must clearly fail.'
}
foreach ($mode in @('Success', 'Delayed', 'TransientVerificationFailure')) {
    Reset-RestoreFixture $mode
    $result = Invoke-AstraRestorePoint -Create
    Assert-RestoreTest ($result.success -and $result.created -and $result.sequenceNumber -eq 11) "$mode must verify a newer point."
    Assert-RestoreTest ($result.name -ceq $script:CreatedName -and $result.creationTime -ne 'Unknown/unavailable') 'Verified name and creation time must be returned.'
    Assert-RestoreTest ($result.message -match 'not a full backup') 'Success must contain the Windows restore-point backup caveat.'
    Assert-RestoreTest ($script:MutationCalls -eq 1 -and $script:ReadCalls -le 5) 'Creation must be requested only once.'
    if ($mode -eq 'TransientVerificationFailure') { Assert-RestoreTest ($result.issues.Count -eq 1) 'Transient verification warnings must not be hidden.' }
    $json = @($result | ConvertTo-Json -Depth 6 -Compress)
    Assert-RestoreTest ($json.Count -eq 1 -and ($json[0] | ConvertFrom-Json).created) 'Response must serialize as one JSON object.'
}
Reset-RestoreFixture
$first = Invoke-AstraRestorePoint -Create
Reset-RestoreFixture
$second = Invoke-AstraRestorePoint -Create
Assert-RestoreTest ($first.name -ne $second.name) 'Each user-triggered request must have a unique fixed-prefix description.'
Assert-RestoreTest ((Convert-RestoreCreationTime $null) -eq 'Unknown/unavailable') 'Missing creation time must not be fabricated.'
Write-Output 'PASS: RestorePoint ASCII/PS5.1 parsing, explicit mutation guard, elevation, exact CIM arguments, baseline/new-point verification, warnings/errors, bounded visibility wait, and unique descriptions. All probes and requests were mocked; no Windows state changed.'
