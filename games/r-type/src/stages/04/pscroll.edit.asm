;*******************************************************************************
; pscroll.edit — la part PAGINEE du champ de gommes du stage 4
;
; Gravure, scroll, ajout, effacement : ~11,3 Ko qui ne tiennent pas en RAM fixe
; et n'en ont pas besoin. Aucune de ces phases ne touche l'ecran, la page peut
; donc etre montee en $A000 — la fenetre DONNEES — le temps de l'appel.
;
; POURQUOI $A000 MARCHE SANS RIEN TOUCHER. Les deux demi-pages sont echangees
; dans cette zone (mesure du 23/08 : offset $0000 se voit en $C000, $2000 en
; $A000). Mais le loader ecrit par la MEME fenetre — ram.set choisit d'apres
; l'adresse de destination, et $A000 lui fait monter la page dans la zone
; donnees. L'inversion s'applique donc a l'ecriture comme a la lecture et
; s'annule : le code se relit lineairement a $A000. Rien a corriger, ni dans
; le builder, ni dans l'arithmetique du module.
;
; La page est RESERVEE a cet usage : son contenu physique est dans l'ordre
; echange, rien d'autre ne peut y cohabiter.
;*******************************************************************************

pscroll.stage4.init EXPORT
pscroll.grow        EXPORT
collisionMapForeground EXTERNAL
pscroll.move        EXPORT              ; la trame residente l'appelle par page
pscroll.field.map   EXPORT              ; le stage l'emplit au demarrage

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
PSCROLL_PART       equ 1                ; la part paginee

 SECTION code

        INCLUDE "engine/graphics/tilemap/pscroll/pscroll.asm"
        INCLUDE "src/stages/04/pscroll-rows.asm"

; -----------------------------------------------------------------------------
; pscroll.stage4.init — poser la couche, puis graver les dix bandes
; -----------------------------------------------------------------------------
; input REG : [d] la position camera de depart
; Appelee page montee. ~160 000 cycles : l'ouverture du stage et le checkpoint.
; -----------------------------------------------------------------------------
pscroll.stage4.init
        pshs  d
        ; le bitfield, depuis la carte de collision. On est DANS la page du
        ; module (fenetre donnees) : la fenetre cartouche est libre pour la
        ; carte, et field.map est ici meme.
        lda   #map.RAM_OVER_CART+collision.page
        _SetCartPageA
        ldx   #collisionMapForeground
        ldu   #pscroll.field.map
!       ldd   ,x++
        std   ,u++
        cmpu  #pscroll.field.map+pscroll.MAP_STRIDE*pscroll.ROWS
        blo   <
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
        ldd   #pscroll.field.map
        std   pscroll.map.address
        puls  d
        jmp   pscroll.init

        INCLUDE "src/stages/04/pscroll-grow.asm"

; LE BITFIELD DES GOMMES — dans CETTE page, avec le code qui le lit et l'ecrit.
; setCell et clearCell tournent page montee : le bitfield y est donc visible.
; `do`, lui, n'y touche jamais.
pscroll.field.map
        fill  0,pscroll.MAP_STRIDE*pscroll.ROWS
