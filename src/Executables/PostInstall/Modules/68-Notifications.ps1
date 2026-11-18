#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications'

switch ($Mode) {
    'Status' {
        $value = Get-AstraDword $path 'ToastEnabled'
        if ($value -eq 0) { 'ON - toast notifications off' }
        elseif ($null -eq $value -or $value -eq 1) { 'OFF - notifications at Windows default' }
        else { "OFF - ToastEnabled $value" }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))) -Notifications $Mode
    }
}
