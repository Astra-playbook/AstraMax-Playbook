[CmdletBinding()]
param(
    [switch]$Siege,
    [switch]$Fortnite,
    [switch]$Cod,
    [switch]$Apex,
    [switch]$CS2,
    [ValidateSet('On','Off','Status')] [string]$Mode = 'On',
    [string]$InstallDirectory,
    [switch]$All,
    [switch]$ApplyLaunchOptions,
    [switch]$Detect
)

$ErrorActionPreference = 'Stop'
if ($All) {
    $Siege = $true
    $Fortnite = $true
    $Cod = $true; $Apex = $true; $CS2 = $true
}

$applied = New-Object System.Collections.Generic.List[string]
$launchDir = 'C:\AstraMax\LaunchOptions'

function Set-ExeProfile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $gpu = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    if (-not (Test-Path -LiteralPath $gpu)) { New-Item -Path $gpu -Force | Out-Null }
    $old = (Get-ItemProperty -LiteralPath $gpu -Name $Path -ErrorAction SilentlyContinue).$Path
    if (-not (@($script:ProfileBackup.Exes | Where-Object { $_.Path -eq $Path }).Count)) {
        $script:ProfileBackup.Exes += [pscustomobject]@{ Path = $Path; Value = $old }
        Save-ProfileBackup
    }
    $tokens = @(([string]$old -split ';') | Where-Object { $_ -and $_ -notmatch '^GpuPreference=' })
    $value = (@($tokens) + 'GpuPreference=2') -join ';'
    Set-ItemProperty -Path $gpu -Name $Path -Value ($value + ';') -Type String -Force
    $applied.Add("exe: $Path")
}

function Get-SteamLibraries {
    $libs = @()
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction SilentlyContinue).SteamPath
    if ($steam) {
        $steam = $steam -replace '/', '\'
        $libs += $steam
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            foreach ($m in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"path"\s+"([^"]+)"')) {
                $libs += ($m.Groups[1].Value -replace '\\\\', '\')
            }
        }
    }
    $libs | Sort-Object -Unique
}

function Find-Siege {
    $found = @()
    $ubisoft = Join-Path ${env:ProgramFiles(x86)} 'Ubisoft\Ubisoft Game Launcher\games'
    $candidates = @(
        (Join-Path $ubisoft "Tom Clancy's Rainbow Six Siege\RainbowSix.exe")
    )
    $candidates += @(Find-SteamGame -AppIds '359550' -ExeNames 'RainbowSix.exe')
    if ($InstallDirectory) { $candidates += (Join-Path $InstallDirectory 'RainbowSix.exe') }
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { $found += $c }
    }
    if (-not $found.Count -and (Test-Path -LiteralPath $ubisoft)) {
        $found = @(Get-ChildItem -LiteralPath $ubisoft -Filter 'RainbowSix.exe' -Recurse -Depth 3 |
            ForEach-Object { $_.FullName })
    }
    $found | Sort-Object -Unique
}

function Find-Fortnite {
    $found = @()
    $dat = Join-Path $env:ProgramData 'Epic\UnrealEngineLauncher\LauncherInstalled.dat'
    if (Test-Path -LiteralPath $dat) {
        try {
            $json = Get-Content -LiteralPath $dat -Raw | ConvertFrom-Json
            foreach ($install in $json.InstallationList) {
                if ($install.AppName -like 'Fortnite*') {
                    $exe = Join-Path $install.InstallLocation 'FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe'
                    if (Test-Path -LiteralPath $exe) { $found += $exe }
                }
            }
        }
        catch { }
    }
    $fallback = Join-Path $env:ProgramFiles 'Epic Games\Fortnite\FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe'
    if (Test-Path -LiteralPath $fallback) { $found += $fallback }
    if ($InstallDirectory) {
        $exe = Join-Path $InstallDirectory 'FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe'
        if (Test-Path -LiteralPath $exe) { $found += [IO.Path]::GetFullPath($exe) }
    }
    $found | Sort-Object -Unique
}

