#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\Multimedia\Audio'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'UserDuckingPreference') -eq 3) { 'ON - other sounds keep full volume during calls' }
        else { 'OFF - Windows default communications ducking' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))) -AudioDucking $Mode
    }
}
