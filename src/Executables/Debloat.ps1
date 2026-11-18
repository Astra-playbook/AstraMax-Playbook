#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Light', 'Moderate', 'Extreme', 'Insane', 'Status')]
    [string]$Level = 'Status',
    [switch]$Restore,
    [switch]$Services,
    [switch]$Report
)

$ErrorActionPreference = 'SilentlyContinue'
$logDir = 'C:\AstraMax\Debloat'
$logFile = Join-Path $logDir 'removed.json'
$reportFile = Join-Path $logDir 'debloat-report.txt'
$serviceStateFile = Join-Path $logDir 'service-state.json'
$userServiceStateFile = Join-Path $logDir 'user-service-state.json'
$kernelStateFile = Join-Path $logDir 'kernel-state.json'
$featureStateFile = Join-Path $logDir 'feature-state.json'
$svcHostKey = 'HKLM:\SYSTEM\CurrentControlSet\Control'
$svcHostValue = 'SvcHostSplitThresholdInKB'
$svcHostGrouped = [uint32]4294967295

# Per-user services run one instance per signed-in user (<Name>_<LUID>), so a
# name-based Set-Service cannot disable them. The template Start value below
# the service key is what Windows copies for each new instance.
$userServiceTemplates = @(
    'CDPUserSvc'
    'OneSyncSvc'
    'UserDataSvc'
    'UnistoreSvc'
    'PimIndexMaintenanceSvc'
    'WpnUserService'
    'BcastDVRUserService'
    'PrintWorkflowUserSvc'
    'PenService'
    'NPSMSvc'
)

