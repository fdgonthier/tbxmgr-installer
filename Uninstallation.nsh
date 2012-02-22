/* This script wraps file adds and logs them to a file. Upun uninstallation, 
the log file is read and only the files present in the log file are removed. */
  
; AddItem macro
!macro AddItem Path
 FileWrite $UninstLog "${Path}$\r$\n"
!macroend
!define AddItem "!insertmacro AddItem"
 
; File macro
!macro File FilePath FileName
  FileWrite $UninstLog "$OUTDIR\${FileName}$\r$\n"
  File "${FilePath}${FileName}"
!macroend
!define File "!insertmacro File"
 
; Copy files macro
!macro CopyFiles SourcePath DestPath
  FileWrite $UninstLog "${DestPath}$\r$\n"
  CopyFiles "${SourcePath}" "${DestPath}"
!macroend
!define CopyFiles "!insertmacro CopyFiles"
 
; Rename macro
!macro Rename SourcePath DestPath
   FileWrite $UninstLog "${DestPath}$\r$\n"
   Rename "${SourcePath}" "${DestPath}"
!macroend
!define Rename "!insertmacro Rename"
 
; CreateDirectory macro
!macro CreateDirectory Path
 CreateDirectory "${Path}"
 FileWrite $UninstLog "${Path}$\r$\n"
!macroend
!define CreateDirectory "!insertmacro CreateDirectory"
 
; SetOutPath macro
!macro SetOutPath Path
 SetOutPath "${Path}"
 FileWrite $UninstLog "${Path}$\r$\n"
!macroend
!define SetOutPath "!insertmacro SetOutPath"
 
; WriteUninstaller macro
!macro WriteUninstaller Path
 WriteUninstaller "${Path}"
 FileWrite $UninstLog "${Path}$\r$\n"
!macroend
!define WriteUninstaller "!insertmacro WriteUninstaller"