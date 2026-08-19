;*******************************************************************************
; L'eclair d'emission — unite paginee (region emflash, page $13 a $3000)
; Partage joueur/ennemis : le flash a la bouche d'un canon quand il tire.
; L'entree v1 s'appelle Object, un nom trop generique pour la frontiere de
; lien : exporte sous emitterFlash.Object.
;*******************************************************************************

emitterFlash.Object EXPORT

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
        INCLUDE "src/enemies/_shared/emitter-flash.equ"

emitterFlash.Object
        INCLUDE "src/enemies/_shared/emitter-flash.asm"

; Les deux scripts, portes des properties v1 : quatre images puis _nextRoutine,
; en version gauche (NB0) et miroir droite (XB0).
        fcb   0
Ani_emitter_flash_left
        fdb   set_emitter_flash_0
        fdb   set_emitter_flash_1
        fdb   set_emitter_flash_2
        fdb   set_emitter_flash_3
        fcb   _nextRoutine
        fcb   0
Ani_emitter_flash_right
        fdb   set_emitter_flash_4
        fdb   set_emitter_flash_5
        fdb   set_emitter_flash_6
        fdb   set_emitter_flash_7
        fcb   _nextRoutine

 ENDSECTION
