/****************************************************************************
  Copyright (c) 2005-2012 Opersys Inc.  All Rights Reserved
 ***************************************************************************/

Name "Teambox Manager"
BrandingText $(^Name)

# General Symbol Definitions
!define TeamboxRegKey "SOFTWARE\Teambox"
!define KwmRegKey "${TeamboxRegKey}\$(^Name)"
!define StartMenuGroup "Teambox Manager"
!define TBX_INSTALLER_VER ${base_ver}.${minor_ver}
!define UninstLog "uninstall.log" # file from which the uninstaller must read to remove the right files.

# Temporary.
#SetCompress off

SetCompressor /SOLID lzma
# Used for Uninstallation.nsh macros.
Var UninstLog

/* Code to increment the minor version automatically. To start from 0, 
   remove the minor_rev line from the file. */
!define verfile "tbx-installer-version.txt"
!include /NonFatal "${verfile}"

!ifndef base_ver
    !define base_ver "1.0" ;if we have no previous number
!endif

!ifndef minor_ver
    !define minor_ver 0 ;if we have no previous number
!endif

!define /math next_minor_ver ${minor_ver} + 1

!delfile "${verfile}"
!appendfile "${verfile}" "!define base_ver ${base_ver}$\n"
!appendfile "${verfile}" "!define minor_ver ${next_minor_ver}"

/* Location of various installer files.*/
# Icons, images, etc.
!define ResDir "Resources"
# Files to deploy.
!define FilesDir "Files"
# Compilation output.
!define OutputDir "Installers"

# MUI Symbol Definitions
!define MUI_ICON ${ResDir}\Teambox.ico
!define MUI_UNICON ${ResDir}\Teambox.ico
!define MUI_LANGDLL_REGISTRY_ROOT HKLM
!define MUI_LANGDLL_REGISTRY_KEY ${KwmRegKey}
!define MUI_LANGDLL_REGISTRY_VALUENAME InstallerLanguage

# Annoying MUI already defines .onUserAbort and un.onUserAbort callbacks. 
# Workaround provided by the MUI framework. 
!define MUI_CUSTOMFUNCTION_ABORT "onAbortCustomFunction"
!define MUI_CUSTOMFUNCTION_UNABORT "un.onUnAbortCustomFunction"

/* NSIS includes */
!include Sections.nsh
!include MUI2.nsh
!include LogicLib.nsh

# Reserved Files
!insertmacro MUI_RESERVEFILE_LANGDLL

# Installer pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE ${ResDir}\license.rtf
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES

    # These indented statements modify settings for MUI_PAGE_FINISH
    !define MUI_FINISHPAGE_RUN
    !define MUI_FINISHPAGE_RUN_CHECKED
    !define MUI_FINISHPAGE_RUN_TEXT "Launch $(^Name) now."
    !define MUI_FINISHPAGE_RUN_FUNCTION ExecKwm
 !insertmacro MUI_PAGE_FINISH
  
!define MUI_ABORTWARNING
!define MUI_ABORTWARNING_CANCEL_DEFAULT

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

# Installer languages
!insertmacro MUI_LANGUAGE English
!insertmacro MUI_LANGUAGE French

# Include Teambox utility functions and other plugins.. 
!include UtilityFunctions.nsh
!include DotNetInstall.nsh
!include DotNet35Install.nsh
!include Strings.nsh # LangStrings for user messages.
!include Uninstallation.nsh
!include FileAssoc.nsh
!include Library.nsh

# Installer attributes
OutFile "${OutputDir}\Teambox Manager ${TBX_INSTALLER_VER}.exe"
InstallDir "$PROGRAMFILES\Teambox\Teambox Manager"
InstallDirRegKey HKLM "${KwmRegKey}" "InstallDir"
CRCCheck on
XPStyle on
ShowInstDetails show
ShowUninstDetails show

/* Required for the UAC plugin.*/
RequestExecutionLevel user 

AutoCloseWindow true

# Variables

/* Outlook installation status. 
0 if not installed
1 if 2003 is installed
2 if 2007 is installed. */ 
var OutlookInstallation

/* This is the main section of the installer. Make appropriate sanity 
   verifications, uninstall old software, but do not install anything 
   yet. */
