#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKCU:\Software\Microsoft\Clipboard'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'CloudClipboardAutomaticUpload') -eq 0) { 'ON - cloud clipboard sync off' }
        else { 'OFF - Windows default cloud clipboard' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))) -CloudClipboard $Mode
    }
}
