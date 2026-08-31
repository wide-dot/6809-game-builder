;*******************************************************************************
; Brood et wick du stage 2, dans LEUR unite : la page du cast (stage2.cast)
; est pleine a l'octet depuis la campagne gomander (31/08/2026) — les deux
; membres SANS AUCUN couplage de label avec le reste du cast en sortent,
; comme le zoid avant eux. Le brood ne touche que les equates du zoid
; (zoid.equ, des graines dans l'OST) et les index d'objets pointent
; brood.Object / wick.Object / wick.Unit avec LEUR page — Obj_Run monte la
; page de chaque objet avant de le tiquer. Un SEUL direntry pour les deux :
; le repertoire du disque est la denree rare (cf. cast.unit.asm).
;*******************************************************************************

set_brood_0  EXTERNAL
set_brood_1  EXTERNAL
set_brood_2  EXTERNAL
set_brood_3  EXTERNAL
set_brood_4  EXTERNAL
set_brood_5  EXTERNAL
set_brood_6  EXTERNAL
set_brood_7  EXTERNAL
set_wick_0  EXTERNAL
set_wick_1  EXTERNAL
set_wick_2  EXTERNAL
set_wick_3  EXTERNAL
set_wick_4  EXTERNAL
set_wick_5  EXTERNAL
set_wick_6  EXTERNAL
set_wick_7  EXTERNAL
set_wick_8  EXTERNAL
set_wick_9  EXTERNAL
set_wick_10  EXTERNAL
set_wick_11  EXTERNAL
set_wick_12  EXTERNAL
set_wick_13  EXTERNAL
set_wick_14  EXTERNAL
set_wick_15  EXTERNAL
set_wick_16  EXTERNAL
set_wick_17  EXTERNAL
set_wick_18  EXTERNAL
set_wick_19  EXTERNAL
set_wick_20  EXTERNAL
set_wick_21  EXTERNAL
set_wick_22  EXTERNAL
set_wick_23  EXTERNAL
set_wick_24  EXTERNAL
set_wick_25  EXTERNAL
set_wick_26  EXTERNAL
set_wick_27  EXTERNAL
set_wick_28  EXTERNAL
set_wick_29  EXTERNAL
set_wick_30  EXTERNAL
set_wick_31  EXTERNAL
set_brood_hit_0  EXTERNAL
set_brood_hit_1  EXTERNAL
set_brood_hit_2  EXTERNAL
set_brood_hit_3  EXTERNAL
brood.Object     EXPORT
wick.Object      EXPORT
wick.Unit        EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "src/stages/02/objid.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"
        INCLUDE "src/common/lib/scale.asm"
        INCLUDE "src/common/fx/animation/index.equ"

        INCLUDE "src/enemies/wick/obj.asm"
        INCLUDE "src/enemies/zoid/zoid.equ"
        INCLUDE "src/enemies/brood/obj.asm"

 ENDSECTION
