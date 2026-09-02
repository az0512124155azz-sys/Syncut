Unicode true
Name "Syncut 0.3.1"
OutFile "Syncut-0.3.1-Windows-x64-Setup.exe"
InstallDir "$LOCALAPPDATA\Programs\Syncut"
RequestExecutionLevel user
SetCompressor /SOLID lzma
SetOverwrite on

!if /FileExists "dist\Syncut\syncut.ico"
  Icon "dist\Syncut\syncut.ico"
  UninstallIcon "dist\Syncut\syncut.ico"
!endif

Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

!macro StopSyncutProcesses
  nsExec::ExecToLog 'taskkill /F /IM syncut.exe'
  nsExec::ExecToLog 'taskkill /F /IM kioworker.exe'
  nsExec::ExecToLog 'taskkill /F /IM kbuildsycoca6.exe'
  nsExec::ExecToLog 'taskkill /F /IM kdenlive_render.exe'
  nsExec::ExecToLog 'taskkill /F /IM melt.exe'
  nsExec::ExecToLog 'taskkill /F /IM melt-7.exe'
  nsExec::ExecToLog 'taskkill /F /IM ffmpeg.exe'
  nsExec::ExecToLog 'taskkill /F /IM ffprobe.exe'
  nsExec::ExecToLog 'taskkill /F /IM ffplay.exe'
  Sleep 1200
!macroend

Section "Syncut" SecMain
  SetShellVarContext current
  !insertmacro StopSyncutProcesses
  RMDir /r "$INSTDIR"
  Sleep 300
  SetOutPath "$INSTDIR"
  File /r "dist\Syncut\*.*"

  CreateDirectory "$SMPROGRAMS\Syncut"
!if /FileExists "dist\Syncut\syncut.ico"
  CreateShortcut "$SMPROGRAMS\Syncut\Syncut.lnk" "$INSTDIR\bin\syncut.exe" "--no-welcome" "$INSTDIR\syncut.ico" 0
  CreateShortcut "$DESKTOP\Syncut.lnk" "$INSTDIR\bin\syncut.exe" "--no-welcome" "$INSTDIR\syncut.ico" 0
!else
  CreateShortcut "$SMPROGRAMS\Syncut\Syncut.lnk" "$INSTDIR\bin\syncut.exe" "--no-welcome"
  CreateShortcut "$DESKTOP\Syncut.lnk" "$INSTDIR\bin\syncut.exe" "--no-welcome"
!endif

  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Syncut" "DisplayName" "Syncut 0.3.1"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Syncut" "DisplayVersion" "0.3.1"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Syncut" "Publisher" "Syncut"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Syncut" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Syncut" "UninstallString" '"$INSTDIR\Uninstall.exe"'
!if /FileExists "dist\Syncut\syncut.ico"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Syncut" "DisplayIcon" "$INSTDIR\syncut.ico"
!else
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Syncut" "DisplayIcon" "$INSTDIR\bin\syncut.exe"
!endif
SectionEnd

Section "Uninstall"
  SetShellVarContext current
  !insertmacro StopSyncutProcesses
  Delete "$DESKTOP\Syncut.lnk"
  Delete "$SMPROGRAMS\Syncut\Syncut.lnk"
  RMDir "$SMPROGRAMS\Syncut"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Syncut"
  RMDir /r "$INSTDIR"
SectionEnd
