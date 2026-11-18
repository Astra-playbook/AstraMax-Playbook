#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On','Off','Status')] [string]$Mode = 'Status')
$ErrorActionPreference = 'Stop'
$p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
if ($Mode -eq 'Status') {
    $values = Get-ItemProperty $p -ErrorAction SilentlyContinue
    if ($null -ne $values.AppsUseLightTheme -and $values.AppsUseLightTheme -eq 0 -and $null -ne $values.SystemUsesLightTheme -and $values.SystemUsesLightTheme -eq 0) { 'ON - Windows and apps dark' }
    elseif ($values.AppsUseLightTheme -eq 1 -and $values.SystemUsesLightTheme -eq 1) { 'OFF - Windows and apps light' }
    else { 'MIXED - Windows/app theme differs or is unset' }
    return
}
$helper = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\QoL.ps1'))
& $helper -DarkMode $Mode
