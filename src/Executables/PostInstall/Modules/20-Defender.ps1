#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$policy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'
$rt = Join-Path $policy 'Real-Time Protection'

if ($Mode -eq 'Status') {
    $mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($null -eq $mp) { 'UNKNOWN - Defender status unavailable' }
    elseif ($mp.RealTimeProtectionEnabled) { 'OFF - real-time protection on' }
    else { 'ON - real-time protection off' }
    return
}

if ($Mode -eq 'On') {
    Set-AstraDword $policy 'DisableAntiSpyware' 1
    Set-AstraDword $rt 'DisableRealtimeMonitoring' 1
    Set-MpPreference -DisableRealtimeMonitoring $true -DisableIOAVProtection $true -ErrorAction SilentlyContinue
    Set-AstraService 'WinDefend' 'Disabled'
    'defender: real-time protection off (tamper protection may override this)'
}
else {
    Remove-AstraValue $policy 'DisableAntiSpyware'
    Remove-AstraValue $rt 'DisableRealtimeMonitoring'
    Set-MpPreference -DisableRealtimeMonitoring $false -DisableIOAVProtection $false -ErrorAction SilentlyContinue
    Set-AstraService 'WinDefend' 'Automatic'
    'defender: real-time protection on'
}
