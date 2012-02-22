/****************************************************************************
  Copyright (c) 2005-2012 Opersys Inc.  All Rights Reserved
 ***************************************************************************/

!include LogicLib.nsh
!include StrUtils.nsh
!include FindProcess.nsh

/* Check if Microsoft Outlook 2003 or 2007 is installed.
   The return value is stored on the stack:
   0 -> No valid Outlook version detected
   1 -> Outlook 2003 is installed
   2 -> Outlook 2007 is installed
*/
Function CheckOutlookPresence
   ClearErrors
   ReadRegStr $0 HKLM Software\Microsoft\Office\11.0\Outlook\InstallRoot "Path"
   IfErrors noMso2003 mso2003
   
   noMso2003:
      ReadRegStr $0 HKLM "Software\Microsoft\Office\12.0\Outlook\InstallRoot" "Path"
      IfErrors nothing mso2007
      
   nothing:
     push "0"
     goto end
     
   mso2003:
     push "1"
     goto end

   mso2007:
     push "2"   
   
   end:  
FunctionEnd
 
/* Log the specified message to the Windows Event Log. Do not call before the dll 
   has been registered with Windows. 
   Level: 0 -> Information, 1 -> Error, 2 -> Warning. */
!macro Log Level Message
    ; Be nice to caller and save his $0  before using it.
    Push $0
    EventLog::WriteEventLog  '' 'TeamboxManager' ${Level} '0' '0' '${Message}'  
    Pop $0
    
    ${If} $0 == 1
        DetailPrint "Failure logging ${Message}."
    ${EndIf}
    
    ; Restore original $0.
    Pop $0
!macroend
# User defined logging level.
!define Log "!insertmacro Log "
# Log an informational message.
!define Trace "!insertmacro Log '0' "

/* Register our Windows Event log dll. The registry key must be deleted manually by the caller.*/
!macro RegisterEventMngr RegisterFlag
    SetOutPath $PLUGINSDIR 
    File "${FilesDir}\EventSourceMngr.exe"
    File "${FilesDir}\TbxMngrEventId.dll"
    
    # Register our custom event source.
    ExecWait "$PLUGINSDIR\EventSourceMngr.exe ${RegisterFlag} TeamboxManager" $0
    
    ${If} $0 == "0"
        ${Trace} "EventSourceMngr.exe executed successfully."
    ${Else}
        ${Log} "1" "EventSourceMngr.exe failed: $0"
    ${EndIf}
    
    # Tell Windows the message DLL location of our event source.
    WriteRegStr HKLM "SYSTEM\CurrentControlSet\Services\Eventlog\Application\TeamboxManager" EventMessageFile "$PLUGINSDIR\TbxMngrEventId.dll"
!macroend

;Call CreateGUID
;Pop $0 ;contains GUID
Function CreateGUID
  System::Call 'ole32::CoCreateGuid(g .s)'
FunctionEnd

!macro SetDebugPrivs
    SetOutPath $PLUGINSDIR 
    File "${FilesDir}\SetSeDebugPriv.exe"
    ExecWait "$PLUGINSDIR\SetSeDebugPriv.exe" $0 
!macroend 

!macro ElevatePrivs
    UAC_Elevate:
        UAC::RunElevated
        StrCmp 1223 $0 UAC_ElevationAborted ; UAC dialog aborted by user?
        StrCmp 0 $0 0 UAC_Err ; Error?
        StrCmp 1 $1 0 UAC_Success ;Are we the real deal or just the wrapper?
        Quit
     
    UAC_Err:
        ${Log} "1" "$(UnableToElevatePriv)$0"
        MessageBox mb_iconstop "$(UnableToElevatePriv)$0" /SD IDOK
        Abort
     
    UAC_ElevationAborted:
        # Elevation was aborted by the user. Cancel installation.
        ${Log} "1" "Aborted by user (or by silent installer.)"
        Abort
     
    UAC_Success:
        StrCmp 1 $3 +4 ;Admin?
        StrCmp 3 $1 0 UAC_ElevationAborted ;Try again?
        MessageBox MB_OKCANCEL|MB_ICONSTOP  $(NotAnAdminTryAgain) /SD IDCANCEL IDOK UAC_Elevate IDCANCEL UAC_ElevationAborted        
!macroend

# Macro called when the (un)installer quits for any reason (user aborted, installation suceeded or failed.
# Used to cleanup our mess.
!macro InstallationEnd
    UAC::Unload
!macroEnd

