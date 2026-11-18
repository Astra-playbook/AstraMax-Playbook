#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'AutoDownload') -eq 2) { 'ON - Store auto-update off' }
        elseif ($null -eq (Get-AstraDword $path 'AutoDownload')) { 'OFF - Store apps update automatically' }
        else { 'MIXED - Store policy is set' }
    }
    'On' {
        Set-AstraDword $path 'AutoDownload' 2
        'store: auto-update off'
    }
    'Off' {
        Remove-AstraValue $path 'AutoDownload'
        'store: Windows default'
    }
}
