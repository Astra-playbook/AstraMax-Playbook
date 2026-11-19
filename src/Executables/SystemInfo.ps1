# Windows PowerShell 5.1. Read-only local inventory; stdout is exactly one JSON object.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$WarningPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$script:InventoryIssues = New-Object 'System.Collections.Generic.List[string]'
$script:InventorySections = New-Object 'System.Collections.Generic.List[object]'

function Add-InventoryIssue {
    param([string]$Context, [string]$Message)
    $script:InventoryIssues.Add(('{0}: {1}' -f $Context, ($Message -replace '[\r\n]+', ' ')))
}

function Invoke-InventoryProbe {
    param([string]$Context, [scriptblock]$Probe, [switch]$AllowEmpty)
    try {
        $WarningPreference = 'Continue'
        $records = @(& $Probe 3>&1)
        $items = @($records | Where-Object { $_ -isnot [System.Management.Automation.WarningRecord] })
        foreach ($warning in @($records | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })) {
            Add-InventoryIssue $Context ('Provider warning: ' + $warning.Message)
        }
        if ($items.Count -eq 0 -and -not $AllowEmpty) {
            Add-InventoryIssue $Context 'No data returned; unavailable.'
        }
        return $items
    } catch {
        Add-InventoryIssue $Context $_.Exception.Message
        return $null
    }
}

function Invoke-OptionalInventoryProbe {
    param([string]$Context, [string]$Command, [scriptblock]$Probe, [int]$TimeoutSeconds = 10)
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Add-InventoryIssue $Context ($Command + ' is unavailable.')
        return $null
    }
    $job = $null
    try {
        # Optional providers can hang independently of CIM's operation timeout.
        # Run only the fixed, local read-only probes below, with a bounded wait.
        $job = Start-Job -ScriptBlock {
            param($ProbeText)
            $ErrorActionPreference = 'Stop'
            $WarningPreference = 'Continue'
            $ProgressPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'
            $DebugPreference = 'SilentlyContinue'
            $InformationPreference = 'SilentlyContinue'
            $records = @(& ([scriptblock]::Create($ProbeText)) 3>&1)
            [pscustomobject]@{
                Data = @($records | Where-Object { $_ -isnot [System.Management.Automation.WarningRecord] })
                Warnings = @($records | Where-Object { $_ -is [System.Management.Automation.WarningRecord] } | ForEach-Object { $_.Message })
            }
        } -ArgumentList $Probe.ToString() -ErrorAction Stop
        $finished = Wait-Job -Job $job -Timeout $TimeoutSeconds -ErrorAction Stop
        if (-not $finished) { throw ('Probe exceeded {0} seconds; unavailable.' -f $TimeoutSeconds) }
        $result = @(Receive-Job -Job $job -ErrorAction Stop -WarningAction Stop 3>&1)
        if ($job.State -ne 'Completed') { throw 'Provider did not complete successfully; unavailable.' }
        foreach ($envelope in $result) {
            foreach ($warning in @($envelope.Warnings)) {
                if ($warning) { Add-InventoryIssue $Context ('Provider warning: ' + $warning) }
            }
            $envelope.Data
        }
    } catch {
        Add-InventoryIssue $Context $_.Exception.Message
        return $null
    } finally {
        if ($null -ne $job) {
            try {
                if ($job.State -eq 'Running') { Stop-Job -Job $job -ErrorAction Stop }
                Remove-Job -Job $job -Force -ErrorAction Stop
            } catch { Add-InventoryIssue $Context ('Probe cleanup: ' + $_.Exception.Message) }
        }
    }
}

function Get-InventoryCim {
    param([string]$Class, [string]$Namespace = 'root/cimv2', [string]$Filter)
    $arguments = @{ ClassName = $Class; Namespace = $Namespace; OperationTimeoutSec = 6; ErrorAction = 'Stop' }
    if ($Filter) { $arguments.Filter = $Filter }
    Get-CimInstance @arguments
}

function Format-InventoryText {
    param($Value)
    if ($null -eq $Value) { return 'Unknown/unavailable' }
    if ($Value -is [bool]) { if ($Value) { return 'Yes' } else { return 'No' } }
    $text = ([string]$Value).Trim()
    if (-not $text) { return 'Unknown/unavailable' }
    return $text
}

function Format-InventoryBytes {
    param($Bytes)
    if ($null -eq $Bytes -or $Bytes -le 0) { return 'Unknown/unavailable' }
    return ('{0:N2} GiB ({1:N0} bytes)' -f ([double]$Bytes / 1GB), [double]$Bytes)
}

function Convert-InventoryDate {
    param($Value)
    if ($null -eq $Value -or -not ([string]$Value).Trim()) { return $null }
    try {
        if ($Value -is [datetime]) { return [datetime]$Value }
        if ([string]$Value -match '^\d{14}\.\d{6}[+-]\d{3}$') {
            return [System.Management.ManagementDateTimeConverter]::ToDateTime([string]$Value)
        }
        $date = [datetime]::MinValue
        if ([datetime]::TryParse([string]$Value, [ref]$date)) { return $date }
    } catch { }
    return $null
}

function Format-InventoryDate {
    param($Value)
    $date = Convert-InventoryDate $Value
    if ($null -eq $date) { return 'Unknown/unavailable' }
    return $date.ToString('o')
}

function New-InventoryFact {
    param([string]$Label, $Value)
    return [pscustomobject]@{ label = $Label; value = [string](Format-InventoryText $Value) }
}

function Add-InventorySection {
    param([string]$Title, [object[]]$Facts)
    $script:InventorySections.Add([pscustomobject]@{ title = $Title; facts = @($Facts) })
}

function Get-InventoryRegistry {
    param([string]$Path)
    # A missing key and an unreadable key must not become a fabricated false value.
    if (Test-Path -LiteralPath $Path -ErrorAction Stop) {
        return Get-ItemProperty -LiteralPath $Path -ErrorAction Stop
    }
    return $null
}

