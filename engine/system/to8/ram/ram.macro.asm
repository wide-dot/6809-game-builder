* Garde d'inclusion : un membre de pageset porte plusieurs units qui
* incluent chacun cet en-tete. Un en-tete doit pouvoir etre inclus deux
* fois — c'est vrai independamment du pageset.
 IFNDEF TO8_RAM_MACRO
TO8_RAM_MACRO equ 1

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

 ENDC
