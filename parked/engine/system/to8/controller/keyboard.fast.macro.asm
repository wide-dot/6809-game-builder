 IFNDEF keyboard.fast.macro.asm
keyboard.fast.macro.asm equ 1

_keyboard.fast.ktst MACRO
        lda   map.MC6821.PRA            ; Test KTST bit (PA0)
        lsra                            ; Move to carry
 ENDM

_keyboard.fast.flush MACRO
        lda   map.MC6846.PDR            ; Read PDR
        anda  #$DF                      ; Clear PP5 (ready)
        sta   map.MC6846.PDR            ; Save PDR
        ldb   map.MC6846.PCR            ; Read PCR
        andb  #$FC                      ; Clear bits 0-1
        stb   map.MC6846.PCR            ; Save PCR
        ora   #$20                      ; Set PP5 (done)
        sta   map.MC6846.PDR            ; Save PDR
        coma                            ; Set carry = 1 (key pressed)
 ENDM

_keyboard.fast.check MACRO
        jsr   keyboard.fast.check
 ENDM

_keyboard.fast.waitKey MACRO
@loop   jsr   keyboard.fast.check
        beq   @loop
 ENDM

 ENDC