# Cache and report folders written by services the tiers disable. Only data Windows
# rebuilds is listed: the service keys and startup snapshots stay so -Restore works.
$serviceTraces = [ordered]@{
    'MapsBroker'     = @('C:\ProgramData\Microsoft\MapData')
    'DiagTrack'      = @('C:\ProgramData\Microsoft\Diagnosis')
    'WerSvc'         = @(
        'C:\ProgramData\Microsoft\Windows\WER\ReportQueue'
        'C:\ProgramData\Microsoft\Windows\WER\ReportArchive'
        'C:\ProgramData\Microsoft\Windows\WER\Temp'
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\WER')
    )
    'whesvc'         = @(
        'C:\ProgramData\Microsoft\Windows\WER\ReportQueue'
        'C:\ProgramData\Microsoft\Windows\WER\ReportArchive'
    )
    'WSearch'        = @('C:\ProgramData\Microsoft\Search\Data')
    'WdiServiceHost' = @('C:\ProgramData\Microsoft\Windows\WDI')
    'WdiSystemHost'  = @('C:\ProgramData\Microsoft\Windows\WDI')
    'wuauserv'       = @('C:\Windows\SoftwareDistribution\Download')
    'BITS'           = @(
        'C:\Windows\SoftwareDistribution\Download'
        'C:\ProgramData\Microsoft\Network\Downloader'
    )
    'DoSvc'          = @('C:\Windows\SoftwareDistribution\Download')
    'UsoSvc'         = @('C:\Windows\SoftwareDistribution\Download')
    'Spooler'        = @('C:\Windows\System32\spool\PRINTERS')
    'WpnService'     = @((Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Notifications'))
}

# Cumulative tiers. Insane includes Extreme, Extreme includes Moderate, Moderate includes Light.
$tiers = [ordered]@{
    Light    = @(
        'Clipchamp.Clipchamp'
        'Microsoft.BingNews'
        'Microsoft.BingWeather'
        'Microsoft.BingSearch'
        'Microsoft.Getstarted'
        'Microsoft.MicrosoftSolitaireCollection'
        'Microsoft.People'
    )
    Moderate = @(
        'Microsoft.549981C3F5F10'
        'Microsoft.MicrosoftOfficeHub'
        'Microsoft.MixedReality.Portal'
        'Microsoft.3DViewer'
        'Microsoft.Microsoft3DViewer'
        'Microsoft.Print3D'
        'MicrosoftCorporationII.MicrosoftFamily'
        'Microsoft.MSPaint'
        'Microsoft.WindowsAlarms'
        'Microsoft.WindowsMaps'
        'Microsoft.ZuneMusic'
        'Microsoft.ZuneVideo'
        'Microsoft.YourPhone'
        'Microsoft.CrossDevice'
        'MicrosoftTeams'
        'MSTeams'
        'Microsoft.PowerAutomateDesktop'
        'Microsoft.WindowsSoundRecorder'
        'microsoft.windowscommunicationsapps'
        'Microsoft.Todos'
        'Microsoft.SkypeApp'
        'Microsoft.WindowsFeedbackHub'
    )
    Extreme  = @(
        'Microsoft.WindowsStore'
        'Microsoft.StorePurchaseApp'
        'Microsoft.XboxApp'
        'Microsoft.GamingApp'
        'Microsoft.XboxGamingOverlay'
        'Microsoft.Photos'
        'Microsoft.Windows.Photos'
        'Microsoft.Camera'
        'Microsoft.WindowsCamera'
        'Microsoft.OutlookForWindows'
        'Microsoft.Windows.DevHome'
        'Microsoft.Copilot'
        'Microsoft.Windows.Copilot'
        'Microsoft.Windows.Ai.Copilot.Provider'
    )
    # Insane is the gaming strip. It removes the last Microsoft apps people often keep
    # (Calculator, Notepad, Snipping Tool, Paint, Sticky Notes, Get Help, OneNote, Wallet,
    # Xbox speech overlay) plus the remaining consumer platforms and tools: Widgets,
    # Quick Assist, Journal, Whiteboard, Mobile Plans and the RAW image extension.
    # Edge, WebView2, media codecs, DirectX, VC++ and the Xbox identity/Game Services
    # runtimes stay because game launchers and titles depend on them.
    Insane   = @(
        'Microsoft.WindowsCalculator'
        'Microsoft.WindowsNotepad'
        'Microsoft.ScreenSketch'
        'Microsoft.Paint'
        'Microsoft.MicrosoftStickyNotes'
        'Microsoft.GetHelp'
        'Microsoft.Office.OneNote'
        'Microsoft.Wallet'
        'Microsoft.XboxSpeechToTextOverlay'
        'MicrosoftWindows.Client.WebExperience'
        'Microsoft.WidgetsPlatformRuntime'
        'MicrosoftCorporationII.QuickAssist'
        'Microsoft.MicrosoftJournal'
        'Microsoft.Whiteboard'
        'Microsoft.OneConnect'
        'Microsoft.RawImageExtension'
    )
}

# Insane also removes non-gaming Windows optional features. States are snapshotted
# before the first change; -Restore re-enables exactly what was enabled. Reboot may be required.
$insaneFeatures = @(
    'WorkFolders-Client'
    'FaxServicesClientPackage'
    'Printing-XPSServices-Features'
    'Printing-Foundation-LPDPrintService'
    'Printing-Foundation-LPRPortMonitor'
    'Printing-Foundation-InternetPrinting-Client'
    'SimpleTCP'
    'TelnetClient'
    'TFTP-Client'
    'SNMP'
    'WMISnmpProvider'
    'ServicesForNFS-ClientOnly'
    'ClientForNFS-Infrastructure'
    'NFS-Administration'
    'MSRDC-Infrastructure'
    'DirectoryServices-ADAM-Client'
    'Microsoft-RemoteDesktopConnection'
    'SMB1Protocol'
    'WindowsMediaPlayer'
)

# Service tiers for the Services page (-Services). Cumulative, like the app tiers.
# Extreme stops search indexing, printing, notifications and Store delivery: the Caution tier.
# Insane additionally disables Windows Update, RDP host, Xbox/Game Pass, biometrics,
# camera frame server, smart cards, diagnostics, UPnP discovery, VPN dialing, update
# orchestration, time sync, Security Center, hardware error reporting, storage settings,
# proxy discovery, IP Helper, file sharing and the remaining UWP brokers. It also disables
# the per-user service templates and raises SvcHostSplitThresholdInKB so Windows merges
# service hosts after a reboot. Startup types are snapshotted; -Restore puts them back.
$svcTiers = [ordered]@{
    Light    = @(
        'MapsBroker'
        'Fax'
        'WMPNetworkSvc'
        'RetailDemo'
        'PhoneSvc'
        'RemoteRegistry'
        'RemoteAccess'
        'dmwappushservice'
    )
    Moderate = @(
        'DiagTrack'
        'SysMain'
        'WerSvc'
        'wisvc'
        'lfsvc'
    )
    Extreme  = @(
        'WSearch'
        'Spooler'
        'DoSvc'
        'WpnService'
        'WinRM'
        'SharedAccess'
    )
    Insane   = @(
        'wuauserv'
        'BITS'
        'DPS'
        'WdiServiceHost'
        'WdiSystemHost'
        'PcaSvc'
        'Wecsvc'
        'pla'
        'TabletInputService'
        'WbioSrvc'
        'FrameServer'
        'WalletService'
        'WpcMonSvc'
        'NaturalAuthentication'
        'SCardSvr'
        'ScDeviceEnum'
        'CertPropSvc'
        'lmhosts'
        'TermService'
        'UmRdpService'
        'SessionEnv'
        'XblAuthManager'
        'XblGameSave'
        'XboxGipSvc'
        'XboxNetApiSvc'
        'UsoSvc'
        'CDPSvc'
        'NcbService'
        'SSDPSRV'
        'SstpSvc'
        'RasMan'
        'TimeBrokerSvc'
        'GraphicsPerfSvc'
        'InventorySvc'
        'WSAIFabricSvc'
        'stisvc'
        'seclogon'
        'w32time'
        'wscsvc'
        'whesvc'
        'StorSvc'
        'WinHttpAutoProxySvc'
        'iphlpsvc'
        'LanmanServer'
    )
}

# Never touched, even if a tier pattern would match one by accident.
$protected = @(
    'Microsoft.DesktopAppInstaller'
    'Microsoft.Winget.Source'
    'Microsoft.VCLibs*'
    'Microsoft.UI.Xaml*'
    'Microsoft.WindowsAppRuntime*'
    'Microsoft.NET.Native*'
    'Microsoft.Services.Store.Engagement'
    'Microsoft.Windows.ShellExperienceHost'
    'Microsoft.Windows.StartMenuExperienceHost'
    'Microsoft.Windows.Search'
    'Microsoft.SecHealthUI'
    'Microsoft.GamingServices'
    'Microsoft.XboxIdentityProvider'
    'Microsoft.Xbox.TCUI'
    'Microsoft.WindowsTerminal'
    # The Control Panel is a Store app; keep every NVIDIA package so a driver
    # update or NVIDIA App install can never be treated as debloat.
    '*NVIDIA*'
)

# Services the engine refuses to disable, even if a tier list changes by accident.
$protectedServices = @(
    'RpcSs'
    'DcomLaunch'
    'RpcEptMapper'
    'LSARpc'
    'SamSs'
    'EventLog'
    'PlugPlay'
    'Power'
    'ProfSvc'
    'UserManager'
    'StateRepository'
    'SystemEventsBroker'
    'Winmgmt'
    'CryptSvc'
    'TrustedInstaller'
    'msiserver'
    'AppXSvc'
    'ClipSVC'
    'BrokerInfrastructure'
    'gpsvc'
    'KeyIso'
    'VaultSvc'
    'Nsi'
    'netprofm'
    'Dnscache'
    'Dhcp'
    'NlaSvc'
    'netman'
    'Audiosrv'
    'AudioEndpointBuilder'
    'Themes'
    'UxSms'
    'WlanSvc'
    'BFE'
    'MpsSvc'
    'DsmSvc'
    'DeviceInstall'
    'DeviceAssociationService'
    'SENS'
    'Schedule'
    'NVDisplay.ContainerLocalSystem'
    'NvContainerLocalSystem'
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$messages = New-Object System.Collections.Generic.List[string]
$counts = [ordered]@{}

function Say {
    param([string]$Text)
    $messages.Add($Text)
    Write-Host $Text
}

function Get-TierApps {
    param([string]$Name)
    $apps = @()
    foreach ($tier in $tiers.Keys) {
        $apps += $tiers[$tier]
        if ($tier -eq $Name) { break }
    }
    $apps | Select-Object -Unique
}

function Get-TierServices {
    param([string]$Name)
    $list = @()
    foreach ($tier in $svcTiers.Keys) {
        $list += $svcTiers[$tier]
        if ($tier -eq $Name) { break }
    }
    $list | Select-Object -Unique
}

function Test-Protected {
    param([string]$Name)
    foreach ($pattern in $protected) {
        if ($Name -like $pattern) { return $true }
    }
    return $false
}

function Test-ProtectedService {
    param([string]$Name)
    return ($protectedServices -contains $Name)
}

function Read-ServiceState {
    if (-not (Test-Path -LiteralPath $serviceStateFile)) { return [ordered]@{} }
    try {
        $loaded = Get-Content -LiteralPath $serviceStateFile -Raw | ConvertFrom-Json
        $state = [ordered]@{}
        foreach ($prop in $loaded.PSObject.Properties) { $state[$prop.Name] = $prop.Value }
        return $state
    }
    catch {
        Say 'services: snapshot unreadable; a new snapshot is written from current values'
        return [ordered]@{}
    }
}

function Save-ServiceState {
    param([string]$Name)
    $state = Read-ServiceState
    if ($state.Contains($Name)) { return }
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) { return }
    $key = Join-Path 'HKLM:\SYSTEM\CurrentControlSet\Services' $Name
    $start = (Get-ItemProperty -Path $key -Name 'Start' -ErrorAction SilentlyContinue).Start
    if ($null -eq $start) { return }
    $delayed = (Get-ItemProperty -Path $key -Name 'DelayedAutostart' -ErrorAction SilentlyContinue).DelayedAutostart
    $state[$Name] = [pscustomobject]@{
        Start   = [int]$start
        Delayed = if ($null -ne $delayed) { [int]$delayed } else { 0 }
        Running = ($svc.Status -eq 'Running')
    }
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    ($state | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $serviceStateFile -Encoding UTF8
}

function Get-ServiceStartupType {
    param([int]$Start, [int]$Delayed = 0)
    switch ($Start) {
        2 { if ($Delayed -eq 1) { 'AutomaticDelayedStart' } else { 'Automatic' } }
        3 { 'Manual' }
        4 { 'Disabled' }
        default { $null }
    }
}

function Restore-ServiceState {
    $state = Read-ServiceState
    if ($state.Count -eq 0) {
        Say 'services: no Astra service snapshot found; startup types are unchanged'
        return
    }
    $failed = 0
    foreach ($name in @($state.Keys)) {
        $entry = $state[$name]
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        if (-not $svc) { Say "service: $name is not installed; skipped"; continue }
        $type = Get-ServiceStartupType -Start ([int]$entry.Start) -Delayed ([int]$entry.Delayed)
        if (-not $type) { Say "service: $name has unsupported Start=$($entry.Start); left unchanged"; continue }
        try {
            Set-Service -Name $name -StartupType $type -ErrorAction Stop
            if ($entry.Running) { Start-Service -Name $name -ErrorAction SilentlyContinue }
            Say "service: $name -> $type (restored)"
        }
        catch {
            $failed++
            Say "service: $name could not be restored"
        }
    }
    if ($failed -eq 0) {
        Remove-Item -LiteralPath $serviceStateFile -Force -ErrorAction SilentlyContinue
        Say 'services: snapshot restored exactly and cleared'
    }
    else {
        Say "services: $failed service(s) need attention; snapshot kept at $serviceStateFile"
    }
}

function Read-UserServiceState {
    if (-not (Test-Path -LiteralPath $userServiceStateFile)) { return [ordered]@{} }
    try {
        $loaded = Get-Content -LiteralPath $userServiceStateFile -Raw | ConvertFrom-Json
        $state = [ordered]@{}
        foreach ($prop in $loaded.PSObject.Properties) { $state[$prop.Name] = $prop.Value }
        return $state
    }
    catch {
        Say 'user services: snapshot unreadable; a new snapshot is written from current values'
        return [ordered]@{}
    }
}

function Save-UserServiceState {
    param([string]$Name, [int]$Start)
    $state = Read-UserServiceState
    if ($state.Contains($Name)) { return }
    $state[$Name] = [pscustomobject]@{ Start = $Start }
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    ($state | ConvertTo-Json -Depth 3) | Set-Content -LiteralPath $userServiceStateFile -Encoding UTF8
}

function Set-AstraUserServiceState {
    param([string]$Name)
    $key = Join-Path 'HKLM:\SYSTEM\CurrentControlSet\Services' $Name
    $current = (Get-ItemProperty -Path $key -Name 'Start' -ErrorAction SilentlyContinue).Start
    if ($null -eq $current -or [int]$current -eq 4) { return }
    Save-UserServiceState -Name $Name -Start ([int]$current)
    try {
        Set-ItemProperty -Path $key -Name 'Start' -Value 4 -Type DWord -ErrorAction Stop
        Get-Service -Name "$Name*" -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue
        Add-Record -Name $Name -FullName $key -Kind 'user-service-off'
        Say "user service: $Name -> disabled (sign out to stop every instance)"
    }
    catch {
        Say "user service: $Name unchanged"
    }
}

function Restore-UserServiceState {
    $state = Read-UserServiceState
    if ($state.Count -eq 0) {
        Say 'user services: no Astra user-service snapshot found; templates are unchanged'
        return
    }
    $failed = 0
    foreach ($name in @($state.Keys)) {
        $key = Join-Path 'HKLM:\SYSTEM\CurrentControlSet\Services' $name
        if (-not (Test-Path -LiteralPath $key)) { Say "user service: $name is not installed; skipped"; continue }
        try {
            Set-ItemProperty -Path $key -Name 'Start' -Value ([int]$state[$name].Start) -Type DWord -ErrorAction Stop
            Say "user service: $name -> Start=$([int]$state[$name].Start) (restored)"
        }
        catch {
            $failed++
            Say "user service: $name could not be restored"
        }
    }
    if ($failed -eq 0) {
        Remove-Item -LiteralPath $userServiceStateFile -Force -ErrorAction SilentlyContinue
        Say 'user services: templates restored; sign out and back in to start them again'
    }
    else {
        Say "user services: $failed template(s) need attention; snapshot kept at $userServiceStateFile"
    }
}

function Get-AstraStaleUserServiceInstances {
    param([string]$RootKey = 'HKLM:\SYSTEM\CurrentControlSet\Services')
    $stale = New-Object System.Collections.Generic.List[object]
    foreach ($template in $userServiceTemplates) {
        $pattern = '^' + [regex]::Escape($template) + '_[0-9A-Fa-f]+$'
        foreach ($child in @(Get-ChildItem -LiteralPath $RootKey -ErrorAction SilentlyContinue)) {
            if ($child.PSChildName -notmatch $pattern) { continue }
            # A key the service controller still knows belongs to a signed-in user;
            # Windows deletes it at sign-out, so never touch a live instance.
            if (Get-Service -Name $child.PSChildName -ErrorAction SilentlyContinue) { continue }
            $stale.Add([pscustomobject]@{ Name = $child.PSChildName; Template = $template; Key = $child.PSPath; Display = $child.Name })
        }
    }
    return @($stale | Sort-Object Name -Unique)
}

function Remove-AstraServiceTrace {
    param([string]$Name, [string[]]$Paths)
    if (-not $PSBoundParameters.ContainsKey('Paths')) {
        if (-not $serviceTraces.Contains($Name)) { return 0 }
        $Paths = @($serviceTraces[$Name])
    }
    # Never delete data for a service that is still enabled.
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($svc -and $svc.StartType -ne 'Disabled') { return 0 }
    $removed = 0
    foreach ($path in @($Paths | Where-Object { $_ } | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        try {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
            $removed++
            Add-Record -Name $Name -FullName $path -Kind 'service-data'
            Say "trace: removed service data $path"
        }
        catch {
            Say "trace: could not remove service data $path"
        }
    }
    return $removed
}

function Remove-AstraStaleUserServiceInstances {
    param([string]$RootKey = 'HKLM:\SYSTEM\CurrentControlSet\Services')
    $removed = 0
    foreach ($instance in @(Get-AstraStaleUserServiceInstances -RootKey $RootKey)) {
        try {
            Remove-Item -LiteralPath $instance.Key -Recurse -Force -ErrorAction Stop
            $removed++
            Add-Record -Name $instance.Name -FullName $instance.Display -Kind 'user-service-stale'
            Say "trace: removed stale user-service key $($instance.Name)"
        }
        catch {
            Say "trace: could not remove stale user-service key $($instance.Name)"
        }
    }
    return $removed
}

function Read-KernelState {
    if (-not (Test-Path -LiteralPath $kernelStateFile)) { return [ordered]@{} }
    try {
        $loaded = Get-Content -LiteralPath $kernelStateFile -Raw | ConvertFrom-Json
        $state = [ordered]@{}
        foreach ($prop in $loaded.PSObject.Properties) { $state[$prop.Name] = $prop.Value }
        return $state
    }
    catch {
        Say 'kernel: snapshot unreadable; a new snapshot is written from current values'
        return [ordered]@{}
    }
}

function Save-KernelState {
    param([bool]$Present, [uint32]$Value)
    $state = Read-KernelState
    if ($state.Contains($svcHostValue)) { return }
    $state[$svcHostValue] = [pscustomobject]@{ Present = $Present; Value = $Value }
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    ($state | ConvertTo-Json -Depth 3) | Set-Content -LiteralPath $kernelStateFile -Encoding UTF8
}

function Set-SvcHostGrouping {
    $key = Get-ItemProperty -Path $svcHostKey -Name $svcHostValue -ErrorAction SilentlyContinue
    $present = $null -ne $key
    if ($present -and [uint32]$key.$svcHostValue -eq $svcHostGrouped) {
        Say 'kernel: service hosts already grouped'
        return
    }
    Save-KernelState -Present $present -Value $(if ($present) { [uint32]$key.$svcHostValue } else { [uint32]0 })
    try {
        Set-ItemProperty -Path $svcHostKey -Name $svcHostValue -Value $svcHostGrouped -Type DWord -ErrorAction Stop
        Add-Record -Name $svcHostValue -FullName (Join-Path $svcHostKey $svcHostValue) -Kind 'kernel-on'
        Say 'kernel: service host split threshold at maximum; reboot merges service hosts'
    }
    catch {
        Say 'kernel: service host grouping could not be changed'
    }
}

function Restore-KernelState {
    $state = Read-KernelState
    if ($state.Count -eq 0) {
        Say 'kernel: no Astra kernel snapshot found; service host grouping is unchanged'
        return
    }
    foreach ($name in @($state.Keys)) {
        try {
            if ($state[$name].Present) {
                Set-ItemProperty -Path $svcHostKey -Name $name -Value ([uint32]$state[$name].Value) -Type DWord -ErrorAction Stop
                Say "kernel: $name -> $([uint32]$state[$name].Value) (restored)"
            }
            else {
                Remove-ItemProperty -Path $svcHostKey -Name $name -ErrorAction SilentlyContinue
                Say "kernel: $name removed (restored to Windows default)"
            }
        }
        catch {
            Say "kernel: $name could not be restored"
        }
    }
    Remove-Item -LiteralPath $kernelStateFile -Force -ErrorAction SilentlyContinue
    Say 'kernel: reboot to apply the restored service host grouping'
}

function Read-FeatureState {
    if (-not (Test-Path -LiteralPath $featureStateFile)) { return [ordered]@{} }
    try {
        $loaded = Get-Content -LiteralPath $featureStateFile -Raw | ConvertFrom-Json
        $state = [ordered]@{}
        foreach ($prop in $loaded.PSObject.Properties) { $state[$prop.Name] = $prop.Value }
        return $state
    }
    catch {
        Say 'features: snapshot unreadable; a new snapshot is written from current values'
        return [ordered]@{}
    }
}

function Save-FeatureState {
    param([string]$Name, [string]$State)
    $snapshot = Read-FeatureState
    if ($snapshot.Contains($Name)) { return }
    $snapshot[$Name] = $State
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    ($snapshot | ConvertTo-Json -Depth 3) | Set-Content -LiteralPath $featureStateFile -Encoding UTF8
}

function Restore-FeatureState {
    $snapshot = Read-FeatureState
    if ($snapshot.Count -eq 0) {
        Say 'features: no Astra feature snapshot found; optional features are unchanged'
        return
    }
    $failed = 0
    foreach ($name in @($snapshot.Keys)) {
        if ([string]$snapshot[$name] -ne 'Enabled') { continue }
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName $name -All -NoRestart -ErrorAction Stop | Out-Null
            Say "feature: $name enabled (restored; reboot may be required)"
        }
        catch {
            $failed++
            Say "feature: $name could not be restored"
        }
    }
    if ($failed -eq 0) {
        Remove-Item -LiteralPath $featureStateFile -Force -ErrorAction SilentlyContinue
        Say 'features: snapshot restored and cleared'
    }
    else {
        Say "features: $failed feature(s) need attention; snapshot kept at $featureStateFile"
    }
}

function Disable-AstraFeature {
    param([string]$Name)
    $feature = Get-WindowsOptionalFeature -Online -FeatureName $Name -ErrorAction SilentlyContinue
    if (-not $feature) { Say "feature: $Name is not present; skipped"; return }
    if ($feature.State -ne 'Enabled') { return }
    Save-FeatureState $Name 'Enabled'
    try {
        Disable-WindowsOptionalFeature -Online -FeatureName $Name -NoRestart -ErrorAction Stop | Out-Null
        Add-Record -Name $Name -FullName "OptionalFeature:$Name" -Kind 'feature-off'
        Say "feature: $Name disabled (reboot may be required)"
    }
    catch {
        Say "feature: $Name could not be disabled"
    }
}

function Add-Record {
    param([string]$Name, [string]$FullName, [string]$Kind)
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $records = @()
    if (Test-Path -LiteralPath $logFile) {
        try { $records = @(Get-Content -LiteralPath $logFile -Raw | ConvertFrom-Json) } catch { $records = @() }
    }
    $records += [pscustomobject]@{
        Time     = (Get-Date).ToString('s')
        Level    = $Level
        Kind     = $Kind
        Name     = $Name
        FullName = $FullName
    }
    ($records | ConvertTo-Json -Depth 3) | Set-Content -LiteralPath $logFile -Encoding UTF8
}

function Get-AstraPackageDataDirs {
    param([string]$Pattern)

    $roots = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    $local = Join-Path $env:LOCALAPPDATA 'Packages'
    if ($env:LOCALAPPDATA -and -not $seen.ContainsKey($local.ToLower())) {
        $seen[$local.ToLower()] = $true
        $roots.Add([pscustomobject]@{ Path = $local; CurrentUser = $true })
    }
    foreach ($profile in @(Get-ChildItem -LiteralPath 'C:\Users' -Directory -ErrorAction SilentlyContinue)) {
        $path = Join-Path $profile.FullName 'AppData\Local\Packages'
        if ($seen.ContainsKey($path.ToLower())) { continue }
        $seen[$path.ToLower()] = $true
        $roots.Add([pscustomobject]@{ Path = $path; CurrentUser = $false })
    }
    if (-not $seen.ContainsKey('c:\programdata\packages')) {
        $roots.Add([pscustomobject]@{ Path = 'C:\ProgramData\Packages'; CurrentUser = $false })
    }

    $dirs = New-Object System.Collections.Generic.List[object]
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root.Path)) { continue }
        foreach ($dir in @(Get-ChildItem -LiteralPath $root.Path -Directory -ErrorAction SilentlyContinue)) {
            # Package family names are <PackageName>_<PublisherId>, so the folder
            # still belongs to this pattern even when the package is already gone.
            $base = $dir.Name -replace '_[^_]+$', ''
            if ($base -notlike $Pattern) { continue }
            if (Test-Protected $base) { continue }
            $dirs.Add([pscustomobject]@{
                Path        = $dir.FullName
                Name        = $dir.Name
                Base        = $base
                CurrentUser = $root.CurrentUser
            })
        }
    }
    return @($dirs | Sort-Object Path -Unique)
}

