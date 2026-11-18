#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Json,
    [string]$OutFile = 'C:\AstraMax\last-report.json'
)

$ErrorActionPreference = 'SilentlyContinue'
$checks = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param([string]$Name, [string]$Value, [string]$State = 'info', [string]$Detail = '')
    $checks.Add([pscustomobject]@{ Name = $Name; Value = $Value; State = $State; Detail = $Detail })
}

function Get-RegValue {
    param([string]$Path, [string]$Name)
    (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
}

# --- power plan and core parking -------------------------------------------------
$planRaw = (powercfg /getactivescheme) -join ' '
$plan = if ($planRaw -match '\(([^)]+)\)') { $Matches[1] } else { 'unknown' }
$scheme = if ($planRaw -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') { $Matches[1].ToLower() } else { '' }
Add-Check 'Power plan' $plan 'ok'

$parkGuid = '893dee8e-2bef-41e0-89c6-b55d0929964c'
$ac = $null; $dc = $null
foreach ($i in @(Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerSettingDataIndex -ErrorAction SilentlyContinue)) {
    $id = ([string]$i.InstanceID).ToLower()
    if ($id -notmatch [regex]::Escape($parkGuid)) { continue }
    if ($scheme -and $id -notmatch [regex]::Escape($scheme)) { continue }
    if ($id -match '\\ac\\') { $ac = [int]$i.SettingIndexValue }
    elseif ($id -match '\\dc\\') { $dc = [int]$i.SettingIndexValue }
}
if ($null -ne $ac -or $null -ne $dc) {
    $value = 'AC {0}% / DC {1}% minimum cores' -f $ac, $dc
    $state = if (($ac -eq 100) -and ($dc -eq 100)) { 'ok' } else { 'info' }
    Add-Check 'Core parking' $value $state '100% means no cores are parked'
}
else {
    Add-Check 'Core parking' 'could not read' 'warn'
}

# --- interrupts ------------------------------------------------------------------
$msi = 0; $policy = 0
foreach ($dev in @(Get-PnpDevice -Class Display, Net -Status OK -ErrorAction SilentlyContinue)) {
    $base = Join-Path 'HKLM:\SYSTEM\CurrentControlSet\Enum' $dev.InstanceId
    if (Test-Path -LiteralPath (Join-Path $base 'Device Parameters\Interrupt Management\MessageSignaledInterruptProperties')) {
        if ((Get-RegValue (Join-Path $base 'Device Parameters\Interrupt Management\MessageSignaledInterruptProperties') 'MSISupported') -eq 1) { $msi++ }
    }
    if (Test-Path -LiteralPath (Join-Path $base 'Device Parameters\Interrupt Management\Affinity Policy')) { $policy++ }
}
Add-Check 'MSI interrupts' "$msi GPU/NIC device(s) enabled" $(if ($msi) { 'ok' } else { 'info' })
Add-Check 'Interrupt affinity policy' $(if ($policy) { "$policy device(s) set" } else { 'Windows default' }) $(if ($policy) { 'ok' } else { 'info' }) 'Reboot needed after changes'

# --- network and DNS -------------------------------------------------------------
$dns = @()
$dnsIps = @()
foreach ($cfg in @(Get-NetIPConfiguration -ErrorAction SilentlyContinue)) {
    if (-not $cfg.IPv4DefaultGateway) { continue }
    $addr = @(Get-DnsClientServerAddress -InterfaceIndex $cfg.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        ForEach-Object { $_.ServerAddresses })
    $dnsIps += $addr
    $dns += '{0}: {1}' -f $cfg.InterfaceAlias, $(if ($addr.Count) { $addr -join ', ' } else { 'automatic' })
}
Add-Check 'DNS' $(if ($dns.Count) { $dns -join ' | ' } else { 'no active IPv4 gateway' }) 'ok'

# Windows ships DoH templates for many resolvers; only a strict entry (no UDP fallback) means ours is active.
$strict = @()
if (Get-Command Get-DnsClientDohServerAddress -ErrorAction SilentlyContinue) {
    foreach ($d in @(Get-DnsClientDohServerAddress -ErrorAction SilentlyContinue)) {
        if ($dnsIps -notcontains $d.ServerAddress) { continue }
        if (-not $d.AllowFallbackToUdp) { $strict += $d.ServerAddress }
    }
}
Add-Check 'DNS over HTTPS' $(if ($strict.Count) { "strict for $($strict -join ', ')" } else { 'not enforced' }) $(if ($strict.Count) { 'ok' } else { 'info' }) 'Strict means no plain-UDP fallback'

$tcp = @(Get-NetTCPSetting -SettingName Internet -ErrorAction SilentlyContinue)
if ($tcp.Count) { Add-Check 'TCP autotuning' (($tcp[0].AutoTuningLevelLocal | Out-String).Trim()) 'ok' }

# --- Astra tweaks -----------------------------------------------------------------
$mouse = Get-RegValue 'HKCU:\Control Panel\Mouse' 'MouseSpeed'
Add-Check 'Mouse acceleration' $(if ("$mouse" -eq '0') { 'off' } else { 'on' }) $(if ("$mouse" -eq '0') { 'ok' } else { 'info' }) 'Off means 1:1 input'

$throttle = Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff'
Add-Check 'Power throttling' $(if ($throttle -eq 1) { 'off' } else { 'on' }) $(if ($throttle -eq 1) { 'ok' } else { 'info' })

Add-Check 'Ultimate plan' $(if ($plan -match 'Ultimate') { 'active' } else { 'inactive' }) $(if ($plan -match 'Ultimate') { 'ok' } else { 'info' })

$fast = Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled'
Add-Check 'Fast startup' $(if ($fast -eq 0) { 'off' } else { 'on' }) $(if ($fast -eq 0) { 'ok' } else { 'info' })

$resp = Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'SystemResponsiveness'
Add-Check 'MMCSS game task' $(if ($resp -eq 10) { 'game priority' } else { "Windows default ($resp)" }) $(if ($resp -eq 10) { 'ok' } else { 'info' }) 'Games task priority and scheduling'

$timer = Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'GlobalTimerResolutionRequests'
Add-Check 'Timer resolution' $(if ($timer -eq 1) { 'global requests allowed' } else { 'Windows default' }) $(if ($timer -eq 1) { 'ok' } else { 'info' }) 'Lets apps ask for 0.5 ms timers'

$mc = (Get-MMAgent -ErrorAction SilentlyContinue).MemoryCompression
if ($null -ne $mc) {
    Add-Check 'Memory compression' $(if ($mc) { 'on' } else { 'off' }) 'info'
}

$idle = $null
foreach ($i in @(Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerSettingDataIndex -ErrorAction SilentlyContinue)) {
    $id = ([string]$i.InstanceID).ToLower()
    if ($id -notmatch '5d76a2ca-e8c0-402f-a133-2158492d58ad') { continue }
    if ($scheme -and $id -notmatch [regex]::Escape($scheme)) { continue }
    if ($id -match '\\ac\\') { $idle = [int]$i.SettingIndexValue }
}
if ($null -ne $idle) {
    Add-Check 'CPU idle states' $(if ($idle -eq 1) { 'disabled on AC' } else { 'enabled' }) 'info'
}

# --- quality of life -------------------------------------------------------------
$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$personalize = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$qol = @()
if (Test-Path -LiteralPath 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}') { $qol += 'classic menu' }
if ((Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled') -eq 1) { $qol += 'long paths' }
if ((Get-RegValue $adv 'ShowSecondsInSystemClock') -eq 1) { $qol += 'clock seconds' }
if ((Get-RegValue $adv 'LaunchTo') -eq 1) { $qol += 'This PC' }
if ((Get-RegValue $personalize 'AppsUseLightTheme') -eq 0) { $qol += 'dark mode' }
if ((Get-RegValue $adv 'Start_IrisRecommendations') -eq 0) { $qol += 'no Start recs' }
if ((Get-RegValue 'HKCU:\Software\Microsoft\Clipboard' 'EnableClipboardHistory') -eq 1) { $qol += 'clipboard history' }
if ((Get-RegValue $adv 'TaskbarAl') -eq 0) { $qol += 'left taskbar' }
Add-Check 'Quality of life' $(if ($qol) { $qol -join ', ' } else { 'Windows defaults' }) 'ok'

$extras = @()
if ((Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec') -eq 0) { $extras += 'startup delay 0' }
if ((Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsDynamicSearchBoxEnabled') -eq 0) { $extras += 'no search highlights' }
if ((Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338387Enabled') -eq 0) { $extras += 'no lock screen tips' }
if ((Get-RegValue $adv 'ShowRecent') -eq 0) { $extras += 'no recent files' }
Add-Check 'Windows extras' $(if ($extras) { $extras -join ', ' } else { 'Windows defaults' }) 'ok'

$optional = @()
if ((Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled') -eq 1) { $optional += 'background apps off' }
if ((Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation') -eq 38) { $optional += 'foreground priority 38' }
if ((Get-RegValue $adv 'ShowSyncProviderNotifications') -eq 0) { $optional += 'no sync ads' }
if ((Get-RegValue $adv 'NoWindowMinimizingShortcuts') -eq 1) { $optional += 'no Aero Shake' }
$minAnimate = Get-RegValue 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate'
if ("$minAnimate" -eq '0' -and (Get-RegValue $adv 'TaskbarAnimations') -eq 0) { $optional += 'animations off' }
Add-Check 'Optional toggles' $(if ($optional) { $optional -join ', ' } else { 'Windows defaults' }) 'ok'

$gamingShell = @()
if ((Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications' 'ToastEnabled') -eq 0) { $gamingShell += 'no pop-ups' }
if ((Get-RegValue 'HKCU:\Control Panel\Desktop' 'MenuShowDelay') -eq '0') { $gamingShell += 'menu delay 0' }
if ((Get-RegValue 'HKCU:\Control Panel\Accessibility\StickyKeys' 'Flags') -eq '506') { $gamingShell += 'a11y keys off' }
if ((Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PenWorkspace' 'PenWorkspaceButtonDesiredVisibility') -eq 0) { $gamingShell += 'ink button hidden' }
if ((Get-RegValue 'HKCU:\Software\Policies\Microsoft\Edge' 'HubsSidebarEnabled') -eq 0) { $gamingShell += 'edge gaming policies' }
Add-Check 'Gaming shell extras' $(if ($gamingShell) { $gamingShell -join ', ' } else { 'Windows defaults' }) 'ok'

# --- gaming and desktop ----------------------------------------------------------
$dvr = Get-RegValue 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled'
Add-Check 'Game Bar capture' $(if ($dvr -eq 0) { 'off' } else { 'on' }) $(if ($dvr -eq 0) { 'ok' } else { 'warn' })

$wall = Get-RegValue 'HKCU:\Control Panel\Desktop' 'Wallpaper'
if ($wall) {
    Add-Check 'Wallpaper' $(Split-Path $wall -Leaf) $(if (Test-Path -LiteralPath $wall) { 'ok' } else { 'warn' }) $wall
    $wallAssets = 'C:\AstraMax\PostInstall\Assets'
    if ((Test-Path -LiteralPath $wall) -and (Test-Path -LiteralPath $wallAssets)) {
        $curHash = (Get-FileHash -LiteralPath $wall -Algorithm SHA256).Hash
        $theme = 'custom image'
        if ($curHash -eq (Get-FileHash -LiteralPath (Join-Path $wallAssets 'Astra-Wallpaper-RedPurple.png') -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash) { $theme = 'red and purple theme' }
        elseif ($curHash -eq (Get-FileHash -LiteralPath (Join-Path $wallAssets 'Astra-Wallpaper.png') -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash) { $theme = 'midnight blue theme' }
        Add-Check 'Wallpaper theme' $theme 'info'
    }
}
else {
    Add-Check 'Wallpaper' 'not set' 'info'
}

$gpuKey = Get-Item 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' -ErrorAction SilentlyContinue
$gpu = if ($gpuKey) { @($gpuKey.Property) } else { @() }
Add-Check 'Per-app GPU preference' $(if ($gpu.Count) { "$($gpu.Count) exe(s) set to High performance" } else { 'none set' }) $(if ($gpu.Count) { 'ok' } else { 'info' })

$shortcuts = @(Get-ChildItem ([Environment]::GetFolderPath('Desktop')) -Filter 'Astra*.lnk' -ErrorAction SilentlyContinue)
Add-Check 'Astra shortcuts' $(if ($shortcuts) { ($shortcuts | ForEach-Object { $_.BaseName }) -join ', ' } else { 'none' }) $(if ($shortcuts) { 'ok' } else { 'info' })

# --- services --------------------------------------------------------------------
$svcNames = 'DiagTrack', 'SysMain', 'WSearch', 'Spooler', 'DoSvc', 'WpnService'
$off = @()
foreach ($n in $svcNames) {
    $s = Get-Service -Name $n -ErrorAction SilentlyContinue
    if ($s -and $s.StartType -eq 'Disabled') { $off += $n }
}
Add-Check 'Services disabled' $(if ($off) { $off -join ', ' } else { 'none of the tuned services' }) 'ok'
$procCount = @(Get-Process -ErrorAction SilentlyContinue).Count
$hostCount = @(Get-Process -Name 'svchost' -ErrorAction SilentlyContinue).Count
Add-Check 'Processes' "$procCount total, $hostCount service hosts" 'info'

# --- security --------------------------------------------------------------------
$mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
if ($mp) {
    Add-Check 'Defender real-time' $(if ($mp.RealTimeProtectionEnabled) { 'on' } else { 'off' }) $(if ($mp.RealTimeProtectionEnabled) { 'ok' } else { 'warn' })
}
$vbs = Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity'
Add-Check 'VBS' $(switch ($vbs) { 1 { 'enabled' } 0 { 'disabled' } default { 'not configured' } }) 'info'

# --- runtimes and toolkit --------------------------------------------------------
$wow = Join-Path $env:SystemRoot 'SysWOW64'
Add-Check 'DirectX 9' $(if (Test-Path (Join-Path $env:SystemRoot 'System32\d3dx9_43.dll')) { 'present' } else { 'missing' }) 'info'
Add-Check 'Visual C++ runtime' $(if ((Test-Path (Join-Path $env:SystemRoot 'System32\vcruntime140.dll')) -and (Test-Path (Join-Path $wow 'vcruntime140.dll'))) { 'x86 + x64 present' } else { 'incomplete' }) 'info'
Add-Check '.NET Framework 3.5' $(if ((Get-RegValue 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5' 'Install') -eq 1) { 'installed' } else { 'not installed' }) 'info'

$maxRoot = 'C:\AstraMax'
$appExe = Join-Path $maxRoot 'AstraTweaks\Astra.exe'
if (Test-Path -LiteralPath $appExe) {
    $appVersion = (Get-Item -LiteralPath $appExe).VersionInfo.ProductVersion
    Add-Check 'Astra Tweaks app' $(if ($appVersion) { "v$appVersion in C:\AstraMax" } else { 'deployed to C:\AstraMax' }) 'ok'
}
else {
    Add-Check 'Astra Tweaks app' 'not deployed' 'info'
}
Add-Check 'Astra helpers' $(if (Test-Path -LiteralPath (Join-Path $maxRoot 'Restore.ps1')) { 'Restore and Verify in C:\AstraMax' } else { 'not deployed' }) 'info'
$postMenu = Join-Path $maxRoot 'PostInstall\Astra-PostInstall.cmd'
Add-Check 'Post-install menu' $(if (Test-Path -LiteralPath $postMenu) { 'Astra-PostInstall.cmd in C:\AstraMax\PostInstall' } else { 'not deployed' }) 'info'

$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
$result = [pscustomobject]@{
    Generated = $stamp
    Machine   = $env:COMPUTERNAME
    Checks    = $checks
}

if ($Json) {
    $payload = $result | ConvertTo-Json -Depth 5
    $encoding = New-Object System.Text.UTF8Encoding($false)
    $target = $OutFile
    try {
        $dir = Split-Path $target -Parent
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop | Out-Null }
        [System.IO.File]::WriteAllText($target, $payload, $encoding)
    }
    catch {
        $target = Join-Path $env:TEMP 'astra-report.json'
        [System.IO.File]::WriteAllText($target, $payload, $encoding)
    }
    Write-Output $target
    return
}

'Astra report - {0} ({1})' -f $stamp, $env:COMPUTERNAME
'-' * 68
foreach ($c in $checks) {
    $tag = switch ($c.State) {
        'ok' { '[ok]  ' }
        'warn' { '[warn]' }
        default { '[info]' }
    }
    '{0} {1,-26} {2}' -f $tag, $c.Name, $c.Value
    if ($c.Detail) { '{0} {1,-26} {2}' -f '      ', '', $c.Detail }
}
'-' * 68
'Run Restore.ps1 to undo power, interrupt, DNS and Steam launch-option changes.'
