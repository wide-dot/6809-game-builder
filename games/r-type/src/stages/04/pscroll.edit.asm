;*******************************************************************************
; pscroll.edit — la part CARTOUCHE du champ de gommes du stage 4
;
; Scroll, ajout, effacement, la carte et les sequences de colonnes : tout ce
; qui ne touche jamais un buffer. La page se monte dans la fenetre CARTOUCHE
; ($0000) par paged.call, comme n'importe quelle page du jeu — le loader sait
; l'ecrire, et les routines de la part $4000 la REMONTENT avant leur rts
; quand elles ont commute la fenetre pour un buffer.
;
; LE BITFIELD EST ICI. Il n'est lu et ecrit QUE par ce cote (mutate, clearRun,
; zone, grow — via pscroll.map.address) : feedBand, lui, lit des sequences
; generees, qu'il copie dans son staging AVANT de monter un buffer. La carte
; est `fill 0`, remplie a l'init depuis la carte de collision : le loader n'a
; rien a en charger.
;*******************************************************************************

pscroll.stage4.init EXPORT
pscroll.grow        EXPORT
pscroll.erase       EXPORT
pscroll.move        EXPORT              ; la trame residente l'appelle par page
pscroll.gum.map     EXTERNAL            ; la carte des gommes, RESIDENTE :
                                        ; elle est aussi le plan arriere de la
                                        ; collision du stage (gumres.unit.asm)
pscroll.half.on        EXTERNAL         ; la part $4000 n'est visible que
pscroll.half.off       EXTERNAL         ; demi-page 0 montee

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "gen/layout.asm"
        INCLUDE "gen/stages/04/map/map.const.asm"
field.MAP_W        equ map.COLS*12
field.VP_Y         equ 11
pscroll.CELL_W     equ 3
pscroll.BAND_LINES equ 180
pscroll.MAP_WIDTH  equ field.MAP_W
pscroll.MAX_SEAMS  equ 8
PSCROLL_PART       equ 1                ; la part cartouche

 SECTION code

        INCLUDE "engine/graphics/tilemap/pscroll/pscroll.asm"
        INCLUDE "src/stages/04/pscroll-rows.asm"

; -----------------------------------------------------------------------------
; pscroll.stage4.init — poser la couche, puis graver les dix bandes
; -----------------------------------------------------------------------------
; input REG : [d] la position camera de depart
; Appelee page montee (paged.call). ~160 000 cycles : l'ouverture du stage et
; le checkpoint.
; -----------------------------------------------------------------------------
pscroll.stage4.init
        ; ce que les routines de la part $4000 remonteront apres chaque
        ; commutation de buffer — a poser AVANT le premier appel a la part $4000
        lda   #map.RAM_OVER_CART+pscroll.edit.page
        sta   pscroll.cart.page
        ; TOUTE L'INIT appelle la part $4000 — buildSkeleton et feedBand
        ; depuis pscroll.init. Elle n'est visible que demi-page 0 montee :
        ; sans ca l'init grave dans le vide et le stage part avec un ruban
        ; muet.
        ; La carte des gommes, elle, est deja remplie : le main du stage a
        ; appele stage.checkpointReset (pellet.reset) juste avant, qui deplie
        ; le flux des gommes d'origine dans la carte residente.
        jsr   pscroll.half.on
        lda   #map.RAM_OVER_CART+pscroll.buf0.page
        sta   pscroll.buf.page
        lda   #map.RAM_OVER_CART+pscroll.buf1.page
        sta   pscroll.buf.page+1
        lda   #map.RAM_OVER_CART+pscroll.buf2.page
        sta   pscroll.buf.page+2
        lda   #map.RAM_OVER_CART+pscroll.buf3.page
        sta   pscroll.buf.page+3
        ldd   #$0000
        std   pscroll.buf.address
        std   pscroll.buf.address+2
        std   pscroll.buf.address+4
        std   pscroll.buf.address+6
        ldd   #$A000+(field.VP_Y+pscroll.BAND_LINES)*40
        std   pscroll.viewport.ram
        ldd   #field.MAP_W-160
        std   pscroll.camera.x.max
        ldd   #pscroll.gum.map
        std   pscroll.map.address
        ldd   pscroll.camera.x         ; posee par l'appelant : D servait a
        jsr   pscroll.init             ; porter la page pour paged.call
        jmp   pscroll.half.off         ; et la demi-page du jeu revient

        INCLUDE "src/stages/04/pscroll-grow.asm"

; LE BITFIELD DES GOMMES N'EST PLUS ICI (24/08/2026). Il a demenage en RAM
; RESIDENTE — src/stages/04/gumres.unit.asm, arene stage4.res — parce qu'il est
; devenu le PLAN ARRIERE de la collision du stage : terrainCollision le lit
; page collision montee, ou cette page-ci est invisible. C'est la meme carte
; des deux cotes, donc il n'y a plus rien a synchroniser.
;
; Ce qui part avec : la copie initiale (fillMap, supprimee) et le
; croisement avec le terrain dur. La carte se remplit maintenant du seul flux
; des gommes d'origine, deplie par pellet.reset.
