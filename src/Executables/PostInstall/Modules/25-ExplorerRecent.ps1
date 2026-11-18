#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'

switch ($Mode) {
    'Status' {
        $recent = Get-AstraDword $path 'ShowRecent'
        $frequent = Get-AstraDword $path 'ShowFrequent'
        if ($recent -eq 0 -and $frequent -eq 0) { 'ON - recent and frequent lists hidden' }
        elseif ($recent -eq 1 -or $frequent -eq 1) { 'OFF - recent and frequent lists shown' }
        else { 'MIXED - one list still shown' }
    }
    'On' {
        Set-AstraDword $path 'ShowRecent' 0
        Set-AstraDword $path 'ShowFrequent' 0
        'explorer: recent and frequent lists hidden'
    }
    'Off' {
        Set-AstraDword $path 'ShowRecent' 1
        Set-AstraDword $path 'ShowFrequent' 1
        'explorer: recent and frequent lists back on'
    }
}
