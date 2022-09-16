* ---------------------------------------------------------------------------
* IrqPsg
* ------
* IRQ Subroutine to play sound with SN76489
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
        stb   MC6846.TCR                     ; timer precision x8
        ldd   #IrqPsg
        std   TIMERPT
        ldx   #IRQ.ONEFRAME                     ; on every frame
        stx   MC6846.TMSB
        jsr   IrqOn   
        rts
       
IrqOn         
        lda   STATUS                           
        ora   #$20
        sta   STATUS                                   ; STATUS register
        andcc #$EF                                    ; tell 6809 to activate irq
        rts
        
IrqOff 
        lda   STATUS                           
        anda  #$DF
        sta   STATUS                                   ; STATUS register
        orcc  #$10                                    ; tell 6809 to activate irq
        rts
        
IrqPsg 
        _GetCartPageA
        sta   IrqPsg_end+1                            ; backup data page
        
        ldd   Vint_runcount
        addd  #1
        std   Vint_runcount        
        
        jsr   PSGFrame
       *jsr   PSGSFXFrame
IrqPsg_end        
        lda   #$00
        _SetCartPageA                                 ; restore data page
        jmp   IRQ.EXIT                                   ; return to caller
