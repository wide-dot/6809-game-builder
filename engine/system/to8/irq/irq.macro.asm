_irq.init MACRO
        ldd   #irq.manage
        std   map.TIMERPT
 ENDM

_irq.setRoutine MACRO
        ldd   \1
        std   irq.userRoutine
 ENDM

_irq.set50Hz MACRO
        ldd   #255                     ; set sync out of display
        ldx   #irq.ONE_FRAME           ; for palette changes
        jsr   irq.syncScreenLine
 ENDM

_irq.on MACRO
        jsr   irq.on
 ENDM

_irq.off MACRO
        jsr   irq.off
 ENDM