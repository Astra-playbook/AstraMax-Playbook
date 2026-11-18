#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Control Panel\Desktop'

switch ($Mode) {
    'Status' {
        $value = (Get-ItemProperty -Path $path -Name 'MenuShowDelay' -ErrorAction SilentlyContinue).MenuShowDelay
        if ("$value" -eq '0') { 'ON - menu delay 0 ms' }
        elseif ($null -eq $value) { 'OFF - Windows default (value not set)' }
        else { "OFF - MenuShowDelay $value ms" }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))) -MenuDelay $Mode
    }
}
