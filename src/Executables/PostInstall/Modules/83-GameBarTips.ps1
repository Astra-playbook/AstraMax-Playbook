#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\GameBar'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'ShowStartupPanel') -eq 0) { 'ON - Game Bar startup panel and tips off' }
        else { 'OFF - Game Bar at Windows default' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))) -GameBarTips $Mode
    }
}
