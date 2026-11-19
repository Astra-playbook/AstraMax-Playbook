#requires -Version 5.1
param([string]$Compiler)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not $Compiler) { $Compiler = Join-Path (Split-Path $root -Parent) 'build-tools\roslyn-4.11.0\tasks\netcore\bincore\csc.dll' }
$dotnetRoot = Join-Path ${env:ProgramFiles} 'dotnet'
$core = Get-ChildItem (Join-Path $dotnetRoot 'shared\Microsoft.NETCore.App') -Directory | Where-Object Name -like '8.*' | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
$desktop = Get-ChildItem (Join-Path $dotnetRoot 'shared\Microsoft.WindowsDesktop.App') -Directory | Where-Object Name -like '8.*' | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
$managed = @{}
foreach ($file in (@(Get-ChildItem (Join-Path $core.FullName '*.dll')) + @(Get-ChildItem (Join-Path $desktop.FullName '*.dll')))) {
    try { $null = [Reflection.AssemblyName]::GetAssemblyName($file.FullName); $managed[$file.Name] = $file.FullName } catch { }
}
$references = @($managed.Keys | Sort-Object | ForEach-Object { '/reference:' + $managed[$_] })
$work = Join-Path $env:TEMP ('AstraSnapshotFixture-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
    $toolbox = Join-Path $root 'src\Executables\Toolbox'
    foreach ($file in 'Astra.Core.dll','Toolbox.dll') { Copy-Item -LiteralPath (Join-Path $toolbox $file) -Destination $work; $references += '/reference:' + (Join-Path $work $file) }
    Copy-Item -LiteralPath (Join-Path $toolbox 'Toolbox.runtimeconfig.json') -Destination (Join-Path $work 'SnapshotFixture.runtimeconfig.json')
    & (Join-Path $dotnetRoot 'dotnet.exe') --roll-forward Major $Compiler /noconfig /nologo /nostdlib /target:exe ('/out:' + (Join-Path $work 'SnapshotFixture.dll')) $references (Join-Path $PSScriptRoot 'test-toolbox-snapshots.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Snapshot fixture compilation failed.' }
    & (Join-Path $dotnetRoot 'dotnet.exe') (Join-Path $work 'SnapshotFixture.dll') (Join-Path $work 'state')
    if ($LASTEXITCODE -ne 0) { throw 'Snapshot fixtures failed.' }
} finally { Remove-Item -LiteralPath $work -Recurse -Force }
