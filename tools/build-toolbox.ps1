#requires -Version 5.1
[CmdletBinding()]
param([string]$Compiler)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not $Compiler) { $Compiler = Join-Path (Split-Path $root -Parent) 'build-tools\roslyn-4.11.0\tasks\netcore\bincore\csc.dll' }
if (-not (Test-Path -LiteralPath $Compiler)) { throw 'Provide -Compiler pointing to a Roslyn csc.dll (Microsoft.Net.Compilers.Toolset 4.11.0 or newer).' }
$toolbox = Join-Path $root 'src\Executables\Toolbox'
$csc = Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$dotnetRoot = Join-Path ${env:ProgramFiles} 'dotnet'
$core = Get-ChildItem (Join-Path $dotnetRoot 'shared\Microsoft.NETCore.App') -Directory | Where-Object Name -like '8.*' | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
$desktop = Get-ChildItem (Join-Path $dotnetRoot 'shared\Microsoft.WindowsDesktop.App') -Directory | Where-Object Name -like '8.*' | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if (-not $core -or -not $desktop) { throw '.NET Desktop Runtime 8 x64 is required to compile and run the toolbox.' }
$managed = @{}
foreach ($file in (@(Get-ChildItem (Join-Path $core.FullName '*.dll')) + @(Get-ChildItem (Join-Path $desktop.FullName '*.dll')))) {
    try { $null = [Reflection.AssemblyName]::GetAssemblyName($file.FullName); $managed[$file.Name] = $file.FullName } catch { }
}
$references = @($managed.Keys | Sort-Object | ForEach-Object { '/reference:' + $managed[$_] })
$references += '/reference:' + (Join-Path $toolbox 'Astra.Core.dll')
$sources = @(Get-ChildItem $toolbox -Filter '*.cs' | Where-Object Name -ne 'Launcher.cs' | ForEach-Object FullName)
if (-not $sources.Count) { throw 'No toolbox source files found.' }
& (Join-Path $dotnetRoot 'dotnet.exe') --roll-forward Major $Compiler /noconfig /nologo /nostdlib /target:winexe /optimize+ ('/out:' + (Join-Path $toolbox 'Toolbox.dll')) $references $sources
if ($LASTEXITCODE -ne 0) { throw 'Toolbox compilation failed.' }
$config = '{"runtimeOptions":{"tfm":"net8.0","frameworks":[{"name":"Microsoft.NETCore.App","version":"8.0.0"},{"name":"Microsoft.WindowsDesktop.App","version":"8.0.0"}]}}'
[IO.File]::WriteAllText((Join-Path $toolbox 'Toolbox.runtimeconfig.json'), $config, (New-Object Text.UTF8Encoding($false)))
$manifest = '<?xml version="1.0" encoding="utf-8"?><assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0"><assemblyIdentity version="1.0.0.0" name="Astra.Toolbox" type="win32"/><trustInfo xmlns="urn:schemas-microsoft-com:asm.v3"><security><requestedPrivileges><requestedExecutionLevel level="asInvoker" uiAccess="false"/></requestedPrivileges></security></trustInfo><application xmlns="urn:schemas-microsoft-com:asm.v3"><windowsSettings><dpiAware xmlns="http://schemas.microsoft.com/SMI/2005/WindowsSettings">true/pm</dpiAware></windowsSettings></application></assembly>'
$work = Join-Path $env:TEMP ('astra-toolbox-build-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
    $manifestPath = Join-Path $work 'toolbox.manifest'
    [IO.File]::WriteAllText($manifestPath, $manifest, (New-Object Text.UTF8Encoding($false)))
    & $csc /noconfig /nologo /target:winexe /optimize+ ('/out:' + (Join-Path $toolbox 'Astra-Toolbox.exe')) ('/win32icon:' + (Join-Path $toolbox 'Assets\gojo.ico')) ('/win32manifest:' + $manifestPath) /reference:System.dll /reference:System.Core.dll /reference:System.Windows.Forms.dll (Join-Path $toolbox 'Launcher.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Toolbox launcher compilation failed.' }
} finally { Remove-Item -LiteralPath $work -Recurse -Force }
'Built: ' + (Join-Path $toolbox 'Astra-Toolbox.exe')
'Backend SHA256: ' + (Get-FileHash -LiteralPath (Join-Path $toolbox 'Astra.Core.dll')).Hash
