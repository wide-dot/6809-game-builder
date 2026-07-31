_vgc.obj.play MACRO
        _ram.cart.set \1 ; this macro should use register A
    	ldx   \2       ; vgc.data
        ldb   \3       ; vgc.loop
        ldy   \4       ; vgc.callback
        jsr   vgc.obj.play
 ENDM

_vgc.frame.play MACRO
        _ram.cart.set \1
        jsr   vgc.frame.play
 ENDM