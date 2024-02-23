; -----------------------------------------------------------------------------
; Megadrive joypad driver (3 buttons + start)
; -----------------------------------------------------------------------------
; wide-dot - Benoit Rousseau - 26/09/2023
; ---------------------------------------

; Buttons masks
; -----------------------------------------------------------------------------
joypad.md6.up    equ   %00000001
joypad.md6.down  equ   %00000010
joypad.md6.left  equ   %00000100
joypad.md6.right equ   %00001000

joypad.md6.z     equ   %00000001
joypad.md6.y     equ   %00000010
joypad.md6.x     equ   %00000100
joypad.md6.mode  equ   %00001000
joypad.md6.b     equ   %00010000
joypad.md6.a     equ   %00100000

; State variables
; -----------------------------------------------------------------------------
joypad.md6.ctrl0.held
joypad.md6.ctrl0.held.dpad     fcb   0
joypad.md6.ctrl0.held.fire     fcb   0
joypad.md6.ctrl0.press
joypad.md6.ctrl0.press.dpad    fcb   0
joypad.md6.ctrl0.press.fire    fcb   0

joypad.md6.ctrl1.held
joypad.md6.ctrl1.held.dpad     fcb   0
joypad.md6.ctrl1.held.fire     fcb   0
joypad.md6.ctrl1.press
joypad.md6.ctrl1.press.dpad    fcb   0
joypad.md6.ctrl1.press.fire    fcb   0

joypad.md6.init

        ; configure MC6821 to be able to read joypads (1&2) direction
        lda   $E7CE      ; read Control Register A (CRA)
        anda  #$FB       ; unset bit 2 
        sta   $E7CE      ; select Data Direction Register A (DDRA)
        clrb             ; unset all bits
        stb   $E7CC      ; Peripherial Interface A (PIA) lines set as input
        ora   #$04       ; set b2
        sta   $E7CE      ; select Peripherial Interface A (PIA) Register

        ; configure MC6821 to be able to read joypads (1&2) buttons
        lda   $E7CF      ; read Control Register B (CRB)
        anda  #$FB       ; unset bit 2 
        sta   $E7CF      ; select Data Direction Register B (DDRB)
        ldb   #$0C       ; set bit 2 (pin7 ctrl 0) and 3 (pin7 ctrl 1), warning : DAC bits set as output
        stb   $E7CD      ; Peripherial Interface B (PIB) lines set as input
        ora   #$04       ; set b2
        sta   $E7CF      ; select Peripherial Interface B (PIB) Register
        rts

joypad.md6.read

        ; mute DAC
        lda   map.MC6846.CSR
        ora   #%00000100
        sta   map.MC6846.CSR

        ldd   #$0C00     ; PB2=1 (pin7 port manette 0) PB3=1 (pin7 port manette 1)
        sta   $E7CD      ; set line select to HI
        ldx   $E7CC      ; read data : E7CC:Right1|Left1|Down1|Up1|Right0|Left0|Down0|Up0 - E7CD:B1|B0|_|_|_|_|_|_
        stb   $E7CD      ; set line select to LO
        sta   $E7CD      ; set line select to HI
        stb   $E7CD      ; set line select to LO
        sta   $E7CD      ; set line select to HI
        stb   $E7CD      ; set line select to LO
        ldb   $E7CD      ; read data : E7CD:A1|A0|_|_|_|_|_|_
        sta   $E7CD      ; set line select to HI
        lda   $E7CC      ; read data : E7CC:Mode1|X1|Y1|Z1|Mode0|X0|Y0|Z0

        ; control pad 0
        anda  #%00001111 ; keep MXYZ in place
        andb  #%01000000 ; filter A for ctrl0 only
        lsrb             ; set A in place
        stb   @b         ; set ora operator
        ora   #0         ; merge bits
@b      equ   *-1
        sta   @a         ; save value
        tfr   x,d
        anda  #%00001111 ; keep RLDU in place, dpad values are in register A
        andb  #%01000000 ; filter B for ctrl0 only
        lsrb
        lsrb             ; set B in place
        orb   #0         ; merge bits, fire values are in register B
@a      equ   *-1

        ; process dpad
        coma                              ; reverse bits to get 0:released 1:pressed
        sta   @a
        lda   joypad.md6.ctrl0.held.dpad
        eora  @a
        anda  @a
        sta   joypad.md6.ctrl0.press.dpad ; store only new pressed pads
        lda   #0
@a      equ   *-1
        sta   joypad.md6.ctrl0.held.dpad  ; store current pressed state

        ; process fire
        comb                              ; reverse bits to get 0:released 1:pressed
        stb   @b
        ldb   joypad.md6.ctrl0.held.fire
        eorb  @b
        andb  @b
        stb   joypad.md6.ctrl0.press.fire ; store only new pressed btns
        ldb   #0
@b      equ   *-1
        stb   joypad.md6.ctrl0.held.fire  ; store current pressed state
        rts
