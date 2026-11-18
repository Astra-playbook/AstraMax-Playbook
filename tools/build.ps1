#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Output,
    [string]$Password = 'malte'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$src  = Join-Path $root 'src'
if (-not $Output) {
    $Output = Join-Path $root 'AstraMax.apbx'
}
$sevenZip = Join-Path $PSScriptRoot '7zr.exe'

$required = @(
    'playbook.conf',
    'playbook.png',
    'Configuration\main.yml',
    'Configuration\Tasks\astra-app.yml',
    'Configuration\Tasks\astra-extras.yml',
    'Configuration\Tasks\startallback.yml',
    'Configuration\Tasks\debloat.yml',
    'Configuration\Tasks\qol.yml',
    'Configuration\Tasks\services.yml',
    'Configuration\Tasks\tweaks.yml',
    'Executables\Astra-Max-Setup.exe',
    'Executables\AstraTweaks\Astra.exe',
    'Executables\Cleanup.ps1',
    'Executables\Debloat.ps1',
    'Executables\GameProfiles.ps1',
    'Executables\HardwareTweaks.ps1',
    'Executables\PersonalWallpaper.ps1',
    'Executables\LiveWallpaper\AstraLive.cs',
    'Executables\LiveWallpaper\index.html',
    'Executables\LiveWallpaper\motion.js',
    'Executables\LiveWallpaper\LivelyInfo.json',
    'Configuration\Tasks\hardware.yml',
    'Configuration\Tasks\games\additional.yml',
    'Executables\Interrupts.ps1',
    'Executables\LaunchOptions.json',
    'Executables\Network.ps1',
    'Executables\NvidiaTools.ps1',
    'Executables\Restore.ps1',
    'Executables\Tweaks.ps1',
    'Executables\QoL.ps1',
    'Executables\Verify.ps1',
    'Executables\Wallpaper.ps1',
    'Executables\Astra-Wallpaper.png',
    'Executables\Astra-Wallpaper-RedPurple.png',
    'Executables\Redist\VisualCppRedist_AIO_x86_x64.exe',
    'Executables\Redist\directx_Jun2010_redist.exe',
    'Executables\Redist\windowsdesktop-runtime-8.0.34-win-x64.exe',
    'Executables\Security.ps1',
    'Executables\StartAllBack.ps1',
    'Configuration\Tasks\nvidia.yml',
    'Configuration\Tasks\extra-privacy.yml',
    'Configuration\Tasks\harden.yml'
)

foreach ($rel in $required) {
    $path = Join-Path $src $rel
    if (-not (Test-Path $path)) {
        throw "Missing required file: $path"
    }
}

if (-not (Test-Path $sevenZip)) {
    throw "7zr.exe not found: $sevenZip. Download the standalone console from https://www.7-zip.org/a/7zr.exe"
}

$startAllBack = Join-Path $src 'Executables\StartAllBack_setup.exe'
if (Test-Path $startAllBack) {
    Write-Warning 'StartAllBack_setup.exe is being bundled. It is commercial, per-user licensed third-party software; redistribution is your responsibility. It is gitignored, so it is not committed to the public repository.'
}

if (Test-Path $Output) {
    Remove-Item $Output -Force
}

# AME Wizard requires .apbx to be a 7z archive whose data and file list are
# AES-256 encrypted with the password 'malte'. A plain zip is rejected with
# "Playbook must be encrypted using 'malte' as the password."
$entries = Get-ChildItem $src | ForEach-Object { $_.Name }
Push-Location $src
try {
    $buildLog = & $sevenZip a -t7z "-p$Password" -mhe=on -mx=9 -y $Output @entries 2>&1
}
finally {
    Pop-Location
}
if ($LASTEXITCODE -ne 0) {
    throw "7-Zip failed with exit code $LASTEXITCODE`n$($buildLog -join "`n")"
}

$listing = & $sevenZip l "-p$Password" $Output 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Archive cannot be opened with password '$Password'`n$($listing -join "`n")"
}
$listText = $listing -join "`n"

if ($listText -notmatch '(?m)\splaybook\.conf\s*$') {
    throw 'playbook.conf is not at the archive root'
}
if ($listText -notmatch 'Astra-Max-Setup\.exe') {
    throw 'Astra-Max-Setup.exe is missing from the archive'
}
if ($listText -match 'PostInstall') {
    throw 'The retired post-install menu is still inside src; Astra is the only control panel'
}

# Expected to fail: proving the file list is encrypted, not just the data.
$ErrorActionPreference = 'SilentlyContinue'
$null = & $sevenZip l $Output 2>&1
$headersReadable = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = 'Stop'
if ($headersReadable) {
    throw 'Archive headers are readable without a password; -mhe=on did not take effect'
}

$null = & $sevenZip t "-p$Password" $Output 2>&1
if ($LASTEXITCODE -ne 0) {
    throw 'Archive failed its integrity test'
}

"Archive OK: {0} files, {1:N1} MB, 7z AES-256, headers encrypted, password '{2}'" -f `
    (Get-ChildItem $src -Recurse -File).Count, ((Get-Item $Output).Length / 1MB), $Password
$listing |
    Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}' } |
    ForEach-Object { ($_ -split '\s+')[-1] } |
    Sort-Object

"SHA256: " + (Get-FileHash $Output -Algorithm SHA256).Hash
"Built:  $Output"
