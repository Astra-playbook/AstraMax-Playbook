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
    'Configuration\Tasks\debloat.yml',
    'Configuration\Tasks\postinstall.yml',
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
    'Executables\PostInstall\Astra-PostInstall.cmd',
    'Executables\PostInstall\PostInstall.ps1',
    'Executables\PostInstall\PostInstallGui.ps1',
    'Executables\PostInstall\Catalog.ps1',
    'Executables\PostInstall\AstraMaxPostInstall.exe',
    'Executables\PostInstall\Modules\_Common.ps1',
    'Executables\PostInstall\Modules\01-PowerPlan.ps1',
    'Executables\PostInstall\Modules\21-Wallpaper.ps1',
    'Executables\PostInstall\Modules\26-MouseAcceleration.ps1',
    'Executables\PostInstall\Modules\41-StoreAutoUpdate.ps1',
    'Executables\PostInstall\Modules\73-NvidiaTools.ps1',
    'Executables\PostInstall\Modules\74-NvidiaTelemetry.ps1',
    'Executables\PostInstall\Modules\75-Spotlight.ps1',
    'Executables\PostInstall\Modules\76-Scoobe.ps1',
    'Executables\PostInstall\Modules\77-StartRecent.ps1',
    'Executables\PostInstall\Modules\78-SmartScreen.ps1',
    'Executables\PostInstall\Modules\79-Llmnr.ps1',
    'Executables\PostInstall\Modules\80-Autorun.ps1',
    'Executables\PostInstall\Modules\81-SecurityNotifications.ps1',
    'Executables\PostInstall\Modules\82-CloudClipboard.ps1',
    'Executables\PostInstall\Modules\83-GameBarTips.ps1',
    'Executables\PostInstall\Modules\84-OnlineSpeech.ps1',
    'Executables\PostInstall\Modules\85-InkTyping.ps1',
    'Executables\PostInstall\Modules\86-LanguageList.ps1',
    'Executables\PostInstall\Modules\87-TailoredExperiences.ps1',
    'Executables\PostInstall\Modules\88-StartRecommendations.ps1',
    'Executables\PostInstall\Modules\89-HiddenFiles.ps1',
    'Executables\PostInstall\Modules\90-FullPath.ps1',
    'Executables\PostInstall\Modules\91-TaskbarSmallIcons.ps1',
    'Executables\PostInstall\Modules\92-HoverDelay.ps1',
    'Executables\PostInstall\Modules\93-KeyboardRepeat.ps1',
    'Executables\PostInstall\Modules\94-AudioDucking.ps1',
    'Executables\PostInstall\Modules\95-WerUi.ps1',
    'Executables\PostInstall\Modules\96-PagingExecutive.ps1',
    'Executables\PostInstall\Modules\97-Maintenance.ps1',
    'Executables\PostInstall\Modules\98-RestartApps.ps1',
    'Executables\PostInstall\Modules\99-ClearPagefile.ps1',
    'Executables\PostInstall\Modules\100-Wsh.ps1',
    'Executables\Security.ps1',
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
