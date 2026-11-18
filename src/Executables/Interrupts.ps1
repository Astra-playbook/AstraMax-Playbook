[CmdletBinding()]
param(
    [ValidateSet('Msi', 'Spread', 'Pin')]
    [string]$Mode = 'Msi'
)

$ErrorActionPreference = 'SilentlyContinue'
$applied = New-Object System.Collections.Generic.List[string]

# Only touch devices whose drivers already expose interrupt management keys.
# MSISupported is safe to set there; forcing it on devices without the key can hang boot.
foreach ($dev in @(Get-PnpDevice -Class Display, Net -Status OK)) {
    $base = Join-Path 'HKLM:\SYSTEM\CurrentControlSet\Enum' $dev.InstanceId
    if (-not (Test-Path -LiteralPath $base)) { continue }

    $msi = Join-Path $base 'Device Parameters\Interrupt Management\MessageSignaledInterruptProperties'
    if (Test-Path -LiteralPath $msi) {
        Set-ItemProperty -Path $msi -Name 'MSISupported' -Type DWord -Value 1 -Force
        $applied.Add("msi: $($dev.FriendlyName)")
    }

    if ($Mode -eq 'Msi') { continue }

    $aff = Join-Path $base 'Device Parameters\Interrupt Management\Affinity Policy'
    New-Item -Path $aff -Force | Out-Null

    if ($Mode -eq 'Spread') {
        # IrqPolicySpreadMessagesAcrossAllProcessors
        Set-ItemProperty -Path $aff -Name 'DevicePolicy' -Type DWord -Value 5 -Force
        Remove-ItemProperty -Path $aff -Name 'AssignmentSetOverride' -Force
    }
    else {
        # IrqPolicySpecifiedProcessors, mask = every CPU except core 0
        Set-ItemProperty -Path $aff -Name 'DevicePolicy' -Type DWord -Value 4 -Force
        $mask = New-Object byte[] 8
        $mask[0] = 0xFE
        for ($i = 1; $i -lt 8; $i++) { $mask[$i] = 0xFF }
        Set-ItemProperty -Path $aff -Name 'AssignmentSetOverride' -Type Binary -Value $mask -Force
    }
    $applied.Add("affinity ($Mode): $($dev.FriendlyName)")
}

if (-not $applied.Count) { $applied.Add('interrupts: no matching GPU/NIC devices found') }
$applied | ForEach-Object { Write-Host $_ }
