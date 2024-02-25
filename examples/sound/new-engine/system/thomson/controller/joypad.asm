;*******************************************************************************
; Read joypad state
;
; Read Joypads state and store result as Press and Help values :
; - One byte with direction for joypad 0 and joypad 1
; - One byte with button for joypad 0 and joypad 1
;
; ------------------------------------------------------------------------------
;
; Result values: joypad.held, joypad.pressed
; -----------------------------------------------
; (16 bits)
; Joypad1     Joypad0
; 0000        0000 (0: release | 1: press) 00 000000 (0: release | 1: press)  
; ||||_Up     ||||_Up                       ||  ||         
; |||__Down   |||__Down                     ||  ||_ Btn B Joypad0
; ||___Left   ||___Left                     ||  |__ Btn B Joypad1                   
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