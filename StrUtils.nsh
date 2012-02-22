;----------------------------------------------------------------------
; Copyright (c) 2005-2012 Opersys Inc.  All Rights Reserved
;----------------------------------------------------------------------

;-----------------------------------------------------------------------------------
;
; StrStr Function
;
; This function searches for a substring on a string, and returns itself plus
; the remaining part of the string on the right of the substring.
;
;-----------------------------------------------------------------------------------

!macro mStrStr un
    Function ${un}StrStrF
    /*After this point:
      ------------------------------------------
      $R0 = SubString (input)
      $R1 = String (input)
      $R2 = SubStringLen (temp)
      $R3 = StrLen (temp)
      $R4 = StartCharPos (temp)
      $R5 = TempStr (temp)*/
    
      ;Get input from user
      Exch $R0
      Exch
      Exch $R1
      Push $R2
      Push $R3
      Push $R4
      Push $R5
    
      ;Get "String" and "SubString" length
      StrLen $R2 $R0
      StrLen $R3 $R1
      ;Start "StartCharPos" counter
      StrCpy $R4 0
    
      ;Loop until "SubString" is found or "String" reaches its end
      ${Do}
        ;Remove everything before and after the searched part ("TempStr")
        StrCpy $R5 $R1 $R2 $R4
    
        ;Compare "TempStr" with "SubString"
        ${IfThen} $R5 == $R0 ${|} ${ExitDo} ${|}
        ;If not "SubString", this could be "String"'s end
        ${IfThen} $R4 >= $R3 ${|} ${ExitDo} ${|}
        ;If not, continue the loop
        IntOp $R4 $R4 + 1
      ${Loop}
    
    /*After this point:
      ------------------------------------------
      $R0 = ResultVar (output)*/
    
      ;Remove part before "SubString" on "String" (if there has one)
      StrCpy $R0 $R1 `` $R4
    
      ;Return output to user
      Pop $R5
      Pop $R4
      Pop $R3
      Pop $R2
      Pop $R1
      Exch $R0
    FunctionEnd
!macroend

#!insertmacro mStrStr ""
!insertmacro mStrStr "un."

;-----------------------------------------------------------------------------------
;
; Macro to call StrStr Function
;
;-----------------------------------------------------------------------------------

!macro un.StrStr ResultVar String SubString
  Push `${String}`
  Push `${SubString}`
  Call un.StrStrF
  Pop `${ResultVar}`
!macroend

!macro StrStr ResultVar String SubString
  Push `${String}`
  Push `${SubString}`
  Call StrStrF
  Pop `${ResultVar}`
!macroend
/*
!macro un.StrStr ResultVar String SubString
  Push `${String}`
  Push `${SubString}`
  Call un.StrStrF
  Pop `${ResultVar}`
!macroend*/
;-----------------------------------------------------------------------------------
;
; Macro to call StrRep Function
;
;-----------------------------------------------------------------------------------
!define StrRep "!insertmacro StrRep"

!macro StrRep ResultVar StrToDoReplecement StrToReplace StrReplacement
  Push `${StrToDoReplecement}`
  Push `${StrToReplace}`
  Push `${StrReplacement}`
  Call StrRep
  Pop `${ResultVar}`
!macroend

;-----------------------------------------------------------------------------------
;
; StrRep Function
;
; A string replace function. This one can be optimized considerably if you know
; what you are replacing as I originally wrote it to replace /s with \s and vice
; versa - that version is at the end
;
;-----------------------------------------------------------------------------------
Function StrRep
  Exch $R4 ; $R4 = Replacement String
  Exch
  Exch $R3 ; $R3 = String to replace (needle)
  Exch 2
  Exch $R1 ; $R1 = String to do replacement in (haystack)
  Push $R2 ; Replaced haystack
  Push $R5 ; Len (needle)
  Push $R6 ; len (haystack)
  Push $R7 ; Scratch reg
  StrCpy $R2 ""
  StrLen $R5 $R3
  StrLen $R6 $R1
loop:
  StrCpy $R7 $R1 $R5
  StrCmp $R7 $R3 found
  StrCpy $R7 $R1 1 ; - optimization can be removed if U know len needle=1
  StrCpy $R2 "$R2$R7"
  StrCpy $R1 $R1 $R6 1
  StrCmp $R1 "" done loop
found:
  StrCpy $R2 "$R2$R4"
  StrCpy $R1 $R1 $R6 $R5
  StrCmp $R1 "" done loop
done:
  StrCpy $R3 $R2
  Pop $R7
  Pop $R6
  Pop $R5
  Pop $R2
  Pop $R1
  Pop $R4
  Exch $R3
FunctionEnd