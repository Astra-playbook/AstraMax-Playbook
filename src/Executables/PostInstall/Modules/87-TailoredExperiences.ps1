#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'TailoredExperiencesWithDiagnosticDataEnabled') -eq 0) { 'ON - tailored suggestions from diagnostic data off' }
        else { 'OFF - Windows default tailored experiences' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))) -TailoredExperiences $Mode
    }
}
