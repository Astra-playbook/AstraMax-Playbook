#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'FullPath') -eq 1) { 'ON - full folder path in the title bar' }
        else { 'OFF - Windows default title bar' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))) -FullPath $Mode
    }
}
