;*******************************************************************************
; Le cast du stage 3 — les pieces qui vivent sur le vaisseau
;
; Meme forme que le cast du stage 2 : UN direntry multi-asm, une unite par
; famille, chacune prefixant ses etiquettes de son nom. Le script de spawn les
; fait naitre au fil de la course de la couche (warship/pilot.asm).
;
; Premiere tranche (27/08/2026) : les 22 tourelles autonomes. Les 46 autres
; entrees du script portent l'identifiant 0 et sont sautees — voir
; doc/warship-parts-plan.md pour le decoupage de la campagne.
;*******************************************************************************

; Les poses des tourelles franchissent la frontiere de direntry : neuf par
; montage, resolues au chargement.
set_small_turret_top_0  EXTERNAL
set_small_turret_top_1  EXTERNAL
set_small_turret_top_2  EXTERNAL
set_small_turret_top_3  EXTERNAL
set_small_turret_top_4  EXTERNAL
set_small_turret_top_5  EXTERNAL
set_small_turret_top_6  EXTERNAL
set_small_turret_top_7  EXTERNAL
set_small_turret_top_8  EXTERNAL
set_small_turret_bottom_0  EXTERNAL
set_small_turret_bottom_1  EXTERNAL
set_small_turret_bottom_2  EXTERNAL
set_small_turret_bottom_3  EXTERNAL
set_small_turret_bottom_4  EXTERNAL
set_small_turret_bottom_5  EXTERNAL
set_small_turret_bottom_6  EXTERNAL
set_small_turret_bottom_7  EXTERNAL
set_small_turret_bottom_8  EXTERNAL
set_big_turret_0  EXTERNAL
set_big_turret_1  EXTERNAL
set_big_turret_2  EXTERNAL
set_big_turret_3  EXTERNAL
set_big_turret_4  EXTERNAL
set_big_turret_5  EXTERNAL
set_big_turret_6  EXTERNAL
set_big_turret_7  EXTERNAL
set_big_turret_8  EXTERNAL
turret.Object   EXPORT
part.Object     EXPORT

        INCLUDE "src/common/engine/api.asm"

; La couche porte les pieces : elles rangent leur position dans SON repere.
mscroll.camera.x  EXTERNAL
mscroll.camera.y  EXTERNAL
; L'index d'objets du stage charge : les tirs et les explosions y sont lus.
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
        INCLUDE "src/stages/03/objid.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"
        INCLUDE "src/common/lib/scale.asm"
        INCLUDE "src/common/lib/projectile.macro.asm"

        INCLUDE "src/enemies/warship-elements/layer.asm"
        INCLUDE "src/enemies/warship-elements/turret/obj.asm"
        INCLUDE "src/enemies/warship-elements/part/obj.asm"

 ENDSECTION
