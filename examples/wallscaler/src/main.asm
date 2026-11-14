;*******************************************************************************
; wallscaler : a maze walked with the joypad (left / right turn, up / down
; walk), on engine/graphics/raycast.
;
; The bench (bench.json) starts its sequence by writing $A5 at bench.go :
; 16 cameras, their descriptors and the view summed at $9C00
; (src/bench.equ).
;*******************************************************************************

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.macro.asm"
        INCLUDE "engine/system/thomson/graphics/mode/gfxmode.macro.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.macro.asm"
        INCLUDE "src/bench.equ"
        INCLUDE "src/boot.equ"

 opt c,ct

game.START_X equ 640                       ; the camera : cell 2.5, 4.5, facing east
game.START_Y equ 1152
game.START_A equ 0
game.TURN    equ 2                         ; angle units a VBL : 35 degrees a second
game.MOVE    equ 5                         ; 5/256 cell a VBL : a cell a second
game.DT_MAX  equ 8                         ; a longer gap (the boot) counts as 8

main
        jsr   InitGlobals
        ldu   #pal.work                    ; bootfade's bar faded out, the VBL
        ldd   #$0000                       ; polled (no IRQ yet) : black
        jsr   palette.fade
        _gfxmode.setBM16
        ldd   #pal.work                    ; the IRQ writes pal.work, black
        std   Pal_current                  ; until the game is on screen
        lda   #1
        sta   pal.fading

        ldx   #bench.go                    ; the witnesses
        ldd   #0
