#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$ultimate = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
$balanced = '381b4222-f694-41f0-9685-ff5bb260df2e'
$raw = (powercfg /getactivescheme) -join ' '
$name = if ($raw -match '\(([^)]+)\)') { $Matches[1] } else { 'unknown' }

if ($Mode -eq 'Status') {
    if ($name -match 'Ultimate') { "ON - $name" } else { "OFF - $name" }
    return
}

if ($Mode -eq 'On') {
    powercfg /setactive $ultimate 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $out = (powercfg -duplicatescheme $ultimate 2>&1) -join ' '
        if ($out -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') {
            powercfg /setactive $Matches[1] 2>&1 | Out-Null
        }
    }
    $now = (powercfg /getactivescheme) -join ' '
    if ($now -match 'Ultimate') { 'power plan: Ultimate Performance active' }
    else { 'power plan: Ultimate Performance is not available on this build' }
}
else {
    powercfg /setactive $balanced 2>&1 | Out-Null
    'power plan: Balanced active'
}
