#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'DisableWindowsConsumerFeatures') -eq 1) { 'ON - consumer features off' }
        elseif ($null -eq (Get-AstraDword $path 'DisableWindowsConsumerFeatures')) { 'OFF - suggested apps on' }
        else { 'MIXED - consumer policy is set to 0' }
    }
    'On' {
        Set-AstraDword $path 'DisableWindowsConsumerFeatures' 1
        'consumer features: off'
    }
    'Off' {
        Remove-AstraValue $path 'DisableWindowsConsumerFeatures'
        'consumer features: Windows default'
    }
}
