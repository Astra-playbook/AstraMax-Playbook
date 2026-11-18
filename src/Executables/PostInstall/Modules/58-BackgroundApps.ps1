#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'GlobalUserDisabled') -eq 1) { 'ON - background apps off' }
        else { 'OFF - apps may run in the background' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))) -BackgroundApps $Mode
    }
}
