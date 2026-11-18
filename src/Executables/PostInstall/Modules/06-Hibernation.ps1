#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power'

if ($Mode -eq 'Status') {
    if ((Get-AstraDword $key 'HibernateEnabled') -eq 0) { 'ON - hibernation off' } else { 'OFF - hibernation on' }
    return
}

if ($Mode -eq 'On') {
    powercfg /h off 2>&1 | Out-Null
    'hibernation: off (also removes hiberfil.sys)'
}
else {
    powercfg /h on 2>&1 | Out-Null
    'hibernation: on'
}
