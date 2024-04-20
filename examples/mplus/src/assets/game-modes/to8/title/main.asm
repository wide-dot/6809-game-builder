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

        jsr   dac.mute
        jsr   dac.enable
        jsr   joypad.md6.init

; ------------------------------------------------------------------------------
main.loop
        jsr   joypad.md6.read
        jsr   checkSampleRequest

        _gfxlock.on
        ; ... all writes to gfx buffer should be placed here for double buffering
        _gfxlock.off

        _gfxlock.loop
        jmp   main.loop

; ------------------------------------------------------------------------------
userIRQ
        _palette.checkUpdate
        _gfxlock.swap
        ; ... enter user code here
        rts

; ------------------------------------------------------------------------------

checkSampleRequest
        lda   #1
        ldb   joypad.md6.pressed.dpad
        beq   >
        bitb  #joypad.md6.x.UP
        bne   @fire
        inca
        bitb  #joypad.md6.x.DOWN
        bne   @fire
        inca
        bitb  #joypad.md6.x.LEFT
        bne   @fire
        inca
        bitb  #joypad.md6.x.RIGHT
        bne   @fire
        inca
!
        ldb   joypad.md6.pressed.fire
        beq   >
        bitb  #joypad.md6.x.A
        bne   @fire
        inca
        bitb  #joypad.md6.x.B
        bne   @fire
        inca
!
        ldb   joypad.md6.pressed.fireExt
        beq   @nofire
        bitb  #joypad.md6.x.X
        bne   @fire
        inca
        bitb  #joypad.md6.x.Y
        bne   @fire
        inca
        bitb  #joypad.md6.x.Z
        bne   @fire
        inca  ; joypad.md6.x.MODE
@fire
        ; load sample data location and duration
        sta   sample.current.id           ; id 0 means
        deca                              ; "no sound"
        lsla                              ; and black screen border
        ldx   #samples.duration
        ldx   a,x
        stx   sample.current.duration
        ldx   #samples.address
        ldx   a,x
        stx   sample.current.address
        ;
        ; change border color based on sampleid - for debug purpose onbly
        _gfxlock.screenBorder.update sample.current.id
        ;
        ; enable sample output by firq
        jsr   dac.unmute
        _firq.pcm.play sample.current.address,sample.current.duration
@nofire
        ; disable screen border if sample ended
        lda   map.MPLUS.CTRL              ; load ctrl register
        bita  #%00001000                  ; Bit 3: RW Timer - (F)IRQ enable (0=NO, 1=YES)
        bne   @rts                        ; Sample/FIRQ is still running
        jsr   dac.mute
        _gfxlock.screenBorder.update #0
@rts    
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
        fdb   222 ; 16124 hz - Hi-Tom
        fdb   248 ; 14434 hz - Hi-Bongo       
        fdb   378 ;  9470 hz - Low-Bongo
        fdb   508 ;  7046 hz - Low-Timpani    
        fdb   417 ;  8584 hz - Mid-Timpani    
        fdb   378 ;  9470 hz - Hi-Timpani     
        fdb   248 ; 14434 hz - Scratch        


sample.current.address
        fdb   0

samples.address
        fdb   samples.kick
        fdb   samples.snare
        fdb   samples.clap
        fdb   samples.tom
        fdb   samples.bongo      
        fdb   samples.bongo      
        fdb   samples.timpani
        fdb   samples.timpani
        fdb   samples.timpani
        fdb   samples.scratch

 ENDSECTION

        INCLUDE "engine/global/glb.init.asm"
        INCLUDE "engine/system/to8/irq/irq.asm"
        INCLUDE "engine/system/to8/palette/palette.update.asm"
        INCLUDE "engine/system/thomson/graphics/buffer/gfxlock.asm"
        INCLUDE "engine/system/thomson/graphics/buffer/gfxlock.memset.asm"
        INCLUDE "engine/sound/firq.pcm.asm"
        INCLUDE "engine/system/to8/controller/joypad.md6.dac.asm"
        INCLUDE "engine/system/thomson/sound/dac.enable.asm"
        INCLUDE "engine/system/to8/sound/dac.mute.asm"
