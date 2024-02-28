        INCLUDE "new-engine/sound/ymm.external.asm"
        INCLUDE "new-engine/sound/vgc.external.asm"

scenes.level1     EXTERNAL
sound.title.ymm   EXTERNAL
sound.title.vgc   EXTERNAL
sound.level1.ymm  EXTERNAL
sound.level1.vgc  EXTERNAL

 SECTION code

        INCLUDE "new-engine/pack/mo6/std.asm"
        INCLUDE "new-engine/pack/mo6/irq.asm"
        INCLUDE "new-engine/pack/ymm.asm"
        INCLUDE "new-engine/pack/vgc.asm"

page.ymm equ map.RAM_OVER_CART+6  ; ram page that contains ymm player and sound data (as defined in scene file)
page.vgc equ map.RAM_OVER_CART+7 
addr.ymm equ $B400                ; ram addr that contains ymm player and sound data (as defined in scene file)
addr.vgc equ $BA80

; ------------------------------------------------------------------------------
init
        _glb.init                 ; clean dp variables
        _irq.init                 ; set irq manager routine
        _irq.setRoutine #userIRQ  ; set user routine called by irq manager
        ;_gfxlock.init

        _cart.setRam  #page.ymm   ; mount ram page that contains player and sound data
        _ymm.obj.play #page.ymm,#sound.title.ymm,#ymm.LOOP,#ymm.NO_CALLBACK

        _cart.setRam  #page.vgc
        _vgc.obj.play #page.vgc,#sound.title.vgc,#vgc.LOOP,#vgc.NO_CALLBACK
        _irq.on

; ------------------------------------------------------------------------------
mainLoop
        jsr   keyboard.read
        tst   keyboard.pressed
        beq   >

        _irq.off
        _data.setRam #loader.PAGE ; load a new song from disk 
        ldx   #scenes.level1
        jsr   loader.ADDRESS+3

        _cart.setRam  #page.ymm
        _ymm.obj.play #page.ymm,#sound.level1.ymm,#ymm.LOOP,#ymm.NO_CALLBACK

        _cart.setRam  #page.vgc
        _vgc.obj.play #page.vgc,#sound.level1.vgc,#vgc.LOOP,#vgc.NO_CALLBACK
        _irq.on
!

        ;_gfxlock.on
        ; all writes to gfx buffer should be placed here for double buffering
        ; ...
        ;_gfxlock.off

        ;_gfxlock.loop
        bra   mainLoop           ; infinite loop

; ------------------------------------------------------------------------------
userIRQ
        _cart.setRam #page.ymm   ; mount object page
        _ymm.frame.play          ; play a music frame

        _cart.setRam #page.vgc   ; mount object page
        _vgc.frame.play          ; play a music frame
        rts

 ENDSECTION

        INCLUDE "new-engine/global/glb.init.asm"
        INCLUDE "new-engine/system/mo6/irq/irq.asm"
        INCLUDE "new-engine/graphics/buffer/gfxlock.asm"
        INCLUDE "new-engine/system/mo6/controller/keyboard.asm"
