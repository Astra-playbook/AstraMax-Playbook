#requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$InputFile, [Parameter(Mandatory)][string]$Destination)
$ErrorActionPreference = 'Stop'
$bytes = [IO.File]::ReadAllBytes($InputFile)
$signature = [byte[]](0x8b,0x12,0x02,0xb9,0x6a,0x61,0x20,0x38,0x72,0x7b,0x93,0x02,0x14,0xd7,0xa0,0x32,0x13,0xf5,0xb9,0xe6,0xef,0xae,0x33,0x18,0xee,0x3b,0x2d,0xce,0x24,0xb3,0x6a,0xae)
$encoding = [Text.Encoding]::GetEncoding(28591)
$index = $encoding.GetString($bytes).IndexOf($encoding.GetString($signature), [StringComparison]::Ordinal)
if ($index -lt 8) { throw 'No .NET single-file bundle header found.' }
$offset = [BitConverter]::ToInt64($bytes, $index - 8)
$stream = New-Object IO.MemoryStream(,$bytes)
$reader = New-Object IO.BinaryReader($stream)
$stream.Position = $offset
$major = $reader.ReadUInt32()
$minor = $reader.ReadUInt32()
$count = $reader.ReadInt32()
$id = $reader.ReadString()
if ($major -ge 2) { $null = $reader.ReadBytes(40) }
$entries = @()
for ($i = 0; $i -lt $count; $i++) {
    $position = $reader.ReadInt64()
    $size = $reader.ReadInt64()
    $compressed = if ($major -ge 6) { $reader.ReadInt64() } else { 0 }
    $type = $reader.ReadByte()
    $name = $reader.ReadString()
    $entries += [pscustomobject]@{ Name = $name; Offset = $position; Size = $size; CompressedSize = $compressed; Type = $type }
}
New-Item -ItemType Directory -Path $Destination -Force | Out-Null
$root = [IO.Path]::GetFullPath($Destination).TrimEnd('\') + '\'
foreach ($entry in $entries) {
    $target = [IO.Path]::GetFullPath((Join-Path $root $entry.Name))
    if (-not $target.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid bundle entry path.' }
    New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
    $output = [IO.File]::Create($target)
    try {
        $stream.Position = $entry.Offset
        if ($entry.CompressedSize -gt 0) {
            $payload = $reader.ReadBytes([int]$entry.CompressedSize)
            $input = New-Object IO.MemoryStream(,$payload)
            $deflate = New-Object IO.Compression.DeflateStream($input, [IO.Compression.CompressionMode]::Decompress)
            try { $deflate.CopyTo($output) } finally { $deflate.Dispose(); $input.Dispose() }
        } else { $output.Write($bytes, [int]$entry.Offset, [int]$entry.Size) }
    } finally { $output.Dispose() }
    if ((Get-Item -LiteralPath $target).Length -ne $entry.Size) { throw "Incorrect decompressed length: $($entry.Name)" }
}
$reader.Dispose()
"Bundle $major.$minor : $count files extracted to $Destination"
$entries | Where-Object { $_.Name -match 'Astra|json|html|css|js$' } | Format-Table Name, Size, CompressedSize -AutoSize
