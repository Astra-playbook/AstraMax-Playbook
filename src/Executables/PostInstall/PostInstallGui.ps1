#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$NoElevate
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
. (Join-Path $root 'Catalog.ps1')

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

$ui = @{
    Bg        = [System.Drawing.Color]::FromArgb(15, 4, 14)
    Panel     = [System.Drawing.Color]::FromArgb(24, 6, 19)
    Sidebar   = [System.Drawing.Color]::FromArgb(20, 5, 16)
    Row       = [System.Drawing.Color]::FromArgb(32, 8, 25)
    RowAlt    = [System.Drawing.Color]::FromArgb(27, 7, 21)
    Line      = [System.Drawing.Color]::FromArgb(72, 14, 54)
    Accent    = [System.Drawing.Color]::FromArgb(192, 38, 211)
    Hot       = [System.Drawing.Color]::FromArgb(236, 45, 85)
    Text      = [System.Drawing.Color]::FromArgb(241, 233, 245)
    Muted     = [System.Drawing.Color]::FromArgb(163, 137, 180)
    Dim       = [System.Drawing.Color]::FromArgb(118, 96, 132)
    On        = [System.Drawing.Color]::FromArgb(232, 121, 249)
    Off       = [System.Drawing.Color]::FromArgb(156, 163, 175)
    Mixed     = [System.Drawing.Color]::FromArgb(251, 191, 36)
    NavActive = [System.Drawing.Color]::FromArgb(48, 10, 37)
    NavHover  = [System.Drawing.Color]::FromArgb(38, 8, 29)
}

$groupBlurb = @{
    'All'         = 'Every setting in one list. Narrow it with the categories on the left or the search box.'
    'Performance' = 'Power, scheduling and memory changes for steadier frame times.'
    'CPU'         = 'Processor boost and energy policies on the active power scheme.'
    'GPU'         = 'Scheduling and windowed-game preferences. Reboot or restart games after changes.'
    'Gaming'      = 'Per-game profiles and capture settings. Close a game before changing its profile.'
    'Network'     = 'Latency and adapter preferences. DNS lives in the wizard, not here.'
    'Privacy'     = 'Telemetry, suggestions, Copilot, Recall and search privacy.'
    'Shell'       = 'Explorer, taskbar and Start behaviour. Mostly cosmetic and instant.'
    'System'      = 'Services, updates, Store and other machine-wide Windows components.'
    'Input'       = 'Pointer behaviour for 1:1 mouse input.'
    'Appearance'  = 'Dark mode, wallpaper and the private live wallpaper host.'
    'Security'    = 'Defender and virtualization-based security. Trade-offs are spelled out per row.'
    'Debloat'     = 'Cumulative app tiers. Removed apps are not restored by OFF; read each note.'
}

$script:States = @{}
$script:Busy = $false
$script:Filter = 'All'
$script:Query = ''
$script:Rows = @()
$script:NavItems = @()
$script:LastWidth = 0
$script:SelectedRow = $null
$script:SearchPlaceholder = 'Search tweaks...'

