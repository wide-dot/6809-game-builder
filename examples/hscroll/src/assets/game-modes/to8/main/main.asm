;*******************************************************************************
; Horizontal band scroll — example
;
; A 160 pixel band that loops on itself, scrolled left and right with the
; joypad. The band is not blitted : png2bin compiles it into a code buffer of
; stack pushes, and scrolling means entering that code at a different point.
; A whole-chunk rotation is free, and the fine steps come from offsetting S
; and swapping the two video planes.
;
; The band image is a measuring pattern, not artwork — see tools/gen_testband.py.
; Everything in it has a period dividing 160, so it meets itself at the wrap and
; any seam is a defect rather than a property of the picture. The ruler at the
; top ticks every 16 pixels, which is exactly one entry chunk of the buffer.
;
; Left and right on the joypad or the keyboard steer, up to two pixels per
; frame in either direction. The band starts drifting on its own so that the
; example says something even with nothing plugged in.
;*******************************************************************************

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.macro.asm"
        INCLUDE "engine/system/thomson/graphics/mode/gfxmode.macro.asm"
        INCLUDE "engine/graphics/tilemap/hscroll/hscroll.macro.asm"

        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/controller/joypad.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.macro.asm"

        INCLUDE "gen/layout.asm"

 opt c,ct

        ; the scene loads this at the game mode region and jumps to its first
        ; byte, so main has to be the first thing emitted

main
        jsr   InitGlobals
        jsr   joypad.init

        ; 160x200 in 16 colours. Without this the machine stays in its boot
        ; mode — 320x200 with two colours per 8 horizontal pixels — and the
        ; band's bytes get read as that instead, which shreds it into columns.
        _gfxmode.setBM16

        ; the band's own palette
        ldd   #Pal_band
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow

        ; The band sits at the top of the screen. That is not decoration : the
        ; code buffer runs on S, and putting the band anywhere else would have
        ; the stack spill past the end of a video zone. At the top, the spill
        ; lands in the unused $9FF4-$9FFF and $BFF4-$BFFF tails.
        _hscroll.setBuffer #objid.bandA,#objid.bandB
        _hscroll.setExitOffset #hscroll.band.EXIT_OFFSET
        _hscroll.setGuardColor #hscroll.band.GUARD
        _hscroll.setViewport #0,#hscroll.band.HEIGHT
        _hscroll.setCameraPos #0
        _hscroll.setCameraSpeed ctrlspeed

        ; irq
        ldd   #userIRQ
        std   Irq_user_routine
        jsr   IrqInit
        lda   #255                         ; sync out of display
        ldx   #Irq_one_frame
        jsr   IrqSync
        _gfxlock.init
        jsr   IrqOn

mainLoop
        ; steering, capped at one 2 pixel step per frame either way
        jsr   joypad.read
        lda   joypad.held.dpad
        bita  #joypad.0.LEFT
        beq   @right
        ldx   ctrlspeed
        leax  -$0010,x
        cmpx  #-$0200
        bge   @store
        ldx   #-$0200
        bra   @store
@right
        bita  #joypad.0.RIGHT
        beq   @steered
        ldx   ctrlspeed
        leax  $0010,x
        cmpx  #$0200
        ble   @store
        ldx   #$0200
@store  stx   ctrlspeed
        _hscroll.setCameraSpeed ctrlspeed
@steered

        _gfxlock.on
        jsr   hscroll.do                   ; draw the band where the camera is
        jsr   hscroll.move                 ; and advance the camera
        _gfxlock.off

        inc   $9C00                        ; a frame counter, so a stall is visible
        _gfxlock.loop
        lbra  mainLoop

ctrlspeed fdb $0080                        ; half a pixel per frame, rightward

userIRQ
        jsr   gfxlock.bufferSwap.check
        jmp   PalUpdateNow

;*******************************************************************************
; object index — where the two code buffers ended up
;*******************************************************************************
; hscroll reads a buffer's page and address out of these tables, the same way
; RunObjects reaches an object's code. The buffers are raw binaries loaded at a
; declared region, so the values come straight from the layout : there is
; nothing to relocate and nothing for the linker to resolve.

objid.bandA equ 1
objid.bandB equ 2

Obj_Index_Page
        fcb   $00
        fcb   map.RAM_OVER_CART+bandA.page
        fcb   map.RAM_OVER_CART+bandB.page

Obj_Index_Address
        fdb   $0000
        fdb   bandA.address
        fdb   bandB.address

;*******************************************************************************
; engine
;*******************************************************************************
        INCLUDE "engine/InitGlobals.asm"
        INCLUDE "engine/irq/Irq.asm"
        INCLUDE "engine/palette/PalUpdateNow.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.asm"
        INCLUDE "engine/graphics/tilemap/hscroll/hscroll.asm"

 ENDSECTION

; a v2 module, which brings its own section
        INCLUDE "engine/system/to8/controller/joypad.asm"
