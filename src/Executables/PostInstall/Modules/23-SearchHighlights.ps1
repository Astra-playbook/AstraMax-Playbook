#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'IsDynamicSearchBoxEnabled') -eq 0) { 'ON - search highlights off' }
        else { 'OFF - search highlights shown' }
    }
    'On' {
        Set-AstraDword $path 'IsDynamicSearchBoxEnabled' 0
        'search highlights: off'
    }
    'Off' {
        Set-AstraDword $path 'IsDynamicSearchBoxEnabled' 1
        'search highlights: Windows default'
    }
}