if (-not ('AstraDwm' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AstraDwm {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr window, int attribute, ref int value, int size);
}
'@
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Astra - Post-Install Toolkit'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(1260, 820)
$form.MinimumSize = New-Object System.Drawing.Size(1120, 700)
$form.BackColor = $ui.Bg
$form.ForeColor = $ui.Text
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$form.KeyPreview = $true

# --- header ----------------------------------------------------------------------
$header = New-Object System.Windows.Forms.Panel
$header.Dock = 'Top'
$header.Height = 92
$header.BackColor = $ui.Panel

$accentLine = New-Object System.Windows.Forms.Panel
$accentLine.Dock = 'Bottom'
$accentLine.Height = 2
$accentLine.BackColor = $ui.Hot

$title = New-Object System.Windows.Forms.Label
$title.Text = 'ASTRA MAX'
$title.Font = New-Object System.Drawing.Font('Segoe UI', 25, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = $ui.Hot
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(24, 10)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = 'POST-INSTALL TOOLKIT   |   OFF restores saved values where supported'
$subtitle.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$subtitle.ForeColor = $ui.Muted
$subtitle.AutoSize = $true
$subtitle.Location = New-Object System.Drawing.Point(28, 58)

$adminLabel = New-Object System.Windows.Forms.Label
$adminLabel.AutoSize = $false
$adminLabel.Width = 320
$adminLabel.Dock = 'Right'
$adminLabel.TextAlign = 'MiddleRight'
$adminLabel.Padding = New-Object System.Windows.Forms.Padding(0, 0, 24, 0)
$adminLabel.Text = if ($isAdmin) { "ELEVATED`r`n$($env:COMPUTERNAME)" } else { "READ ONLY`r`nnot elevated" }
$adminLabel.ForeColor = if ($isAdmin) { $ui.On } else { $ui.Mixed }

$header.Controls.AddRange(@($title, $subtitle, $adminLabel, $accentLine))

# --- bottom bar ------------------------------------------------------------------
$bottom = New-Object System.Windows.Forms.Panel
$bottom.Dock = 'Bottom'
$bottom.Height = 58
$bottom.BackColor = $ui.Panel

function New-AstraButton {
    param([string]$Text, [int]$X, [int]$W, [System.Drawing.Color]$Back, [System.Drawing.Color]$Fore)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Location = New-Object System.Drawing.Point($X, 13)
    $b.Size = New-Object System.Drawing.Size($W, 32)
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderColor = $ui.Line
    $b.FlatAppearance.BorderSize = 1
    $b.BackColor = $Back
    $b.ForeColor = $Fore
    $b.Enabled = $isAdmin
    $b
}

$btnAllOn = New-AstraButton 'ALL ON' 20 100 $ui.Row $ui.On
$btnAllOff = New-AstraButton 'ALL OFF' 128 100 $ui.Row $ui.Off
$btnRefresh = New-AstraButton 'REFRESH' 236 110 $ui.Row $ui.Text

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.AutoSize = $false
$statusLabel.Width = 470
$statusLabel.Dock = 'Right'
$statusLabel.TextAlign = 'MiddleRight'
$statusLabel.Padding = New-Object System.Windows.Forms.Padding(0, 0, 24, 0)
$statusLabel.ForeColor = $ui.Muted
$statusLabel.Text = 'starting...'

$bottom.Controls.AddRange(@($btnAllOn, $btnAllOff, $btnRefresh, $statusLabel))

# --- sidebar ---------------------------------------------------------------------
$side = New-Object System.Windows.Forms.Panel
$side.Dock = 'Left'
$side.Width = 224
$side.BackColor = $ui.Sidebar

$navTitle = New-Object System.Windows.Forms.Label
$navTitle.Text = 'CATEGORIES'
$navTitle.Dock = 'Top'
$navTitle.Height = 34
$navTitle.Padding = New-Object System.Windows.Forms.Padding(18, 14, 0, 0)
$navTitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8)
$navTitle.ForeColor = $ui.Accent

$nav = New-Object System.Windows.Forms.FlowLayoutPanel
$nav.Dock = 'Fill'
$nav.FlowDirection = 'TopDown'
$nav.WrapContents = $false
$nav.AutoScroll = $true
$nav.Padding = New-Object System.Windows.Forms.Padding(10, 2, 10, 8)
$nav.BackColor = $ui.Sidebar

$tools = New-Object System.Windows.Forms.Panel
$tools.Dock = 'Bottom'
$tools.Height = 138
$tools.Padding = New-Object System.Windows.Forms.Padding(12, 6, 12, 8)

$toolsTitle = New-Object System.Windows.Forms.Label
$toolsTitle.Text = 'UTILITIES'
$toolsTitle.Dock = 'Top'
$toolsTitle.Height = 22
$toolsTitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8)
$toolsTitle.ForeColor = $ui.Accent

function New-AstraToolButton {
    param([string]$Text, [int]$Y, [System.Drawing.Color]$Fore)
    $b = New-AstraButton $Text 0 196 $ui.Row $Fore
    $b.Location = New-Object System.Drawing.Point(12, $Y)
    $b.Size = New-Object System.Drawing.Size(196, 30)
    $b.Enabled = $true
    $b
}

