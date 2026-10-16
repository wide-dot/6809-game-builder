;*******************************************************************************
; bellmite — the stage 5 boss, its own direntry (stage5.bellmite)
;
; The manager and the grouped renderer share this page: the renderer draws
; the slots the manager publishes, and both read the same records. The entry
; is the FIRST byte of the unit (docs/lang/en/migration/unit-entry-point.md).
; Porting sheet: obj.asm.
;*******************************************************************************

bellmite.Object EXPORT
bellmite.Render EXPORT

        INCLUDE "src/common/engine/api.asm"

Obj_Index_Page    EXTERNAL
Obj_Index_Address EXTERNAL
Img_Page_Index    EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "src/stages/05/objid.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"

        INCLUDE "src/enemies/bellmite/obj.asm"

 ENDSECTION
