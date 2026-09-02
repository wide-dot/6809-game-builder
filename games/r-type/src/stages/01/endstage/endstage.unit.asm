;*******************************************************************************
; endstage — le sequenceur de fin du stage 1, porte de la v1
;
; Objet MONTE, pas cree : le stage l'appelle avec une commande en B (INIT, TICK
; ou BLIT) et il rend un statut. Il porte la logique de fin de niveau — compte
; a rebours, autopilote du vaisseau, fondu pixel, releve du score — hors de la
; RAM residente, qui est saturee.
;
; L'etat qu'il partage avec le boss (le pas de deplacement commun, les drapeaux
; de mort) est resident dans le stage : voir src/stages/01/main.asm.
;
; L'entree doit etre le premier octet de l'unite : le code d'abord, les tables
; ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************
endstage.Object   EXPORT

        INCLUDE "src/common/engine/api.asm"

; L'index d'objets du stage : la sequence fait tourner d'autres objets.
Obj_Index_Page    EXTERNAL
Obj_Index_Address EXTERNAL

; L'etat resident du sequencement, ecrit ici et lu par les six objets du boss.
; C'est l'objet qui le remet a zero (commande INIT), a l'ouverture du niveau et
; au rechargement de checkpoint.
main.timestamp.moveAlienStart  EXTERNAL
main.dobkeratops.move.frame    EXTERNAL
main.dobkeratops.move.step     EXTERNAL
main.dobkeratops.move.left     EXTERNAL
main.dobkeratops.halfDamage    EXTERNAL
main.dobkeratops.nervesErasing EXTERNAL
main.dobkeratops.explode       EXTERNAL
main.endstage.counter          EXTERNAL
main.endstage.phase            EXTERNAL
main.endstage.scoreArmed       EXTERNAL
main.endstage.scoreDone        EXTERNAL

; La palette de noir, dans le stage avec celle du jeu : la sequence l'installe
; avant de rendre la main, pour que la coupure ne se voie pas.
Pal_black                      EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        ; Les champs de l'OST du joueur (beam_value, is_charging) : la sequence
        ; eteint la charge du faisceau au passage en autopilote.
        INCLUDE "src/common/player/player1.equ"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/objects/palette/fade/fade.equ"
        INCLUDE "src/stages/01/objid.const.asm"
        ; La chronologie du boss et les reperes de la sequence de fin.
        INCLUDE "src/stages/01/timestamps.const.asm"
        INCLUDE "src/common/state/variables.asm"
        ; Les pas de deplacement en 8.8 : l'autopilote s'en sert.
        INCLUDE "src/common/lib/scale.asm"
        ; La geometrie de la carte de CE stage.
        INCLUDE "gen/stages/01/map/map.const.asm"

; V2-DEVIATION : la v1 declare ces deux constantes dans son main ; en v2 la
; largeur de carte vit dans les constantes de la carte du stage, et la boucle
; commune calcule le meme plafond (map.COLS*12-144).
map_width       equ map.COLS*12
viewport_width  equ 144

; V2-DEVIATION : l'entree v1 s'appelle `Object`, un nom trop generique pour la
; frontiere de lien.
endstage.Object
        INCLUDE "src/stages/01/endstage/obj_endstage.asm"

 ENDSECTION
