_ymm.obj.play MACRO
        _ram.cart.set \1 ; this macro should use register A
    	ldx   \2       ; ymm.data
        ldb   \3       ; ymm.loop
        ldy   \4       ; ymm.callback
        jsr   ymm.obj.play
 ENDM

_ymm.frame.play MACRO
        _ram.cart.set \1
        jsr   ymm.frame.play
 ENDM