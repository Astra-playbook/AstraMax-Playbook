#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Keep', 'On', 'Off')] [string]$Mouse = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$PowerThrottling = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$UltimatePlan = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$FastStartup = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$Mmcss = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$TimerResolution = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$NicPower = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$CpuIdle = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$MemoryCompression = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$StartupDelay = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$SearchHighlights = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$Suggestions = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$ExplorerRecent = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$WerUi = 'Keep',
    [switch]$AllOff
)

$ErrorActionPreference = 'SilentlyContinue'
if ($AllOff) {
    $Mouse = 'Off'; $PowerThrottling = 'Off'; $UltimatePlan = 'Off'; $FastStartup = 'Off'; $Mmcss = 'Off'
    $TimerResolution = 'Off'; $NicPower = 'Off'; $CpuIdle = 'Off'; $MemoryCompression = 'Off'
    $StartupDelay = 'Off'; $SearchHighlights = 'Off'; $Suggestions = 'Off'; $ExplorerRecent = 'Off'; $WerUi = 'Off'
}

$log = New-Object System.Collections.Generic.List[string]
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

function Set-Dword {
    param([string]$Path, [string]$Name, [int]$Value)
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Type DWord -Value $Value -Force
}

# --- mouse acceleration (user scope) ---------------------------------------------
if ($Mouse -ne 'Keep') {
    if (-not ('AstraMouse' -as [type])) {
        Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public static class AstraMouse {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(uint action, uint param, int[] values, uint flags);
}
'@
    }
    $key = 'HKCU:\Control Panel\Mouse'
    if ($Mouse -eq 'On') {
        Set-ItemProperty -Path $key -Name 'MouseSpeed' -Value '0' -Force
        Set-ItemProperty -Path $key -Name 'MouseThreshold1' -Value '0' -Force
        Set-ItemProperty -Path $key -Name 'MouseThreshold2' -Value '0' -Force
        [AstraMouse]::SystemParametersInfo(0x0004, 0, @(0, 0, 0), 3) | Out-Null
        $log.Add('mouse: acceleration off (1:1 input)')
    }
    else {
        Set-ItemProperty -Path $key -Name 'MouseSpeed' -Value '1' -Force
        Set-ItemProperty -Path $key -Name 'MouseThreshold1' -Value '6' -Force
        Set-ItemProperty -Path $key -Name 'MouseThreshold2' -Value '10' -Force
        [AstraMouse]::SystemParametersInfo(0x0004, 0, @(1, 6, 10), 3) | Out-Null
        $log.Add('mouse: Windows acceleration restored')
    }
}

# --- power throttling ------------------------------------------------------------
if ($PowerThrottling -ne 'Keep') {
    if (-not $isAdmin) { $log.Add('power throttling: needs an elevated PowerShell') }
    else {
        Set-Dword 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' $(if ($PowerThrottling -eq 'On') { 1 } else { 0 })
        $log.Add($(if ($PowerThrottling -eq 'On') { 'power throttling: off (sign out to apply everywhere)' } else { 'power throttling: Windows default' }))
    }
}

# --- Ultimate Performance plan ---------------------------------------------------
if ($UltimatePlan -ne 'Keep') {
    if (-not $isAdmin) { $log.Add('power plan: needs an elevated PowerShell') }
    else {
        if ($UltimatePlan -eq 'On') {
            $ultimate = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
            powercfg /setactive $ultimate 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                $out = (powercfg -duplicatescheme $ultimate 2>&1) -join ' '
                if ($out -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') {
                    powercfg /setactive $Matches[1] 2>&1 | Out-Null
                }
            }
            $now = ((powercfg /getactivescheme) -join ' ')
            if ($now -match 'Ultimate') { $log.Add('power plan: Ultimate Performance active') }
            else { $log.Add('power plan: Ultimate Performance is not available on this build') }
        }
        else {
            powercfg /setactive '381b4222-f694-41f0-9685-ff5bb260df2e' 2>&1 | Out-Null
            $log.Add('power plan: Balanced active')
        }
    }
}

# --- fast startup -----------------------------------------------------------------
if ($FastStartup -ne 'Keep') {
    if (-not $isAdmin) { $log.Add('fast startup: needs an elevated PowerShell') }
    else {
        Set-Dword 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' $(if ($FastStartup -eq 'On') { 0 } else { 1 })
        $log.Add($(if ($FastStartup -eq 'On') { 'fast startup: off (full shutdown every boot)' } else { 'fast startup: Windows default' }))
    }
}

# --- MMCSS game task --------------------------------------------------------------
if ($Mmcss -ne 'Keep') {
    if (-not $isAdmin) { $log.Add('mmcss: needs an elevated PowerShell') }
    else {
        $profile = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
        $games = Join-Path $profile 'Tasks\Games'
        New-Item -Path $games -Force | Out-Null
        if ($Mmcss -eq 'On') {
            Set-Dword $profile 'SystemResponsiveness' 10
            Set-Dword $games 'GPU Priority' 8
            Set-Dword $games 'Priority' 6
            Set-ItemProperty -Path $games -Name 'Scheduling Category' -Type String -Value 'High' -Force
            Set-ItemProperty -Path $games -Name 'SFIO Priority' -Type String -Value 'High' -Force
            $log.Add('mmcss: Games task raised (priority 6, scheduling High)')
        }
        else {
            Set-Dword $profile 'SystemResponsiveness' 20
            Set-Dword $games 'GPU Priority' 8
            Set-Dword $games 'Priority' 2
            Set-ItemProperty -Path $games -Name 'Scheduling Category' -Type String -Value 'Medium' -Force
            Set-ItemProperty -Path $games -Name 'SFIO Priority' -Type String -Value 'Normal' -Force
            $log.Add('mmcss: Games task back to Windows defaults')
        }
    }
}

