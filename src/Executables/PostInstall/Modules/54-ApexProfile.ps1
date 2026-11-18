#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On','Off','Status')] [string]$Mode = 'Status')
$helper = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\GameProfiles.ps1'))
& $helper -Apex -Mode $Mode
