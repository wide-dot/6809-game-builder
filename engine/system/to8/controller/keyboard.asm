;*******************************************************************************
; Read keyboard ascii code
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
        clr   keyboard.pressed
        lda   map.MC6821.PRA
        lsra                   ; Was a key pressed ?
        bcc   >                ; No exit
        jsr   map.GETC         ; Read new key code in b
        bcc   >
        cmpb  keyboard.held
        beq   @rts             ; Return if key is already held, Press was cleared, but not Held
        stb   keyboard.pressed ; Store new key for one main loop
!       stb   keyboard.held    ; New key code was read
@rts    rts

 ENDSECTION
