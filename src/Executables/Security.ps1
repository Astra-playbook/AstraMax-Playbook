#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Keep', 'On', 'Off')] [string]$SmartScreen = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$Llmnr = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$Autorun = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$PagingExecutive = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$Maintenance = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$ClearPagefile = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$Wsh = 'Keep',
    [switch]$AllOff
)

$ErrorActionPreference = 'SilentlyContinue'
if ($AllOff) {
    $SmartScreen = 'Off'; $Llmnr = 'Off'; $Autorun = 'Off'
    $PagingExecutive = 'Off'; $Maintenance = 'Off'; $ClearPagefile = 'Off'; $Wsh = 'Off'
}

$log = New-Object System.Collections.Generic.List[string]
$backupDir = Join-Path $env:ProgramData 'AstraMax\Security'

function Save-Snapshot {
    param([string]$Id, $Entries)
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    $Entries | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $backupDir "$Id.json") -Encoding UTF8
}

function Read-Snapshot {
    param([string]$Id)
    $file = Join-Path $backupDir "$Id.json"
    if (-not (Test-Path -LiteralPath $file)) { return }
    @(Get-Content -LiteralPath $file -Raw | ConvertFrom-Json)
}

function Remove-Snapshot {
    param([string]$Id)
    Remove-Item -LiteralPath (Join-Path $backupDir "$Id.json") -Force -ErrorAction SilentlyContinue
}

function Get-RegistryEntry {
    param([string]$Path, [string]$Name, [string]$Type)
    $value = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
    [pscustomobject]@{
        Path   = $Path
        Name   = $Name
        Type   = $Type
        Exists = ($null -ne $value)
        Value  = $value
    }
}

function Set-RegistryEntry {
    param([string]$Path, [string]$Name, [string]$Type, $Value)
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Type $Type -Value $Value -Force
}

function Restore-Entries {
    param($Entries)
    foreach ($entry in $Entries) {
        if ($entry.Exists) {
            Set-RegistryEntry $entry.Path $entry.Name $entry.Type $entry.Value
        }
        else {
            Remove-ItemProperty -Path $entry.Path -Name $entry.Name -Force -ErrorAction SilentlyContinue
        }
    }
}

# --- SmartScreen -----------------------------------------------------------------
if ($SmartScreen -ne 'Keep') {
    $userPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
    $policyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
    if ($SmartScreen -eq 'On') {
        $saved = Read-Snapshot 'SmartScreen'
        if (-not $saved) {
            Save-Snapshot 'SmartScreen' @(
                (Get-RegistryEntry $userPath 'SmartScreenEnabled' 'String')
                (Get-RegistryEntry $policyPath 'EnableSmartScreen' 'DWord')
            )
        }
        Set-RegistryEntry $userPath 'SmartScreenEnabled' 'String' 'Warn'
        Set-RegistryEntry $policyPath 'EnableSmartScreen' 'DWord' 1
        $log.Add('smartscreen: checks on (Warn) and policy enabled')
    }
    else {
        $saved = Read-Snapshot 'SmartScreen'
        if ($saved) {
            Restore-Entries $saved
            Remove-Snapshot 'SmartScreen'
            $log.Add('smartscreen: previous values restored')
        }
        else {
            Set-RegistryEntry $userPath 'SmartScreenEnabled' 'String' 'Off'
            Set-RegistryEntry $policyPath 'EnableSmartScreen' 'DWord' 0
            $log.Add('smartscreen: checks and policy off (security trade-off)')
        }
    }
}

# --- LLMNR -----------------------------------------------------------------------
if ($Llmnr -ne 'Keep') {
    $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'
    if ($Llmnr -eq 'On') {
        if (-not (Read-Snapshot 'Llmnr')) {
            Save-Snapshot 'Llmnr' @((Get-RegistryEntry $path 'EnableMulticast' 'DWord'))
        }
        Set-RegistryEntry $path 'EnableMulticast' 'DWord' 0
        $log.Add('llmnr: multicast name resolution off (policy)')
    }
    else {
        $saved = Read-Snapshot 'Llmnr'
        if ($saved) {
            Restore-Entries $saved
            Remove-Snapshot 'Llmnr'
            $log.Add('llmnr: previous policy value restored')
        }
        else {
            Remove-ItemProperty -Path $path -Name 'EnableMulticast' -Force -ErrorAction SilentlyContinue
            $log.Add('llmnr: policy value removed (Windows default)')
        }
    }
}

