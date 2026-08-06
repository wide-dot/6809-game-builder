;*******************************************************************************
; scant — ennemi porté de la v1 (stage 1)
;
; Le code v1 est repris tel quel ; l'unité porte les en-têtes communs et la
; table de liaison des images. Elle est paginée : RunObjects lit sa page dans
; l'index d'objets du stage, la monte, puis saute à l'entrée.
;
; L'entrée doit être le premier octet de l'unité : le code d'abord, les tables
; ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

scant.Object   EXPORT

        INCLUDE "src/common/engine/api.asm"

; L'index d'objets du stage chargé : LoadObject y lit page et adresse de ce
; que scant fait naître (scantfire, emitter_flash).
Obj_Index_Page    EXTERNAL
Obj_Index_Address EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/map.const.asm"
        ; Les identifiants d'objets sont des CONSTANTES, pas des externes : le
        ; code les combine par décalage, ce qu'aucune relocation ne sait faire.
        INCLUDE "src/stages/01/objid.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/player/emitter-flash.equ"
        INCLUDE "src/common/state/variables.asm"
        ; Les pas de deplacement en 8.8, constantes de jeu partagees.
        INCLUDE "src/common/lib/scale.asm"

; V2-DEVIATION : la v1 nomme ses entrées d'imageset `Img_<nom>`, gfxcomp les
; génère en `set_<nom>`. Une table de liaison laisse le fichier v1 au 1:1.
; Les properties v1 : 0..2 = scant_v2_*.png tel quel, 3..5 = les mêmes en
; miroir X (l'ennemi regarde des deux côtés).
Img_scant_0                  equ set_scant_0
Img_scant_1                  equ set_scant_1
Img_scant_2                  equ set_scant_2
Img_scant_3                  equ set_scant_3
Img_scant_4                  equ set_scant_4
Img_scant_5                  equ set_scant_5

; V2-DEVIATION : l'entrée v1 s'appelle `Onject` (sic), un nom qui ne franchit
; pas la frontière de lien.
scant.Object
        INCLUDE "src/enemies/scant/obj.asm"

 ENDSECTION
