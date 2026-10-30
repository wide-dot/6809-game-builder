 IFNDEF keyboard.fast.macro.asm
keyboard.fast.macro.asm equ 1

; C = 1 while a key is down (KTEST) ; Shift and CNT alone are no key
_keyboard.fast.ktst MACRO
        lda   map.MC6821.PRA
        lsra
 ENDM

_keyboard.fast.init MACRO
        jsr   keyboard.fast.init
 ENDM

_keyboard.fast.read MACRO
        jsr   keyboard.fast.read
 ENDM

; waits for a key pressed (not a repeat), its frame in D
_keyboard.fast.waitKey MACRO
@loop   jsr   keyboard.fast.read
        ldd   keyboard.fast.pressed
        bmi   @loop
 ENDM

 ENDC
