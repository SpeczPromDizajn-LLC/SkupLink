@echo off
setlocal

cd /d "%~dp0contracts"

set "API_CONTRACT_MODE=fail"

echo Running SkupLink contract tests in STRICT mode...
echo API_CONTRACT_MODE=%API_CONTRACT_MODE%
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
  echo Strict contract tests failed.
  exit /b 1
)

echo.
echo Strict contract tests passed.
exit /b 0
