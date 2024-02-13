_vgc.obj.play MACRO
        lda   \1       ; vgc.data.page
    	ldx   \2       ; vgc.data
        ldb   \3       ; vgc.loop
        ldy   \4       ; vgc.callback
        jsr   vgc.obj.play
 ENDM

_vgc.frame.play MACRO
        jsr   vgc.frame.play
 ENDM