Section -Main SEC0000
    # OutlookInstallation is set in .onInit.
    
    # FIXME: implement a way to close the running applications. It is not trivial since they
    # can run in different sesions (Terminal Server / Citrix). LockList plugin might work.
    
    /* Check if Outlook or Teambox Manager are running. If running and the installer is in
      silent mode, cancel the installation. If running and the installer is not silent, 
      prompt a warning to close the program before continuing the installation. */
    call BlockUntilSoftwareIsClosed
    
    # Check if a legacy kpp-mso program is installed. If we find one, 
    # uninstall it automatically and fall through.
    ReadRegStr $0 HKLM "Software\teambox\kpp-mso" "Installer_Version"
    ${If} $0 != ""
        ${Trace} "Legacy plugin detected. Attemping uninstallation."
        ; Got some version. Uninstall stale program.
        ReadRegStr $1 HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\kpp-mso-2k3" "UninstallString"
        
        ${If} $1 S== ""
            ReadRegStr $1 HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\kpp-mso-2k7" "UninstallString"
        ${EndIf}
        
        ${If} $1 S!= ""
            ; Force the uninstaller to not spawn itself to a temp dir so
            ; that ExecWait really waits for something instead of returning
            ; very early.
            ReadRegStr $0 HKLM "Software\teambox\kpp-mso" "Install_Dir"
        
            ; Always uninstall legacy software silently.    
            ${Trace} "Uninstalling: $1 /S _?=$0"
            ExecWait "$1 /S _?=$0" $1
            
            # Check if the uninstallation was successfull.
            ${If} $1 != "0"
                ${Log} "1" "Uninstallation failed: uninstall.exe returned $1."
                MessageBox MB_OK|MB_ICONEXCLAMATION|MB_SETFOREGROUND $(UninstError) /SD IDOK
                goto cancelInstallation
            ${EndIf}

            Delete "$1"
            RmDir /r $0
            ${Trace} "Deletion of the legacy uninstaller successfull."
            
        ${Else}
            ${Log} "1" "Could not find the path to uninstall.exe. Aborting." 
            MessageBox MB_OK|MB_ICONEXCLAMATION|MB_SETFOREGROUND $(UninstError) /SD IDOK
            goto cancelInstallation
        ${EndIf}
    ${Else}
        ${Trace} "No legacy software detected. Carrying on."
    ${EndIf}

    # Check for a previous version of the non-legacy tbxmngr-installer.
    ReadRegStr $0 HKLM "${KwmRegKey}" "InstallVersion"
   
    ${If} $0 == ""
        # No previous version of the non-legacy software found, carry on.
        ${Trace} "No older non-legacy software found. Carrying on."
        goto postCheckVersion
    ${EndIf}
    
    ${VersionCompare} ${TBX_INSTALLER_VER} $0 $R0
    
    ${Trace} "Detected a non-legacy software installed. Installed version: $0."
    
    ${If} $R0 = 0
        # Versions are equal. Automatically reinstall (without uninstalling) if silent, prompt otherwise.
        ${Trace} "Reinstalling the same version of $(^Name)."
        # Automatically proceed to installation, no questions asked.
        goto postCheckVersion
        
    ${ElseIf} $R0 == 1
        # Current version is newer."
        ReadRegStr $1 HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)" "UninstallString"
        ${If} $1 != ""
            # Force the uninstaller to not spawn itself to a temp dir so
            # that ExecWait really waits for something instead of returning
            # very early. Also make sure to pass /F so that the uninstaller 
            # does not call any Delete with /REBOOTOK.
            ReadRegStr $0 HKLM "${KwmRegKey}" "InstallDir"
            ${Trace} "Uninstalling older version ($0) of $(^Name) by calling $1 /S /F _?=$0."
            ExecWait "$1 /S /F _?=$0" $2
            
            # Check if the uninstallation was successfull.
            ${If} $2 != "0"
                ${Log} "1" "Uninstallation failed: uninstall.exe returned $2."
                MessageBox MB_OK|MB_ICONEXCLAMATION|MB_SETFOREGROUND $(UninstError) /SD IDOK
                goto cancelInstallation
            ${EndIf}
            
            # Manually delete the uninstaller to make sure it is removed.
            ${Trace} "Deleting the previous version's uninstaller..."
            Delete "$1"
            
        ${Else}
            ${Trace} "Could not find the path to uninstall.exe. Aborting."
            MessageBox MB_OK|MB_ICONSTOP|MB_SETFOREGROUND $(UninstError) /SD IDOK
            goto cancelInstallation
        ${EndIf}
          
     
    ${ElseIf} $R0 == 2
            ${Log} "1" "Existing version $0 of $(^Name) is newer than the one you are trying to install (${TBX_INSTALLER_VER}). Unable to continue."
            MessageBox MB_OK|MB_ICONEXCLAMATION|MB_SETFOREGROUND $(UninstErrorNewer) /SD IDOK
            goto cancelInstallation
    ${EndIf}
    
    postCheckVersion:
  
    # Prepare the uninstall log file stuff. Do not call this before uninstalling the previous versions
    # have been done: uninstallation will not be able to delete the uninstall.log file since we are
    # opening it right now. 
    CreateDirectory "$INSTDIR"
    IfFileExists "$INSTDIR\${UninstLog}" +3
    FileOpen $UninstLog "$INSTDIR\${UninstLog}" w
    Goto +4
    SetFileAttributes "$INSTDIR\${UninstLog}" NORMAL
    FileOpen $UninstLog "$INSTDIR\${UninstLog}" a
    FileSeek $UninstLog 0 END
    
    # Check if the appropriate .Net framework is installed on the target computer. If this fails,
    # carry on as normal. The user will see the problem later on.
    
    # FIXME some day: unify the check and use the right method through the registry.
    ${If} $OutlookInstallation == 0
        !insertmacro CheckDotNET "2.0" 
    ${Else}
        !insertmacro CheckDotNET3Point5
    ${EndIf}
    
    WriteRegStr HKLM "${KwmRegKey}\Components" Main 1
    goto normalEnd
    
    cancelInstallation:
        Abort
    normalEnd:
