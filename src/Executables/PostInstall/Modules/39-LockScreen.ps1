#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'NoLockScreen') -eq 1) { 'ON - lock screen off' }
        elseif ($null -eq (Get-AstraDword $path 'NoLockScreen')) { 'OFF - lock screen shown' }
        else { 'MIXED - lock screen policy is set to 0' }
    }
    'On' {
        Set-AstraDword $path 'NoLockScreen' 1
        'lock screen: off'
    }
    'Off' {
        Remove-AstraValue $path 'NoLockScreen'
        'lock screen: Windows default'
    }
}