function Find-SteamGame {
    param([string[]]$AppIds, [string[]]$ExeNames)
    foreach ($lib in Get-SteamLibraries) {
        foreach ($id in $AppIds) {
            $manifest = Join-Path $lib "steamapps\appmanifest_$id.acf"
            if (-not (Test-Path -LiteralPath $manifest)) { continue }
            $m = [regex]::Match((Get-Content -LiteralPath $manifest -Raw), '"installdir"\s+"([^"]+)"')
            if (-not $m.Success -or $m.Groups[1].Value -match '[\\/]|^\.\.?$') { continue }
            $dir = Join-Path $lib ('steamapps\common\' + $m.Groups[1].Value)
            foreach ($exeName in $ExeNames) {
                $exe = Join-Path $dir $exeName
                if (Test-Path -LiteralPath $exe) { $exe }
            }
        }
    }
}

function Find-AdditionalGame {
    param([string]$Game)
    $names = switch ($Game) { 'Cod' { 'cod.exe' } 'Apex' { 'r5apex.exe'; 'r5apex_dx12.exe' } 'CS2' { 'game\bin\win64\cs2.exe' } }
    $ids = switch ($Game) { 'Cod' { '1938090' } 'Apex' { '1172470' } 'CS2' { '730' } }
    $found = @(Find-SteamGame -AppIds $ids -ExeNames $names)
    if ($Game -eq 'Cod') {
        foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
            foreach ($folder in @('Call of Duty','Call of Duty\_retail_')) {
                $exe = Join-Path $base ($folder + '\cod.exe')
                if (Test-Path -LiteralPath $exe) { $found += $exe }
            }
        }
    }
    if ($InstallDirectory) {
        foreach ($name in $names) {
            $exe = Join-Path $InstallDirectory $name
            if (Test-Path -LiteralPath $exe) { $found += [IO.Path]::GetFullPath($exe) }
        }
    }
    $found | Sort-Object -Unique
}

function Save-ProfileBackup {
    New-Item -ItemType Directory -Path (Split-Path $script:ProfileBackupFile -Parent) -Force | Out-Null
    $script:ProfileBackup | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $script:ProfileBackupFile -Encoding UTF8
}

function Set-ExistingIniValues {
    param([string]$File, [string]$Section, [System.Collections.IDictionary]$Pairs)
    $text = [IO.File]::ReadAllText($File)
    $active = ''; $changed = $false; $updated = @()
    $parts = [regex]::Split($text, '(\r\n|\n|\r)')
    for ($i = 0; $i -lt $parts.Length; $i += 2) {
        $line = $parts[$i]
        if ($line -match '^\s*\[([^\]]+)\]\s*$') { $active = $Matches[1]; continue }
        if ($active -ne $Section -or $line -notmatch '^\s*([^=;#]+?)\s*=(.*)$') { continue }
        $key = $Matches[1]; $old = $Matches[2]
        if (-not $Pairs.Contains($key)) { continue }
        if ($Mode -eq 'On' -and -not @($script:ProfileBackup.Config | Where-Object { $_.File -eq $File -and $_.Section -eq $Section -and $_.Key -eq $key }).Count) {
            $script:ProfileBackup.Config += [pscustomobject]@{ File = $File; Section = $Section; Key = $key; Value = $old }
            Save-ProfileBackup
        }
        $parts[$i] = $key + '=' + $Pairs[$key]
        $updated += $key
        $changed = $true
    }
    if ($changed) { [IO.File]::WriteAllText($File, ($parts -join ''), (New-Object Text.UTF8Encoding($false))); $applied.Add("config: $File") }
    $updated
}

function Update-FortniteConfig {
    $ini = Join-Path $env:LOCALAPPDATA 'FortniteGame\Saved\Config\WindowsClient\GameUserSettings.ini'
    if (-not (Test-Path -LiteralPath $ini)) {
        $applied.Add('fortnite config: not created yet, launch the game once')
        return
    }
    Set-ExistingIniValues -File $ini -Section '/Script/FortniteGame.FortniteGameUserSettings' -Pairs ([ordered]@{ bUseVSync = 'False'; bUseDynamicResolution = 'False' }) | Out-Null
}

