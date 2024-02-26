_cart.setRam MACRO 
        lda   \1
        sta   map.CF74021.CART      ; Set RAM over catridge space, switch RAM page
 ENDM

_data.setRam MACRO 
        lda   #$10
        ora   map.CF74021.SYS1.R ; Set RAM
        sta   map.CF74021.SYS1.R ; over data
        sta   map.CF74021.SYS1   ; space
        ldb   \1
        stb   map.CF74021.DATA   ; Switch RAM page
 ENDM