#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$min = '893dee8e-2bef-41e0-89c6-b55d0929964c'
$max = 'bc5038f7-23e0-4960-96da-33abaf5935ec'
$ac = Get-AstraPowerIndex $script:AstraSubProcessor $min 'AC'
$dc = Get-AstraPowerIndex $script:AstraSubProcessor $min 'DC'

if ($Mode -eq 'Status') {
    if ($ac -eq 100 -and $dc -eq 100) { 'ON - no cores parked' }
    else { "OFF - AC $ac / DC $dc minimum cores" }
    return
}

if ($Mode -eq 'On') {
    Set-AstraPowerIndex $script:AstraSubProcessor $min 100 100
    Set-AstraPowerIndex $script:AstraSubProcessor $max 100
    'core parking: disabled on AC and DC'
}
else {
    Set-AstraPowerIndex $script:AstraSubProcessor $min 0 0
    'core parking: Windows default'
}
