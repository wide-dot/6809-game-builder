_ram.cart.set MACRO 
        lda   \1
        ora   #map.RAM_OVER_CART
        sta   map.CF74021.CART      ; Set RAM over catridge space, switch RAM page
 ENDM

_ram.data.set MACRO 
        lda   #$10
        ora   map.CF74021.SYS1.R ; Set RAM
        sta   map.CF74021.SYS1.R ; over data
        sta   map.CF74021.SYS1   ; space
        ldb   \1
        stb   map.CF74021.DATA   ; Switch RAM page
 ENDM