$btnFolder = New-AstraToolButton 'OPEN INSTALL FOLDER' 26 $ui.Text
$btnVerify = New-AstraToolButton 'RUN VERIFY REPORT' 64 $ui.Text
$btnSiege = New-AstraToolButton 'SIEGE UBI LAUNCH ARGS' 102 $ui.Text
$btnVerify.ForeColor = $ui.On
$tools.Controls.AddRange(@($toolsTitle, $btnFolder, $btnVerify, $btnSiege))

$side.Controls.AddRange(@($nav, $navTitle, $tools))
$side.Add_Paint({
    param($sender, $e)
    $pen = New-Object System.Drawing.Pen($ui.Line, 1)
    $e.Graphics.DrawLine($pen, $sender.Width - 1, 0, $sender.Width - 1, $sender.Height)
    $pen.Dispose()
})

function New-AstraNavItem {
    param([string]$Group, [int]$Count, [int]$Y)
    $item = New-Object System.Windows.Forms.Panel
    $item.BackColor = $ui.Sidebar
    $item.Location = New-Object System.Drawing.Point(0, $Y)
    $item.Size = New-Object System.Drawing.Size(184, 32)
    $item.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 3)
    $item.Tag = $Group
    $item.Cursor = [System.Windows.Forms.Cursors]::Hand

    $bar = New-Object System.Windows.Forms.Panel
    $bar.BackColor = $ui.Hot
    $bar.Location = New-Object System.Drawing.Point(0, 5)
    $bar.Size = New-Object System.Drawing.Size(3, 22)
    $bar.Visible = $false
    $bar.Tag = $Group

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Group
    $label.ForeColor = $ui.Muted
    $label.Location = New-Object System.Drawing.Point(13, 6)
    $label.Size = New-Object System.Drawing.Size(134, 20)
    $label.Tag = $Group
    $label.Cursor = [System.Windows.Forms.Cursors]::Hand

    $badge = New-Object System.Windows.Forms.Label
    $badge.Text = [string]$Count
    $badge.ForeColor = $ui.Dim
    $badge.TextAlign = 'MiddleRight'
    $badge.Font = New-Object System.Drawing.Font('Consolas', 8.5)
    $badge.Location = New-Object System.Drawing.Point(146, 6)
    $badge.Size = New-Object System.Drawing.Size(30, 20)
    $badge.Tag = $Group

    $item.Controls.AddRange(@($bar, $label, $badge))
    $item.Add_Click({ param($sender, $e) Set-Filter ([string]$sender.Tag) })
    $label.Add_Click({ param($sender, $e) Set-Filter ([string]$sender.Tag) })
    $badge.Add_Click({ param($sender, $e) Set-Filter ([string]$sender.Tag) })
    $item.Add_MouseEnter({ param($sender, $e) if ($script:Filter -ne [string]$sender.Tag) { $sender.BackColor = $ui.NavHover } })
    $item.Add_MouseLeave({ param($sender, $e) if ($script:Filter -ne [string]$sender.Tag) { $sender.BackColor = $ui.Sidebar } })

    $nav.Controls.Add($item)
    $script:NavItems += [pscustomobject]@{ Tag = $Group; Panel = $item; Label = $label; Badge = $badge; Bar = $bar }
}

$y = 0
foreach ($g in $AstraGroups) {
    $count = if ($g -eq 'All') { $AstraModules.Count } else { @($AstraModules | Where-Object { $_.Group -eq $g }).Count }
    New-AstraNavItem $g $count $y
    $y += 35
}

# --- content ---------------------------------------------------------------------
$content = New-Object System.Windows.Forms.Panel
$content.Dock = 'Fill'
$content.BackColor = $ui.Bg

$contentHeader = New-Object System.Windows.Forms.Panel
$contentHeader.Dock = 'Top'
$contentHeader.Height = 78
$contentHeader.BackColor = $ui.Bg

$pageTitle = New-Object System.Windows.Forms.Label
$pageTitle.Text = 'All tweaks'
$pageTitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 17)
$pageTitle.ForeColor = $ui.Text
$pageTitle.AutoSize = $true
$pageTitle.Location = New-Object System.Drawing.Point(20, 12)

$pageSub = New-Object System.Windows.Forms.Label
$pageSub.Text = $groupBlurb['All']
$pageSub.ForeColor = $ui.Muted
$pageSub.AutoSize = $false
$pageSub.Location = New-Object System.Drawing.Point(22, 46)
$pageSub.Size = New-Object System.Drawing.Size(560, 22)
$pageSub.AutoEllipsis = $true

