; ---------------------------------------------------------------------------
; Object
;
; input REG : [u] pointer to Object Status Table (OST)
; ---------
;
; ---------------------------------------------------------------------------

; V2-DEVIATION : en-tete porte par l'enveloppe unit.
;        INCLUDE "./engine/macros.asm"
; V2-DEVIATION : en-tete porte par l'enveloppe unit.
;        INCLUDE "./global/variables.asm"

Object
        lda   routine,u
        asla
        ldx   #Routines
        jmp   [a,x]

Routines
        fdb   Init
        fdb   AlreadyDeleted

Init
        lda   #1
        sta   globals.nextGameMode

        inc   routine,u
        jmp   DeleteObject
AlreadyDeleted
        rts


