@echo off
setlocal EnableExtensions
chcp 65001 >nul
set "SRC=%~dp0dist\Syncut-Alpha-0.1"
set "EXE=%SRC%\bin\syncut.exe"
set "DEST=%LOCALAPPDATA%\Programs\Syncut"

if not exist "%EXE%" (
  echo [ERROR] Native syncut.exe was not found.
  echo Build it first with Build-Syncut-Windows.cmd.
  echo No HTML preview will be installed.
  pause
  exit /b 1
)

if exist "%DEST%" rmdir /S /Q "%DEST%"
mkdir "%DEST%" >nul 2>&1
xcopy "%SRC%\*" "%DEST%\" /E /I /H /Y >nul
if errorlevel 1 (
  echo [ERROR] Failed to copy Syncut files.
  pause
  exit /b 2
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ws=New-Object -ComObject WScript.Shell;" ^
 "$s=$ws.CreateShortcut([Environment]::GetFolderPath('Desktop')+'\Syncut.lnk');" ^
 "$s.TargetPath='%DEST%\bin\syncut.exe';$s.WorkingDirectory='%DEST%\bin';$s.IconLocation='%DEST%\bin\syncut.exe,0';$s.Save();" ^
 "$sm=[Environment]::GetFolderPath('StartMenu')+'\Programs\Syncut.lnk';$s2=$ws.CreateShortcut($sm);$s2.TargetPath='%DEST%\bin\syncut.exe';$s2.WorkingDirectory='%DEST%\bin';$s2.IconLocation='%DEST%\bin\syncut.exe,0';$s2.Save()"

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Syncut" /v DisplayName /d "Syncut Alpha 0.1" /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Syncut" /v InstallLocation /d "%DEST%" /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Syncut" /v DisplayIcon /d "%DEST%\bin\syncut.exe" /f >nul

echo.
echo Syncut Alpha 0.1 installed successfully.
echo %DEST%\bin\syncut.exe
start "" "%DEST%\bin\syncut.exe"
