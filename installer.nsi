Unicode true
Name "Syncut Alpha 0.3"
OutFile "Syncut-Alpha-0.3-Windows-x64-Setup.exe"
InstallDir "$LOCALAPPDATA\Programs\Syncut"
RequestExecutionLevel user
SetCompressor /SOLID lzma
SetOverwrite on

!if /FileExists "dist\Syncut\syncut.ico"
  Icon "dist\Syncut\syncut.ico"
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
  Sleep 1200
!macroend

Section "Syncut"
  !insertmacro StopSyncutProcesses
  RMDir /r "$INSTDIR"
  Sleep 300
  SetOutPath "$INSTDIR"
  File /r "dist\Syncut\*.*"

  CreateDirectory "$SMPROGRAMS\Syncut"

  ; Use syncut.exe's compiled multi-resolution icon for Windows shortcuts.
  ; This avoids the tiny padded .ico that appeared in previous builds.
  CreateShortcut "$SMPROGRAMS\Syncut\Syncut.lnk" "$INSTDIR\bin\syncut.exe" "" "$INSTDIR\bin\syncut.exe" 0
  CreateShortcut "$DESKTOP\Syncut.lnk" "$INSTDIR\bin\syncut.exe" "" "$INSTDIR\bin\syncut.exe" 0

  WriteUninstaller "$INSTDIR\Uninstall.exe"

  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Syncut" "DisplayName" "Syncut Alpha 0.3"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Syncut" "DisplayVersion" "0.3"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Syncut" "Publisher" "Syncut"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Syncut" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Syncut" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Syncut" "DisplayIcon" "$INSTDIR\bin\syncut.exe"
SectionEnd

Section "Uninstall"
  !insertmacro StopSyncutProcesses
  Delete "$DESKTOP\Syncut.lnk"
  Delete "$SMPROGRAMS\Syncut\Syncut.lnk"
  RMDir "$SMPROGRAMS\Syncut"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Syncut"
  RMDir /r "$INSTDIR"
SectionEnd
