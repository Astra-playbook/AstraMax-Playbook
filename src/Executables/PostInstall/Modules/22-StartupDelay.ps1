#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'StartupDelayInMSec') -eq 0) { 'ON - startup apps launch immediately' }
        else { 'OFF - Windows startup delay' }
    }
    'On' {
        Set-AstraDword $path 'StartupDelayInMSec' 0
        'startup delay: 0 ms'
    }
    'Off' {
        Remove-AstraValue $path 'StartupDelayInMSec'
        'startup delay: Windows default'
    }
}
