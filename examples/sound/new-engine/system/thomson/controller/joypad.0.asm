;*******************************************************************************
; Read joypad 0 state
;
; Store result as pressed and held values :
; - one byte with direction and button
;
; ------------------------------------------------------------------------------
;
; Result values: joypad.0.held, joypad.0.pressed
; -----------------------------------------------
; (16 bits)
; 0000        0000 (0: release | 1: press)
; ||||_Up     ||
; |||__Down   ||
; ||___Left   ||___Btn B
; |____Right  |____Btn A
;
;*******************************************************************************

joypad.0.read    EXPORT
joypad.0.held    EXPORT
joypad.0.pressed EXPORT

 SECTION code

joypad.0.held    fcb   0
joypad.0.pressed fcb   0

joypad.0.read

        ldd   map.MC6821.PRA1
        stb   @a
        anda  #%00001111
        lsla
        lsla
        lsla
        lsla
        andb  #%01000000
        lsrb
        lsrb
        lsrb
        stb   @b
        ldb   #0
@a      equ   *-1
        andb  #%00000100
        orb   #0
@b      equ   *-1
        stb   @c
        ora   #0
@c      equ   *-1
        coma
        sta   @d
        lda   joypad.0.held
        eora  @d
        anda  @d
        sta   joypad.0.pressed
        lda   #0
@d      equ   *-1
        sta   joypad.0.held
        rts

 ENDSECTION
