#requires -Version 5.1
param([Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$src = Join-Path $root 'src\Executables'
$toolbox = Join-Path $src 'Toolbox'
$zip = Join-Path $OutputDirectory 'Astra-Toolbox.zip'
$wallpaperZip = Join-Path $OutputDirectory 'Astra-Wallpapers.zip'
if ((Test-Path -LiteralPath $zip) -or (Test-Path -LiteralPath $wallpaperZip)) { throw 'Use a fresh output directory to preserve existing packages.' }
foreach ($file in 'Astra-Toolbox.exe','Toolbox.dll','Astra.Core.dll','Toolbox.runtimeconfig.json','Assets\gojo.ico','Wallpapers\catalog.json') {
    if (-not (Test-Path -LiteralPath (Join-Path $toolbox $file))) { throw "Required toolbox asset is missing: $file" }
}
$catalog = Get-Content -LiteralPath (Join-Path $toolbox 'Wallpapers\catalog.json') -Raw | ConvertFrom-Json
if ($catalog.Count -ne 9) { throw 'The nine-image wallpaper library is required.' }
foreach ($entry in $catalog) { if (-not (Test-Path -LiteralPath (Join-Path $toolbox ('Wallpapers\' + $entry.file)))) { throw "Wallpaper missing: $($entry.file)" } }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$work = Join-Path $env:TEMP ('AstraToolboxPackage-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
    $bundle = Join-Path $work 'Astra-Toolbox'
    $appDir = Join-Path $bundle 'Toolbox'
    New-Item -ItemType Directory -Path $appDir -Force | Out-Null
    Get-ChildItem -LiteralPath $toolbox | Where-Object Extension -ne '.cs' | Copy-Item -Destination $appDir -Recurse
    foreach ($file in 'Wallpaper.ps1','GameProfiles.ps1','LaunchOptions.json','SystemInfo.ps1','RestorePoint.ps1') { Copy-Item -LiteralPath (Join-Path $src $file) -Destination $bundle }
    $redist = Join-Path $bundle 'Redist'
    New-Item -ItemType Directory -Path $redist | Out-Null
    Copy-Item -LiteralPath (Join-Path $src 'Redist\windowsdesktop-runtime-8.0.34-win-x64.exe') -Destination $redist
    Compress-Archive -LiteralPath $bundle -DestinationPath $zip -CompressionLevel Optimal
    $wallpapers = Join-Path $work 'Wallpapers'
    Copy-Item -LiteralPath (Join-Path $toolbox 'Wallpapers') -Destination $wallpapers -Recurse
    Compress-Archive -LiteralPath $wallpapers -DestinationPath $wallpaperZip -CompressionLevel Optimal
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($zip)
    try {
        if (@($archive.Entries | Where-Object FullName -match 'Astra-Max-Setup|AstraTweaks|\.cs$').Count) { throw 'A retired application or toolbox source is present in the binary ZIP.' }
        foreach ($entry in $archive.Entries) {
            if (-not $entry.Name) { continue }
            $staged = Join-Path $work $entry.FullName
            $stream = $entry.Open()
            $sha = [Security.Cryptography.SHA256]::Create()
            try { $actual = ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
            finally { $stream.Dispose(); $sha.Dispose() }
            if ($actual -ne (Get-FileHash -LiteralPath $staged -Algorithm SHA256).Hash) { throw "ZIP verification failed: $($entry.FullName)" }
        }
    } finally { $archive.Dispose() }
    foreach ($file in $zip,$wallpaperZip) {
        "Built: $file"
        "SHA256: $((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash)"
        "Size: $((Get-Item -LiteralPath $file).Length) bytes"
    }
} finally { Remove-Item -LiteralPath $work -Recurse -Force }
