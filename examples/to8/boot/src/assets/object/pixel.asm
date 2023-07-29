gfx.ram.a EXTERN
gfx.ram.b EXTERN
dualpix1  EXTERN ; 8 bits
dualpix2  EXTERN ; 16 bits

pixels.even       EXPORT
pixels.odd        EXPORT
pixel.even.length EXPORT
pixel.odd.length  EXPORT

 SECTION absval,constant

pixel.even.length equ pixels.even.end-pixels.even
pixel.odd.length equ pixels.odd.end-pixels.odd

 ENDSECTION

 SECTION code
        ldu   #gfx.ram.b
        ldx   #pixels.even
        lda   #pixel.even.length
!       ldb   ,x+
        stb   ,u+
        deca
        bne   <
        ldu   #gfx.ram.a
        ldx   #pixels.odd
        lda   #pixel.odd.length
!       ldb   ,x+
        stb   ,u+
        deca
        bne   <
        rts

pixels.even
        fcb   $01,$45,$89,$CD,dualpix1 ; length 5 bytes
pixels.even.end

pixels.odd
        fdb   $2367,$ABEF,dualpix2-257 ; length 6 bytes
pixels.odd.end

 ENDSECTION