# Blocks until the user closes both MSO and the KWM, or hits cancel.
!macro mBlockUntilSoftwareIsClosed un
    Function ${un}BlockUntilSoftwareIsClosed
    ${Trace} "${un}BlockUntilSoftwareIsClosed called."
        ${Do}
            !insertmacro ${un}FindProcess "Outlook.exe" $0
            ${If} $0 <> 0
                ; Found outlook.exe running: cancel if silent, warn otherwise
                MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION|MB_SETFOREGROUND $(CloseOutlook) /SD IDCANCEL IDOK check IDCANCEL cancel
                cancel:
                    ${If} ${Silent}
                        ${Log} "1" "One or more Outlook.exe processes are running. The installation will abort."
                    ${EndIf}
                    Quit
            ${EndIf}
         
            check:
        ${LoopWhile} $0 <> 0
            
        ${Do}
            !insertmacro ${un}FindProcess "kwm.exe" $0
            ${If} $0 <> 0
                MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION|MB_SETFOREGROUND $(CloseKwm) /SD IDCANCEL IDOK close_kwm_check IDCANCEL cancel_kwm
                cancel_kwm:
                  ${If} ${Silent}
                        ${Log} "1" "One or more kwm.exe processes are running. The installation will abort."
                    ${EndIf}
                    Quit
            ${EndIf}
        close_kwm_check:
        ${LoopWhile} $0 <> 0
    FunctionEnd
!macroend    

!insertMacro mBlockUntilSoftwareIsClosed ""
!insertMacro mBlockUntilSoftwareIsClosed "un."

Function ExecKwm
    UAC::Exec '1' '"$INSTDIR\kwm.exe"' '' ''
FunctionEnd

!macro mGetParams un
    Function ${un}GetParameters
     
      Push $R0
      Push $R1
      Push $R2
      Push $R3
     
      StrCpy $R2 1
      StrLen $R3 $CMDLINE
     
      ;Check for quote or space
      StrCpy $R0 $CMDLINE $R2
      StrCmp $R0 '"' 0 +3
        StrCpy $R1 '"'
        Goto loop
      StrCpy $R1 " "
     
      loop:
        IntOp $R2 $R2 + 1
        StrCpy $R0 $CMDLINE 1 $R2
        StrCmp $R0 $R1 get
        StrCmp $R2 $R3 get
        Goto loop
     
      get:
        IntOp $R2 $R2 + 1
        StrCpy $R0 $CMDLINE 1 $R2
        StrCmp $R0 " " get
        StrCpy $R0 $CMDLINE "" $R2
     
      Pop $R3
      Pop $R2
      Pop $R1
      Exch $R0     
    FunctionEnd
!macroEnd
!macro GetParams
    Call GetParameters
!macroend
!macro un.GetParams
    Call un.GetParameters
!macroend
!insertmacro mGetParams "un."


# Sets $0 to "" if the /F flag has been set on the command line (do not force deletion).
# Sets $0 to "/REBOOTOK" otherwise. If this is called from an Uninstallation context,
# set Uninstall to "un."
!macro RequireForceDeletion un
    Function ${un}ReqForceDeletion
        !insertmacro ${un}GetParams
        Pop $1
        !insertmacro ${un}StrStr $0 '$1' "/F"
        StrCpy $0 $0 2
        StrCmp $0 "/F" FFlag
            
        StrCpy $0 "/REBOOTOK"
        ${Trace} "Using REBOOTOK file deletion."
        Return
            
        FFlag:
        ${Trace} "Forcing no-REBOOTOK file deletion."
        StrCpy $0 ""
    FunctionEnd
!macroend

!insertMacro RequireForceDeletion "un."

# Add exceptions to the Windows firewall.
!macro PunchWindowsFw
    SimpleFC::IsFirewallEnabled
    Pop $0 ; return error(1)/success(0)
    Pop $1 ; return 1=Enabled/0=Disabled
  
    ${If} $0 == 0 ; function succeeded
        ${If} $1 == 1 ; firewall enable
            ${Trace} "Windows firewall is enabled. Adding exceptions for the Teambox softwares."            
            ; Add kmod.exe to the firewall exception list - All Networks - All IP Version - Enabled
            SimpleFC::AddApplication "kmod.exe" "$INSTDIR\kmod\kmod.exe" 0 2 "" 1
            Pop $0            
        
            ${Unless} $0 = 0  ; Unless function succeeded
                ${Log} "1"  "Unable to add kmod.exe to the firewall. This might cause some trouble down the road."
            ${EndUnless}
            
            SimpleFC::AddApplication "ktlstunnel.exe" "$INSTDIR\ktlstunnel\ktlstunnel.exe" 0 2 "" 1
            Pop $0            
            ${Unless} $0 = 0  ; Unless function succeeded
                ${Log} "1" "Unable to add ktlstunnel.exe to the firewall. This might cause some trouble down the road."
            ${EndUnless}
        ${Else}
            ${Trace} "Windows firewall is disabled. No need to add exceptions."    
        ${EndIf}
        
    ${Else}
        ${Log} "1" "Error adding exceptions to Windows firewall. This might cause some trouble down the road."
    ${EndIf}
!macroend

# Remove exceptions to the Windows firewall.
!macro UnpunchWindowsFw
    # If the Windows firewall was disabled at the time of installation, 
    # no exceptions were added to the firewall. However, this won't fail.
    ${Trace} "Removing Teambox softwares from Windows firewall."
    
    SimpleFC::RemoveApplication "$INSTDIR\kmod\kmod.exe"
    SimpleFC::RemoveApplication "$INSTDIR\ktlstunnel\ktlstunnel.exe"
!macroend
