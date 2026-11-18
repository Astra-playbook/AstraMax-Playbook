#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Control Panel\Keyboard'

switch ($Mode) {
    'Status' {
        $delay = (Get-ItemProperty -Path $path -Name 'KeyboardDelay').KeyboardDelay
        if ("$delay" -eq '0') { 'ON - fastest keyboard repeat' }
        else { 'OFF - Windows default keyboard repeat delay' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))) -KeyboardRepeat $Mode
    }
}
