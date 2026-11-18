#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$tool = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\NvidiaTools.ps1'))
if (-not (Test-Path -LiteralPath $tool)) { $tool = 'C:\AstraMax\NvidiaTools.ps1' }

switch ($Mode) {
    'Status' {
        $out = @(& $tool -Mode Status 2>&1 | ForEach-Object { [string]$_ })
        if (-not ($out | Where-Object { $_ -match '^adapter: (?!none)' })) {
            'OFF - no NVIDIA adapter detected'
            break
        }
        $panel = [bool]($out | Where-Object { $_ -match '^control panel: present' })
        $app = [bool]($out | Where-Object { $_ -match '^nvidia app: present' })
        if ($panel -and $app) {
            'ON - NVIDIA app and Control Panel present'
            break
        }
        $missing = @()
        if (-not $panel) { $missing += 'Control Panel' }
        if (-not $app) { $missing += 'NVIDIA App' }
        $blockers = @()
        if ($out | Where-Object { $_ -match '^microsoft store: missing' }) { $blockers += 'Store missing' }
        if ($out | Where-Object { $_ -match '^wuauserv: Disabled' }) { $blockers += 'Windows Update disabled' }
        if ($out | Where-Object { $_ -match '^bits: Disabled' }) { $blockers += 'BITS disabled' }
        $text = "MIXED - missing $($missing -join ' and ')"
        if ($blockers) { $text += "; $($blockers -join ', ')" }
        "$text - press ON for the exact install steps"
    }
    'On' {
        $out = @(& $tool -Mode Install 2>&1)
        "nvidia tools: $($out -join ' | ')"
    }
    'Off' {
        'nothing to undo. Uninstall the NVIDIA App in Settings > Apps; install a driver from nvidia.com to restore a removed Control Panel. No NVIDIA binaries are downloaded automatically.'
    }
}
