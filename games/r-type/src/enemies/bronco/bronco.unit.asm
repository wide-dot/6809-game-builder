;*******************************************************************************
; bronco — the stage 7 boss, its own direntry (stage7.bronco)
;
; The manager, the grouped renderer, the lamps and the main attacker's cells
; share this page; the junk and the chasers have a page each. The entry is
; the FIRST byte of the unit (docs/lang/en/migration/unit-entry-point.md).
; Porting sheet: obj.asm.
;*******************************************************************************

bronco.Object EXPORT
bronco.Render EXPORT

        INCLUDE "src/common/engine/api.asm"

Obj_Index_Page    EXTERNAL
Obj_Index_Address EXTERNAL
Img_Page_Index    EXTERNAL

; the cells on the other pages (stage7.bronco.junk, stage7.bronco.chaser),
; and the small junk, which is the bug (lib.bug, loaded in stage 7)
set_bronco_debris_0        EXTERNAL
set_bronco_debris_1        EXTERNAL
set_bronco_debris_2        EXTERNAL
set_bronco_debris_3        EXTERNAL
set_bronco_debris_4        EXTERNAL
set_bronco_debris_5        EXTERNAL
set_bronco_debris_6        EXTERNAL
set_bronco_debris_7        EXTERNAL
set_bronco_debris_8        EXTERNAL
set_bronco_debris_9        EXTERNAL
set_bronco_debris_10       EXTERNAL
set_bronco_debris_11       EXTERNAL
set_bronco_debris_strong_0 EXTERNAL
set_bronco_debris_rare_0   EXTERNAL
set_bronco_debris_rare_1   EXTERNAL
set_bronco_debris_geld_0   EXTERNAL
set_bronco_debris_geld_1   EXTERNAL
set_bronco_debris_pursuer_0 EXTERNAL
set_bronco_debris_pursuer_1 EXTERNAL
set_bronco_debris_pursuer_2 EXTERNAL
set_bronco_debris_pursuer_3 EXTERNAL
set_bronco_debris_pursuer_4 EXTERNAL
set_bronco_debris_pursuer_5 EXTERNAL
set_bronco_debris_pursuer_6 EXTERNAL
set_bronco_debris_pursuer_7 EXTERNAL
set_bronco_debris_pursuer_8 EXTERNAL
set_bronco_debris_pursuer_9 EXTERNAL
set_bronco_debris_pursuer_10 EXTERNAL
set_bronco_debris_pursuer_11 EXTERNAL
set_bronco_debris_pursuer_12 EXTERNAL
set_bronco_debris_pursuer_13 EXTERNAL
set_bronco_debris_pursuer_14 EXTERNAL
set_bronco_debris_pursuer_15 EXTERNAL
set_bronco_chaser_head_0   EXTERNAL
set_bronco_chaser_leg0_0   EXTERNAL
set_bronco_chaser_leg1_0   EXTERNAL
set_bronco_chaser_leg2_0   EXTERNAL
set_bronco_chaser_leg3_0   EXTERNAL
set_bronco_chaser_leg4_0   EXTERNAL
set_bronco_chaser_leg5_0   EXTERNAL
set_bronco_chaser_leg6_0   EXTERNAL
set_bronco_chaser_leg7_0   EXTERNAL
set_bronco_chaser_leg8_0   EXTERNAL
set_bronco_segment_0       EXTERNAL
set_bronco_segment_1       EXTERNAL
set_bronco_segment_2       EXTERNAL
set_bronco_segment_3       EXTERNAL
set_bug_2                  EXTERNAL
set_bug_10                 EXTERNAL

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
        INCLUDE "src/common/state/variables.asm"
        INCLUDE "src/common/lib/object.const.asm"
        INCLUDE "gen/layout.asm"

; the pages of the cells
bro.PG_MAIN   equ stage7.bronco.page
bro.PG_JUNK   equ stage7.bronco.junk.page
bro.PG_CHASER equ stage7.bronco.chaser.page
bro.PG_LAMP   equ stage7.bronco.lamps.page

        INCLUDE "src/enemies/bronco/obj.asm"

 ENDSECTION
