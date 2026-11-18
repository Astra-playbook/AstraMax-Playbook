#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$usb = '2a737441-1930-4402-8d77-b2bebba308a3'
$setting = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'

switch ($Mode) {
    'Status' {
        $ac = Get-AstraPowerIndex $usb $setting 'AC'
        if ($ac -eq 0) { 'ON - USB selective suspend disabled' }
        elseif ($null -eq $ac) { 'MIXED - USB power setting not readable' }
        else { 'OFF - USB devices may be suspended' }
    }
    'On' {
        Set-AstraPowerIndex $usb $setting 0 0
        'usb: selective suspend off on AC and DC'
    }
    'Off' {
        Set-AstraPowerIndex $usb $setting 1 1
        'usb: selective suspend back to default'
    }
}
