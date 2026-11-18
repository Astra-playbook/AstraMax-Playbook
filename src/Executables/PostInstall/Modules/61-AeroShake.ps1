#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'NoWindowMinimizingShortcuts') -eq 1) { 'ON - Aero Shake off' }
        else { 'OFF - Windows default (Aero Shake on)' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))) -AeroShake $Mode
    }
}
