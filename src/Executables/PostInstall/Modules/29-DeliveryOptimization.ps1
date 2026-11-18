#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'DODownloadMode') -eq 0) { 'ON - peer downloads off' }
        elseif ($null -eq (Get-AstraDword $path 'DODownloadMode')) { 'OFF - Windows default' }
        else { 'MIXED - Delivery Optimization is configured' }
    }
    'On' {
        Set-AstraDword $path 'DODownloadMode' 0
        'delivery optimization: peer downloads off'
    }
    'Off' {
        Remove-AstraValue $path 'DODownloadMode'
        'delivery optimization: Windows default'
    }
}
