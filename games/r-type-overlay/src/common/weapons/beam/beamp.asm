;*******************************************************************************
; Le beam (tir charge) — unite paginee (region beamp, page $13 a $2000)
; Ses tables d'animation (Ani_Beams, un palier par tier) sont dans son code.
;*******************************************************************************

Beam              EXPORT

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

        INCLUDE "src/common/weapons/beam/beam.asm"

 ENDSECTION
