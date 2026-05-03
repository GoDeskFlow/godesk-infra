# install-test-cert.ps1 — import GoDesk's internal-test code-signing cert into
# the LocalMachine trust stores so SmartScreen does not warn on signed builds.
#
# RUN AS ADMINISTRATOR. The two stores below require elevation.
#
# Usage on each test machine:
#   1. Copy godesk-test.cer (the public part) alongside this script
#   2. Right-click PowerShell → Run as Administrator
#   3. cd <folder with the script>
#   4. .\install-test-cert.ps1
#
# To uninstall later: remove the cert from both Cert:\LocalMachine\Root and
# Cert:\LocalMachine\TrustedPublisher (use certmgr.msc or Get-ChildItem +
# Remove-Item).

[CmdletBinding()]
param(
    [string]$Cer = "$PSScriptRoot\godesk-test.cer"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Cer)) {
    throw "Cert file not found: $Cer — get it from the GoDesk maintainer"
}

# Sanity: are we admin?
$admin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    throw "This script must be run as Administrator. Right-click PowerShell → Run as Administrator."
}

Write-Host "Importing $Cer into Trusted Root..."
Import-Certificate -FilePath $Cer -CertStoreLocation Cert:\LocalMachine\Root | Out-Null

Write-Host "Importing $Cer into Trusted Publisher..."
Import-Certificate -FilePath $Cer -CertStoreLocation Cert:\LocalMachine\TrustedPublisher | Out-Null

Write-Host ""
Write-Host "Done. GoDesk installers signed with this cert will now run without"
Write-Host "SmartScreen warnings on this machine."
Write-Host ""
Write-Host "Verify a signed installer:"
Write-Host "  Get-AuthenticodeSignature .\GoDesk-Setup-x64-X.Y.Z.exe | Format-List Status, SignerCertificate"
