;-----------------------------------------------------------------
; glb.init
; reset  REG : [D] [X]
;-----------------------------------------------------------------
; Init common global values
;----------------------------------------------------------------- 

glb.init       EXPORT

 SECTION code
glb.init
        ldd   #0

        ; clear direct_page data
        ldx   #dp
        lda   #0
!       sta   ,x+
        cmpx  #dp+256
        bne   <

        lda   #1
        sta   glb_alphaTiles
        rts
 ENDSECTION