#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$interfaces = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
$netbt = 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters'
$dns = 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters'
$wpad = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad'

if ($Mode -eq 'Status') {
    if ((Get-AstraDword $dns 'EnableMulticast') -eq 0) { 'ON - Nagle and legacy name resolution off' }
    else { 'OFF - Windows defaults' }
    return
}

if ($Mode -eq 'On') {
    foreach ($key in @(Get-ChildItem $interfaces)) {
        Set-AstraDword $key.PSPath 'TcpAckFrequency' 1
        Set-AstraDword $key.PSPath 'TCPNoDelay' 1
        Set-AstraDword $key.PSPath 'TcpDelAckTicks' 0
    }
    foreach ($key in @(Get-ChildItem (Join-Path $netbt 'Interfaces'))) {
        Set-AstraDword $key.PSPath 'NetbiosOptions' 2
    }
    Set-AstraDword $dns 'EnableMulticast' 0
    Set-AstraDword $netbt 'EnableLMHOSTS' 0
    Set-AstraDword $wpad 'WpadOverride' 1
    ipconfig /flushdns 2>&1 | Out-Null
    'network latency: Nagle, NetBIOS, LLMNR and WPAD off'
}
else {
    foreach ($key in @(Get-ChildItem $interfaces)) {
        Remove-AstraValue $key.PSPath 'TcpAckFrequency'
        Remove-AstraValue $key.PSPath 'TCPNoDelay'
        Remove-AstraValue $key.PSPath 'TcpDelAckTicks'
    }
    foreach ($key in @(Get-ChildItem (Join-Path $netbt 'Interfaces'))) {
        Set-AstraDword $key.PSPath 'NetbiosOptions' 0
    }
    Set-AstraDword $dns 'EnableMulticast' 1
    Set-AstraDword $netbt 'EnableLMHOSTS' 1
    Remove-AstraValue $wpad 'WpadOverride'
    ipconfig /flushdns 2>&1 | Out-Null
    'network latency: Windows name resolution and Nagle restored'
}
