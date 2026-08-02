@echo off
setlocal EnableExtensions

cd /d "%~dp0"

set "EXE=..\SkupLinkService\SkupLink.exe"
REM Must match Common.pas STR_SERVICE_DISPLAY_NAME
set "SERVICE_DISPLAY_NAME=SkupLink UPS SNMP Agent"

net stop "%SERVICE_DISPLAY_NAME%"

if not exist "%EXE%" (
  echo ERROR: missing "%EXE%"
  exit /b 1
)

"%EXE%" /uninstall /silent
exit /b %ERRORLEVEL%