function Test-AstraPackageRemaining {
    param([string]$Family, [switch]$AllUsers)
    if ($AllUsers) {
        return (@(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.PackageFamilyName -eq $Family }).Count -gt 0)
    }
    return (@(Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.PackageFamilyName -eq $Family }).Count -gt 0)
}

function Remove-AstraPackageData {
    param([string]$Pattern)
    $removed = 0
    foreach ($dir in @(Get-AstraPackageDataDirs -Pattern $Pattern)) {
        if ($dir.CurrentUser) {
            if (Test-AstraPackageRemaining -Family $dir.Name) { continue }
        }
        else {
            if (-not $isAdmin) { continue }
            if (Test-AstraPackageRemaining -Family $dir.Name -AllUsers) { continue }
        }
        try {
            Remove-Item -LiteralPath $dir.Path -Recurse -Force -ErrorAction Stop
            $removed++
            Add-Record -Name $dir.Base -FullName $dir.Name -Kind 'data'
            Say "trace: removed data $($dir.Name)"
        }
        catch {
            Say "trace: could not remove data $($dir.Name)"
        }
    }
    return $removed
}

function Remove-AstraAppRegistryTrace {
    param([string[]]$FullNames, [string[]]$Families)
    $removed = 0
    $current = @(Get-AppxPackage -ErrorAction SilentlyContinue)
    $repoRoot = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages'
    foreach ($full in @($FullNames | Where-Object { $_ } | Select-Object -Unique)) {
        if (@($current | Where-Object { $_.PackageFullName -eq $full }).Count -gt 0) { continue }
        $key = Join-Path $repoRoot $full
        if (-not (Test-Path -LiteralPath $key)) { continue }
        try {
            Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction Stop
            $removed++
            Add-Record -Name $full -FullName $full -Kind 'registry'
            Say "trace: removed registry $full"
        }
        catch {
            Say "trace: could not remove registry $full"
        }
    }
    $systemRoot = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData'
    foreach ($family in @($Families | Where-Object { $_ } | Select-Object -Unique)) {
        if (@($current | Where-Object { $_.PackageFamilyName -eq $family }).Count -gt 0) { continue }
        $key = Join-Path $systemRoot $family
        if (-not (Test-Path -LiteralPath $key)) { continue }
        try {
            Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction Stop
            $removed++
            Add-Record -Name $family -FullName $family -Kind 'registry'
            Say "trace: removed registry $family"
        }
        catch {
            Say "trace: could not remove registry $family"
        }
    }
    return $removed
}