function Get-InventoryPendingRestart {
    $states = New-Object 'System.Collections.Generic.List[object]'
    foreach ($path in @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )) {
        try { $states.Add([bool](Test-Path -LiteralPath $path -ErrorAction Stop)) }
        catch { $states.Add($null); Add-InventoryIssue 'Pending restart' $_.Exception.Message }
    }
    try {
        $session = Get-InventoryRegistry 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
        if ($null -eq $session) { $states.Add($null) }
        else { $states.Add([bool](@($session.PendingFileRenameOperations | Where-Object { $_ }).Count -gt 0)) }
    } catch { $states.Add($null); Add-InventoryIssue 'Pending file operations' $_.Exception.Message }
    try {
        $active = Get-InventoryRegistry 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName'
        $configured = Get-InventoryRegistry 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName'
        if ($active.ComputerName -and $configured.ComputerName) {
            $states.Add([bool]($active.ComputerName -ne $configured.ComputerName))
        } else { $states.Add($null) }
    } catch { $states.Add($null); Add-InventoryIssue 'Pending computer rename' $_.Exception.Message }
    if (@($states | Where-Object { $_ -is [bool] -and $_ }).Count -gt 0) { return $true }
    if (@($states | Where-Object { $null -eq $_ }).Count -gt 0) {
        Add-InventoryIssue 'Pending restart' 'Some indicators were unavailable; absence of a pending restart is not established.'
        return $null
    }
    return $false
}

function Get-InventoryGpuMemory {
    param($Gpu)
    # AdapterRAM is a uint32 and can wrap/truncate above 4 GiB. Do not treat it as VRAM.
    # Read the 64-bit driver value only when a single adapter key matches the EXACT PnP ID.
    try {
        if (-not $Gpu.PNPDeviceID) { return 'Unknown/unavailable (WMI AdapterRAM is 32-bit and may truncate)' }
        $root = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
        $matches = @()
        foreach ($key in @(Get-ChildItem -LiteralPath $root -ErrorAction Stop | Where-Object { $_.PSChildName -match '^\d{4}$' })) {
            $data = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction Stop
            if ($data.MatchingDeviceId -ieq $Gpu.PNPDeviceID -or $data.DeviceInstanceID -ieq $Gpu.PNPDeviceID) {
                $matches += $data
                continue
            }
            # MatchingDeviceId is usually only a hardware ID, not a unique instance: reject it.
            $instance = Get-InventoryRegistry ($key.PSPath + '\Device Parameters')
            if ($instance.DeviceInstanceID -ieq $Gpu.PNPDeviceID) { $matches += $data }
        }
        if ($matches.Count -eq 1) {
            $memory = $matches[0].'HardwareInformation.qwMemorySize'
            if ($memory -is [byte[]] -and $memory.Length -eq 8) { $memory = [BitConverter]::ToUInt64($memory, 0) }
            if (($memory -is [long] -or $memory -is [ulong]) -and $memory -gt 0) {
                return ((Format-InventoryBytes $memory) + ' (64-bit driver-reported adapter memory; not necessarily dedicated VRAM)')
            }
        }
        return 'Unknown/unavailable (no unique 64-bit driver memory match; WMI AdapterRAM may truncate above 4 GiB)'
    } catch {
        Add-InventoryIssue 'GPU memory' $_.Exception.Message
        return 'Unknown/unavailable (protected driver registry or no reliable 64-bit memory value)'
    }
}

