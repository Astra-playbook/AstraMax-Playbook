#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$personalize = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$desktop = 'HKCU:\Control Panel\Desktop'

if ($Mode -eq 'Status') {
    if ((Get-AstraDword $personalize 'EnableTransparency') -eq 0) { 'ON - transparency and animations off' }
    else { 'OFF - Windows effects on' }
    return
}

if ($Mode -eq 'On') {
    Set-AstraDword $personalize 'EnableTransparency' 0
    Set-AstraDword $adv 'UseOLEDTaskbarTransparency' 0
    Set-AstraText $desktop 'MenuShowDelay' '0'
    'visual effects: transparency off, instant menus'
}
else {
    Set-AstraDword $personalize 'EnableTransparency' 1
    Set-AstraDword $adv 'UseOLEDTaskbarTransparency' 1
    Set-AstraText $desktop 'MenuShowDelay' '400'
    'visual effects: Windows defaults'
}
