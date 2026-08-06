;*******************************************************************************
; dobkeratops_jaw — la machoire du boss, portee de la v1
;
; Objet a part entiere : le corps la fait naitre, elle s'ouvre et se referme.
;
; L'entree doit etre le premier octet de l'unite : le code d'abord, les
; tables ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************
dobkeratopsJaw.Object   EXPORT

        INCLUDE "src/common/engine/api.asm"

; L'index d'objets du stage charge : la machoire y lit ce qu'elle fait naitre.
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
        ; code les combine par decalage, ce qu'aucune relocation ne sait faire.
        INCLUDE "src/stages/01/objid.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"
        ; Les pas de deplacement en 8.8, constantes de jeu partagees.
        INCLUDE "src/common/lib/scale.asm"

; V2-DEVIATION : entrees d'imageset en set_<nom>.
Img_dobkeratops_jaw_0            equ set_dobkeratops_jaw_0
Img_dobkeratops_jaw_1            equ set_dobkeratops_jaw_1
Img_dobkeratops_jaw_2            equ set_dobkeratops_jaw_2

; V2-DEVIATION : l'entree v1 s'appelle `Object`, un nom trop generique pour la
; frontiere de lien.
dobkeratopsJaw.Object
        INCLUDE "src/enemies/dobkeratops/jaw.asm"

 ENDSECTION
