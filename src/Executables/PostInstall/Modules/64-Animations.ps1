#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$metrics = 'HKCU:\Control Panel\Desktop\WindowMetrics'
$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

switch ($Mode) {
    'Status' {
        $min = (Get-ItemProperty -Path $metrics -Name 'MinAnimate' -ErrorAction SilentlyContinue).MinAnimate
        $taskbar = Get-AstraDword $adv 'TaskbarAnimations'
        if ("$min" -eq '0' -and $taskbar -eq 0) { 'ON - window and taskbar animations off' }
        elseif ("$min" -eq '0' -or $taskbar -eq 0) { 'MIXED - only part of the animations are off' }
        else { 'OFF - Windows animations active' }
    }
    default {
        & ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))) -Animations $Mode
    }
}
