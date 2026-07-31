;*******************************************************************************
; Megadrive joypad driver (UP, DOWN, LEFT, RIGHT, A, B, X, Y, Z, Mode)
; ------------------------------------------------------------------------------
;
; Read joypad 0 state
; This routine should be used with DAC muted
;
; wide-dot - Benoit Rousseau
; 26/09/2023 : Init
;*******************************************************************************

joypad.md6.init            EXPORT
joypad.md6.read            EXPORT
joypad.md6.held            EXPORT
joypad.md6.held.dpad       EXPORT
joypad.md6.held.fire       EXPORT
joypad.md6.held.fireExt    EXPORT
joypad.md6.pressed         EXPORT
joypad.md6.pressed.dpad    EXPORT
joypad.md6.pressed.fire    EXPORT
joypad.md6.pressed.fireExt EXPORT

 SECTION code

joypad.md6.state.dpad      fcb   0
joypad.md6.state.fire      fcb   0
joypad.md6.state.fireExt   fcb   0

joypad.md6.held
joypad.md6.held.dpad       fcb   0
joypad.md6.held.fire       fcb   0
joypad.md6.held.fireExt    fcb   0

joypad.md6.pressed
joypad.md6.pressed.dpad    fcb   0
joypad.md6.pressed.fire    fcb   0
joypad.md6.pressed.fireExt fcb   0

joypad.md6.init

        ; configure MC6821 to be able to read joypads (0&1) direction
        ldd   #$FB00
        anda  map.MC6821.CRA1      ; unset bit 2 to Control Register A (CRA)
        sta   map.MC6821.CRA1      ; select Data Direction Register A (DDRA)
        stb   map.MC6821.PRA1      ; Peripherial Interface A (PIA) lines set as input, unset all bits
        ora   #$04                 ; set b2
        sta   map.MC6821.CRA1      ; select Peripherial Interface A (PIA) Register

        ; configure MC6821 to be able to read joypads (0&1) A and B buttons
        lda   map.MC6821.CRA2      ; read Control Register B (CRB)
        anda  #$FB                 ; unset bit 2 
        sta   map.MC6821.CRA2      ; select Data Direction Register B (DDRB)
        ldb   #$0C                 ; set bit 2 (pin7 ctrl 0) and 3 (pin7 ctrl 1), warning : DAC bits set as output
        stb   map.MC6821.PRA2      ; Peripherial Interface B (PIB) lines set as input
        ora   #$04                 ; set b2
        sta   map.MC6821.CRA2      ; select Peripherial Interface B (PIB) Register
        rts

joypad.md6.read

        ; hot plug of controllers need resync
        _ldd  %00000100,joypad.0.DPAD
        jsr   joypad.md6.sync
        sta   joypad.0.type

        _ldd  %00001000,joypad.1.DPAD
        jsr   joypad.md6.sync
        sta   joypad.1.type

        ; read physical state
        lda   map.MC6821.PRA2          ; read data : E7CD:A1|A0|_|_|_|_|_|_
        coma                           ; reverse bits to get 0:released 1:pressed
        anda  #%11000000               ; filter A only
        lsra                           ; set A in place
        lsra                           ; implicit init of bit 7 and bit6 to 0
        sta   joypad.md6.state.fire
        lda   #$0C
        sta   map.MC6821.PRA2          ; set line select to HI for both gamepad
        ldb   map.MC6821.PRA1          ; read data : E7CC:Mode1|X1|Y1|Z1|Mode0|X0|Y0|Z0
        comb                           ; reverse bits to get 0:released 1:pressed
        stb   joypad.md6.state.fireExt
        clrb
        stb   map.MC6821.PRA2          ; set line select to LO
        sta   map.MC6821.PRA2          ; set line select to HI
        ldd   map.MC6821.PRA1          ; read data : E7CC:Right1|Left1|Down1|Up1|Right0|Left0|Down0|Up0 - E7CD:B1|B0|_|_|_|_|_|_
        coma                           ; reverse bits to get 0:released 1:pressed
        comb
        andb  #%11000000               ; filter B only
        orb   joypad.md6.state.fire    ; merge bits (A with B) as BBAA____
        std   joypad.md6.state.dpad    ; and joypad.md6.state.fire

        ; process dpad
        lda   joypad.md6.held.dpad
        eora  joypad.md6.state.dpad    ; Toggle off buttons that were previously being held
        anda  joypad.md6.state.dpad
        sta   joypad.md6.pressed.dpad  ; Store only new pressed pads
        lda   joypad.md6.state.dpad
        sta   joypad.md6.held.dpad     ; Store current held state

        ; process fire
        ldd   joypad.md6.held.fire
        eora  joypad.md6.state.fire    ; Toggle off buttons that were previously being held
        eorb  joypad.md6.state.fireExt
        anda  joypad.md6.state.fire
        andb  joypad.md6.state.fireExt
        std   joypad.md6.pressed.fire  ; Store only new pressed buttons
        ldd   joypad.md6.state.fire
        std   joypad.md6.held.fire     ; Store current held state
        rts

joypad.md6.sync
        ; do not loop infinitly to handle when no gamepad is plugged
        ; test for 3btn gamepad
        bitb  map.MC6821.PRA1
        beq   @md6
        sta   map.MC6821.PRA2          ; set line select to HI
        clr   map.MC6821.PRA2          ; set line select to LO
        bitb  map.MC6821.PRA1
        beq   @md6
        sta   map.MC6821.PRA2          ; set line select to HI
        clr   map.MC6821.PRA2          ; set line select to LO
        bitb  map.MC6821.PRA1
        beq   @md6
        sta   map.MC6821.PRA2          ; set line select to HI
        clr   map.MC6821.PRA2          ; set line select to LO
        bitb  map.MC6821.PRA1
        beq   @md6
        sta   map.MC6821.PRA2          ; set line select to HI
        clr   map.MC6821.PRA2          ; set line select to LO
        bitb  map.MC6821.PRA1
        bne   >
@md6    lda   #joypad.type.MD6
        rts
!       andb  #joypad.x.LEFT|joypad.x.RIGHT
        bitb  map.MC6821.PRA1          ; two tests are mandatory since cycle 4 does not have the LR marker
        beq   @md3
        sta   map.MC6821.PRA2          ; set line select to HI
        clr   map.MC6821.PRA2          ; set line select to LO
        bitb  map.MC6821.PRA1
        bne   @jpd
@md3    lda   #joypad.type.MD3
        rts
@jpd    lda   #joypad.type.JPD
        rts

 ENDSECTION
