#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling'

if ($Mode -eq 'Status') {
    if ((Get-AstraDword $key 'PowerThrottlingOff') -eq 1) { 'ON - throttling off' } else { 'OFF - Windows default' }
    return
}

if ($Mode -eq 'On') {
    Set-AstraDword $key 'PowerThrottlingOff' 1
    'power throttling: off (sign out to apply everywhere)'
}
else {
    Set-AstraDword $key 'PowerThrottlingOff' 0
    'power throttling: Windows default'
}
