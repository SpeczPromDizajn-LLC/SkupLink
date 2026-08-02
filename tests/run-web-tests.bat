@echo off
setlocal

cd /d "%~dp0web"

set "HTML_ID_MODE=fail"
set "LANG_UNUSED_MODE=fail"
set "CSS_UNUSED_MODE=fail"

echo Running SkupLink web UI tests in STRICT mode...
echo HTML_ID_MODE=%HTML_ID_MODE%
echo LANG_UNUSED_MODE=%LANG_UNUSED_MODE%
echo CSS_UNUSED_MODE=%CSS_UNUSED_MODE%
echo.

if not exist "node_modules\" (
  echo Installing npm dependencies if needed...
  call npm install
  if errorlevel 1 (
    echo npm install failed.
    exit /b 1
  )
  echo.
)

call npm test
if errorlevel 1 (
  echo.
  echo Strict web tests failed.
  exit /b 1
)

echo.
echo Strict web tests passed.
exit /b 0