$searchPanel = New-Object System.Windows.Forms.Panel
$searchPanel.Dock = 'Right'
$searchPanel.Width = 286
$searchPanel.BackColor = $ui.Bg

$search = New-Object System.Windows.Forms.TextBox
$search.Location = New-Object System.Drawing.Point(0, 24)
$search.Size = New-Object System.Drawing.Size(260, 26)
$search.BackColor = $ui.Row
$search.ForeColor = $ui.Muted
$search.BorderStyle = 'FixedSingle'
$search.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$search.Text = $script:SearchPlaceholder
$searchPanel.Controls.Add($search)

$contentHeader.Controls.AddRange(@($pageTitle, $pageSub, $searchPanel))
$contentHeader.Add_Resize({
    $pageSub.Width = [math]::Max(140, $contentHeader.Width - 312)
})

$details = New-Object System.Windows.Forms.Panel
$details.Dock = 'Right'
$details.Width = 312
$details.BackColor = $ui.Panel
$details.Padding = New-Object System.Windows.Forms.Padding(16, 12, 16, 12)

$noteTitle = New-Object System.Windows.Forms.Label
$noteTitle.Text = 'WHAT THIS DOES'
$noteTitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8)
$noteTitle.ForeColor = $ui.Accent
$noteTitle.Dock = 'Top'
$noteTitle.Height = 22

$noteLabel = New-Object System.Windows.Forms.Label
$noteLabel.Dock = 'Top'
$noteLabel.Height = 158
$noteLabel.ForeColor = $ui.Text
$noteLabel.Text = 'Select a row for details. OFF restores saved settings where available; removed apps need reinstallation. Personal wallpapers are excluded from bulk actions.'

$stateTitle = New-Object System.Windows.Forms.Label
$stateTitle.Text = 'LIVE STATE'
$stateTitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8)
$stateTitle.ForeColor = $ui.Accent
$stateTitle.Dock = 'Top'
$stateTitle.Height = 22

$stateLabel = New-Object System.Windows.Forms.Label
$stateLabel.Dock = 'Top'
$stateLabel.Height = 44
$stateLabel.ForeColor = $ui.Muted
$stateLabel.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$stateLabel.Text = 'not read yet'

$logTitle = New-Object System.Windows.Forms.Label
$logTitle.Text = 'ACTIVITY'
$logTitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8)
$logTitle.ForeColor = $ui.Accent
$logTitle.Dock = 'Top'
$logTitle.Height = 24

# RichTextBox honours a custom background when ReadOnly; plain TextBox forces the system colour.
$logBox = New-Object System.Windows.Forms.RichTextBox
$logBox.ReadOnly = $true
$logBox.Dock = 'Fill'
$logBox.BackColor = $ui.Bg
$logBox.ForeColor = $ui.Muted
$logBox.BorderStyle = 'None'
$logBox.DetectUrls = $false
$logBox.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
$logBox.Font = New-Object System.Drawing.Font('Consolas', 8.5)

$details.Controls.AddRange(@($logBox, $logTitle, $stateLabel, $stateTitle, $noteLabel, $noteTitle))
$details.Add_Paint({
    param($sender, $e)
    $pen = New-Object System.Drawing.Pen($ui.Line, 1)
    $e.Graphics.DrawLine($pen, 0, 0, 0, $sender.Height)
    $pen.Dispose()
})

$list = New-Object System.Windows.Forms.FlowLayoutPanel
$list.Dock = 'Fill'
$list.AutoScroll = $true
$list.FlowDirection = 'TopDown'
$list.WrapContents = $false
$list.BackColor = $ui.Bg
$list.Padding = New-Object System.Windows.Forms.Padding(16, 6, 10, 10)
# Docked fill control goes in first: WinForms lays out docked siblings in reverse
# add-order, so a fill added last would sit on top of the top/right panels.
$content.Controls.Add($list)
$content.Controls.Add($contentHeader)
$content.Controls.Add($details)

$form.Controls.Add($content)
$form.Controls.Add($side)
$form.Controls.Add($header)
$form.Controls.Add($bottom)

