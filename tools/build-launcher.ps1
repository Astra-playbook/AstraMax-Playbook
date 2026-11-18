#requires -Version 5.1
[CmdletBinding()]
param()

# Builds the tiny elevated launcher that starts PostInstallGui.ps1 without a
# console window. csc.exe ships with .NET Framework on every Windows 11 install.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$out = Join-Path $root 'src\Executables\PostInstall\AstraMaxPostInstall.exe'
$csc = Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $csc)) {
    $csc = Join-Path $env:SystemRoot 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
}
if (-not (Test-Path -LiteralPath $csc)) { throw 'csc.exe not found; install the .NET Framework' }

$work = Join-Path $env:TEMP ('astra-launcher-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null

$code = @'
using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

static class Program
{
    [STAThread]
    static void Main()
    {
        string dir = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location);
        string script = Path.Combine(dir, "PostInstallGui.ps1");
        if (!File.Exists(script))
        {
            MessageBox.Show("PostInstallGui.ps1 is missing next to this program.", "Astra");
            return;
        }
        string ps = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe");
        ProcessStartInfo psi = new ProcessStartInfo();
        psi.FileName = ps;
        psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + script + "\"";
        psi.WorkingDirectory = dir;
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        try { Process.Start(psi); }
        catch (Exception ex) { MessageBox.Show(ex.Message, "Astra"); }
    }
}
'@

$manifest = @'
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <assemblyIdentity version="1.0.0.0" name="AstraMax.PostInstall" type="win32"/>
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v3">
    <security>
      <requestedPrivileges>
        <requestedExecutionLevel level="requireAdministrator" uiAccess="false"/>
      </requestedPrivileges>
    </security>
  </trustInfo>
  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">
    <application>
      <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>
    </application>
  </compatibility>
</assembly>
'@

$cs = Join-Path $work 'Launcher.cs'
$mf = Join-Path $work 'Launcher.manifest'
[System.IO.File]::WriteAllText($cs, $code, (New-Object System.Text.UTF8Encoding($false)))
[System.IO.File]::WriteAllText($mf, $manifest, (New-Object System.Text.UTF8Encoding($false)))

if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Force }
$log = & $csc /nologo /target:winexe "/win32manifest:$mf" "/out:$out" /reference:System.Windows.Forms.dll $cs 2>&1
if ($LASTEXITCODE -ne 0) {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    throw "csc failed:`n$($log -join "`n")"
}
Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue

"launcher: $out"
"SHA256: " + (Get-FileHash -LiteralPath $out -Algorithm SHA256).Hash
