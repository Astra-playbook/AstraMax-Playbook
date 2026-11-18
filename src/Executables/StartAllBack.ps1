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
$destinations = @((Join-Path $desktop 'Install StartAllBack.lnk'))
if (Test-Path -LiteralPath $startMenu) {
    $destinations += (Join-Path $startMenu 'Install StartAllBack.lnk')
}
foreach ($path in $destinations) {
    $lnk = $ws.CreateShortcut($path)
    if (Test-Path -LiteralPath $setup) {
        $lnk.TargetPath = $setup
        $lnk.WorkingDirectory = $tools
        $lnk.Description = 'Install StartAllBack (paid add-on)'
    }
    else {
        $lnk.TargetPath = $url
        $lnk.Description = 'Download StartAllBack (paid add-on)'
    }
    $lnk.Save()
}
$log.Add('startallback: install shortcut added to the desktop and Start menu')
$log.Add("startallback: notes at $(Join-Path $tools 'StartAllBack.txt')")
$log | ForEach-Object { Write-Output $_ }
