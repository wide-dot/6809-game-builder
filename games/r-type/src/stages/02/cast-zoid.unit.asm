;*******************************************************************************
; Le zoid du stage 2, dans SON unite : la page du cast (stage2.cast) est
; pleine — l'ajouter la depassait les 16 Ko d'une page. Le zoid n'a aucun
; couplage de label avec le reste du cast : le brood ne touche que ses
; equates d'etat (zoid.equ) et les index d'objets pointent zoid.Object avec
; SA page — Obj_Run monte la page de chaque objet avant de le tiquer.
;*******************************************************************************

set_zoid_egg_0  EXTERNAL
set_zoid_egg_1  EXTERNAL
set_zoid_egg_2  EXTERNAL
set_zoid_egg_3  EXTERNAL
set_zoid_hatch_0  EXTERNAL
set_zoid_hatch_1  EXTERNAL
set_zoid_hatch_2  EXTERNAL
set_zoid_hatch_3  EXTERNAL
set_zoid_0  EXTERNAL
set_zoid_1  EXTERNAL
set_zoid_2  EXTERNAL
set_zoid_3  EXTERNAL
set_zoid_hit_0  EXTERNAL
zoid.Object      EXPORT

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

        INCLUDE "src/enemies/zoid/zoid.equ"
        INCLUDE "src/enemies/zoid/obj.asm"

 ENDSECTION
