#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
$names = 'SubscribedContent-338387Enabled', 'SubscribedContent-338388Enabled', 'SubscribedContent-310093Enabled'

function Get-AstraSuggestionState {
    $off = 0
    foreach ($name in $names) {
        if ((Get-AstraDword $path $name) -eq 0) { $off++ }
    }
    $off
}

switch ($Mode) {
    'Status' {
        $off = Get-AstraSuggestionState
        if ($off -eq $names.Count) { 'ON - lock screen tips and suggestions off' }
        elseif ($off -eq 0) { 'OFF - Windows tips and suggestions' }
        else { 'MIXED - some suggestions still on' }
    }
    'On' {
        foreach ($name in $names) { Set-AstraDword $path $name 0 }
        'suggestions: off'
    }
    'Off' {
        foreach ($name in $names) { Set-AstraDword $path $name 1 }
        'suggestions: Windows default'
    }
}
