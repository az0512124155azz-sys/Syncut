@echo off
setlocal EnableExtensions
chcp 65001 >nul
cls
echo ================================================================
echo                         SYNCUT ALPHA 0.1
echo                     Native Windows Build
echo ================================================================
echo.
echo This builds the REAL C++/Qt editor from source.
echo It does NOT install an AI model.
echo.
set "MSYS=C:\msys64\ucrt64.exe"
if not exist "%MSYS%" (
  echo MSYS2 UCRT64 was not found at C:\msys64.
  echo.
  where winget >nul 2>&1
  if errorlevel 1 (
    echo Install MSYS2 from https://www.msys2.org/ and run this file again.
    pause
    exit /b 1
  )
  choice /C YN /N /M "Install the MSYS2 build environment now? [Y/N]: "
  if errorlevel 2 exit /b 1
  winget install --id MSYS2.MSYS2 -e --accept-package-agreements --accept-source-agreements
  if not exist "%MSYS%" (
    echo MSYS2 installation was not found after winget completed.
    pause
    exit /b 2
  )
)

set "ROOT=%~dp0"
set "ROOT=%ROOT:\=/%"
"%MSYS%" -defterm -no-start -here -c "cd '%ROOT%' && bash ./build-syncut-msys2.sh"
if errorlevel 1 (
  echo.
  echo [ERROR] Native Syncut build failed. See the messages above.
  pause
  exit /b 3
)

echo.
echo Build finished.
echo Output: %~dp0dist\Syncut-Alpha-0.1-Windows.zip
pause
