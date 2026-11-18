#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidateSet('CpuBoost','CpuEpp','PciePower','DiskIdle','DynamicTick','GpuScheduling','WindowedGaming')] [string]$Feature,
    [ValidateSet('On','Off','Status')] [string]$Mode = 'Status'
)
$ErrorActionPreference = 'Stop'
$backupDir = Join-Path $env:LOCALAPPDATA 'AstraMax\Backups'
$isCpu = $Feature -in 'CpuBoost','CpuEpp'
$isPowerPolicy = $Feature -in 'CpuBoost','CpuEpp','PciePower','DiskIdle'
if ($isPowerPolicy) {
    if (-not ('AstraPowerPolicy' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AstraPowerPolicy {
    [DllImport("powrprof.dll")] public static extern uint PowerGetActiveScheme(IntPtr root, out IntPtr scheme);
    [DllImport("powrprof.dll")] public static extern uint PowerReadACValueIndex(IntPtr root, ref Guid scheme, ref Guid sub, ref Guid setting, out uint value);
    [DllImport("kernel32.dll")] public static extern IntPtr LocalFree(IntPtr memory);
}
'@
    }
    $ptr = [IntPtr]::Zero
    if ([AstraPowerPolicy]::PowerGetActiveScheme([IntPtr]::Zero, [ref]$ptr) -ne 0) { throw 'Cannot read the active power scheme' }
    try { $scheme = [guid][Runtime.InteropServices.Marshal]::PtrToStructure($ptr, [type][guid]) }
    finally { [void][AstraPowerPolicy]::LocalFree($ptr) }
    $sub = switch ($Feature) {
        'PciePower' { [guid]'501a4d13-42af-4429-9fd1-a8218c268e20' }
        'DiskIdle' { [guid]'0012ee47-9041-4b5d-9b77-535fba8b1442' }
        default { [guid]'54533251-82be-4824-96c1-47b60b740d00' }
    }
    $setting = switch ($Feature) {
        'CpuBoost' { [guid]'be337238-0d82-4146-a960-4f3749d470c7' }
        'CpuEpp' { [guid]'36687f9e-e3a5-4dbf-b1dc-15eb381c6863' }
        'PciePower' { [guid]'ee12f906-d277-404b-b6da-e5fa1a576df5' }
        'DiskIdle' { [guid]'6738e2c4-e8a5-4a42-b16a-e040e769756e' }
    }
    $target = switch ($Feature) {
        'CpuBoost' { 2 }
        default { 0 }
    }
    $current = [uint32]0
    if ([AstraPowerPolicy]::PowerReadACValueIndex([IntPtr]::Zero, [ref]$scheme, [ref]$sub, [ref]$setting, [ref]$current) -ne 0) {
        'MIXED - this power policy is unavailable on the active scheme'
        return
    }
    $backup = Join-Path $backupDir "$Feature-$scheme.json"
}
elseif ($Feature -eq 'DynamicTick') {
    $bcd = @(& bcdedit /enum '{current}' 2>&1) -join "`n"
    $match = [regex]::Match($bcd, '(?im)^\s*disabledynamictick\s+(Yes|No)\b')
    $current = if ($match.Success) { $match.Groups[1].Value.ToLower() } else { 'absent' }
    $enabled = $current -eq 'yes'
    $backup = Join-Path $backupDir 'DynamicTick.json'
}
else {
    $path = if ($Feature -eq 'GpuScheduling') { 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' } else { 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' }
    $name = if ($Feature -eq 'GpuScheduling') { 'HwSchMode' } else { 'DirectXUserGlobalSettings' }
    $key = Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
    $exists = $key -and ($key.GetValueNames() -contains $name)
    $current = if ($exists) { $key.GetValue($name) } else { $null }
    if ($Feature -eq 'GpuScheduling') { $target = 2; $enabled = $current -eq 2 }
    else { $enabled = [string]$current -match '(?:^|;)SwapEffectUpgradeEnable=1(?:;|$)' }
    $backup = Join-Path $backupDir "$Feature.json"
}
if ($Mode -eq 'Status') {
    if ($isPowerPolicy) {
        switch ($Feature) {
            'PciePower' {
                if ($current -eq $target) { 'ON - PCIe link state power management off (AC)' }
                else { "OFF - PCIe ASPM index $current" }
            }
            'DiskIdle' {
                if ($current -eq $target) { 'ON - hard disk idle timeout disabled (AC)' }
                else { "OFF - disk idle timeout $current seconds" }
            }
            default {
                if ($current -eq $target) { "ON - $Feature AC policy configured; firmware determines boost behavior" }
                else { "OFF - $Feature AC index $current" }
            }
        }
    }
    elseif ($Feature -eq 'DynamicTick') {
        if ($enabled) { 'ON - kernel dynamic tick disabled (reboot required)' }
        elseif ($current -eq 'absent') { 'OFF - Windows default (setting not present)' }
        else { "OFF - disabledynamictick $current" }
    }
    elseif ($enabled) {
        if ($Feature -eq 'GpuScheduling') { 'ON - HAGS requested; reboot and verify support in Graphics settings' }
        else { 'ON - windowed DX10/DX11 optimizations requested; restart games' }
    }
    else { "OFF - $Feature is not explicitly requested" }
    return
}
if ($Feature -in 'GpuScheduling','DynamicTick' -and -not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'This tweak needs elevation' }
if ($Mode -eq 'On') {
    if (-not (Test-Path -LiteralPath $backup)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        if ($isPowerPolicy) { $saved = @{ Index = $current } }
        elseif ($Feature -eq 'DynamicTick') { $saved = @{ Present = [bool]($current -ne 'absent'); Value = $(if ($current -ne 'absent') { $current } else { $null }) } }
        else { $saved = @{ Exists = [bool]$exists; Value = $current; Kind = $(if ($exists) { [string]$key.GetValueKind($name) } else { 'String' }) } }
        $saved | ConvertTo-Json | Set-Content -LiteralPath $backup -Encoding UTF8
    }
    if ($isPowerPolicy) {
        & powercfg /setacvalueindex $scheme $sub $setting $target | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Power policy write failed' }
    }
    elseif ($Feature -eq 'DynamicTick') {
        & bcdedit /set '{current}' disabledynamictick yes | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Boot configuration write failed' }
    }
    else {
        if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -Force | Out-Null }
        if ($Feature -eq 'GpuScheduling') { Set-ItemProperty $path $name -Value 2 -Type DWord }
        else {
            $tokens = @(([string]$current -split ';') | Where-Object { $_ -and $_ -notmatch '^SwapEffectUpgradeEnable=' })
            $text = (@($tokens) + 'SwapEffectUpgradeEnable=1') -join ';'
            Set-ItemProperty $path $name -Value ($text + ';') -Type String
        }
    }
}
else {
    if (-not (Test-Path -LiteralPath $backup)) { 'No previous setting saved for this policy/active scheme; nothing changed'; return }
    $saved = Get-Content -LiteralPath $backup -Raw | ConvertFrom-Json
    if ($isPowerPolicy) {
        & powercfg /setacvalueindex $scheme $sub $setting ([uint32]$saved.Index) | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Power policy restore failed' }
    }
    elseif ($Feature -eq 'DynamicTick') {
        if ($saved.Present) {
            & bcdedit /set '{current}' disabledynamictick ([string]$saved.Value) | Out-Null
        }
        else {
            & bcdedit /deletevalue '{current}' disabledynamictick | Out-Null
        }
        if ($LASTEXITCODE -ne 0) { throw 'Boot configuration restore failed' }
    }
    elseif ($Feature -eq 'WindowedGaming') {
        $tokens = @(([string]$current -split ';') | Where-Object { $_ -and $_ -notmatch '^SwapEffectUpgradeEnable=' })
        $original = @(([string]$saved.Value -split ';') | Where-Object { $_ -match '^SwapEffectUpgradeEnable=' })
        $text = (@($tokens) + @($original)) -join ';'
        if ($text -or $saved.Exists) {
            if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -Force | Out-Null }
            Set-ItemProperty $path $name -Value $(if ($text) { $text + ';' } else { '' }) -Type String
        }
        elseif ($exists) { Remove-ItemProperty $path $name }
    }
    elseif ($saved.Exists) {
        if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty $path $name -Value $saved.Value -Type $saved.Kind
    }
    elseif ($exists) { Remove-ItemProperty $path $name }
}
if ($isPowerPolicy) {
    & powercfg /setactive $scheme | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Power scheme refresh failed' }
}
if ($Mode -eq 'Off') { Remove-Item -LiteralPath $backup -Force }
if ($isPowerPolicy) {
    if ($isCpu) { "$Feature $Mode on AC only; monitor temperatures and benchmark frame times" }
    else { "$Feature $Mode on AC only; benchmark before keeping it" }
}
elseif ($Feature -eq 'DynamicTick') { "Dynamic tick $Mode; reboot required" }
elseif ($Feature -eq 'GpuScheduling') { "GPU scheduling $Mode configuration saved; reboot required, unsupported hardware may ignore it" }
else { "Windowed optimizations $Mode configuration saved; restart DX10/DX11 games (Auto HDR can override Off)" }
