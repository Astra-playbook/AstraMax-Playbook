#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Power,
    [switch]$Interrupts,
    [switch]$Dns,
    [switch]$Steam,
    [switch]$Capture,
    [switch]$Tweaks,
    [switch]$QoL,
    [switch]$Security,
    [switch]$Hardware,
    [switch]$Games,
    [switch]$Debloat,
    [switch]$Toolbox,
    [switch]$Wallpaper,
    [switch]$All,
    [switch]$Force,
    [switch]$Msi
)

$ErrorActionPreference = 'SilentlyContinue'
$log = New-Object System.Collections.Generic.List[string]

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'Restore needs an elevated PowerShell. Reopen the shortcut and approve the prompt.'
    exit 1
}

if ($All -or -not ($Power -or $Interrupts -or $Dns -or $Steam -or $Capture -or $Tweaks -or $QoL -or $Security -or $Hardware -or $Games -or $Debloat -or $Toolbox -or $Wallpaper)) {
    if (-not $All) { Write-Host 'No section selected, restoring everything.' }
    $Power = $true; $Interrupts = $true; $Dns = $true; $Steam = $true; $Capture = $true; $Tweaks = $true; $QoL = $true; $Security = $true; $Hardware = $true; $Games = $true; $Debloat = $true; $Toolbox = $true; $Wallpaper = $true
}

if (-not $Force) {
    Write-Host 'This will:'
    if ($Power) { Write-Host '  - allow Windows to park cores again' }
    if ($Interrupts) { Write-Host '  - drop the interrupt affinity policy' }
    if ($Dns) { Write-Host '  - set every adapter back to automatic DNS and remove DoH' }
    if ($Steam) { Write-Host '  - restore Steam launch options from the Astra backup' }
    if ($Capture) { Write-Host '  - turn Game Bar capture back on' }
    if ($Tweaks) { Write-Host '  - reset mouse, power throttling, power plan, fast startup, MMCSS and latency tweaks' }
    if ($QoL) { Write-Host '  - reset Explorer, taskbar, clock, Start, Spotlight, setup-prompt, clipboard and background-app preferences to Windows defaults' }
    if ($Security) { Write-Host '  - restore saved SmartScreen, LLMNR and AutoRun values (or remove them)' }
    if ($Hardware) { Write-Host '  - restore saved CPU policies for the active scheme and GPU settings' }
    if ($Games) { Write-Host '  - restore saved per-game GPU and config values (close the games first)' }
    if ($Debloat) { Write-Host '  - restore the service startup types saved before the debloat tiers (removed apps stay removed)' }
    if ($Toolbox) { Write-Host '  - restore the 41 reviewed Windows/browser choices from toolbox backups; use Astra System to review all saved tweak backups' }
    if ($Wallpaper) { Write-Host '  - restore the previous static wallpaper and fit from the wallpaper snapshot' }
    Write-Host 'Re-run with -Force to apply.'
    exit 0
}

function Set-PowerValue {
    param([string]$Sub, [string]$Setting, [string]$Value)
    powercfg /setacvalueindex SCHEME_CURRENT $Sub $Setting $Value | Out-Null
    powercfg /setdcvalueindex SCHEME_CURRENT $Sub $Setting $Value | Out-Null
}

if ($Power) {
    Set-PowerValue '54533251-82be-4824-96c1-47b60b740d00' '893dee8e-2bef-41e0-89c6-b55d0929964c' 0
    powercfg /setactive SCHEME_CURRENT | Out-Null
    $log.Add('core parking: Windows defaults restored')
}

if ($Interrupts) {
    $changed = 0
    foreach ($dev in @(Get-PnpDevice -Class Display, Net -Status OK)) {
        $base = Join-Path 'HKLM:\SYSTEM\CurrentControlSet\Enum' $dev.InstanceId
        $aff = Join-Path $base 'Device Parameters\Interrupt Management\Affinity Policy'
        if (Test-Path -LiteralPath $aff) {
            Remove-ItemProperty -Path $aff -Name 'DevicePolicy' -Force
            Remove-ItemProperty -Path $aff -Name 'AssignmentSetOverride' -Force
            $changed++
        }
        if ($Msi) {
            $props = Join-Path $base 'Device Parameters\Interrupt Management\MessageSignaledInterruptProperties'
            if (Test-Path -LiteralPath $props) { Set-ItemProperty -Path $props -Name 'MSISupported' -Type DWord -Value 0 -Force }
        }
    }
    $log.Add("interrupt affinity: cleared on $changed device(s)")
    if ($Msi) { $log.Add('MSI: reverted to driver defaults, reboot to take effect') }
}

if ($Dns) {
    $n = 0
    foreach ($cfg in @(Get-NetIPConfiguration)) {
        if (-not $cfg.IPv4DefaultGateway) { continue }
        Set-DnsClientServerAddress -InterfaceIndex $cfg.InterfaceIndex -ResetServerAddresses
        $n++
    }
    $log.Add("dns: automatic on $n adapter(s)")

    if (Get-Command Get-DnsClientDohServerAddress -ErrorAction SilentlyContinue) {
        $removed = 0
        foreach ($d in @(Get-DnsClientDohServerAddress)) {
            Remove-DnsClientDohServerAddress -ServerAddress $d.ServerAddress -Confirm:$false
            $removed++
        }
        $log.Add("doh: removed $removed entr(ies)")
    }
}

