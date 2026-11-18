#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$userPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
$policyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'

switch ($Mode) {
    'Status' {
        $value = (Get-ItemProperty -Path $userPath -Name 'SmartScreenEnabled').SmartScreenEnabled
        $policy = Get-AstraDword $policyPath 'EnableSmartScreen'
        if ("$value" -eq 'Warn' -and $policy -eq 1) { 'ON - SmartScreen checks on (Warn)' }
        elseif ("$value" -eq 'Off' -and $policy -eq 0) { 'OFF - SmartScreen checks and policy off' }
        elseif ($null -eq $value -and $null -eq $policy) { 'OFF - SmartScreen at Windows default' }
        else { 'MIXED - SmartScreen values look manually changed' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Security.ps1'))) -SmartScreen $Mode
    }
}
