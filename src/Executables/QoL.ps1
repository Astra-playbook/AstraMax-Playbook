#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Keep', 'On', 'Off')] [string]$ClassicMenu = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$LongPaths = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$ClockSeconds = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$OpenThisPC = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$DarkMode = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$StartRecommendations = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$ClipboardHistory = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$TaskbarLeft = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$EndTask = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$BackgroundApps = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$PriorityBoost = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$SyncAds = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$AeroShake = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$Animations = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$Notifications = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$MenuDelay = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$A11yKeys = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$InkWorkspace = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$EdgeGaming = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$Spotlight = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$Scoobe = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$StartRecentApps = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$SecurityNotifications = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$CloudClipboard = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$GameBarTips = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$OnlineSpeech = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$InkTyping = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$LanguageList = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$TailoredExperiences = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$HiddenFiles = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$FullPath = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$TaskbarSmallIcons = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$HoverDelay = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$KeyboardRepeat = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$AudioDucking = 'Keep',
    [ValidateSet('Keep', 'On', 'Off')] [string]$RestartApps = 'Keep',
    [switch]$AllOff
)

$ErrorActionPreference = 'SilentlyContinue'
if ($AllOff) {
    $ClassicMenu = 'Off'; $LongPaths = 'Off'; $ClockSeconds = 'Off'; $OpenThisPC = 'Off'
    $DarkMode = 'Off'; $StartRecommendations = 'Off'; $ClipboardHistory = 'Off'; $TaskbarLeft = 'Off'; $EndTask = 'Off'
    $BackgroundApps = 'Off'; $PriorityBoost = 'Off'; $SyncAds = 'Off'; $AeroShake = 'Off'; $Animations = 'Off'
    $Notifications = 'Off'; $MenuDelay = 'Off'; $A11yKeys = 'Off'; $InkWorkspace = 'Off'; $EdgeGaming = 'Off'
    $Spotlight = 'Off'; $Scoobe = 'Off'; $StartRecentApps = 'Off'
    $SecurityNotifications = 'Off'; $CloudClipboard = 'Off'; $GameBarTips = 'Off'
    $OnlineSpeech = 'Off'; $InkTyping = 'Off'; $LanguageList = 'Off'; $TailoredExperiences = 'Off'
    $HiddenFiles = 'Off'; $FullPath = 'Off'; $TaskbarSmallIcons = 'Off'; $HoverDelay = 'Off'
    $KeyboardRepeat = 'Off'; $AudioDucking = 'Off'; $RestartApps = 'Off'
}

$log = New-Object System.Collections.Generic.List[string]
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

function Set-Dword {
    param([string]$Path, [string]$Name, [int]$Value)
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Type DWord -Value $Value -Force -ErrorAction Stop
}

function Set-Text {
    param([string]$Path, [string]$Name, [string]$Value)
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force -ErrorAction Stop
}

$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$personalize = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'

# --- classic right-click menu (Windows 11) ---------------------------------------
if ($ClassicMenu -ne 'Keep') {
    $cls = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'
    if ($ClassicMenu -eq 'On') {
        New-Item -Path (Join-Path $cls 'InprocServer32') -Force | Out-Null
        Set-ItemProperty -Path (Join-Path $cls 'InprocServer32') -Name '(Default)' -Value '' -Force
        $log.Add('classic menu: Windows 10 right-click menu (restart Explorer or sign out to see it)')
    }
    else {
        Remove-Item -Path $cls -Recurse -Force
        $log.Add('classic menu: Windows 11 right-click menu restored')
    }
}

# --- long paths ------------------------------------------------------------------
if ($LongPaths -ne 'Keep') {
    if (-not $isAdmin) { $log.Add('long paths: needs an elevated PowerShell') }
    else {
        Set-Dword 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled' $(if ($LongPaths -eq 'On') { 1 } else { 0 })
        $log.Add($(if ($LongPaths -eq 'On') { 'long paths: enabled (paths over 260 characters)' } else { 'long paths: Windows default' }))
    }
}

