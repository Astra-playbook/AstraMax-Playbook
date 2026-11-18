#requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'
$log = New-Object System.Collections.Generic.List[string]

# StartAllBack is commercial, per-user licensed software. The feature option is
# the consent: an offline build can use a bundled signed setup; every other
# build downloads the official setup from the vendor. Astra does not
# redistribute the installer.
$tools = 'C:\AstraMax\Tools'
New-Item -ItemType Directory -Path $tools -Force | Out-Null
$setup = Join-Path $tools 'StartAllBack_setup.exe'
$bundled = Join-Path $PSScriptRoot 'StartAllBack_setup.exe'
$downloadUrl = 'https://www.startallback.com/download.php'

if (Test-Path -LiteralPath $bundled) {
    Copy-Item -LiteralPath $bundled -Destination $setup -Force
    $log.Add("startallback: bundled setup staged at $setup")
}
else {
    Remove-Item -LiteralPath $setup -Force -ErrorAction SilentlyContinue
    $log.Add('startallback: downloading the official setup from startallback.com')
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $setup -UseBasicParsing -TimeoutSec 90
    }
    catch {
        Remove-Item -LiteralPath $setup -Force -ErrorAction SilentlyContinue
        $log.Add("startallback: download failed ($($_.Exception.Message)); use the shortcut")
    }
}

if (Test-Path -LiteralPath $setup) {
    $sig = Get-AuthenticodeSignature -LiteralPath $setup
    $signed = $sig.Status -eq 'Valid' -and $sig.SignerCertificate -and $sig.SignerCertificate.Subject -match 'Zinukhov'
    if (-not $signed) {
        $log.Add("startallback: setup signature is $($sig.Status); not run")
        Remove-Item -LiteralPath $setup -Force -ErrorAction SilentlyContinue
    }
    else {
        $log.Add("startallback: setup verified ($($sig.SignerCertificate.Subject))")
        $proc = Start-Process -FilePath $setup -ArgumentList '/install', '/elevated', '/silent' -PassThru
        if (-not $proc) {
            $log.Add('startallback: setup could not start; use the shortcut')
        }
        elseif ($proc.WaitForExit(180000)) {
            $log.Add("startallback: setup finished (exit $($proc.ExitCode)); sign out to load the new shell")
        }
        else {
            $log.Add('startallback: setup did not finish in 3 minutes; finish it from the shortcut')
        }
    }
}

$readme = @'
StartAllBack
============

StartAllBack is paid third-party software from startallback.com with a
per-user license. It is not part of Windows and it is not covered by the
Astra playbook's undo tools.

Install: ticking the StartAllBack option downloads the official setup
from startallback.com, verifies its signature and installs it silently.
An offline build can use a bundled signed copy instead. If the download
or verification fails, the "Install StartAllBack" shortcut opens the
official page. Sign out after installing so the new Start menu and
taskbar load.

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
