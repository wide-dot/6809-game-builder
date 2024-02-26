        INCLUDE "new-engine/sound/ymm.external.asm"
        INCLUDE "new-engine/sound/vgc.external.asm"
        INCLUDE "new-engine/system/to8/bootloader/loader.external.asm"

loader.PAGE       EXTERNAL
scenes.level1     EXTERNAL
sound.title.ymm   EXTERNAL
sound.title.vgc   EXTERNAL
sound.level1.ymm  EXTERNAL
sound.level1.vgc  EXTERNAL

 SECTION code

        INCLUDE "new-engine/pack/to8/std.asm"
        INCLUDE "new-engine/pack/to8/irq.asm"
        INCLUDE "new-engine/pack/ymm.asm"
        INCLUDE "new-engine/pack/vgc.asm"

page.ymm equ map.RAM_OVER_CART+6 ; ram page that contains ymm player and sound data (as defined in scene file)
page.vgc equ map.RAM_OVER_CART+7 ; ram page that contains vgc player and sound data (as defined in scene file)
addr.ymm equ $0400
addr.vgc equ $0A80

; ------------------------------------------------------------------------------
init
        _glb.init                ; clean dp variables
        _irq.init                ; set irq manager routine
        _irq.setRoutine #userIRQ ; set user routine called by irq manager
        _irq.set50Hz             ; set irq to run every video frame, when spot is outside visible area
        ;_gfxlock.init

        _cart.setRam  #page.ymm    ; mount ram page that contains player and sound data
        _ymm.obj.play #page.ymm,#sound.title.ymm,#ymm.LOOP,#ymm.NO_CALLBACK

        _cart.setRam  #page.vgc    ; mount ram page that contains player and sound data
        _vgc.obj.play #page.vgc,#sound.title.vgc,#vgc.LOOP,#vgc.NO_CALLBACK

        _irq.on

; ------------------------------------------------------------------------------
mainLoop
        jsr   keyboard.read
        tst   keyboard.pressed
        beq   >

        _irq.off

        _data.setRam #loader.PAGE
        ldx   #scenes.level1
        jsr   loader.scene.load  ; load a new song from disk 

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
        INCLUDE "new-engine/system/to8/irq/irq.asm"
        INCLUDE "new-engine/graphics/buffer/gfxlock.asm"
        INCLUDE "new-engine/system/thomson/controller/keyboard.asm"