function Remove-AstraApp {
    param([string]$Pattern)
    if (Test-Protected $Pattern) {
        Say "app: skipped protected $Pattern"
        return [pscustomobject]@{ Packages = 0; Data = 0; Registry = 0 }
    }
    $removed = 0
    $families = New-Object System.Collections.Generic.List[string]
    $fullNames = New-Object System.Collections.Generic.List[string]

    foreach ($pkg in @(Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $Pattern })) {
        if ($pkg.PackageFamilyName) { $families.Add($pkg.PackageFamilyName) }
        if ($pkg.PackageFullName) { $fullNames.Add($pkg.PackageFullName) }
        try {
            Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
            $removed++
            Add-Record -Name $pkg.Name -FullName $pkg.PackageFullName -Kind 'user'
            Say "app: removed $($pkg.Name) (current user)"
        }
        catch {
            Say "app: could not remove $($pkg.Name) (current user)"
        }
    }

    if ($isAdmin) {
        foreach ($pkg in @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $Pattern })) {
            if ($pkg.PackageFamilyName) { $families.Add($pkg.PackageFamilyName) }
            if ($pkg.PackageFullName) { $fullNames.Add($pkg.PackageFullName) }
            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                $removed++
                Add-Record -Name $pkg.Name -FullName $pkg.PackageFullName -Kind 'all-users'
                Say "app: removed $($pkg.Name) (all users)"
            }
            catch {
                Say "app: could not remove $($pkg.Name) (all users)"
            }
        }

        foreach ($prov in @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $Pattern })) {
            if ($prov.PackageName) { $fullNames.Add($prov.PackageName) }
            try {
                Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction Stop | Out-Null
                $removed++
                Add-Record -Name $prov.DisplayName -FullName $prov.PackageName -Kind 'provisioned'
                Say "app: removed $($prov.DisplayName) (provisioned)"
            }
            catch {
                Say "app: could not remove $($prov.DisplayName) (provisioned)"
            }
        }
    }

    $data = Remove-AstraPackageData -Pattern $Pattern
    $registry = Remove-AstraAppRegistryTrace -FullNames $fullNames.ToArray() -Families $families.ToArray()
    return [pscustomobject]@{ Packages = $removed; Data = $data; Registry = $registry }
}

