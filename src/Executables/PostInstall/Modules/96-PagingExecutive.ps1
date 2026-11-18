#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'DisablePagingExecutive') -eq 1) { 'ON - kernel paging executive kept in RAM' }
        else { 'OFF - Windows default paging executive' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Security.ps1'))) -PagingExecutive $Mode
    }
}