function Write-Log {
    param([string]$Text)
    $stamp = Get-Date -Format 'HH:mm:ss'
    $logBox.AppendText("[$stamp] $Text`r`n")
    $logBox.SelectionStart = $logBox.TextLength
    $logBox.ScrollToCaret()
}

function Invoke-AstraModule {
    param([string]$Script, [string]$Mode)
    $file = Join-Path $root (Join-Path 'Modules' $Script)
    try {
        $out = & $file -Mode $Mode 2>&1
        if ($null -eq $out) { return '' }
        return (($out | ForEach-Object { [string]$_ }) -join ' | ')
    }
    catch {
        throw $_.Exception.Message
    }
}

function Update-AstraState {
    param($Module)
    try {
        $text = Invoke-AstraModule $Module.Script 'Status'
        $state = if ($text -match '^ON') { 'ON' }
        elseif ($text -match '^OFF') { 'OFF' }
        elseif ($text -match '^MIXED') { 'MIXED' }
        else { '?' }
        $script:States[$Module.N] = @{ State = $state; Text = $text }
    }
    catch {
        $script:States[$Module.N] = @{ State = '?'; Text = "error: $($_.Exception.Message)" }
    }
}

function Get-VisibleModules {
    $needle = $script:Query.Trim()
    foreach ($m in $AstraModules) {
        if ($script:Filter -ne 'All' -and $m.Group -ne $script:Filter) { continue }
        if ($needle -and ("$($m.Label) $($m.Group) $($m.Note)" -notlike "*$needle*")) { continue }
        $m
    }
}

function Update-StatusBar {
    $on = @($script:States.Values | Where-Object { $_.State -eq 'ON' }).Count
    $off = @($script:States.Values | Where-Object { $_.State -eq 'OFF' }).Count
    $mixed = @($script:States.Values | Where-Object { $_.State -eq 'MIXED' }).Count
    $visible = @(Get-VisibleModules).Count
    $statusLabel.Text = "$on ON   $off OFF   $mixed MIXED   |   $visible in view of $($AstraModules.Count)"
}

function Update-Nav {
    foreach ($item in $script:NavItems) {
        $active = $item.Tag -eq $script:Filter
        $item.Panel.BackColor = if ($active) { $ui.NavActive } else { $ui.Sidebar }
        $item.Label.ForeColor = if ($active) { $ui.Text } else { $ui.Muted }
        $item.Badge.ForeColor = if ($active) { $ui.On } else { $ui.Dim }
        $item.Bar.Visible = $active
    }
}

function Set-Filter {
    param([string]$Group)
    $script:Filter = $Group
    $pageTitle.Text = if ($Group -eq 'All') { 'All tweaks' } else { $Group }
    $pageSub.Text = $groupBlurb[$Group]
    Update-Nav
    Build-Rows
}

function Set-RowState {
    param($Row, [string]$State)
    $color = switch ($State) {
        'ON' { $ui.On }
        'OFF' { $ui.Off }
        'MIXED' { $ui.Mixed }
        default { $ui.Mixed }
    }
    $Row.Pill.Text = $State
    $Row.Pill.ForeColor = $color
}

function Rescan {
    param([switch]$Quiet)
    $script:Busy = $true
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    if (-not $Quiet) { Write-Log 'scanning tweak states...' }
    foreach ($m in $AstraModules) {
        Update-AstraState $m
        $row = $script:Rows | Where-Object { $_.N -eq $m.N }
        if ($row) { Set-RowState -Row $row -State $script:States[$m.N].State }
        [System.Windows.Forms.Application]::DoEvents()
    }
    Update-StatusBar
    if ($script:SelectedRow) {
        $st = $script:States[$script:SelectedRow.N]
        if ($st) { $stateLabel.Text = $st.Text }
    }
    $form.Cursor = [System.Windows.Forms.Cursors]::Default
    $script:Busy = $false
    if (-not $Quiet) { Write-Log 'scan complete' }
}

