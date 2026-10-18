* ---------------------------------------------------------------------------
* RunPgSubRoutine
* ---------------
* Calls a subroutine in another page, then puts the caller's page back.
*
* input : PSR_Page the page, PSR_Address the subroutine, PSR_Param its A
* ---------------------------------------------------------------------------

RunPgSubRoutine 
        _GetCartPageA
        sta   @page
        lda   #0
PSR_Page equ *-1
        _SetCartPageA                  ; set data page for sub routine to call
        lda   #0
PSR_Param equ *-1
        jsr   >0
PSR_Address equ *-2
RunPgSubRoutine_return        
        lda   #0
@page   equ *-1
        _SetCartPageA                  ; restore data page
        rts
