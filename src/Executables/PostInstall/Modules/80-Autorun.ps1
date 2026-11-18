#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'

switch ($Mode) {
    'Status' {
        $value = Get-AstraDword $path 'NoDriveTypeAutoRun'
        if ($value -eq 255) { 'ON - AutoRun disabled for every drive type' }
        elseif ($null -eq $value) { 'OFF - Windows default AutoPlay behaviour' }
        else { "OFF - AutoRun limited by value $value" }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Security.ps1'))) -Autorun $Mode
    }
}
