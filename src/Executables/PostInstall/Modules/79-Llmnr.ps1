#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'

switch ($Mode) {
    'Status' {
        $value = Get-AstraDword $path 'EnableMulticast'
        if ($value -eq 0) { 'ON - LLMNR multicast resolution off (policy)' }
        elseif ($null -eq $value) { 'OFF - Windows default (LLMNR on)' }
        else { "OFF - LLMNR policy value is $value" }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Security.ps1'))) -Llmnr $Mode
    }
}
