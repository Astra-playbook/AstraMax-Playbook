#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive'

if ($Mode -eq 'Status') {
    if ((Get-AstraDword $key 'DisableFileSyncNGSC') -eq 1) { 'ON - OneDrive sync blocked' } else { 'OFF - OneDrive allowed' }
    return
}

if ($Mode -eq 'On') {
    Set-AstraDword $key 'DisableFileSyncNGSC' 1
    Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
    'onedrive: sync blocked and process stopped'
}
else {
    Remove-AstraValue $key 'DisableFileSyncNGSC'
    'onedrive: policy removed (app starts at next sign-in)'
}
