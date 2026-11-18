#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'ClearPageFileAtShutdown') -eq 1) { 'ON - pagefile cleared at shutdown' }
        else { 'OFF - Windows default pagefile shutdown' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Security.ps1'))) -ClearPagefile $Mode
    }
}
