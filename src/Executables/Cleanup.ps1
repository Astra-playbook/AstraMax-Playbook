#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$IncludeRecycleBin
)

$ErrorActionPreference = 'SilentlyContinue'
$freed = 0

function Clear-Folder {
    param([string]$Path, [string]$Label)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return }
    $before = 0
    $files = @(Get-ChildItem -LiteralPath $Path -Recurse -Force -File)
    foreach ($f in $files) { $before += $f.Length }
    Get-ChildItem -LiteralPath $Path -Force | Remove-Item -Recurse -Force
    $after = 0
    foreach ($f in @(Get-ChildItem -LiteralPath $Path -Recurse -Force -File)) { $after += $f.Length }
    $saved = [math]::Max(0, $before - $after)
    $script:freed += $saved
    '{0,-26} {1,8:N1} MB' -f $Label, ($saved / 1MB)
}

'Cleanup - locked files are skipped'
'-' * 40
Clear-Folder $env:TEMP 'user temp'
Clear-Folder (Join-Path $env:SystemRoot 'Temp') 'windows temp'
Clear-Folder (Join-Path $env:LOCALAPPDATA 'D3DSCache') 'directx shader cache'
Clear-Folder (Join-Path $env:LOCALAPPDATA 'NVIDIA\DXCache') 'nvidia shader cache'
Clear-Folder (Join-Path $env:LOCALAPPDATA 'NVIDIA\GLCache') 'nvidia gl cache'
Clear-Folder (Join-Path $env:LOCALAPPDATA 'AMD\DxCache') 'amd shader cache'
Clear-Folder (Join-Path $env:LOCALAPPDATA 'AMD\DxcCache') 'amd dxc cache'
Clear-Folder (Join-Path $env:LOCALAPPDATA 'CrashDumps') 'crash dumps'

if ($IncludeRecycleBin) {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    'recycle bin emptied'
}

'-' * 40
'Reclaimed: {0:N1} MB' -f ($freed / 1MB)
'Shader caches rebuild on first launch of each game.'
