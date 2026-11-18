#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'

if ($Mode -eq 'Status') {
    if ((Get-AstraDword $key 'HiberbootEnabled') -eq 0) { 'ON - full shutdown every boot' } else { 'OFF - fast startup on' }
    return
}

if ($Mode -eq 'On') {
    Set-AstraDword $key 'HiberbootEnabled' 0
    'fast startup: off (clean driver load every boot)'
}
else {
    Set-AstraDword $key 'HiberbootEnabled' 1
    'fast startup: Windows default'
}
