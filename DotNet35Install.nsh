# Written by AnarkiNet(AnarkiNet@gmail.com) originally, modified by eyal0 (for use in http://www.sourceforge.net/projects/itwister), hacked up by PSIMS APS MEDILINK 20090703 for dotnet 3.5
# Downloads and runs the Microsoft .NET Framework version 2.0 Redistributable and runs it if the user does not have the correct version.
# To use, call the macro with a string:
# 'CheckDotNET3Point5'
# All register variables are saved and restored by CheckDotNet
# No output


!macro CheckDotNET3Point5
  !define DOTNET_URL "http://download.microsoft.com/download/7/0/3/703455ee-a747-4cc8-bd3e-98a615c3aedb/dotNetFx35setup.exe"
  ${Trace} "Checking your .NET Framework version..."
  ;callee register save
  Push $0
  Push $1
  Push $2
  Push $3
  Push $4
  Push $5
  Push $6 ;backup of intsalled ver
  Push $7 ;backup of DoNetReqVer
  Push $8
 
  StrCpy $7 "3.5.0"
 
  loop:
  EnumRegKey $1 HKLM "SOFTWARE\Microsoft\NET Framework Setup\NDP" $8
  StrCmp $1 "" done ;jump to end if no more registry keys
  IntOp $8 $8 + 1
  StrCpy $0 $1
  goto loop
  done:
 
  ${If} $0 == 0
    ${Trace} ".NET Framework not found, download is required for program to run."
    Goto NoDotNET35
  ${EndIf}
 
  StrCpy $1 $0 1 1
 
  ${If} $1 > 3
    Goto NewDotNET35
  ${EndIf}
 
  StrCpy $2 $0 1 3
 
  ${If} $1 == 3
    ${If} $2 > 4
      Goto NewDotNET35
    ${EndIf}
  ${EndIf}
 
  StrCpy $3 $0 "" 5
 
  ${If} $3 == ""
    StrCpy $3 "0"
  ${EndIf}
 
  StrCpy $6 "$1.$2.$3"
 
  Goto OldDotNET35
 
 
  ${If} $0 < 0
    ${Trace} ".NET Framework Version found: $6, but is older than the required version: $7"
    Goto OldDotNET35
  ${Else}
    ${Trace} ".NET Framework Version found: $6, equal or newer to required version: $7."
    Goto NewDotNET35
  ${EndIf}
 
NoDotNET35:
    MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION \
    "This software requires .NET Framework $7 or greater. Click OK to install (this may take a few minutes)." \
    /SD IDOK IDOK DownloadDotNET35 IDCANCEL GiveUpDotNET35
    goto GiveUpDotNET35 ;IDCANCEL
OldDotNET35:
     MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION \
    "This software requires .NET Framework $7 or greater. Click OK to install (this may take a few minutes)." \
    /SD IDOK IDOK DownloadDotNET35 IDCANCEL GiveUpDotNET35
    goto GiveUpDotNET35 ;IDCANCEL
 
DownloadDotNET35:
  ${Trace} "Beginning download of latest .NET Framework version."
  NSISDL::download ${DOTNET_URL} "$PLUGINSDIR\dotNetFx35setup.exe"
  ${Trace} "Completed download."
  Pop $0
  ${If} $0 == "cancel"
     goto GiveUpDotNET35
  ${ElseIf} $0 != "success"
    MessageBox MB_YESNO|MB_ICONEXCLAMATION \
    "Download failed:$\n$R0$\n$\nWould you like to continue the installation anyway?" \
    /SD IDYES IDYES NewDotNET35 IDNO GiveUpDotNET35
  ${EndIf}
  
  ${Trace} "Pausing installation while downloaded .NET Framework installer runs."
  ${If} ${Silent} 
   ${Trace} "Installing .net silently."
    ExecWait '$PLUGINSDIR\dotNetFx35setup.exe /q /norestart' $0
  ${Else}
   ${Trace} "Installing .net normally."
    ExecWait '$PLUGINSDIR\dotNetFx35setup.exe /NORESTART' $0
  ${EndIf}
  
  ${If} $0 = 0
    ${Trace} ".Net framework installation successfull. No reboot required."
  ${ElseIf} $0 = 3010 
  ${OrIf} $0 = 1641
    ${Trace} ".Net framework installation successfull. Reboot will be required."
    SetRebootFlag true
  ${Else}
    ${Log} "1" "Error installing .Net framework. "  
     MessageBox MB_YESNO|MB_ICONEXCLAMATION \
    "Installation of the .Net Framework failed (return code $0).$\n$\nWould you like to continue the installation anyway?" \
    /SD IDNO IDYES NewDotNET IDNO GiveUpDotNET
  ${EndIf}  
  goto NewDotNet
 
GiveUpDotNET35:
  Abort "Installation cancelled by user."
 
NewDotNET35:
  DetailPrint "Proceeding with remainder of installation."
  Pop $0
  Pop $1
  Pop $2
  Pop $3
  Pop $4
  Pop $5
  Pop $6 ;backup of intsalled ver
  Pop $7 ;backup of DoNetReqVer
  Pop $8
 
!macroend