;*******************************************************************************
; mid — the stage 5 and 7 spinning vessel and its horizontal laser, one
; direntry of the shared library (lib.mid, arena `enemies`)
;
; The laser is the same object born with its father's id and a marked
; subtype: one entry, one page, nothing to align between the two stages'
; object ids. The entry is the FIRST byte of the unit
; (docs/lang/en/migration/unit-entry-point.md). Porting sheet: obj.asm.
;*******************************************************************************

mid.Object EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/map.const.asm"
        ; the common ids (explosion) are the same in every stage
        INCLUDE "src/stages/01/objid.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"

        INCLUDE "src/enemies/mid/obj.asm"

 ENDSECTION
