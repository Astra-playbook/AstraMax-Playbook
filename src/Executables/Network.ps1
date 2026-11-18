#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Keep', 'Auto', 'Cloudflare', 'Google', 'Quad9')]
    [string]$Dns = 'Keep',

    [ValidateSet('On', 'Off', 'Keep')]
    [string]$Doh = 'Keep'
)

$ErrorActionPreference = 'SilentlyContinue'

$providers = @{
    Cloudflare = @('1.1.1.1', '1.0.0.1')
    Google     = @('8.8.8.8', '8.8.4.4')
    Quad9      = @('9.9.9.9', '149.112.112.112')
}
$templates = @{
    '1.1.1.1'         = 'https://cloudflare-dns.com/dns-query'
    '1.0.0.1'         = 'https://cloudflare-dns.com/dns-query'
    '8.8.8.8'         = 'https://dns.google/dns-query'
    '8.8.4.4'         = 'https://dns.google/dns-query'
    '9.9.9.9'         = 'https://dns.quad9.net/dns-query'
    '149.112.112.112' = 'https://dns.quad9.net/dns-query'
}

$adapters = @()
if ($Dns -ne 'Keep') {
    $adapters = @(Get-NetIPConfiguration | Where-Object {
            $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up'
        })

    if (-not $adapters.Count) {
        'dns: no adapter with a default gateway, nothing changed'
    }
    foreach ($a in $adapters) {
        if ($Dns -eq 'Auto') {
            Set-DnsClientServerAddress -InterfaceIndex $a.InterfaceIndex -ResetServerAddresses
            "dns: $($a.InterfaceAlias) -> automatic"
        }
        else {
            Set-DnsClientServerAddress -InterfaceIndex $a.InterfaceIndex -ServerAddresses $providers[$Dns]
            "dns: $($a.InterfaceAlias) -> $($providers[$Dns] -join ', ')"
        }
    }
}

if ($Doh -eq 'Keep') { return }

if (-not (Get-Command Add-DnsClientDohServerAddress -ErrorAction SilentlyContinue)) {
    'doh: this Windows build has no DoH cmdlets, skipped'
    return
}

if ($Doh -eq 'On') {
    $servers = @(Get-DnsClientServerAddress -AddressFamily IPv4 |
        ForEach-Object { $_.ServerAddresses } |
        Select-Object -Unique)
    foreach ($ip in $servers) {
        if (-not $templates.ContainsKey($ip)) { continue }
        try {
            Add-DnsClientDohServerAddress -ServerAddress $ip -DohTemplate $templates[$ip] `
                -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction Stop
            "doh: $ip"
        }
        catch {
            "doh skipped: $ip ($($_.Exception.Message))"
        }
    }
}
else {
    foreach ($ip in @(Get-DnsClientDohServerAddress)) {
        if (-not $templates.ContainsKey($ip.ServerAddress)) { continue }
        Remove-DnsClientDohServerAddress -ServerAddress $ip.ServerAddress -Confirm:$false
        "doh removed: $($ip.ServerAddress)"
    }
}
