#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$idle = '5d76a2ca-e8c0-402f-a133-2158492d58ad'
$ac = Get-AstraPowerIndex $script:AstraSubProcessor $idle 'AC'

if ($Mode -eq 'Status') {
    if ($ac -eq 1) { 'ON - idle states disabled on AC' } else { 'OFF - idle states enabled' }
    return
}

if ($Mode -eq 'On') {
    Set-AstraPowerIndex $script:AstraSubProcessor $idle 1
    'cpu idle: disabled on AC (lower latency, runs hotter)'
}
else {
    Set-AstraPowerIndex $script:AstraSubProcessor $idle 0 0
    'cpu idle: Windows idle states enabled'
}
