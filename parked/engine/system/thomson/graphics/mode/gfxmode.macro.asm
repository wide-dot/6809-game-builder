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
        ; 160x200x4c
        lda   #$21
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
