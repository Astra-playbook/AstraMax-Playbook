#requires -Version 5.1

function Test-AstraAdmin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Set-AstraDword {
    param([string]$Path, [string]$Name, [int]$Value)
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Type DWord -Value $Value -Force
}

function Get-AstraDword {
    param([string]$Path, [string]$Name)
    (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
}

function Set-AstraText {
    param([string]$Path, [string]$Name, [string]$Value)
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Type String -Value $Value -Force
}

function Remove-AstraValue {
    param([string]$Path, [string]$Name)
    Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction SilentlyContinue
}

function Set-AstraService {
    param([string]$Name, [string]$Startup)
    Set-Service -Name $Name -StartupType $Startup -ErrorAction SilentlyContinue
}

function Get-AstraPowerIndex {
    param([string]$Sub, [string]$Setting, [string]$Kind = 'AC')
    $out = @(powercfg /q SCHEME_CURRENT $Sub $Setting 2>$null)
    $line = $out | Where-Object { $_ -match "$Kind Power Setting Index" } | Select-Object -First 1
    if ($line -match '0x([0-9a-fA-F]+)') { return [Convert]::ToInt32($Matches[1], 16) }
    return $null
}

function Set-AstraPowerIndex {
    param([string]$Sub, [string]$Setting, [int]$Ac, [int]$Dc = -1)
    powercfg /setacvalueindex SCHEME_CURRENT $Sub $Setting $Ac 2>&1 | Out-Null
    if ($Dc -ge 0) { powercfg /setdcvalueindex SCHEME_CURRENT $Sub $Setting $Dc 2>&1 | Out-Null }
    powercfg /setactive SCHEME_CURRENT 2>&1 | Out-Null
}

$script:AstraSubProcessor = '54533251-82be-4824-96c1-47b60b740d00'
