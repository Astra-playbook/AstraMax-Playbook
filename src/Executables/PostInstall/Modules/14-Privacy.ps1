#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$search = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
$policy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
$system = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
$location = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors'
$ads = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'

if ($Mode -eq 'Status') {
    if ((Get-AstraDword $search 'BingSearchEnabled') -eq 0) { 'ON - web search, activity history and location off' }
    else { 'OFF - Windows defaults' }
    return
}

if ($Mode -eq 'On') {
    Set-AstraDword $search 'BingSearchEnabled' 0
    Set-AstraDword $search 'CortanaConsent' 0
    Set-AstraDword $policy 'AllowCortana' 0
    Set-AstraDword $policy 'DisableWebSearch' 1
    Set-AstraDword $policy 'ConnectedSearchUseWeb' 0
    Set-AstraDword $system 'EnableActivityFeed' 0
    Set-AstraDword $system 'PublishUserActivities' 0
    Set-AstraDword $system 'UploadUserActivities' 0
    Set-AstraDword $location 'DisableLocation' 1
    Set-AstraDword $ads 'Enabled' 0
    'privacy: web search, Copilot search, activity history and location off'
}
else {
    Set-AstraDword $search 'BingSearchEnabled' 1
    Set-AstraDword $search 'CortanaConsent' 1
    Remove-AstraValue $policy 'AllowCortana'
    Set-AstraDword $policy 'DisableWebSearch' 0
    Set-AstraDword $policy 'ConnectedSearchUseWeb' 1
    Set-AstraDword $system 'EnableActivityFeed' 1
    Set-AstraDword $system 'PublishUserActivities' 1
    Set-AstraDword $system 'UploadUserActivities' 1
    Set-AstraDword $location 'DisableLocation' 0
    Set-AstraDword $ads 'Enabled' 1
    'privacy: Windows defaults restored'
}
