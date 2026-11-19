#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$toolbox = Join-Path (Split-Path $PSScriptRoot -Parent) 'src\Executables\Toolbox'
$dotnet = Join-Path ${env:ProgramFiles} 'dotnet\dotnet.exe'
$cases = @(
    @{ Args = '--unknown'; Exit = 1 },
    @{ Args = '--apply nonexistent-tweak'; Exit = 1 },
    @{ Args = '--apply-option gaming.game-mode'; Exit = 1 },
    @{ Args = '--clean UnknownCategory'; Exit = 1 },
    @{ Args = '--power UnknownPreset'; Exit = 1 },
    @{ Args = '--wallpaper ../../untrusted.png'; Exit = 1 },
    @{ Args = '--catalog --restore-all'; Exit = 1 },
    @{ Args = '--preview --preview'; Exit = 1 },
    @{ Args = '--preview --apply exm-notification-sound-off'; Exit = 3 },
    @{ Args = '--preview --apply-option exm-chrome-geolocation-off'; Exit = 3 },
    @{ Args = '--preview --revert-option exm-chrome-geolocation-off'; Exit = 3 },
    @{ Args = '--preview --restore-all'; Exit = 3 },
    @{ Args = '--preview --restore-point'; Exit = 3 },
    @{ Args = '--restore-point --catalog'; Exit = 1 },
    @{ Args = '--preview --power Gaming'; Exit = 3 },
    @{ Args = '--preview --clean UserTemp'; Exit = 3 },
    @{ Args = '--preview --wallpaper gojo'; Exit = 3 },
    @{ Args = '--preview --game CS2'; Exit = 3 }
)
$root = Split-Path $PSScriptRoot -Parent
$source = [IO.File]::ReadAllText((Join-Path $toolbox 'Toolbox.cs'))
$match = [regex]::Match($source, 'ReviewedOptions\s*=\s*new string\[\]\s*\{(?<ids>[^}]+)\}')
if (-not $match.Success) { throw 'Reviewed playbook whitelist was not found.' }
$reviewed = @([regex]::Matches($match.Groups['ids'].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
if (-not $reviewed.Count -or @($reviewed | Select-Object -Unique).Count -ne $reviewed.Count) { throw 'Reviewed IDs must be nonempty and unique.' }
$tokens = $null; $parseErrors = $null
$helper = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'src\Executables\Invoke-ToolboxTweak.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'Reviewed option helper has invalid PowerShell syntax.' }
$idParameter = $helper.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Id' }
$validation = $idParameter.Attributes | Where-Object { $_.TypeName.FullName -eq 'ValidateSet' }
$helperIds = @($validation.PositionalArguments | ForEach-Object Value)
if (@(Compare-Object ($reviewed | Sort-Object) ($helperIds | Sort-Object)).Count) { throw 'C# and PowerShell reviewed whitelists differ.' }
$taskText = [IO.File]::ReadAllText((Join-Path $root 'src\Configuration\Tasks\exm-extras.yml'))
$blocks = @([regex]::Split($taskText, '(?m)^  - !powerShell:\r?\n') | Select-Object -Skip 1)
[xml]$conf = [IO.File]::ReadAllText((Join-Path $root 'src\playbook.conf'))
$taskIds = @(); $taskOptions = @()
foreach ($block in $blocks) {
    $idMatch = [regex]::Match($block, "Invoke-ToolboxTweak\.ps1' -Id '([^']+)'")
    $optionMatch = [regex]::Match($block, '(?m)^    option: (\S+)\s*$')
    if (-not $idMatch.Success -or -not $optionMatch.Success) { throw 'Every reviewed action must use the fixed helper and an option gate.' }
    foreach ($required in 'exeDir: true','runas: currentUserElevated','wait: true') {
        if (-not $block.Contains($required)) { throw "Reviewed action is missing $required" }
    }
    $id = $idMatch.Groups[1].Value; $option = $optionMatch.Groups[1].Value
    $choice = @($conf.SelectNodes('//CheckboxOption') | Where-Object { $_.Name -eq $option })
    if ($choice.Count -ne 1 -or $choice[0].IsChecked -ne 'false') { throw "Reviewed option must appear once and default to off: $option" }
    $taskIds += $id; $taskOptions += $option
}
if (@($taskOptions | Select-Object -Unique).Count -ne $taskOptions.Count -or @($taskIds | Select-Object -Unique).Count -ne $taskIds.Count) { throw 'Reviewed action gates and IDs must be unique.' }
if (@(Compare-Object ($reviewed | Sort-Object) ($taskIds | Sort-Object)).Count) { throw 'Reviewed task actions and whitelists differ.' }
$restoreSource = [IO.File]::ReadAllText((Join-Path $root 'src\Executables\Restore.ps1'))
$restoreMatch = [regex]::Match($restoreSource, 'foreach \(\$id in @\((?<ids>[^)]+)\)\)')
$restoreIds = @([regex]::Matches($restoreMatch.Groups['ids'].Value, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
if (-not $restoreMatch.Success -or @(Compare-Object ($reviewed | Sort-Object) ($restoreIds | Sort-Object)).Count) { throw 'Reviewed restore coverage and whitelists differ.' }
"PASS: $($reviewed.Count) reviewed choices have matching whitelists, restore coverage and unique off-by-default wizard gates"
foreach ($id in $reviewed) {
    $cases += @{ Args = "--preview --apply-option $id"; Exit = 3 }
    $cases += @{ Args = "--preview --revert-option $id"; Exit = 3 }
}
foreach ($case in $cases) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $dotnet
    $info.Arguments = '"' + (Join-Path $toolbox 'Toolbox.dll') + '" ' + $case.Args
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($info)
    $output = $process.StandardOutput.ReadToEndAsync()
    $errorOutput = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(15000)) { throw "CLI test did not finish: $($case.Args)" }
    if ($process.ExitCode -ne $case.Exit) { throw "CLI test failed: $($case.Args), exit $($process.ExitCode), $($output.Result) $($errorOutput.Result)" }
    "PASS: $($case.Args) rejected with exit $($case.Exit)"
    $process.Dispose()
}
'Safe CLI tests passed; all mutation requests were blocked before service construction.'
