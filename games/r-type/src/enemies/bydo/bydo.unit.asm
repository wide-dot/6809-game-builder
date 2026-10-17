;*******************************************************************************
; bydo — the stage 8 boss, its own direntry (stage8.bydo)
;
; The core, the grouped renderer of the wins, the tentacle patches and the
; wins share this page; the head's five frames have their own. The entry is the
; FIRST byte of the unit (docs/lang/en/migration/unit-entry-point.md).
; Porting sheet: obj.asm.
;*******************************************************************************

bydo.Object EXPORT
bydo.Render EXPORT

        INCLUDE "src/common/engine/api.asm"

Obj_Index_Page    EXTERNAL
Obj_Index_Address EXTERNAL
Img_Page_Index    EXTERNAL

; the head's five frames, on their own page (stage8.bydo.head)
set_bydo_head_0   EXTERNAL
set_bydo_head_1   EXTERNAL
set_bydo_head_2   EXTERNAL
set_bydo_head_3   EXTERNAL
set_bydo_head_4   EXTERNAL

; resident, in the stage 8 main: the ending's clock, set at the death
ending.gc0        EXTERNAL
ending.music      EXTERNAL
; the palette fade to black (stage-main), the bg's fade (40:C238)
stage.deathFadeOut EXTERNAL
; the wreck of the chamber, a stamp on the stage 8 map (stage8.maps)
wreck             EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "src/stages/08/objid.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"
        INCLUDE "src/common/lib/object.const.asm"
        INCLUDE "gen/layout.asm"

; the pages of the pictures (the patches are drawn by the stage's front hook)
bydo.PG       equ stage8.bydo.page
bydo.PG_HEAD  equ stage8.bydo.head.page

        INCLUDE "src/enemies/bydo/obj.asm"

 ENDSECTION
