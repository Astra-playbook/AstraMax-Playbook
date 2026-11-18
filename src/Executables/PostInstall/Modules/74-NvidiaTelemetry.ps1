#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('On', 'Off', 'Status')] [string]$Mode = 'Status')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_Common.ps1')
if ($Mode -ne 'Status' -and -not (Test-AstraAdmin)) { throw 'Administrator rights required' }

$service = 'NvTelemetryContainer'
$stateDir = Join-Path $env:ProgramData 'AstraMax'
$stateFile = Join-Path $stateDir 'NvidiaTelemetry.json'

switch ($Mode) {
    'Status' {
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
        if (-not $svc) { 'OFF - NVIDIA telemetry service not installed (no NVIDIA App or telemetry component)' }
        elseif ($svc.StartType -eq 'Disabled') { 'ON - NVIDIA telemetry service disabled' }
        else { "OFF - NVIDIA telemetry service at $($svc.StartType)" }
    }
    'On' {
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
        if (-not $svc) { 'nvidia telemetry: service not installed; nothing to disable'; break }
        if (-not (Test-Path -LiteralPath $stateFile)) {
            New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
            [pscustomobject]@{
                StartType = [string]$svc.StartType
                Running   = ($svc.Status -eq 'Running')
            } | ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding UTF8
        }
        Set-Service -Name $service -StartupType Disabled
        Stop-Service -Name $service -Force
        'nvidia telemetry: service disabled and stopped; previous startup type saved for OFF'
    }
    'Off' {
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
        if (-not $svc) { 'nvidia telemetry: service not installed; nothing to restore'; break }
        $saved = $null
        if (Test-Path -LiteralPath $stateFile) {
            $saved = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
        }
        $start = if ($saved -and $saved.StartType) { [string]$saved.StartType } else { 'Manual' }
        Set-Service -Name $service -StartupType $start
        if ($saved -and $saved.Running) { Start-Service -Name $service }
        Remove-Item -LiteralPath $stateFile -Force
        "nvidia telemetry: service back at $start$(if ($saved -and $saved.Running) { ' and started' } else { '' })"
    }
}
