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
set_front_turret_a_0  EXTERNAL
set_front_turret_a_1  EXTERNAL
set_front_turret_a_2  EXTERNAL
set_front_turret_a_3  EXTERNAL
set_front_turret_a_4  EXTERNAL
set_front_turret_a_5  EXTERNAL
set_front_turret_a_6  EXTERNAL
set_front_turret_b_0  EXTERNAL
set_front_turret_b_1  EXTERNAL
set_front_turret_b_2  EXTERNAL
set_front_turret_b_3  EXTERNAL
set_front_turret_b_4  EXTERNAL
set_front_turret_c_0  EXTERNAL
set_front_turret_c_1  EXTERNAL
set_front_turret_c_2  EXTERNAL
set_front_turret_c_3  EXTERNAL
set_front_turret_c_4  EXTERNAL
set_front_turret_c_5  EXTERNAL
set_front_turret_c_6  EXTERNAL
set_front_turret_d_0  EXTERNAL
set_front_turret_d_1  EXTERNAL
set_front_turret_d_2  EXTERNAL
set_front_turret_d_3  EXTERNAL
set_front_turret_d_4  EXTERNAL
set_front_turret_e_0  EXTERNAL
set_front_turret_e_1  EXTERNAL
set_front_turret_e_2  EXTERNAL
set_front_turret_e_3  EXTERNAL
set_front_turret_e_4  EXTERNAL
set_front_turret_e_5  EXTERNAL
set_multi_tl_0  EXTERNAL
set_multi_tl_1  EXTERNAL
set_multi_tl_2  EXTERNAL
set_multi_tl_3  EXTERNAL
set_multi_bl_0  EXTERNAL
set_multi_bl_1  EXTERNAL
set_multi_bl_2  EXTERNAL
set_multi_bl_3  EXTERNAL
set_multi_tr_0  EXTERNAL
set_multi_tr_1  EXTERNAL
set_multi_tr_2  EXTERNAL
set_multi_tr_3  EXTERNAL
set_multi_br_0  EXTERNAL
set_multi_br_1  EXTERNAL
set_multi_br_2  EXTERNAL
set_multi_br_3  EXTERNAL
set_fire_ball_0  EXTERNAL
set_fire_ball_1  EXTERNAL
set_fire_ball_2  EXTERNAL
set_fire_ball_3  EXTERNAL
set_fire_ball_4  EXTERNAL
set_fire_ball_5  EXTERNAL
set_fire_ball_6  EXTERNAL
set_fire_ball_7  EXTERNAL
set_fire_ball_8  EXTERNAL
set_fire_ball_9  EXTERNAL
set_fire_ball_10  EXTERNAL
set_fire_ball_11  EXTERNAL
set_fire_ball_12  EXTERNAL
set_fire_ball_13  EXTERNAL
set_fire_ball_14  EXTERNAL
set_fire_ball_15  EXTERNAL
set_fire_ball_16  EXTERNAL
set_fire_ball_17  EXTERNAL
set_fire_ball_18  EXTERNAL
set_fire_ball_19  EXTERNAL
set_fire_ball_20  EXTERNAL
set_fire_ball_21  EXTERNAL
set_fireball_flash_0  EXTERNAL
set_fireball_flash_1  EXTERNAL
set_fireball_flash_2  EXTERNAL
set_fireball_flash_3  EXTERNAL
set_fireball_flash_4  EXTERNAL
set_fireball_flash_5  EXTERNAL
set_fireball_flash_6  EXTERNAL
set_fireball_flash_7  EXTERNAL
turret.Object   EXPORT
part.Object     EXPORT
fturret.Object  EXPORT
multi.Object    EXPORT
fireball.Object EXPORT
muzzle.Object   EXPORT

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
        ; les alias de champs du tir (fireDisplayDelay...) — la multi seme
        ; des foefire generiques
        INCLUDE "src/common/lib/object.const.asm"
        INCLUDE "src/common/lib/projectile.macro.asm"

        INCLUDE "src/enemies/warship-elements/layer.asm"
        INCLUDE "src/enemies/warship-elements/turret/obj.asm"
        INCLUDE "src/enemies/warship-elements/part/obj.asm"
        INCLUDE "src/enemies/warship-elements/frontturret/obj.asm"
        INCLUDE "src/enemies/warship-elements/fireball/obj.asm"
        INCLUDE "src/enemies/warship-elements/multiturret/obj.asm"

 ENDSECTION
