@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0delphi"

set "RSVARS="
if exist "%ProgramFiles(x86)%\Embarcadero\Studio\23.0\bin\rsvars.bat" set "RSVARS=%ProgramFiles(x86)%\Embarcadero\Studio\23.0\bin\rsvars.bat"
if not defined RSVARS if exist "%ProgramFiles(x86)%\Embarcadero\Studio\22.0\bin\rsvars.bat" set "RSVARS=%ProgramFiles(x86)%\Embarcadero\Studio\22.0\bin\rsvars.bat"
if not defined RSVARS (
  echo [ERROR] rsvars.bat not found. Install RAD Studio / Delphi or open SkupLinkTests.dproj in the IDE.
  exit /b 1
)

call "%RSVARS%"
if errorlevel 1 exit /b 1

set "PLATFORM=Win32"
msbuild SkupLinkTests.dproj /nologo /t:Build /p:Config=Debug /p:Platform=!PLATFORM!
if errorlevel 1 (
  echo.
  echo [WARN] Win32 build failed — retrying Win64 ^(common when DUnitX DCUs are Win64-only^).
  set "PLATFORM=Win64"
  msbuild SkupLinkTests.dproj /nologo /t:Build /p:Config=Debug /p:Platform=!PLATFORM!
  if errorlevel 1 (
    echo [ERROR] Build failed for Win32 and Win64.
    exit /b 1
  )
)

set "EXE=!PLATFORM!\Debug\SkupLinkTests.exe"
if not exist "!EXE!" (
  echo [ERROR] Expected executable not found: !EXE!
  exit /b 1
)

echo.
echo Running !EXE! ...
"!EXE!" %*
exit /b %ERRORLEVEL%
