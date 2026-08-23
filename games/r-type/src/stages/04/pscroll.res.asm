;*******************************************************************************
; pscroll.res — la part RESIDENTE du champ de gommes du stage 4
;
; Ce qui doit rester en RAM fixe, et rien de plus :
;   - `do`, qui peint la fenetre depuis le ruban. Il lui faut l'ECRAN monte en
;     $A000 ; la page du module n'y est donc pas a cet instant ;
;   - `runBuffer`, qu'il appelle ;
;   - TOUTES les variables du module, pour la meme raison : `do` ne peut pas
;     lire une variable qui vivrait dans une page non montee.
;
; Le reste — gravure, scroll, ajout, effacement — vit dans pscroll.edit, une
; page montee en $A000 le temps de l'appel. C'est possible parce qu'aucune de
; ces phases n'a besoin de l'ecran.
;*******************************************************************************

pscroll.stage4.frame EXPORT

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
PSCROLL_PART       equ 0                ; la part residente

pscroll.move       EXTERNAL              ; l'autre moitie, en page
paged.call         EXTERNAL

 SECTION code

        INCLUDE "engine/graphics/tilemap/pscroll/pscroll.asm"

; -----------------------------------------------------------------------------
; pscroll.stage4.frame — la trame : peindre ici, avancer dans la page
; -----------------------------------------------------------------------------
; input REG : [d] la vitesse camera 8.8 de la trame
;
; `do` peint d'abord — c'est lui qui remplace l'effacement du champ, et il a
; besoin de l'ecran monte. `move` ensuite, dans la page du module : il grave ce
; qui entre et n'a plus besoin de l'ecran. L'appelant remonte sa page ecran
; apres, ce que la trame fait en dessinant.
; -----------------------------------------------------------------------------
pscroll.stage4.frame
        std   pscroll.camera.speedx
        jsr   pscroll.do
        lda   #map.RAM_OVER_CART+pscroll.edit.page
        ldx   #pscroll.move
        jmp   paged.call
