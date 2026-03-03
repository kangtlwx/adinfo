[CmdletBinding()]
param(
    [string]$SiteName = 'Default Web Site'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module WebAdministration

$paths = @('owa', 'ecp')
foreach ($path in $paths) {
    $location = "$SiteName/$path"
    Write-Host "=== $location ===" -ForegroundColor Cyan

    $allowUnlisted = Get-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Filter 'system.webServer/security/ipSecurity' -Location $location -Name allowUnlisted
    Write-Host "allowUnlisted: $allowUnlisted"

    $rules = Get-WebConfiguration -PSPath 'MACHINE/WEBROOT/APPHOST' -Filter 'system.webServer/security/ipSecurity/add' -Location $location
    if ($null -eq $rules.Collection -or $rules.Collection.Count -eq 0) {
        Write-Warning 'No IP allow rules found.'
    } else {
        $rules.Collection | ForEach-Object {
            Write-Host ("Rule: {0}/{1} allowed={2}" -f $_.ipAddress, $_.subnetMask, $_.allowed)
        }
    }
}

Write-Host '--- Firewall rules on port 443 ---' -ForegroundColor Cyan
Get-NetFirewallRule -Direction Inbound -Enabled True |
    Get-NetFirewallPortFilter |
    Where-Object { $_.Protocol -eq 'TCP' -and $_.LocalPort -eq '443' } |
    Select-Object Name, LocalPort, Protocol

Write-Host 'Validation script completed.' -ForegroundColor Green
