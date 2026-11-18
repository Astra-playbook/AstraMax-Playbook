#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On','Off','Status')] [string]$Mode = 'Status',
    [switch]$Live,
    [switch]$PrepareOnly,
    [string]$Image,
    [string]$MotionFile,
    [string]$PackageDirectory
)
$ErrorActionPreference = 'Stop'
$personal = Join-Path ([Environment]::GetFolderPath('MyPictures')) 'Astra'
if (-not $PackageDirectory) { $PackageDirectory = Join-Path $personal 'Astra-Personal-Live' }
if (-not $Image) {
    foreach ($name in 'personal-wallpaper.png','astra-gojo-wallpaper.png') {
        $candidate = Join-Path $personal $name
        if (Test-Path -LiteralPath $candidate) { $Image = $candidate; break }
    }
}
if (-not $MotionFile) { $MotionFile = Join-Path $personal 'hair-motion.json' }
$backupDir = Join-Path $env:LOCALAPPDATA 'AstraMax\Backups'
$backup = Join-Path $backupDir $(if ($Live) { 'PersonalLive.json' } else { 'PersonalStatic.json' })
$desktopKey = 'HKCU:\Control Panel\Desktop'
$layoutFile = Join-Path $env:LOCALAPPDATA 'Lively Wallpaper\WallpaperLayout.json'
$startup = Join-Path ([Environment]::GetFolderPath('Startup')) 'AstraMax Personal Live.lnk'
$hostExe = Join-Path $PackageDirectory 'AstraLiveWallpaper.exe'
$logFile = Join-Path $env:LOCALAPPDATA 'AstraMax\Logs\live-wallpaper.log'

