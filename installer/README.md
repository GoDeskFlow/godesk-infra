# GoDesk Windows installer

NSIS script that bundles `flutter_godesk` Release build into a signed-ready
installer. Phase 4 deliverable.

## One-time setup on the build machine

1. Install NSIS 3.x — `winget install NSIS.NSIS` or download from
   <https://nsis.sourceforge.io/Download>. Adds `makensis` to PATH.
2. (Phase 4 only — not needed for unsigned dev builds) install Windows SDK's
   `signtool.exe` (already present if VS Build Tools have C++ workload).

## Build the installer

```powershell
# 1. Build the Flutter Release binary
cd D:\Vibecoding\GoDesk\client\flutter_godesk
flutter build windows --release

# 2. Build the installer
cd D:\Vibecoding\GoDesk\infra\installer
makensis /DGODESK_VERSION=0.1.0 godesk.nsi
```

Output: `D:\Vibecoding\GoDesk\dist\GoDesk-Setup-x64-0.1.0.exe`.

## Sign (Phase 4, after OV cert is bought)

```powershell
signtool sign /f godesk-cs.pfx /p $env:GODESK_CS_PASSWORD `
  /tr http://timestamp.sectigo.com /td sha256 /fd sha256 `
  ..\..\dist\GoDesk-Setup-x64-0.1.0.exe
```

Verify:

```powershell
signtool verify /pa /v ..\..\dist\GoDesk-Setup-x64-0.1.0.exe
```

## What gets installed

- `C:\Program Files\GoDesk\godesk.exe` (renamed from `flutter_godesk.exe`)
- All Flutter runtime DLLs and the `data/` directory (assets, fonts, snapshot)
- Start menu shortcut: `Start → GoDesk`
- Desktop shortcut
- Add/Remove Programs entry (publisher = "GoDesk Contributors", URL = godeskflow.com)
- Uninstaller in install dir + registry pointer

## What is NOT included yet

- Code signature (Phase 4 cert purchase pending)
- `branding/installer/header.bmp` and `sidebar.bmp` — placeholder design assets
  for the welcome panel; until they exist, the `MUI_HEADERIMAGE` lines can be
  commented out and NSIS uses its default look. Drop final BMPs (164×314 sidebar,
  150×57 header) when branding is ready.
- Auto-update wiring (RustDesk has its own update channel; we point it at
  `update.godeskflow.com` in Phase 4 alongside signing).
- License file — the script references `..\..\LICENSE` which will be the AGPL
  text from upstream RustDesk. Drop it at the project root before building.

## Smoke test

After building and (optionally) signing:

```powershell
# Fresh Win11 VM:
.\GoDesk-Setup-x64-0.1.0.exe   # silent: /S
# Verify:
#   - SmartScreen does NOT block (signed builds; unsigned builds will warn)
#   - Install completes without admin prompts beyond the initial UAC
#   - Start menu has GoDesk
#   - GoDesk window opens, title says "GoDesk" (not "flutter_godesk")
#   - Uninstaller from Add/Remove Programs cleans everything
```