function Set-AstraServiceState {
    param([string]$Name, [string]$State)
    if (Test-ProtectedService $Name) {
        Say "service: skipped protected $Name"
        return
    }
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) { return }
    try {
        if ($State -eq 'Off') {
            Save-ServiceState $Name
            Set-Service -Name $Name -StartupType Disabled -ErrorAction Stop
            Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
            Add-Record -Name $Name -FullName (Join-Path 'HKLM:\SYSTEM\CurrentControlSet\Services' $Name) -Kind 'service-off'
            Say "service: $Name -> disabled"
        }
        else {
            Set-Service -Name $Name -StartupType Automatic -ErrorAction Stop
            Start-Service -Name $Name -ErrorAction SilentlyContinue
            Add-Record -Name $Name -FullName (Join-Path 'HKLM:\SYSTEM\CurrentControlSet\Services' $Name) -Kind 'service-on'
            Say "service: $Name -> automatic"
        }
    }
    catch {
        Say "service: $Name unchanged"
    }
}

function Remove-OneDrive {
    $setup = Join-Path $env:SystemRoot 'System32\OneDriveSetup.exe'
    $removed = 0
    if (Test-Path -LiteralPath $setup) {
        Get-Process -Name OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        try {
            Start-Process -FilePath $setup -ArgumentList '/uninstall' -Wait -ErrorAction Stop
            Add-Record -Name 'OneDrive' -FullName $setup -Kind 'app-off'
            Say 'onedrive: uninstalled (reinstall from microsoft.com/onedrive)'
        }
        catch {
            Say 'onedrive: uninstaller could not run'
        }
    }
    else {
        Say 'onedrive: setup not found, cleaning leftovers only'
    }

    # Install data and app settings only. The user's synced files in
    # %USERPROFILE%\OneDrive are deliberately never touched.
    $paths = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\OneDrive')
        'C:\ProgramData\Microsoft\OneDrive'
    )
    if ($env:ProgramFiles) { $paths += (Join-Path $env:ProgramFiles 'Microsoft OneDrive') }
    if (${env:ProgramFiles(x86)}) { $paths += (Join-Path ${env:ProgramFiles(x86)} 'Microsoft OneDrive') }
    foreach ($path in @($paths | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        try {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
            $removed++
            Add-Record -Name 'OneDrive' -FullName $path -Kind 'data'
            Say "onedrive: removed data $path"
        }
        catch {
            Say "onedrive: could not remove $path"
        }
    }

    foreach ($key in 'HKCU:\Software\Microsoft\OneDrive', 'HKLM:\SOFTWARE\Microsoft\OneDrive', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\OneDrive') {
        if (-not (Test-Path -LiteralPath $key)) { continue }
        try {
            Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction Stop
            $removed++
            Add-Record -Name 'OneDrive' -FullName $key -Kind 'registry'
            Say "onedrive: removed registry $key"
        }
        catch {
            Say "onedrive: could not remove registry $key"
        }
    }

    if ($removed -gt 0) {
        Say 'onedrive: app data and settings removed; personal files under the OneDrive folder were not touched'
    }
    return $removed
}

