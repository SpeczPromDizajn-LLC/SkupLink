@echo off
setlocal EnableExtensions

cd /d "%~dp0"

set "EXE=..\SkupLinkService\SkupLink.exe"

net stop "SkupLink UPS SNMP Agent"

if not exist "%EXE%" (
  echo ERROR: missing "%EXE%"
  exit /b 1
)

"%EXE%" /uninstall /silent
exit /b %ERRORLEVEL%
