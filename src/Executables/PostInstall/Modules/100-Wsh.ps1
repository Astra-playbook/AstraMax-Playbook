#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings'

switch ($Mode) {
    'Status' {
        $value = Get-AstraDword $path 'Enabled'
        if ($value -eq 0) { 'ON - Windows Script Host disabled' }
        elseif ($value -eq 1) { 'OFF - Windows Script Host enabled' }
        else { 'OFF - Windows default (Windows Script Host enabled)' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Security.ps1'))) -Wsh $Mode
    }
}
