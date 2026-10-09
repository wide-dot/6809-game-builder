_gfxmode.set40C MACRO
        ; 320x200x16c with constraint of only 2 colors each 8 horizontal pixels
        lda   #$00
        sta   map.CF74021.LGAMOD
 ENDM

_gfxmode.set80C MACRO
        ; 640x200x2c
        lda   #$2A
        sta   map.CF74021.LGAMOD
 ENDM

_gfxmode.setBM4 MACRO
        ; 320x200x4c, bitmap 4 : a pixel's index split over the two planes,
        ; its high bit in RAMA, its low bit in RAMB, at the same address
        lda   #$21
        sta   map.CF74021.LGAMOD
 ENDM

_gfxmode.setBM4S MACRO
        ; 320x200x4c, bitmap 4 "special" (TO8/TO8D/TO9+ only, not the TO9 nor
        ; the MO6) : the BM16 byte layout with 2-bit pixels, so a byte holds
        ; four pixels and RAMA the four left of RAMB's. Code compiled by
        ; gfxcomp videomode="bm4s" draws in it through the BM16 runtime
        lda   #$41
        sta   map.CF74021.LGAMOD
 ENDM

_gfxmode.setBM16 MACRO
        ; 160x200x16c
        lda   #$7B
        sta   map.CF74021.LGAMOD
 ENDM

_gfxmode.setLayer1 MACRO
        ; layer 1 : 320x200, 2 colors
        lda   #$24
        sta   map.CF74021.LGAMOD
 ENDM

_gfxmode.setLayer2 MACRO
        ; layer 2 : 320x200, 2 colors
        lda   #$25
        sta   map.CF74021.LGAMOD
 ENDM

_gfxmode.set2Layers MACRO
        ; layer 1 : 320x200, 2 colors
        ; layer 2 : 320x200, 1 color + alpha
        lda   #$26
        sta   map.CF74021.LGAMOD
 ENDM

_gfxmode.set4Layers MACRO
        ; layer 1 : 160x200, 2 colors
        ; layer 2 : 160x200, 1 color + alpha
        ; layer 3 : 160x200, 1 color + alpha
        ; layer 4 : 160x200, 1 color + alpha
        lda   #$3F
        sta   map.CF74021.LGAMOD
 ENDM
