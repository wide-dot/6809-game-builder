;*******************************************************************************
; cytron — l'ennemi mecanique qui rampe sur les parois du stage 4
;
; Porte de l'arcade (create_cytron 0x40:696E, run_cytron 0x40:69B4) ; la fiche
; de portage complete est en tete de obj.asm.
;
; L'entree doit etre le premier octet de l'unite : le code d'abord, les tables
; ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

cytron.Object  EXPORT

        INCLUDE "src/common/engine/api.asm"

; L'index d'objets du stage charge : LoadObject y lit page et adresse de ce que
; cytron fait naitre (l'explosion de sa mort, le tir de foefire).
Obj_Index_Page    EXTERNAL
Obj_Index_Address EXTERNAL

; La repousse du champ de gommes vit dans le stage : c'est lui qui porte les
; cartes C et T et leur page. Une seule frontiere, un seul nom.
pscroll.grow      EXTERNAL

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
        INCLUDE "src/stages/04/objid.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"
        INCLUDE "src/common/lib/scale.asm"
        ; _loadFirePreset : le preset de tir, charge par sous-routine paginee.
        INCLUDE "src/common/lib/projectile.macro.asm"

cytron.Object
        INCLUDE "src/enemies/cytron/obj.asm"

 ENDSECTION
