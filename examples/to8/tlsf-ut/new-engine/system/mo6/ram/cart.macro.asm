_cart.setRam MACRO 
        lda   #map.RAM_OVER_CART+\1
        sta   map.CF74021.CART      ; selection de la page RAM en zone cartouche
 ENDM