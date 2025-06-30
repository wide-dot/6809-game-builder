        INCLUDE "engine/sound/ymm.external.asm"
        INCLUDE "engine/sound/vgc.external.asm"

sn76489.init       EXTERNAL
ym2413.init        EXTERNAL
scenes.level1      EXTERNAL
sounds.title.ymm   EXTERNAL
sounds.title.vgc   EXTERNAL
sounds.level1.ymm  EXTERNAL
sounds.level1.vgc  EXTERNAL

 SECTION code
        opt c
        INCLUDE "engine/system/mo6/pack/std.asm"
        INCLUDE "engine/system/mo6/pack/irq.asm"
        INCLUDE "engine/pack/ymm.asm"
        INCLUDE "engine/pack/vgc.asm"

page.ymm equ map.RAM_OVER_CART+6  ; ram page that contains ymm player and sound data (as defined in scene file)
page.vgc equ map.RAM_OVER_CART+7

; ------------------------------------------------------------------------------
init
        _glb.init                 ; clean dp variables
        _irq.init                 ; set irq manager routine
        _irq.setRoutine #userIRQ  ; set user routine called by irq manager
        _palette.update           ; update palette with the default black palette
        _gfxlock.init

        jsr   keyboard.disableBuzzer

        _ram.cart.set  #page.ymm   ; mount ram page that contains player and sound data
        _ymm.obj.play #page.ymm,#sounds.title.ymm,#ymm.LOOP,#ymm.NO_CALLBACK

        _ram.cart.set  #page.vgc
        _vgc.obj.play #page.vgc,#sounds.title.vgc,#vgc.LOOP,#vgc.NO_CALLBACK
        _irq.on

        _gfxmode.setBM16
        _gfxlock.memset #$0000    ; init video buffers
        _gfxlock.memset #$0000

; ------------------------------------------------------------------------------
mainLoop
        ;jsr   keyboard.read
        ;tst   keyboard.pressed
        ;beq   >

        ldb   #$68 ; ENTER
        stb   map.MC6821.PRB
        lda   map.MC6821.PRB
        bmi   >

        _irq.off
        _ram.cart.set  #page.vgc
        _sn76489.init
        _ram.cart.set  #page.ymm
        _ym2413.init

        _ram.data.set #loader.PAGE ; load a new song from disk 
        _loader.scene.load #scenes.level1

        _ram.cart.set  #page.ymm
        _ymm.obj.play #page.ymm,#sounds.level1.ymm,#ymm.LOOP,#ymm.NO_CALLBACK

        _ram.cart.set  #page.vgc
        _vgc.obj.play #page.vgc,#sounds.level1.vgc,#vgc.LOOP,#vgc.NO_CALLBACK
        _irq.on
!

        _gfxlock.on
        ; all writes to gfx buffer should be placed here for double buffering
        ; ...
        _gfxlock.off

        _gfxlock.loop
        jmp   mainLoop           ; infinite loop

; ------------------------------------------------------------------------------
userIRQ
        _palette.checkUpdate
        _gfxlock.swap

        _ram.cart.set #page.ymm   ; mount object page
        _ymm.frame.play          ; play a music frame

        _ram.cart.set #page.vgc   ; mount object page
        _vgc.frame.play          ; play a music frame
        rts

 ENDSECTION

        INCLUDE "engine/global/glb.init.asm"
        INCLUDE "engine/system/mo6/irq/irq.asm"
        INCLUDE "engine/system/to8/palette/palette.update.asm"
        INCLUDE "engine/system/thomson/graphics/buffer/gfxlock.asm"
        INCLUDE "engine/system/thomson/graphics/buffer/gfxlock.memset.asm"
        INCLUDE "engine/system/mo6/controller/keyboard.asm"