function Update-SiegeConfig {
    $root = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'My Games\Rainbow Six - Siege'
    if (-not (Test-Path -LiteralPath $root)) {
        $applied.Add('siege config: not created yet, launch the game once')
        return
    }
    foreach ($file in (Get-ChildItem -LiteralPath $root -Filter 'GameSettings.ini' -Recurse -Depth 2)) {
        Set-ExistingIniValues -File $file.FullName -Section 'DISPLAY' -Pairs ([ordered]@{ VSync = '0' }) | Out-Null
    }
}

function Get-LaunchConfig {
    $path = Join-Path $PSScriptRoot 'LaunchOptions.json'
    if (-not (Test-Path -LiteralPath $path)) { $path = 'C:\AstraMax\LaunchOptions.json' }
    if (Test-Path -LiteralPath $path) {
        try { return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json }
        catch { $applied.Add("launch options: cannot parse $path, using defaults") }
    }
    return [pscustomobject]@{
        Siege    = [pscustomobject]@{ AppId = '359550'; UbisoftGameId = '635'; Options = '' }
        Fortnite = [pscustomobject]@{ Options = '' }
    }
}

function Set-SteamLaunchOptions {
    param([string]$AppId, [string]$Options)
    if (-not $AppId -or -not $Options) { return }
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) {
        $applied.Add('steam launch options: Steam not installed')
        return
    }
    if (Get-Process -Name steam -ErrorAction SilentlyContinue) {
        $applied.Add('steam launch options: Steam is running, close it and re-run')
        return
    }
    $steam = $steam -replace '/', '\'
    $userdata = Join-Path $steam 'userdata'
    if (-not (Test-Path -LiteralPath $userdata)) {
        $applied.Add('steam launch options: no userdata folder found')
        return
    }

    $quoted = '"' + $AppId + '"'
    $patched = 0
    foreach ($ud in @(Get-ChildItem -LiteralPath $userdata -Directory -ErrorAction SilentlyContinue)) {
        $cfg = Join-Path $ud.FullName 'config\localconfig.vdf'
        if (-not (Test-Path -LiteralPath $cfg)) { continue }
        $text = [System.IO.File]::ReadAllText($cfg)

        $appsIdx = $text.IndexOf('"apps"')
        if ($appsIdx -lt 0) { continue }

        # Find the app id key whose next non-space token is an opening brace
        $search = $appsIdx
        $braceStart = -1
        while ($true) {
            $idx = $text.IndexOf($quoted, $search)
            if ($idx -lt 0) { break }
            $after = $idx + $quoted.Length
            $candidate = $text.IndexOf('{', $after)
            if ($candidate -lt 0) { break }
            if ($text.Substring($after, $candidate - $after).Trim() -eq '') {
                $braceStart = $candidate
                break
            }
            $search = $after
        }
        if ($braceStart -lt 0) { continue }

        $depth = 0
        $end = -1
        for ($i = $braceStart; $i -lt $text.Length; $i++) {
            $c = $text[$i]
            if ($c -eq '{') { $depth++ }
            elseif ($c -eq '}') {
                $depth--
                if ($depth -eq 0) { $end = $i; break }
            }
        }
        if ($end -lt 0) { continue }

        $block = $text.Substring($braceStart, $end - $braceStart + 1)
        $braceLine = $text.LastIndexOf("`n", $braceStart)
        $braceIndent = ''
        if ($braceLine -ge 0) {
            $braceIndent = ($text.Substring($braceLine + 1, $braceStart - $braceLine - 1) -replace '[^ \t].*$', '')
        }
        $indentMatch = [regex]::Match($block, '(?m)^([ \t]+)"')
        $keyIndent = if ($indentMatch.Success) { $indentMatch.Groups[1].Value } else { $braceIndent + '    ' }

        if ($block -match '"LaunchOptions"\s+"[^"]*"') {
            $newBlock = [regex]::Replace($block, '"LaunchOptions"\s+"[^"]*"', '"LaunchOptions" "' + $Options + '"', 1)
        }
        else {
            $newBlock = $block.Insert(1, "`r`n$keyIndent`"LaunchOptions`" `"$Options`"")
        }
        if ($newBlock -eq $block) { continue }

        # localconfig.vdf is cloud-synced, so keep a one-time local backup
        $backup = $cfg + '.astra-backup'
        if (-not (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $cfg -Destination $backup -Force }
        $newText = $text.Substring(0, $braceStart) + $newBlock + $text.Substring($end + 1)
        [System.IO.File]::WriteAllText($cfg, $newText, (New-Object System.Text.UTF8Encoding($false)))
        $patched++
    }

    if ($patched) { $applied.Add("steam launch options: $AppId -> $Options ($patched profile(s))") }
    else { $applied.Add('steam launch options: app block not found, set them in the Steam UI') }
}

function Set-UbisoftLaunchShortcut {
    param([string]$GameId)
    if (-not $GameId) { return }
    $url = "uplay://launch/$GameId/0"
    $file = Join-Path $launchDir 'Rainbow Six Siege (Astra).url'
    $lines = @('[InternetShortcut]', "URL=$url")
    [System.IO.File]::WriteAllText($file, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
    $desktop = [Environment]::GetFolderPath('Desktop')
    if ($desktop) {
        $target = Join-Path $desktop 'Rainbow Six Siege (Astra).url'
        Copy-Item -LiteralPath $file -Destination $target -Force
        $applied.Add("siege shortcut: $target")
    }
}

function Write-LaunchInstructions {
    param([string]$Game, [string]$Options)
    New-Item -ItemType Directory -Path $launchDir -Force | Out-Null
    $shown = if ($Options) { $Options } else { '(none yet - add them to C:\AstraMax\LaunchOptions.json)' }

    if ($Game -eq 'Siege') {
        $file = Join-Path $launchDir 'Siege.txt'
        $paste = if ($Options) { "  -> Launch arguments -> paste: $Options" }
                 else { "  -> Launch arguments -> nothing to paste yet; add flags in C:\AstraMax\LaunchOptions.json first" }
        $body = @"
Rainbow Six Siege - launch arguments
====================================
Configured options: $shown

Ubisoft Connect (the copy Astra cannot write for you):
  Games -> Tom Clancy's Rainbow Six Siege -> Manage -> Properties
$paste
  -> Save. The field is per game and stored inside Ubisoft Connect,
     so this one step stays manual.

No launch flags are supplied by default. Use the game's settings for VSync,
render mode and latency features. Add only publisher-documented arguments
supported by your installed version; clear custom arguments if launch fails.

Steam:
  Library -> right-click Siege -> Properties -> Launch Options -> paste the options.
  Steam adds -uplay_steam_mode automatically; keep it if it is already there.
  Astra writes these options into Steam's localconfig.vdf when Steam is closed,
  using the values in C:\AstraMax\LaunchOptions.json.

Astra also drops "Rainbow Six Siege (Astra).url" on your desktop. It opens
uplay://launch/635/0, which starts the game straight from Ubisoft Connect
without the home screen. Arguments set in Properties still apply.

Edit C:\AstraMax\LaunchOptions.json and re-run "SIEGE UBI ARGS" in the
Post Install app to change the options later.
"@
        [System.IO.File]::WriteAllText($file, $body, (New-Object System.Text.UTF8Encoding($false)))
        $applied.Add("siege launch options: $file")
    }
    else {
        $file = Join-Path $launchDir 'Fortnite.txt'
        $body = @"
Fortnite - launch options
=========================
Configured options: $shown

Epic Games Launcher:
  Settings (gear icon) -> scroll down to Fortnite
  -> tick "Additional Command Line Arguments" -> paste the options -> restart Fortnite.

The Epic launcher stores this per game, so Astra cannot write it for you.
No launch flags are supplied by default. Select rendering and latency settings
inside Fortnite. Add only arguments documented for your installed version.
"@
        [System.IO.File]::WriteAllText($file, $body, (New-Object System.Text.UTF8Encoding($false)))
        $applied.Add("fortnite launch options: $file")
    }
}

function Apply-LaunchOptions {
    param([bool]$DoSiege, [bool]$DoFortnite)
    $cfg = Get-LaunchConfig
    if ($DoSiege) {
        $options = [string]$cfg.Siege.Options
        $appId = [string]$cfg.Siege.AppId
        $ubiId = [string]$cfg.Siege.UbisoftGameId
        if (-not $ubiId) { $ubiId = '635' }
        Set-SteamLaunchOptions -AppId $appId -Options $options
        Set-UbisoftLaunchShortcut -GameId $ubiId
        Write-LaunchInstructions -Game 'Siege' -Options $options
    }
    if ($DoFortnite) {
        $options = [string]$cfg.Fortnite.Options
        Write-LaunchInstructions -Game 'Fortnite' -Options $options
    }
}

function Restore-Profile {
    $gpu = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    foreach ($entry in @($script:ProfileBackup.Exes)) {
        $key = Get-Item -LiteralPath $gpu -ErrorAction SilentlyContinue
        $exists = $key -and ($key.GetValueNames() -contains $entry.Path)
        $current = if ($exists) { $key.GetValue($entry.Path) } else { '' }
        $tokens = @(([string]$current -split ';') | Where-Object { $_ -and $_ -notmatch '^GpuPreference=' })
        $original = @(([string]$entry.Value -split ';') | Where-Object { $_ -match '^GpuPreference=' })
        $value = (@($tokens) + @($original)) -join ';'
        if ($value -or $null -ne $entry.Value) {
            if (-not (Test-Path -LiteralPath $gpu)) { New-Item -Path $gpu -Force | Out-Null }
            Set-ItemProperty -LiteralPath $gpu -Name $entry.Path -Value $(if ($value) { $value + ';' } else { '' }) -Type String
        }
        elseif ($exists) { Remove-ItemProperty -LiteralPath $gpu -Name $entry.Path }
    }
    $pending = @()
    foreach ($group in @($script:ProfileBackup.Config | Group-Object File,Section)) {
        $first = $group.Group[0]
        if (-not (Test-Path -LiteralPath $first.File)) { $pending += @($group.Group); continue }
        $pairs = [ordered]@{}
        foreach ($entry in $group.Group) { $pairs[$entry.Key] = $entry.Value }
        $restored = @(Set-ExistingIniValues -File $first.File -Section $first.Section -Pairs $pairs)
        $pending += @($group.Group | Where-Object { $_.Key -notin $restored })
    }
    if ($pending.Count) {
        $script:ProfileBackup.Exes = @()
        $script:ProfileBackup.Config = $pending
        Save-ProfileBackup
        return $false
    }
    Remove-Item -LiteralPath $script:ProfileBackupFile -Force -ErrorAction Stop
    return $true
}

function Write-GameGuide {
    param([string]$Game)
    $guide = @(
        "$Game - Astra profile",
        'Automatic: per-game Windows high-performance GPU preference; no anti-cheat launchers or game binaries are changed.',
        'Siege/Fortnite: existing VSync values only; Fortnite dynamic resolution off. Display mode and quality are left alone.',
        'GPU preference only selects between GPUs; it is not an overclock or a guaranteed FPS improvement.',
        '',
        'Manual settings, using the options exposed by your current game version:',
        'NVIDIA GPU: enable in-game NVIDIA Reflex if available. Try On first; On + Boost uses more power.',
        'Do not stack driver Ultra Low Latency with in-game Reflex. AMD/Intel: do not invent a Reflex config key.',
        'Choose an in-game FPS cap your PC can sustain. Measure frame times and 1% lows; no universal cap fits every monitor.',
        'VRR/G-SYNC users should choose a cap below the display limit and follow their display/vendor pacing guidance.',
        'Let shader compilation finish. Do not delete shader caches on every boot.',
        'Keep signed GPU drivers current. Never disable anti-cheat, TPM, Secure Boot or security protection for these profiles.'
    )
    switch ($Game) {
        'Cod' { $guide += 'COD/Warzone: compare render scaling/DLSS/FSR and texture-streaming options in the in-game graphics menu; do not force RenderWorkerCount or video-memory values for unknown hardware.' }
        'Siege' { $guide += 'Siege: benchmark the renderers actually present in your installed version; no Vulkan/DX11 launch flag is added by this profile.' }
        'Fortnite' { $guide += 'Fortnite: select the currently supported Performance rendering option in-game if you want lower visual quality; Astra does not force a removed renderer or edit hidden engine flags.' }
        'Apex' { $guide += 'Apex: compare texture streaming budget to available VRAM in-game; do not use autoexec network-rate or anti-cheat flags.' }
        'CS2' { $guide += 'CS2: use its own video options and Reflex, not legacy CS:GO -threads/-high/-tickrate flags.' }
    }
    $guide += 'Sources: https://support.microsoft.com/en-us/windows/hardware/display-graphics/optimizations-for-windowed-games-in-windows-11'
    $guide += 'Sources: https://www.nvidia.com/en-us/geforce/news/reflex-low-latency-apex-legends-valorant-fortnite-cs2/'
    New-Item -ItemType Directory -Path $launchDir -Force | Out-Null
    $guide | Set-Content -LiteralPath (Join-Path $launchDir "$Game-Graphics.txt") -Encoding UTF8
}

$selected = @()
if ($Siege) { $selected += 'Siege' }; if ($Fortnite) { $selected += 'Fortnite' }
if ($Cod) { $selected += 'Cod' }; if ($Apex) { $selected += 'Apex' }; if ($CS2) { $selected += 'CS2' }
if ($Detect -and -not $selected.Count) { $selected = 'Siege','Fortnite','Cod','Apex','CS2' }
foreach ($game in $selected) {
    $exes = @(switch ($game) { 'Siege' { Find-Siege } 'Fortnite' { Find-Fortnite } default { Find-AdditionalGame $game } })
    if ($Detect) { if ($exes.Count) { $exes | ForEach-Object { "${game}: $_" } } else { "${game}: none" }; continue }
    $script:ProfileBackupFile = Join-Path $env:LOCALAPPDATA "AstraMax\Backups\Game-$game.json"
    $script:ProfileBackup = [pscustomobject]@{ Exes = @(); Config = @() }
    if (Test-Path -LiteralPath $script:ProfileBackupFile) {
        $script:ProfileBackup = Get-Content -LiteralPath $script:ProfileBackupFile -Raw | ConvertFrom-Json -ErrorAction Stop
        $script:ProfileBackup.Exes = @($script:ProfileBackup.Exes)
        $script:ProfileBackup.Config = @($script:ProfileBackup.Config)
    }
    if ($Mode -eq 'Status') {
        if (-not $exes.Count) { "OFF - $game not installed/detected; custom installs can use -InstallDirectory"; continue }
        $count = 0
        foreach ($exe in $exes) {
            $value = (Get-ItemProperty 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' -Name $exe -ErrorAction SilentlyContinue).$exe
            if ($value -match '(?:^|;)GpuPreference=2(?:;|$)') { $count++ }
        }
        if ($count -eq $exes.Count) { "ON - $game GPU preference set ($count exe); in-game settings are separate" }
        elseif ($count -eq 0) { "OFF - $game GPU preference not set" }
        else { "MIXED - $game preference on $count of $($exes.Count) executables" }
        continue
    }
    $names = @($exes + @($script:ProfileBackup.Exes | ForEach-Object { $_.Path }) | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_) } | Select-Object -Unique)
    if (@($names | Where-Object { Get-Process -Name $_ -ErrorAction SilentlyContinue }).Count) { $applied.Add("$game is running: close the game before changing/restoring its profile"); continue }
    if ($Mode -eq 'Off') {
        if (Test-Path -LiteralPath $script:ProfileBackupFile) {
            if (Restore-Profile) { $applied.Add("$game previous profile restored") }
            else { $applied.Add("$game partially restored: missing config files/keys retained in backup; rerun Off when available") }
        }
        else { $applied.Add("$game has no saved original profile; nothing changed") }
        continue
    }
    Write-GameGuide $game
    if (-not $exes.Count) { $applied.Add("$game not detected; guide prepared, rerun after install or use -InstallDirectory"); continue }
    foreach ($exe in $exes) { Set-ExeProfile $exe }
    if ($game -eq 'Siege') { Update-SiegeConfig }
    if ($game -eq 'Fortnite') { Update-FortniteConfig }
}
if ($Detect -or $Mode -eq 'Status') { return }
if ($ApplyLaunchOptions -and $Mode -eq 'On') { Apply-LaunchOptions -DoSiege $Siege.IsPresent -DoFortnite $Fortnite.IsPresent }
if (-not $selected.Count) { Write-Host 'No profile selected. Use -Siege, -Fortnite, -Cod, -Apex, -CS2 or -All.' }
$applied | ForEach-Object { Write-Output $_ }
