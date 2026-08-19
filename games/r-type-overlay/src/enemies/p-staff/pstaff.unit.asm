;*******************************************************************************
; p-staff — ennemi porté de la v1 (stage 1)
;
; Le code v1 est repris tel quel ; l'unité porte les en-têtes communs et la
; table de liaison des images. Elle est paginée : RunObjects lit sa page dans
; l'index d'objets du stage, la monte, puis saute à l'entrée.
;
; L'entrée doit être le premier octet de l'unité : le code d'abord, les tables
; ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

pstaff.Object   EXPORT

        INCLUDE "src/common/engine/api.asm"

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
        INCLUDE "src/common/state/variables.asm"
        ; Les pas de deplacement en 8.8, constantes de jeu partagees.
        INCLUDE "src/common/lib/scale.asm"

; V2-DEVIATION : la v1 nomme ses entrées d'imageset `Img_<nom>`, gfxcomp les
; génère en `set_<nom>`. Une table de liaison laisse le fichier v1 au 1:1.
; Les properties v1 déclarent SIX images (0,1,2,6,8,9) et leurs six miroirs X
; (10,11,12,16,18,19) ; les indices manquants sont des alias, que le fichier v1
; pose lui-même en tête (Img_pstaff_3 equ Img_pstaff_0, etc.).
Img_pstaff_0                 equ set_pstaff_0
Img_pstaff_1                 equ set_pstaff_1
Img_pstaff_2                 equ set_pstaff_2
Img_pstaff_6                 equ set_pstaff_6
Img_pstaff_8                 equ set_pstaff_8
Img_pstaff_9                 equ set_pstaff_9
Img_pstaff_10                equ set_pstaff_10
Img_pstaff_11                equ set_pstaff_11
Img_pstaff_12                equ set_pstaff_12
Img_pstaff_16                equ set_pstaff_16
Img_pstaff_18                equ set_pstaff_18
Img_pstaff_19                equ set_pstaff_19

; V2-DEVIATION : l'entrée v1 s'appelle `Onject` (sic), un nom qui ne franchit
; pas la frontière de lien.
pstaff.Object
        INCLUDE "src/enemies/p-staff/obj.asm"

 ENDSECTION
