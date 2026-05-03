; GoDesk Windows installer — NSIS script.
; Phase 4 deliverable per wiki/roadmap.md.
;
; Build prerequisites:
;   - NSIS 3.x installed (https://nsis.sourceforge.io/Download)
;   - Modern UI 2 + nsDialogs (bundled with NSIS)
;   - Optionally: signtool.exe for code-signing (Phase 4 OV cert step)
;
; Build:
;   makensis /DGODESK_VERSION=0.1.0 godesk.nsi
;
; Output:
;   GoDesk-Setup-x64-0.1.0.exe
;
; Signing (after cert is bought):
;   signtool sign /f godesk-cs.pfx /p PASSWORD ^
;     /tr http://timestamp.sectigo.com /td sha256 /fd sha256 ^
;     GoDesk-Setup-x64-0.1.0.exe

!ifndef GODESK_VERSION
  !define GODESK_VERSION "0.1.0"
!endif

!define APP_NAME       "GoDesk"
!define APP_PUBLISHER  "GoDesk Contributors"
!define APP_URL        "https://godeskflow.com"
!define APP_SUPPORT    "https://godeskflow.com/help"
!define APP_LICENSE    "AGPL-3.0-only"
!define APP_BUNDLE_ID  "com.godesk.client"
!define APP_EXE        "godesk.exe"
!define UNINST_KEY     "Software\Microsoft\Windows\CurrentVersion\Uninstall\GoDesk"

!include "MUI2.nsh"
!include "FileFunc.nsh"

Name              "${APP_NAME} ${GODESK_VERSION}"
OutFile           "..\..\dist\GoDesk-Setup-x64-${GODESK_VERSION}.exe"
InstallDir        "$PROGRAMFILES64\${APP_NAME}"
InstallDirRegKey  HKLM "Software\${APP_NAME}" "InstallDir"
RequestExecutionLevel admin
Unicode           true
SetCompressor     /SOLID lzma

VIProductVersion "${GODESK_VERSION}.0"
VIAddVersionKey  "ProductName"     "${APP_NAME}"
VIAddVersionKey  "CompanyName"     "${APP_PUBLISHER}"
VIAddVersionKey  "FileDescription" "${APP_NAME} installer"
VIAddVersionKey  "FileVersion"     "${GODESK_VERSION}"
VIAddVersionKey  "ProductVersion"  "${GODESK_VERSION}"
VIAddVersionKey  "LegalCopyright"  "Copyright (C) 2026 ${APP_PUBLISHER}. ${APP_LICENSE}."

!define MUI_ABORTWARNING
!define MUI_ICON   "..\..\client\flutter_godesk\windows\runner\resources\app_icon.ico"
!define MUI_UNICON "..\..\client\flutter_godesk\windows\runner\resources\app_icon.ico"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "..\..\branding\installer\header.bmp"
!define MUI_WELCOMEFINISHPAGE_BITMAP "..\..\branding\installer\sidebar.bmp"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE  "..\..\LICENSE"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_LINK "Visit ${APP_URL}"
!define MUI_FINISHPAGE_LINK_LOCATION "${APP_URL}"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

!insertmacro MUI_LANGUAGE "English"

Section "${APP_NAME}" SecMain
  SectionIn RO
  SetOutPath "$INSTDIR"

  ; Copy entire flutter build output. The Flutter build emits the EXE plus
  ; required runtime DLLs and the data/ directory; we ship them all.
  File /r "..\..\client\flutter_godesk\build\windows\x64\runner\Release\*"

  ; Rename the binary the build emits (flutter_godesk.exe) to godesk.exe.
  ; (Flutter's `--release` keeps the project name; the rename happens at
  ; install time so the installed app is consistent with the rebrand.)
  IfFileExists "$INSTDIR\flutter_godesk.exe" 0 +3
    Rename "$INSTDIR\flutter_godesk.exe" "$INSTDIR\${APP_EXE}"
    ; If a stale godesk.exe exists, the rename will fail silently — accept it.

  ; Start menu + desktop shortcuts
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortcut  "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
  CreateShortcut  "$DESKTOP\${APP_NAME}.lnk"                "$INSTDIR\${APP_EXE}"

  ; Uninstaller
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  ; Add/Remove Programs entry
  WriteRegStr   HKLM "${UNINST_KEY}" "DisplayName"     "${APP_NAME}"
  WriteRegStr   HKLM "${UNINST_KEY}" "DisplayVersion"  "${GODESK_VERSION}"
  WriteRegStr   HKLM "${UNINST_KEY}" "Publisher"       "${APP_PUBLISHER}"
  WriteRegStr   HKLM "${UNINST_KEY}" "URLInfoAbout"    "${APP_URL}"
  WriteRegStr   HKLM "${UNINST_KEY}" "HelpLink"        "${APP_SUPPORT}"
  WriteRegStr   HKLM "${UNINST_KEY}" "DisplayIcon"     "$INSTDIR\${APP_EXE},0"
  WriteRegStr   HKLM "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr   HKLM "${UNINST_KEY}" "UninstallString" "$INSTDIR\Uninstall.exe"
  WriteRegStr   HKLM "${UNINST_KEY}" "QuietUninstallString" "$INSTDIR\Uninstall.exe /S"
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoRepair" 1

  ; Compute install size for Add/Remove Programs
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKLM "${UNINST_KEY}" "EstimatedSize" "$0"

  ; Persist install dir for upgrades
  WriteRegStr HKLM "Software\${APP_NAME}" "InstallDir"     "$INSTDIR"
  WriteRegStr HKLM "Software\${APP_NAME}" "Version"        "${GODESK_VERSION}"
  WriteRegStr HKLM "Software\${APP_NAME}" "BundleId"       "${APP_BUNDLE_ID}"
SectionEnd

Section "Uninstall"
  ; Stop running instance, if any
  ExecWait 'taskkill /F /IM ${APP_EXE}'

  ; Remove shortcuts
  Delete    "$DESKTOP\${APP_NAME}.lnk"
  Delete    "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
  RMDir     "$SMPROGRAMS\${APP_NAME}"

  ; Remove install dir (recursive)
  RMDir /r "$INSTDIR"

  ; Registry cleanup
  DeleteRegKey HKLM "${UNINST_KEY}"
  DeleteRegKey HKLM "Software\${APP_NAME}"
SectionEnd
