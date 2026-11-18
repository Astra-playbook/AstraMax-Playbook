#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$tier = 'Moderate'
$debloat = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Debloat.ps1'))
if (-not (Test-Path -LiteralPath $debloat)) { $debloat = 'C:\AstraMax\Debloat.ps1' }

switch ($Mode) {
    'Status' {
        $out = @(& $debloat -Level $tier -Report 2>&1) -join ' '
        if ($out -match ': (\d+) of (\d+) apps removed') {
            $removed = [int]$Matches[1]
            $total = [int]$Matches[2]
            if ($removed -eq 0) { "OFF - none of the $tier apps removed" }
            elseif ($removed -eq $total) { "ON - all $tier apps removed" }
            else { "MIXED - $removed of $total $tier apps removed" }
        }
        else { 'MIXED - status unavailable; run Debloat.ps1 -Level Status' }
    }
    'On' {
        & $debloat -Level $tier | Out-Null
        $out = @(& $debloat -Level $tier -Report 2>&1) -join ' '
        "debloat $tier applied. $out"
    }
    'Off' {
        "apps stay removed ($tier is not reversible). Reinstall from the Store, winget or removed.json"
    }
}
