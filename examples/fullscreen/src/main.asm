;*******************************************************************************
; Fullscreen picture — example and bench
;
; A 160x200 picture (src/mire.png, a measuring pattern : tools/gen_mire.py)
; converted by <png2bin buffer="fullscreen"> into the 16 000 bytes
; engine/graphics/draw/DrawFullscreenImage.asm copies, then copied into both
; screen buffers and shown.
;
; Witnesses at $9C00 : +0 $CA once running, +1 $0D once both buffers hold the
; picture.
;
; The setup (mode, palette, irq, gfxlock) is examples/hscroll's.
;*******************************************************************************

bench.magic equ $9C00
bench.done  equ $9C01

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.macro.asm"
        INCLUDE "engine/system/thomson/graphics/mode/gfxmode.macro.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.macro.asm"

 opt c,ct

        ; the scene loads this at the game mode region and jumps to its first
        ; byte, so main has to be the first thing emitted

main
        jsr   InitGlobals
        _gfxmode.setBM16

        ldd   #Pal_mire
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow

        clr   bench.done
        lda   #$CA
        sta   bench.magic

        ; both buffers, before the interrupt runs : the copy pushes through S
        orcc  #$50
        _ram.data.set #2
        ldx   #image
        jsr   DrawFullscreenImage
        _ram.data.set #3
        ldx   #image
        jsr   DrawFullscreenImage
        andcc #$AF

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

        lda   #$0D
        sta   bench.done
loop    _gfxlock.on                        ; nothing drawn : the picture stays
        _gfxlock.off
        _gfxlock.loop
        bra   loop

image                                      ; DrawFullscreenImage's parameter
        fcb   map.RAM_OVER_CART+assets.image.page
        fdb   assets.image.address

userIRQ
        jsr   gfxlock.bufferSwap.check
        jmp   PalUpdateNow

;*******************************************************************************
; engine
;*******************************************************************************
        INCLUDE "engine/InitGlobals.asm"
        INCLUDE "engine/irq/Irq.asm"
        INCLUDE "engine/palette/PalUpdateNow.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.asm"
        INCLUDE "engine/graphics/draw/DrawFullscreenImage.asm"

 ENDSECTION
