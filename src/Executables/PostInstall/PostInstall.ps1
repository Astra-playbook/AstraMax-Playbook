#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Status,
    [ValidateSet('On', 'Off')] [string]$All,
    [switch]$IncludeRisky
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
. (Join-Path $root 'Catalog.ps1')
$modules = $AstraModules

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    $child = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    if ($Status) { $child += '-Status' }
    if ($All) { $child += @('-All', $All) }
    if ($IncludeRisky) { $child += '-IncludeRisky' }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $child
    return
}

function Invoke-Module {
    param([string]$Script, [string]$Mode)
    $file = Join-Path $root (Join-Path 'Modules' $Script)
    try {
        $out = & $file -Mode $Mode 2>&1
        if ($null -eq $out) { return '' }
        return (($out | ForEach-Object { [string]$_ }) -join ' | ')
    }
    catch {
        return "ERROR: $($_.Exception.Message)"
    }
}

function Get-ModuleState {
    param($Module)
    $text = Invoke-Module $Module.Script 'Status'
    if ($text -match '^ON') { 'ON' }
    elseif ($text -match '^OFF') { 'OFF' }
    elseif ($text -match '^MIXED') { 'MIXED' }
    else { '?' }
}

function Show-StatusTable {
    foreach ($m in $modules) {
        $state = Get-ModuleState $m
        '{0,2}. [{1,-5}] {2}{3}' -f $m.N, $state, $m.Label, $(if ($m.Risk) { '  (risky)' } else { '' })
    }
}

function Show-Menu {
    Clear-Host
    Write-Host ''
    Write-Host '   ASTRA MAX  -  POST INSTALL' -ForegroundColor Red
    Write-Host '   ON applies; OFF restores where supported. Removed apps need reinstalling.' -ForegroundColor DarkMagenta
    Write-Host ('   Console menu. For the full window, run AstraMaxPostInstall.exe.' ) -ForegroundColor DarkGray
    Write-Host ('   ' + ('-' * 62)) -ForegroundColor DarkMagenta
    foreach ($m in $modules) {
        $state = Get-ModuleState $m
        $color = switch ($state) {
            'ON' { 'Magenta' }
            'OFF' { 'DarkGray' }
            'MIXED' { 'Yellow' }
            default { 'DarkYellow' }
        }
        $risk = if ($m.Risk) { ' *' } else { '' }
        Write-Host ("   {0,2}. {1,-48} {2}{3}" -f $m.N, $m.Label, $state, $risk) -ForegroundColor $color
    }
    Write-Host ('   ' + ('-' * 62)) -ForegroundColor DarkMagenta
    Write-Host '   21 switches the wallpaper: ON is red and purple, OFF is midnight blue.' -ForegroundColor DarkMagenta
    Write-Host '   * risky: asks for confirmation' -ForegroundColor DarkGray
    Write-Host '   Numbers toggle (1,4,7)   A all on   D all off   R refresh   Q quit' -ForegroundColor Gray
}

function Apply-All {
    param([string]$Mode)
    foreach ($m in $modules) {
        if ($m.IndividualOnly) { continue }
        if ($m.Risk -and -not $IncludeRisky) {
            Write-Host ("   skip {0} (risky)" -f $m.Label) -ForegroundColor DarkYellow
            continue
        }
        Invoke-Module $m.Script $Mode | Out-Null
        Write-Host ("   {0}: {1}" -f $m.Label, $Mode) -ForegroundColor DarkGray
    }
    Write-Host '   done' -ForegroundColor Magenta
}

function Toggle-Selection {
    param([string]$Text)
    foreach ($n in [regex]::Matches($Text, '\d+')) {
        $index = [int]$n.Value
        $m = $modules | Where-Object { $_.N -eq $index }
        if (-not $m) { Write-Host "   $index : no such item" -ForegroundColor Red; continue }
        $state = Get-ModuleState $m
        $target = if ($state -eq 'ON' -or $state -eq 'MIXED') { 'Off' } else { 'On' }
        if ($m.Risk) {
            $ok = Read-Host ("   {0} is risky. Type YES to set {1}" -f $m.Label, $target)
            if ($ok -ne 'YES') { Write-Host '   skipped' -ForegroundColor DarkYellow; continue }
        }
        Write-Host ("   {0}: {1}" -f $m.Label, $target) -ForegroundColor Magenta
        $result = Invoke-Module $m.Script $target
        if ($result) { Write-Host "     $result" -ForegroundColor Cyan }
    }
}

if ($Status) {
    Show-StatusTable
    return
}

if ($All) {
    Apply-All $All
    return
}

while ($true) {
    Show-Menu
    $choice = (Read-Host '   Choice').Trim().ToLower()
    switch -Regex ($choice) {
        '^(q|quit|exit)$' { return }
        '^(r|refresh)?$' { continue }
        '^(a|all on|allon)$' { Apply-All 'On'; Read-Host '   Press Enter' | Out-Null; continue }
        '^(d|all off|alloff)$' { Apply-All 'Off'; Read-Host '   Press Enter' | Out-Null; continue }
        '\d' { Toggle-Selection $choice; Read-Host '   Press Enter' | Out-Null; continue }
        default { Write-Host '   Unknown choice' -ForegroundColor Red }
    }
}
