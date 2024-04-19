;*******************************************************************************
; Read keyboard and map as joypad state
;
;
; ------------------------------------------------------------------------------
;
;*******************************************************************************

joypad.md6.kb.read            EXPORT
joypad.md6.kb.held            EXPORT
joypad.md6.kb.held.dpad       EXPORT
joypad.md6.kb.held.fire       EXPORT
joypad.md6.kb.held.fireExt    EXPORT
joypad.md6.kb.pressed         EXPORT
joypad.md6.kb.pressed.dpad    EXPORT
joypad.md6.kb.pressed.fire    EXPORT
joypad.md6.kb.pressed.fireExt EXPORT

 SECTION code

joypad.md6.kb.state
joypad.md6.kb.state.dpad      fcb   0
joypad.md6.kb.state.fire      fcb   0
joypad.md6.kb.state.fireExt   fcb   0
   
joypad.md6.kb.held
joypad.md6.kb.held.dpad       fcb   0
joypad.md6.kb.held.fire       fcb   0
joypad.md6.kb.held.fireExt    fcb   0

joypad.md6.kb.pressed     
joypad.md6.kb.pressed.dpad    fcb   0
joypad.md6.kb.pressed.fire    fcb   0
joypad.md6.kb.pressed.fireExt fcb   0

joypad.md6.kb.read
        ldd   #0
        sta   joypad.md6.kb.state.dpad    ; Clear current state
        std   joypad.md6.kb.state.fire    ; Clear current state
@loop                                     ; Read all buffered scan codes
        swi                               ; Was a key pressed ?
        fcb   map.JSR_KTST
        bcc   >                           ; No exit
        swi                               ; Read new key code in b
        fcb   map.JSR_GETC
        jsr   joypad.md6.kb.map
        bra   @loop
!       
        ; process fire
        ldd   joypad.md6.held.fire
        eora  joypad.md6.state.fire    ; Toggle off buttons that were previously being held
        eorb  joypad.md6.state.fireExt
        anda  joypad.md6.state.fire
        andb  joypad.md6.state.fireExt
        std   joypad.md6.pressed.fire  ; Store only new pressed buttons
        ldd   joypad.md6.state.fire
        std   joypad.md6.held.fire     ; Store current held state

        ; process dpad
        lda   joypad.md6.held.dpad
        eora  joypad.md6.state.dpad    ; Toggle off buttons that were previously being held
        anda  joypad.md6.state.dpad
        sta   joypad.md6.pressed.dpad  ; Store only new pressed pads
        lda   joypad.md6.state.dpad
        sta   joypad.md6.held.dpad     ; Store current held state
        rts

joypad.md6.kb.map
        lda   joypad.md6.kb.state.dpad
        cmpb  #scancode.LEFT
        bne   >
        ora   #joypad.md6.x.LEFT
        bra   @save
!       cmpb  #scancode.RIGHT
        bne   >
        ora   #joypad.md6.x.RIGHT
        bra   @save
!       cmpb  #scancode.DOWN
        bne   >
        ora   #joypad.md6.x.DOWN
        bra   @save
!       cmpb  #scancode.UP
        bne   >
        ora   #joypad.md6.x.UP
@save   sta   joypad.md6.kb.state.dpad
        rts
!

        lda   joypad.md6.kb.state.fire
!       cmpb  #scancode.X
        bne   >
        ora   #joypad.md6.x.A
        bra   @save
!       cmpb  #scancode.C
        bne   >
        ora   #joypad.md6.x.B
@save   sta   joypad.md6.kb.state.fire
        rts
!

        lda   joypad.md6.kb.state.fireExt
!       cmpb  #scancode.V
        bne   >
        ora   #joypad.md6.x.MODE
        bra   @save
!       cmpb  #scancode.S
        bne   >
        ora   #joypad.md6.x.X
        bra   @save
!       cmpb  #scancode.D
        bne   >
        ora   #joypad.md6.x.Y
        bra   @save
!       cmpb  #scancode.F
        bne   >
        ora   #joypad.md6.x.Z
@save   sta   joypad.md6.kb.state.fireExt
!       rts
