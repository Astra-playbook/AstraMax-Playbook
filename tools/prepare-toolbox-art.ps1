#requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$InputDirectory, [Parameter(Mandatory)][string]$GojoImage)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$toolbox = Join-Path (Split-Path $PSScriptRoot -Parent) 'src\Executables\Toolbox'
$assets = Join-Path $toolbox 'Assets'
$wallpapers = Join-Path $toolbox 'Wallpapers'
New-Item -ItemType Directory -Path $assets,$wallpapers -Force | Out-Null
$items = @(
    @{ id='gojo'; title='Gojo - Hollow Purple'; file='gojo.png'; source=$GojoImage },
    @{ id='night-rain'; title='Night Rain'; file='night-rain.png'; source=(Join-Path $InputDirectory '8e8e234c-3b20-421d-99b5-4911479f7752.png') },
    @{ id='azure-eyes'; title='Azure Eyes'; file='azure-eyes.png'; source=(Join-Path $InputDirectory '52430661-1b77-4aef-9a7a-aabbd7638019.png') },
    @{ id='obsidian-eye'; title='Obsidian Eye'; file='obsidian-eye.png'; source=(Join-Path $InputDirectory '676de99b-1439-40cd-a569-7ed39b415106.png') },
    @{ id='shadow'; title='Shadow'; file='shadow.png'; source=(Join-Path $InputDirectory '42280643-5862-4d3d-a8f8-d5663e1d4056.png') },
    @{ id='noir'; title='Noir'; file='noir.png'; source=(Join-Path $InputDirectory '274edb8d-2b8c-4a77-83e9-70bc4bcaf223.png') },
    @{ id='manga-rain'; title='Manga Rain'; file='manga-rain.png'; source=(Join-Path $InputDirectory 'dc2133f3-9fad-4f60-a40f-bc9b433fea51.png') },
    @{ id='liquid-chrome'; title='Liquid Chrome'; file='liquid-chrome.png'; source=(Join-Path $InputDirectory 'cfa6bfc3-23fc-47eb-9824-8820bcc83bc9.png') },
    @{ id='monochrome'; title='Monochrome'; file='monochrome.png'; source=(Join-Path $InputDirectory 'e8d3ecbe-162c-4b4e-bf9e-e58a0ea2c27c.png') }
)
$manifest = @()
foreach ($item in $items) {
    Copy-Item -LiteralPath $item.source -Destination (Join-Path $wallpapers $item.file) -Force
    $image = [Drawing.Image]::FromFile($item.source)
    try { $manifest += [pscustomobject]@{ id=$item.id; title=$item.title; file=$item.file; width=$image.Width; height=$image.Height } } finally { $image.Dispose() }
}
[IO.File]::WriteAllText((Join-Path $wallpapers 'catalog.json'), (ConvertTo-Json -InputObject $manifest -Depth 3), (New-Object Text.UTF8Encoding($false)))
Copy-Item -LiteralPath $GojoImage -Destination (Join-Path $assets 'gojo-wallpaper.png') -Force
$source = [Drawing.Image]::FromFile($GojoImage)
$icon = New-Object Drawing.Bitmap(256,256)
$graphics = [Drawing.Graphics]::FromImage($icon)
try {
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.Clear([Drawing.Color]::Transparent)
    $path = New-Object Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse(4,4,248,248)
    $graphics.SetClip($path)
    $rect = New-Object Drawing.Rectangle(0,0,256,256)
    $crop = New-Object Drawing.Rectangle(840,368,248,248)
    $graphics.DrawImage($source,$rect,$crop,[Drawing.GraphicsUnit]::Pixel)
    $graphics.ResetClip()
    $pen = New-Object Drawing.Pen([Drawing.Color]::FromArgb(220,166,101,255),5)
    $graphics.DrawEllipse($pen,4,4,248,248)
    $pen.Dispose(); $path.Dispose()
    $png = Join-Path $assets 'gojo-icon.png'
    $icon.Save($png,[Drawing.Imaging.ImageFormat]::Png)
    $data = [IO.File]::ReadAllBytes($png)
    $stream = [IO.File]::Create((Join-Path $assets 'gojo.ico'))
    $writer = New-Object IO.BinaryWriter($stream)
    try {
        $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]1)
        $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0)
        $writer.Write([uint16]1); $writer.Write([uint16]32)
        $writer.Write([uint32]$data.Length); $writer.Write([uint32]22); $writer.Write($data)
    } finally { $writer.Dispose() }
} finally { $graphics.Dispose(); $icon.Dispose(); $source.Dispose() }
"Prepared $($manifest.Count) wallpapers and Gojo icon."