function Write-Report {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $lines = @(
        'Astra debloat report'
        "level: $Level"
        "admin: $isAdmin"
        "time: $((Get-Date).ToString('s'))"
        ''
    )
    foreach ($key in $counts.Keys) { $lines += "$key : $($counts[$key]) removed" }
    $lines += ''
    $lines += $messages
    $lines | Set-Content -LiteralPath $reportFile -Encoding UTF8
    Say "report: $reportFile"
}

if ($Restore) {
    Say 'debloat: restoring service startup types and optional features from the Astra snapshot'
    if (-not $isAdmin) { Say 'restore needs an elevated session, nothing changed'; return }
    Restore-ServiceState
    Restore-UserServiceState
    Restore-FeatureState
    Restore-KernelState
    if (Test-Path -LiteralPath $logFile) {
        try {
            $records = @(Get-Content -LiteralPath $logFile -Raw | ConvertFrom-Json)
            Say "removed earlier: $($records.Count) entries"
            $records | Group-Object Name | Sort-Object Name | ForEach-Object { Say "  $($_.Name) ($($_.Count))" }
        }
        catch { Say 'removed log unreadable' }
    }
    Say 'Apps are not reinstalled by this command.'
    Say 'Package data folders and per-user AppModel registry entries removed by debloat are not restored; reinstall the app to recreate them.'
    Say 'Microsoft Store: run "wsreset -i" in an elevated terminal to reinstall it.'
    Say 'Other apps: reinstall from the Store or winget once the Store is back.'
    Say 'OneDrive: download the installer from microsoft.com/onedrive.'
    Say 'Restart Windows to apply restored service startup types and optional features.'
    Say 'Service cache folders removed by the service tier are not restored; Windows rebuilds them when a service runs again.'
    Say 'Stale per-user service keys removed by the service tier are recreated at sign-in once their templates are restored.'
    return
}

