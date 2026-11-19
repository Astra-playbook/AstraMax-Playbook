# Isolated fixtures only. No live hardware, security, registry, network, or restore queries.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root 'src\Executables\SystemInfo.ps1'
$text = [IO.File]::ReadAllText($path)
$tokens = $null; $parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
if (@([IO.File]::ReadAllBytes($path) | Where-Object { $_ -gt 127 }).Count) { throw 'Production inventory must be ASCII.' }
if ($ast.ParamBlock.Parameters.Count -ne 0) { throw 'Inventory must not expose mutation or fixture parameters.' }

function Assert-InventoryTest {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
# Import declarations, not the inventory entry point.
foreach ($statement in $ast.EndBlock.Statements) {
    if ($statement -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
        . ([scriptblock]::Create($statement.Extent.Text))
    }
}
$now = [datetime]'2026-11-16T12:00:00Z'
$unknown = @{
    RamTotalBytes = 'Unknown/unavailable'; RamAvailableBytes = $null; InstalledModuleCount = $null
    MemoryModules = @(@{ Label = 'Unknown'; ConfiguredMHz = 0; ReportedMHz = 'Unknown/unavailable' })
    Volumes = @(@{ Name = 'Unknown'; SizeBytes = 0; FreeBytes = $null })
    Disks = @(@{ Name = 'Unknown'; Health = 'Unknown/unavailable'; PredictFailure = $null })
    Gpus = @(@{ Name = 'Unknown'; RefreshHz = $null; DriverDate = 'Unknown/unavailable' })
    StartupCount = $null; PendingRestart = 'Unknown/unavailable'; UptimeDays = $null
    DefenderEnabled = 'False'; DefenderRealtime = $null; SecureBoot = 'False'; PowerPlan = $null
}
Assert-InventoryTest (@(Get-SystemRecommendations $unknown $now).Count -eq 0) 'Unknown data must not produce recommendations.'
Assert-InventoryTest (@(Get-SystemRecommendations @{} $now).Count -eq 0) 'Missing facts must not produce recommendations.'
$fixture = @{
    RamTotalBytes = [long]16GB; RamAvailableBytes = [long]512MB; InstalledModuleCount = 1
    MemoryModules = @(@{ Label = 'DIMM A'; ConfiguredMHz = 2133; ReportedMHz = 3200 })
    Volumes = @(@{ Name = 'C:\'; SizeBytes = [long]100GB; FreeBytes = [long]10GB })
    Disks = @(@{ Name = 'Fixture SSD'; Health = 'Unhealthy'; PredictFailure = $null })
    Gpus = @(@{ Name = 'Fixture GPU'; RefreshHz = 60; DriverVersion = '1.2.3'; DriverDate = [datetime]'2020-01-01' })
    StartupCount = 20; PendingRestart = $true; UptimeDays = 30.0
    DefenderEnabled = $false; DefenderRealtime = $false; SecureBoot = $false; PowerPlan = 'Balanced'
}
$recommendations = @(Get-SystemRecommendations $fixture $now)
Assert-InventoryTest ($recommendations.Count -ge 10) 'Expected evidence-based recommendations for the populated fixture.'
foreach ($recommendation in $recommendations) {
    Assert-InventoryTest ($recommendation.priority -in @('High', 'Medium', 'Low')) 'Invalid priority.'
    Assert-InventoryTest ([bool]$recommendation.evidence -and [bool]$recommendation.action) 'Evidence/action must be populated.'
}
Assert-InventoryTest (($recommendations | Where-Object title -eq 'Reduce memory pressure').priority -eq 'High') 'Critical memory pressure must be High.'
Assert-InventoryTest (($recommendations | Where-Object title -eq 'Back up a disk reporting trouble').priority -eq 'High') 'Unhealthy disks require backup priority.'
Assert-InventoryTest (($recommendations | Where-Object title -eq 'Recover volume headroom').priority -eq 'Medium') 'Ten percent free should be Medium.'
Assert-InventoryTest (($recommendations | Where-Object title -eq 'Check memory expansion and channel layout').action -match '^If ') 'One DIMM advice must be conditional.'
Assert-InventoryTest (($recommendations | Where-Object title -eq 'Check the display refresh-rate option').action -match 'Only if') '60 Hz does not prove higher refresh support.'
Assert-InventoryTest (($recommendations | Where-Object title -eq 'Compare the installed GPU driver with the OEM').evidence -match 'does not prove') 'Driver age must not imply a newer release.'
Assert-InventoryTest (-not ($recommendations | Where-Object title -eq 'Consider a planned restart')) 'Pending-restart recommendation should supersede long uptime.'
$fixture.RamAvailableBytes = [long]0
Assert-InventoryTest ((@(Get-SystemRecommendations $fixture $now) | Where-Object title -eq 'Reduce memory pressure').priority -eq 'High') 'Known zero available RAM is not unknown.'
$fixture.Volumes[0].FreeBytes = [long]15GB
Assert-InventoryTest (-not (@(Get-SystemRecommendations $fixture $now) | Where-Object title -eq 'Recover volume headroom')) 'Exactly 15 percent free should not trigger.'
$fixture.Gpus[0].RefreshHz = 144
$fixture.Gpus[0].DriverDate = $now
Assert-InventoryTest (-not (@(Get-SystemRecommendations $fixture $now) | Where-Object { $_.title -in @('Check the display refresh-rate option', 'Compare the installed GPU driver with the OEM') })) 'Current driver and 144 Hz should not trigger display advice.'

# Dynamic-scope mocks cover every production probe. Unknown commands are never delegated.
function Get-Command { param($Name, $ErrorAction) return $null }
function Test-Path { param($LiteralPath, $ErrorAction) return $false }
function Get-ItemProperty { throw 'Isolated registry access is unavailable.' }
function Get-ChildItem { param($LiteralPath, $ErrorAction) return @() }
function Get-Process { throw 'Isolated process query is protected.' }
function Start-Job { throw 'No real jobs are allowed in the inventory fixture.' }
function Invoke-CimMethod { throw 'Inventory must never invoke a CIM mutation.' }
function Set-ItemProperty { throw 'No registry writes are allowed.' }
function Enable-ComputerRestore { throw 'No protection changes are allowed.' }
function Checkpoint-Computer { throw 'No restore creation is allowed.' }
function Get-CimInstance {
    param($ClassName, $Namespace, $OperationTimeoutSec, $ErrorAction, $Filter)
    Assert-InventoryTest ($OperationTimeoutSec -gt 0 -and $OperationTimeoutSec -le 8) 'CIM probes must be bounded.'
    switch ($ClassName) {
        'Win32_Processor' {
            Write-Warning 'Fixture CPU provider warning'
            return [pscustomobject]@{ Name = 'Fixture CPU'; SocketDesignation = 'CPU0'; NumberOfCores = 8; NumberOfLogicalProcessors = 16; CurrentClockSpeed = 3200; MaxClockSpeed = 4000; VirtualizationFirmwareEnabled = $false }
        }
        'Win32_ComputerSystem' { return [pscustomobject]@{ Manufacturer = 'Fixture OEM'; Model = 'Fixture PC'; TotalPhysicalMemory = [long]16GB; AutomaticManagedPagefile = $true } }
        'Win32_BaseBoard' { return [pscustomobject]@{ Manufacturer = 'Fixture OEM'; Product = 'Fixture board'; Version = '1' } }
        'Win32_BIOS' { return [pscustomobject]@{ Manufacturer = 'Fixture OEM'; SMBIOSBIOSVersion = '1.0'; ReleaseDate = [datetime]'2025-01-01' } }
        'Win32_OperatingSystem' { return [pscustomobject]@{ Caption = 'Fixture Windows'; TotalVisibleMemorySize = [long](16GB / 1KB); FreePhysicalMemory = [long](128MB / 1KB); BuildNumber = '26100'; LastBootUpTime = [datetime]::UtcNow.AddDays(-20) } }
        'Win32_PhysicalMemory' { return [pscustomobject]@{ Capacity = [long]16GB; DeviceLocator = 'DIMM A'; Speed = 3200; ConfiguredClockSpeed = 2133; Manufacturer = 'Fixture' } }
        'Win32_PhysicalMemoryArray' { return [pscustomobject]@{ MemoryDevices = 2 } }
        'Win32_VideoController' { return [pscustomobject]@{ Name = 'Fixture GPU'; PNPDeviceID = 'PCI\VEN_TEST\UNIQUE_INSTANCE'; AdapterRAM = [uint32]4294967295; CurrentHorizontalResolution = 1920; CurrentVerticalResolution = 1080; CurrentRefreshRate = 60; DriverVersion = '1.2.3'; DriverDate = [datetime]'2020-01-01' } }
        'Win32_DiskDrive' { return [pscustomobject]@{ Model = 'Fixture SSD'; Index = 0; Size = [long]100GB; Status = 'OK' } }
        'Win32_Volume' { return [pscustomobject]@{ Name = 'C:\'; Capacity = [long]100GB; FreeSpace = [long]10GB; FileSystem = 'NTFS'; BootVolume = $true; SystemVolume = $false } }
        'Win32_QuickFixEngineering' { return [pscustomobject]@{ HotFixID = 'KB-FIXTURE'; Description = 'Fixture update'; InstalledOn = '2026-01-01' } }
        'Win32_PowerPlan' { return [pscustomobject]@{ ElementName = 'Balanced' } }
        'Win32_Battery' { return @() }
        'Win32_StartupCommand' { return @(1..20 | ForEach-Object { [pscustomobject]@{ Name = "Fixture startup $_"; Location = 'Fixture registration' } }) }
        'Win32_PageFileUsage' { return @() }
        'Win32_Tpm' { throw 'Fixture TPM query is protected.' }
        'SystemRestore' { throw 'Fixture restore history is protected.' }
        default { throw "Unexpected production query in fixture: $ClassName" }
    }
}
# Execute the parsed inventory AST in the mocked scope, not a live file/process.
$output = @(& ($ast.GetScriptBlock()))
Assert-InventoryTest ($output.Count -eq 1 -and $output[0] -is [string]) 'Inventory stdout must contain only one JSON string.'
$document = $output[0] | ConvertFrom-Json
Assert-InventoryTest ($document.sections.Count -ge 12) 'Detailed inventory sections are missing.'
Assert-InventoryTest ([bool]$document.capturedAt -and [bool]$document.summary.cpu) 'Summary/timestamp missing.'
foreach ($section in $document.sections) {
    Assert-InventoryTest ($section.title -is [string]) 'Section title must be a string.'
    foreach ($fact in $section.facts) {
        Assert-InventoryTest ($fact.label -is [string] -and $fact.value -is [string]) 'Every fact label/value must be a string.'
    }
}
Assert-InventoryTest (@($document.issues | Where-Object { $_ -match 'Fixture CPU provider warning' }).Count -eq 1) 'Provider warnings must be retained in issues, not stdout.'
Assert-InventoryTest (@($document.issues | Where-Object { $_ -match 'restore history is protected' }).Count -eq 1) 'Protected restore history must retain its issue.'
$history = $document.sections | Where-Object title -eq 'System restore history'
Assert-InventoryTest (($history.facts | Where-Object label -eq 'Existing restore points visible to this account').value -eq 'Unknown/unavailable') 'Protected restore history must not become zero points.'
$graphics = $document.sections | Where-Object title -eq 'Graphics and display'
Assert-InventoryTest (($graphics.facts | Where-Object label -like '*Adapter memory').value -match '^Unknown/unavailable') '32-bit AdapterRAM must not become claimed VRAM.'
Assert-InventoryTest (-not ($document.recommendations | Where-Object title -in @('Verify active antivirus protection', 'Review Secure Boot support'))) 'Unavailable security queries must not become disabled-security advice.'

# Test optional-job timeout and warning handling using fake jobs, never Start-Job itself.
$script:InventoryIssues = New-Object 'System.Collections.Generic.List[string]'
$script:FakeJobMode = 'Timeout'; $script:JobStopped = 0; $script:JobRemoved = 0
function Get-Command { param($Name, $ErrorAction) return [pscustomobject]@{ Name = $Name } }
function Start-Job { param($ScriptBlock, $ArgumentList, $ErrorAction) return [pscustomobject]@{ State = $(if ($script:FakeJobMode -eq 'Timeout') { 'Running' } else { 'Completed' }) } }
function Wait-Job { param($Job, $Timeout, $ErrorAction) if ($script:FakeJobMode -ne 'Timeout') { return $Job } }
function Receive-Job { param($Job, $ErrorAction, $WarningAction) return [pscustomobject]@{ Data = @([pscustomobject]@{ Value = 'Fixture' }); Warnings = @('Fixture optional provider warning') } }
function Stop-Job { param($Job, $ErrorAction) $script:JobStopped++ }
function Remove-Job { param($Job, [switch]$Force, $ErrorAction) $script:JobRemoved++ }
$timeout = @(Invoke-OptionalInventoryProbe 'Fixture timeout' 'FixtureCommand' { throw 'Never executed' } -TimeoutSeconds 1)
Assert-InventoryTest (@($timeout | Where-Object { $null -ne $_ }).Count -eq 0) 'Timed-out data must be unknown.'
Assert-InventoryTest ($script:JobStopped -eq 1 -and $script:JobRemoved -eq 1) 'Timed-out job must be cleaned up.'
$script:FakeJobMode = 'Completed'
$optional = @(Invoke-OptionalInventoryProbe 'Fixture optional' 'FixtureCommand' { throw 'Never executed' })
Assert-InventoryTest ($optional[0].Value -eq 'Fixture') 'Successful optional data should be returned.'
Assert-InventoryTest (@($script:InventoryIssues | Where-Object { $_ -match 'optional provider warning' }).Count -eq 1) 'Optional provider warnings must be retained.'
Write-Output 'PASS: SystemInfo ASCII/PS5.1 parsing, pure recommendations, isolated JSON schema/unknown handling, warning capture, and bounded optional probes. No live probes executed.'
