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

 opt c,ct

; ------------------------------------------------------------------------------
init
        _glb.init                         ; clean dp variables
        _irq.init                         ; set irq manager routine
        _irq.setRoutine #userIRQ          ; set user routine called by irq manager
        _irq.set50Hz                      ; set irq to run every video frame, when spot is outside visible area
        ;_palette.update                   ; update palette with the default black palette
        _cart.setRam #map.RAM_OVER_CART+5 ; set ram over cartridge space (sample data)
        _gfxlock.halfPage.swap.off        ; do not auto swap halp page in sync with double buffering
        _gfxlock.halfPage.set0            ; set the visible half page (sample data)
        _gfxlock.init                     ; init double buffering

        ldd   #$fb3f  ! Mute by CRA to
        anda  $e7cf   ! avoid sound when
        sta   $e7cf   ! $e7cd written
        stb   $e7cd   ! Full sound line
        ora   #$04    ! Disable mute by
        sta   $e7cf   ! CRA and sound

        _firq.pcm.init             ; bind pcm firq routine
        _irq.on                    ; enable main 50Hz irq

        _gfxmode.setBM16           ; set video mode to 160x200 16 colors
        _gfxlock.memset #$0000     ; init video buffers to uniform color
        _gfxlock.memset #$0000

; ------------------------------------------------------------------------------
mainLoop
        jsr   keyboard.read
        ldb   keyboard.pressed
        beq   >

        ; load sample data location and duration
        subb  #scancode.A
        cmpb  #17
        bhs   >
        stb   sample.current.id

        ldx   #samples.duration
        aslb
        ldx   b,x
        stx   sample.current.duration

        ldb   sample.current.id
        ldx   #samples.id
        ldb   b,x
        ldx   #samples.address
        aslb
        ldx   b,x
        stx   sample.current.address

        ; change border color based on sampleid - for debug purpose onbly
        _gfxlock.screenBorder.update sample.current.id

        ; enable sample output by firq
        _firq.pcm.play sample.current.address,sample.current.duration
!
        _gfxlock.on
        ; all writes to gfx buffer should be placed here for double buffering
        ; ...
        _gfxlock.off

        _gfxlock.loop
        jmp   mainLoop             ; infinite loop

; ------------------------------------------------------------------------------
userIRQ
        _palette.checkUpdate
        _gfxlock.swap

        ; enter user code here
        ; ...

        rts

; ------------------------------------------------------------------------------

sample.current.duration
        fdb   0

samples.duration
        fdb   443 ;  8080 hz - Kick           
        fdb   222 ; 16124 hz - Snare          fdb   157 ; 22800 hz - Snare          
        fdb   222 ; 16124 hz - Clap           
        fdb   248 ; 14434 hz - Scratch        
        fdb   495 ;  7231 hz - Mid-Low-Timpani
        fdb   274 ; 13064 hz - Floor-Tom      
        fdb   495 ;  7231 hz - Floor-Bongo    
        fdb   378 ;  9470 hz - Hi-Timpani     
        fdb   417 ;  8584 hz - Mid-Timpani    
        fdb   508 ;  7046 hz - Low-Timpani    
        fdb   521 ;  6871 hz - Floor-Timpani  
        fdb   222 ; 16124 hz - Hi-Tom         fdb   170 ; 21056 hz - Hi-Tom         
        fdb   222 ; 16124 hz - Mid-Tom        fdb   209 ; 17127 hz - Mid-Tom        
        fdb   248 ; 14434 hz - Low-Tom        
        fdb   248 ; 14434 hz - Hi-Bongo       
        fdb   287 ; 12472 hz - Mid-Bongo      
        fdb   378 ;  9470 hz - Low-Bongo

sample.current.id
        fcb   0

samples.id
        fcb   0 ; Kick
        fcb   1 ; Snare
        fcb   2 ; Clap
        fcb   3 ; Scratch
        fcb   4 ; Mid-Low-Timpani
        fcb   5 ; Floor-Tom
        fcb   6 ; Floor-Bongo
        fcb   4 ; Hi-Timpani
        fcb   4 ; Mid-Timpani
        fcb   4 ; Low-Timpani
        fcb   4 ; Floor-Timpani
        fcb   5 ; Hi-Tom
        fcb   5 ; Mid-Tom
        fcb   5 ; Low-Tom
        fcb   6 ; Hi-Bongo
        fcb   6 ; Mid-Bongo
        fcb   6 ; Low-Bongo

sample.current.address
        fdb   0

samples.address
        fdb   samples.kick
        fdb   samples.snare
        fdb   samples.clap
        fdb   samples.scratch
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
        INCLUDE "engine/system/to8/controller/keyboard.asm"
