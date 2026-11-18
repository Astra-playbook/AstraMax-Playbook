#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'DisableAutoplay') -eq 1) { 'ON - AutoPlay off' }
        else { 'OFF - AutoPlay prompts' }
    }
    'On' {
        Set-AstraDword $path 'DisableAutoplay' 1
        'autoplay: off'
    }
    'Off' {
        Set-AstraDword $path 'DisableAutoplay' 0
        'autoplay: Windows default'
    }
}