SectionEnd

/* Mandatory section: install Teambox Manager. */
Section -TeamboxManager SEC0001
    ${Trace} "-TeamboxManager section called."
    
    SetOverwrite on
    SetOutPath $INSTDIR
    ${File} "${FilesDir}\kwm\" release-notes.txt
    ${File} "${FilesDir}\kwm\" release-notes-en.txt
    ${File} "${ResDir}\" userguide.pdf
    ${File} "${ResDir}\" quickstart.pdf
    
    # KMOD files
    ${SetOutPath} "$INSTDIR\kmod"
    ${File} "${FilesDir}\kmod\" cryptoeay32-0.9.8.dll
    ${File} "${FilesDir}\kmod\" kmod.exe
    ${File} "${FilesDir}\kmod\" libgcrypt.dll
    ${File} "${FilesDir}\kmod\" libgpg-error-0.dll
    ${File} "${FilesDir}\kmod\" OPENSSL_LICENSE.txt
    ${File} "${FilesDir}\kmod\" sqlite3.dll
    ${File} "${FilesDir}\kmod\" ssleay32-0.9.8.dll
    
    #KWM files
    SetOutPath $INSTDIR
    ${File} "${FilesDir}\kwm\" CpGetOpt.dll
    ${File} "${FilesDir}\kwm\" TbxUtils.dll
    ${File} "${FilesDir}\kwm\" XpTabControl.dll
    ${File} "${FilesDir}\kwm\" kwm.exe
    ${File} "${FilesDir}\kwm\" kwm.exe.config
    ${File} "${FilesDir}\kwm\" KwmAppControls.dll
    ${File} "${FilesDir}\kwm\" System.Data.SQLite.DLL
    ${File} "${FilesDir}\kwm\" Wizard.Controls.dll
    ${File} "${FilesDir}\kwm\" Wizard.UI.dll
    
    # VNC files
    ${SetOutPath} "$INSTDIR\vnc"
    ${File} "${FilesDir}\vnc\" kappserver.exe
    ${File} "${FilesDir}\vnc\" kappviewer.exe
    ${File} "${FilesDir}\vnc\" VNCHooks.dll
    
    # ktlstunnel files
    ${SetOutPath} "$INSTDIR\ktlstunnel"
    ${File} "${FilesDir}\ktlstunnel\" ktlstunnel.exe
    ${File} "${FilesDir}\ktlstunnel\" libgcrypt-11.dll
    ${File} "${FilesDir}\ktlstunnel\" libgnutls-26.dll
    ${File} "${FilesDir}\ktlstunnel\" libgpg-error-0.dll
    ${File} "${FilesDir}\ktlstunnel\" libtasn1-3.dll
    ${File} "${FilesDir}\ktlstunnel\" pthreadGC2.dll
    
    ; Set KWM running at windows startup
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Run" "TeamboxManager" "$INSTDIR\kwm.exe"
  
   !define VncRegKey "${KwmRegKey}\vnc\server"
    ; Set VNC registries
    WriteRegDWORD HKLM ${VncRegKey} "ConnectPriority" "00000002"
    WriteRegDWORD HKLM ${VncRegKey} "LoopbackOnly" "00000001"
    WriteRegDWORD HKLM ${VncRegKey} "EnableHTTPDaemon" "00000000"
    WriteRegDWORD HKLM ${VncRegKey} "AllowLoopback" "00000001"
    WriteRegDWORD HKLM ${VncRegKey} "AuthRequired" "00000000"
    WriteRegDWORD HKLM ${VncRegKey} "DebugMode" "00000000"
    WriteRegDWORD HKLM ${VncRegKey} "DebugLevel" "00000000"
    WriteRegDWORD HKLM ${VncRegKey} "DisableTrayIcon" "00000001"

    ; These override what is in CurrentUser
    WriteRegDWORD HKLM "${VncRegKey}\Default" "InputsEnabled" "00000000"
    WriteRegBin   HKLM "${VncRegKey}\Default" "Password" "5AB2CDC0BADCAF13"
    WriteRegBin   HKLM "${VncRegKey}\Default" "PasswordViewOnly" "5AB2CDC0BADCAF13"
    WriteRegDWORD HKLM "${VncRegKey}\Default" "PollFullScreen" "00000001"
    WriteRegDWORD HKLM "${VncRegKey}\Default" "RemoveWallpaper" "00000000"
  
    WriteRegStr HKLM "${KwmRegKey}\Components" TeamboxManager 1

    ; Save a GUID, used for statistics gathering when checking software updates.
    Call CreateGUID
    pop $0    
    WriteRegStr HKLM "${KwmRegKey}" InstallationGUID $0
