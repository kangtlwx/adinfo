[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$DisableExternalEws = $true,
    [switch]$DisableExternalActiveSync = $false,
    [switch]$DisableExternalMapi = $false,
    [switch]$DisableBasicAuthOnOwaEcp = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Set-NullExternalUrl {
    param(
        [Parameter(Mandatory = $true)][string]$Cmd,
        [Parameter(Mandatory = $true)][string]$Identity
    )

    if ($PSCmdlet.ShouldProcess($Identity, "Clear ExternalUrl via $Cmd")) {
        & $Cmd -Identity $Identity -ExternalUrl $null
    }
}

if ($DisableBasicAuthOnOwaEcp) {
    Get-OwaVirtualDirectory | ForEach-Object {
        if ($PSCmdlet.ShouldProcess($_.Identity, 'Disable OWA BasicAuthentication')) {
            Set-OwaVirtualDirectory -Identity $_.Identity -BasicAuthentication:$false
        }
    }

    Get-EcpVirtualDirectory | ForEach-Object {
        if ($PSCmdlet.ShouldProcess($_.Identity, 'Disable ECP BasicAuthentication')) {
            Set-EcpVirtualDirectory -Identity $_.Identity -BasicAuthentication:$false
        }
    }
}

if ($DisableExternalEws) {
    Get-WebServicesVirtualDirectory | ForEach-Object {
        Set-NullExternalUrl -Cmd 'Set-WebServicesVirtualDirectory' -Identity $_.Identity
    }
}

if ($DisableExternalActiveSync) {
    Get-ActiveSyncVirtualDirectory | ForEach-Object {
        Set-NullExternalUrl -Cmd 'Set-ActiveSyncVirtualDirectory' -Identity $_.Identity
    }
}

if ($DisableExternalMapi) {
    Get-MapiVirtualDirectory | ForEach-Object {
        Set-NullExternalUrl -Cmd 'Set-MapiVirtualDirectory' -Identity $_.Identity
    }
}

Write-Host 'Exchange external auth/protocol hardening completed.' -ForegroundColor Green
