#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Policies\Microsoft\Edge'

switch ($Mode) {
    'Status' {
        $sidebar = Get-AstraDword $path 'HubsSidebarEnabled'
        $widgets = Get-AstraDword $path 'WebWidgetAllowed'
        if ($sidebar -eq 0 -and $widgets -eq 0) { 'ON - Edge sidebar, shopping and widgets off' }
        elseif ($null -eq $sidebar -and $null -eq $widgets) { 'OFF - Edge policies at Windows default' }
        else { 'MIXED - some Edge gaming policies set' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))) -EdgeGaming $Mode
    }
}
