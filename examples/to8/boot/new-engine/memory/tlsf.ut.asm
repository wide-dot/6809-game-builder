;-----------------------------------------------------------------
; Unit Test for TLSF (Two Level Segregated Fit)
;-----------------------------------------------------------------
; Benoit Rousseau - 02/09/2023
;-----------------------------------------------------------------

tlsf.ut
        ldb   #15                ; page number
        lda   #$10
        ora   <$6081             ; Set RAM
        sta   <$6081             ; over data
        sta   >$e7e7             ; space
        orb   #$60               ; Set RAM over cartridge space
        stb   >map.CF74021.CART  ; Switch ram page

        jsr   tlsf.ut.init
        jsr   tlsf.ut.mappingSearch
        rts

tlsf.ut.init
        ; for default settings only
        ldd   #$0001
        ldx   #$1111
        jsr   tlsf.init
        ldd   tlsf.index
        cmpd  #$0008
        bne   *
        ldd   tlsf.index+2
        cmpd  #$0002
        bne   *
        ldd   tlsf.index+28
        cmpd  #$1111
        bne   *

        ldd   #$8000
        ldx   #$2222
        jsr   tlsf.init
        ldd   tlsf.index
        cmpd  #$8000
        bne   *
        ldd   tlsf.index+26
        cmpd  #$0001
        bne   *
        ldd   tlsf.index+410
        cmpd  #$2222
        bne   *

        rts

tlsf.ut.mappingSearch
        ; for default settings only
        ldx   #tlsf.ut.mappingSearch.in
        ldy   #tlsf.ut.mappingSearch.out
!       ldd   ,x++
        pshs  x,y
        jsr   tlsf.mappingSearch
        puls  x,y
        lda   tlsf.fl
        ldb   tlsf.sl
        cmpd  ,y++
        bne   *
        cmpx  #tlsf.ut.mappingSearch.in.end
        bne   <
        rts

tlsf.ut.mappingSearch.in
        fdb   %0000000000000000 ;      0
        fdb   %0000000000000001 ;      1
        fdb   %0000000000000010 ;      2
        fdb   %0000000000000011 ;    ...
        fdb   %0000000000000100
        fdb   %0000000000000101
        fdb   %0000000000000110
        fdb   %0000000000000111
        fdb   %0000000000001000
        fdb   %0000000000001001
        fdb   %0000000000001010
        fdb   %0000000000001011
        fdb   %0000000000001100
        fdb   %0000000000001101
        fdb   %0000000000001110
        fdb   %0000000000001111
        fdb   %0000000000010000
        fdb   %0000000000010001
        fdb   %0000000000010010
        fdb   %0000000000010011
        fdb   %0000000000010100
        fdb   %0000000000010101
        fdb   %0000000000010110
        fdb   %0000000000010111
        fdb   %0000000000011000
        fdb   %0000000000011001
        fdb   %0000000000011010
        fdb   %0000000000011011
        fdb   %0000000000011100
        fdb   %0000000000011101
        fdb   %0000000000011110 ;    ...
        fdb   %0000000000011111 ;     31

        fdb   %0000000000010000 ;     16
        fdb   %0000000000100010 ;     34
        fdb   %0000000001001000 ;     72
        fdb   %0000000010011000 ;    152
        fdb   %0000000101000000 ;    320
        fdb   %0000001010100000 ;    672
        fdb   %0000010110000000 ;  1 408
        fdb   %0000101110000000 ;  2 944
        fdb   %0001100000000000 ;  6 144
        fdb   %0011001000000000 ; 12 800
        fdb   %0110100000000000 ; 26 624
        fdb   %0110110000000000 ; 27 648
        fdb   %0111000000000000 ; 28 672
        fdb   %0111010000000000 ; 29 696
        fdb   %0111100000000000 ; 30 720
        fdb   %0111110000000000 ; 31 744

        fdb   %0000000000010001 ;     17
        fdb   %0000000000100011 ;     35
        fdb   %0000000001001001 ;     73
        fdb   %0000000010011001 ;    153
        fdb   %0000000101000001 ;    321
        fdb   %0000001010100001 ;    673
        fdb   %0000010110000001 ;  1 409
        fdb   %0000101110000001 ;  2 945
        fdb   %0001100000000001 ;  6 145
        fdb   %0011001000000001 ; 12 801
        fdb   %0110100000000001 ; 26 625
        fdb   %0110110000000001 ; 27 649
        fdb   %0111000000000001 ; 28 673
        fdb   %0111010000000001 ; 29 697
        fdb   %0111100000000001 ; 30 721
        fdb   %0111110000000001 ; 31 745
tlsf.ut.mappingSearch.in.end

tlsf.ut.mappingSearch.out
        fcb   0,0               ; fl,sl
        fcb   3,1
        fcb   3,2
        fcb   3,3
        fcb   3,4
        fcb   3,5
        fcb   3,6
        fcb   3,7
        fcb   3,8
        fcb   3,9
        fcb   3,10
        fcb   3,11
        fcb   3,12
        fcb   3,13
        fcb   3,14
        fcb   3,15
        fcb   4,0
        fcb   4,1
        fcb   4,2
        fcb   4,3
        fcb   4,4
        fcb   4,5
        fcb   4,6
        fcb   4,7
        fcb   4,8
        fcb   4,9
        fcb   4,10
        fcb   4,11
        fcb   4,12
        fcb   4,13
        fcb   4,14
        fcb   4,15

        fcb   4,0
        fcb   5,1
        fcb   6,2
        fcb   7,3
        fcb   8,4
        fcb   9,5
        fcb   10,6
        fcb   11,7
        fcb   12,8
        fcb   13,9
        fcb   14,10
        fcb   14,11
        fcb   14,12
        fcb   14,13
        fcb   14,14
        fcb   14,15

        fcb   4,1
        fcb   5,2 ; pb d'arrondi
        fcb   6,3
        fcb   7,4
        fcb   8,5
        fcb   9,6
        fcb   10,7
        fcb   11,8
        fcb   12,9
        fcb   13,10
        fcb   14,11
        fcb   14,12
        fcb   14,13
        fcb   14,14
        fcb   14,15
        fcb   15,0