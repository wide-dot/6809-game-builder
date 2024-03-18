_ymm.obj.play MACRO
        lda   \1       ; ymm.data.page
    	ldx   \2       ; ymm.data
        ldb   \3       ; ymm.loop
        ldy   \4       ; ymm.callback
        jsr   ymm.obj.play
 ENDM

_ymm.frame.play MACRO
        jsr   ymm.frame.play
 ENDM