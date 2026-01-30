 IFNDEF keyboard.fast.macro.asm
keyboard.fast.macro.asm equ 1

_keyboard.fast.check MACRO
	ldb   \1
        stb   map.MC6821.PRB
        lda   map.MC6821.PRB
 ENDM

_keyboard.fast.waitKey MACRO
@loop   _keyboard.fast.check \1
        bmi   @loop
 ENDM

_keyboard.fast.disableBuzzer MACRO
        lda   map.STATUS
        ora   #map.STATUS.CUTBUZZER
        sta   map.STATUS
 ENDM

 ENDC