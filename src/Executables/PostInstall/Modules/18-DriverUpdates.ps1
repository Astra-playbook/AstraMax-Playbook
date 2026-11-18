#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$search = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching'
$wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'

if ($Mode -eq 'Status') {
    if ((Get-AstraDword $wu 'ExcludeWUDriversInQualityUpdate') -eq 1) { 'ON - Windows Update drivers blocked' }
    else { 'OFF - Windows Update may replace drivers' }
    return
}

if ($Mode -eq 'On') {
    Set-AstraDword $search 'SearchOrderConfig' 0
    Set-AstraDword $wu 'ExcludeWUDriversInQualityUpdate' 1
    'driver updates: blocked (security updates still install)'
}
else {
    Set-AstraDword $search 'SearchOrderConfig' 1
    Remove-AstraValue $wu 'ExcludeWUDriversInQualityUpdate'
    'driver updates: Windows default'
}
