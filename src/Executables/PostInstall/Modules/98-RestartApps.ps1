#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'RestartApps') -eq 0) { 'ON - Windows will not reopen apps after sign-in' }
        elseif ((Get-AstraDword $path 'RestartApps') -eq 1) { 'OFF - app restart after sign-in allowed' }
        else { 'OFF - Windows default app restart behaviour' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))) -RestartApps $Mode
    }
}
