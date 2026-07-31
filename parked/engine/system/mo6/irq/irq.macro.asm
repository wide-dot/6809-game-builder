_irq.init MACRO
        ldd   #irq.manage
        std   map.TIMERPT
 ENDM

_irq.setRoutine MACRO
        ldd   \1
        std   irq.userRoutine
 ENDM

_irq.set50Hz MACRO
        ; dummy macro for code compatibility
        ; factory set to 50hz
 ENDM

_irq.on MACRO
        jsr   irq.on
 ENDM

_irq.off MACRO
        jsr   irq.off
 ENDM