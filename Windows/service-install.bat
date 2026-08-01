@echo off
setlocal EnableExtensions

cd /d "%~dp0"

set "EXE=..\SkupLinkService\SkupLink.exe"

if not exist "%EXE%" (
  echo ERROR: missing "%EXE%"
  exit /b 1
)

"%EXE%" /install /silent
net start "SkupLink UPS SNMP Agent"
exit /b %ERRORLEVEL%
