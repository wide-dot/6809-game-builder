;*******************************************************************************
; Read keyboard and map as joypad state
;
;
; ------------------------------------------------------------------------------
;
;*******************************************************************************

joypad.kb.read         EXPORT
joypad.kb.held         EXPORT
joypad.kb.held.dpad    EXPORT
joypad.kb.held.fire    EXPORT
joypad.kb.pressed      EXPORT
joypad.kb.pressed.dpad EXPORT
joypad.kb.pressed.fire EXPORT

 SECTION code

joypad.kb.state
joypad.kb.state.dpad   fcb   0
joypad.kb.state.fire   fcb   0
   
joypad.kb.held
joypad.kb.held.dpad    fcb   0
joypad.kb.held.fire    fcb   0

joypad.kb.pressed     
joypad.kb.pressed.dpad fcb   0
joypad.kb.pressed.fire fcb   0

joypad.kb.read
        ldd   #0
        std   joypad.kb.state         ; Clear current state
@loop                                 ; Read all buffered scan codes
        jsr   map.KTST                ; Was a key pressed ?
        bcc   >                       ; No clear and exit
        jsr   map.GETC                ; Read new key code in b
        jsr   joypad.kb.map
        bra   @loop
!       
        ; process dpad and fire
        ldd   joypad.kb.held
        eora  joypad.kb.state.dpad    ; Toggle off buttons that were previously being held
        eorb  joypad.kb.state.fire
        anda  joypad.kb.state.dpad
        andb  joypad.kb.state.fire
        std   joypad.kb.pressed       ; Store only new pressed buttons
        ldd   joypad.kb.state
        std   joypad.kb.held          ; Store current held state
        rts

joypad.kb.map
        lda   joypad.kb.state.dpad
        cmpb  #ascii.LEFT
        bne   >
        ora   #joypad.x.LEFT
        bra   @save
!       cmpb  #ascii.RIGHT
        bne   >
        ora   #joypad.x.RIGHT
        bra   @save
!       cmpb  #ascii.DOWN
        bne   >
        ora   #joypad.x.DOWN
        bra   @save
!       cmpb  #ascii.UP
        bne   >
        ora   #joypad.x.UP
@save   sta   joypad.kb.state.dpad
        rts
!

        lda   joypad.kb.state.fire
!       cmpb  #ascii.X
        bne   >
        ora   #joypad.x.A
        bra   @save
!       cmpb  #ascii.C
        bne   >
        ora   #joypad.x.B
@save   sta   joypad.kb.state.fire
!       rts
