;*******************************************************************************
; shell — la rotonde du stage 1, portée de la v1
;
; Le code v1 est repris tel quel ; l'unité porte les en-têtes communs et la
; table de liaison des images. Elle est paginée : RunObjects lit sa page dans
; l'index d'objets du stage, la monte, puis saute à l'entrée.
;
; L'entrée doit être le premier octet de l'unité : le code d'abord, les tables
; ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

shell.Object   EXPORT

        INCLUDE "src/common/engine/api.asm"

; L'index d'objets du stage chargé : les macros de tir y lisent la page et
; l'adresse des sous-routines paginées avant de les faire monter.
Obj_Index_Page    EXTERNAL
Obj_Index_Address EXTERNAL

; La table d'effacement de la rotonde vit dans la RAM du stage : chaque shell y
; écrit sa position, l'effaceur la relit. Elle traverse donc la frontière de
; lien, comme toute donnée que deux unités se partagent.
shellEraseTable     EXTERNAL

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
        INCLUDE "src/common/lib/projectile.macro.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"
        ; Les pas de deplacement en 8.8, constantes de jeu partagees.
        INCLUDE "src/common/lib/scale.asm"

; V2-DEVIATION : la v1 nomme ses entrées d'imageset `Img_<nom>`, gfxcomp les
; génère en `set_<nom>`. Une table de liaison laisse le fichier v1 au 1:1.
; Les properties v1 déclarent DEUX variantes par image de rotonde et d'œil
; (ND0 et XYD0) : la rotonde tourne, chaque moitié est le miroir XY de l'autre.
; L'entrée d'imageset est la même — c'est le descripteur qui porte les deux
; rendus —, donc une seule liaison par nom.
Img_shell_0                  equ set_shell_0
Img_shell_1                  equ set_shell_1
Img_shell_2                  equ set_shell_2
Img_shell_3                  equ set_shell_3
Img_shell_4                  equ set_shell_4
Img_shell_5                  equ set_shell_5
Img_shell_6                  equ set_shell_6
Img_shell_7                  equ set_shell_7
Img_shelleye_0               equ set_shelleye_0
Img_shelleye_1               equ set_shelleye_1
Img_shelleye_2               equ set_shelleye_2
Img_shelleye_3               equ set_shelleye_3
Img_shelleye_4               equ set_shelleye_4
Img_shelleye_5               equ set_shelleye_5
Img_shelleye_6               equ set_shelleye_6
Img_shelleye_7               equ set_shelleye_7
Img_shellbroken              equ set_shellbroken

; V2-DEVIATION : l'entrée v1 s'appelle `Onject` (sic), un nom qui ne franchit
; pas la frontière de lien.
shell.Object
        INCLUDE "src/enemies/shell/obj.asm"

 ENDSECTION