function Apply-One {
    param($Module, [string]$Mode)
    if ($script:Busy) { return }
    if (-not $isAdmin) { Write-Log 'blocked: run the app as administrator'; return }
    if ($Module.Risk -and $Mode -eq 'On') {
        $answer = [System.Windows.Forms.MessageBox]::Show(
            "$($Module.Label) is a risky tweak.`r`n`r`n$($Module.Note)`r`n`r`nTurn it ON?",
            'Astra', 'YesNo', 'Warning')
        if ($answer -ne 'Yes') { Write-Log "skipped $($Module.Label)"; return }
    }
    $script:Busy = $true
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    try {
        $result = Invoke-AstraModule $Module.Script $Mode
        Write-Log "$($Module.Label) -> $Mode. $result"
    }
    catch {
        Write-Log "FAILED $($Module.Label): $($_.Exception.Message)"
    }
    Update-AstraState $Module
    $row = $script:Rows | Where-Object { $_.N -eq $Module.N }
    if ($row) { Set-RowState -Row $row -State $script:States[$Module.N].State }
    if ($script:SelectedRow -and $script:SelectedRow.N -eq $Module.N) {
        $stateLabel.Text = $script:States[$Module.N].Text
    }
    Update-StatusBar
    $form.Cursor = [System.Windows.Forms.Cursors]::Default
    $script:Busy = $false
}

function Apply-Bulk {
    param([string]$Mode)
    if ($script:Busy) { return }
    if (-not $isAdmin) { Write-Log 'blocked: run the app as administrator'; return }
    $targets = @(Get-VisibleModules | Where-Object { -not $_.IndividualOnly })
    if (-not $targets.Count) { Write-Log 'nothing in this view to apply'; return }
    $risky = @($targets | Where-Object { $_.Risk })
    $msg = "Apply $Mode to $($targets.Count) tweaks in this view?"
    if ($risky.Count) { $msg += "`r`n`r`nIncludes $($risky.Count) risky item(s): $(($risky | ForEach-Object { $_.Label }) -join ', ')." }
    $answer = [System.Windows.Forms.MessageBox]::Show($msg, 'Astra', 'YesNo', 'Question')
    if ($answer -ne 'Yes') { return }

    $script:Busy = $true
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $index = 0
    foreach ($m in $targets) {
        $index++
        $statusLabel.Text = "applying $index / $($targets.Count)..."
        try { $result = Invoke-AstraModule $m.Script $Mode; Write-Log "$($m.Label) -> $Mode" }
        catch { Write-Log "FAILED $($m.Label): $($_.Exception.Message)" }
        Update-AstraState $m
        $row = $script:Rows | Where-Object { $_.N -eq $m.N }
        if ($row) { Set-RowState -Row $row -State $script:States[$m.N].State }
        [System.Windows.Forms.Application]::DoEvents()
    }
    Write-Log "bulk $Mode complete"
    Update-StatusBar
    $form.Cursor = [System.Windows.Forms.Cursors]::Default
    $script:Busy = $false
}

function Select-Row {
    param($Row)
    if ($script:SelectedRow -and $script:SelectedRow.Bar) { $script:SelectedRow.Bar.Visible = $false }
    $script:SelectedRow = $Row
    if ($Row) { $Row.Bar.Visible = $true }
}

