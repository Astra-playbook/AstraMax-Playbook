#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$tier = 'Insane'
$debloat = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Debloat.ps1'))
if (-not (Test-Path -LiteralPath $debloat)) { $debloat = 'C:\AstraMax\Debloat.ps1' }

switch ($Mode) {
    'Status' {
        $out = @(& $debloat -Level $tier -Services -Report 2>&1) -join ' '
        $svc = [regex]::Match($out, 'services tier [^:]+: (\d+) of (\d+) disabled')
        if (-not $svc.Success) { "MIXED - status unavailable; run Debloat.ps1 -Level Status" }
        else {
            $off = [int]$svc.Groups[1].Value
            $total = [int]$svc.Groups[2].Value
            $extra = @()
            $usr = [regex]::Match($out, 'user services : (\d+) of (\d+) disabled')
            if ($usr.Success) { $extra += "per-user $($usr.Groups[1].Value)/$($usr.Groups[2].Value)" }
            if ($out -match 'service host grouping : on') { $extra += 'hosts grouped' } else { $extra += 'hosts split' }
            $suffix = " ($($extra -join ', '))"
            if ($off -eq 0) { "OFF - no $tier services disabled$suffix" }
            elseif ($off -eq $total) { "ON - all $tier services disabled$suffix" }
            else { "MIXED - $off of $total $tier services disabled$suffix" }
        }
    }
    'On' {
        & $debloat -Level $tier -Services | Out-Null
        $out = @(& $debloat -Level $tier -Services -Report 2>&1) -join ' '
        "services $tier applied. $out. Startup types were saved to C:\AstraMax\Debloat\service-state.json; per-user templates to user-service-state.json; service host grouping to kernel-state.json. Disabled services also lost their cache/report folders and stale per-user service keys; those are not restored."
    }
    'Off' {
        $out = @(& $debloat -Restore 2>&1) -join ' '
        "services restored from the Astra snapshot. $out"
    }
}
