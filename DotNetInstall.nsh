# DotNET version checking macro.
# Written by AnarkiNet(AnarkiNet@gmail.com) originally, modified by eyal0 (for use in http://www.sourceforge.net/projects/itwister)
# Downloads and runs the Microsoft .NET Framework version 2.0 Redistributable and runs it if the user does not have the correct version.
# To use, call the macro with a string:
# !insertmacro CheckDotNET "2"
# !insertmacro CheckDotNET "2.0.9"
# (Version 2.0.9 is less than version 2.0.10.)
# All register variables are saved and restored by CheckDotNet
# No output

!macro CheckDotNET DotNetReqVer
  !define BASE_URL http://download.microsoft.com/download
  !define v2_URL "${BASE_URL}/5/6/7/567758a3-759e-473e-bf8f-52154438565a/dotnetfx.exe"
                    
  DetailPrint "Checking your .NET Framework version..."
  ;callee register save
  Push $0
  Push $1
  Push $2
  Push $3
  Push $4
  Push $5
  Push $6 ;backup of intsalled ver
  Push $7 ;backup of DoNetReqVer

  StrCpy $7 ${DotNetReqVer}

  System::Call "mscoree::GetCORVersion(w .r0, i ${NSIS_MAX_STRLEN}, *i r2r2) i .r1 ?u"

  ${If} $0 == 0
  	DetailPrint ".NET Framework not found, download is required for program to run."
    Goto NoDotNET
  ${EndIf}

  ;at this point, $0 has maybe v2.345.678.
  StrCpy $0 $0 $2 1 ;remove the starting "v", $0 has the installed version num as a string
  StrCpy $6 $0
  StrCpy $1 $7 ;$1 has the requested verison num as a string

  ;now let's compare the versions, installed against required <part0>.<part1>.<part2>.
  ${Do}
    StrCpy $2 "" ;clear out the installed part
    StrCpy $3 "" ;clear out the required part

    ${Do}
      ${If} $0 == "" ;if there are no more characters in the version
        StrCpy $4 "." ;fake the end of the version string
      ${Else}
        StrCpy $4 $0 1 0 ;$4 = character from the installed ver
        ${If} $4 != "."
          StrCpy $0 $0 ${NSIS_MAX_STRLEN} 1 ;remove that first character from the remaining
        ${EndIf}
      ${EndIf}

      ${If} $1 == ""  ;if there are no more characters in the version
        StrCpy $5 "." ;fake the end of the version string
      ${Else}
        StrCpy $5 $1 1 0 ;$5 = character from the required ver
        ${If} $5 != "."
          StrCpy $1 $1 ${NSIS_MAX_STRLEN} 1 ;remove that first character from the remaining
        ${EndIf}
      ${EndIf}
      
      ${If} $4 == "."
      ${AndIf} $5 == "."
        ${ExitDo} ;we're at the end of the part
      ${EndIf}

      ${If} $4 == "." ;if we're at the end of the current installed part
        StrCpy $2 "0$2" ;put a zero on the front
      ${Else} ;we have another character
        StrCpy $2 "$2$4" ;put the next character on the back
      ${EndIf}
      ${If} $5 == "." ;if we're at the end of the current required part
        StrCpy $3 "0$3" ;put a zero on the front
      ${Else} ;we have another character
        StrCpy $3 "$3$5" ;put the next character on the back
      ${EndIf}
    ${Loop}

    ${If} $0 != "" ;let's remove the leading period on installed part if it exists
      StrCpy $0 $0 ${NSIS_MAX_STRLEN} 1
    ${EndIf}
    ${If} $1 != "" ;let's remove the leading period on required part if it exists
      StrCpy $1 $1 ${NSIS_MAX_STRLEN} 1
    ${EndIf}

    ;$2 has the installed part, $3 has the required part
    ${If} $2 S< $3
      IntOp $0 0 - 1 ;$0 = -1, installed less than required
      ${ExitDo}
    ${ElseIf} $2 S> $3
      IntOp $0 0 + 1 ;$0 = 1, installed greater than required
      ${ExitDo}
    ${ElseIf} $2 == ""
    ${AndIf} $3 == ""
      IntOp $0 0 + 0 ;$0 = 0, the versions are identical
      ${ExitDo}
    ${EndIf} ;otherwise we just keep looping through the parts
  ${Loop}

  ${If} $0 < 0
    ${Trace} ".NET Framework Version found: $6, but is older than the required version: $7"
    Goto OldDotNET
  ${Else}
    ${Trace} ".NET Framework Version found: $6, equal or newer to required version: $7."
    Goto NewDotNET
  ${EndIf}

NoDotNET:
    MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION \
    "This software requires .NET Framework $7 or greater. Click OK to install (this may take a few minutes)." \
    /SD IDOK IDOK DownloadDotNET IDCANCEL GiveUpDotNET
    goto GiveUpDotNET ;IDCANCEL
OldDotNET:
    MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION \
    "This software requires .NET Framework $7 or greater. Click OK to install (this may take a few minutes)." \
    /SD IDOK IDOK DownloadDotNET IDCANCEL GiveUpDotNET
    goto GiveUpDotNET ;IDCANCEL

DownloadDotNET:
  ${Trace} "Beginning download of .NET Framework version $7."
  
  ${If} $7 == "2.0"
    ${Trace} "Downloading ${v2_URL}"
    NSISdl::download ${v2_URL} "$PLUGINSDIR\dotnetfx.exe"
  ${Else}
    ${Trace} "Aborting since we don't know how to install v$7."
    goto GiveUpDotNET
  ${EndIf}
  
  ${Trace} "Completed download. Installing..."
  Pop $R0
  ${If} $R0 == "cancel"
     goto GiveUpDotNET
  ${ElseIf} $R0 != "success"
    MessageBox MB_YESNO|MB_ICONEXCLAMATION \
    "Download failed:$\n$R0$\n$\nWould you like to continue the installation anyway?" \
    /SD IDYES IDYES NewDotNET IDNO GiveUpDotNET
  ${EndIf}
  ${Trace} "Pausing installation while downloaded .NET Framework installer runs."
  
  ${If} ${Silent} 
    ${Trace} "Installing .net silently."
    ExecWait '$PLUGINSDIR\dotnetfx.exe /q:a /c:"install /q"' $0
  ${Else}
  ${Trace} "Installing .net normally."
    ExecWait '$PLUGINSDIR\dotnetfx.exe /c:"install"' $0
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

GiveUpDotNET:
  Abort "Installation cancelled by user."

NewDotNET:
  ${Trace} ".Net requirement OK. Proceeding with remainder of installation."
  Pop $0
  Pop $1
  Pop $2
  Pop $3
  Pop $4
  Pop $5
  Pop $6 ;backup of intsalled ver
  Pop $7 ;backup of DoNetReqVer
!macroend