# Pure function: no probes, I/O, registry access, or mutation. Fixtures pass the same structured facts.
function Get-SystemRecommendations {
    param([System.Collections.IDictionary]$Facts, [datetime]$Now = [datetime]::UtcNow)
    $items = New-Object 'System.Collections.Generic.List[object]'
    function Test-RecommendationNumber {
        param($Value)
        return ($Value -is [byte] -or $Value -is [int] -or $Value -is [long] -or
            $Value -is [uint32] -or $Value -is [uint64] -or $Value -is [double] -or
            $Value -is [single] -or $Value -is [decimal])
    }
    function Add-Recommendation {
        param([string]$Title, [string]$Evidence, [string]$Action, [string]$Priority)
        $items.Add([pscustomobject]@{ title = $Title; evidence = $Evidence; action = $Action; priority = $Priority })
    }
    if ((Test-RecommendationNumber $Facts.RamTotalBytes) -and $Facts.RamTotalBytes -gt 0 -and
        (Test-RecommendationNumber $Facts.RamAvailableBytes) -and $Facts.RamAvailableBytes -ge 0 -and
        $Facts.RamAvailableBytes -le $Facts.RamTotalBytes) {
        $percent = 100.0 * $Facts.RamAvailableBytes / $Facts.RamTotalBytes
        if ($percent -lt 15 -or $Facts.RamAvailableBytes -lt 2GB) {
            $priority = 'Medium'
            if ($percent -lt 5 -or $Facts.RamAvailableBytes -lt 1GB) { $priority = 'High' }
            Add-Recommendation 'Reduce memory pressure' ('Available RAM: {0:N2} GiB ({1:N1}% of OS-visible RAM).' -f ($Facts.RamAvailableBytes / 1GB), $percent) 'Review the listed memory consumers and close unused applications. If normal workloads repeatedly exhaust RAM, check compatible capacity upgrades; keep the pagefile enabled.' $priority
        }
    }
    if ((Test-RecommendationNumber $Facts.InstalledModuleCount) -and $Facts.InstalledModuleCount -eq 1) {
        Add-Recommendation 'Check memory expansion and channel layout' 'One memory module was reported. This does not prove single-channel operation or that a slot is available.' 'If your motherboard supports paired channels and has a compatible available slot, consult its slot-layout guide before considering a matched module. Soldered RAM, DDR5 subchannels, and OEM layouts differ.' 'Low'
    }
    foreach ($module in @($Facts.MemoryModules)) {
        if ((Test-RecommendationNumber $module.ConfiguredMHz) -and $module.ConfiguredMHz -gt 0 -and
            (Test-RecommendationNumber $module.ReportedMHz) -and $module.ReportedMHz -gt $module.ConfiguredMHz) {
            Add-Recommendation 'Check reported memory configuration' ('{0}: configured {1} MHz; module-reported speed {2} MHz (not proof of an XMP/EXPO rating).' -f $module.Label, $module.ConfiguredMHz, $module.ReportedMHz) 'Check the motherboard/OEM memory support list and BIOS settings. Only consider a supported profile after checking stability, voltage, warranty, and recovery instructions; no overclock or BIOS change is applied here.' 'Low'
            break
        }
    }
    foreach ($volume in @($Facts.Volumes)) {
        if ((Test-RecommendationNumber $volume.SizeBytes) -and $volume.SizeBytes -gt 0 -and
            (Test-RecommendationNumber $volume.FreeBytes) -and $volume.FreeBytes -ge 0 -and $volume.FreeBytes -le $volume.SizeBytes) {
            $percent = 100.0 * $volume.FreeBytes / $volume.SizeBytes
            if ($percent -lt 15) {
                $priority = 'Medium'; if ($percent -lt 5) { $priority = 'High' }
                Add-Recommendation 'Recover volume headroom' ('{0}: {1:N1}% free ({2:N2} GiB).' -f $volume.Name, $percent, ($volume.FreeBytes / 1GB)) 'Review Windows Storage settings and move or remove only files you recognize. Back up first; never indiscriminately delete system files or restore points.' $priority
            }
        }
    }
    foreach ($disk in @($Facts.Disks)) {
        if ($disk.Health -in @('Warning', 'Unhealthy') -or $disk.PredictFailure -eq $true) {
            Add-Recommendation 'Back up a disk reporting trouble' ('{0}: health {1}; predictive failure {2}.' -f $disk.Name, $disk.Health, $disk.PredictFailure) 'Back up important files immediately, check the vendor diagnostic tool and connections, and plan replacement if confirmed. Cleanup and performance tweaks cannot repair hardware failure.' 'High'
        }
    }
    foreach ($gpu in @($Facts.Gpus)) {
        if ((Test-RecommendationNumber $gpu.RefreshHz) -and $gpu.RefreshHz -ge 59 -and $gpu.RefreshHz -le 61) {
            Add-Recommendation 'Check the display refresh-rate option' ('{0}: Windows reports {1} Hz for its current mode.' -f $gpu.Name, $gpu.RefreshHz) 'Only if the connected monitor, cable, port, and resolution support higher refresh rates, check Settings > System > Display > Advanced display. This inventory does not establish monitor capability.' 'Low'
        }
        if ($gpu.DriverDate -is [datetime] -and $gpu.DriverDate -lt $Now.AddYears(-2)) {
            Add-Recommendation 'Compare the installed GPU driver with the OEM' ('{0}: version {1}, driver date {2:yyyy-MM-dd}. A driver date does not prove a newer compatible release exists.' -f $gpu.Name, $gpu.DriverVersion, $gpu.DriverDate) 'Compare the exact version against the PC/GPU manufacturer support page and release notes. Use a supported driver only if appropriate; avoid third-party driver updaters.' 'Low'
        }
    }
    if ((Test-RecommendationNumber $Facts.StartupCount) -and $Facts.StartupCount -ge 15) {
        Add-Recommendation 'Review registered startup applications' ('{0} startup registrations were reported; registrations may already be disabled in Task Manager.' -f $Facts.StartupCount) 'Check Task Manager startup impact and disable only optional launchers you recognize. Keep security, audio, input, and essential OEM services.' 'Medium'
    }
    if ($Facts.PendingRestart -is [bool] -and $Facts.PendingRestart) {
        Add-Recommendation 'Complete the pending Windows restart' 'At least one Windows pending-restart indicator is present.' 'Save work and restart when convenient, then re-check Windows Update. Do not forcibly interrupt servicing.' 'Medium'
    } elseif ((Test-RecommendationNumber $Facts.UptimeDays) -and $Facts.UptimeDays -ge 14) {
        Add-Recommendation 'Consider a planned restart' ('The last reported Windows boot was {0:N1} days ago.' -f $Facts.UptimeDays) 'Save work and restart at a convenient time if you are seeing stale state or performance problems. Long uptime alone is not evidence of a fault.' 'Low'
    }
    if ($Facts.DefenderEnabled -is [bool] -and -not $Facts.DefenderEnabled) {
        Add-Recommendation 'Verify active antivirus protection' 'Microsoft Defender reports antivirus protection disabled; third-party antivirus may be responsible.' 'Check Windows Security for a healthy registered antivirus provider. If none is active, re-enable supported protection; do not weaken security for performance.' 'High'
    } elseif ($Facts.DefenderRealtime -is [bool] -and -not $Facts.DefenderRealtime) {
        Add-Recommendation 'Check real-time antivirus protection' 'Microsoft Defender reports real-time protection disabled.' 'Confirm whether a healthy third-party antivirus is active. If Defender is your intended provider, restore real-time protection in Windows Security.' 'High'
    }
    if ($Facts.SecureBoot -is [bool] -and -not $Facts.SecureBoot) {
        Add-Recommendation 'Review Secure Boot support' 'The Windows Secure Boot query explicitly reports disabled.' 'Consult the OEM firmware guide. Before enabling Secure Boot, confirm UEFI-compatible boot, save any BitLocker recovery key privately, and check dual-boot/driver compatibility. Do not change it blindly.' 'Medium'
    }
    if ($Facts.PowerPlan -and $Facts.PowerPlan -match 'Balanced|Power saver|Power saving') {
        Add-Recommendation 'Measure power-plan tradeoffs, if needed' ('Active plan: {0}.' -f $Facts.PowerPlan) 'If a repeatable workload is CPU-limited, compare supported power modes using the same workload. Higher-performance modes may increase temperatures, fan noise, and battery drain; Balanced is usually appropriate. No change is applied.' 'Low'
    }
    return $items.ToArray()
}

