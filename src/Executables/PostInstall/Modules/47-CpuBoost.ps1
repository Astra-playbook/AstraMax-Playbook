#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On','Off','Status')] [string]$Mode = 'Status')
$helper = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\HardwareTweaks.ps1'))
& $helper -Feature CpuBoost -Mode $Mode
