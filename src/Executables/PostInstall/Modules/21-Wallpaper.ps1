#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$assets = Join-Path (Split-Path $PSScriptRoot -Parent) 'Assets'
$red = Join-Path $assets 'Astra-Wallpaper-RedPurple.png'
$blue = Join-Path $assets 'Astra-Wallpaper.png'
$destDir = Join-Path $env:SystemRoot 'Web\Wallpaper\Astra'
$dest = Join-Path $destDir 'astra-wallpaper.png'

function Get-AstraTheme {
    if (-not (Test-Path -LiteralPath $dest)) { return 'none' }
    $current = (Get-FileHash -LiteralPath $dest -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
    if (-not $current) { return 'custom' }
    if ((Test-Path -LiteralPath $red) -and $current -eq (Get-FileHash -LiteralPath $red -Algorithm SHA256).Hash) { return 'red' }
    if ((Test-Path -LiteralPath $blue) -and $current -eq (Get-FileHash -LiteralPath $blue -Algorithm SHA256).Hash) { return 'blue' }
    return 'custom'
}

function Set-AstraTheme {
    param([string]$Image)
    if (-not (Test-Path -LiteralPath $Image)) { throw "Wallpaper asset missing: $Image" }
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    Copy-Item -LiteralPath $Image -Destination $dest -Force

    $desktop = 'HKCU:\Control Panel\Desktop'
    foreach ($pair in @(
        @{ Name = 'Wallpaper'; Value = $dest },
        @{ Name = 'WallpaperStyle'; Value = '10' },
        @{ Name = 'TileWallpaper'; Value = '0' }
    )) {
        Set-AstraText $desktop $pair.Name $pair.Value
    }

    if (-not ('AstraPostWallpaper' -as [type])) {
        Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
namespace AstraPostWallpaper {
    public static class Native {
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, string pvParam, uint fWinIni);
    }
}
'@
    }
    [void][AstraPostWallpaper.Native]::SystemParametersInfo(0x0014, 0, $dest, 0x01 -bor 0x02)
}

switch ($Mode) {
    'Status' {
        switch (Get-AstraTheme) {
            'red' { 'ON - red and purple theme' }
            'blue' { 'OFF - midnight blue theme' }
            'custom' { 'MIXED - a custom wallpaper is set' }
            default { 'OFF - no Astra wallpaper' }
        }
    }
    'On' {
        Set-AstraTheme $red
        'wallpaper: red and purple'
    }
    'Off' {
        Set-AstraTheme $blue
        'wallpaper: midnight blue'
    }
}
