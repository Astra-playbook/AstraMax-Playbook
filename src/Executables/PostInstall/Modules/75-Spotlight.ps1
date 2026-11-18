#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'

switch ($Mode) {
    'Status' {
        $rotating = Get-AstraDword $path 'RotatingLockScreenEnabled'
        $overlay = Get-AstraDword $path 'RotatingLockScreenOverlayEnabled'
        if ($rotating -eq 0 -and $overlay -eq 0) { 'ON - lock screen Spotlight and its tips off' }
        elseif ($null -eq $rotating -and $null -eq $overlay) { 'OFF - Windows default lock screen' }
        else { 'MIXED - some Spotlight values set' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))) -Spotlight $Mode
    }
}
