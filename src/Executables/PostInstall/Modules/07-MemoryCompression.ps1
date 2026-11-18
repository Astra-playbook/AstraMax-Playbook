#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$agent = Get-MMAgent -ErrorAction SilentlyContinue

if ($Mode -eq 'Status') {
    if ($null -eq $agent.MemoryCompression) { 'UNKNOWN - Get-MMAgent failed' }
    elseif ($agent.MemoryCompression) { 'OFF - compression on' }
    else { 'ON - compression off' }
    return
}

if ($Mode -eq 'On') {
    Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
    'memory compression: off (16 GB+ recommended)'
}
else {
    Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
    'memory compression: Windows default'
}