SectionEnd

/* Optional section: install Teambox Outlook Connector if Microsoft Outlook has been found. */
Section /o -OutlookConnector SEC0002
    ${Trace} "-OutlookConnector section called."
    SetOutPath $INSTDIR
    SetOverwrite on
    ${File} "${FilesDir}\otc\" adxloader.dll
    ${File} "${FilesDir}\otc\" adxloader.dll.manifest
    ${File} "${FilesDir}\otc\" TeamboxOutlookConnector.dll
    ${File} "${FilesDir}\otc\" TeamboxOutlookNative.dll
    
    ${File} "${FilesDir}\otc\StaticIncludes\" AddinExpress.MSO.2005.dll
    ${File} "${FilesDir}\otc\StaticIncludes\" AddinExpress.OL.2005.dll
    ${File} "${FilesDir}\otc\StaticIncludes\" extensibility.dll
    ${File} "${FilesDir}\otc\StaticIncludes\" Interop.Office.dll
    ${File} "${FilesDir}\otc\StaticIncludes\" Office.dll
    ${File} "${FilesDir}\otc\StaticIncludes\" Interop.VBIDE.dll
    ${File} "${FilesDir}\otc\StaticIncludes\" Microsoft.Office.Interop.Outlook.dll
    ${File} "${FilesDir}\otc\StaticIncludes\" AddinExpress.MAPI.dll
    
    # Load the adx shim loader.
    !define LIBRARY_COM
    ${Trace} "Loading COM addin..."
    ClearErrors 
    !insertmacro InstallLib REGDLL NOTSHARED REBOOT_NOTPROTECTED "${FilesDir}\otc\adxloader.dll" $INSTDIR\adxloader.dll $INSTDIR
    ${If} ${Errors} 
       ${Trace} "Registration failed. Diagnostic logs are available in the file adxloader.log located in the installation directory."
    ${Else}
       ${Trace} "Registration successfull."
    ${EndIf}

    ${Trace} "Loading native helper outlook library..."
    ClearErrors
    nsExec::ExecToStack 'regsvr32.exe /s "$INSTDIR\TeamboxOutlookNative.dll"'
    Pop $R0
    ${Trace} "Result: $R0. If you are seeing |error|, the dll file was not found. Otherwise, its the return value of the registration."
    WriteRegStr HKLM "${KwmRegKey}\Components" OutlookConnector 1
