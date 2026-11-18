#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$cu = 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'
$lm = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'
$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $lm 'TurnOffWindowsCopilot') -eq 1) { 'ON - Copilot off' }
        elseif ($null -eq (Get-AstraDword $lm 'TurnOffWindowsCopilot')) { 'OFF - Copilot available' }
        else { 'MIXED - Copilot policy is set to 0' }
    }
    'On' {
        Set-AstraDword $cu 'TurnOffWindowsCopilot' 1
        Set-AstraDword $lm 'TurnOffWindowsCopilot' 1
        Set-AstraDword $adv 'ShowCopilotButton' 0
        'copilot: off'
    }
    'Off' {
        Remove-AstraValue $cu 'TurnOffWindowsCopilot'
        Remove-AstraValue $lm 'TurnOffWindowsCopilot'
        Set-AstraDword $adv 'ShowCopilotButton' 1
        'copilot: Windows default'
    }
}