function Build-Rows {
    $list.SuspendLayout()
    $list.Controls.Clear()
    $script:Rows = @()
    $width = $list.ClientSize.Width - $list.Padding.Horizontal - 22
    if ($width -lt 440) { $width = 440 }
    $script:LastWidth = $list.ClientSize.Width

    $visible = @(Get-VisibleModules)
    $index = 0
    foreach ($m in $visible) {
        $index++
        $base = if ($index % 2) { $ui.Row } else { $ui.RowAlt }

        $rowPanel = New-Object System.Windows.Forms.Panel
        $rowPanel.Size = New-Object System.Drawing.Size($width, 58)
        $rowPanel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 6)
        $rowPanel.BackColor = $base
        $rowPanel.Tag = $m
        $rowPanel.Cursor = [System.Windows.Forms.Cursors]::Hand

        $bar = New-Object System.Windows.Forms.Panel
        $bar.BackColor = $ui.Hot
        $bar.Location = New-Object System.Drawing.Point(0, 0)
        $bar.Size = New-Object System.Drawing.Size(3, 58)
        $bar.Visible = $false

        $num = New-Object System.Windows.Forms.Label
        $num.Text = ('{0:D2}' -f $m.N)
        $num.ForeColor = $ui.Muted
        $num.Font = New-Object System.Drawing.Font('Consolas', 10)
        $num.Location = New-Object System.Drawing.Point(12, 19)
        $num.Size = New-Object System.Drawing.Size(30, 20)

        $name = New-Object System.Windows.Forms.Label
        $name.Text = $m.Label
        $name.ForeColor = $ui.Text
        $name.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9.5)
        $name.Location = New-Object System.Drawing.Point(48, 9)
        $name.Size = New-Object System.Drawing.Size([math]::Max(140, $width - 300), 20)
        $name.AutoEllipsis = $true

        $note = New-Object System.Windows.Forms.Label
        $note.Text = "$($m.Group)  -  $($m.Note)"
        $note.ForeColor = if ($m.Risk) { $ui.Mixed } else { $ui.Muted }
        $note.Font = New-Object System.Drawing.Font('Segoe UI', 8)
        $note.Location = New-Object System.Drawing.Point(48, 32)
        $note.Size = New-Object System.Drawing.Size([math]::Max(140, $width - 300), 18)
        $note.AutoEllipsis = $true

        $pill = New-Object System.Windows.Forms.Label
        $pill.Text = '...'
        $pill.TextAlign = 'MiddleCenter'
        $pill.Font = New-Object System.Drawing.Font('Consolas', 9, [System.Drawing.FontStyle]::Bold)
        $pill.ForeColor = $ui.Muted
        $pill.BackColor = $ui.Bg
        $pill.Location = New-Object System.Drawing.Point(($width - 250), 18)
        $pill.Size = New-Object System.Drawing.Size(78, 22)

        $btnOn = New-Object System.Windows.Forms.Button
        $btnOn.Text = 'ON'
        $btnOn.FlatStyle = 'Flat'
        $btnOn.FlatAppearance.BorderSize = 1
        $btnOn.FlatAppearance.BorderColor = $ui.Line
        $btnOn.BackColor = $ui.Panel
        $btnOn.ForeColor = $ui.On
        $btnOn.Location = New-Object System.Drawing.Point(($width - 168), 14)
        $btnOn.Size = New-Object System.Drawing.Size(70, 28)
        $btnOn.Enabled = $isAdmin
        $btnOn.Tag = $m
        $btnOn.Cursor = [System.Windows.Forms.Cursors]::Hand
        $btnOn.Add_Click({ param($sender, $e) Apply-One $sender.Tag 'On' })

        $btnOff = New-Object System.Windows.Forms.Button
        $btnOff.Text = 'OFF'
        $btnOff.FlatStyle = 'Flat'
        $btnOff.FlatAppearance.BorderSize = 1
        $btnOff.FlatAppearance.BorderColor = $ui.Line
        $btnOff.BackColor = $ui.Panel
        $btnOff.ForeColor = $ui.Off
        $btnOff.Location = New-Object System.Drawing.Point(($width - 92), 14)
        $btnOff.Size = New-Object System.Drawing.Size(70, 28)
        $btnOff.Enabled = $isAdmin
        $btnOff.Tag = $m
        $btnOff.Cursor = [System.Windows.Forms.Cursors]::Hand
        $btnOff.Add_Click({ param($sender, $e) Apply-One $sender.Tag 'Off' })

        $rowPanel.Controls.AddRange(@($bar, $num, $name, $note, $pill, $btnOn, $btnOff))
        $rowPanel.Add_Click({ param($sender, $e) Show-Note $sender.Tag $sender })
        $num.Add_Click({ param($sender, $e) Show-Note $sender.Parent.Tag $sender.Parent })
        $name.Add_Click({ param($sender, $e) Show-Note $sender.Parent.Tag $sender.Parent })
        $note.Add_Click({ param($sender, $e) Show-Note $sender.Parent.Tag $sender.Parent })
        $pill.Add_Click({ param($sender, $e) Show-Note $sender.Parent.Tag $sender.Parent })

        $list.Controls.Add($rowPanel)
        $script:Rows += [pscustomobject]@{ N = $m.N; Panel = $rowPanel; Pill = $pill; Bar = $bar }
    }
    $list.ResumeLayout()
    $list.AutoScrollPosition = New-Object System.Drawing.Point(0, 0)

    foreach ($row in $script:Rows) {
        $st = $script:States[$row.N]
        if ($st) { Set-RowState -Row $row -State $st.State }
    }
    if ($script:SelectedRow) {
        $same = $script:Rows | Where-Object { $_.N -eq $script:SelectedRow.N } | Select-Object -First 1
        if ($same) { Select-Row $same }
        else { Select-Row $null; $noteLabel.Text = 'Select a row for details.'; $stateLabel.Text = 'not read yet' }
    }
    if (-not $visible.Count) {
        $empty = New-Object System.Windows.Forms.Label
        $empty.Text = 'No tweaks match this category and search.'
        $empty.ForeColor = $ui.Muted
        $empty.AutoSize = $true
        $empty.Margin = New-Object System.Windows.Forms.Padding(4, 20, 0, 0)
        $list.Controls.Add($empty)
    }
    Update-StatusBar
}

