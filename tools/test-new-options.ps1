#requires -Version 5.1
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$src = Join-Path (Split-Path $PSScriptRoot -Parent) 'src\Executables'
$temp = Join-Path $env:TEMP ('AstraOptions-' + [guid]::NewGuid())
$registry = 'HKCU:\Software\AstraOptions-' + [guid]::NewGuid()
$originalLocal = $env:LOCALAPPDATA
New-Item -ItemType Directory -Path $temp -Force | Out-Null
New-Item -Path $registry -Force | Out-Null
function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message }; "PASS: $Message" }
function Import-Functions([string]$File, [string[]]$Names) {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($File, [ref]$null, [ref]$null)
    foreach ($node in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
        if ($node.Name -in $Names) {
            $text = $node.Extent.Text.Replace('HKCU:\Software\Microsoft\DirectX\UserGpuPreferences', ($registry + '\Gpu'))
            . ([scriptblock]::Create($text))
            Set-Item -Path ('Function:script:' + $node.Name) -Value (Get-Item ('Function:' + $node.Name)).ScriptBlock
        }
    }
}
try {
    $env:LOCALAPPDATA = $temp
    $qol = Get-Content (Join-Path $src 'QoL.ps1') -Raw
    $qol = $qol.Replace('HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize', ($registry + '\Theme')).Replace('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced', ($registry + '\Explorer')).Replace('HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications', ($registry + '\Bg')).Replace('HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl', ($registry + '\Priority')).Replace('HKCU:\Control Panel\Desktop\WindowMetrics', ($registry + '\Metrics')).Replace('HKCU:\Control Panel\Desktop', ($registry + '\Desktop')).Replace('HKCU:\Control Panel\Accessibility', ($registry + '\A11y')).Replace('HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications', ($registry + '\Push')).Replace('HKCU:\Software\Microsoft\Narrator\NoRoam', ($registry + '\Narrator')).Replace('HKCU:\Software\Microsoft\Windows\CurrentVersion\PenWorkspace', ($registry + '\Pen')).Replace('HKCU:\Software\Policies\Microsoft\Edge', ($registry + '\Edge')).Replace('HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', ($registry + '\CDM')).Replace('HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement', ($registry + '\UPE')).Replace('HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance', ($registry + '\Toast')).Replace('HKCU:\Software\Microsoft\Clipboard', ($registry + '\Clip')).Replace('HKCU:\Software\Microsoft\GameBar', ($registry + '\GameBar')).Replace('HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy', ($registry + '\Speech')).Replace('HKCU:\Software\Microsoft\InputPersonalization', ($registry + '\Input')).Replace('HKCU:\Control Panel\International\User Profile', ($registry + '\Lang')).Replace('HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy', ($registry + '\Privacy')).Replace('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState', ($registry + '\Cabinet')).Replace('HKCU:\Control Panel\Keyboard', ($registry + '\Keyboard')).Replace('HKCU:\Software\Microsoft\Multimedia\Audio', ($registry + '\Audio')).Replace('HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon', ($registry + '\Winlogon')).Replace('HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings', ($registry + '\SearchSettings')).Replace('HKCU:\Software\Microsoft\Windows\CurrentVersion\Search', ($registry + '\Search')).Replace('HKCU:\System\GameConfigStore', ($registry + '\Gcs')).Replace('HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR', ($registry + '\Dvr')).Replace('HKLM:\Software\Policies\Microsoft\Windows\GameDVR', ($registry + '\DvrPolicy')).Replace('HKLM:\SOFTWARE\Microsoft\Windows\Dwm', ($registry + '\Dwm')).Replace('HKLM:\Software\Policies\Microsoft\Windows\Psched', ($registry + '\Psched')).Replace('HKCU:\Software\Policies\Microsoft\Windows\WindowsAI', ($registry + '\WindowsAI'))
    New-Item ($registry + '\Theme') -Force | Out-Null
    Set-ItemProperty ($registry + '\Theme') 'Unrelated' 17 -Type DWord
    & ([scriptblock]::Create($qol)) -DarkMode On -EndTask On | Out-Null
    $values = Get-ItemProperty ($registry + '\Theme')
    Assert ($values.AppsUseLightTheme -eq 0 -and $values.SystemUsesLightTheme -eq 0) 'Dark mode sets both theme values'
    Assert ($values.Unrelated -eq 17) 'Theme writes preserve unrelated values'
    Assert ((Get-ItemProperty ($registry + '\Explorer\TaskbarDeveloperSettings')).TaskbarEndTask -eq 1) 'End task enabled at the correct key'
    & ([scriptblock]::Create($qol)) -DarkMode Off -EndTask Off | Out-Null
    $values = Get-ItemProperty ($registry + '\Theme')
    Assert ($values.AppsUseLightTheme -eq 1 -and $values.SystemUsesLightTheme -eq 1 -and $values.Unrelated -eq 17) 'Light mode restoration preserves other settings'
    & ([scriptblock]::Create($qol)) -BackgroundApps On -SyncAds On -AeroShake On | Out-Null
    $bg = Get-ItemProperty ($registry + '\Bg')
    Assert ($bg.GlobalUserDisabled -eq 1 -and $bg.BackgroundAppGlobalToggle -eq 0) 'Background apps off writes both user values'
    $explorer = Get-ItemProperty ($registry + '\Explorer')
    Assert ($explorer.ShowSyncProviderNotifications -eq 0 -and $explorer.NoWindowMinimizingShortcuts -eq 1) 'Sync ads and Aero Shake toggles write the Explorer values'
    & ([scriptblock]::Create($qol)) -BackgroundApps Off -SyncAds Off -AeroShake Off | Out-Null
    $bg = Get-ItemProperty ($registry + '\Bg')
    Assert ($bg.GlobalUserDisabled -eq 0 -and $bg.PSObject.Properties.Name -notcontains 'BackgroundAppGlobalToggle') 'Background apps restore the Windows default'
    $explorer = Get-ItemProperty ($registry + '\Explorer')
    Assert ($explorer.PSObject.Properties.Name -notcontains 'ShowSyncProviderNotifications' -and $explorer.PSObject.Properties.Name -notcontains 'NoWindowMinimizingShortcuts') 'Sync ads and Aero Shake restore the Windows default'
    Assert ($qol -match 'Win32PrioritySeparation' -and $qol -match '\{ 38 \}') 'Priority boost uses the documented 38 value'
    New-Item ($registry + '\Metrics') -Force | Out-Null
    & ([scriptblock]::Create($qol)) -Animations On | Out-Null
    $metrics = Get-ItemProperty ($registry + '\Metrics')
    $explorer = Get-ItemProperty ($registry + '\Explorer')
    Assert ("$($metrics.MinAnimate)" -eq '0' -and $explorer.TaskbarAnimations -eq 0) 'Animations off writes window and taskbar values'
    & ([scriptblock]::Create($qol)) -Animations Off | Out-Null
    $metrics = Get-ItemProperty ($registry + '\Metrics')
    $explorer = Get-ItemProperty ($registry + '\Explorer')
    Assert ("$($metrics.MinAnimate)" -eq '1' -and $explorer.TaskbarAnimations -eq 1) 'Animations restore the Windows defaults'
    & ([scriptblock]::Create($qol)) -Notifications On -MenuDelay On -A11yKeys On -InkWorkspace On -EdgeGaming On | Out-Null
    Assert ((Get-ItemProperty ($registry + '\Push')).ToastEnabled -eq 0) 'Notification toggle turns toast pop-ups off'
    Assert ((Get-ItemProperty ($registry + '\Desktop')).MenuShowDelay -eq '0') 'Menu delay toggle writes zero delay'
    Assert ((Get-ItemProperty ($registry + '\A11y\StickyKeys')).Flags -eq '506' -and (Get-ItemProperty ($registry + '\A11y\Keyboard Response')).Flags -eq '122' -and (Get-ItemProperty ($registry + '\A11y\ToggleKeys')).Flags -eq '58' -and (Get-ItemProperty ($registry + '\Narrator')).WinEnterLaunchEnabled -eq 0) 'Accessibility toggle disables all four shortcut paths'
    Assert ((Get-ItemProperty ($registry + '\Pen')).PenWorkspaceButtonDesiredVisibility -eq 0) 'Ink toggle hides the workspace button'
    $edge = Get-ItemProperty ($registry + '\Edge')
    Assert ($edge.HubsSidebarEnabled -eq 0 -and $edge.EdgeShoppingAssistantEnabled -eq 0 -and $edge.WebWidgetAllowed -eq 0 -and $edge.HideFirstRunExperience -eq 1) 'Edge gaming policies set all four values'
    & ([scriptblock]::Create($qol)) -Notifications Off -MenuDelay Off -A11yKeys Off -InkWorkspace Off -EdgeGaming Off | Out-Null
    Assert ((Get-ItemProperty ($registry + '\Push')).ToastEnabled -eq 1) 'Notification toggle restores the Windows default'
    Assert ((Get-ItemProperty ($registry + '\Desktop')).MenuShowDelay -eq '400') 'Menu delay toggle restores the 400 ms default'
    Assert ((Get-ItemProperty ($registry + '\A11y\StickyKeys')).Flags -eq '510' -and (Get-ItemProperty ($registry + '\A11y\Keyboard Response')).Flags -eq '126' -and (Get-ItemProperty ($registry + '\A11y\ToggleKeys')).Flags -eq '62' -and (Get-ItemProperty ($registry + '\Narrator')).WinEnterLaunchEnabled -eq 1) 'Accessibility toggle restores the Windows defaults'
    Assert ((Get-ItemProperty ($registry + '\Pen')).PenWorkspaceButtonDesiredVisibility -eq 1) 'Ink toggle restores the Windows default'
    $edge = Get-ItemProperty ($registry + '\Edge')
    Assert ($edge.PSObject.Properties.Name -notcontains 'HubsSidebarEnabled' -and $edge.PSObject.Properties.Name -notcontains 'EdgeShoppingAssistantEnabled' -and $edge.PSObject.Properties.Name -notcontains 'WebWidgetAllowed' -and $edge.PSObject.Properties.Name -notcontains 'HideFirstRunExperience') 'Edge gaming policies remove only their own values'
    & ([scriptblock]::Create($qol)) -Spotlight On -Scoobe On -StartRecentApps On | Out-Null
    Assert ((Get-ItemProperty ($registry + '\CDM')).RotatingLockScreenEnabled -eq 0 -and (Get-ItemProperty ($registry + '\CDM')).RotatingLockScreenOverlayEnabled -eq 0) 'Spotlight toggle turns off the rotating lock screen and its tips'
    Assert ((Get-ItemProperty ($registry + '\UPE')).ScoobeSystemSettingEnabled -eq 0) 'Setup-prompt toggle writes the documented value'
    Assert ((Get-ItemProperty ($registry + '\Explorer')).Start_TrackProgs -eq 0) 'Recently added apps toggle writes the documented value'
    & ([scriptblock]::Create($qol)) -Spotlight Off -Scoobe Off -StartRecentApps Off | Out-Null
    $cdm = Get-ItemProperty ($registry + '\CDM')
    $upe = Get-ItemProperty ($registry + '\UPE')
    Assert ($cdm.PSObject.Properties.Name -notcontains 'RotatingLockScreenEnabled' -and $cdm.PSObject.Properties.Name -notcontains 'RotatingLockScreenOverlayEnabled') 'Spotlight toggle restores the Windows default'
    Assert ($upe.PSObject.Properties.Name -notcontains 'ScoobeSystemSettingEnabled') 'Setup-prompt toggle restores the Windows default'
    Assert ((Get-ItemProperty ($registry + '\Explorer')).PSObject.Properties.Name -notcontains 'Start_TrackProgs') 'Recently added apps toggle restores the Windows default'
    & ([scriptblock]::Create($qol)) -SecurityNotifications On -CloudClipboard On -GameBarTips On | Out-Null
    Assert ((Get-ItemProperty ($registry + '\Toast')).Enabled -eq 0) 'Security Center toggle turns toast alerts off'
    Assert ((Get-ItemProperty ($registry + '\Clip')).CloudClipboardAutomaticUpload -eq 0) 'Cloud clipboard toggle stops automatic upload'
    Assert ((Get-ItemProperty ($registry + '\GameBar')).ShowStartupPanel -eq 0) 'Game Bar toggle hides the startup panel'
    & ([scriptblock]::Create($qol)) -SecurityNotifications Off -CloudClipboard Off -GameBarTips Off | Out-Null
    Assert ((Get-ItemProperty ($registry + '\Toast')).Enabled -eq 1) 'Security Center toggle restores the default'
    Assert ((Get-ItemProperty ($registry + '\Clip')).PSObject.Properties.Name -notcontains 'CloudClipboardAutomaticUpload') 'Cloud clipboard toggle restores the default'
    Assert ((Get-ItemProperty ($registry + '\GameBar')).ShowStartupPanel -eq 1) 'Game Bar toggle restores the default'
    & ([scriptblock]::Create($qol)) -OnlineSpeech On -InkTyping On -LanguageList On -TailoredExperiences On -HiddenFiles On -FullPath On -TaskbarSmallIcons On -HoverDelay On -KeyboardRepeat On -AudioDucking On -RestartApps On | Out-Null
    Assert ((Get-ItemProperty ($registry + '\Speech')).HasAccepted -eq 0) 'Online speech toggle declines cloud speech'
    Assert ((Get-ItemProperty ($registry + '\Input')).RestrictImplicitTextCollection -eq 1 -and (Get-ItemProperty ($registry + '\Input')).RestrictImplicitInkCollection -eq 1) 'Ink and typing toggle sets both restriction values'
    Assert ((Get-ItemProperty ($registry + '\Lang')).HttpAcceptLanguageOptOut -eq 1) 'Language list toggle blocks website access'
    Assert ((Get-ItemProperty ($registry + '\Privacy')).TailoredExperiencesWithDiagnosticDataEnabled -eq 0) 'Tailored experiences toggle writes the documented value'
    $explorer = Get-ItemProperty ($registry + '\Explorer')
    Assert ($explorer.Hidden -eq 1 -and $explorer.TaskbarSmallIcons -eq 1 -and $explorer.ExtendedUIHoverTime -eq 0) 'Explorer, taskbar size and preview delay toggles write their values'
    Assert ((Get-ItemProperty ($registry + '\Cabinet')).FullPath -eq 1) 'Full path toggle writes the title-bar value'
    $keyboard = Get-ItemProperty ($registry + '\Keyboard')
    Assert ($keyboard.KeyboardDelay -eq '0' -and $keyboard.KeyboardSpeed -eq '31') 'Keyboard toggle writes the fastest repeat values'
    Assert ((Get-ItemProperty ($registry + '\Audio')).UserDuckingPreference -eq 3) 'Audio toggle stops communications ducking'
    Assert ((Get-ItemProperty ($registry + '\Winlogon')).RestartApps -eq 0) 'Restart-apps toggle writes the documented value'
    & ([scriptblock]::Create($qol)) -OnlineSpeech Off -InkTyping Off -LanguageList Off -TailoredExperiences Off -HiddenFiles Off -FullPath Off -TaskbarSmallIcons Off -HoverDelay Off -KeyboardRepeat Off -AudioDucking Off -RestartApps Off | Out-Null
    Assert ((Get-ItemProperty ($registry + '\Speech')).PSObject.Properties.Name -notcontains 'HasAccepted') 'Online speech toggle removes the override'
    Assert ((Get-ItemProperty ($registry + '\Input')).PSObject.Properties.Name -notcontains 'RestrictImplicitTextCollection') 'Ink and typing toggle removes both restrictions'
    Assert ((Get-ItemProperty ($registry + '\Lang')).PSObject.Properties.Name -notcontains 'HttpAcceptLanguageOptOut') 'Language list toggle restores the default access'
    Assert ((Get-ItemProperty ($registry + '\Privacy')).PSObject.Properties.Name -notcontains 'TailoredExperiencesWithDiagnosticDataEnabled') 'Tailored experiences toggle restores the default'
    $explorer = Get-ItemProperty ($registry + '\Explorer')
    Assert ($explorer.Hidden -eq 0 -and $explorer.TaskbarSmallIcons -eq 0 -and $explorer.PSObject.Properties.Name -notcontains 'ExtendedUIHoverTime') 'Explorer, taskbar size and preview delay toggles restore the defaults'
    Assert ((Get-ItemProperty ($registry + '\Cabinet')).FullPath -eq 0) 'Full path toggle restores the default title bar'
    $keyboard = Get-ItemProperty ($registry + '\Keyboard')
    Assert ($keyboard.KeyboardDelay -eq '1' -and $keyboard.KeyboardSpeed -eq '31') 'Keyboard toggle restores the normal delay'
    Assert ((Get-ItemProperty ($registry + '\Audio')).PSObject.Properties.Name -notcontains 'UserDuckingPreference') 'Audio toggle restores the default ducking'
    Assert ((Get-ItemProperty ($registry + '\Winlogon')).PSObject.Properties.Name -notcontains 'RestartApps') 'Restart-apps toggle restores the default'
    & ([scriptblock]::Create($qol)) -GameDvr On -FullscreenOpt On -Mpo On -QosBandwidth On -SearchLocal On -CloudSearch On -Recall On -Widgets On | Out-Null
    $gcs = Get-ItemProperty ($registry + '\Gcs')
    Assert ($gcs.GameDVR_Enabled -eq 0 -and (Get-ItemProperty ($registry + '\Dvr')).AppCaptureEnabled -eq 0 -and (Get-ItemProperty ($registry + '\DvrPolicy')).AllowGameDVR -eq 0) 'Game DVR toggle disables capture, background recording and the policy'
    Assert ($gcs.GameDVR_FSEBehaviorMode -eq 2 -and $gcs.GameDVR_HonorUserFSEBehaviorMode -eq 1 -and $gcs.GameDVR_DXGIHonorFSEWindowsCompatible -eq 1 -and $gcs.GameDVR_EFSEFeatureFlags -eq 0) 'Fullscreen optimizations toggle writes the four Astra values'
    Assert ((Get-ItemProperty ($registry + '\Dwm')).OverlayTestMode -eq 5) 'MPO toggle writes OverlayTestMode 5'
    Assert ((Get-ItemProperty ($registry + '\Psched')).NonBestEffortLimit -eq 0) 'QoS toggle releases the reserved bandwidth'
    Assert ((Get-ItemProperty ($registry + '\Search')).BingSearchEnabled -eq 0) 'Local search toggle stops Bing results'
    $searchSettings = Get-ItemProperty ($registry + '\SearchSettings')
    Assert ($searchSettings.IsMSACloudSearchEnabled -eq 0 -and $searchSettings.IsAADCloudSearchEnabled -eq 0) 'Cloud search toggle writes both account values'
    Assert ((Get-ItemProperty ($registry + '\WindowsAI')).DisableAIDataAnalysis -eq 1) 'Recall toggle disables snapshots'
    Assert ((Get-ItemProperty ($registry + '\Explorer')).TaskbarDa -eq 0) 'Widgets toggle hides the taskbar button'
    & ([scriptblock]::Create($qol)) -GameDvr Off -FullscreenOpt Off -Mpo Off -QosBandwidth Off -SearchLocal Off -CloudSearch Off -Recall Off -Widgets Off | Out-Null
    $gcs = Get-ItemProperty ($registry + '\Gcs')
    Assert ($gcs.GameDVR_Enabled -eq 1 -and (Get-ItemProperty ($registry + '\Dvr')).AppCaptureEnabled -eq 1 -and (Get-ItemProperty ($registry + '\DvrPolicy')).PSObject.Properties.Name -notcontains 'AllowGameDVR') 'Game DVR toggle restores capture and removes the policy'
    Assert ($gcs.GameDVR_FSEBehaviorMode -eq 0 -and $gcs.GameDVR_HonorUserFSEBehaviorMode -eq 0 -and $gcs.GameDVR_DXGIHonorFSEWindowsCompatible -eq 0) 'Fullscreen optimizations toggle restores the defaults'
    Assert ((Get-ItemProperty ($registry + '\Dwm')).PSObject.Properties.Name -notcontains 'OverlayTestMode') 'MPO toggle removes the override'
    Assert ((Get-ItemProperty ($registry + '\Psched')).PSObject.Properties.Name -notcontains 'NonBestEffortLimit') 'QoS toggle removes the policy'
    Assert ((Get-ItemProperty ($registry + '\Search')).BingSearchEnabled -eq 1) 'Local search toggle restores web results'
    $searchSettings = Get-ItemProperty ($registry + '\SearchSettings')
    Assert ($searchSettings.PSObject.Properties.Name -notcontains 'IsMSACloudSearchEnabled' -and $searchSettings.PSObject.Properties.Name -notcontains 'IsAADCloudSearchEnabled') 'Cloud search toggle removes both values'
    Assert ((Get-ItemProperty ($registry + '\WindowsAI')).PSObject.Properties.Name -notcontains 'DisableAIDataAnalysis') 'Recall toggle removes the policy'
    Assert ((Get-ItemProperty ($registry + '\Explorer')).TaskbarDa -eq 1) 'Widgets toggle restores the button'
    $tweaksText = Get-Content -LiteralPath (Join-Path $src 'Tweaks.ps1') -Raw
    $tweaksText = $tweaksText.Replace('HKCU:\Software\Microsoft\Windows\Windows Error Reporting', ($registry + '\Wer'))
    & ([scriptblock]::Create($tweaksText)) -WerUi On | Out-Null
    Assert ((Get-ItemProperty ($registry + '\Wer')).DontShowUI -eq 1) 'WER UI toggle hides crash dialogs'
    & ([scriptblock]::Create($tweaksText)) -WerUi Off | Out-Null
    Assert ((Get-ItemProperty ($registry + '\Wer')).PSObject.Properties.Name -notcontains 'DontShowUI') 'WER UI toggle restores the default dialogs'
    $originalProgramData = $env:ProgramData
    $env:ProgramData = $temp
    $security = Get-Content -LiteralPath (Join-Path $src 'Security.ps1') -Raw
    $security = $security.Replace('HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer', ($registry + '\HkcuPolicy')).Replace('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer', ($registry + '\Explorer')).Replace('HKLM:\SOFTWARE\Policies\Microsoft\Windows\System', ($registry + '\SysPolicy')).Replace('HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient', ($registry + '\DnsPolicy')).Replace('HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management', ($registry + '\Mem')).Replace('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance', ($registry + '\Maint')).Replace('HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings', ($registry + '\Wsh'))
    New-Item ($registry + '\HkcuPolicy') -Force | Out-Null
    Set-ItemProperty ($registry + '\HkcuPolicy') 'NoDriveTypeAutoRun' 1 -Type DWord
    New-Item ($registry + '\Explorer') -Force | Out-Null
    Set-ItemProperty ($registry + '\Explorer') 'SmartScreenEnabled' 'Warn' -Type String
    & ([scriptblock]::Create($security)) -SmartScreen On -Llmnr On -Autorun On | Out-Null
    Assert ((Get-ItemProperty ($registry + '\Explorer')).SmartScreenEnabled -eq 'Warn' -and (Get-ItemProperty ($registry + '\SysPolicy')).EnableSmartScreen -eq 1) 'SmartScreen hardening writes Warn and the policy'
    Assert ((Get-ItemProperty ($registry + '\DnsPolicy')).EnableMulticast -eq 0) 'LLMNR hardening writes the policy value'
    Assert ((Get-ItemProperty ($registry + '\HkcuPolicy')).NoDriveTypeAutoRun -eq 255) 'AutoRun hardening covers all drive types'
    Assert (Test-Path (Join-Path $temp 'AstraMax\Security\SmartScreen.json')) 'Security hardening snapshots the previous values'
    & ([scriptblock]::Create($security)) -SmartScreen Off -Llmnr Off -Autorun Off | Out-Null
    Assert ((Get-ItemProperty ($registry + '\HkcuPolicy')).NoDriveTypeAutoRun -eq 1) 'AutoRun restore returns the previous value'
    Assert ((Get-ItemProperty ($registry + '\DnsPolicy')).PSObject.Properties.Name -notcontains 'EnableMulticast') 'LLMNR restore removes the value that did not exist'
    Assert (-not (Test-Path (Join-Path $temp 'AstraMax\Security\SmartScreen.json'))) 'Security restore clears the snapshot'
    & ([scriptblock]::Create($security)) -SmartScreen Off | Out-Null
    Assert ((Get-ItemProperty ($registry + '\Explorer')).SmartScreenEnabled -eq 'Off' -and (Get-ItemProperty ($registry + '\SysPolicy')).EnableSmartScreen -eq 0) 'SmartScreen off without a snapshot writes Off and policy 0'
    & ([scriptblock]::Create($security)) -PagingExecutive On -Maintenance On -ClearPagefile On -Wsh On | Out-Null
    $mem = Get-ItemProperty ($registry + '\Mem')
    Assert ($mem.DisablePagingExecutive -eq 1 -and $mem.ClearPageFileAtShutdown -eq 1) 'System toggles write the memory values'
    Assert ((Get-ItemProperty ($registry + '\Maint')).MaintenanceDisabled -eq 1) 'Maintenance toggle writes the documented value'
    Assert ((Get-ItemProperty ($registry + '\Wsh')).Enabled -eq 0) 'Script Host toggle disables WSH'
    foreach ($id in 'PagingExecutive', 'Maintenance', 'ClearPagefile', 'Wsh') {
        Assert (Test-Path (Join-Path $temp "AstraMax\Security\$id.json")) "System toggle snapshots $id"
    }
    & ([scriptblock]::Create($security)) -PagingExecutive Off -Maintenance Off -ClearPagefile Off -Wsh Off | Out-Null
    $mem = Get-ItemProperty ($registry + '\Mem')
    Assert ($mem.PSObject.Properties.Name -notcontains 'DisablePagingExecutive' -and $mem.PSObject.Properties.Name -notcontains 'ClearPageFileAtShutdown') 'System memory toggles remove values that did not exist'
    Assert ((Get-ItemProperty ($registry + '\Maint')).PSObject.Properties.Name -notcontains 'MaintenanceDisabled') 'Maintenance toggle removes the value'
    Assert ((Get-ItemProperty ($registry + '\Wsh')).PSObject.Properties.Name -notcontains 'Enabled') 'Script Host toggle removes the value'
    foreach ($id in 'PagingExecutive', 'Maintenance', 'ClearPagefile', 'Wsh') {
        Assert (-not (Test-Path (Join-Path $temp "AstraMax\Security\$id.json"))) "System toggle clears the $id snapshot"
    }
    $env:ProgramData = $originalProgramData
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AstraPowerPolicy {
    public static uint Current = 3;
    public static uint PowerGetActiveScheme(IntPtr root, out IntPtr ptr) {
        ptr=Marshal.AllocHGlobal(16);
        Marshal.StructureToPtr(new Guid("381b4222-f694-41f0-9685-ff5bb260df2e"),ptr,false);
        return 0;
    }
    public static uint PowerReadACValueIndex(IntPtr root, ref Guid scheme, ref Guid sub, ref Guid setting, out uint value) {value=Current;return 0;}
    public static IntPtr LocalFree(IntPtr ptr) {Marshal.FreeHGlobal(ptr);return IntPtr.Zero;}
}
'@
    $script:PowerCalls = @()
    function global:powercfg {
        $script:PowerCalls += ($args -join ' ')
        if ($args[0] -eq '/setacvalueindex') { [AstraPowerPolicy]::Current = [uint32]$args[4] }
        elseif ($args[0] -ne '/setactive') { throw 'Unexpected power command' }
        $global:LASTEXITCODE = 0
    }
    $hardware = Get-Content (Join-Path $src 'HardwareTweaks.ps1') -Raw
    $hardware = $hardware.Replace('HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers', ($registry + '\Drivers')).Replace('HKCU:\Software\Microsoft\DirectX\UserGpuPreferences', ($registry + '\Gpu'))
    foreach ($feature in 'CpuBoost','CpuEpp') {
        [AstraPowerPolicy]::Current = 3
        & ([scriptblock]::Create($hardware)) -Feature $feature -Mode On | Out-Null
        Assert ([AstraPowerPolicy]::Current -eq $(if ($feature -eq 'CpuBoost') { 2 } else { 0 })) "$feature writes documented AC index"
        & ([scriptblock]::Create($hardware)) -Feature $feature -Mode Off | Out-Null
        Assert ([AstraPowerPolicy]::Current -eq 3) "$feature restores original index"
    }
    Assert (-not @($script:PowerCalls | Where-Object { $_ -match 'setdc' }).Count) 'CPU policies do not change battery settings'
    foreach ($feature in 'PciePower','DiskIdle') {
        [AstraPowerPolicy]::Current = 3
        & ([scriptblock]::Create($hardware)) -Feature $feature -Mode On | Out-Null
        Assert ([AstraPowerPolicy]::Current -eq 0) "$feature writes the documented zero index"
        & ([scriptblock]::Create($hardware)) -Feature $feature -Mode Off | Out-Null
        Assert ([AstraPowerPolicy]::Current -eq 3) "$feature restores the original index"
    }
    $script:bcdText = "Windows Boot Loader`r`nidentifier            {current}`r`ndisabledynamictick      Yes`r`n"
    function global:bcdedit { $script:bcdText; $global:LASTEXITCODE = 0 }
    Assert ((& ([scriptblock]::Create($hardware)) -Feature DynamicTick -Mode Status) -match '^ON') 'Dynamic tick status reads the boot configuration'
    $script:bcdText = "Windows Boot Loader`r`nidentifier            {current}`r`n"
    Assert ((& ([scriptblock]::Create($hardware)) -Feature DynamicTick -Mode Status) -match 'setting not present') 'Dynamic tick status detects the Windows default'
    $script:bcdText = "Windows Boot Loader`r`nidentifier            {current}`r`ndisabledynamictick      No`r`n"
    Assert ((& ([scriptblock]::Create($hardware)) -Feature DynamicTick -Mode Status) -match 'disabledynamictick no') 'Dynamic tick status reports an explicit No'
    Assert ($hardware -match 'bcdedit /set' -and $hardware -match 'bcdedit /deletevalue') 'Dynamic tick writes and restores via bcdedit'
    New-Item ($registry + '\Drivers') -Force | Out-Null
    Set-ItemProperty ($registry + '\Drivers') 'HwSchMode' 1 -Type DWord
    & ([scriptblock]::Create($hardware)) -Feature GpuScheduling -Mode On | Out-Null
    & ([scriptblock]::Create($hardware)) -Feature GpuScheduling -Mode Off | Out-Null
    Assert ((Get-ItemProperty ($registry + '\Drivers')).HwSchMode -eq 1) 'HAGS restores original registry state'
    New-Item ($registry + '\Gpu') -Force | Out-Null
    Set-ItemProperty ($registry + '\Gpu') 'DirectXUserGlobalSettings' 'Other=7;SwapEffectUpgradeEnable=0;' -Type String
    & ([scriptblock]::Create($hardware)) -Feature WindowedGaming -Mode On | Out-Null
    $current = (Get-ItemProperty ($registry + '\Gpu')).DirectXUserGlobalSettings
    Assert ($current -match 'Other=7;' -and $current -match 'SwapEffectUpgradeEnable=1;') 'Windowed setting preserves other graphics tokens'
    Set-ItemProperty ($registry + '\Gpu') 'DirectXUserGlobalSettings' ($current + 'Later=9;') -Type String
    & ([scriptblock]::Create($hardware)) -Feature WindowedGaming -Mode Off | Out-Null
    $current = (Get-ItemProperty ($registry + '\Gpu')).DirectXUserGlobalSettings
    Assert ($current -match 'Later=9;' -and $current -match 'SwapEffectUpgradeEnable=0;') 'Windowed restore preserves subsequent unrelated changes'
    Import-Functions (Join-Path $src 'GameProfiles.ps1') @('Set-ExeProfile','Save-ProfileBackup','Set-ExistingIniValues','Restore-Profile')
    $script:ProfileBackupFile = Join-Path $temp 'Game-test.json'
    $script:ProfileBackup = [pscustomobject]@{Exes=@();Config=@()}
    $applied = New-Object System.Collections.Generic.List[string]
    $Mode = 'On'
    $exe = Join-Path $temp 'fixture.exe'
    [IO.File]::WriteAllText($exe,'')
    Set-ItemProperty ($registry + '\Gpu') $exe 'Other=4;GpuPreference=1;' -Type String
    Set-ExeProfile $exe
    Set-ExeProfile $exe
    Assert ($script:ProfileBackup.Exes.Count -eq 1) 'Reapplying profile does not overwrite original backup'
    $current = (Get-ItemProperty ($registry + '\Gpu') -Name $exe).$exe
    Assert ($current -match 'Other=4;' -and $current -match 'GpuPreference=2;') 'Game GPU preference preserves other tokens'
    Set-ItemProperty ($registry + '\Gpu') $exe ($current + 'Later=8;') -Type String
    $ini = Join-Path $temp 'GameSettings.ini'
    $original = "[OTHER]`r`nVSync=7`r`n[DISPLAY]`r`nVSync=1`r`nWindowMode=2`r`n"
    [IO.File]::WriteAllText($ini,$original)
    Set-ExistingIniValues $ini 'DISPLAY' ([ordered]@{VSync='0';Missing='9'}) | Out-Null
    $current = [IO.File]::ReadAllText($ini)
    Assert ($current -match 'VSync=7' -and $current -match 'VSync=0' -and $current -match 'WindowMode=2' -and $current -notmatch 'Missing=') 'INI edits are section-aware and never invent missing keys'
    Assert (([regex]::Matches($current,"`r`n")).Count -eq 5) 'INI newline structure is preserved'
    $Mode = 'Off'
    Remove-Item $ini
    Assert (-not (Restore-Profile)) 'Missing config is reported as partial restore'
    Assert (Test-Path $script:ProfileBackupFile) 'Partial restore retains pending backup'
    [IO.File]::WriteAllText($ini,"[DISPLAY]`r`nVSync=0`r`nLater=6`r`n")
    Assert (Restore-Profile) 'Pending config restores when it becomes available'
    Assert (([IO.File]::ReadAllText($ini)) -match 'VSync=1' -and ([IO.File]::ReadAllText($ini)) -match 'Later=6') 'Config restore retains later unrelated settings'
    $current = (Get-ItemProperty ($registry + '\Gpu') -Name $exe).$exe
    Assert ($current -match 'GpuPreference=1;' -and $current -match 'Later=8;') 'Game preference restores its original token without losing later changes'
    Import-Functions (Join-Path $src 'PersonalWallpaper.ps1') @('Read-Layout')
    $layoutFile = Join-Path $temp 'WallpaperLayout.json'
    foreach ($json in '[]','null','[null,{}]') {
        [IO.File]::WriteAllText($layoutFile,$json)
        Assert (@(Read-Layout).Count -eq 0) "Empty Lively layout emits no active wallpaper: $json"
    }
    [IO.File]::WriteAllText($layoutFile,'[{"LivelyInfoPath":"personal","LivelyScreen":{"Index":1}},null,{"LivelyInfoPath":"other","LivelyScreen":{"Index":2}}]')
    $entries = @(Read-Layout)
    Assert ($entries.Count -eq 2 -and $entries[0].LivelyScreen.Index -eq 1 -and $entries[1].LivelyInfoPath -eq 'other') 'Lively layout preserves valid wallpapers and monitor indices'
    $launch = Get-Content -LiteralPath (Join-Path $src 'LaunchOptions.json') -Raw | ConvertFrom-Json
    Assert (-not $launch.Siege.Options -and -not $launch.Fortnite.Options) 'Public launch flags are empty by default'
    Import-Functions (Join-Path $src 'Debloat.ps1') @('Say','Get-ServiceStartupType','Read-ServiceState','Save-ServiceState','Test-ProtectedService')
    $script:logDir = $temp
    $script:serviceStateFile = Join-Path $temp 'service-state.json'
    $script:messages = New-Object System.Collections.Generic.List[string]
    $script:protectedServices = @('RpcSs','EventLog')
    Assert ((Get-ServiceStartupType -Start 2 -Delayed 0) -eq 'Automatic') 'Service snapshot maps Automatic'
    Assert ((Get-ServiceStartupType -Start 2 -Delayed 1) -eq 'AutomaticDelayedStart') 'Service snapshot maps delayed Automatic'
    Assert ((Get-ServiceStartupType -Start 3) -eq 'Manual') 'Service snapshot maps Manual'
    Assert ((Get-ServiceStartupType -Start 4) -eq 'Disabled') 'Service snapshot maps Disabled'
    Assert (-not (Get-ServiceStartupType -Start 0)) 'Service snapshot leaves unknown Start values alone'
    Assert (Test-ProtectedService 'RpcSs' -and -not (Test-ProtectedService 'wuauserv')) 'Critical service exclusions protect RPC but allow Insane update service'
    Save-ServiceState 'EventLog'
    Assert (Test-Path -LiteralPath $script:serviceStateFile) 'Service startup type is snapshotted before the first change'
    $snap = Get-Content -LiteralPath $script:serviceStateFile -Raw | ConvertFrom-Json
    Assert ($null -ne $snap.EventLog -and $snap.EventLog.Start -in 2,3,4) 'Service snapshot records the current Start value'
    Remove-Item -LiteralPath $script:serviceStateFile -Force
    Import-Functions (Join-Path $src 'Debloat.ps1') @('Say','Read-UserServiceState','Save-UserServiceState')
    $script:userServiceStateFile = Join-Path $temp 'user-service-state.json'
    Save-UserServiceState 'CDPUserSvc' 2
    Save-UserServiceState 'CDPUserSvc' 4
    $userSnap = Get-Content -LiteralPath $script:userServiceStateFile -Raw | ConvertFrom-Json
    Assert ($userSnap.CDPUserSvc.Start -eq 2 -and @($userSnap.PSObject.Properties).Count -eq 1) 'Per-user service snapshot records the first template Start only'
    Remove-Item -LiteralPath $script:userServiceStateFile -Force
    Import-Functions (Join-Path $src 'Debloat.ps1') @('Say','Read-KernelState','Save-KernelState')
    $script:kernelStateFile = Join-Path $temp 'kernel-state.json'
    $script:svcHostValue = 'SvcHostSplitThresholdInKB'
    Save-KernelState -Present $true -Value 3670016
    Save-KernelState -Present $false -Value 0
    $kernelSnap = Get-Content -LiteralPath $script:kernelStateFile -Raw | ConvertFrom-Json
    $hostSnap = $kernelSnap.SvcHostSplitThresholdInKB
    Assert ($hostSnap.Present -eq $true -and $hostSnap.Value -eq 3670016 -and @($kernelSnap.PSObject.Properties).Count -eq 1) 'Service-host grouping snapshot keeps the first value only'
    Remove-Item -LiteralPath $script:kernelStateFile -Force
    Import-Functions (Join-Path $src 'Debloat.ps1') @('Say','Read-FeatureState','Save-FeatureState')
    $script:featureStateFile = Join-Path $temp 'feature-state.json'
    Save-FeatureState 'SMB1Protocol' 'Enabled'
    Save-FeatureState 'SMB1Protocol' 'Disabled'
    $featureSnap = Get-Content -LiteralPath $script:featureStateFile -Raw | ConvertFrom-Json
    Assert ($featureSnap.SMB1Protocol -eq 'Enabled' -and @($featureSnap.PSObject.Properties).Count -eq 1) 'Optional-feature snapshot records the first state only'
    Remove-Item -LiteralPath $script:featureStateFile -Force
    $conf = [xml](Get-Content -LiteralPath (Join-Path (Split-Path $src -Parent) 'playbook.conf') -Raw)
    $appPage = @($conf.SelectNodes("//CheckboxPage[Options/CheckboxOption/Name='debloat-insane']"))
    Assert ($appPage.Count -eq 1 -and $appPage[0].SelectSingleNode('Options/CheckboxOption').IsChecked -eq 'false') 'Insane app tier is a separate unchecked warning page'
    $svcPage = @($conf.SelectNodes("//CheckboxPage[Options/CheckboxOption/Name='svc-insane']"))
    Assert ($svcPage.Count -eq 1 -and $svcPage[0].SelectSingleNode('Options/CheckboxOption').IsChecked -eq 'false') 'Insane service tier is a separate unchecked warning page'
    $debloatText = Get-Content -LiteralPath (Join-Path $src 'Debloat.ps1') -Raw
    Assert ($debloatText -match "'Microsoft.WindowsCalculator'" -and $debloatText -match "'wuauserv'" -and $debloatText -match 'service-state.json') 'Insane app and service lists plus snapshot file are present'
    Assert ($debloatText -match 'user-service-state.json' -and $debloatText -match 'kernel-state.json' -and $debloatText -match 'SvcHostSplitThresholdInKB') 'Insane process diet snapshots per-user templates and service-host grouping'
    foreach ($name in 'CDPUserSvc', 'WpnUserService', 'OneSyncSvc', 'PenService', 'NcbService', 'SSDPSRV', 'SstpSvc', 'UsoSvc', 'InventorySvc', 'w32time', 'wscsvc', 'WinHttpAutoProxySvc', 'iphlpsvc', 'LanmanServer') {
        Assert ($debloatText -match [regex]::Escape("'$name'")) "Insane process diet covers $name"
    }
    Assert ($debloatText -match 'feature-state.json' -and $debloatText -match 'Disable-WindowsOptionalFeature' -and $debloatText -match "'SMB1Protocol'" -and $debloatText -match "'Microsoft-RemoteDesktopConnection'") 'Insane optional-feature strip and snapshot are present'
    Assert ($debloatText -match 'Remove-AstraPackageData' -and $debloatText -match 'Remove-AstraAppRegistryTrace' -and $debloatText -match 'ProgramData\\Packages' -and $debloatText -match 'AppModel\\SystemAppData') 'Debloat removes package data folders and per-user AppModel registry traces'
    Assert ($debloatText -match 'ProgramData\\Microsoft\\OneDrive' -and $debloatText -match 'personal files') 'OneDrive cleanup removes app data without touching synced files'
    foreach ($name in 'Microsoft.Microsoft3DViewer', 'Microsoft.Print3D', 'MicrosoftCorporationII.MicrosoftFamily', 'Microsoft.Windows.Copilot', 'Microsoft.Windows.Ai.Copilot.Provider') {
        Assert ($debloatText -match [regex]::Escape("'$name'")) "Debloat covers $name"
    }
    Assert ($appPage[0].Description -match 'package-data') 'Insane app page documents trace cleanup'
    Import-Functions (Join-Path $src 'Debloat.ps1') @('Get-AstraPackageDataDirs', 'Test-Protected')
    $script:protected = @()
    $traceFamily = 'Astra.TraceTest_8wekyb3d8bbwe'
    $traceDir = Join-Path $env:LOCALAPPDATA ('Packages\' + $traceFamily)
    New-Item -ItemType Directory -Path $traceDir -Force | Out-Null
    $traceHits = @(Get-AstraPackageDataDirs -Pattern 'Astra.TraceTest')
    Assert ($traceHits.Count -eq 1 -and $traceHits[0].Name -eq $traceFamily) 'Package-data trace lookup matches the family folder'
    Import-Functions (Join-Path $src 'Debloat.ps1') @('Test-AstraPackageRemaining', 'Remove-AstraPackageData', 'Add-Record')
    $script:logFile = Join-Path $temp 'trace-removed.json'
    $script:Level = 'Status'
    $script:isAdmin = $false
    $deleted = Remove-AstraPackageData -Pattern 'Astra.TraceTest'
    Assert ($deleted -eq 1 -and -not (Test-Path -LiteralPath $traceDir)) 'Package-data cleanup deletes an orphaned family folder'
    Assert ($debloatText -match 'Remove-AstraServiceTrace' -and $debloatText -match 'Remove-AstraStaleUserServiceInstances' -and $debloatText -match 'service-data' -and $debloatText -match 'user-service-stale') 'Service tiers remove cache folders and stale per-user keys and record them'
    Assert ($debloatText -match 'SoftwareDistribution\\Download' -and $debloatText -match 'ProgramData\\Microsoft\\Diagnosis' -and $debloatText -match 'ProgramData\\Microsoft\\Search\\Data') 'Service trace table lists the cache and report paths'
    Assert ($svcPage[0].Description -match 'cache and report folders') 'Insane service page documents trace cleanup'
    Import-Functions (Join-Path $src 'Debloat.ps1') @('Remove-AstraServiceTrace', 'Add-Record')
    $svcTraceDir = Join-Path $temp 'service-cache'
    New-Item -ItemType Directory -Path $svcTraceDir -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $svcTraceDir 'queue.dat'),'x')
    $svcDeleted = Remove-AstraServiceTrace -Name 'AstraTraceSvc' -Paths @($svcTraceDir)
    Assert ($svcDeleted -eq 1 -and -not (Test-Path -LiteralPath $svcTraceDir)) 'Service cache cleanup deletes an orphaned cache folder'
    $svcKeepDir = Join-Path $temp 'service-cache-live'
    New-Item -ItemType Directory -Path $svcKeepDir -Force | Out-Null
    $svcSkipped = Remove-AstraServiceTrace -Name 'EventLog' -Paths @($svcKeepDir)
    Assert ($svcSkipped -eq 0 -and (Test-Path -LiteralPath $svcKeepDir)) 'Service cache cleanup never deletes data while the service is enabled'
    Remove-Item -LiteralPath $svcKeepDir -Recurse -Force
    Import-Functions (Join-Path $src 'Debloat.ps1') @('Get-AstraStaleUserServiceInstances', 'Remove-AstraStaleUserServiceInstances', 'Add-Record')
    $script:userServiceTemplates = @('CDPUserSvc')
    $staleRoot = $registry + '\Services'
    New-Item -Path ($staleRoot + '\CDPUserSvc_deadbeef') -Force | Out-Null
    New-Item -Path ($staleRoot + '\CDPUserSvc_cafe01') -Force | Out-Null
    New-Item -Path ($staleRoot + '\Other_1234') -Force | Out-Null
    $stale = @(Get-AstraStaleUserServiceInstances -RootKey $staleRoot)
    Assert ($stale.Count -eq 2 -and ($stale.Name -contains 'CDPUserSvc_deadbeef') -and -not ($stale.Name -contains 'Other_1234')) 'Stale user-service lookup matches only disabled template instance keys'
    $staleRemoved = Remove-AstraStaleUserServiceInstances -RootKey $staleRoot
    Assert ($staleRemoved -eq 2 -and -not (Test-Path -LiteralPath ($staleRoot + '\CDPUserSvc_deadbeef')) -and (Test-Path -LiteralPath ($staleRoot + '\Other_1234'))) 'Stale user-service cleanup deletes only template instance keys'
    $togglePage = @($conf.SelectNodes("//CheckboxPage[Options/CheckboxOption/Name='tweak-bg-apps']"))
    $toggleOptions = @($togglePage[0].SelectNodes('Options/CheckboxOption'))
    Assert ($togglePage.Count -eq 1 -and $toggleOptions.Count -eq 4 -and @($toggleOptions | Where-Object IsChecked -eq 'true').Count -eq 0) 'Optional toggles page exists with four unchecked options'
    $animPage = @($conf.SelectNodes("//CheckboxPage[Options/CheckboxOption/Name='qol-animations-off']"))
    Assert ($animPage.Count -eq 1 -and $animPage[0].SelectSingleNode('Options/CheckboxOption').IsChecked -eq 'false') 'Animation toggle is a separate unchecked page'
    $latencyPage = @($conf.SelectNodes("//CheckboxPage[Options/CheckboxOption/Name='pcie-aspm']"))
    $latencyOptions = @($latencyPage[0].SelectNodes('Options/CheckboxOption'))
    Assert ($latencyPage.Count -eq 1 -and $latencyOptions.Count -eq 3 -and @($latencyOptions | Where-Object IsChecked -eq 'true').Count -eq 0) 'Gaming latency page exists with three unchecked options'
    $shellPage = @($conf.SelectNodes("//CheckboxPage[Options/CheckboxOption/Name='tweak-toasts']"))
    $shellOptions = @($shellPage[0].SelectNodes('Options/CheckboxOption'))
    Assert ($shellPage.Count -eq 1 -and $shellOptions.Count -eq 3 -and @($shellOptions | Where-Object IsChecked -eq 'true').Count -eq 0) 'Gaming shell page exists with three unchecked options'
    $tidyPage = @($conf.SelectNodes("//CheckboxPage[Options/CheckboxOption/Name='tweak-ink-button']"))
    $tidyOptions = @($tidyPage[0].SelectNodes('Options/CheckboxOption'))
    Assert ($tidyPage.Count -eq 1 -and $tidyOptions.Count -eq 3 -and @($tidyOptions | Where-Object IsChecked -eq 'true').Count -eq 0) 'Gaming tidy-up page exists with three unchecked options'
    $nvidiaPage = @($conf.SelectNodes("//CheckboxPage[Options/CheckboxOption/Name='install-nvidia-tools']"))
    Assert ($nvidiaPage.Count -eq 1 -and $nvidiaPage[0].SelectSingleNode('Options/CheckboxOption').IsChecked -eq 'false') 'NVIDIA tools page is a separate unchecked option'
    $nvidiaText = Get-Content -LiteralPath (Join-Path $src 'NvidiaTools.ps1') -Raw
    Assert ($nvidiaText -match 'nvidia\.com/en-us/software/nvidia-app' -and $nvidiaText -match 'nvidia\.com/en-us/drivers' -and $nvidiaText -match 'Shortcuts') 'NVIDIA tools script links the official pages and creates shortcuts'
    Assert ($nvidiaText -match '9NF8H0H7WMLT' -and $nvidiaText -match 'ms-windows-store://pdp/\?ProductId=9nf8h0h7wmlt' -and $nvidiaText -match 'winget install') 'NVIDIA diagnostic uses the documented Store id, PDP page and winget command'
    Assert ($nvidiaText -match 'nvcplui\.exe' -and $nvidiaText -match 'NVIDIAControlPanel' -and $nvidiaText -match 'wuauserv' -and $nvidiaText -match "'BITS'") 'NVIDIA diagnostic checks the package, the panel executable and the update services'
    Assert ($nvidiaText -match 'Debloat\.ps1 -Restore' -and $nvidiaText -match 'wsreset -i') 'NVIDIA diagnostic names the exact service and Store recovery steps'
    $extraTask = Get-Content -LiteralPath (Join-Path (Split-Path $src -Parent) 'Configuration\Tasks\extra-privacy.yml') -Raw
    foreach ($option in 'extra-spotlight-off', 'extra-scoobe-off', 'extra-start-recent-off') {
        Assert ($extraTask -match [regex]::Escape("option: $option")) "Extra privacy task gates $option"
    }
    Assert ($extraTask -match '-Spotlight On' -and $extraTask -match '-Scoobe On' -and $extraTask -match '-StartRecentApps On') 'Extra privacy task calls the QoL switches'
    $nvidiaTask = Get-Content -LiteralPath (Join-Path (Split-Path $src -Parent) 'Configuration\Tasks\nvidia.yml') -Raw
    Assert ($nvidiaTask -match 'option: install-nvidia-tools' -and $nvidiaTask -match 'NvidiaTools\.ps1') 'NVIDIA task file gates the shortcut option'
    $mainText = Get-Content -LiteralPath (Join-Path (Split-Path $src -Parent) 'Configuration\main.yml') -Raw
    Assert ($mainText.Contains('Tasks\nvidia.yml') -and $mainText -match 'option: install-nvidia-tools') 'NVIDIA task is included in the main flow'
    Assert ($mainText.Contains('Tasks\extra-privacy.yml')) 'Extra privacy task is included in the main flow'
    $extraPage = @($conf.SelectNodes("//CheckboxPage[Options/CheckboxOption/Name='extra-spotlight-off']"))
    $extraOptions = @($extraPage[0].SelectNodes('Options/CheckboxOption'))
    Assert ($extraPage.Count -eq 1 -and $extraOptions.Count -eq 4 -and @($extraOptions | Where-Object IsChecked -eq 'true').Count -eq 0) 'Extra privacy page exists with four unchecked options'
    $hardenPage = @($conf.SelectNodes("//CheckboxPage[Options/CheckboxOption/Name='harden-smartscreen']"))
    $hardenOptions = @($hardenPage[0].SelectNodes('Options/CheckboxOption'))
    Assert ($hardenPage.Count -eq 1 -and $hardenOptions.Count -eq 3 -and @($hardenOptions | Where-Object IsChecked -eq 'true').Count -eq 3) 'Security hardening page exists with three checked options'
    $offPage = @($conf.SelectNodes("//CheckboxPage[Options/CheckboxOption/Name='sec-smartscreen-off']"))
    $offOptions = @($offPage[0].SelectNodes('Options/CheckboxOption'))
    Assert ($offPage.Count -eq 1 -and $offOptions.Count -eq 2 -and @($offOptions | Where-Object IsChecked -eq 'true').Count -eq 0) 'Disable security page exists with two unchecked options'
    $defenderPage = @($conf.SelectNodes("//RadioPage[Options/RadioOption/Name='disable-defender']"))
    $vbsPage = @($conf.SelectNodes("//RadioPage[Options/RadioOption/Name='disable-vbs']"))
    Assert ($defenderPage[0].DefaultOption -eq 'disable-defender') 'Defender defaults to disabled'
    Assert ($vbsPage[0].DefaultOption -eq 'disable-vbs') 'VBS defaults to disabled'
    $hardenTask = Get-Content -LiteralPath (Join-Path (Split-Path $src -Parent) 'Configuration\Tasks\harden.yml') -Raw
    foreach ($option in 'harden-smartscreen', 'harden-llmnr', 'harden-autorun') {
        Assert ($hardenTask -match [regex]::Escape("option: $option")) "Hardening task gates $option"
    }
    Assert ($hardenTask -match 'Security\.ps1') 'Hardening task calls Security.ps1'
    $securityTask = Get-Content -LiteralPath (Join-Path (Split-Path $src -Parent) 'Configuration\Tasks\security.yml') -Raw
    Assert ($securityTask -match 'option: sec-smartscreen-off' -and $securityTask -match 'option: sec-security-notifications-off' -and $securityTask -match 'Security\.ps1') 'Security task gates the disable-security options'
    $qolTaskText = Get-Content -LiteralPath (Join-Path (Split-Path $src -Parent) 'Configuration\Tasks\qol.yml') -Raw
    Assert ($qolTaskText -match 'option: tweak-gamebar-tips' -and $qolTaskText -match '-GameBarTips On') 'QoL task gates the Game Bar tips option'
    Assert ($extraTask -match 'option: extra-cloud-clipboard-off' -and $extraTask -match '-CloudClipboard On') 'Extra privacy task gates the cloud clipboard option'
    Assert ($mainText.Contains('Tasks\harden.yml')) 'Hardening task is included in the main flow'
    $restoreText = Get-Content -LiteralPath (Join-Path $src 'Restore.ps1') -Raw
    Assert ($restoreText -match '\[switch\]\$Security' -and $restoreText -match 'Security\.ps1' -and $restoreText -match '-AllOff') 'Restore.ps1 exposes a Security section'
    $securityText = Get-Content -LiteralPath (Join-Path $src 'Security.ps1') -Raw
    Assert ($securityText -match "'Warn'" -and $securityText -match 'EnableMulticast' -and $securityText -match 'NoDriveTypeAutoRun' -and $securityText -match 'AstraMax\\Security') 'Security helper writes the documented hardening values and snapshots them'
    Assert ($debloatText -match "'\*NVIDIA\*'" -and $debloatText -match 'NVDisplay\.ContainerLocalSystem') 'Debloat protects NVIDIA packages and services'
    $extrasTask = Get-Content -LiteralPath (Join-Path (Split-Path $src -Parent) 'Configuration\Tasks\astra-extras.yml') -Raw
    foreach ($option in 'extra-game-dvr-off', 'extra-fso-off', 'extra-mpo-off', 'extra-qos-off', 'extra-search-local', 'extra-cloud-search-off', 'extra-recall-off', 'extra-widgets-off') {
        Assert ($extrasTask -match [regex]::Escape("option: $option")) "Astra extras task gates $option"
    }
    Assert ($extrasTask -match '-GameDvr On' -and $extrasTask -match '-FullscreenOpt On' -and $extrasTask -match '-Mpo On' -and $extrasTask -match '-QosBandwidth On' -and $extrasTask -match '-SearchLocal On' -and $extrasTask -match '-CloudSearch On' -and $extrasTask -match '-Recall On' -and $extrasTask -match '-Widgets On') 'Astra extras task calls every QoL switch'
    $extrasPage = @($conf.SelectNodes("//CheckboxPage[Options/CheckboxOption/Name='extra-game-dvr-off']"))
    $extrasOptions = @($extrasPage[0].SelectNodes('Options/CheckboxOption'))
    Assert ($extrasPage.Count -eq 1 -and $extrasOptions.Count -eq 4 -and @($extrasOptions | Where-Object IsChecked -eq 'true').Count -eq 0) 'Capture and display extras page exists with four unchecked options'
    $searchPage = @($conf.SelectNodes("//CheckboxPage[Options/CheckboxOption/Name='extra-search-local']"))
    $searchOptions = @($searchPage[0].SelectNodes('Options/CheckboxOption'))
    Assert ($searchPage.Count -eq 1 -and $searchOptions.Count -eq 4 -and @($searchOptions | Where-Object IsChecked -eq 'true').Count -eq 0) 'Search extras page exists with four unchecked options'
    Assert ($extrasTask -match 'option: extra-cloud-search-off' -and $extrasTask -match 'option: extra-recall-off' -and $extrasTask -match 'option: extra-widgets-off') 'Search extras page options are gated'
    $startAllBackPage = @($conf.SelectNodes("//CheckboxPage[Options/CheckboxOption/Name='install-startallback']"))
    Assert ($startAllBackPage.Count -eq 1 -and $startAllBackPage[0].SelectSingleNode('Options/CheckboxOption').IsChecked -eq 'false') 'StartAllBack is a separate unchecked option'
    $startAllBackTask = Get-Content -LiteralPath (Join-Path (Split-Path $src -Parent) 'Configuration\Tasks\startallback.yml') -Raw
    Assert ($startAllBackTask -match 'option: install-startallback' -and $startAllBackTask -match 'StartAllBack\.ps1') 'StartAllBack task gates the install option'
    $startAllBackText = Get-Content -LiteralPath (Join-Path $src 'StartAllBack.ps1') -Raw
    Assert ($startAllBackText -match 'startallback\.com' -and $startAllBackText -match 'StartAllBack_setup\.exe' -and $startAllBackText -match 'StartAllBack\.txt') 'StartAllBack helper stages the setup and writes the notes'
    Assert ($startAllBackText -match 'Start-Process' -and $startAllBackText -match "'/install'" -and $startAllBackText -match "'/silent'" -and $startAllBackText -match 'WaitForExit') 'StartAllBack helper installs the bundled setup with a timeout'
    Assert ($startAllBackText -match 'InternetShortcut' -and $startAllBackText -match 'Install StartAllBack\.url') 'StartAllBack falls back to a working .url shortcut when the setup is absent'
    $astrAppTask = Get-Content -LiteralPath (Join-Path (Split-Path $src -Parent) 'Configuration\Tasks\astra-app.yml') -Raw
    Assert ($astrAppTask -match 'StartAllBack\.ps1') 'Astra app deploy copies the StartAllBack helper'
    $buildText = Get-Content -LiteralPath (Join-Path (Split-Path $src -Parent) '..\tools\build.ps1') -Raw
    Assert ($buildText -match 'astra-extras\.yml' -and $buildText -match 'startallback\.yml' -and $buildText -match 'StartAllBack\.ps1') 'Build requires the new tasks and helper'
    Assert ($mainText.Contains('Tasks\astra-extras.yml') -and $mainText.Contains('Tasks\startallback.yml')) 'New tasks are included in the main flow'
    Assert ($conf.Playbook.Version -eq '1.5.2') 'Playbook version is 1.5.2'
    Assert ($conf.Playbook.ProgressText -match 'working through the stack') 'Progress screen uses the custom Astra status line'
    $builds = @($conf.Playbook.SupportedBuilds.string)
    Assert ($builds -contains '26300') 'Windows 11 26H2 build 26300 is supported'
    $qolText = Get-Content -LiteralPath (Join-Path (Split-Path $src -Parent) 'Configuration\Tasks\qol.yml') -Raw
    foreach ($option in 'tweak-bg-apps', 'tweak-priority-boost', 'tweak-sync-ads', 'tweak-aero-shake', 'qol-animations-off', 'tweak-toasts', 'tweak-menu-delay', 'tweak-a11y-keys', 'tweak-ink-button', 'tweak-edge-gaming') {
        Assert ($qolText -match [regex]::Escape("option: $option")) "Task file gates $option"
    }
    $hardwareText = Get-Content -LiteralPath (Join-Path (Split-Path $src -Parent) 'Configuration\Tasks\hardware.yml') -Raw
    foreach ($option in 'pcie-aspm', 'disk-idle', 'dynamic-tick') {
        Assert ($hardwareText -match [regex]::Escape("option: $option")) "Hardware task file gates $option"
    }
    $frameworksText = Get-Content -LiteralPath (Join-Path (Split-Path $src -Parent) 'Configuration\Tasks\frameworks.yml') -Raw
    foreach ($file in 'Redist\directx_Jun2010_redist.exe', 'Redist\VisualCppRedist_AIO_x86_x64.exe', 'Redist\windowsdesktop-runtime-8.0.34-win-x64.exe') {
        Assert ($frameworksText.Contains($file)) "Frameworks task uses the bundled $file"
    }
    foreach ($option in 'install-directx', 'install-vcredist', 'install-dotnet8') {
        $node = @($conf.SelectNodes("//CheckboxOption[Name='$option']"))
        Assert ($node.Count -eq 1 -and $node[0].IsChecked -eq 'true') "Bundled runtime $option is selected by default"
    }
    'Safe option tests passed; no live game files or power settings changed'
}
finally {
    $env:LOCALAPPDATA = $originalLocal
    Remove-Item $registry -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item Function:global:powercfg -ErrorAction SilentlyContinue
    Remove-Item Function:global:bcdedit -ErrorAction SilentlyContinue
}

