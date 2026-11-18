#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$data = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
$cloud = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
$ads = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
$siuf = 'HKCU:\Software\Microsoft\Siuf\Rules'
$do = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'

$tasks = @(
    @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'Consolidator' },
    @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'UsbCeip' },
    @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'KernelCeipTask' },
    @{ Path = '\Microsoft\Windows\Feedback\Siuf\'; Name = 'DmClient' },
    @{ Path = '\Microsoft\Windows\Feedback\Siuf\'; Name = 'DmClientOnScenarioDownload' },
    @{ Path = '\Microsoft\Windows\Device Information\'; Name = 'Device' },
    @{ Path = '\Microsoft\Windows\Device Information\'; Name = 'Device User' },
    @{ Path = '\Microsoft\Windows\DiskDiagnostic\'; Name = 'Microsoft-Windows-DiskDiagnosticDataCollector' }
)

if ($Mode -eq 'Status') {
    if ((Get-AstraDword $data 'AllowTelemetry') -eq 0) { 'ON - telemetry off' } else { 'OFF - Windows default' }
    return
}

if ($Mode -eq 'On') {
    Set-AstraDword $data 'AllowTelemetry' 0
    Set-AstraDword $data 'DoNotShowFeedbackNotifications' 1
    Set-AstraDword $cloud 'DisableTailoredExperiencesWithDiagnosticData' 1
    Set-AstraDword $ads 'Enabled' 0
    Set-AstraDword $siuf 'NumberOfSIUFInPeriod' 0
    Set-AstraDword $do 'DODownloadMode' 0
    foreach ($t in $tasks) { Disable-ScheduledTask -TaskPath $t.Path -TaskName $t.Name -ErrorAction SilentlyContinue | Out-Null }
    'telemetry: policy off, ads ID off, 8 CEIP tasks disabled'
}
else {
    Remove-AstraValue $data 'AllowTelemetry'
    Remove-AstraValue $data 'DoNotShowFeedbackNotifications'
    Remove-AstraValue $cloud 'DisableTailoredExperiencesWithDiagnosticData'
    Set-AstraDword $ads 'Enabled' 1
    Remove-AstraValue $siuf 'NumberOfSIUFInPeriod'
    Remove-AstraValue $do 'DODownloadMode'
    foreach ($t in $tasks) { Enable-ScheduledTask -TaskPath $t.Path -TaskName $t.Name -ErrorAction SilentlyContinue | Out-Null }
    'telemetry: policies removed, CEIP tasks enabled'
}
