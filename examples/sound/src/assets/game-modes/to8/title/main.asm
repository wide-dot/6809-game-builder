        INCLUDE "new-engine/sound/ymm.external.asm"
        INCLUDE "new-engine/sound/vgc.external.asm"

sound.title.ymm EXTERNAL
sound.title.vgc EXTERNAL

 SECTION code

        INCLUDE "new-engine/pack/to8/std.asm"
        INCLUDE "new-engine/pack/to8/irq.asm"
        INCLUDE "new-engine/pack/ymm.asm"
        INCLUDE "new-engine/pack/vgc.asm"

page.ymm equ 6                   ; ram page that contains ymm player and sound data (as defined in scene file)
page.vgc equ 7                   ; ram page that contains vgc player and sound data (as defined in scene file)

        _glb.init                ; clean dp variables
        _irq.init                ; set irq manager routine
        _irq.setRoutine #UserIRQ ; set user routine called by irq manager
        _irq.set50Hz             ; set irq to run every video frame, when spot is outside visible area

        _cart.setRam page.ymm    ; mount ram page that contains player and sound data
        _ymm.obj.play #map.RAM_OVER_CART+page.ymm,#sound.title.ymm,#ymm.LOOP,#ymm.NO_CALLBACK

        _cart.setRam page.vgc    ; mount ram page that contains player and sound data
        _vgc.obj.play #map.RAM_OVER_CART+page.vgc,#sound.title.vgc,#vgc.LOOP,#vgc.NO_CALLBACK

        _irq.on

        bra   *                  ; infinite loop

UserIRQ
        _cart.setRam page.ymm    ; mount object page
        _ymm.frame.play          ; play a music frame

        _cart.setRam page.vgc    ; mount object page
        _vgc.frame.play          ; play a music frame
        rts

 ENDSECTION

        INCLUDE "new-engine/global/glb.init.asm"
        INCLUDE "new-engine/system/to8/irq/irq.asm"
        INCLUDE "new-engine/graphics/buffer/gfxlock.asm"
