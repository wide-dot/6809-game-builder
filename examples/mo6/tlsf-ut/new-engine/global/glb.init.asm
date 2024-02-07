;-----------------------------------------------------------------
; glb.init
; reset  REG : [D] [X]
;-----------------------------------------------------------------
; Init common global values
;----------------------------------------------------------------- 

glb.init       EXPORT

 SECTION code
glb.init
        ; clear direct_page data
        ldd   #0
        ldx   #dp
!       std   ,x++
        cmpx  #dp+256
        bne   <

        lda   #1
        sta   glb_alphaTiles
        rts
 ENDSECTION