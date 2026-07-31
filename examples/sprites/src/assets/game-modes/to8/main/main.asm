;*******************************************************************************
; Compiled sprites — toolchain bench (M3)
;
; What this proves : PNGs go through gfxcomp inside a <lwasm> unit, land in a
; direntry of their own, and the game mode reaches their imageset index through
; the load time linker. Drawing them is the next step (M4, once the v1 sprite
; runtime is imported) ; for now the game mode only checks that the index is
; there and reports what it read at $9C00, the loader-ut convention:
;
;   +0 : magic $CA once the game mode runs
;   +1 : $01 when the shell imageset index reads back as expected
;   +2 : $01 when the launcher imageset index reads back as expected
;*******************************************************************************

set_shell    EXTERNAL
set_launcher EXTERNAL

 SECTION code

        ; v2 compatibility bridge : anything resolved at load time expects
        ; the v2 names, the v1 dialect provides IrqOn/IrqOff
irq.on  EXPORT
irq.on  equ   IrqOn
irq.off EXPORT
irq.off equ   IrqOff

        ; v1 engine dialect (1:1 imported files)
        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.macro.asm"

        ; v2 kept features : loader/scenes, ram paging
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.macro.asm"

page.sprites equ map.RAM_OVER_CART+6   ; sprites region, as declared in <layout>

 opt c,ct

main
        jsr   InitGlobals
        ldd   #userIRQ
        std   Irq_user_routine
        jsr   IrqInit
        jsr   IrqSet50Hz
        jsr   PalUpdateNow
        _gfxlock.init

        lda   #$CA                 ; the game mode is running
        sta   $9C00

        ; the compiled sprites live in a page mapped over the cartridge
        ; window, so mount it before reading anything of theirs
        _ram.cart.set #page.sprites

        ; imageset header : [n][x][y][xy] sub set offsets, then x_size,
        ; y_size, center_offset. A missing mirror falls back to an existing
        ; one, so every offset is non zero as soon as one variant exists.
        ldx   #set_shell
        lda   ,x                   ; unmirrored sub set offset
        beq   @shellko
        lda   4,x                  ; x_size
        cmpa  #11
        bne   @shellko
        lda   5,x                  ; y_size
        cmpa  #21
        bne   @shellko
        lda   #$01
        sta   $9C01
@shellko

        ldx   #set_launcher
        lda   ,x
        beq   @launcherko
        lda   4,x
        cmpa  #2
        bne   @launcherko
        lda   5,x
        cmpa  #2
        bne   @launcherko
        lda   #$01
        sta   $9C02
@launcherko

mainLoop
        _gfxlock.on
        _gfxlock.off
        _gfxlock.loop
        bra   mainLoop

userIRQ
        jsr   PalUpdateNow
        jsr   gfxlock.bufferSwap.check
        rts

        INCLUDE "engine/InitGlobals.asm"
        INCLUDE "engine/irq/Irq.asm"
        INCLUDE "engine/palette/PalUpdateNow.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.asm"

 ENDSECTION