@w      std   ,x++
        cmpx  #bench.sums+2*bench.TESTS
        blo   @w
        ldd   #game.START_X                ; the camera
        std   raycast.x
        ldd   #game.START_Y
        std   raycast.y
        ldd   #game.START_A
        std   raycast.angle

        ; both buffers : a test card (what is outside the view is the
        ; game's), then the view's empty room
        _ram.data.set #2
        jsr   game.card
        jsr   wallscaler.background
        _ram.data.set #3
        jsr   game.card
        jsr   wallscaler.background

        lda   #-1                          ; no swap pending when the interrupt starts
        sta   gfxlock.status
        ldd   #userIRQ
        std   Irq_user_routine
        jsr   IrqInit
        lda   #255                         ; sync out of display
        ldx   #Irq_one_frame
        jsr   IrqSync
        _gfxlock.init
        jsr   IrqOn
        lda   #$CA
        sta   bench.magic

loop    lda   bench.go
        cmpa  #$A5
        lbeq  bench.run
        _gfxlock.on
        jsr   game.camera
        jsr   raycast.cast
        jsr   wallscaler.draw
        _gfxlock.off
        _gfxlock.loop
        bra   loop

userIRQ
        ldd   game.vbl
        addd  #1
        std   game.vbl
        jsr   gfxlock.bufferSwap.check     ; first, the beam out of the screen
        tst   pal.fading
        beq   @pal
        ldd   game.frames                  ; both buffers drawn, one shown : the
        cmpd  #3                           ; palette in, a step an IRQ
        blo   @pal
        jsr   pal.step
        bne   @write
        clr   pal.fading
@write  clr   PalRefresh                   ; pal.work to the chip
@pal    jmp   PalUpdateNow

;-------------------------------------------------------------------------------
; pal.step : pal.work one notch toward Pal_wall, every component (a nibble).
; Out : Z clear while something moved. 15 steps at most.
;-------------------------------------------------------------------------------
pal.step
        ldx   #Pal_wall
        ldu   #pal.work
        clr   pal.moved
        lda   #32
        sta   pal.n
@byte   ldb   ,x+                          ; the target byte
        stb   pal.t
        andb  #$F0                         ; high nibble
        lda   ,u
        anda  #$F0
        pshs  b
        cmpa  ,s+
        beq   @lo
        bhi   @hdown
        lda   ,u
        adda  #$10
        bra   @hset
@hdown  lda   ,u
        suba  #$10
@hset   sta   ,u
        inc   pal.moved
@lo     ldb   pal.t                        ; low nibble
        andb  #$0F
        lda   ,u
        anda  #$0F
        pshs  b
        cmpa  ,s+
        beq   @next
        bhi   @ldown
        inc   ,u
        bra   @lset
@ldown  dec   ,u
@lset   inc   pal.moved
@next   leau  1,u
        dec   pal.n
        bne   @byte
        tst   pal.moved
        rts

pal.fading fcb 0
pal.moved  fcb 0
pal.n      fcb 0
pal.t      fcb 0
pal.work                                   ; bootfade's palette : black, its bar
        fdb   $0000
        fcb   boot.TRACK_GR,boot.TRACK_B
        fcb   boot.BAR_GR,boot.BAR_B
        fill  0,26

;-------------------------------------------------------------------------------
; game.camera : the camera moved by the joypad, by the time gone since the
; frame before (a frame takes 3 to 9 VBLs)
;-------------------------------------------------------------------------------
game.camera
        ldd   game.frames
        addd  #1
        std   game.frames
        ldd   game.vbl                     ; the VBLs since the frame before
        subd  game.lastVbl
        cmpd  #game.DT_MAX
        bls   @dt
        ldd   #game.DT_MAX
@dt     stb   game.dt
        ldd   game.vbl
        std   game.lastVbl
        jsr   ReadJoypads
        lda   #game.TURN                   ; TURN a VBL
        ldb   game.dt
        mul
        std   game.turn
        ldx   raycast.angle
        lda   Ctrl_1_Held
        bita  #button_left_mask
        beq   @r
        tfr   x,d
        subd  game.turn
        tfr   d,x
@r      lda   Ctrl_1_Held
        bita  #button_right_mask
        beq   @st
        ldd   game.turn
        leax  d,x
@st     tfr   x,d
        anda  #(1024-1)/256                ; 0-1023
        std   raycast.angle
        lda   #game.MOVE                   ; MOVE a VBL
        ldb   game.dt
        mul                                ; B, 40 at most
        lda   Ctrl_1_Held
        bita  #button_up_mask
        bne   @go
        bita  #button_down_mask
        beq   @rts
        negb
@go     jsr   raycast.move
@rts    rts

game.frames  fdb 0
game.vbl     fdb 0
game.lastVbl fdb 0
game.turn    fdb 0
game.dt      fcb 0

;-------------------------------------------------------------------------------
; game.card : the buffer in the data window to a test card, a byte the two
; halves of its address : what shows outside the view, and stays
;-------------------------------------------------------------------------------
game.card
        ldx   #$A000
        bsr   @bank
        ldx   #$C000
@bank   leay  8000,x
        sty   @end+1
@byte   tfr   x,d
        pshs  a
        eorb  ,s+
        stb   ,x+
@end    cmpx  #$0000                       ; (dynamic)
        bne   @byte
        rts

;-------------------------------------------------------------------------------
; bench.run : the bench's sequence. A camera : both buffers drawn, then two
; tests — its descriptors' sum (top rows and texture columns : the scalers'
; pages and addresses are the builder's), the view's sum. A last test : what
; is outside the view sums as before the first frame.
;-------------------------------------------------------------------------------
bench.run
        clr   bench.go
        lda   #bench.TESTS
        sta   bench.tests
        ldx   #bench.results
        stx   bench.result
        ldx   #bench.sums
        stx   bench.word
        jsr   bench.outside
        std   bench.out
        ldu   #bench.cameras
bench.camera
        pulu  d,x,y
        std   raycast.x
        stx   raycast.y
        sty   raycast.angle
        stu   bench.next
        jsr   bench.frame                  ; a buffer
        _gfxlock.on                        ; the other : both hold the camera
        jsr   raycast.cast
        jsr   bench.sumDescs               ; before the draw, which spends them
        jsr   bench.record
        jsr   wallscaler.draw
        jsr   bench.sumView                ; the back buffer, in the data window
        jsr   bench.record
        _gfxlock.off
        _gfxlock.loop
        ldu   bench.next
        cmpu  #bench.cameras.end
        lbne  bench.camera
        _gfxlock.on
        jsr   bench.outside
        pshs  d
        _gfxlock.off
        puls  d
        cmpd  bench.out
        bne   bench.end                    ; the test stays at 0 : failed
        jsr   bench.record
bench.end
        lda   #$0D
        sta   bench.done
        jmp   loop

bench.frame
        _gfxlock.on
        jsr   raycast.cast
        jsr   wallscaler.draw
        _gfxlock.off
        _gfxlock.loop
        rts

; bench.record : D a sum — the next test passes, with its word
bench.record
        ldx   bench.word
        std   ,x++
        stx   bench.word
        ldx   bench.result
        lda   #1
        sta   ,x+
        stx   bench.result
        rts

; a sum : D rotated left by a bit, plus the byte at X+
bench.sumDescs
        ldx   #wallscaler.descriptors
        ldd   #0
@col    leax  1,x                          ; the scaler's page : the builder's
        jsr   bench.add                    ; the top row
        jsr   bench.add                    ; the texture column
        jsr   bench.add
        leax  2,x                          ; the scaler : the builder's
        cmpx  #wallscaler.descriptors+wallscaler.COLS*wallscaler.DESC
        bne   @col
        rts

bench.add
        lslb
        rola
        adcb  #0
        addb  ,x+
        adca  #0
        rts

bench.sumView                              ; the view of the buffer in the data window
        ldd   #0
        ldx   #$A000+wallscaler.Y*40+wallscaler.X/2
        bsr   @bank
        ldx   #$C000+wallscaler.Y*40+wallscaler.X/2
@bank   pshs  a
        lda   #wallscaler.ROWS
        sta   bench.row
        puls  a
@row    ldy   #wallscaler.COLS/2
@byte   lslb
        rola
        adcb  #0
        addb  ,x+
        adca  #0
        leay  -1,y
        bne   @byte
        leax  40-wallscaler.COLS/2,x
        dec   bench.row
        bne   @row
        rts

bench.outside                              ; the same buffer, less the view
        ldd   #0
        ldx   #$A000
        bsr   @bank
        ldx   #$C000
@bank   clr   bench.row
@row    clr   bench.col
@byte   pshs  a
        lda   bench.row
        suba  #wallscaler.Y
        cmpa  #wallscaler.ROWS
        bhs   @out
        lda   bench.col
        suba  #wallscaler.X/2
        cmpa  #wallscaler.COLS/2
        bhs   @out
        puls  a
        leax  1,x                          ; in the view
        bra   @next
@out    puls  a
        lslb
        rola
        adcb  #0
        addb  ,x+
        adca  #0
@next   inc   bench.col
        pshs  a
        lda   bench.col
        cmpa  #40
        puls  a
        bne   @byte
        inc   bench.row
        pshs  a
        lda   bench.row
        cmpa  #200
        puls  a
        bne   @row
        rts

bench.result fdb 0
bench.word   fdb 0
bench.next   fdb 0
bench.out    fdb 0
bench.row    fcb 0
bench.col    fcb 0

; the bench's cameras : x, y (8.8 cells), angle
bench.cameras
        fdb   693,1152,0
        fdb   1600,1152,0
        fdb   1920,1957,256
        fdb   2773,2176,0
        fdb   3968,1856,912
        fdb   4546,1280,0
        fdb   5268,1280,299
        fdb   5268,1280,0
        fdb   5248,2496,258
        fdb   5035,2944,512
        fdb   3221,2944,512
        fdb   1408,2944,512
        fdb   1382,2381,753
        fdb   1152,1306,768
        fdb   640,1152,154
        fdb   5248,2944,384
bench.cameras.end

;*******************************************************************************
; engine
;*******************************************************************************
        INCLUDE "engine/InitGlobals.asm"
        INCLUDE "engine/irq/Irq.asm"
        INCLUDE "engine/palette/PalUpdateNow.asm"
        INCLUDE "engine/palette/palette-fade.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.asm"
        INCLUDE "engine/joypad/ReadJoypads2.asm"
        INCLUDE "engine/graphics/raycast/wallscaler.asm"
        INCLUDE "engine/graphics/raycast/raycast.asm"

 ENDSECTION
