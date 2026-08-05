;*******************************************************************************
; bink — le CORPS de l'unite, sans enveloppe
;
; Un <block> de pageset EST l'enveloppe : la source du membre ouvre la SECTION
; et pose le label d'entree pour tous ses blocs. Ce fichier ne porte donc ni
; SECTION, ni EXPORT, ni label — seulement les en-tetes et le code.
;
; bink.unit.asm est l'autre montage du meme corps : l'unite autonome d'un
; direntry, qui ouvre sa section elle-meme.
;*******************************************************************************
        INCLUDE "src/common/engine/api.asm"

; L'index d'objets du stage chargé : les macros de tir y lisent la page et
; l'adresse des sous-routines paginées avant de les faire monter.
Obj_Index_Page    EXTERNAL
Obj_Index_Address EXTERNAL


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
Img_bink_0                   equ set_bink_0
Img_bink_1                   equ set_bink_1
Img_bink_2                   equ set_bink_2
Img_bink_3                   equ set_bink_3
Img_bink_4                   equ set_bink_4
Img_bink_5                   equ set_bink_5
Img_bink_6                   equ set_bink_6
Img_bink_7                   equ set_bink_7
Img_bink_8                   equ set_bink_8
Img_bink_9                   equ set_bink_9
Img_bink_10                  equ set_bink_10
Img_bink_11                  equ set_bink_11

; V2-DEVIATION : l'entrée v1 s'appelle `Object`, un nom trop générique pour la
; frontière de lien.
        INCLUDE "src/enemies/bink/obj.asm"