SectionEnd

/* Executed before the Main Section. This code is located after the sections
   block because it refers to the SEC0002 define.
  This is used to:
   - Check admin privileges
   - Initialize the uninstall.log stuff
   - Register our Windows event log (extracted files are automatically cleanup)
   - Check Outlook version, if any, and select the right section to execute. */
Function .onInit
    # If we are silent, just test for admin privileges. If not admin, abort.
    ${If} ${Silent}
        Uac::IsAdmin
        ${If} $0 = 0
            ${Log} "1" "This software requires administrator privileges. The installation will abort."
            Abort
        ${Else}
            ${Trace} "Silent installer has sufficient privileges to continue."
        ${EndIf}
    ${EndIf}

   /* UAC plugin routine. This attempts to elevate priviledges to Administrator.
   Note: this can cause the installer to close and respawn using a different 
   set of user credentials, thus causing what seems to be reentrance. Make 
   sure any code that must be called only once (such as language selection) 
   comes AFTER this call.
   This should never prompt in silent mode since if we're silent and not an admin, 
   we should've aborted. */
   !insertmacro ElevatePrivs

   InitPluginsDir

   # Extract the helper program and the event log message dll to a temporary
   # folder that will automatically be cleaned up at the end of the installer.
   !insertmacro RegisterEventMngr "1"
   
   # Elevate our privileges just a bit by setting the SeDebugPrivilege token to our process.
   # This is required in order to get the process list and check to see if the KWM or Outlook
   # is running.
   !insertmacro SetDebugPrivs
   
   ${Trace} "$(^Name) installer initializing after privilege requirements have been met."
    
    !insertmacro MUI_LANGDLL_DISPLAY
    
    # Select SEC0002 if Microsoft Outlook is installed on this computer.
    Call CheckOutlookPresence
    pop $OutlookInstallation
    ${If} $OutlookInstallation S!= "0"
        ${Trace} "Outlook installation detected ($OutlookInstallation). Selecting the installation section for execution."
        !insertmacro SelectSection ${SEC0002}
    ${EndIf}
FunctionEnd

/* Always executed after all the required and optional sections have been executed.
   We set the global registry informations related to our software, as well as the
   unintaller informations. */ 
Section -post
    ${Trace} "Post-installation executing."
    # Write installation directory and version in the registry. 
    WriteRegStr HKLM "${KwmRegKey}" "InstallDir" $INSTDIR
    WriteRegStr HKLM "${KwmRegKey}" "InstallVersion" ${TBX_INSTALLER_VER}
    
    SetOutPath $INSTDIR
    ${WriteUninstaller} $INSTDIR\uninstall.exe
    
    # Create shortcuts for all users. A wildcard delete takes care of
    # removing all of them in the uninstaller.
    SetShellVarContext all
    CreateDirectory "$SMPROGRAMS\${StartMenuGroup}"
    CreateShortcut "$SMPROGRAMS\${StartMenuGroup}\$(^Name).lnk" $INSTDIR\kwm.exe
    
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)" DisplayName "$(^Name)"
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)" DisplayIcon $INSTDIR\uninstall.exe
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)" UninstallString $INSTDIR\uninstall.exe
    WriteRegDWORD HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)" NoModify 1
    WriteRegDWORD HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)" NoRepair 1
    
    # Write the event log handler "permanently".
    ${File} "${FilesDir}\" "EventSourceMngr.exe"
    ${File} "${FilesDir}\" "TbxMngrEventId.dll"
    WriteRegStr HKLM "SYSTEM\CurrentControlSet\Services\Eventlog\Application\TeamboxManager" EventMessageFile "$INSTDIR\TbxMngrEventId.dll"
    
    # Setup windows firewall
    !insertmacro PunchWindowsFw
    
    # Register .wsl file type to us.
    !insertmacro APP_ASSOCIATE "wsl" "Teambox.TeamboxFile" "Teambox Manager File" "$INSTDIR\kwm.exe,0" "Open this Teambox" "$INSTDIR\kwm.exe $\"-i$\" $\"%1$\""
    !insertmacro APP_ASSOCIATE "tbx" "Teambox.TeamboxFile" "Teambox Manager File" "$INSTDIR\kwm.exe,0" "Open this Teambox" "$INSTDIR\kwm.exe $\"-i$\" $\"%1$\""
    !insertmacro UPDATEFILEASSOC
