; ---------------------------------------------------------------------------
; compiler — the stage 4 boss, ported 1:1 from the arcade (obj.asm)
;
; REWRITTEN 16/10/2026 in arcade space, one arcade frame at a time, checked
; against the arcade by the trace bench (tools/fidelity/, doc/fidelite-
; arcade.md). The previous port converted speeds to TO8 units and ran each
; part on its own clock: the parts drifted out of the arcade's lockstep, the
; variant was drawn among 3 instead of 8 weighted slots, and the rolling
; laser kept an invented 128-frame pause.
;
; The entry must be the FIRST byte of the unit: code first, tables after.
; Migration case: docs/lang/en/migration/unit-entry-point.md
; ---------------------------------------------------------------------------

compiler.Object EXPORT

; LES SEIZE POSES DE TOURELLE VIVENT DANS UN AUTRE DIRENTRY
; (lib.compiler.turret) : l'unite passait 16 Ko une fois ses neuf scripts de
; combat ajoutes, et un direntry tient dans une page. Ce sont les IMAGES qui
; ont demenage, pas le code — la table ci-dessous les nomme et le loader
; resout au chargement. Img_Page_Index envoie deja ObjID_compilerturret vers
; leur page.
set_compiler_turret_0  EXTERNAL
weaponPodImmune        EXTERNAL ; l'immunite au pod, posee par PartLive
set_compiler_turret_1  EXTERNAL
set_compiler_turret_2  EXTERNAL
set_compiler_turret_3  EXTERNAL
set_compiler_turret_4  EXTERNAL
set_compiler_turret_5  EXTERNAL
set_compiler_turret_6  EXTERNAL
set_compiler_turret_7  EXTERNAL
set_compiler_turret_8  EXTERNAL
set_compiler_turret_9  EXTERNAL
set_compiler_turret_10 EXTERNAL
set_compiler_turret_11 EXTERNAL
set_compiler_turret_12 EXTERNAL
set_compiler_turret_13 EXTERNAL
set_compiler_turret_14 EXTERNAL
set_compiler_turret_15 EXTERNAL

        INCLUDE "src/common/engine/api.asm"

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
        INCLUDE "src/stages/04/objid.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"
        INCLUDE "src/common/lib/scale.asm"
        ; les tourelles tirent par le chemin commun (_loadFirePreset,
        ; tryFoeFire) : la macro vient avec.
        INCLUDE "src/common/lib/projectile.macro.asm"
        INCLUDE "src/common/lib/object.const.asm"

compiler.Object
        INCLUDE "src/enemies/compiler/obj.asm"

; ---------------------------------------------------------------------------
; THE PICTURES — what the puppets show
; ---------------------------------------------------------------------------
; the three parts, in the arcade's part order: right, bottom, left
cpl.images
        fdb   set_compiler_right
        fdb   set_compiler_bottom
        fdb   set_compiler_left

; Depth, part by part (A762: 0x4020, 0x4010, 0x4000 — the higher the more in
; front; our scale runs the other way, the ship is at 3).
;   right part 4 | right laser 5 | turrets 5 | bottom part 6
;   left part 7  | left laser 8  | rolling laser 8
cpl.prio
        fcb   4,6,7
cpl.PRIO_TURRET equ 5
cpl.PRIO_WAVE   equ 8

; one box per part, half sizes in v2 pixels (geometrie.txt: 66x96, 42x120,
; 66x84)
cpl.hitbox
        fcb   33,48
        fcb   21,60
        fcb   33,42

; e6c0: four frames, indexed by (gc & 6)
cpl.laser.images
        fdb   set_compiler_laser_0,set_compiler_laser_1
        fdb   set_compiler_laser_2,set_compiler_laser_3

; one pose per direction (the export took them from 1000:5872, indirect
; stride 4): the index is the direction code / 4
cpl.turret.images
        fdb   set_compiler_turret_0,set_compiler_turret_1
        fdb   set_compiler_turret_2,set_compiler_turret_3
        fdb   set_compiler_turret_4,set_compiler_turret_5
        fdb   set_compiler_turret_6,set_compiler_turret_7
        fdb   set_compiler_turret_8,set_compiler_turret_9
        fdb   set_compiler_turret_10,set_compiler_turret_11
        fdb   set_compiler_turret_12,set_compiler_turret_13
        fdb   set_compiler_turret_14,set_compiler_turret_15

; af07: a segment keeps one pose for its whole life
cpl.wave.images
        fdb   set_compiler_wave_0,set_compiler_wave_1
        fdb   set_compiler_wave_2,set_compiler_wave_3

; The dome's pulse, GENERATED (python3 tools/gen_dome_pulse.py)
        INCLUDE "src/enemies/compiler/dome-pulse.asm"

; The arcade tables and the raw ROM range, GENERATED
; (python3 tools/gen_compiler.py)
        INCLUDE "src/enemies/compiler/tables.asm"

 ENDSECTION