# --- global timer resolution ------------------------------------------------------
if ($TimerResolution -ne 'Keep') {
    if (-not $isAdmin) { $log.Add('timer resolution: needs an elevated PowerShell') }
    else {
        Set-Dword 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'GlobalTimerResolutionRequests' $(if ($TimerResolution -eq 'On') { 1 } else { 0 })
        $log.Add($(if ($TimerResolution -eq 'On') { 'timer resolution: apps may request 0.5 ms timers (Windows 11)' } else { 'timer resolution: Windows default' }))
    }
}

# --- network adapter power saving -------------------------------------------------
if ($NicPower -ne 'Keep') {
    if (-not $isAdmin) { $log.Add('nic power: needs an elevated PowerShell') }
    else {
        $state = if ($NicPower -eq 'On') { 'Disabled' } else { 'Enabled' }
        $nics = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'Not Present' })
        foreach ($nic in $nics) {
            Set-NetAdapterPowerManagement -Name $nic.Name -AllowComputerToTurnOffDevice $state -ErrorAction SilentlyContinue
        }
        if ($nics.Count) {
            $log.Add($(if ($NicPower -eq 'On') { "nic power: power saving off on $($nics.Count) adapter(s)" } else { "nic power: Windows power saving allowed on $($nics.Count) adapter(s)" }))
        }
        else { $log.Add('nic power: no adapters found') }
    }
}

# --- CPU idle states --------------------------------------------------------------
if ($CpuIdle -ne 'Keep') {
    if (-not $isAdmin) { $log.Add('cpu idle: needs an elevated PowerShell') }
    else {
        if ($CpuIdle -eq 'On') {
            powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR 5d76a2ca-e8c0-402f-a133-2158492d58ad 1 2>&1 | Out-Null
            $log.Add('cpu idle: disabled on AC (lower latency, runs hotter)')
        }
        else {
            powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR 5d76a2ca-e8c0-402f-a133-2158492d58ad 0 2>&1 | Out-Null
            powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR 5d76a2ca-e8c0-402f-a133-2158492d58ad 0 2>&1 | Out-Null
            $log.Add('cpu idle: Windows idle states restored')
        }
        powercfg /setactive SCHEME_CURRENT 2>&1 | Out-Null
    }
}

# --- memory compression -----------------------------------------------------------
if ($MemoryCompression -ne 'Keep') {
    if (-not $isAdmin) { $log.Add('memory compression: needs an elevated PowerShell') }
    else {
        if ($MemoryCompression -eq 'On') {
            Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
            $log.Add('memory compression: off (16 GB+ recommended)')
        }
        else {
            Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
            $log.Add('memory compression: Windows default')
        }
    }
}

# --- startup app delay (user scope) -----------------------------------------------
if ($StartupDelay -ne 'Keep') {
    $serialize = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize'
    if ($StartupDelay -eq 'On') {
        Set-Dword $serialize 'StartupDelayInMSec' 0
        $log.Add('startup delay: 0 ms (startup apps launch immediately)')
    }
    else {
        Remove-ItemProperty -Path $serialize -Name 'StartupDelayInMSec' -Force -ErrorAction SilentlyContinue
        $log.Add('startup delay: Windows default')
    }
}

# --- search highlights (user scope) -----------------------------------------------
if ($SearchHighlights -ne 'Keep') {
    $search = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'
    Set-Dword $search 'IsDynamicSearchBoxEnabled' $(if ($SearchHighlights -eq 'On') { 0 } else { 1 })
    $log.Add($(if ($SearchHighlights -eq 'On') { 'search highlights: off' } else { 'search highlights: Windows default' }))
}

# --- lock screen / settings suggestions (user scope) ------------------------------
if ($Suggestions -ne 'Keep') {
    $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    $value = if ($Suggestions -eq 'On') { 0 } else { 1 }
    foreach ($name in 'SubscribedContent-338387Enabled', 'SubscribedContent-338388Enabled', 'SubscribedContent-310093Enabled') {
        Set-Dword $cdm $name $value
    }
    $log.Add($(if ($Suggestions -eq 'On') { 'suggestions: lock screen tips and Windows tips off' } else { 'suggestions: Windows default' }))
}

# --- Explorer recent and frequent lists (user scope) ------------------------------
if ($ExplorerRecent -ne 'Keep') {
    $explorer = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
    $value = if ($ExplorerRecent -eq 'On') { 0 } else { 1 }
    Set-Dword $explorer 'ShowRecent' $value
    Set-Dword $explorer 'ShowFrequent' $value
    $log.Add($(if ($ExplorerRecent -eq 'On') { 'explorer: recent and frequent lists hidden' } else { 'explorer: recent and frequent lists back on' }))
}

# --- Windows Error Reporting UI (user scope) --------------------------------------
if ($WerUi -ne 'Keep') {
    $wer = 'HKCU:\Software\Microsoft\Windows\Windows Error Reporting'
    if ($WerUi -eq 'On') {
        Set-Dword $wer 'DontShowUI' 1
        $log.Add('error reporting: crash dialogs hidden (reports still follow the WER policy)')
    }
    else {
        Remove-ItemProperty -Path $wer -Name 'DontShowUI' -Force -ErrorAction SilentlyContinue
        $log.Add('error reporting: Windows default crash dialogs')
    }
}

if (-not $log.Count) { $log.Add('nothing selected') }
$log | ForEach-Object { Write-Host $_ }
