# sign-test.ps1 — sign a GoDesk installer with the internal-test self-signed
# certificate. NOT a public-trust cert; SmartScreen will warn unless the
# cert is imported into Trusted Root + Trusted Publisher on the test machine
# (see infra/installer/README.md → "Internal-test signing").
#
# Usage:
#   pwsh -File .\sign-test.ps1 -Installer ..\..\dist\GoDesk-Setup-x64-0.1.3.exe
#
# Pre-requisites (one-time, see README):
#   1. branding/keys/godesk-test.pfx exists (created via New-SelfSignedCertificate)
#   2. signtool.exe is available — comes with Windows 10 SDK
#
# This script auto-discovers signtool.exe under "C:\Program Files (x86)\Windows Kits\10\bin\".

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Installer,

    [string]$Pfx = "$PSScriptRoot\..\..\branding\keys\godesk-test.pfx",
    [string]$PfxPassword = "godesk-internal",
    [string]$TimestampUrl = "http://timestamp.digicert.com"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Installer)) {
    throw "Installer not found: $Installer"
}
if (-not (Test-Path $Pfx)) {
    throw "PFX not found: $Pfx — create it via README → 'Internal-test signing → 1. Create cert'"
}

# Auto-discover signtool — pick the newest x64 build.
$kitsRoot = "C:\Program Files (x86)\Windows Kits\10\bin"
$signtool = Get-ChildItem $kitsRoot -Recurse -Filter signtool.exe -ErrorAction SilentlyContinue `
    | Where-Object { $_.FullName -like "*x64*" } `
    | Sort-Object FullName -Descending `
    | Select-Object -First 1
if (-not $signtool) {
    throw "signtool.exe not found under $kitsRoot — install Windows 10 SDK"
}

Write-Host "Signing $Installer"
Write-Host "  Cert: $Pfx"
Write-Host "  Tool: $($signtool.FullName)"

& $signtool.FullName sign `
    /f $Pfx `
    /p $PfxPassword `
    /tr $TimestampUrl `
    /td sha256 `
    /fd sha256 `
    $Installer

if ($LASTEXITCODE -ne 0) {
    throw "signtool failed (exit $LASTEXITCODE)"
}

# Verify locally — checks the signature is structurally valid + timestamped.
# It will report NotTrusted on machines without the cert imported, which is
# expected for internal-test certs.
$sig = Get-AuthenticodeSignature $Installer
Write-Host ""
Write-Host "Signature status: $($sig.Status)"
Write-Host "Signed by      : $($sig.SignerCertificate.Subject)"
if ($sig.TimeStamperCertificate) {
    Write-Host "Timestamped by : $($sig.TimeStamperCertificate.Subject)"
}
if ($sig.Status -ne 'Valid' -and $sig.Status -ne 'UnknownError' -and $sig.Status -ne 'NotTrusted') {
    throw "Unexpected signature status: $($sig.Status)"
}
Write-Host ""
Write-Host "Done. On test machines without the cert imported, SmartScreen will still"
Write-Host "warn. Run install-test-cert.ps1 from this folder once per test machine to"
Write-Host "suppress the warning."
