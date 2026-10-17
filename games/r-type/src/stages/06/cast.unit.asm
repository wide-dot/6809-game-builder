;*******************************************************************************
; the stage 6 cast — the wave's Dops and Newts, one direntry (stage6.cast)
;
; Both probe the whole stage map (dop.Map, here once) through the same probe
; (dop.Solid, the arcade's tile RAM ring included). The Dops' pictures are the
; boss's (stage6.dopswarm, the page Img_Page_Index gives ObjID_dop); the
; Newts' and their shots' are in stage6.newt.img (ObjID_newt's). Two entries, each its object's first
; instruction (docs/lang/en/migration/unit-entry-point.md).
; Porting sheets: src/enemies/dop/dops.asm, src/enemies/newt/obj.asm.
;*******************************************************************************

dop.Object  EXPORT
newt.Object EXPORT

        INCLUDE "src/common/engine/api.asm"

dops.boxes        EXTERNAL           ; resident, stage 6 main
dops.used         EXTERNAL
; _loadFirePreset reads its subroutine's page and address in the stage's
; object index
Obj_Index_Page    EXTERNAL
Obj_Index_Address EXTERNAL
set_dop_right_0   EXTERNAL
set_dop_right_1   EXTERNAL
set_dop_right_2   EXTERNAL
set_dop_right_3   EXTERNAL
set_dop_righthit  EXTERNAL
set_dop_left_0    EXTERNAL
set_dop_left_1    EXTERNAL
set_dop_left_2    EXTERNAL
set_dop_left_3    EXTERNAL
set_dop_lefthit   EXTERNAL
set_newt_h_0      EXTERNAL
set_newt_h_1      EXTERNAL
set_newt_h_2      EXTERNAL
set_newt_h_3      EXTERNAL
set_newt_h_4      EXTERNAL
set_newt_ha_0     EXTERNAL
set_newt_ha_1     EXTERNAL
set_newt_ha_2     EXTERNAL
set_newt_ha_3     EXTERNAL
set_newt_ha_4     EXTERNAL
set_newt_va_0     EXTERNAL
set_newt_va_1     EXTERNAL
set_newt_va_2     EXTERNAL
set_newt_va_3     EXTERNAL
set_newt_va_4     EXTERNAL
set_newt_v_0      EXTERNAL
set_newt_v_1      EXTERNAL
set_newt_v_2      EXTERNAL
set_newt_v_3      EXTERNAL
set_newt_v_4      EXTERNAL
set_newt_hit_h_0  EXTERNAL
set_newt_hit_v_0  EXTERNAL
set_newtfire_0    EXTERNAL
set_newtfire_1    EXTERNAL
set_newtfire_2    EXTERNAL
set_newtfire_3    EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "src/stages/06/objid.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"
        INCLUDE "src/common/lib/object.const.asm"
        INCLUDE "src/common/lib/projectile.macro.asm"

        INCLUDE "src/enemies/dop/dops.asm"
        INCLUDE "src/enemies/newt/obj.asm"
        INCLUDE "src/stages/06/paths.asm"

 ENDSECTION
