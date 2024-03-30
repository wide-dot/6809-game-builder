samples.clap EXTERNAL

 SECTION code

        INCLUDE "engine/pack/to8/std.asm"
        INCLUDE "engine/pack/to8/irq.asm"
        INCLUDE "engine/pack/firq.asm"

 opt c,ct

; ------------------------------------------------------------------------------
init
        _glb.init                  ; clean dp variables
        _irq.init                  ; set irq manager routine
        _irq.setRoutine #userIRQ   ; set user routine called by irq manager
        _irq.set50Hz               ; set irq to run every video frame, when spot is outside visible area
        _palette.update            ; update palette with the default black palette
        _gfxlock.halfPage.swap.off ; do not auto swap halp page in sync with double buffering
        _gfxlock.halfPage.set0     ; set the visible half page
        _gfxlock.init              ; init double buffering

        _firq.pcm.init             ; bind pcm firq routine
        _irq.on                    ; enable main 50Hz irq

        _gfxmode.setBM16           ; set video mode to 160x200 16 colors
        _gfxlock.memset #$0000     ; init video buffers to uniform color
        _gfxlock.memset #$0000

; ------------------------------------------------------------------------------
mainLoop
        jsr   keyboard.read
        tst   keyboard.pressed
        beq   >

        ; load sample data location and duration
        lda   #2
        sta   sample.current.id

        ldx   #samples.duration
        asla
        ldx   a,x
        stx   sample.current.duration

        lda   sample.current.id
        ldx   #samples.id
        lda   a,x
        ldx   #samples.address
        asla
        ldx   a,x
        stx   sample.current.address

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
sample.current.id
        fcb   0

sample.current.address
        fdb   0

sample.current.duration
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

samples.address
        fdb   0
        fdb   0
        fdb   samples.clap
        fdb   0
        fdb   0
        fdb   0
        fdb   0

samples.duration
        fdb   443 ;  8080 hz - Kick           
        fdb   157 ; 22800 hz - Snare          
        fdb   222 ; 16124 hz - Clap           
        fdb   248 ; 14434 hz - Scratch        
        fdb   495 ;  7231 hz - Mid-Low-Timpani
        fdb   274 ; 13064 hz - Floor-Tom      
        fdb   495 ;  7231 hz - Floor-Bongo    
        fdb   378 ;  9470 hz - Hi-Timpani     
        fdb   417 ;  8584 hz - Mid-Timpani    
        fdb   508 ;  7046 hz - Low-Timpani    
        fdb   521 ;  6871 hz - Floor-Timpani  
        fdb   170 ; 21056 hz - Hi-Tom         
        fdb   209 ; 17127 hz - Mid-Tom        
        fdb   248 ; 14434 hz - Low-Tom        
        fdb   248 ; 14434 hz - Hi-Bongo       
        fdb   287 ; 12472 hz - Mid-Bongo      
        fdb   378 ;  9470 hz - Low-Bongo      

 ENDSECTION

        INCLUDE "engine/global/glb.init.asm"
        INCLUDE "engine/system/to8/irq/irq.asm"
        INCLUDE "engine/system/to8/palette/palette.update.asm"
        INCLUDE "engine/system/thomson/graphics/buffer/gfxlock.asm"
        INCLUDE "engine/system/thomson/graphics/buffer/gfxlock.memset.asm"
        INCLUDE "engine/system/to8/controller/keyboard.asm"
        INCLUDE "engine/sound/firq.pcm.asm"
