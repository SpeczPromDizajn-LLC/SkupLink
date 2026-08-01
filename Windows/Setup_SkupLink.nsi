!include "MUI2.nsh"

!define VERSION "1.0"
!define /date MYTIMESTAMP "%Y_%m_%d"
!define SYSTEM_NAME "SkupLink"
!define SERVICE_DIR "..\SkupLinkService"
!define TRAY_EXE "..\SkupLinkTray\Win32\Release\SkupLinkTray.exe"
!define EXE_NAME "SkupLink"
!define SERVICE_DISPLAY_NAME "SkupLink UPS SNMP Agent"
!define WEB_URL "http://localhost:8847/"

Unicode true
CRCCheck off

!define MUI_ICON "SkupLink.ico"
!define MUI_UNICON "SkupLink.ico"

Name "${SYSTEM_NAME}"
OutFile "Setup_${EXE_NAME}_${VERSION}_${MYTIMESTAMP}.exe"
InstallDir $PROGRAMFILES\${EXE_NAME}
RequestExecutionLevel admin

SetCompressor BZIP2

ReserveFile "${NSISDIR}\Contrib\Graphics\Wizard\win.bmp"
ReserveFile "${NSISDIR}\Contrib\Graphics\Icons\modern-install-full.ico"
ReserveFile "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall-full.ico"
ReserveFile /plugin LangDLL.dll

!define MUI_LANGDLL_REGISTRY_ROOT "HKLM"
!define MUI_LANGDLL_REGISTRY_KEY "Software\${EXE_NAME}"
!define MUI_LANGDLL_REGISTRY_VALUENAME "Installer Language"
!define MUI_LANGDLL_WINDOWTITLE "$R0"
!define MUI_LANGDLL_INFO "$R1"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "LICENSE"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Russian"

Page instfiles

LangString PUBLISHER ${LANG_ENGLISH} "SpecPromDizajn LLC"
LangString PUBLISHER ${LANG_RUSSIAN} "ќќќ —пецѕромƒизайн"
LangString DESC_Service ${LANG_ENGLISH} "SkupLink service: SNMP polling, HTTP API and web UI."
LangString DESC_Service ${LANG_RUSSIAN} "—лужба SkupLink: опрос SNMP, HTTP API и веб-интерфейс."
LangString DESC_Tray ${LANG_ENGLISH} "Windows notification area icon (UPS status, quick access to the web UI)."
LangString DESC_Tray ${LANG_RUSSIAN} "»конка в области уведомлений Windows (статус »Ѕѕ, быстрый доступ к веб-UI)."
LangString SEC_Service ${LANG_ENGLISH} "SkupLink"
LangString SEC_Service ${LANG_RUSSIAN} "SkupLink"
LangString SEC_Tray ${LANG_ENGLISH} "SkupLink Tray"
LangString SEC_Tray ${LANG_RUSSIAN} "SkupLink Tray"
LangString SHORTCUT_Uninstall ${LANG_ENGLISH} "Uninstall ${SYSTEM_NAME}"
LangString SHORTCUT_Uninstall ${LANG_RUSSIAN} "”далить ${SYSTEM_NAME}"

Function .onInit
  StrCmp $LANGUAGE ${LANG_RUSSIAN} 0 lang_dll_en
    StrCpy $R0 "язык установщика"
    StrCpy $R1 "¬ыберите €зык установки"
    Goto lang_dll_show
  lang_dll_en:
    StrCpy $R0 "Installer Language"
    StrCpy $R1 "Please select a language"
  lang_dll_show:
  !insertmacro MUI_LANGDLL_DISPLAY
FunctionEnd

Function un.onInit
  !insertmacro MUI_UNGETLANGUAGE
FunctionEnd

