 SECTION code

        ldu   #$A000
        ldx   #pixels.even
        lda   #pixels.even.end-pixels.even
!       ldb   ,x+
        stb   ,u+
        deca
        bne   <
        ldu   #$A000
        ldx   #pixels.odd
        lda   #pixels.odd.end-pixels.odd
!       ldb   ,x+
        stb   ,u+
        deca
        bne   <
        rts

pixels.even
        fcb   $01,$45,$89,$CD
pixels.even.end

pixels.odd
        fcb   $23,$67,$AB,$EF
pixels.odd.end

 ENDSECTION