# --- AutoRun / AutoPlay ----------------------------------------------------------
if ($Autorun -ne 'Keep') {
    $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'
    if ($Autorun -eq 'On') {
        if (-not (Read-Snapshot 'Autorun')) {
            Save-Snapshot 'Autorun' @((Get-RegistryEntry $path 'NoDriveTypeAutoRun' 'DWord'))
        }
        Set-RegistryEntry $path 'NoDriveTypeAutoRun' 'DWord' 255
        $log.Add('autorun: disabled for all drive types')
    }
    else {
        $saved = Read-Snapshot 'Autorun'
        if ($saved) {
            Restore-Entries $saved
            Remove-Snapshot 'Autorun'
            $log.Add('autorun: previous value restored')
        }
        else {
            Remove-ItemProperty -Path $path -Name 'NoDriveTypeAutoRun' -Force -ErrorAction SilentlyContinue
            $log.Add('autorun: value removed (Windows default)')
        }
    }
}

# --- kernel paging executive -----------------------------------------------------
if ($PagingExecutive -ne 'Keep') {
    $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
    if ($PagingExecutive -eq 'On') {
        if (-not (Read-Snapshot 'PagingExecutive')) {
            Save-Snapshot 'PagingExecutive' @((Get-RegistryEntry $path 'DisablePagingExecutive' 'DWord'))
        }
        Set-RegistryEntry $path 'DisablePagingExecutive' 'DWord' 1
        $log.Add('memory: kernel paging executive stays in RAM (reboot to apply)')
    }
    else {
        $saved = Read-Snapshot 'PagingExecutive'
        if ($saved) {
            Restore-Entries $saved
            Remove-Snapshot 'PagingExecutive'
            $log.Add('memory: previous paging executive value restored')
        }
        else {
            Remove-ItemProperty -Path $path -Name 'DisablePagingExecutive' -Force -ErrorAction SilentlyContinue
            $log.Add('memory: paging executive at Windows default')
        }
    }
}

# --- automatic maintenance -------------------------------------------------------
if ($Maintenance -ne 'Keep') {
    $path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance'
    if ($Maintenance -eq 'On') {
        if (-not (Read-Snapshot 'Maintenance')) {
            Save-Snapshot 'Maintenance' @((Get-RegistryEntry $path 'MaintenanceDisabled' 'DWord'))
        }
        Set-RegistryEntry $path 'MaintenanceDisabled' 'DWord' 1
        $log.Add('maintenance: automatic maintenance off (defrag/cleanup run manually)')
    }
    else {
        $saved = Read-Snapshot 'Maintenance'
        if ($saved) {
            Restore-Entries $saved
            Remove-Snapshot 'Maintenance'
            $log.Add('maintenance: previous value restored')
        }
        else {
            Remove-ItemProperty -Path $path -Name 'MaintenanceDisabled' -Force -ErrorAction SilentlyContinue
            $log.Add('maintenance: Windows default automatic maintenance')
        }
    }
}

# --- clear pagefile at shutdown --------------------------------------------------
if ($ClearPagefile -ne 'Keep') {
    $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
    if ($ClearPagefile -eq 'On') {
        if (-not (Read-Snapshot 'ClearPagefile')) {
            Save-Snapshot 'ClearPagefile' @((Get-RegistryEntry $path 'ClearPageFileAtShutdown' 'DWord'))
        }
        Set-RegistryEntry $path 'ClearPageFileAtShutdown' 'DWord' 1
        $log.Add('memory: pagefile cleared at shutdown (shutdown takes longer)')
    }
    else {
        $saved = Read-Snapshot 'ClearPagefile'
        if ($saved) {
            Restore-Entries $saved
            Remove-Snapshot 'ClearPagefile'
            $log.Add('memory: previous pagefile shutdown value restored')
        }
        else {
            Remove-ItemProperty -Path $path -Name 'ClearPageFileAtShutdown' -Force -ErrorAction SilentlyContinue
            $log.Add('memory: pagefile at Windows default')
        }
    }
}

# --- Windows Script Host ---------------------------------------------------------
if ($Wsh -ne 'Keep') {
    $path = 'HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings'
    if ($Wsh -eq 'On') {
        if (-not (Read-Snapshot 'Wsh')) {
            Save-Snapshot 'Wsh' @((Get-RegistryEntry $path 'Enabled' 'DWord'))
        }
        Set-RegistryEntry $path 'Enabled' 'DWord' 0
        $log.Add('script host: Windows Script Host disabled (security trade-off; .vbs/.js scripts stop)')
    }
    else {
        $saved = Read-Snapshot 'Wsh'
        if ($saved) {
            Restore-Entries $saved
            Remove-Snapshot 'Wsh'
            $log.Add('script host: previous value restored')
        }
        else {
            Remove-ItemProperty -Path $path -Name 'Enabled' -Force -ErrorAction SilentlyContinue
            $log.Add('script host: Windows default (Windows Script Host enabled)')
        }
    }
}

if (-not $log.Count) { $log.Add('nothing selected') }
$log | ForEach-Object { Write-Output $_ }
