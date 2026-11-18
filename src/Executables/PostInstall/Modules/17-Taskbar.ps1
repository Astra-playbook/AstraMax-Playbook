#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$search = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'

if ($Mode -eq 'Status') {
    if ((Get-AstraDword $adv 'TaskbarDa') -eq 0) { 'ON - widgets, chat and search box hidden' } else { 'OFF - Windows defaults' }
    return
}

if ($Mode -eq 'On') {
    Set-AstraDword $adv 'TaskbarDa' 0
    Set-AstraDword $adv 'TaskbarMn' 0
    Set-AstraDword $adv 'ShowTaskViewButton' 0
    Set-AstraDword $search 'SearchboxTaskbarMode' 0
    Set-AstraDword $adv 'TaskbarAl' 0
    'taskbar: widgets, chat and task view hidden, search box off, icons left'
}
else {
    Set-AstraDword $adv 'TaskbarDa' 1
    Set-AstraDword $adv 'TaskbarMn' 1
    Set-AstraDword $adv 'ShowTaskViewButton' 1
    Set-AstraDword $search 'SearchboxTaskbarMode' 2
    Set-AstraDword $adv 'TaskbarAl' 1
    'taskbar: Windows defaults'
}