# --- clock seconds ---------------------------------------------------------------
if ($ClockSeconds -ne 'Keep') {
    Set-Dword $adv 'ShowSecondsInSystemClock' $(if ($ClockSeconds -eq 'On') { 1 } else { 0 })
    $log.Add($(if ($ClockSeconds -eq 'On') { 'clock: seconds shown in the taskbar' } else { 'clock: hours and minutes only' }))
}

# --- Explorer opens This PC ------------------------------------------------------
if ($OpenThisPC -ne 'Keep') {
    Set-Dword $adv 'LaunchTo' $(if ($OpenThisPC -eq 'On') { 1 } else { 2 })
    $log.Add($(if ($OpenThisPC -eq 'On') { 'explorer: opens This PC' } else { 'explorer: opens Home' }))
}

# --- dark mode -------------------------------------------------------------------
if ($DarkMode -ne 'Keep') {
    $light = if ($DarkMode -eq 'On') { 0 } else { 1 }
    Set-Dword $personalize 'AppsUseLightTheme' $light
    Set-Dword $personalize 'SystemUsesLightTheme' $light
    if (-not ('AstraThemeRefresh' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AstraThemeRefresh {
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern IntPtr SendMessageTimeout(IntPtr window, uint message, UIntPtr wParam, string lParam, uint flags, uint timeout, out UIntPtr result);
}
'@
    }
    $result = [UIntPtr]::Zero
    [void][AstraThemeRefresh]::SendMessageTimeout([IntPtr]0xffff, 0x001a, [UIntPtr]::Zero, 'ImmersiveColorSet', 2, 1000, [ref]$result)
    $log.Add($(if ($DarkMode -eq 'On') { 'theme: dark for Windows and apps (third-party apps may need restarting)' } else { 'theme: light' }))
}

# --- Start recommendations -------------------------------------------------------
if ($StartRecommendations -ne 'Keep') {
    Set-Dword $adv 'Start_IrisRecommendations' $(if ($StartRecommendations -eq 'On') { 0 } else { 1 })
    $log.Add($(if ($StartRecommendations -eq 'On') { 'start: recommendations hidden' } else { 'start: recommendations shown' }))
}

# --- clipboard history -----------------------------------------------------------
if ($ClipboardHistory -ne 'Keep') {
    Set-Dword 'HKCU:\Software\Microsoft\Clipboard' 'EnableClipboardHistory' $(if ($ClipboardHistory -eq 'On') { 1 } else { 0 })
    $log.Add($(if ($ClipboardHistory -eq 'On') { 'clipboard: history on (Win+V)' } else { 'clipboard: history off' }))
}

# --- taskbar alignment -----------------------------------------------------------
if ($TaskbarLeft -ne 'Keep') {
    Set-Dword $adv 'TaskbarAl' $(if ($TaskbarLeft -eq 'On') { 0 } else { 1 })
    $log.Add($(if ($TaskbarLeft -eq 'On') { 'taskbar: icons aligned left' } else { 'taskbar: icons centered' }))
}

if ($EndTask -ne 'Keep') {
    $build = [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber
    if ($build -lt 22631) { $log.Add('end task: Windows 11 23H2 or newer required') }
    else {
        Set-Dword (Join-Path $adv 'TaskbarDeveloperSettings') 'TaskbarEndTask' $(if ($EndTask -eq 'On') { 1 } else { 0 })
        $log.Add('end task: ' + $EndTask + ' (right-click a running app on the taskbar; unsaved work can be lost)')
    }
}

# --- background apps -------------------------------------------------------------
if ($BackgroundApps -ne 'Keep') {
    $bg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'
    if ($BackgroundApps -eq 'On') {
        Set-Dword $bg 'GlobalUserDisabled' 1
        Set-Dword $bg 'BackgroundAppGlobalToggle' 0
        $log.Add('background apps: off for this user (sign out so every app honours it)')
    }
    else {
        Set-Dword $bg 'GlobalUserDisabled' 0
        Remove-ItemProperty -Path $bg -Name 'BackgroundAppGlobalToggle' -Force -ErrorAction SilentlyContinue
        $log.Add('background apps: Windows default (apps may run in the background)')
    }
}

# --- foreground scheduling priority ----------------------------------------------
if ($PriorityBoost -ne 'Keep') {
    if (-not $isAdmin) { $log.Add('foreground priority: needs an elevated PowerShell') }
    else {
        Set-Dword 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' $(if ($PriorityBoost -eq 'On') { 38 } else { 2 })
        $log.Add($(if ($PriorityBoost -eq 'On') { 'foreground priority: 38 (short fixed quantum, foreground boost)' } else { 'foreground priority: Windows default (2)' }))
    }
}

# --- Explorer sync provider notifications ----------------------------------------
if ($SyncAds -ne 'Keep') {
    if ($SyncAds -eq 'On') {
        Set-Dword $adv 'ShowSyncProviderNotifications' 0
        $log.Add('explorer: OneDrive sync provider notifications hidden')
    }
    else {
        Remove-ItemProperty -Path $adv -Name 'ShowSyncProviderNotifications' -Force -ErrorAction SilentlyContinue
        $log.Add('explorer: sync provider notifications at Windows default')
    }
}

# --- Aero Shake ------------------------------------------------------------------
if ($AeroShake -ne 'Keep') {
    if ($AeroShake -eq 'On') {
        Set-Dword $adv 'NoWindowMinimizingShortcuts' 1
        $log.Add('aero shake: off (shaking a window no longer minimizes the others)')
    }
    else {
        Remove-ItemProperty -Path $adv -Name 'NoWindowMinimizingShortcuts' -Force -ErrorAction SilentlyContinue
        $log.Add('aero shake: Windows default (on)')
    }
}

# --- OS animations ---------------------------------------------------------------
if ($Animations -ne 'Keep') {
    $metrics = 'HKCU:\Control Panel\Desktop\WindowMetrics'
    if ($Animations -eq 'On') {
        Set-ItemProperty -Path $metrics -Name 'MinAnimate' -Value '0' -Force
        Set-Dword $adv 'TaskbarAnimations' 0
        $log.Add('animations: window minimize/maximize and taskbar animations off (sign out or restart Explorer to finish)')
    }
    else {
        Set-ItemProperty -Path $metrics -Name 'MinAnimate' -Value '1' -Force
        Set-Dword $adv 'TaskbarAnimations' 1
        $log.Add('animations: Windows window and taskbar animations on')
    }
}

# --- notification pop-ups --------------------------------------------------------
if ($Notifications -ne 'Keep') {
    $push = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications'
    Set-Dword $push 'ToastEnabled' $(if ($Notifications -eq 'On') { 0 } else { 1 })
    $log.Add($(if ($Notifications -eq 'On') { 'notifications: toast pop-ups off (Focus Assist settings are unchanged)' } else { 'notifications: Windows default (toast pop-ups on)' }))
}

# --- menu show delay -------------------------------------------------------------
if ($MenuDelay -ne 'Keep') {
    $desktop = 'HKCU:\Control Panel\Desktop'
    Set-Text $desktop 'MenuShowDelay' $(if ($MenuDelay -eq 'On') { '0' } else { '400' })
    $log.Add($(if ($MenuDelay -eq 'On') { 'menus: instant (no 400 ms fly-out delay; sign out or restart Explorer to finish)' } else { 'menus: Windows default delay' }))
}

# --- accessibility shortcut keys -------------------------------------------------
if ($A11yKeys -ne 'Keep') {
    $sticky = 'HKCU:\Control Panel\Accessibility\StickyKeys'
    $filter = 'HKCU:\Control Panel\Accessibility\Keyboard Response'
    $toggle = 'HKCU:\Control Panel\Accessibility\ToggleKeys'
    $narrator = 'HKCU:\Software\Microsoft\Narrator\NoRoam'
    if ($A11yKeys -eq 'On') {
        Set-Text $sticky 'Flags' '506'
        Set-Text $filter 'Flags' '122'
        Set-Text $toggle 'Flags' '58'
        Set-Dword $narrator 'WinEnterLaunchEnabled' 0
        $log.Add('accessibility: Sticky/Filter/Toggle Keys and Narrator short-cuts off (re-enable in Settings > Accessibility)')
    }
    else {
        Set-Text $sticky 'Flags' '510'
        Set-Text $filter 'Flags' '126'
        Set-Text $toggle 'Flags' '62'
        Set-Dword $narrator 'WinEnterLaunchEnabled' 1
        $log.Add('accessibility: Windows default shortcut keys')
    }
}

# --- Windows Ink Workspace button ------------------------------------------------
if ($InkWorkspace -ne 'Keep') {
    Set-Dword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PenWorkspace' 'PenWorkspaceButtonDesiredVisibility' $(if ($InkWorkspace -eq 'On') { 0 } else { 1 })
    $log.Add($(if ($InkWorkspace -eq 'On') { 'ink: pen workspace button hidden (sign out to finish)' } else { 'ink: pen workspace button at Windows default' }))
}

# --- Edge gaming policies --------------------------------------------------------
if ($EdgeGaming -ne 'Keep') {
    $edge = 'HKCU:\Software\Policies\Microsoft\Edge'
    if ($EdgeGaming -eq 'On') {
        Set-Dword $edge 'HubsSidebarEnabled' 0
        Set-Dword $edge 'EdgeShoppingAssistantEnabled' 0
        Set-Dword $edge 'WebWidgetAllowed' 0
        Set-Dword $edge 'HideFirstRunExperience' 1
        $log.Add('edge: sidebar, shopping assistant, widgets and first-run experience off (restart Edge)')
    }
    else {
        foreach ($value in 'HubsSidebarEnabled', 'EdgeShoppingAssistantEnabled', 'WebWidgetAllowed', 'HideFirstRunExperience') {
            Remove-ItemProperty -Path $edge -Name $value -Force -ErrorAction SilentlyContinue
        }
        $log.Add('edge: Windows default policies')
    }
}

# --- lock screen Spotlight -------------------------------------------------------
if ($Spotlight -ne 'Keep') {
    $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    if ($Spotlight -eq 'On') {
        Set-Dword $cdm 'RotatingLockScreenEnabled' 0
        Set-Dword $cdm 'RotatingLockScreenOverlayEnabled' 0
        $log.Add('spotlight: rotating lock screen and its tips off')
    }
    else {
        foreach ($value in 'RotatingLockScreenEnabled', 'RotatingLockScreenOverlayEnabled') {
            Remove-ItemProperty -Path $cdm -Name $value -Force -ErrorAction SilentlyContinue
        }
        $log.Add('spotlight: Windows default lock screen (values removed)')
    }
}

# --- post-setup nags -------------------------------------------------------------
if ($Scoobe -ne 'Keep') {
    $upe = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement'
    if ($Scoobe -eq 'On') {
        Set-Dword $upe 'ScoobeSystemSettingEnabled' 0
        $log.Add('nags: post-update "finish setting up" prompts off')
    }
    else {
        Remove-ItemProperty -Path $upe -Name 'ScoobeSystemSettingEnabled' -Force -ErrorAction SilentlyContinue
        $log.Add('nags: Windows default setup prompts')
    }
}

# --- recently added apps list ----------------------------------------------------
if ($StartRecentApps -ne 'Keep') {
    if ($StartRecentApps -eq 'On') {
        Set-Dword $adv 'Start_TrackProgs' 0
        $log.Add('start: recently added apps list off (sign out to finish)')
    }
    else {
        Remove-ItemProperty -Path $adv -Name 'Start_TrackProgs' -Force -ErrorAction SilentlyContinue
        $log.Add('start: Windows default recently added apps list')
    }
}

# --- Security Center notifications ------------------------------------------------
if ($SecurityNotifications -ne 'Keep') {
    $toast = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance'
    Set-Dword $toast 'Enabled' $(if ($SecurityNotifications -eq 'On') { 0 } else { 1 })
    $log.Add($(if ($SecurityNotifications -eq 'On') { 'security: Defender/Security Center toast alerts off' } else { 'security: Windows default Security Center alerts' }))
}

# --- cloud clipboard sync ---------------------------------------------------------
if ($CloudClipboard -ne 'Keep') {
    $clip = 'HKCU:\Software\Microsoft\Clipboard'
    if ($CloudClipboard -eq 'On') {
        Set-Dword $clip 'CloudClipboardAutomaticUpload' 0
        $log.Add('clipboard: cloud sync off (local clipboard history still works)')
    }
    else {
        Remove-ItemProperty -Path $clip -Name 'CloudClipboardAutomaticUpload' -Force -ErrorAction SilentlyContinue
        $log.Add('clipboard: Windows default cloud sync')
    }
}

# --- Game Bar startup tips --------------------------------------------------------
if ($GameBarTips -ne 'Keep') {
    $bar = 'HKCU:\Software\Microsoft\GameBar'
    Set-Dword $bar 'ShowStartupPanel' $(if ($GameBarTips -eq 'On') { 0 } else { 1 })
    $log.Add($(if ($GameBarTips -eq 'On') { 'game bar: startup panel and tips off' } else { 'game bar: Windows default startup panel' }))
}

# --- online speech recognition ----------------------------------------------------
if ($OnlineSpeech -ne 'Keep') {
    $speech = 'HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy'
    if ($OnlineSpeech -eq 'On') {
        Set-Dword $speech 'HasAccepted' 0
        $log.Add('speech: online speech recognition off (Windows may ask again)')
    }
    else {
        Remove-ItemProperty -Path $speech -Name 'HasAccepted' -Force -ErrorAction SilentlyContinue
        $log.Add('speech: Windows default online speech prompt')
    }
}

# --- inking and typing personalization --------------------------------------------
if ($InkTyping -ne 'Keep') {
    $inputKey = 'HKCU:\Software\Microsoft\InputPersonalization'
    if ($InkTyping -eq 'On') {
        Set-Dword $inputKey 'RestrictImplicitTextCollection' 1
        Set-Dword $inputKey 'RestrictImplicitInkCollection' 1
        $log.Add('input: typing and handwriting samples no longer collected')
    }
    else {
        foreach ($value in 'RestrictImplicitTextCollection', 'RestrictImplicitInkCollection') {
            Remove-ItemProperty -Path $inputKey -Name $value -Force -ErrorAction SilentlyContinue
        }
        $log.Add('input: Windows default personalization')
    }
}

# --- website access to the language list ------------------------------------------
if ($LanguageList -ne 'Keep') {
    $profile = 'HKCU:\Control Panel\International\User Profile'
    if ($LanguageList -eq 'On') {
        Set-Dword $profile 'HttpAcceptLanguageOptOut' 1
        $log.Add('language: websites can no longer read the Windows language list')
    }
    else {
        Remove-ItemProperty -Path $profile -Name 'HttpAcceptLanguageOptOut' -Force -ErrorAction SilentlyContinue
        $log.Add('language: Windows default language list access')
    }
}

# --- tailored experiences ---------------------------------------------------------
if ($TailoredExperiences -ne 'Keep') {
    $privacy = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'
    if ($TailoredExperiences -eq 'On') {
        Set-Dword $privacy 'TailoredExperiencesWithDiagnosticDataEnabled' 0
        $log.Add('privacy: tailored suggestions from diagnostic data off')
    }
    else {
        Remove-ItemProperty -Path $privacy -Name 'TailoredExperiencesWithDiagnosticDataEnabled' -Force -ErrorAction SilentlyContinue
        $log.Add('privacy: Windows default tailored experiences')
    }
}

# --- hidden files in Explorer -----------------------------------------------------
if ($HiddenFiles -ne 'Keep') {
    Set-Dword $adv 'Hidden' $(if ($HiddenFiles -eq 'On') { 1 } else { 0 })
    $log.Add($(if ($HiddenFiles -eq 'On') { 'explorer: hidden files shown (protected system files stay hidden)' } else { 'explorer: hidden files hidden again' }))
}

# --- full path in the title bar ---------------------------------------------------
if ($FullPath -ne 'Keep') {
    $cabinet = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState'
    Set-Dword $cabinet 'FullPath' $(if ($FullPath -eq 'On') { 1 } else { 0 })
    $log.Add($(if ($FullPath -eq 'On') { 'explorer: full folder path in the title bar' } else { 'explorer: Windows default title bar' }))
}

# --- small taskbar icons ----------------------------------------------------------
if ($TaskbarSmallIcons -ne 'Keep') {
    Set-Dword $adv 'TaskbarSmallIcons' $(if ($TaskbarSmallIcons -eq 'On') { 1 } else { 0 })
    $log.Add($(if ($TaskbarSmallIcons -eq 'On') { 'taskbar: small icons (sign out to finish)' } else { 'taskbar: Windows default icon size' }))
}

# --- taskbar preview hover delay --------------------------------------------------
if ($HoverDelay -ne 'Keep') {
    if ($HoverDelay -eq 'On') {
        Set-Dword $adv 'ExtendedUIHoverTime' 0
        $log.Add('taskbar: previews appear without the hover delay (restart Explorer)')
    }
    else {
        Remove-ItemProperty -Path $adv -Name 'ExtendedUIHoverTime' -Force -ErrorAction SilentlyContinue
        $log.Add('taskbar: Windows default preview delay')
    }
}

# --- keyboard repeat rate ---------------------------------------------------------
if ($KeyboardRepeat -ne 'Keep') {
    $keyboard = 'HKCU:\Control Panel\Keyboard'
    if ($KeyboardRepeat -eq 'On') {
        Set-Text $keyboard 'KeyboardDelay' '0'
        Set-Text $keyboard 'KeyboardSpeed' '31'
        $log.Add('keyboard: shortest repeat delay and fastest repeat rate')
    }
    else {
        Set-Text $keyboard 'KeyboardDelay' '1'
        Set-Text $keyboard 'KeyboardSpeed' '31'
        $log.Add('keyboard: Windows default repeat delay')
    }
}

# --- communications ducking -------------------------------------------------------
if ($AudioDucking -ne 'Keep') {
    $audio = 'HKCU:\Software\Microsoft\Multimedia\Audio'
    if ($AudioDucking -eq 'On') {
        Set-Dword $audio 'UserDuckingPreference' 3
        $log.Add('audio: other sounds no longer duck during calls')
    }
    else {
        Remove-ItemProperty -Path $audio -Name 'UserDuckingPreference' -Force -ErrorAction SilentlyContinue
        $log.Add('audio: Windows default communications ducking')
    }
}

# --- restart apps after sign-in ---------------------------------------------------
if ($RestartApps -ne 'Keep') {
    $winlogon = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'
    if ($RestartApps -eq 'On') {
        Set-Dword $winlogon 'RestartApps' 0
        $log.Add('sign-in: Windows will not reopen apps automatically')
    }
    else {
        Remove-ItemProperty -Path $winlogon -Name 'RestartApps' -Force -ErrorAction SilentlyContinue
        $log.Add('sign-in: Windows default app restart behaviour')
    }
}

if (-not $log.Count) { $log.Add('nothing selected') }
$log | ForEach-Object { Write-Output $_ }
