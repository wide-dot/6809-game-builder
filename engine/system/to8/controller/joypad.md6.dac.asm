;*******************************************************************************
; Megadrive joypad driver (UP, DOWN, LEFT, RIGHT, A, B, X, Y, Z, Mode)
; ------------------------------------------------------------------------------
;
; Read joypad 0 state
;
; wide-dot - Benoit Rousseau
; 26/09/2023 : Init
; 25/02/2024 : Moved to obj
;*******************************************************************************

joypad.md6.read            EXPORT
joypad.md6.held.dpad       EXPORT
joypad.md6.held.fire       EXPORT
joypad.md6.held.fireExt    EXPORT
joypad.md6.pressed.dpad    EXPORT
joypad.md6.pressed.fire    EXPORT
joypad.md6.pressed.fireExt EXPORT

 SECTION code

joypad.md6.state.dpad      fcb   0
joypad.md6.state.fire      fcb   0
joypad.md6.state.fireExt   fcb   0

joypad.md6.held.dpad       fcb   0
joypad.md6.held.fire       fcb   0
joypad.md6.held.fireExt    fcb   0

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
        rts

joypad.md6.read

        ; DAC disable, select joypad
        ldd   #$fb0c                   ; ! Mute by CRA to
        anda  map.MC6821.CRA2          ; ! avoid sound when
        sta   map.MC6821.CRA2          ; ! $e7cd is written
        stb   map.MC6821.PRA2          ; Peripherial Interface B (PIB) lines set as input
        ora   #$04                     ; set b2
        sta   map.MC6821.CRA2          ; select Peripherial Interface B (PIB) Register

        lda   #$0C                     ; PB2=1 (pin7 joypad port 0) PB3=1 (pin7 joypad port 1)
        sta   map.MC6821.PRA2          ; set line select to HI
        ldd   map.MC6821.PRA1          ; read data : E7CC:Right1|Left1|Down1|Up1|Right0|Left0|Down0|Up0 - E7CD:B1|B0|_|_|_|_|_|_
        coma                           ; reverse bits to get 0:released 1:pressed
        comb
        andb  #%11000000               ; filter B only
        std   joypad.md6.state.dpad
        clrb
        stb   map.MC6821.PRA2          ; set line select to LO
        sta   map.MC6821.PRA2          ; set line select to HI
        stb   map.MC6821.PRA2          ; set line select to LO
        sta   map.MC6821.PRA2          ; set line select to HI
        stb   map.MC6821.PRA2          ; set line select to LO
        ldb   map.MC6821.PRA2          ; read data : E7CD:A1|A0|_|_|_|_|_|_
        comb                           ; reverse bits to get 0:released 1:pressed
        sta   map.MC6821.PRA2          ; set line select to HI
        lda   map.MC6821.PRA1          ; read data : E7CC:Mode1|X1|Y1|Z1|Mode0|X0|Y0|Z0
        coma                           ; reverse bits to get 0:released 1:pressed
        sta   joypad.md6.state.fireExt

        lsrb                           ; set A in place
        lsrb                           ; implicit init of bit 7 and bit6 to 0
        orb   joypad.md6.state.fire    ; merge bits (A with B)
        stb   joypad.md6.state.fire    ; Store BBAA____

        ; DAC enable
        ldd    #$fb3f                  ; ! Mute by CRA to
        anda   map.MC6821.CRA2         ; ! avoid sound when
        sta    map.MC6821.CRA2         ; ! $e7cd written
        stb    map.MC6821.PRA2         ; Full sound line
        ora    #$04                    ; ! Disable mute by
        sta    map.MC6821.CRA2         ; ! CRA and sound

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

 ENDSECTION
