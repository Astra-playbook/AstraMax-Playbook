#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$sticky = 'HKCU:\Control Panel\Accessibility\StickyKeys'
$filter = 'HKCU:\Control Panel\Accessibility\Keyboard Response'
$toggle = 'HKCU:\Control Panel\Accessibility\ToggleKeys'

function Get-Flags([string]$Path) {
    "$((Get-ItemProperty -Path $Path -Name 'Flags' -ErrorAction SilentlyContinue).Flags)"
}

switch ($Mode) {
    'Status' {
        $values = @((Get-Flags $sticky), (Get-Flags $filter), (Get-Flags $toggle))
        if ($values[0] -eq '506' -and $values[1] -eq '122' -and $values[2] -eq '58') { 'ON - accessibility shortcut keys off' }
        elseif ($values[0] -in '', '510' -and $values[1] -in '', '126' -and $values[2] -in '', '62') { 'OFF - Windows default shortcut keys' }
        else { "MIXED - flags $($values -join '/')" }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))) -A11yKeys $Mode
    }
}
