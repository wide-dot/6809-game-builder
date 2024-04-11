;*******************************************************************************
; Read keyboard scan code
;
;
; ------------------------------------------------------------------------------
;
;*******************************************************************************

keyboard.read          EXPORT
keyboard.held    EXPORT
keyboard.pressed EXPORT

 SECTION code

keyboard.held    fcb   0 
keyboard.pressed fcb   0

keyboard.read
        clrb
        stb   keyboard.pressed
        jsr   map.KTST         ; Was a key pressed ?
        bcc   >                ; No exit
 IFDEF keyboard.MASK_MPLUS_FIRQ
        ;lda   map.MPLUS.CTRL
        ;sta   @a
        ;anda  #%11110111       ; disable (F)IRQ
        ;sta   map.MPLUS.CTRL
 ENDC
        jsr   map.GETC         ; Read new key code in b
 IFDEF keyboard.MASK_MPLUS_FIRQ
        ;lda   #0               ; restore (F)IRQ previous state
@a      ;equ   *-1
        ;sta   map.MPLUS.CTRL
 ENDC
        bcc   >
        cmpb  keyboard.held
        beq   @rts             ; Return if key is already held, Press was cleared, but not Held
        stb   keyboard.pressed ; Store new key for one main loop
!       stb   keyboard.held    ; New key code was read
@rts    rts

 ENDSECTION
