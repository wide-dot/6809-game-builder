;*******************************************************************************
; ending — the end of the game (stage 8), its own direntry (stage8.ending)
;
; The manager, the fleet's grouped renderer, the fleet's pictures, the
; director's tables and the playfield's frame (images/viewport, drawn by the
; stage's overlay in place of the game's mask) share this page; the credits'
; lines live in their own (credits.unit.asm). The entry is the FIRST byte of the unit
; (docs/lang/en/migration/unit-entry-point.md). Porting sheet: obj.asm.
;*******************************************************************************

ending.Object EXPORT
ending.Render EXPORT
ending.ClearField EXPORT

        INCLUDE "src/common/engine/api.asm"

Obj_Index_Page    EXTERNAL
Obj_Index_Address EXTERNAL
Img_Page_Index    EXTERNAL

; resident, in the stage 8 main: what the loop and its text drawer read
ending.rowText    EXTERNAL
ending.textY      EXTERNAL
ending.hudOff     EXTERNAL
ending.done       EXTERNAL
ending.gc0        EXTERNAL
ending.black      EXTERNAL
ending.music      EXTERNAL
ending.Slots      EXTERNAL              ; the fleet's slots, filled by fleet.unit
ending.clock      EXTERNAL              ; the clock it reads
fleet.Init        EXTERNAL
fleet.Update      EXTERNAL
; the engine's starfield (common.starfield), armed through paged.call
starfield.init    EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "src/stages/08/objid.const.asm"
        INCLUDE "src/common/state/variables.asm"
        INCLUDE "src/common/lib/object.const.asm"
        INCLUDE "gen/layout.asm"

ending.PG     equ stage8.ending.page

        INCLUDE "src/stages/08/ending/obj.asm"
        INCLUDE "src/stages/08/ending/clear.asm"

 ENDSECTION
