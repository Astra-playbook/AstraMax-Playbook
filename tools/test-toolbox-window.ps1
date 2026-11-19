#requires -Version 5.1
param([string]$ScreenshotDirectory)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$exe = Join-Path (Split-Path $PSScriptRoot -Parent) 'src\Executables\Toolbox\Astra-Toolbox.exe'
$launcher = Start-Process -FilePath $exe -ArgumentList '--preview' -PassThru
$window = $null
function Find-Element([string]$Name) {
    $condition = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::NameProperty, $Name)
    $window.FindFirst([Windows.Automation.TreeScope]::Descendants, $condition)
}
function Find-Id([string]$Id) {
    $condition = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::AutomationIdProperty, $Id)
    $window.FindFirst([Windows.Automation.TreeScope]::Descendants, $condition)
}
function Wait-For([scriptblock]$Probe, [string]$Label, [int]$Seconds = 8) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    do {
        $value = & $Probe
        if ($value) { return $value }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out: $Label"
}
function Assert($Value, [string]$Label) { if (-not $Value) { throw $Label }; "PASS: $Label" }
function Save-WindowScreenshot([string]$Name) {
    if (-not $ScreenshotDirectory) { return }
    if (-not (Test-Path -LiteralPath $ScreenshotDirectory -PathType Container)) { throw 'Screenshot directory must already exist.' }
    $window.GetCurrentPattern([Windows.Automation.WindowPattern]::Pattern).SetWindowVisualState([Windows.Automation.WindowVisualState]::Normal)
    $window.SetFocus()
    $null = Wait-For { $window.Current.BoundingRectangle.Height -ge 650 } 'visible screenshot window'
    $bounds = $window.Current.BoundingRectangle
    $bitmap = New-Object Drawing.Bitmap([int]$bounds.Width, [int]$bounds.Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen([int]$bounds.X, [int]$bounds.Y, 0, 0, $bitmap.Size, [Drawing.CopyPixelOperation]::SourceCopy)
        $bitmap.Save((Join-Path $ScreenshotDirectory $Name), [Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Navigate([string]$Name) {
    $button = Find-Id ('Nav' + $Name)
    $button.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke()
    $null = Wait-For { (Find-Id ('Nav' + $Name)).Current.HelpText -eq 'Current page' } "navigation $Name"
}
try {
    $child = Wait-For { Get-CimInstance Win32_Process -Filter "ParentProcessId=$($launcher.Id)" -OperationTimeoutSec 5 | Where-Object Name -eq 'dotnet.exe' | Select-Object -First 1 } 'owned toolbox process' 30
    Assert ($child.CommandLine -match '--preview' -and $child.CommandLine -notmatch '--self-test') 'native interactions target only the owned preview process'
    $condition = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ProcessIdProperty, [int]$child.ProcessId)
    $window = Wait-For { [Windows.Automation.AutomationElement]::RootElement.FindFirst([Windows.Automation.TreeScope]::Children, $condition) } 'native window' 30
    Assert ($null -ne $window) 'native preview window opens through the launcher'
    $null = Wait-For { $button = Find-Id 'NavTweaks'; $button -and $button.Current.IsEnabled } 'read-only startup' 100
    Assert ((Find-Id 'NavTweaks').Current.IsEnabled) 'live read-only startup completes'
    $window.SetFocus()
    Navigate 'Tweaks'
    $search = Wait-For { Find-Id 'TweakSearch' } 'tweak search'
    Assert ($null -ne $search) 'real tweak search control is accessible'
    $search.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern).SetValue('ASTRA__NO_MATCH__LIVE')
    $null = Wait-For { Find-Id 'NoResults' } 'search empty state'
    Assert ($null -ne (Find-Element "No matching tweaks.`nTry another search or clear your filters.")) 'real search shows its no-results state'
    (Find-Element 'Clear search').GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke()
    $null = Wait-For { $search.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern).Current.Value -eq '' } 'cleared search'
    Assert ($search.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern).Current.Value -eq '') 'clear search works in the actual window'
    Save-WindowScreenshot 'native-tweaks.png'
    Navigate 'Overview'
    Save-WindowScreenshot 'native-overview.png'
    Navigate 'System'
    $null = Wait-For { Find-Element 'Your PC, in detail' } 'System heading'
    $null = Wait-For { Find-Element 'PROCESSOR' } 'live measured System summary' 100
    Save-WindowScreenshot 'native-system.png'
    Assert ($null -ne (Find-Id 'NavSystem') -and $null -eq (Find-Id 'NavRestore')) 'System replaces the Restore navigation tab'
    $point = Find-Id 'CreateRestorePoint'
    Assert ($null -ne $point -and -not $point.Current.IsEnabled) 'restore-point creation is visibly blocked in preview'
    Assert (-not (Find-Id 'OpenSystemProtection').Current.IsEnabled) 'preview blocks external System Protection controls'
    $backups = Find-Element 'Saved Astra snapshots and restore controls'
    Assert ($null -ne $backups) 'existing snapshot restore controls remain inside System'
    $backups.GetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern).Expand()
    $null = Wait-For { Find-Element 'Review restore of all saved tweaks' } 'expanded backup controls'
    Assert (-not (Find-Element 'Review restore of all saved tweaks').Current.IsEnabled) 'expanded backup restore remains non-mutating in preview'
    foreach ($name in 'Power','Games','Cleaner','Wallpapers','Overview') {
        Navigate $name
        Assert ((Find-Id ('Nav' + $name)).Current.HelpText -eq 'Current page') "real navigation opens $name"
        if ($name -eq 'Wallpapers') { Save-WindowScreenshot 'native-wallpapers.png' }
    }
    $transform = $window.GetCurrentPattern([Windows.Automation.TransformPattern]::Pattern)
    $transform.Resize(900,650)
    $null = Wait-For { $window.Current.BoundingRectangle.Width -le 901 } 'minimum-size resize'
    foreach ($name in 'Overview','Tweaks','System','Power','Games','Cleaner','Wallpapers') {
        Assert (-not (Find-Id ('Nav' + $name)).Current.IsOffscreen) "minimum-size sidebar keeps $name visible"
    }
    Navigate 'System'
    Save-WindowScreenshot 'native-system-small.png'
    Assert (-not (Find-Id 'CreateRestorePoint').Current.IsOffscreen) 'restore-point button is visible at minimum window size'
    Assert ($null -ne (Find-Element ('Preview ' + [char]0x00B7 + ' read only'))) 'actual window remains in non-mutating preview mode'
    (Find-Element 'Refresh state').GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke()
    $reader = Wait-For { Get-CimInstance Win32_Process -Filter "ParentProcessId=$($child.ProcessId)" -OperationTimeoutSec 5 | Where-Object Name -eq 'powershell.exe' | Select-Object -First 1 } 'owned background inventory reader' 20
    $null = Wait-For { (Find-Id 'NavTweaks').Current.IsEnabled } 'navigation during background scan'
    Navigate 'Tweaks'
    Assert ((Find-Id 'NavTweaks').Current.HelpText -eq 'Current page') 'navigation stays usable during an active hardware scan'
    $jobs = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($reader.ProcessId)" -OperationTimeoutSec 5)
    $window.GetCurrentPattern([Windows.Automation.WindowPattern]::Pattern).Close()
    $window = $null
    Assert ($launcher.WaitForExit(10000)) 'closing during a background scan exits the owned app'
    $null = Wait-For { $alive = @(@($reader) + $jobs | Where-Object { Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }); $alive.Count -eq 0 } 'owned inventory process cleanup' 10
    Assert (@(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($reader.ProcessId)" -OperationTimeoutSec 5).Count -eq 0) 'closing stops only the owned inventory reader and its child jobs'
    'Native window interaction tests passed; no restore point, apply, cleanup or wallpaper action ran.'
} catch {
    if ($window) {
        Save-WindowScreenshot 'native-failure.png'
        $window.FindAll([Windows.Automation.TreeScope]::Descendants, [Windows.Automation.Condition]::TrueCondition) | ForEach-Object { $_.Current.Name }
    }
    throw
} finally {
    if ($window) { $window.GetCurrentPattern([Windows.Automation.WindowPattern]::Pattern).Close() }
    $null = $launcher.WaitForExit(10000)
    $launcher.Dispose()
}