function Show-Note {
    param($Module, $Row)
    if (-not $Module) { return }
    Select-Row $Row
    $noteLabel.Text = "$($Module.Label)`r`n`r`n$($Module.Note)"
    $st = $script:States[$Module.N]
    if ($st) {
        $stateLabel.Text = $st.Text
        Write-Log "state: $($st.Text)"
    }
    else {
        $stateLabel.Text = 'not read yet'
    }
}

$list.Add_Resize({ if (-not $script:Busy -and [math]::Abs($list.ClientSize.Width - $script:LastWidth) -ge 8) { Build-Rows } })
$search.Add_GotFocus({
    if ($search.Text -eq $script:SearchPlaceholder) {
        $search.Text = ''
        $search.ForeColor = $ui.Text
    }
})
$search.Add_LostFocus({
    if (-not $search.Text.Trim()) {
        $search.Text = $script:SearchPlaceholder
        $search.ForeColor = $ui.Muted
        $script:Query = ''
        Build-Rows
    }
})
$search.Add_TextChanged({
    if ($search.Text -eq $script:SearchPlaceholder) { return }
    $script:Query = $search.Text
    Build-Rows
})

$form.Add_KeyDown({
    param($sender, $e)
    if ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::F) { $search.Focus(); $e.SuppressKeyPress = $true }
    elseif ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $form.Close() }
})

$form.Add_Shown({
    # Defer until the dock layout has settled, otherwise rows are sized for the
    # pre-layout width and the ON/OFF buttons land off-screen.
    $form.BeginInvoke([Action]{
        $dark = 1
        try { [void][AstraDwm]::DwmSetWindowAttribute($form.Handle, 20, [ref]$dark, 4) }
        catch { try { [void][AstraDwm]::DwmSetWindowAttribute($form.Handle, 19, [ref]$dark, 4) } catch { } }
        Update-Nav
        Build-Rows
        Rescan
        Write-Log "ready. $($AstraModules.Count) tweaks available."
        if (-not $isAdmin) { Write-Log 'not elevated: toggles disabled, states still shown' }
    })
})

$btnRefresh.Add_Click({ Rescan })
$btnAllOn.Add_Click({ Apply-Bulk 'On' })
$btnAllOff.Add_Click({ Apply-Bulk 'Off' })
$btnFolder.Add_Click({ Start-Process -FilePath 'explorer.exe' -ArgumentList "`"$root`"" })
$btnVerify.Add_Click({
    $verify = 'C:\AstraMax\Verify.ps1'
    if (-not (Test-Path -LiteralPath $verify)) { Write-Log 'Verify.ps1 not found in C:\AstraMax'; return }
    Write-Log 'running Verify.ps1...'
    try {
        $out = & $verify 2>&1
        foreach ($line in $out) { Write-Log ([string]$line) }
    }
    catch { Write-Log "verify failed: $($_.Exception.Message)" }
})
$btnSiege.Add_Click({
    $tool = 'C:\AstraMax\GameProfiles.ps1'
    if (-not (Test-Path -LiteralPath $tool)) { Write-Log 'GameProfiles.ps1 not found in C:\AstraMax'; return }
    Write-Log 'applying Siege profile and Ubisoft Connect launch shortcut...'
    try {
        $out = & $tool -Siege -ApplyLaunchOptions 2>&1
        foreach ($line in $out) { Write-Log ([string]$line) }
    }
    catch { Write-Log "siege action failed: $($_.Exception.Message)" }
})

[void]$form.ShowDialog()
