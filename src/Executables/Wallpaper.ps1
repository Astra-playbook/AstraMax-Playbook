#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Image = (Join-Path $PSScriptRoot 'Astra-Wallpaper.png')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Image)) {
    throw "Wallpaper not found: $Image"
}

$destDir = Join-Path $env:SystemRoot 'Web\Wallpaper\Astra'
New-Item -ItemType Directory -Path $destDir -Force | Out-Null
$dest = Join-Path $destDir 'astra-wallpaper.png'
Copy-Item -LiteralPath $Image -Destination $dest -Force

$desktop = 'HKCU:\Control Panel\Desktop'
foreach ($pair in @(
    @{ Name = 'Wallpaper'; Value = $dest },
    @{ Name = 'WallpaperStyle'; Value = '10' },
    @{ Name = 'TileWallpaper'; Value = '0' }
)) {
    New-ItemProperty -Path $desktop -Name $pair.Name -Value $pair.Value -PropertyType String -Force | Out-Null
}

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
[void][AstraWallpaper.Native]::SystemParametersInfo(0x0014, 0, $dest, 0x01 -bor 0x02)

"wallpaper: $dest"
