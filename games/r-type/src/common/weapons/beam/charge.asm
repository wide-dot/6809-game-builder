;*******************************************************************************
; L'anim de charge du beam — unite paginee (region beamcharge, page $13 a $1000)
;*******************************************************************************

Beamcharge        EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/graphics/animation/constants-animation.equ"
        INCLUDE "src/common/player/player1.equ"

        INCLUDE "src/common/weapons/beam/beamcharge.asm"

; Le script d'animation, porte des properties v1 (beamcharge.d7.properties) :
; huit images en compte a rebours, wait 0.
        fcb   0
Ani_beamcharge
        fdb   set_beamcharge_7
        fdb   set_beamcharge_6
        fdb   set_beamcharge_5
        fdb   set_beamcharge_4
        fdb   set_beamcharge_3
        fdb   set_beamcharge_2
        fdb   set_beamcharge_1
        fdb   set_beamcharge_0
        fcb   _resetAnim

 ENDSECTION
