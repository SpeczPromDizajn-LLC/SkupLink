@echo off
setlocal EnableExtensions

cd /d "%~dp0"

set "SRC_WEB=..\SkupLinkService\web"
set "SRC_BIN=..\SkupLinkService\Linux64\Release\SkupLink"
set "SRC_CFG=..\SkupLinkService\config.example.json"

if not exist "%SRC_WEB%\" (
  echo ERROR: missing "%SRC_WEB%"
  exit /b 1
)

if not exist "%SRC_BIN%" (
  echo ERROR: missing "%SRC_BIN%"
  exit /b 1
)

if not exist "%SRC_CFG%" (
  echo ERROR: missing "%SRC_CFG%"
  exit /b 1
)

echo Updating web\
if exist "web\" rmdir /s /q "web"
mkdir "web" || exit /b 1
xcopy /e /i /y /q "%SRC_WEB%\*" "web\" >nul || exit /b 1

echo Updating SkupLink
copy /y "%SRC_BIN%" "SkupLink" >nul || exit /b 1

echo Updating config.example.json
copy /y "%SRC_CFG%" "config.example.json" >nul || exit /b 1

echo Done.
exit /b 0
