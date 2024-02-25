;*******************************************************************************
; Read joypad 1 state
;
; Store result as pressed and held values :
; - one byte with direction and button
;
; ------------------------------------------------------------------------------
;
; Result values: joypad.1.held, joypad.1.pressed
; -----------------------------------------------
; (16 bits)
; 0000        0000 (0: release | 1: press)
; ||||_Up     ||
; |||__Down   ||
; ||___Left   ||___Btn B
; |____Right  |____Btn A
;
;*******************************************************************************

joypad.1.read    EXPORT
joypad.1.held    EXPORT
joypad.1.pressed EXPORT

 SECTION code

joypad.1.held    fcb   0
joypad.1.pressed fcb   0

joypad.1.read

        ldd   map.MC6821.PRA1
        stb   @a
        anda  #%11110000
        andb  #%10000000
        lsrb
        lsrb
        lsrb
        lsrb
        stb   @b
        ldb   #0
@a      equ   *-1
        andb  #%00001000
        lsrb
        orb   #0
@b      equ   *-1
        stb   @c
        ora   #0
@c      equ   *-1
        coma
        sta   @d
        lda   joypad.1.held
        eora  @d
        anda  @d
        sta   joypad.1.pressed
        lda   #0
@d      equ   *-1
        sta   joypad.1.held
        rts

 ENDSECTION