[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$TrustedProxyCidrs = @(
        '192.0.2.10/32',
        '198.51.100.20/32'
    ),

    [Parameter(Mandatory = $false)]
    [string]$SiteName = 'Default Web Site'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Convert-CidrToIpMask {
    param([Parameter(Mandatory = $true)][string]$Cidr)

    if ($Cidr -notmatch '^(.+?)/(\d{1,2})$') {
        throw "Invalid CIDR format: $Cidr"
    }

    $ip = $Matches[1]
    $prefix = [int]$Matches[2]

    if ($prefix -lt 0 -or $prefix -gt 32) {
        throw "Invalid CIDR prefix in: $Cidr"
    }

    $mask = [uint32]0
    for ($i = 0; $i -lt $prefix; $i++) {
        $mask = $mask -bor (1 -shl (31 - $i))
    }

    $maskBytes = [BitConverter]::GetBytes([uint32]$mask)
    [Array]::Reverse($maskBytes)
    $maskString = ($maskBytes | ForEach-Object { [int]$_ }) -join '.'

    [PSCustomObject]@{
        IpAddress = $ip
        SubnetMask = $maskString
    }
}

Import-Module WebAdministration

$paths = @('owa', 'ecp')

foreach ($path in $paths) {
    $location = "$SiteName/$path"

    if ($PSCmdlet.ShouldProcess($location, 'Enable IP restrictions')) {
        Set-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Filter "system.webServer/security/ipSecurity" -Location $location -Name allowUnlisted -Value $false
        Clear-WebConfiguration -PSPath 'MACHINE/WEBROOT/APPHOST' -Filter "system.webServer/security/ipSecurity/add" -Location $location -ErrorAction SilentlyContinue

        foreach ($cidr in $TrustedProxyCidrs) {
            $rule = Convert-CidrToIpMask -Cidr $cidr
            Add-WebConfiguration -PSPath 'MACHINE/WEBROOT/APPHOST' -Filter "system.webServer/security/ipSecurity" -Location $location -Value @{ipAddress = $rule.IpAddress; subnetMask = $rule.SubnetMask; allowed = 'true'}
        }
    }
}

$ruleName = 'Allow HTTPS From Trusted Proxies Only'

if ($PSCmdlet.ShouldProcess('Windows Firewall', 'Set inbound 443 allow list')) {
    Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue

    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort 443 -RemoteAddress ($TrustedProxyCidrs -join ',') | Out-Null

    # Optional hard deny for all other 443 traffic.
    # Enable this only after validating management paths and internal health probes.
    # New-NetFirewallRule -DisplayName 'Block HTTPS From Untrusted Sources' -Direction Inbound -Action Block -Protocol TCP -LocalPort 443 -RemoteAddress 'Any' | Out-Null
}

Write-Host 'OWA/ECP hardening completed.' -ForegroundColor Green
