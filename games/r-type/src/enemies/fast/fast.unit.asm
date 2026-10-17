;*******************************************************************************
; fast — the stage 7 light fighter, its own direntry (stage7.fast)
;
; The object and its one pose (with its 1 px shifted variant). The entry is
; the FIRST byte of the unit (docs/lang/en/migration/unit-entry-point.md).
; Porting sheet: obj.asm.
;*******************************************************************************

fast.Object EXPORT

        INCLUDE "src/common/engine/api.asm"

; _loadFirePreset lit la page et l'adresse de sa sous-routine dans l'index
; d'objets du stage
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
        INCLUDE "src/stages/07/objid.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/lib/projectile.macro.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"

        INCLUDE "src/enemies/fast/obj.asm"

 ENDSECTION