if ($Steam) {
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -Name SteamPath).SteamPath
    if (-not $steam) {
        $log.Add('steam: not installed')
    }
    elseif (Get-Process -Name steam -ErrorAction SilentlyContinue) {
        $log.Add('steam: close Steam and re-run to restore launch options')
    }
    else {
        $steam = $steam -replace '/', '\'
        $restored = 0
        foreach ($cfg in @(Get-ChildItem (Join-Path $steam 'userdata') -Filter 'localconfig.vdf.astra-backup' -Recurse -Depth 2)) {
            $target = $cfg.FullName -replace '\.astra-backup$', ''
            Copy-Item -LiteralPath $cfg.FullName -Destination $target -Force
            $restored++
        }
        $log.Add("steam: restored $restored launch-option backup(s)")
    }
}

if ($Capture) {
    Set-ItemProperty -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled' -Type DWord -Value 1 -Force
    $cap = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'
    New-Item -Path $cap -Force | Out-Null
    Set-ItemProperty -Path $cap -Name 'AppCaptureEnabled' -Type DWord -Value 1 -Force
    Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'AllowGameDVR' -Force
    $log.Add('game bar capture: back on (sign out to finish applying)')
}

if ($Hardware) {
    $helper = Join-Path $PSScriptRoot 'HardwareTweaks.ps1'
    foreach ($feature in 'CpuBoost','CpuEpp','GpuScheduling','WindowedGaming') {
        & $helper -Feature $feature -Mode Off 2>&1 | ForEach-Object { $log.Add([string]$_) }
    }
}
if ($Tweaks) {
    $helper = Join-Path $PSScriptRoot 'Tweaks.ps1'
    if (Test-Path -LiteralPath $helper) {
        & $helper -AllOff 2>&1 | ForEach-Object { $log.Add([string]$_) }
    }
    else {
        $log.Add('tweaks: Tweaks.ps1 is missing')
    }
}

if ($QoL) {
    $helper = Join-Path $PSScriptRoot 'QoL.ps1'
    if (Test-Path -LiteralPath $helper) {
        & $helper -AllOff 2>&1 | ForEach-Object { $log.Add([string]$_) }
    }
    else {
        $log.Add('qol: QoL.ps1 is missing')
    }
}

if ($Security) {
    $helper = Join-Path $PSScriptRoot 'Security.ps1'
    if (Test-Path -LiteralPath $helper) {
        & $helper -AllOff 2>&1 | ForEach-Object { $log.Add([string]$_) }
    }
    else {
        $log.Add('security: Security.ps1 is missing')
    }
}

if ($Games) {
    & (Join-Path $PSScriptRoot 'GameProfiles.ps1') -All -Mode Off 2>&1 | ForEach-Object { $log.Add([string]$_) }
}
if ($Debloat) {
    $helper = Join-Path $PSScriptRoot 'Debloat.ps1'
    if (Test-Path -LiteralPath $helper) {
        & $helper -Restore 2>&1 | ForEach-Object { $log.Add([string]$_) }
    }
    else {
        $log.Add('debloat: Debloat.ps1 is missing')
    }
}
if ($Toolbox) {
    $helper = Join-Path $PSScriptRoot 'Invoke-ToolboxTweak.ps1'
    foreach ($id in @(
        'qol.search-history-off','exm-notification-sound-off','exm-restart-sign-on-off','abs.app.chrome-background-off','exm-chrome-online-spelling-off','exm-chrome-geolocation-off','max.visual.wallpaper-full-quality',
        'sys-first-signin-animation-off','sys-signin-account-details-off','sys-start-recent-apps-off','sys-app-account-info-off','sys-app-contacts-off',
        'chrome-search-suggestions-off','chrome-network-prediction-off','chrome-third-party-cookies-off','chrome-website-notifications-off','chrome-translation-off','chrome-download-location-prompt','chrome-cast-off','chrome-memory-saver-on','chrome-low-battery-saver-on',
        'exm-settings-online-tips-off','exm-store-push-install-off','exm-message-cloud-sync-off','exm-chrome-feedback-off','exm-chrome-spellchecking-off','exm-chrome-sensors-off','exm-chrome-serial-off','exm-chrome-bluetooth-off','exm-chrome-webusb-off',
        'exm-app-diagnostics-off','exm-app-calendar-off','exm-app-email-off','exm-app-messaging-off','exm-app-phone-off','exm-app-call-history-off','exm-app-tasks-off','exm-app-radio-control-off','exm-app-notification-reading-off','exm-app-unpaired-device-sync-off','sys-app-motion-off'
    )) {
        try { & $helper -Id $id -Restore -ErrorAction Stop | ForEach-Object { $log.Add([string]$_) } }
        catch { $log.Add("toolbox: FAILED to restore $id ($($_.Exception.Message))") }
    }
}
if ($Wallpaper) {
    try { & (Join-Path $PSScriptRoot 'Wallpaper.ps1') -Restore -ErrorAction Stop | ForEach-Object { $log.Add([string]$_) } }
    catch { $log.Add("wallpaper: FAILED to restore ($($_.Exception.Message))") }
}
$log | ForEach-Object { Write-Host $_ }
Write-Host 'Reboot to finish restoring power and interrupt settings.'
