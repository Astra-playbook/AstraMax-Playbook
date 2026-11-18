#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Control Panel\International\User Profile'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'HttpAcceptLanguageOptOut') -eq 1) { 'ON - websites cannot read the Windows language list' }
        else { 'OFF - Windows default language list access' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))) -LanguageList $Mode
    }
}
