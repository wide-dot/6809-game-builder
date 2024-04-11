samples.kick    EXTERNAL
samples.snare   EXTERNAL
samples.clap    EXTERNAL
samples.scratch EXTERNAL
samples.timpani EXTERNAL
samples.tom     EXTERNAL
samples.bongo   EXTERNAL

 SECTION code

        INCLUDE "engine/pack/to8/std.asm"
        INCLUDE "engine/pack/to8/irq.asm"
        INCLUDE "engine/pack/firq.asm"

        INCLUDE "engine/system/to8/controller/joypad.const.asm"

 opt c,ct

; ------------------------------------------------------------------------------
init
        _glb.init                         ; clean dp variables
        _irq.init                         ; set irq manager routine
        _irq.setRoutine #userIRQ          ; set user routine called by irq manager
        _irq.set50Hz                      ; set irq to run every video frame, when spot is outside visible area
        ;_palette.update                  ; update palette with the default black palette
        _cart.setRam #map.RAM_OVER_CART+5 ; set ram over cartridge space (sample data)
        _gfxlock.halfPage.swap.off        ; do not auto swap halp page in sync with double buffering
        _gfxlock.halfPage.set0            ; set the visible half page (sample data)
        _gfxlock.init                     ; init double buffering

        _firq.pcm.init                    ; bind pcm firq routine
        _irq.on                           ; enable main 50Hz irq

        _gfxmode.setBM16                  ; set video mode to 160x200 16 colors
        _gfxlock.memset #$0000            ; init video buffers to uniform color
        _gfxlock.memset #$0000

        jsr   dac.enable
        jsr   joypad.md6.init

; ------------------------------------------------------------------------------
main.loop
        jsr   joypad.md6.read
        ldd   joypad.md6.pressed.fire
        beq   main.gfx

        bita  #joypad.md6.x.A
        beq   >
        lda   #0
        bra   @exit
!       bita  #joypad.md6.x.B
        beq   >
        lda   #2
        bra   @exit
!       bitb  #joypad.md6.x.Z
        beq   >
        lda   #4
        bra   @exit
!       bitb  #joypad.md6.x.Y
        beq   >
        lda   #6
        bra   @exit
!       bitb  #joypad.md6.x.X
        beq   >
        lda   #8
        bra   @exit
!       ; joypad.md6.x.MODE
        lda   #10
@exit

        ; load sample data location and duration
        sta   sample.current.id

        ldx   #samples.duration
        ldx   a,x
        stx   sample.current.duration

        ldx   #samples.address
        ldx   a,x
        stx   sample.current.address

        ; change border color based on sampleid - for debug purpose onbly
        _gfxlock.screenBorder.update sample.current.id

        ; enable sample output by firq
        _firq.pcm.play sample.current.address,sample.current.duration

main.gfx
        _gfxlock.on
        ; all writes to gfx buffer should be placed here for double buffering
        ; ...
        _gfxlock.off

        _gfxlock.loop
        jmp   main.loop

; ------------------------------------------------------------------------------
userIRQ
        _palette.checkUpdate
        _gfxlock.swap

        ; enter user code here
        ; ...

        rts

; ------------------------------------------------------------------------------

sample.current.id
        fcb   0

sample.current.duration
        fdb   0

samples.duration
        fdb   443 ;  8080 hz - Kick           
        fdb   222 ; 16124 hz - Snare 
        fdb   222 ; 16124 hz - Clap
        fdb   378 ;  9470 hz - Hi-Timpani 
        fdb   274 ; 13064 hz - Floor-Tom      
        fdb   287 ; 12472 hz - Mid-Bongo 

sample.current.address
        fdb   0

samples.address
        fdb   samples.kick
        fdb   samples.snare
        fdb   samples.clap
        fdb   samples.timpani
        fdb   samples.tom
        fdb   samples.bongo      

 ENDSECTION

        INCLUDE "engine/global/glb.init.asm"
        INCLUDE "engine/system/to8/irq/irq.asm"
        INCLUDE "engine/system/to8/palette/palette.update.asm"
        INCLUDE "engine/system/thomson/graphics/buffer/gfxlock.asm"
        INCLUDE "engine/system/thomson/graphics/buffer/gfxlock.memset.asm"
        INCLUDE "engine/sound/firq.pcm.asm"
        INCLUDE "engine/system/to8/controller/joypad.md6.dac.asm"
        INCLUDE "engine/system/thomson/sound/dac.asm"
