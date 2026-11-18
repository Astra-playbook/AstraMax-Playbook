#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'

switch ($Mode) {
    'Status' {
        $v = Get-AstraDword $path 'NetworkThrottlingIndex'
        if ($null -ne $v -and [uint32]$v -eq 4294967295) { 'ON - network throttling off' }
        else { 'OFF - MMCSS throttling (10 packets/ms)' }
    }
    'On' {
        Set-AstraDword $path 'NetworkThrottlingIndex' -1
        'network throttling: off'
    }
    'Off' {
        Set-AstraDword $path 'NetworkThrottlingIndex' 10
        'network throttling: Windows default'
    }
}
