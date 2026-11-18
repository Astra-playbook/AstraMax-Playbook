#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'

switch ($Mode) {
    'Status' {
        $boost = Get-AstraDword $path 'StartupBoostEnabled'
        $bg = Get-AstraDword $path 'BackgroundModeEnabled'
        if ($boost -eq 0 -and $bg -eq 0) { 'ON - Edge startup boost and background off' }
        elseif ($null -eq $boost -and $null -eq $bg) { 'OFF - Edge defaults' }
        else { 'MIXED - one Edge policy is still set' }
    }
    'On' {
        Set-AstraDword $path 'StartupBoostEnabled' 0
        Set-AstraDword $path 'BackgroundModeEnabled' 0
        'edge: startup boost and background mode off'
    }
    'Off' {
        Remove-AstraValue $path 'StartupBoostEnabled'
        Remove-AstraValue $path 'BackgroundModeEnabled'
        'edge: Windows default'
    }
}
