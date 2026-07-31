;*******************************************************************************
; Read joypad state
;
; Read Joypads state and store result as Press and Help values :
; - One byte with direction for joypad 0 and joypad 1
; - One byte with button for joypad 0 and joypad 1
;
; This routine disable DAC
;
; ------------------------------------------------------------------------------
;
; Result values: joypad.held, joypad.pressed
; -----------------------------------------------
; (16 bits)
; Joypad1     Joypad0
; 0000        0000 (0: release | 1: press)  00 00 0000 (0: release | 1: press)  
; ||||_Up     ||||_Up                       || ||         
; |||__Down   |||__Down                     || ||__ Btn B Joypad0
; ||___Left   ||___Left                     || |___ Btn B Joypad1                   
; |____Right  |____Right                    ||_____ Btn A Joypad0                 
;                                           |______ Btn A Joypad1
;*******************************************************************************

joypad.read         EXPORT
joypad.held         EXPORT
joypad.held.dpad    EXPORT
joypad.held.fire    EXPORT
joypad.pressed      EXPORT
joypad.pressed.dpad EXPORT
joypad.pressed.fire EXPORT

 SECTION code

joypad.state
joypad.state.dpad            fcb   0
joypad.state.fire            fcb   0
   
joypad.held
joypad.held.dpad             fcb   0
joypad.held.fire             fcb   0

joypad.pressed     
joypad.pressed.dpad          fcb   0
joypad.pressed.fire          fcb   0

joypad.init

        ; configure MC6821 to be able to read joypads (0&1) direction
        lda   map.MC6821.CRA1      ; read Control Register A (CRA)
        anda  #$FB                 ; unset bit 2 
        sta   map.MC6821.CRA1      ; select Data Direction Register A (DDRA)
        clrb                       ; unset all bits
        stb   map.MC6821.PRA1      ; Peripherial Interface A (PIA) lines set as input
        ora   #$04                 ; set b2
        sta   map.MC6821.CRA1      ; select Peripherial Interface A (PIA) Register

        ; configure MC6821 to be able to read joypads (0&1) buttons
        lda   map.MC6821.CRA2      ; read Control Register B (CRB)
        anda  #$FB                 ; unset bit 2 
        sta   map.MC6821.CRA2      ; select Data Direction Register B (DDRB)
        clrb                       ; unset all bits, no DAC bits set as output
        stb   map.MC6821.PRA2      ; Peripherial Interface B (PIB) lines set as input
        ora   #$04                 ; set b2
        sta   map.MC6821.CRA2      ; select Peripherial Interface B (PIB) Register
        rts

joypad.read

        ldd   map.MC6821.PRA1          ; Read joypad physical state
        coma
        comb
        std   joypad.state        
        ldd   joypad.held
        eora  joypad.state.dpad        ; Toggle off buttons that were previously being held                  
        eorb  joypad.state.fire
        anda  joypad.state.dpad
        andb  joypad.state.fire
        std   joypad.pressed           ; Put pressed controller input 
        ldd   joypad.state
        std   joypad.held              ; Put raw controller input (for held buttons)
        rts

 ENDSECTION