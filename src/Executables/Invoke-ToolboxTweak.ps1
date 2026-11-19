#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('qol.search-history-off','exm-notification-sound-off','exm-restart-sign-on-off','abs.app.chrome-background-off','exm-chrome-online-spelling-off','exm-chrome-geolocation-off','max.visual.wallpaper-full-quality',
        'sys-first-signin-animation-off','sys-signin-account-details-off','sys-start-recent-apps-off','sys-app-account-info-off','sys-app-contacts-off',
        'chrome-search-suggestions-off','chrome-network-prediction-off','chrome-third-party-cookies-off','chrome-website-notifications-off','chrome-translation-off','chrome-download-location-prompt','chrome-cast-off','chrome-memory-saver-on','chrome-low-battery-saver-on',
        'exm-settings-online-tips-off','exm-store-push-install-off','exm-message-cloud-sync-off',
        'exm-chrome-sensors-off','exm-chrome-serial-off','exm-chrome-bluetooth-off','exm-chrome-webusb-off',
        'exm-chrome-feedback-off','exm-chrome-spellchecking-off',
        'exm-app-calendar-off','exm-app-email-off','exm-app-messaging-off','exm-app-phone-off',
        'exm-app-diagnostics-off','exm-app-call-history-off','exm-app-tasks-off','exm-app-notification-reading-off',
        'exm-app-radio-control-off','exm-app-unpaired-device-sync-off','sys-app-motion-off')]
    [string]$Id,
    [switch]$Restore
)
$ErrorActionPreference = 'Stop'
$runtime = Join-Path ${env:ProgramFiles} 'dotnet\shared\Microsoft.WindowsDesktop.App'
if (-not @(Get-ChildItem -LiteralPath $runtime -Directory -ErrorAction SilentlyContinue | Where-Object Name -like '8.*').Count) {
    $installer = Join-Path $PSScriptRoot 'Redist\windowsdesktop-runtime-8.0.34-win-x64.exe'
    if (-not (Test-Path -LiteralPath $installer)) { throw 'Install the bundled .NET Desktop Runtime 8 x64 before applying toolbox settings.' }
    $setup = Start-Process -FilePath $installer -ArgumentList '/install','/quiet','/norestart' -Wait -PassThru
    if ($setup.ExitCode -notin 0,3010) { throw "Required .NET Desktop Runtime failed: $($setup.ExitCode)" }
}
$exe = Join-Path $PSScriptRoot 'Toolbox\Astra-Toolbox.exe'
$action = if ($Restore) { '--revert-option' } else { '--apply-option' }
$process = Start-Process -FilePath $exe -ArgumentList $action,$Id -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Toolbox $action failed for $Id (exit $($process.ExitCode)); see LocalAppData\AstraPC\Logs\toolbox-cli.log" }
"toolbox: $action $Id completed"
