#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

switch ($Mode) {
    'Status' {
        $svc = Get-Service -Name Spooler -ErrorAction SilentlyContinue
        if (-not $svc) { 'MIXED - Spooler service not found' }
        elseif ($svc.StartType -eq 'Disabled') { 'ON - Print Spooler off' }
        else { 'OFF - printing works' }
    }
    'On' {
        Set-AstraService 'Spooler' 'Disabled'
        Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
        'spooler: off (no printing)'
    }
    'Off' {
        Set-AstraService 'Spooler' 'Automatic'
        Start-Service -Name Spooler -ErrorAction SilentlyContinue
        'spooler: automatic'
    }
}
