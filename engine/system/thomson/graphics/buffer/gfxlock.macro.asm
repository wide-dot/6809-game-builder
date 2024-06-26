; ------------------------------------------------------------------------------
; macros
; ------------------------------------------------------------------------------

_gfxlock.init MACRO
        jsr   gfxlock.init
 ENDM

_gfxlock.on MACRO
        jsr   gfxlock.on
 ENDM

_gfxlock.off MACRO
        clr   gfxlock.status
 ENDM

_gfxlock.loop MACRO
        jsr   gfxlock.loop
 ENDM

_gfxlock.swap MACRO
        jsr   gfxlock.bufferSwap.check
 ENDM

_gfxlock.backProcess.on MACRO
        ; param 1 : routine address
        ldd   #\1
        std   gfxlock.backProcess.routine
        lda   #1
        sta   gfxlock.backProcess.status
 ENDM

_gfxlock.backProcess.off MACRO
        clr   gfxlock.backProcess.status
 ENDM

_gfxlock.memset MACRO
        _gfxlock.on
        ldx   \1
        jsr   gfxlock.memset
        _gfxlock.off
        _gfxlock.loop
 ENDM

_gfxlock.memset2 MACRO
        _gfxlock.on
        ldx   \1
        jsr   gfxlock.text.memset
        ldx   \2
        jsr   gfxlock.color.memset
        _gfxlock.off
        _gfxlock.loop
 ENDM

_gfxlock.halfPage.swap.on MACRO
        lda   #0
        sta   gfxlock.halfPage.swap.auto
 ENDM

_gfxlock.halfPage.swap.off MACRO
        lda   #1
        sta   gfxlock.halfPage.swap.auto
 ENDM

_gfxlock.halfPage.set0 MACRO
        lda   map.HALFPAGE
        anda  #%11111110
        sta   map.HALFPAGE
 ENDM

_gfxlock.halfPage.set1 MACRO
        lda   map.HALFPAGE
        ora   #%00000001
        sta   map.HALFPAGE
 ENDM

_gfxlock.screenBorder.update MACRO
        ldb   \1
        jsr   gfxlock.screenBorder.update
 ENDM
