gfx.ram.a EXTERN
gfx.ram.b EXTERN
singlepix EXTERN ; 8 bits
dualpix   EXTERN ; 16 bits

pixel.draw        EXPORT
pixels.even       EXPORT
pixels.odd        EXPORT
pixel.even.length EXPORT
pixel.odd.length  EXPORT

 SECTION absval,constant
pixel.even.length equ pixels.even.end-pixels.even
pixel.odd.length equ pixels.odd.end-pixels.odd
 ENDSECTION

 SECTION code
pixel.draw
        nop
        ldu   #gfx.ram.b+40
        ldx   #pixels.even
        lda   #pixel.even.length
!       ldb   ,x+
        stb   ,u+
        deca
        bne   <
        ldu   #gfx.ram.a+40
        ldx   #pixels.odd
        lda   #pixel.odd.length
!       ldb   ,x+
        stb   ,u+
        deca
        bne   <
        rts

pixels.even
        fcb   $01,$45,$89,$CD,singlepix ; length 5 bytes
pixels.even.end

pixels.odd
        fdb   $2367,$ABEF,dualpix-257 ; length 6 bytes
pixels.odd.end
 ENDSECTION