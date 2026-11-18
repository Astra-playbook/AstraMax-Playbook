#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel'

if ($Mode -eq 'Status') {
    if ((Get-AstraDword $key 'GlobalTimerResolutionRequests') -eq 1) { 'ON - 0.5 ms timer requests allowed' }
    else { 'OFF - Windows default' }
    return
}

if ($Mode -eq 'On') {
    Set-AstraDword $key 'GlobalTimerResolutionRequests' 1
    'timer resolution: apps may request 0.5 ms timers (Windows 11)'
}
else {
    Set-AstraDword $key 'GlobalTimerResolutionRequests' 0
    'timer resolution: Windows default'
}
