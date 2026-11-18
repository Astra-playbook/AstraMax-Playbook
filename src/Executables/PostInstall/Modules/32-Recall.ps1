#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'DisableAIDataAnalysis') -eq 1) { 'ON - Recall snapshots off' }
        elseif ($null -eq (Get-AstraDword $path 'DisableAIDataAnalysis')) { 'OFF - Recall not restricted' }
        else { 'MIXED - WindowsAI policy exists' }
    }
    'On' {
        Set-AstraDword $path 'DisableAIDataAnalysis' 1
        'recall: off'
    }
    'Off' {
        Remove-AstraValue $path 'DisableAIDataAnalysis'
        'recall: Windows default'
    }
}