$now = [datetime]::UtcNow
$observed = @{}
try {
$cpu = @(Invoke-InventoryProbe 'Processor' { Get-InventoryCim 'Win32_Processor' })
$computer = @(Invoke-InventoryProbe 'Computer system' { Get-InventoryCim 'Win32_ComputerSystem' }) | Select-Object -First 1
$board = @(Invoke-InventoryProbe 'Motherboard' { Get-InventoryCim 'Win32_BaseBoard' })
$bios = @(Invoke-InventoryProbe 'BIOS' { Get-InventoryCim 'Win32_BIOS' }) | Select-Object -First 1
$os = @(Invoke-InventoryProbe 'Windows' { Get-InventoryCim 'Win32_OperatingSystem' }) | Select-Object -First 1
$modules = @(Invoke-InventoryProbe 'Memory modules' { Get-InventoryCim 'Win32_PhysicalMemory' })
$arrays = @(Invoke-InventoryProbe 'Memory slots' { Get-InventoryCim 'Win32_PhysicalMemoryArray' })
$gpus = @(Invoke-InventoryProbe 'Display adapters' { Get-InventoryCim 'Win32_VideoController' })

$facts = @()
foreach ($processor in $cpu) {
    if ($null -eq $processor) { continue }
    $prefix = Format-InventoryText $processor.SocketDesignation
    $facts += New-InventoryFact "$prefix - CPU" $processor.Name
    $facts += New-InventoryFact "$prefix - Manufacturer" $processor.Manufacturer
    $facts += New-InventoryFact "$prefix - Cores / threads" ('{0} / {1}' -f (Format-InventoryText $processor.NumberOfCores), (Format-InventoryText $processor.NumberOfLogicalProcessors))
    $facts += New-InventoryFact "$prefix - Current / maximum reported clock (MHz)" ('{0} / {1}' -f (Format-InventoryText $processor.CurrentClockSpeed), (Format-InventoryText $processor.MaxClockSpeed))
    $facts += New-InventoryFact "$prefix - L2 / L3 cache (KiB)" ('{0} / {1}' -f (Format-InventoryText $processor.L2CacheSize), (Format-InventoryText $processor.L3CacheSize))
    $facts += New-InventoryFact "$prefix - Firmware virtualization enabled" $processor.VirtualizationFirmwareEnabled
    $facts += New-InventoryFact "$prefix - VM monitor extensions / SLAT" ('{0} / {1}' -f (Format-InventoryText $processor.VMMonitorModeExtensions), (Format-InventoryText $processor.SecondLevelAddressTranslationExtensions))
}
$facts += New-InventoryFact 'Reported populated CPU sockets' $(if (@($cpu | Where-Object { $null -ne $_ }).Count) { @($cpu | Where-Object { $null -ne $_ }).Count } else { $null })
$facts += New-InventoryFact 'Hypervisor present' $computer.HypervisorPresent
$facts += New-InventoryFact 'Clock/cache interpretation' 'Provider-reported values, not live boost clocks, temperatures, or benchmark results.'
Add-InventorySection 'Processor' $facts

$firmware = @(Invoke-OptionalInventoryProbe 'Firmware type' 'Get-ComputerInfo' { Get-ComputerInfo -Property BiosFirmwareType -ErrorAction Stop }) | Select-Object -First 1
$facts = @(
    (New-InventoryFact 'Manufacturer / model' ('{0} / {1}' -f (Format-InventoryText $computer.Manufacturer), (Format-InventoryText $computer.Model))),
    (New-InventoryFact 'System type' $computer.SystemType),
    (New-InventoryFact 'BIOS vendor' $bios.Manufacturer),
    (New-InventoryFact 'BIOS version' $bios.SMBIOSBIOSVersion),
    (New-InventoryFact 'BIOS release date' (Format-InventoryDate $bios.ReleaseDate)),
    (New-InventoryFact 'Firmware boot type (UEFI / legacy)' $firmware.BiosFirmwareType)
)
foreach ($baseboard in $board) {
    if ($null -ne $baseboard) {
        $facts += New-InventoryFact 'Motherboard manufacturer / product / revision' ('{0} / {1} / {2}' -f (Format-InventoryText $baseboard.Manufacturer), (Format-InventoryText $baseboard.Product), (Format-InventoryText $baseboard.Version))
    }
}
Add-InventorySection 'Machine, motherboard and firmware' $facts

$ramTotal = $null; $ramAvailable = $null
if ($null -ne $os.TotalVisibleMemorySize -and $os.TotalVisibleMemorySize -gt 0) { $ramTotal = [double]$os.TotalVisibleMemorySize * 1KB }
if ($null -ne $os.FreePhysicalMemory) { $ramAvailable = [double]$os.FreePhysicalMemory * 1KB }
$observed.RamTotalBytes = $ramTotal; $observed.RamAvailableBytes = $ramAvailable
$validModules = @($modules | Where-Object { $null -ne $_ })
$moduleCount = $null; $installedCapacity = $null
if ($validModules.Count) {
    $moduleCount = $validModules.Count
    if (@($validModules | Where-Object { $null -eq $_.Capacity -or $_.Capacity -le 0 }).Count -eq 0) {
        $installedCapacity = ($validModules | Measure-Object -Property Capacity -Sum).Sum
    } else { Add-InventoryIssue 'Memory modules' 'Some capacities are unavailable; installed module capacity is unknown.' }
}
$observed.InstalledModuleCount = $moduleCount
$observed.MemoryModules = @()
$slotCount = $null
$validArrays = @($arrays | Where-Object { $null -ne $_ })
if ($validArrays.Count -gt 0 -and @($validArrays | Where-Object { $null -eq $_.MemoryDevices -or $_.MemoryDevices -le 0 }).Count -eq 0) {
    $slotCount = ($validArrays | Measure-Object -Property MemoryDevices -Sum).Sum
}
$facts = @(
    (New-InventoryFact 'Physical memory reported by system' (Format-InventoryBytes $computer.TotalPhysicalMemory)),
    (New-InventoryFact 'Installed module capacity' (Format-InventoryBytes $installedCapacity)),
    (New-InventoryFact 'OS-visible / available RAM' ('{0} / {1}' -f (Format-InventoryBytes $ramTotal), $(if ($null -ne $ramAvailable -and $ramAvailable -eq 0) { '0 bytes' } else { Format-InventoryBytes $ramAvailable }))),
    (New-InventoryFact 'Installed modules / firmware-reported slots' ('{0} / {1}' -f (Format-InventoryText $moduleCount), (Format-InventoryText $slotCount))),
    (New-InventoryFact 'Channel layout' 'Unknown/unavailable (module count does not establish channel mode; consult the motherboard guide)')
)
foreach ($module in $validModules) {
    $name = '{0} / {1}' -f (Format-InventoryText $module.DeviceLocator), (Format-InventoryText $module.BankLabel)
    $facts += New-InventoryFact "$name - Capacity / manufacturer / part" ('{0} / {1} / {2}' -f (Format-InventoryBytes $module.Capacity), (Format-InventoryText $module.Manufacturer), (Format-InventoryText $module.PartNumber))
    $facts += New-InventoryFact "$name - Configured / module-reported speed (MHz)" ('{0} / {1}' -f $(if ($module.ConfiguredClockSpeed -gt 0) { $module.ConfiguredClockSpeed } else { 'Unknown/unavailable' }), $(if ($module.Speed -gt 0) { $module.Speed } else { 'Unknown/unavailable' }))
    $facts += New-InventoryFact "$name - Data / total width (bits)" ('{0} / {1}' -f (Format-InventoryText $module.DataWidth), (Format-InventoryText $module.TotalWidth))
    $observed.MemoryModules += [pscustomobject]@{ Label = $name; ConfiguredMHz = $module.ConfiguredClockSpeed; ReportedMHz = $module.Speed }
}
Add-InventorySection 'Memory' $facts

$facts = @(); $observed.Gpus = @()
foreach ($gpu in $gpus) {
    if ($null -eq $gpu) { continue }
    $name = Format-InventoryText $gpu.Name
    $facts += New-InventoryFact "$name - Driver version / date" ('{0} / {1}' -f (Format-InventoryText $gpu.DriverVersion), (Format-InventoryDate $gpu.DriverDate))
    $facts += New-InventoryFact "$name - Adapter memory" (Get-InventoryGpuMemory $gpu)
    $mode = 'Unknown/unavailable'
    if ($gpu.CurrentHorizontalResolution -gt 0 -and $gpu.CurrentVerticalResolution -gt 0) { $mode = '{0} x {1}' -f $gpu.CurrentHorizontalResolution, $gpu.CurrentVerticalResolution }
    $hz = $null
    # WMI uses 0/1 for unknown/default refresh; these are not physical measurements.
    if ($gpu.CurrentRefreshRate -gt 1) { $hz = $gpu.CurrentRefreshRate }
    $facts += New-InventoryFact "$name - Current resolution / refresh (Hz)" ('{0} / {1}' -f $mode, (Format-InventoryText $hz))
    $facts += New-InventoryFact "$name - Driver-reported video mode" $gpu.VideoModeDescription
    $observed.Gpus += [pscustomobject]@{ Name = $name; RefreshHz = $hz; DriverVersion = $gpu.DriverVersion; DriverDate = (Convert-InventoryDate $gpu.DriverDate) }
}
if (-not $facts.Count) { $facts += New-InventoryFact 'Display adapters' $null }
$facts += New-InventoryFact 'Display limitations' 'WMI may omit inactive/multiple monitor modes. No monitor capability, temperature, or accurate VRAM is inferred from AdapterRAM.'
Add-InventorySection 'Graphics and display' $facts

$drives = @(Invoke-InventoryProbe 'Disk drives' { Get-InventoryCim 'Win32_DiskDrive' })
$physical = @(Invoke-OptionalInventoryProbe 'Physical disk health' 'Get-PhysicalDisk' { Get-PhysicalDisk -ErrorAction Stop | Select-Object FriendlyName, DeviceId, MediaType, BusType, HealthStatus, OperationalStatus, Size, FirmwareVersion })
$facts = @(); $observed.Disks = @()
foreach ($disk in $drives) {
    if ($null -eq $disk) { continue }
    $name = 'Disk {0} - {1}' -f (Format-InventoryText $disk.Index), (Format-InventoryText $disk.Model)
    $facts += New-InventoryFact "$name - Capacity / interface / firmware" ('{0} / {1} / {2}' -f (Format-InventoryBytes $disk.Size), (Format-InventoryText $disk.InterfaceType), (Format-InventoryText $disk.FirmwareRevision))
    $facts += New-InventoryFact "$name - WMI status (not full SMART health)" $disk.Status
}
foreach ($disk in $physical) {
    if ($null -eq $disk) { continue }
    $name = '{0} (Storage provider ID {1})' -f (Format-InventoryText $disk.FriendlyName), (Format-InventoryText $disk.DeviceId)
    $facts += New-InventoryFact "$name - Type / bus / capacity" ('{0} / {1} / {2}' -f (Format-InventoryText $disk.MediaType), (Format-InventoryText $disk.BusType), (Format-InventoryBytes $disk.Size))
    $facts += New-InventoryFact "$name - Health / operational status / firmware" ('{0} / {1} / {2}' -f (Format-InventoryText $disk.HealthStatus), (Format-InventoryText ($disk.OperationalStatus -join ', ')), (Format-InventoryText $disk.FirmwareVersion))
    $observed.Disks += [pscustomobject]@{ Name = $name; Health = [string]$disk.HealthStatus; PredictFailure = $null }
}
if (-not $facts.Count) { $facts += New-InventoryFact 'Physical disks' $null }
$facts += New-InventoryFact 'Health limitations' 'Storage-provider health is not a complete SMART scan. RAID/USB/virtual disks may hide health, firmware, and physical mapping; no sensor values are invented.'
Add-InventorySection 'Physical storage' $facts

$volumes = @(Invoke-InventoryProbe 'Volumes' { Get-InventoryCim 'Win32_Volume' -Filter 'DriveType = 3' })
$facts = @(); $observed.Volumes = @()
foreach ($volume in $volumes) {
    if ($null -eq $volume) { continue }
    $name = Format-InventoryText $volume.Name
    $free = 'Unknown/unavailable'
    if ($null -ne $volume.FreeSpace -and $volume.FreeSpace -ge 0 -and $volume.Capacity -gt 0) {
        $free = '{0:N2} GiB ({1:N1}% free)' -f ([double]$volume.FreeSpace / 1GB), (100.0 * $volume.FreeSpace / $volume.Capacity)
    }
    $facts += New-InventoryFact "$name - Label / filesystem" ('{0} / {1}' -f (Format-InventoryText $volume.Label), (Format-InventoryText $volume.FileSystem))
    $facts += New-InventoryFact "$name - Capacity / free" ('{0} / {1}' -f (Format-InventoryBytes $volume.Capacity), $free)
    $facts += New-InventoryFact "$name - Boot / system volume" ('{0} / {1}' -f (Format-InventoryText $volume.BootVolume), (Format-InventoryText $volume.SystemVolume))
    $observed.Volumes += [pscustomobject]@{ Name = $name; SizeBytes = $volume.Capacity; FreeBytes = $volume.FreeSpace }
}
if (-not $facts.Count) { $facts += New-InventoryFact 'Fixed volumes' $null }
Add-InventorySection 'Volumes and free space' $facts

$network = @(Invoke-OptionalInventoryProbe 'Network inventory' 'Get-NetAdapter' {
    $adapters = @(Get-NetAdapter -ErrorAction Stop | Select-Object Name, InterfaceDescription, ifIndex, Status, LinkSpeed)
    $interfaces = @(Get-NetIPInterface -ErrorAction Stop | Select-Object InterfaceIndex, AddressFamily, NlMtu, ConnectionState, InterfaceMetric)
    $configurations = @(Get-NetIPConfiguration -All -ErrorAction Stop | ForEach-Object {
        [pscustomobject]@{
            InterfaceIndex = $_.InterfaceIndex
            IPv4 = @($_.IPv4Address | ForEach-Object { '{0}/{1}' -f $_.IPAddress, $_.PrefixLength })
            IPv6 = @($_.IPv6Address | ForEach-Object { '{0}/{1}' -f $_.IPAddress, $_.PrefixLength })
            Gateway = @($_.IPv4DefaultGateway.NextHop) + @($_.IPv6DefaultGateway.NextHop)
            DNS = @($_.DNSServer | ForEach-Object { $_.ServerAddresses })
        }
    })
    [pscustomobject]@{ Adapters = $adapters; Interfaces = $interfaces; Configurations = $configurations }
}) | Select-Object -First 1
$facts = @()
foreach ($adapter in @($network.Adapters)) {
    if ($null -eq $adapter) { continue }
    $name = Format-InventoryText $adapter.Name
    $facts += New-InventoryFact "$name - Adapter / interface index" ('{0} / {1}' -f (Format-InventoryText $adapter.InterfaceDescription), (Format-InventoryText $adapter.ifIndex))
    $facts += New-InventoryFact "$name - Status / negotiated link speed" ('{0} / {1}' -f (Format-InventoryText $adapter.Status), (Format-InventoryText $adapter.LinkSpeed))
    foreach ($interface in @($network.Interfaces | Where-Object { $_.InterfaceIndex -eq $adapter.ifIndex })) {
        $facts += New-InventoryFact "$name - $($interface.AddressFamily) MTU / metric" ('{0} / {1}' -f (Format-InventoryText $interface.NlMtu), (Format-InventoryText $interface.InterfaceMetric))
    }
    foreach ($configuration in @($network.Configurations | Where-Object { $_.InterfaceIndex -eq $adapter.ifIndex })) {
        $facts += New-InventoryFact "$name - IPv4 / IPv6" ('{0} / {1}' -f (Format-InventoryText ($configuration.IPv4 -join ', ')), (Format-InventoryText ($configuration.IPv6 -join ', ')))
        $facts += New-InventoryFact "$name - Gateway / DNS" ('{0} / {1}' -f (Format-InventoryText ($configuration.Gateway -join ', ')), (Format-InventoryText ($configuration.DNS -join ', ')))
    }
}
if (-not $facts.Count) { $facts += New-InventoryFact 'Adapters, link speed, MTU, IP and DNS' $null }
$facts += New-InventoryFact 'Network interpretation' 'Local configuration only: negotiated link speed is not Internet throughput. No ping, speed test, DNS lookup, or outbound request was made.'
Add-InventorySection 'Network' $facts

$windows = @(Invoke-InventoryProbe 'Windows build registry' { Get-InventoryRegistry 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' }) | Select-Object -First 1
$restart = Get-InventoryPendingRestart
$observed.PendingRestart = $restart
$boot = Convert-InventoryDate $os.LastBootUpTime
$uptime = $null
if ($null -ne $boot -and $boot.ToUniversalTime() -le $now) { $uptime = ($now - $boot.ToUniversalTime()).TotalDays }
$observed.UptimeDays = $uptime
$build = Format-InventoryText $os.BuildNumber
if ($null -ne $windows.UBR) { $build += '.' + [string]$windows.UBR }
$facts = @(
    (New-InventoryFact 'Windows edition' $os.Caption),
    (New-InventoryFact 'Architecture / version / build' ('{0} / {1} / {2}' -f (Format-InventoryText $os.OSArchitecture), (Format-InventoryText $os.Version), $build)),
    (New-InventoryFact 'Display version / edition ID' ('{0} / {1}' -f (Format-InventoryText $windows.DisplayVersion), (Format-InventoryText $windows.EditionID))),
    (New-InventoryFact 'Install date' (Format-InventoryDate $os.InstallDate)),
    (New-InventoryFact 'Last boot' (Format-InventoryDate $boot)),
    (New-InventoryFact 'Uptime' $(if ($null -ne $uptime) { '{0:N1} days' -f $uptime } else { 'Unknown/unavailable' })),
    (New-InventoryFact 'Pending restart (common Windows indicators)' $restart)
)
Add-InventorySection 'Windows and uptime' $facts

$updates = @(Invoke-InventoryProbe 'Installed Windows updates' { Get-InventoryCim 'Win32_QuickFixEngineering' } -AllowEmpty)
$datedUpdates = @($updates | Where-Object { $null -ne $_ } | ForEach-Object {
    [pscustomobject]@{ Id = $_.HotFixID; Description = $_.Description; Installed = (Convert-InventoryDate $_.InstalledOn) }
} | Sort-Object Installed -Descending | Select-Object -First 8)
$wu = @(Invoke-InventoryProbe 'Windows Update last success' { Get-InventoryRegistry 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results\Install' } -AllowEmpty) | Select-Object -First 1
$facts = @(
    (New-InventoryFact 'Last successful update install (registry, if retained)' (Format-InventoryDate $wu.LastSuccessTime)),
    (New-InventoryFact 'Update coverage' 'Installed hotfixes only; not a complete update history or proof that Windows is up to date. No online update scan was performed.')
)
foreach ($update in $datedUpdates) {
    $facts += New-InventoryFact ('{0} - {1}' -f (Format-InventoryText $update.Id), (Format-InventoryText $update.Description)) (Format-InventoryDate $update.Installed)
}
if (-not $datedUpdates.Count) { $facts += New-InventoryFact 'Installed hotfix records' 'None returned or unavailable; see issues for query failures.' }
Add-InventorySection 'Windows update evidence' $facts

$plan = @(Invoke-OptionalInventoryProbe 'Active power plan' 'powercfg.exe' {
    $text = (& (Join-Path $env:SystemRoot 'System32\powercfg.exe') /getactivescheme 2>&1) -join ' '
    if ($LASTEXITCODE -ne 0) { throw $text }
    $name = $text
    if ($text -match '\((.*)\)\s*$') { $name = $Matches[1] }
    [pscustomobject]@{ ElementName = $name }
}) | Select-Object -First 1
$batteries = @(Invoke-InventoryProbe 'Battery' { Get-InventoryCim 'Win32_Battery' } -AllowEmpty)
$observed.PowerPlan = $plan.ElementName
$facts = @((New-InventoryFact 'Active power plan' $plan.ElementName))
foreach ($battery in $batteries) {
    if ($null -eq $battery) { continue }
    $facts += New-InventoryFact 'Battery name / charge (%) / status code' ('{0} / {1} / {2}' -f (Format-InventoryText $battery.Name), (Format-InventoryText $battery.EstimatedChargeRemaining), (Format-InventoryText $battery.BatteryStatus))
    $runtime = 'Unknown/unavailable'
    if ($null -ne $battery.EstimatedRunTime -and $battery.EstimatedRunTime -gt 0 -and $battery.EstimatedRunTime -lt 71582788) { $runtime = '{0} minutes (firmware estimate)' -f $battery.EstimatedRunTime }
    $facts += New-InventoryFact 'Estimated battery runtime' $runtime
}
if (-not @($batteries | Where-Object { $null -ne $_ }).Count) { $facts += New-InventoryFact 'Battery' 'No battery reported or provider unavailable; this does not establish AC power status.' }
$facts += New-InventoryFact 'Temperature / fan sensors' 'Unknown/unavailable (no reliable sensor provider queried)'
Add-InventorySection 'Power and battery' $facts

$defender = @(Invoke-OptionalInventoryProbe 'Microsoft Defender' 'Get-MpComputerStatus' {
    Get-MpComputerStatus -ErrorAction Stop | Select-Object AMServiceEnabled, AntivirusEnabled, RealTimeProtectionEnabled, AntivirusSignatureVersion, AntivirusSignatureLastUpdated, NISEnabled
}) | Select-Object -First 1
$tpm = @(Invoke-OptionalInventoryProbe 'TPM' 'Get-Tpm' {
    Get-Tpm -ErrorAction Stop | Select-Object TpmPresent, TpmReady, TpmEnabled, TpmActivated, ManufacturerIdTxt, ManufacturerVersion
}) | Select-Object -First 1
$secureBootResult = @(Invoke-OptionalInventoryProbe 'Secure Boot' 'Confirm-SecureBootUEFI' { Confirm-SecureBootUEFI -ErrorAction Stop })
$secureBoot = $null
if ($secureBootResult.Count -eq 1 -and $secureBootResult[0] -is [bool]) { $secureBoot = $secureBootResult[0] }
$observed.DefenderEnabled = $defender.AntivirusEnabled
$observed.DefenderRealtime = $defender.RealTimeProtectionEnabled
$observed.SecureBoot = $secureBoot
$tpmSpecification = @(Invoke-InventoryProbe 'TPM specification' { Get-InventoryCim 'Win32_Tpm' -Namespace 'root/cimv2/security/microsofttpm' } -AllowEmpty) | Select-Object -First 1
$facts = @(
    (New-InventoryFact 'Defender service / antivirus / real-time protection' ('{0} / {1} / {2}' -f (Format-InventoryText $defender.AMServiceEnabled), (Format-InventoryText $defender.AntivirusEnabled), (Format-InventoryText $defender.RealTimeProtectionEnabled))),
    (New-InventoryFact 'Defender signature version / updated' ('{0} / {1}' -f (Format-InventoryText $defender.AntivirusSignatureVersion), (Format-InventoryDate $defender.AntivirusSignatureLastUpdated))),
    (New-InventoryFact 'Secure Boot enabled (explicit Windows query)' $secureBoot),
    (New-InventoryFact 'TPM present / ready / enabled / activated' ('{0} / {1} / {2} / {3}' -f (Format-InventoryText $tpm.TpmPresent), (Format-InventoryText $tpm.TpmReady), (Format-InventoryText $tpm.TpmEnabled), (Format-InventoryText $tpm.TpmActivated))),
    (New-InventoryFact 'TPM manufacturer / firmware / specification' ('{0} / {1} / {2}' -f (Format-InventoryText $tpm.ManufacturerIdTxt), (Format-InventoryText $tpm.ManufacturerVersion), (Format-InventoryText $tpmSpecification.SpecVersion))),
    (New-InventoryFact 'Protection interpretation' 'Unavailable/protected queries are unknown, not disabled. Defender may be passive when another antivirus is installed. No security settings were changed.')
)
Add-InventorySection 'Security status' $facts

$startups = @(Invoke-InventoryProbe 'Startup registrations' { Get-InventoryCim 'Win32_StartupCommand' } -AllowEmpty)
$validStartups = @($startups | Where-Object { $null -ne $_ })
$startupCount = $null
# Empty successful queries are distinguished from query failures using the issue list.
if (-not @($script:InventoryIssues | Where-Object { $_ -like 'Startup registrations:*' }).Count) { $startupCount = $validStartups.Count }
$observed.StartupCount = $startupCount
$facts = @(
    (New-InventoryFact 'Registered startup entries' $startupCount),
    (New-InventoryFact 'Startup interpretation' 'Registrations are not measured startup impact or proof an item is enabled. Command lines and account names are deliberately omitted.')
)
foreach ($entry in @($validStartups | Sort-Object Name | Select-Object -First 25)) {
    $facts += New-InventoryFact (Format-InventoryText $entry.Name) $entry.Location
}
$processes = @(Invoke-InventoryProbe 'Top memory consumers' {
    Get-Process -ErrorAction Stop | Sort-Object WorkingSet64 -Descending | Select-Object -First 8 Name, Id, WorkingSet64
})
foreach ($process in $processes) {
    if ($null -ne $process) { $facts += New-InventoryFact ('{0} (PID {1}) working set' -f $process.Name, $process.Id) (Format-InventoryBytes $process.WorkingSet64) }
}
Add-InventorySection 'Startup and memory consumers' $facts

$pagefiles = @(Invoke-InventoryProbe 'Pagefile usage' { Get-InventoryCim 'Win32_PageFileUsage' } -AllowEmpty)
$facts = @((New-InventoryFact 'Automatically managed pagefile' $computer.AutomaticManagedPagefile))
foreach ($pagefile in $pagefiles) {
    if ($null -eq $pagefile) { continue }
    $facts += New-InventoryFact (Format-InventoryText $pagefile.Name) ('Allocated / in use / peak: {0} / {1} / {2} MiB' -f (Format-InventoryText $pagefile.AllocatedBaseSize), (Format-InventoryText $pagefile.CurrentUsage), (Format-InventoryText $pagefile.PeakUsage))
}
if (-not @($pagefiles | Where-Object { $null -ne $_ }).Count) { $facts += New-InventoryFact 'Pagefile usage' 'No pagefile reported or unavailable; see issues. Do not infer that paging is disabled from an unavailable query.' }
Add-InventorySection 'Pagefile' $facts

$points = @(Invoke-InventoryProbe 'Existing restore points' { Get-InventoryCim 'SystemRestore' -Namespace 'root/default' } -AllowEmpty)
$validPoints = @($points | Where-Object { $null -ne $_ } | Sort-Object SequenceNumber -Descending)
$pointCount = $null
if (-not @($script:InventoryIssues | Where-Object { $_ -like 'Existing restore points:*' }).Count) { $pointCount = $validPoints.Count }
$facts = @(
    (New-InventoryFact 'Existing restore points visible to this account' $pointCount),
    (New-InventoryFact 'Restore protection status' 'Unknown/unavailable (point history does not prove current protection is enabled)'),
    (New-InventoryFact 'Restore reminder' 'Windows restore points cover supported system state, not a full backup of personal files. Use System Protection to review protection settings; nothing was created or enabled.')
)
foreach ($point in @($validPoints | Select-Object -First 5)) {
    $facts += New-InventoryFact ('Sequence {0} - {1}' -f $point.SequenceNumber, (Format-InventoryText $point.Description)) (Format-InventoryDate $point.CreationTime)
}
Add-InventorySection 'System restore history' $facts
} catch {
    Add-InventoryIssue 'Inventory collection' ('Unexpected provider/formatting failure; inventory is partial. ' + $_.Exception.Message)
    Add-InventorySection 'Inventory availability' @((New-InventoryFact 'Collection status' 'Partial inventory; remaining data is Unknown/unavailable. See issues.'))
}

$cpuNames = @($cpu | Where-Object { $null -ne $_ } | ForEach-Object { $_.Name }) -join '; '
$gpuNames = @($gpus | Where-Object { $null -ne $_ } | ForEach-Object { $_.Name }) -join '; '
$result = [pscustomobject]@{
    capturedAt = $now.ToString('o')
    summary = [pscustomobject]@{
        cpu = [string](Format-InventoryText $cpuNames)
        ram = [string](Format-InventoryBytes $computer.TotalPhysicalMemory)
        gpu = [string](Format-InventoryText $gpuNames)
        os = [string](Format-InventoryText $os.Caption)
        machine = [string]('{0} / {1}' -f (Format-InventoryText $computer.Manufacturer), (Format-InventoryText $computer.Model))
    }
    sections = @($script:InventorySections.ToArray())
    recommendations = @(Get-SystemRecommendations -Facts $observed -Now $now)
    issues = @($script:InventoryIssues.ToArray())
}
$result | ConvertTo-Json -Depth 10 -Compress
