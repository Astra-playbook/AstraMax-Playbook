#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$key = 'HKCU:\Control Panel\Mouse'

function Set-AstraPointer {
    param([int]$Speed, [int]$T1, [int]$T2)
    foreach ($pair in @(@{ N = 'MouseSpeed'; V = "$Speed" }, @{ N = 'MouseThreshold1'; V = "$T1" }, @{ N = 'MouseThreshold2'; V = "$T2" })) {
        Set-AstraText $key $pair.N $pair.V
    }
    if (-not ('AstraPostMouse' -as [type])) {
        Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
namespace AstraPostMouse {
    public static class Native {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SystemParametersInfo(uint action, uint param, int[] values, uint flags);
    }
}
'@
    }
    [void][AstraPostMouse.Native]::SystemParametersInfo(0x0004, 0, @($Speed, $T1, $T2), 3)
}

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $key 'MouseSpeed') -eq 0) { 'ON - mouse acceleration off' }
        else { 'OFF - Windows pointer acceleration' }
    }
    'On' {
        Set-AstraPointer 0 0 0
        'mouse: acceleration off'
    }
    'Off' {
        Set-AstraPointer 1 6 10
        'mouse: Windows acceleration restored'
    }
}
