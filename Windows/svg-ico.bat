@echo off
setlocal
cd /d "%~dp0svg-ico"

if not exist "node_modules\" (
  echo Installing npm dependencies...
  call npm install
  if errorlevel 1 exit /b 1
)

node svg-to-ico.mjs "..\..\SkupLinkService\web\favicon.svg" "..\SkupLink.ico" %*
if errorlevel 1 exit /b 1

echo.
echo Done: %~dp0SkupLink.ico
endlocal
