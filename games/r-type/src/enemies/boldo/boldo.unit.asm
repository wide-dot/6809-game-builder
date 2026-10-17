;*******************************************************************************
; boldo — the stage 7 floating obstacle, its own direntry (stage7.boldo)
;
; The object and its four slices (tools/gen_boldo_slices.py). The slices are
; the same object born with its id and a marked subtype. The entry is the
; FIRST byte of the unit (docs/lang/en/migration/unit-entry-point.md).
; Porting sheet: obj.asm.
;*******************************************************************************

boldo.Object EXPORT

        INCLUDE "src/common/engine/api.asm"

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
        INCLUDE "src/common/fx/explosion/explosion.const.asm"

        INCLUDE "src/enemies/boldo/obj.asm"

 ENDSECTION
