;*******************************************************************************
; Read keyboard scan code
;
;
; ------------------------------------------------------------------------------
;
;*******************************************************************************

keyboard.read          EXPORT
keyboard.disableBuzzer EXPORT
keyboard.held          EXPORT
keyboard.pressed       EXPORT

 SECTION code

keyboard.held    fcb   0 
keyboard.pressed fcb   0

keyboard.read
        clrb
        stb   keyboard.pressed
        swi                    ; Was a key pressed ?
        fcb   map.JSR_KTST
        bcc   >                ; No exit
        swi                    ; Read new key code in b
        fcb   map.JSR_GETC
        cmpb  keyboard.held
        beq   @rts             ; Return if key is already held, Press was cleared, but not Held
        stb   keyboard.pressed ; Store new key for one main loop
!       stb   keyboard.held    ; New key code was read
@rts    rts

keyboard.disableBuzzer
        lda   map.STATUS
        ora   #map.STATUS.CUTBUZZER
        sta   map.STATUS
        rts

 ENDSECTION
