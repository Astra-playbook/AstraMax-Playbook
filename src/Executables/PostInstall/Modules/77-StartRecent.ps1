#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'Start_TrackProgs') -eq 0) { 'ON - recently added apps list off' }
        else { 'OFF - Windows default recently added apps list' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))) -StartRecentApps $Mode
    }
}
