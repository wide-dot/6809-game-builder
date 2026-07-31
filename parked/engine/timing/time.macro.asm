; -----------------------------------------------------------------------------
; time.macro - Macros for timing functions
; -----------------------------------------------------------------------------

_time.ms.wait MACRO
        ldx     \1           ; Load millisecond count
        jsr     time.ms.wait ; Call wait routine
 ENDM