function Find-Lively {
    foreach ($path in @(
        (Join-Path $env:ProgramFiles 'Lively Wallpaper\Lively.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Lively Wallpaper\Lively.exe'),
        (Join-Path $env:LOCALAPPDATA 'Lively Wallpaper\Lively.exe')
    )) { if (Test-Path -LiteralPath $path) { return $path } }
}
function Read-Layout {
    if (Test-Path -LiteralPath $layoutFile) {
        $layout = Get-Content -LiteralPath $layoutFile -Raw | ConvertFrom-Json
        foreach ($entry in $layout) { if ($entry -and $entry.LivelyInfoPath) { $entry } }
    }
}
function Invoke-Lively {
    param([string]$Arguments)
    $process = Start-Process -FilePath $script:livelyExe -ArgumentList $Arguments -PassThru
    if (-not $process.WaitForExit(10000)) { throw 'Lively command has not exited; inspect the app before retrying' }
    if ($process.ExitCode -ne 0) { throw "Lively command failed: $($process.ExitCode)" }
}
function Set-StaticWallpaper {
    param([string]$Path, [string]$Style = '10', [string]$Tile = '0')
    if ($Path -and -not (Test-Path -LiteralPath $Path)) { throw "Saved wallpaper is missing: $Path" }
    if (-not ('AstraPersonalWallpaper' -as [type])) {
        Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public static class AstraPersonalWallpaper {
    [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern bool SystemParametersInfo(uint action, uint param, string value, uint flags);
}
'@
    }
    Set-ItemProperty $desktopKey 'WallpaperStyle' -Value $Style
    Set-ItemProperty $desktopKey 'TileWallpaper' -Value $Tile
    if (-not [AstraPersonalWallpaper]::SystemParametersInfo(20,0,$Path,3)) { throw 'Windows wallpaper update failed' }
}
function Save-Wallpaper {
    if (Test-Path -LiteralPath $backup) { return }
    $values = Get-ItemProperty -LiteralPath $desktopKey
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    @{ Wallpaper=$values.Wallpaper; Style=$values.WallpaperStyle; Tile=$values.TileWallpaper } | ConvertTo-Json | Set-Content -LiteralPath $backup -Encoding UTF8
}
function Get-FrameworkCompiler {
    foreach ($root in "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319", "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319") {
        $candidate = Join-Path $root 'csc.exe'
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    throw '.NET Framework 4 compiler not found; Windows 11 normally includes it'
}
function Compile-Host {
    $source = Join-Path $PSScriptRoot 'LiveWallpaper\AstraLive.cs'
    if (-not (Test-Path -LiteralPath $source)) { throw "Live wallpaper source missing: $source" }
    $csc = Get-FrameworkCompiler
    $arguments = @(
        '/nologo', '/target:winexe', '/optimize+', ('/out:"' + $hostExe + '"'),
        '/r:System.dll', '/r:System.Windows.Forms.dll', '/r:System.Drawing.dll', '/r:System.Web.Extensions.dll',
        ('"' + $source + '"')
    )
    & $csc $arguments
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $hostExe)) { throw "Live wallpaper build failed: csc exit $LASTEXITCODE" }
}
function Prepare-Package {
    if (-not $Image -or -not (Test-Path -LiteralPath $Image)) { throw "Import personal-wallpaper.png and hair-motion.json into $personal first" }
    $template = Join-Path $PSScriptRoot 'LiveWallpaper'
    New-Item -ItemType Directory -Path $PackageDirectory -Force | Out-Null
    foreach ($name in 'index.html','LivelyInfo.json','motion.js') { Copy-Item -LiteralPath (Join-Path $template $name) -Destination $PackageDirectory -Force }
    Copy-Item -LiteralPath $Image -Destination (Join-Path $PackageDirectory 'image.png') -Force
    if (Test-Path -LiteralPath $MotionFile) {
        $motion = Get-Content -LiteralPath $MotionFile -Raw | ConvertFrom-Json
        if (@($motion.points).Count -lt 3) { throw 'Hair mask requires at least three points in image pixels' }
        foreach ($point in $motion.points) {
            if (@($point).Count -ne 2 -or $point[0] -lt 0 -or $point[1] -lt 0) { throw 'Invalid hair mask point' }
        }
        $json = $motion | ConvertTo-Json -Depth 8
        [IO.File]::WriteAllText((Join-Path $PackageDirectory 'motion.json'), $json, (New-Object Text.UTF8Encoding($false)))
        [IO.File]::WriteAllText((Join-Path $PackageDirectory 'motion.js'), ('window.astraMotion = ' + ($motion | ConvertTo-Json -Depth 8 -Compress) + ';'), (New-Object Text.UTF8Encoding($false)))
    }
    else { Write-Output 'No hair-motion.json: the wallpaper stays static until a mask is supplied' }
    Compile-Host
}
function Get-HostProcesses {
    Get-Process -Name AstraLiveWallpaper -ErrorAction SilentlyContinue | Where-Object {
        try { $_.Path -eq $hostExe } catch { $false }
    }
}
function Stop-Host {
    foreach ($process in @(Get-HostProcesses)) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $startup) { Remove-Item -LiteralPath $startup -Force }
}
function Start-Host {
    if (-not (Test-Path -LiteralPath $hostExe)) { throw "Live wallpaper host missing: $hostExe" }
    Stop-Host
    $baseline = if (Test-Path -LiteralPath $logFile) { @(Get-Content -LiteralPath $logFile).Count } else { 0 }
    $process = Start-Process -FilePath $hostExe -ArgumentList @('--file', ('"' + $PackageDirectory + '"')) -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        Start-Sleep -Milliseconds 300
        if ($process.HasExited) { throw "Live wallpaper host exited with code $($process.ExitCode)" }
        if (Test-Path -LiteralPath $logFile) {
            $lines = @(Get-Content -LiteralPath $logFile -ErrorAction SilentlyContinue)
            $new = if ($lines.Count -gt $baseline) { $lines[$baseline..($lines.Count - 1)] } else { @() }
            if (@($new | Where-Object { $_ -match 'pinned wallpaper window at desktop level' }).Count) { return $process }
        }
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Live wallpaper did not confirm desktop placement; see $logFile"
}
function New-HostShortcut {
    $ws = New-Object -ComObject WScript.Shell
    $link = $ws.CreateShortcut($startup)
    $link.TargetPath = $hostExe
    $link.Arguments = '--file "' + $PackageDirectory + '"'
    $link.WorkingDirectory = $PackageDirectory
    $link.Description = 'Restore Astra live wallpaper (hair sway and glow pulse) at sign-in'
    $link.Save()
}
function Close-OwnLivelyEntry {
    param($Saved)
    if (-not $Saved -or -not $Saved.LibraryPath) { return $true }
    $active = @(Read-Layout | Where-Object { $_.LivelyInfoPath -eq $Saved.LibraryPath })
    if (-not $active.Count) { return $true }
    if (-not $script:livelyExe) { throw 'A Lively copy of this wallpaper is active and its executable is missing; close it manually' }
    foreach ($entry in $active) { Invoke-Lively ('closewp --monitor ' + $entry.LivelyScreen.Index) }
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        $remaining = @(Read-Layout | Where-Object { $_.LivelyInfoPath -eq $Saved.LibraryPath })
        if (-not $remaining.Count) { return $true }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    throw 'Lively has not confirmed closing the saved wallpaper; original backup retained'
}
if ($PrepareOnly) { Prepare-Package; "Prepared local package: $PackageDirectory"; return }
$livelyExe = Find-Lively
$livelyRunning = [bool](Get-Process -Name Lively -ErrorAction SilentlyContinue)
if ($Mode -eq 'Status') {
    if ($Live) {
        $hostProcess = @(Get-HostProcesses) | Select-Object -First 1
        if ($hostProcess -and (Test-Path -LiteralPath $startup)) {
            $memory = [math]::Round($hostProcess.WorkingSet64 / 1MB, 1)
            "ON - native Astra live wallpaper (hair sway, glow pulse) running, $memory MB RAM"
        }
        else {
            $saved = if (Test-Path -LiteralPath $backup) { Get-Content -LiteralPath $backup -Raw | ConvertFrom-Json } else { $null }
            $active = @(Read-Layout | Where-Object { $_.LivelyInfoPath -eq $saved.LibraryPath -and $saved.LibraryPath })
            if ($active.Count -and (Get-Process -Name Lively -ErrorAction SilentlyContinue)) { 'ON - legacy Lively personal wallpaper registered; applying again moves it to the native host' }
            else { 'OFF - personal live wallpaper not active; import local personal files to apply' }
        }
    }
    else {
        $current = (Get-ItemProperty -LiteralPath $desktopKey).Wallpaper
        $target = Join-Path $env:LOCALAPPDATA 'AstraMax\Wallpapers\personal.png'
        if ($current -eq $target) { 'ON - personal static wallpaper' } else { 'OFF - personal static wallpaper not selected' }
    }
    return
}
if ($Mode -eq 'Off') {
    if (-not (Test-Path -LiteralPath $backup)) { 'No saved original wallpaper; nothing changed'; return }
    $saved = Get-Content -LiteralPath $backup -Raw | ConvertFrom-Json
    if ($Live) {
        Stop-Host
        [void](Close-OwnLivelyEntry $saved)
        if ($livelyRunning -and @(Read-Layout | Where-Object { $_.LivelyInfoPath -ne $saved.LibraryPath }).Count) {
            'Another Lively wallpaper remains active; saved static wallpaper retained for a later restore'
            return
        }
    }
    Set-StaticWallpaper -Path $saved.Wallpaper -Style $saved.Style -Tile $saved.Tile
    Remove-Item -LiteralPath $backup -Force
    'Previous static wallpaper restored'
    return
}
if (-not $Live) {
    if (-not $Image -or -not (Test-Path -LiteralPath $Image)) { "Skipped: put personal-wallpaper.png in $personal, then rerun"; return }
    if (@(Get-HostProcesses).Count -or (Test-Path -LiteralPath $startup)) { Stop-Host }
    $liveBackup = Join-Path $backupDir 'PersonalLive.json'
    if ((Test-Path -LiteralPath $liveBackup) -and @(Read-Layout).Count) { & $PSCommandPath -Live -Mode Off }
    if ($livelyRunning -and @(Read-Layout).Count) { throw 'Another Lively wallpaper is active; close it before applying a static wallpaper' }
    Save-Wallpaper
    $folder = Join-Path $env:LOCALAPPDATA 'AstraMax\Wallpapers'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $target = Join-Path $folder 'personal.png'
    Copy-Item -LiteralPath $Image -Destination $target -Force
    Set-StaticWallpaper $target
    'Personal static wallpaper applied'
    return
}
if (-not $Image -or -not (Test-Path -LiteralPath $Image)) { "Skipped: put personal-wallpaper.png in $personal, then rerun"; return }
if ((Test-Path -LiteralPath $startup) -and -not (Test-Path -LiteralPath $backup)) { throw 'Astra startup shortcut already exists without its backup; inspect it before replacing' }
Save-Wallpaper
$saved = Get-Content -LiteralPath $backup -Raw | ConvertFrom-Json
[void](Close-OwnLivelyEntry $saved)
if ($livelyRunning -and @(Read-Layout).Count) { throw 'Another Lively wallpaper is active and would cover the native wallpaper; close it first, then rerun' }
Stop-Host
Prepare-Package
$hostProcess = Start-Host
New-HostShortcut
$memory = [math]::Round($hostProcess.WorkingSet64 / 1MB, 1)
"Personal live wallpaper applied by the lightweight Astra host (about $memory MB RAM). Hair sway and the red/blue glow pulse run at 24 fps and pause behind fullscreen apps."
