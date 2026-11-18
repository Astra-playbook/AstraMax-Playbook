#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On','Off','Status')] [string]$Mode = 'Status')
$ErrorActionPreference = 'Stop'
if ($Mode -eq 'Status') {
    $p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings'
    $v = (Get-ItemProperty $p -Name TaskbarEndTask -ErrorAction SilentlyContinue).TaskbarEndTask
    if ($v -eq 1) { 'ON - taskbar End task enabled' } else { 'OFF - taskbar End task disabled' }
    return
}
$helper = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))
& $helper -EndTask $Mode
