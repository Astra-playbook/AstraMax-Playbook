#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'fAllowToGetHelp') -eq 0) { 'ON - Remote Assistance off' }
        else { 'OFF - Remote Assistance allowed' }
    }
    'On' {
        Set-AstraDword $path 'fAllowToGetHelp' 0
        'remote assistance: off'
    }
    'Off' {
        Set-AstraDword $path 'fAllowToGetHelp' 1
        'remote assistance: Windows default'
    }
}
