;*******************************************************************************
; Read joypad state
;
; Read Joypads state and store result as Press and Help values :
; - One byte with direction for player 1 and player 2
; - One byte with button for player 1 and player 2
;
; ------------------------------------------------------------------------------
;
; Result values: Joypads_Held, Joypads_Press
; -----------------------------------------------
; (16 bits)
; Joypad2     Joypad1                                                          
; 0000        0000 (0: release | 1: press) 00 000000 (0: release | 1: press)  
; ||||_Up     ||||_Up                       ||  ||         
; |||__Down   |||__Down                     ||  ||_ Btn B Joypad1
; ||___Left   ||___Left                     ||  |__ Btn B Joypad2                   
; |____Right  |____Right                    ||_____ Btn A Joypad1                 
;                                           |______ Btn A Joypad2
;*******************************************************************************

joypad.read         EXPORT
joypad.state        EXPORT
joypad.state.dpad   EXPORT
joypad.state.fire   EXPORT
joypad.held         EXPORT
joypad.held.dpad    EXPORT
joypad.held.fire    EXPORT
joypad.pressed      EXPORT
joypad.pressed.dpad EXPORT
joypad.pressed.fire EXPORT

 SECTION code

joypad.state
joypad.state.dpad            fcb   $00
joypad.state.fire            fcb   $00
   
joypad.held
joypad.held.dpad             fcb   $00
joypad.held.fire             fcb   $00

joypad.pressed     
joypad.pressed.dpad          fcb   $00
joypad.pressed.fire          fcb   $00

joypad.read
        ldd   $map.MC6821.PRA1         ; Read joypad physical state
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