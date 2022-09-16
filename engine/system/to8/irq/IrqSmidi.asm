* ---------------------------------------------------------------------------
* Irq Smidi
* -------
* IRQ Subroutine to play midi data
*
* input REG : [dp] with value E7 (from Monitor ROM)
* reset REG : none
*
* IrqOn
* reset REG : [a]
*
* IrqOff
* reset REG : [a]
* ---------------------------------------------------------------------------
       
IrqSet50Hz
        ldb   #$42
        stb   MC6846.TCR           ; timer precision x8
        ldd   #IrqSmidi
        std   TIMERPT
        ldx   #IRQ.ONEFRAME           ; on every frame
        stx   MC6846.TMSB
        jsr   IrqOn   
        rts
       
IrqOn         
        lda   STATUS                           
        ora   #$20
        sta   STATUS                    ; STATUS register
        andcc #$EF                     ; tell 6809 to activate irq
        rts
        
IrqOff 
        lda   STATUS                           
        anda  #$DF
        sta   STATUS                    ; STATUS register
        orcc  #$10                     ; tell 6809 to deactivate irq
        rts
        
IrqSmidi 
        _GetCartPageA
        sta   IrqSmidi_end+1           ; backup data page
        
        ldd   Vint_runcount
        addd  #1
        std   Vint_runcount
        
        sts   @a+2                     ; backup system stack
        lds   #IRQSysStack             ; set tmp system stack for IRQ 
        jsr   MusicFrame
@a      lds   #0                       ; (dynamic) restore system stack   
        
IrqSmidi_end        
        lda   #$00                     ; (dynamic)
        _SetCartPageA                  ; restore data page
        jmp   IRQ.EXIT                    ; return to caller
        
; This space allow the use of system stack inside IRQ calls
; otherwise the writes in sys stack will erase data when S is in use
; (outside of IRQ) for another task than sys stack, ex: stack blast copy 
        fill  0,32
IRQSysStack