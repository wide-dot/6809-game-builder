;*******************************************************************************
; tabrok — ennemi porté de la v1 (stage 1)
;
; Le code v1 est repris tel quel ; l'unité porte les en-têtes communs et la
; table de liaison des images. Elle est paginée : RunObjects lit sa page dans
; l'index d'objets du stage, la monte, puis saute à l'entrée.
;
; L'entrée doit être le premier octet de l'unité : le code d'abord, les tables
; ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

tabrok.Object   EXPORT

        INCLUDE "src/common/engine/api.asm"

; L'index d'objets du stage chargé : les macros de tir y lisent la page et
; l'adresse des sous-routines paginées avant de les faire monter.
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
        INCLUDE "src/common/fx/animation/index.equ"
        INCLUDE "src/common/lib/projectile.macro.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"
        ; Les pas de deplacement en 8.8, constantes de jeu partagees.
        INCLUDE "src/common/lib/scale.asm"

; V2-DEVIATION : la v1 nomme ses entrées d'imageset `Img_<nom>`, gfxcomp les
; génère en `set_<nom>`. Une table de liaison laisse le fichier v1 au 1:1.
; Les properties v1 : 0..7 = tabrok_*.png tel quel, 12..15 = les images 4..7 en
; miroir X (le tank marche dans les deux sens). Pas de 8..11 : la v1 n'en
; déclare aucune, et le code ne les cite pas.
Img_tabrok_0                 equ set_tabrok_0
Img_tabrok_1                 equ set_tabrok_1
Img_tabrok_2                 equ set_tabrok_2
Img_tabrok_3                 equ set_tabrok_3
Img_tabrok_4                 equ set_tabrok_4
Img_tabrok_5                 equ set_tabrok_5
Img_tabrok_6                 equ set_tabrok_6
Img_tabrok_7                 equ set_tabrok_7
Img_tabrok_8                 equ set_tabrok_8    ; flash de coup, vol, tourne a gauche
Img_tabrok_9                 equ set_tabrok_9    ; flash de coup, vol, tourne a droite
Img_tabrok_10                equ set_tabrok_10   ; flash de coup, au sol, tourne a gauche
Img_tabrok_11                equ set_tabrok_11   ; flash de coup, au sol, tourne a droite
Img_tabrok_12                equ set_tabrok_12
Img_tabrok_13                equ set_tabrok_13
Img_tabrok_14                equ set_tabrok_14
Img_tabrok_15                equ set_tabrok_15

; V2-DEVIATION : l'entrée v1 s'appelle `Object`, un nom trop générique pour la
; frontière de lien.
tabrok.Object
        INCLUDE "src/enemies/tabrok/obj.asm"

 ENDSECTION
