; ---------------------------------------------------------------------------
; generate a pseudo-random number in a, between param 1 and param 2
; ---------------------------------------------------------------------------
_random.a MACRO
        jsr   random.get
        lda   #\2-\1+1
        mul
 IFEQ \1-1
        inca
 ELSE IFNE \1
        adda  #\1
 ENDC
 ENDM  
 