if ($Report -and $Services) {
    $services = @(Get-TierServices -Name $Level)
    $off = 0
    foreach ($name in $services) {
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        if ($svc -and $svc.StartType -eq 'Disabled') { $off++ }
    }
    "services tier $Level : $off of $($services.Count) disabled"
    if ($Level -eq 'Insane') {
        $offTemplates = 0
        foreach ($name in $userServiceTemplates) {
            $start = (Get-ItemProperty -Path (Join-Path 'HKLM:\SYSTEM\CurrentControlSet\Services' $name) -Name 'Start' -ErrorAction SilentlyContinue).Start
            if ($start -eq 4) { $offTemplates++ }
        }
        "user services : $offTemplates of $($userServiceTemplates.Count) disabled"
        $hostKey = Get-ItemProperty -Path $svcHostKey -Name $svcHostValue -ErrorAction SilentlyContinue
        $grouped = $hostKey -and [uint32]$hostKey.$svcHostValue -eq $svcHostGrouped
        "service host grouping : $(if ($grouped) { 'on (reboot applies)' } else { 'off' })"
    }
    return
}

if ($Report) {
    $installed = @(Get-AppxPackage -ErrorAction SilentlyContinue)
    $apps = @(Get-TierApps -Name $Level)
    $gone = 0
    foreach ($pattern in $apps) {
        if (-not ($installed | Where-Object { $_.Name -like $pattern })) { $gone++ }
    }
    "tier $Level : $gone of $($apps.Count) apps removed"
    return
}

