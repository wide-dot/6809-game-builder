;*******************************************************************************
; mikun — the stage 8 swarm, its own direntry (stage8.mikun)
;
; The invisible emitter a wave line creates and the mikun it launches share
; this page with the poses of directions 0-7 (pre-shifted variants included);
; directions 8-15 have theirs in stage8.mikun.img, reached through a second
; object id (ObjID_mikun_unit2). The entry is the FIRST byte of the unit
; (docs/lang/en/migration/unit-entry-point.md). Porting sheet: obj.asm.
;*******************************************************************************

mikun.Object EXPORT
mikun.Unit   EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "src/stages/08/objid.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"

        INCLUDE "src/enemies/mikun/obj.asm"

 ENDSECTION
