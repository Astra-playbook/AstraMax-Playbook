#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PenWorkspace'

switch ($Mode) {
    'Status' {
        $value = Get-AstraDword $path 'PenWorkspaceButtonDesiredVisibility'
        if ($value -eq 0) { 'ON - Windows Ink Workspace button hidden' }
        else { 'OFF - pen workspace button visible' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))) -InkWorkspace $Mode
    }
}