SectionEnd

Section -closelogfile
 FileClose $UninstLog
 SetFileAttributes "$INSTDIR\${UninstLog}" READONLY|SYSTEM|HIDDEN
SectionEnd
 
Function .OnInstFailed
    ${Log} "1" "Installation failed."
    !insertMacro InstallationEnd
FunctionEnd
 
Function .OnInstSuccess
    ${Trace} "Installation succeeded."
    !insertMacro InstallationEnd
FunctionEnd

# Cannot use .onUserAbort callback since it is already defined by the MUI plugin. 
# See the "!define <...> onAbortCustomFunction" at the top of this file.  
Function onAbortCustomFunction
    ${Log} "1" "Installation aborted by the user."
    !insertMacro InstallationEnd
FunctionEnd

/******************************************************************************
                         UNINSTALLER BLOCK 
 *****************************************************************************/
 
# If the uninstaller is called with /F, do not force deletion of files after
# reboot. The /F flag is set when performing an uninstallation from the
# installer itself.
var /GLOBAL RebootFlag
!define DelFile "!insertmacro DeleteFile "
!macro DeleteFile FilePath
    ${If} $RebootFlag == "/REBOOTOK"
        ${Trace} "Calling Delete /REBOOTOK ${FilePath}" 
        Delete /REBOOTOK '${FilePath}'
    ${Else} 
        ${Trace} "Calling Delete ${FilePath}"
        Delete '${FilePath}'
    ${EndIf}
!macroend

!define DelDir "!insertmacro DeleteDir "
!macro DeleteDir DirPath
    ${If} $RebootFlag == "/REBOOTOK"
        ${Trace} "Calling RmDir /REBOOTOK ${DirPath}"
        RmDir /REBOOTOK '${DirPath}'
    ${Else}
        ${Trace} "Calling RmDir ${DirPath}"
        RmDir '${DirPath}'
    ${EndIf}
!macroend

Function un.onInit 
    # Make sure the user has the appropriate privileges to perform the 
    # uninstallation.
    ; Check if the user is administrator
    userInfo::getAccountType ; Get user info and puts the result in the stack
  
    pop $0
    ; compare the result with the string "Admin" to see if the user is admin.
    ${If} $0 != "Admin"
      ${Trace} "User is not admin. Aborting."
      ; User doesn't have admin rights
      MessageBox MB_OK|MB_ICONSTOP $(NotAnAdminPermFail) /SD IDOK
      Quit
    ${EndIf}
        
    ${Trace} "User is admin, begin uninstallation."
    ReadRegStr $INSTDIR HKLM "${KwmRegKey}" "InstallDir"
    !insertmacro MUI_UNGETLANGUAGE
FunctionEnd

