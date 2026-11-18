#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$helper = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\HardwareTweaks.ps1'))
& $helper -Feature DiskIdle -Mode $Mode
