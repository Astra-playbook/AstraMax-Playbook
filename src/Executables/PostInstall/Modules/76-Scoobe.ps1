#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'ScoobeSystemSettingEnabled') -eq 0) { 'ON - post-update setup prompts off' }
        else { 'OFF - Windows default setup prompts' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))) -Scoobe $Mode
    }
}
