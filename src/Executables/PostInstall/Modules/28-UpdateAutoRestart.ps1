#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'NoAutoRebootWithLoggedOnUsers') -eq 1) { 'ON - no automatic restart while signed in' }
        else { 'OFF - Windows Update may restart' }
    }
    'On' {
        Set-AstraDword $path 'NoAutoRebootWithLoggedOnUsers' 1
        'update: auto-restart while signed in suppressed'
    }
    'Off' {
        Remove-AstraValue $path 'NoAutoRebootWithLoggedOnUsers'
        'update: Windows default'
    }
}
