; ---------------------------------------------------------------------------
; Object
;
; input REG : [u] pointer to Object Status Table (OST)
; ---------
;
; ---------------------------------------------------------------------------

; Include v1 retire (porte par l'unite — loading.unit.asm) :
; INCLUDE "./engine/macros.asm"

Object
        ldd   #Img_loading
        std   image_set,u
        ldb   #3
        stb   priority,u
        lda   render_flags,u
        ora   #render_playfieldcoord_mask
        sta   render_flags,u
        jmp   DisplaySprite