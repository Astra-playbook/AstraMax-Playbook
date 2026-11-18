#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$profile = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
$games = Join-Path $profile 'Tasks\Games'

if ($Mode -eq 'Status') {
    if ((Get-AstraDword $profile 'SystemResponsiveness') -eq 10) { 'ON - Games task raised' } else { 'OFF - Windows default' }
    return
}

if ($Mode -eq 'On') {
    Set-AstraDword $profile 'SystemResponsiveness' 10
    Set-AstraDword $games 'GPU Priority' 8
    Set-AstraDword $games 'Priority' 6
    Set-AstraText $games 'Scheduling Category' 'High'
    Set-AstraText $games 'SFIO Priority' 'High'
    'mmcss: Games task raised (priority 6, scheduling High)'
}
else {
    Set-AstraDword $profile 'SystemResponsiveness' 20
    Set-AstraDword $games 'GPU Priority' 8
    Set-AstraDword $games 'Priority' 2
    Set-AstraText $games 'Scheduling Category' 'Medium'
    Set-AstraText $games 'SFIO Priority' 'Normal'
    'mmcss: Games task back to Windows defaults'
}
