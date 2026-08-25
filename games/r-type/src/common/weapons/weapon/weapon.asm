;*******************************************************************************
; Le tir de base — unite paginee (region weapon, page $13 a $0000)
; Un objet v1 = une unite, comme en v1 : ses labels internes et ses equates
; d'OST lui appartiennent.
;*******************************************************************************

Weapon            EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/map.const.asm"
        ; Le bruitage : le macro ecrit la boite aux lettres residente, que le
        ; pilote depile dans l'IRQ. Les constantes de son sont partagees a
        ; l'assemblage, la boite aux lettres traverse le lien.
        INCLUDE "src/common/fx/soundfx/soundFX.const.asm"
        INCLUDE "engine/sound/soundFX.macro.asm"
        INCLUDE "engine/graphics/animation/constants-animation.equ"
        ; stage.gum.hook : le vecteur de couche destructible du stage
        INCLUDE "src/common/state/variables.asm"

        INCLUDE "src/common/weapons/weapon/obj.asm"

 ENDSECTION