Section "$(SEC_Service)" SecService
  SectionIn RO

  ClearErrors
  ExecWait 'taskkill /IM SkupLinkTray.exe /F'
  ClearErrors
  ExecWait 'net stop "${SERVICE_DISPLAY_NAME}"'
  ClearErrors
  IfFileExists "$INSTDIR\${EXE_NAME}.exe" 0 skip_old_unreg
    ExecWait '"$INSTDIR\${EXE_NAME}.exe" /uninstall /silent'
  skip_old_unreg:

  SetOutPath $INSTDIR

  File "${SERVICE_DIR}\${EXE_NAME}.exe"
  File "${SERVICE_DIR}\config.example.json"
  File "LICENSE"
  File "SkupLink.ico"

  SetOutPath $INSTDIR\web
  File "${SERVICE_DIR}\web\app.css"
  File "${SERVICE_DIR}\web\app.js"
  File "${SERVICE_DIR}\web\favicon.svg"
  File "${SERVICE_DIR}\web\index.html"
  File "${SERVICE_DIR}\web\lang.js"

  SetOutPath $INSTDIR

  CreateDirectory "$COMMONPROGRAMDATA\${EXE_NAME}"
  CopyFiles /SILENT "$INSTDIR\config.example.json" "$COMMONPROGRAMDATA\${EXE_NAME}\config.json"

  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${EXE_NAME}" "DisplayName" "${SYSTEM_NAME}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${EXE_NAME}" "DisplayIcon" "$INSTDIR\SkupLink.ico"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${EXE_NAME}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${EXE_NAME}" "Publisher" "$(PUBLISHER)"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${EXE_NAME}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${EXE_NAME}" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${EXE_NAME}" "NoRepair" 1

  WriteUninstaller "uninstall.exe"

  CreateDirectory "$SMPROGRAMS\${SYSTEM_NAME}"
  WriteINIStr "$DESKTOP\${SYSTEM_NAME} Web UI.url" "InternetShortcut" "URL" "${WEB_URL}"
  WriteINIStr "$SMPROGRAMS\${SYSTEM_NAME}\${SYSTEM_NAME} Web UI.url" "InternetShortcut" "URL" "${WEB_URL}"
  CreateShortcut "$SMPROGRAMS\${SYSTEM_NAME}\$(SHORTCUT_Uninstall).lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0

  ExecWait '"$INSTDIR\${EXE_NAME}.exe" /install /silent'
  ExecWait 'net start "${SERVICE_DISPLAY_NAME}"'
SectionEnd

Section "$(SEC_Tray)" SecTray
  SetOutPath $INSTDIR
  File "${TRAY_EXE}"

  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "SkupLinkTray" '"$INSTDIR\SkupLinkTray.exe"'
  Delete "$SMSTARTUP\SkupLinkTray.lnk"
SectionEnd

Function .onInstSuccess
  SectionGetFlags ${SecTray} $0
  IntOp $0 $0 & ${SF_SELECTED}
  IntCmp $0 0 skip_tray_run
    ExecShell "" "$INSTDIR\SkupLinkTray.exe"
  skip_tray_run:
  ExecShell "open" "${WEB_URL}"
FunctionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecService} $(DESC_Service)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecTray} $(DESC_Tray)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Section "Uninstall"
  SectionIn RO

  ClearErrors
  ExecWait 'net stop "${SERVICE_DISPLAY_NAME}"'
  ClearErrors
  ExecWait '"$INSTDIR\${EXE_NAME}.exe" /uninstall /silent'

  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${EXE_NAME}"
  DeleteRegKey HKLM "Software\${EXE_NAME}"

  ExecWait 'taskkill /IM SkupLinkTray.exe /F'

  DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "SkupLinkTray"
  Delete "$DESKTOP\${SYSTEM_NAME} Web UI.url"
  Delete "$SMSTARTUP\SkupLinkTray.lnk"
  Delete "$SMPROGRAMS\${SYSTEM_NAME}\*.*"
  RMDir "$SMPROGRAMS\${SYSTEM_NAME}"

  RMDir /r "$INSTDIR\web"
  Delete "$INSTDIR\*.*"
  RMDir "$INSTDIR"
SectionEnd
