#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$clip = 'HKCU:\Software\Microsoft\Clipboard'
$cls = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'
$fs = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'

if ($Mode -eq 'Status') {
    $classic = Test-Path -LiteralPath $cls
    $pc = (Get-AstraDword $adv 'LaunchTo') -eq 1
    if ($classic -or $pc) { 'ON - classic menu and/or This PC' } else { 'OFF - Windows defaults' }
    return
}

if ($Mode -eq 'On') {
    New-Item -Path (Join-Path $cls 'InprocServer32') -Force | Out-Null
    Set-ItemProperty -Path (Join-Path $cls 'InprocServer32') -Name '(Default)' -Value '' -Force
    Set-AstraDword $adv 'LaunchTo' 1
    Set-AstraDword $adv 'ShowSecondsInSystemClock' 1
    Set-AstraDword $adv 'HideFileExt' 0
    Set-AstraDword $clip 'EnableClipboardHistory' 1
    Set-AstraDword $fs 'LongPathsEnabled' 1
    'explorer: classic menu, This PC, clock seconds, extensions, clipboard history, long paths'
}
else {
    Remove-Item -Path $cls -Recurse -Force
    Set-AstraDword $adv 'LaunchTo' 2
    Set-AstraDword $adv 'ShowSecondsInSystemClock' 0
    Set-AstraDword $adv 'HideFileExt' 1
    Set-AstraDword $clip 'EnableClipboardHistory' 0
    Set-AstraDword $fs 'LongPathsEnabled' 0
    'explorer: Windows defaults (restart Explorer to see the menu change)'
}
