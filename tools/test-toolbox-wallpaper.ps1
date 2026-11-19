#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$temp = Join-Path $env:TEMP ('AstraWallpaperTest-' + [guid]::NewGuid().ToString('N'))
$registry = 'HKCU:\Software\AstraWallpaperTest-' + [guid]::NewGuid().ToString('N')
$originalLocal = $env:LOCALAPPDATA
New-Item -ItemType Directory -Path $temp | Out-Null
New-Item -Path $registry -Force | Out-Null
Add-Type -TypeDefinition 'namespace AstraWallpaperFixture { public static class Native { public static bool Succeed = true; public static string Path; public static bool SystemParametersInfo(uint action, uint param, string path, uint flags) { Path = path; return Succeed; } } }'
function Assert($Value, [string]$Message) { if (-not $Value) { throw $Message }; "PASS: $Message" }
try {
    $env:LOCALAPPDATA = $temp
    $source = Get-Content -LiteralPath (Join-Path $root 'src\Executables\Wallpaper.ps1') -Raw
    $source = $source.Replace('HKCU:\Control Panel\Desktop', $registry).Replace('AstraWallpaper.Native', 'AstraWallpaperFixture.Native')
    $apply = [scriptblock]::Create($source)
    $image = Join-Path $root 'src\Executables\Toolbox\Wallpapers\gojo.png'
    New-ItemProperty -Path $registry -Name Wallpaper -Value 'previous.png' -PropertyType String | Out-Null
    New-ItemProperty -Path $registry -Name WallpaperStyle -Value '6' -PropertyType String | Out-Null
    New-ItemProperty -Path $registry -Name Unrelated -Value 'keep' -PropertyType String | Out-Null
    & $apply -Image $image | Out-Null
    $snapshot = Join-Path $temp 'AstraPC\State\toolbox-wallpaper.json'
    $first = Get-Content -LiteralPath $snapshot -Raw
    Assert ((Get-ItemProperty $registry).WallpaperStyle -eq '10') 'apply uses fill fit in the isolated registry'
    & $apply -Image $image | Out-Null
    Assert ((Get-Content -LiteralPath $snapshot -Raw) -eq $first) 'reapplying preserves the first wallpaper snapshot'
    $restoreCall = $source.IndexOf("SystemParametersInfo(0x0014, 0, `$path")
    $restoreFit = $source.IndexOf("foreach (`$name in 'Wallpaper','WallpaperStyle','TileWallpaper')")
    Assert ($restoreFit -ge 0 -and $restoreFit -lt $restoreCall) 'restore sets the saved fit before notifying Windows'
    [AstraWallpaperFixture.Native]::Succeed = $false
    $failed = $false
    try { & $apply -Image $image -Restore | Out-Null } catch { $failed = $true }
    Assert ($failed -and (Test-Path $snapshot)) 'a failed Windows restore retains the wallpaper snapshot'
    [AstraWallpaperFixture.Native]::Succeed = $true
    & $apply -Image $image -Restore | Out-Null
    $values = Get-ItemProperty $registry
    Assert ($values.Wallpaper -eq 'previous.png' -and $values.WallpaperStyle -eq '6') 'restoration returns the exact original wallpaper and fit'
    Assert ($values.PSObject.Properties.Name -notcontains 'TileWallpaper' -and $values.Unrelated -eq 'keep') 'restore removes introduced values and preserves unrelated settings'
    Assert (-not (Test-Path $snapshot)) 'successful restore clears the completed snapshot'
    Assert ([AstraWallpaperFixture.Native]::Path -eq 'previous.png') 'native wallpaper API was replaced by a non-mutating fixture'
    'Wallpaper fixtures passed; the live desktop was not changed.'
} finally {
    $env:LOCALAPPDATA = $originalLocal
    Remove-Item -LiteralPath $registry -Recurse -Force
    Remove-Item -LiteralPath $temp -Recurse -Force
}
