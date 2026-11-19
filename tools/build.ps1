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
    $Output = Join-Path $root 'Astra-V1.apbx'
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
    'Executables\Toolbox\Astra-Toolbox.exe',
    'Executables\Toolbox\Toolbox.dll',
    'Executables\Toolbox\Astra.Core.dll',
    'Executables\Toolbox\Toolbox.runtimeconfig.json',
    'Executables\Toolbox\Assets\gojo.ico',
    'Executables\Toolbox\Wallpapers\catalog.json',
    'Configuration\Tasks\exm-extras.yml',
    'Executables\Invoke-ToolboxTweak.ps1',
    'Executables\SystemInfo.ps1',
    'Executables\RestorePoint.ps1',
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
    Write-Warning 'StartAllBack_setup.exe is excluded from packaging; the public playbook downloads the vendor-signed installer instead.'
}

if (Test-Path $Output) {
    Remove-Item $Output -Force
}

$stage = Join-Path $env:TEMP ('astra-package-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
try {
    foreach ($file in Get-ChildItem $src -Recurse -File) {
        $relative = $file.FullName.Substring($src.Length + 1)
        if ($relative -match '^Executables\\(Astra-Max-Setup\.exe$|AstraTweaks\\|StartAllBack_setup\.exe$)' -or ($relative -like 'Executables\Toolbox\*' -and $file.Extension -eq '.cs')) { continue }
        $target = Join-Path $stage $relative
        New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $target
    }
    $packagedCount = (Get-ChildItem $stage -Recurse -File).Count
    $entries = Get-ChildItem $stage | ForEach-Object Name
    Push-Location $stage
    try { $buildLog = & $sevenZip a -t7z "-p$Password" -mhe=on -mx=9 -y $Output @entries 2>&1 }
    finally { Pop-Location }
}
finally {
    Remove-Item -LiteralPath $stage -Recurse -Force
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
if ($listText -notmatch 'Astra-Toolbox\.exe' -or $listText -notmatch 'Astra\.Core\.dll' -or $listText -notmatch 'gojo\.png' -or $listText -notmatch 'SystemInfo\.ps1' -or $listText -notmatch 'RestorePoint\.ps1') {
    throw 'The toolbox, full tweak engine, System helpers or Gojo wallpaper is missing from the archive'
}
if ($listText -match 'PostInstall|Astra-Max-Setup\.exe|AstraTweaks\\|StartAllBack_setup\.exe') {
    throw 'A retired control panel or the commercial StartAllBack installer is present in the archive'
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
    $packagedCount, ((Get-Item $Output).Length / 1MB), $Password
$listing |
    Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}' } |
    ForEach-Object { ($_ -split '\s+')[-1] } |
    Sort-Object

"SHA256: " + (Get-FileHash $Output -Algorithm SHA256).Hash
"Built:  $Output"
