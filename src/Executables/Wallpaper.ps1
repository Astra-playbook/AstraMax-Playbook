#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Image = (Join-Path $PSScriptRoot 'Astra-Wallpaper.png'),
    [switch]$Restore,
    [switch]$Status
)
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:LOCALAPPDATA 'AstraPC'
$stateFile = Join-Path $root 'State\toolbox-wallpaper.json'
$desktop = 'HKCU:\Control Panel\Desktop'
if ($Status) {
    [pscustomobject]@{ Wallpaper = (Get-ItemProperty -LiteralPath $desktop).Wallpaper; HasBackup = (Test-Path -LiteralPath $stateFile) }
    return
}
if (-not $Restore -and -not (Test-Path -LiteralPath $Image -PathType Leaf)) { throw "Wallpaper not found: $Image" }
if ($Restore -and -not (Test-Path -LiteralPath $stateFile)) { 'wallpaper: no saved wallpaper to restore'; return }
if (-not ('AstraWallpaper.Native' -as [type])) {
    Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
namespace AstraWallpaper {
    public static class Native {
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, string pvParam, uint fWinIni);
    }
}
'@
}
if ($Restore) {
    $state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
    $path = [string]$state.Wallpaper.Value
    foreach ($name in 'Wallpaper','WallpaperStyle','TileWallpaper') {
        $value = $state.$name
        if ($value.Existed) { New-ItemProperty -Path $desktop -Name $name -Value ([string]$value.Value) -PropertyType String -Force | Out-Null }
        else { Remove-ItemProperty -LiteralPath $desktop -Name $name -ErrorAction SilentlyContinue }
    }
    if (-not [AstraWallpaper.Native]::SystemParametersInfo(0x0014, 0, $path, 0x01 -bor 0x02)) { throw 'Windows could not restore the wallpaper.' }
    if (-not $state.Wallpaper.Existed) { Remove-ItemProperty -LiteralPath $desktop -Name 'Wallpaper' -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $stateFile
    'wallpaper: saved background and fit restored'
    return
}
if (-not (Test-Path -LiteralPath $stateFile)) {
    $state = @{}
    $key = Get-Item -LiteralPath $desktop
    foreach ($name in 'Wallpaper','WallpaperStyle','TileWallpaper') {
        $exists = $key.GetValueNames() -contains $name
        $state[$name] = @{ Existed = $exists; Value = $(if ($exists) { [string]$key.GetValue($name) } else { $null }) }
    }
    New-Item -ItemType Directory -Path (Split-Path $stateFile -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($stateFile, (ConvertTo-Json $state -Depth 3), (New-Object Text.UTF8Encoding($false)))
}
$destDir = Join-Path $root 'Wallpapers'
New-Item -ItemType Directory -Path $destDir -Force | Out-Null
$hash = (Get-FileHash -LiteralPath $Image -Algorithm SHA256).Hash.Substring(0,16)
$dest = Join-Path $destDir ($hash + [IO.Path]::GetExtension($Image))
if ([IO.Path]::GetFullPath($Image) -ne [IO.Path]::GetFullPath($dest)) { Copy-Item -LiteralPath $Image -Destination $dest -Force }
New-ItemProperty -Path $desktop -Name 'WallpaperStyle' -Value '10' -PropertyType String -Force | Out-Null
New-ItemProperty -Path $desktop -Name 'TileWallpaper' -Value '0' -PropertyType String -Force | Out-Null
if (-not [AstraWallpaper.Native]::SystemParametersInfo(0x0014, 0, $dest, 0x01 -bor 0x02)) { throw 'Windows could not apply the wallpaper.' }
New-ItemProperty -Path $desktop -Name 'Wallpaper' -Value $dest -PropertyType String -Force | Out-Null
"wallpaper: $dest"
