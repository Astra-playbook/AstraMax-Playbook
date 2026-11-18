#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$store = 'HKCU:\System\GameConfigStore'
$capture = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'
$policy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'

if ($Mode -eq 'Status') {
    if ((Get-AstraDword $store 'GameDVR_Enabled') -eq 0) { 'ON - capture and Game DVR off' } else { 'OFF - capture on' }
    return
}

if ($Mode -eq 'On') {
    Set-AstraDword $policy 'AllowGameDVR' 0
    Set-AstraDword $store 'GameDVR_Enabled' 0
    Set-AstraDword $store 'GameDVR_FSEBehaviorMode' 2
    Set-AstraDword $store 'GameDVR_HonorUserFSEBehaviorMode' 1
    Set-AstraDword $store 'GameDVR_DXGIHonorFSEWindowsCompatible' 1
    Set-AstraDword $store 'GameDVR_EFSEFeatureFlags' 0
    Set-AstraDword $capture 'AppCaptureEnabled' 0
    'game mode: fullscreen optimizations off, Game DVR and capture off'
}
else {
    Remove-AstraValue $policy 'AllowGameDVR'
    Set-AstraDword $store 'GameDVR_Enabled' 1
    Set-AstraDword $store 'GameDVR_FSEBehaviorMode' 0
    Set-AstraDword $store 'GameDVR_HonorUserFSEBehaviorMode' 0
    Set-AstraDword $store 'GameDVR_DXGIHonorFSEWindowsCompatible' 0
    Set-AstraDword $store 'GameDVR_EFSEFeatureFlags' 0
    Set-AstraDword $capture 'AppCaptureEnabled' 1
    'game mode: capture on, Windows defaults'
}
