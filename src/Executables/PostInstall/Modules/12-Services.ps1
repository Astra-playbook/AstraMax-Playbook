#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$services = @(
    @{ Name = 'DiagTrack'; Default = 'Automatic' },
    @{ Name = 'dmwappushservice'; Default = 'Manual' },
    @{ Name = 'SysMain'; Default = 'Automatic' },
    @{ Name = 'WSearch'; Default = 'Automatic' },
    @{ Name = 'NDU'; Default = 'Manual' },
    @{ Name = 'WerSvc'; Default = 'Manual' },
    @{ Name = 'XblAuthManager'; Default = 'Manual' },
    @{ Name = 'XblGameSave'; Default = 'Manual' },
    @{ Name = 'XboxGipSvc'; Default = 'Manual' },
    @{ Name = 'XboxNetApiSvc'; Default = 'Manual' }
)

if ($Mode -eq 'Status') {
    $off = @($services | Where-Object {
            (Get-Service -Name $_.Name -ErrorAction SilentlyContinue).StartType -eq 'Disabled'
        })
    if ($off.Count -eq $services.Count) { 'ON - all 10 services disabled' }
    elseif ($off.Count -eq 0) { 'OFF - services at Windows defaults' }
    else { "MIXED - $($off.Count) of $($services.Count) disabled" }
    return
}

if ($Mode -eq 'On') {
    foreach ($s in $services) { Set-AstraService $s.Name 'Disabled' }
    'services: DiagTrack, SysMain, WSearch, NDU, WER, Xbox and push disabled'
}
else {
    foreach ($s in $services) { Set-AstraService $s.Name $s.Default }
    'services: startup types restored (WSearch, SysMain and Xbox need a reboot)'
}
