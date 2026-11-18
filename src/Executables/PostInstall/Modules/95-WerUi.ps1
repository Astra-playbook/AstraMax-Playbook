#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\Windows\Windows Error Reporting'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'DontShowUI') -eq 1) { 'ON - crash reporting dialogs hidden' }
        else { 'OFF - Windows default crash dialogs' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Tweaks.ps1'))) -WerUi $Mode
    }
}