Section Uninstall
    Call un.BlockUntilSoftwareIsClosed
    
    # Check if we must force the deletion of files with the /REBOOTOK flag.
    Call un.ReqForceDeletion
    StrCpy $RebootFlag $0 

    ${Trace} "Read reboot flag: $0."

    # Check wether or not the OTC was installed. If so, unregister the DLL.
    Push $R0
    ReadRegStr $R0 HKLM "${KwmRegKey}\Components" "OutlookConnector"
    ${If} $R0 == 1
        ${Trace} "Detected OTC, attempting unregistration." 
        # DO NOT USE !insertmacro UninstallLib. This makes the uninstaller executable retain the various
        # plugin DLLs in memory and forces a reboot. Calling regsvr32.exe directly avoids this issue.
        # /u: uninstall, /s: silent (no dialog boxes)
        nsExec::ExecToStack 'regsvr32.exe /u /s "$INSTDIR\adxloader.dll"'
        Pop $R0
        ${Trace} "Result: $R0. If you are seeing |error|, the dll file was not found. Otherwise, its the return value of the unregistration."
        
        nsExec::ExecToStack 'regsvr32.exe /u /s "$INSTDIR\TeamboxOutlookNative.dll"'
        Pop $R0
        ${Trace} "Result: $R0. If you are seeing |error|, the dll file was not found. Otherwise, its the return value of the unregistration."
    ${Else}
        ${Trace} "Did not find OTC installed. Skipping DLL unregistration." 
    ${EndIf}
    Pop $R0
    
    ; Delete all files that were copied during the installation.
    ${Unless} ${FileExists} $INSTDIR\${UninstLog}
        ${Log} "1" "$(UninstLogMissing)"
        MessageBox MB_OK|MB_ICONSTOP "$(UninstLogMissing)" /SD IDOK
        Abort
    ${EndIf}

    Push $R0
    Push $R1
    Push $R2
    SetFileAttributes "$INSTDIR\${UninstLog}" NORMAL
    FileOpen $UninstLog "$INSTDIR\${UninstLog}" r
    StrCpy $R1 0
 
  GetLineCount:
    ClearErrors
    FileRead $UninstLog $R0
    IntOp $R1 $R1 + 1
    IfErrors 0 GetLineCount
   
  LoopRead:
    FileSeek $UninstLog 0 SET
    StrCpy $R2 0
       
  FindLine:
    FileRead $UninstLog $R0
    IntOp $R2 $R2 + 1
    StrCmp $R1 $R2 0 FindLine
 
    StrCpy $R0 $R0 -2
    
    # This is how we test if some path is a file or a directory.
    ${If} ${FileExists} "$R0\*.*"
        ${DelDir} $R0
    ${Else}
        ${If} ${FileExists} $R0
            ${DelFile} $R0
        ${EndIf}            
    ${EndIf}
    
    IntOp $R1 $R1 - 1
    StrCmp $R1 0 LoopDone
    Goto LoopRead
       
  LoopDone:
    FileClose $UninstLog
    ${DelFile} "$INSTDIR\${UninstLog}"
    ${DelFile} "$INSTDIR\adxloader.log"
    
    # Do not force removal of instdir since the user might have installed directly in C:\Program Files. 
    # You don't want to wipe his entire drive.
    
    # Attempt to remove the installation directory (Usually Program Files\Teambox\Teambox Manager)
    RmDir "$INSTDIR"
    # Attempt to remove the installation's parent directory (Usually Program Files\Teambox)
    RMDir "$INSTDIR\.."
    
    Pop $R2
    Pop $R1
    Pop $R0       
SectionEnd

/* Always executed after all the required and optional sections have been executed.
   Undo what is in the -post section.*/
Section -un.post
    ${Trace} "un.Post called." 
  
    DeleteRegKey HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)"
    DeleteRegKey HKLM "SYSTEM\CurrentControlSet\Services\Eventlog\Application\TeamboxManager\EventMessageFile"
    DeleteRegKey /IfEmpty HKLM "SYSTEM\CurrentControlSet\Services\Eventlog\Application\TeamboxManager"
            
    SetShellVarContext all
    ${DelFile} "$SMPROGRAMS\${StartMenuGroup}\*"
    ${DelDir} "$SMPROGRAMS\${StartMenuGroup}\"
    
    DeleteRegValue HKLM "${KwmRegKey}" "InstallDir"
    DeleteRegValue HKLM "${KwmRegKey}" "InstallVersion"
    
    DeleteRegKey HKLM "${KwmRegKey}\vnc"
    
    DeleteRegKey /IfEmpty HKLM "${KwmRegKey}\Components"
    DeleteRegKey /IfEmpty HKLM "${KwmRegKey}"
    DeleteRegKey /IfEmpty HKLM "${TeamboxRegKey}"

    !insertmacro UnpunchWindowsFw

    !insertmacro APP_UNASSOCIATE "wsl" "Teambox.TeamboxFile"
    !insertmacro APP_UNASSOCIATE "tbx" "Teambox.TeamboxFile"
    !insertmacro UPDATEFILEASSOC

    Push $R0
    StrCpy $R0 $StartMenuGroup 1
    StrCmp $R0 ">" no_smgroup
no_smgroup:
    Pop $R0
SectionEnd

Function un.OnUninstFailed
    !insertMacro InstallationEnd
FunctionEnd
 
Function un.OnUninstSuccess
    !insertMacro InstallationEnd
FunctionEnd

# Cannot use un.onUserAbort callback since it is already defined by the MUI plugin.   
Function un.onUnAbortCustomFunction
    !insertMacro InstallationEnd
FunctionEnd