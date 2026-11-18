#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters'

switch ($Mode) {
    'Status' {
        if ((Get-AstraDword $path 'EnablePrefetcher') -eq 0) { 'ON - prefetch off' }
        else { 'OFF - prefetch enabled' }
    }
    'On' {
        Set-AstraDword $path 'EnablePrefetcher' 0
        Set-AstraDword $path 'EnableSuperfetch' 0
        'prefetch: off'
    }
    'Off' {
        Set-AstraDword $path 'EnablePrefetcher' 3
        Set-AstraDword $path 'EnableSuperfetch' 3
        'prefetch: Windows default'
    }
}
