#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy'

switch ($Mode) {
    'Status' {
        $value = Get-AstraDword $path 'HasAccepted'
        if ($value -eq 0) { 'ON - online speech recognition off' }
        elseif ($value -eq 1) { 'OFF - online speech recognition allowed' }
        else { 'OFF - Windows default online speech prompt' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))) -OnlineSpeech $Mode
    }
}
