#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'NonBestEffortLimit') -eq 0) { 'ON - QoS reservation cleared' }
        elseif ($null -eq (Get-AstraDword $path 'NonBestEffortLimit')) { 'OFF - 20 percent reserved' }
        else { 'MIXED - QoS limit is set' }
    }
    'On' {
        Set-AstraDword $path 'NonBestEffortLimit' 0
        'qos: no reserved bandwidth'
    }
    'Off' {
        Remove-AstraValue $path 'NonBestEffortLimit'
        'qos: Windows default'
    }
}
