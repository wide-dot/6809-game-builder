        INCLUDE "new-engine/sound/ymm.external.asm"
sound.title.ymm EXTERNAL

 SECTION code

        INCLUDE "new-engine/pack/mo6/std.asm"
        INCLUDE "new-engine/pack/mo6/irq.asm"
        INCLUDE "new-engine/pack/ymm.asm"

page.ymm equ 6                   ; ram page that contains player and sound data (as defined in scene file)

        _glb.init                ; clean dp variables
        _ym2413.init             ; init ym2413 sound chip registers
        _irq.init                ; set irq manager routine
        _irq.setRoutine #UserIRQ ; set user routine called by irq manager

        _cart.setRam page.ymm    ; mount ram page that contains player and sound data
        _ymm.init #map.RAM_OVER_CART+page.ymm,#sound.title.ymm,#ymm.LOOP,#ymm.NO_CALLBACK
        _irq.on                  ; start playing music

        bra   *                  ; infinite loop

UserIRQ
        _cart.setRam page.ymm    ; mount object page
        _ymm.frame.play          ; play a music frame
        rts

 ENDSECTION

        INCLUDE "new-engine/global/glb.init.asm"
        INCLUDE "new-engine/system/mo6/irq/irq.asm"
        INCLUDE "new-engine/sound/ym2413.asm"
        INCLUDE "new-engine/graphics/buffer/gfxlock.asm"
