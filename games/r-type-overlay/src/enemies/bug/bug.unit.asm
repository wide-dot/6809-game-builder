;*******************************************************************************
; bug — ennemi porté de la v1
;
; Le code v1 est repris tel quel ; l'unité porte les en-têtes communs et la
; table de liaison des images. Elle est paginée : RunObjects lit sa page dans
; l'index d'objets du stage, la monte, puis saute à l'entrée.
;
; L'entrée doit être le premier octet de l'unité : le code d'abord, les tables
; ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

bug.Object   EXPORT

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
Img_bug_0                    equ set_bug_0
Img_bug_1                    equ set_bug_1
Img_bug_2                    equ set_bug_2
Img_bug_3                    equ set_bug_3
Img_bug_4                    equ set_bug_4
Img_bug_5                    equ set_bug_5
Img_bug_6                    equ set_bug_6
Img_bug_7                    equ set_bug_7
Img_bug_8                    equ set_bug_8
Img_bug_9                    equ set_bug_9
Img_bug_10                   equ set_bug_10
Img_bug_11                   equ set_bug_11
Img_bug_12                   equ set_bug_12
Img_bug_13                   equ set_bug_13
Img_bug_14                   equ set_bug_14
Img_bug_15                   equ set_bug_15

; V2-DEVIATION : l'entrée v1 s'appelle `Object`, un nom trop générique pour la
; frontière de lien.
; L'objet est COMMUN (stages 1, 4 et 7) : c'est la version FULL qui vit ici,
; avec les seize variantes de direction. obj_level1 (huit images, le reste
; rabattu sur bug_8) etait le sous-ensemble du seul stage 1.
bug.Object
        INCLUDE "src/enemies/bug/obj_full.asm"

 ENDSECTION