if ($Level -eq 'Status') {
    Say "debloat status (admin: $isAdmin)"
    foreach ($tier in $tiers.Keys) {
        $present = 0
        foreach ($app in $tiers[$tier]) {
            if (Get-AppxPackage -Name $app -ErrorAction SilentlyContinue) { $present++ }
        }
        Say "tier $tier : $present of $($tiers[$tier].Count) apps present"
    }
    foreach ($tier in $svcTiers.Keys) {
        $off = 0
        foreach ($svc in $svcTiers[$tier]) {
            $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($s -and $s.StartType -eq 'Disabled') { $off++ }
        }
        Say "services $tier : $off of $($svcTiers[$tier].Count) disabled"
    }
    $installed = @(Get-AppxPackage -ErrorAction SilentlyContinue)
    $installedAll = if ($isAdmin) { @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue) } else { $installed }
    $leftover = 0
    foreach ($app in @(Get-TierApps -Name 'Insane')) {
        foreach ($dir in @(Get-AstraPackageDataDirs -Pattern $app)) {
            if (-not $dir.CurrentUser -and -not $isAdmin) { continue }
            $pool = if ($dir.CurrentUser) { $installed } else { $installedAll }
            if (@($pool | Where-Object { $_.PackageFamilyName -eq $dir.Name }).Count -gt 0) { continue }
            $leftover++
        }
    }
    Say "app data leftovers : $leftover folder(s) for tuned apps"
    $offTemplates = 0
    foreach ($name in $userServiceTemplates) {
        $start = (Get-ItemProperty -Path (Join-Path 'HKLM:\SYSTEM\CurrentControlSet\Services' $name) -Name 'Start' -ErrorAction SilentlyContinue).Start
        if ($start -eq 4) { $offTemplates++ }
    }
    Say "user services Insane : $offTemplates of $($userServiceTemplates.Count) templates disabled"
    $svcDataPaths = @()
    foreach ($tier in $svcTiers.Keys) {
        foreach ($svc in $svcTiers[$tier]) {
            $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($s -and $s.StartType -eq 'Disabled') { $svcDataPaths += @($serviceTraces[$svc]) }
        }
    }
    $svcDataLeft = @($svcDataPaths | Where-Object { $_ } | Select-Object -Unique | Where-Object { Test-Path -LiteralPath $_ }).Count
    Say "service data leftovers : $svcDataLeft folder(s) for disabled services"
    Say "stale user-service keys : $(@(Get-AstraStaleUserServiceInstances).Count)"
    $hostKey = Get-ItemProperty -Path $svcHostKey -Name $svcHostValue -ErrorAction SilentlyContinue
    $grouped = $hostKey -and [uint32]$hostKey.$svcHostValue -eq $svcHostGrouped
    Say "service host grouping : $(if ($grouped) { 'on (reboot applies)' } else { 'Windows default' })"
    if ($isAdmin) {
        $offFeatures = 0
        foreach ($name in $insaneFeatures) {
            $f = Get-WindowsOptionalFeature -Online -FeatureName $name -ErrorAction SilentlyContinue
            if ($f -and $f.State -eq 'Disabled') { $offFeatures++ }
        }
        Say "features Insane : $offFeatures of $($insaneFeatures.Count) disabled"
    }
    else { Say 'features Insane : elevation required to inspect' }
    $store = Get-AppxPackage -Name 'Microsoft.WindowsStore' -ErrorAction SilentlyContinue
    Say "store: $(if ($store) { 'present' } else { 'removed' })"
    Say "onedrive: $(if (Test-Path -LiteralPath (Join-Path $env:SystemRoot 'System32\OneDriveSetup.exe')) { 'installer present' } else { 'not present' })"
    return
}

if ($Services) {
    $services = @(Get-TierServices -Name $Level)
    Say "services: $Level tier, $($services.Count) services, admin: $isAdmin"
    if (-not $isAdmin) { Say 'services: needs an elevated session, nothing changed'; return }
    $svcDataTotal = 0
    foreach ($svc in $services) {
        Set-AstraServiceState -Name $svc -State 'Off'
        $svcDataTotal += Remove-AstraServiceTrace -Name $svc
    }
    $staleInstances = 0
    if ($Level -eq 'Extreme') {
        Say 'services: Extreme stops search indexing, the print spooler, notifications, Store delivery, WinRM and ICS'
    }
    if ($Level -eq 'Insane') {
        foreach ($name in $userServiceTemplates) {
            Set-AstraUserServiceState -Name $name
        }
        $staleInstances = Remove-AstraStaleUserServiceInstances
        Set-SvcHostGrouping
        Say 'services: Insane also stops Windows Update, RDP host, Xbox/Game Pass, biometrics, camera, smart cards, diagnostics, UPnP discovery, VPN dialing and update orchestration; per-user templates are disabled and service hosts merge after reboot'
    }
    $counts['services'] = $services.Count
    $counts['service data'] = $svcDataTotal
    if ($svcDataTotal -gt 0) { Say "trace: $svcDataTotal service cache folder(s) removed and recorded" }
    else { Say 'trace: no service cache folders left to remove' }
    if ($Level -eq 'Insane') {
        if ($staleInstances -gt 0) { Say "trace: $staleInstances stale per-user service key(s) removed; live instance keys stay until sign-out" }
        else { Say 'trace: no stale per-user service keys' }
    }
    Write-Report
    return
}

$apps = @(Get-TierApps -Name $Level)
Say "debloat: $Level tier, $($apps.Count) app patterns, admin: $isAdmin"

$removedTotal = 0
$dataTotal = 0
$registryTotal = 0
foreach ($app in $apps) {
    $result = Remove-AstraApp -Pattern $app
    $counts[$app] = $result.Packages
    $removedTotal += $result.Packages
    $dataTotal += $result.Data
    $registryTotal += $result.Registry
}

if ($Level -eq 'Extreme' -or $Level -eq 'Insane') {
    $oneDriveTrace = Remove-OneDrive
    if ($oneDriveTrace -gt 0) { $counts['onedrive'] = $oneDriveTrace }
}

if ($Level -eq 'Insane') {
    if (-not $isAdmin) { Say 'features: Insane feature strip needs an elevated session, nothing changed' }
    else {
        foreach ($name in $insaneFeatures) { Disable-AstraFeature $name }
    }
}

$counts['app data'] = $dataTotal
$counts['app registry'] = $registryTotal
Say "debloat: $removedTotal package entries removed"
if (($dataTotal + $registryTotal) -gt 0) {
    Say "debloat: $dataTotal package data folder(s) and $registryTotal registry key(s) cleaned"
}
else {
    Say 'debloat: no package data or registry leftovers found'
}
Write-Report
