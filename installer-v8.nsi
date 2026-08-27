Unicode true
Name "Syncut Alpha 0.1"
OutFile "Syncut-Alpha-0.1-Windows-x64-Setup.exe"
InstallDir "$LOCALAPPDATA\Programs\Syncut"
RequestExecutionLevel user
SetCompressor /SOLID lzma

!if /FileExists "dist\Syncut\syncut.ico"
  Icon "dist\Syncut\syncut.ico"
!endif

Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section "Syncut"
  SetOutPath "$INSTDIR"
  File /r "dist\Syncut\*.*"

  CreateDirectory "$SMPROGRAMS\Syncut"

!if /FileExists "dist\Syncut\syncut.ico"
  CreateShortcut "$SMPROGRAMS\Syncut\Syncut.lnk" "$INSTDIR\bin\syncut.exe" "" "$INSTDIR\syncut.ico" 0
  CreateShortcut "$DESKTOP\Syncut.lnk" "$INSTDIR\bin\syncut.exe" "" "$INSTDIR\syncut.ico" 0
!else
  CreateShortcut "$SMPROGRAMS\Syncut\Syncut.lnk" "$INSTDIR\bin\syncut.exe"
  CreateShortcut "$DESKTOP\Syncut.lnk" "$INSTDIR\bin\syncut.exe"
!endif

  WriteUninstaller "$INSTDIR\Uninstall.exe"

  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Syncut" "DisplayName" "Syncut Alpha 0.1"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Syncut" "DisplayVersion" "0.1"
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
  Delete "$DESKTOP\Syncut.lnk"
  Delete "$SMPROGRAMS\Syncut\Syncut.lnk"
  RMDir "$SMPROGRAMS\Syncut"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Syncut"
  RMDir /r "$INSTDIR"
SectionEnd
