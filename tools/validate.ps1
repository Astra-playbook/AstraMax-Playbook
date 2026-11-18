#requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$src  = Join-Path $root 'src'
$failed = $false

$conf = [xml](Get-Content (Join-Path $src 'playbook.conf') -Raw)
'conf: XML ok'
$names = @($conf.SelectNodes('//Options/*/Name') | ForEach-Object { $_.InnerText })
if (@($names | Group-Object | Where-Object Count -gt 1).Count) { throw 'Duplicate feature option names' }
foreach ($page in $conf.SelectNodes('//RadioPage | //CheckboxPage')) {
    $limit = if ($page.Name -eq 'CheckboxPage' -and ($page.TopLine -or $page.BottomLine)) { 3 } else { 4 }
    if ($page.Options.ChildNodes.Count -gt $limit) { throw "Feature page exceeds $limit options: $($page.Description)" }
}
. (Join-Path $src 'Executables\PostInstall\Catalog.ps1')
if (@($AstraModules | Group-Object N | Where-Object Count -gt 1).Count) { throw 'Duplicate module IDs' }
foreach ($module in $AstraModules) {
    $file = Join-Path $src ('Executables\PostInstall\Modules\' + $module.Script)
    if (-not (Test-Path -LiteralPath $file)) { throw "Missing module: $($module.Script)" }
    if ($module.Script -notmatch ('^{0:D2}-' -f $module.N)) { throw "Module prefix mismatch: $($module.Script)" }
}
'features: page limits and module catalog checked'

Get-ChildItem (Join-Path $src 'Executables') -Recurse -Include '*.ps1', '*.psm1' | ForEach-Object {
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$errors) | Out-Null
    if ($errors) {
        $failed = $true
        "ps1: FAIL $($_.FullName.Substring($src.Length + 1)): $($errors[0].Message)"
    }
    else {
        "ps1: ok $($_.FullName.Substring($src.Length + 1))"
    }
}

$config = Join-Path $src 'Configuration'
foreach ($file in (Get-ChildItem $config -Recurse -Filter '*.yml')) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    $lineNo = 0
    foreach ($line in ($text -split "`r?`n")) {
        $lineNo++

        # YAML double-quoted scalars treat \ as an escape, so paths like '.\Tool.ps1' throw.
        if ($line -match ':\s*".*\\') {
            $failed = $true
            "yaml: FAIL $($file.Name):$lineNo backslash inside a double-quoted scalar; use a block scalar (command: |)"
        }

        # A PowerShell here-string terminator must sit at column 0, which ends a YAML block scalar early.
        if ($line -match "^('@|`"@)\s*$") {
            $failed = $true
            "yaml: FAIL $($file.Name):$lineNo here-string terminator at column 0; build the string from an array instead"
        }
    }

    foreach ($option in [regex]::Matches($text, 'option:\s*([a-z0-9-]+)')) {
        if ($option.Groups[1].Value -notin $names) { throw "Unknown option $($option.Groups[1].Value) in $($file.Name)" }
    }
    $lines = $text -split "`r?`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch '^(\s*)command:\s*\|\s*$') { continue }
        $indent = $Matches[1].Length
        $command = @()
        for ($j = $i + 1; $j -lt $lines.Count; $j++) {
            if ($lines[$j].Trim() -and ($lines[$j] -replace '^\s*','').Length -ge $lines[$j].Length - $indent) { break }
            $command += $(if ($lines[$j].Length -gt $indent + 2) { $lines[$j].Substring($indent + 2) } else { '' })
        }
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseInput(($command -join "`n"), [ref]$null, [ref]$errors) | Out-Null
        if ($errors) { throw "Embedded PowerShell invalid in $($file.Name): $($errors[0].Message)" }
    }
    foreach ($m in [regex]::Matches($text, "!task:\s*\{path:\s*'([^']+)'")) {
        $rel = $m.Groups[1].Value
        if (-not (Test-Path -LiteralPath (Join-Path $config $rel))) {
            $failed = $true
            "task: MISSING $rel (referenced by $($file.Name))"
        }
    }
}
'tasks: references and yaml quoting checked'

$template = Join-Path $src 'Executables\LiveWallpaper'
if (@(Get-ChildItem $template -File | Where-Object Extension -in '.png','.jpg','.jpeg','.webp','.gif','.mp4').Count) { throw 'Public live template must not contain personal artwork/video' }
if ($failed) { throw 'Validation failed' }
'Validation passed'
