#requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'
$log = New-Object System.Collections.Generic.List[string]

# StartAllBack is commercial, per-user licensed software. The playbook never
# installs it silently: it stages the setup (when bundled) and adds a shortcut.
$tools = 'C:\AstraMax\Tools'
New-Item -ItemType Directory -Path $tools -Force | Out-Null
$setup = Join-Path $tools 'StartAllBack_setup.exe'
$bundled = Join-Path $PSScriptRoot 'StartAllBack_setup.exe'
if (Test-Path -LiteralPath $bundled) {
    Copy-Item -LiteralPath $bundled -Destination $setup -Force
    $log.Add("startallback: setup staged at $setup")
}
else {
    $log.Add('startallback: setup not bundled; the shortcut opens startallback.com')
}

$readme = @'
StartAllBack
============

StartAllBack is paid third-party software from startallback.com with a
per-user license. It is not part of Windows and it is not covered by the
Astra playbook's undo tools.

Install: double-click "Install StartAllBack" on the desktop (or in the
Start menu) and follow its setup. Sign out afterwards so the new Start
menu and taskbar load.

About search: StartAllBack changes the Start menu and taskbar, not the
Windows search index. To make Start search itself lighter, enable the
Astra extras "Keep Start search local" and "Turn off Start cloud search"
options; they stop Bing and cloud results without touching local files.
'@
[IO.File]::WriteAllText((Join-Path $tools 'StartAllBack.txt'), $readme, [Text.Encoding]::UTF8)

$url = 'https://www.startallback.com/'
$ws = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath('Desktop')
$startMenu = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'
$hasSetup = Test-Path -LiteralPath $setup
$name = if ($hasSetup) { 'Install StartAllBack.lnk' } else { 'Install StartAllBack.url' }
$folders = @($desktop)
if (Test-Path -LiteralPath $startMenu) { $folders += $startMenu }
foreach ($folder in $folders) {
    # Remove either form so a re-run cannot leave a stale broken shortcut.
    Remove-Item -LiteralPath (Join-Path $folder 'Install StartAllBack.lnk') -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $folder 'Install StartAllBack.url') -Force -ErrorAction SilentlyContinue
    $path = Join-Path $folder $name
    if ($hasSetup) {
        $lnk = $ws.CreateShortcut($path)
        $lnk.TargetPath = $setup
        $lnk.WorkingDirectory = $tools
        $lnk.Description = 'Install StartAllBack (paid add-on)'
        $lnk.Save()
    }
    else {
        # A .lnk with an https target saves with an empty target; .url is the working form.
        $ini = "[InternetShortcut]`r`nURL=$url`r`nIconIndex=0`r`n"
        [IO.File]::WriteAllText($path, $ini, [Text.Encoding]::ASCII)
    }
}
$log.Add('startallback: install shortcut added to the desktop and Start menu')
$log.Add("startallback: notes at $(Join-Path $tools 'StartAllBack.txt')")
$log | ForEach-Object { Write-Output $_ }
