#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\InputPersonalization'

switch ($Mode) {
    'Status' {
        $text = Get-AstraDword $path 'RestrictImplicitTextCollection'
        $ink = Get-AstraDword $path 'RestrictImplicitInkCollection'
        if ($text -eq 1 -and $ink -eq 1) { 'ON - typing and handwriting samples no longer collected' }
        elseif ($null -eq $text -and $null -eq $ink) { 'OFF - Windows default personalization' }
        elseif ($text -eq 0 -and $ink -eq 0) { 'OFF - input personalization allowed' }
        else { 'MIXED - only some input personalization values set' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))) -InkTyping $Mode
    }
}
