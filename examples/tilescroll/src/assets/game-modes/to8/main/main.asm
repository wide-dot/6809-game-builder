;*******************************************************************************
; Horizontal tilemap scroll — example
;
; The scroll r-type level 1 uses, on a generated test map. It moves one pixel
; at a time over a map of compiled tiles, and the trick that makes that free is
; the pair of maps : the even one points at the unshifted tile routines, the
; odd one at the same tiles pre-shifted by a pixel, so an odd camera position
; costs a different table lookup rather than any work.
;
; Not to be confused with examples/hscroll, which loops a fixed width band on
; itself. This one walks a map longer than the screen and has no wrap.
;
; The tiles and the map are measuring patterns — see tools/. Column parity
; alternates two flat tiles, every fourth column carries a framed one so
; columns can be counted, and a diagonal runs along the top row so a broken
; tile boundary reads as a broken line.
;
; Left and right steer, and it drifts on its own so the example says something
; with nothing plugged in. Results at $9C00 :
;   +0 : $CA the game mode runs
;   +1 : frame counter, so a stall is visible
;   +2 : (word) glb_camera_x_pos, so the scroll can be read from memory
;*******************************************************************************

adr_tile0_ND0 EXTERNAL
adr_tile0_ND1 EXTERNAL
adr_tile1_ND0 EXTERNAL
adr_tile1_ND1 EXTERNAL
adr_tile2_ND0 EXTERNAL
adr_tile2_ND1 EXTERNAL
adr_tile3_ND0 EXTERNAL
adr_tile3_ND1 EXTERNAL
assets.tiles$PAGE EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.macro.asm"
        INCLUDE "engine/system/thomson/graphics/mode/gfxmode.macro.asm"

        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/controller/joypad.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.macro.asm"

        INCLUDE "gen/layout.asm"

; The scroll asks the game for these two, and caps the camera with them so the
; map never runs off its own end.
tile_size       equ 12
viewport_width  equ 12*tile_size
map_width       equ 24*tile_size

 opt c,ct

        ; the scene loads this at the game mode region and jumps to its first
        ; byte, so main has to be the first thing emitted

main
        jsr   InitGlobals
        jsr   joypad.init

        ; 160x200 in 16 colours : compiled tiles are that format, and without
        ; this the machine stays in its boot mode and reads them as 320x200
        ; with two colours per 8 pixels
        _gfxmode.setBM16

        ldd   #Pal_tiles
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow

        ; blank both buffers : the scroll only paints its viewport
        jsr   IrqOff
        _ram.data.set #2
        ldx   #$0000
        jsr   ClearInterlacedEvenDataMemory
        ldx   #$0000
        jsr   ClearInterlacedOddDataMemory
        _ram.data.set #3
        ldx   #$0000
        jsr   ClearInterlacedEvenDataMemory
        ldx   #$0000
        jsr   ClearInterlacedOddDataMemory
        jsr   IrqOn

        lda   #$CA
        sta   $9C00

        ; the map, and where it lives
        ldd   #map.even
        std   scroll_map_even
        ldd   #map.odd
        std   scroll_map_odd
        lda   #map.RAM_OVER_CART+gamemode.page
        sta   scroll_map_page_even
        sta   scroll_map_page_odd

        ; the viewport, in tiles and in pixels
        lda   #12
        sta   scroll_vp_h_tiles
        lda   #map.ROWS
        sta   scroll_vp_v_tiles
        lda   #tile_size
        sta   scroll_tile_width
        sta   scroll_tile_height
        lda   #8                           ; viewport position on screen
        sta   scroll_vp_x_pos
        lda   #40
        sta   scroll_vp_y_pos
        ldd   #$0030                       ; 8.8 : r-type's own scroll speed
        std   scroll_vel

        jsr   InitScroll

        ldd   #userIRQ
        std   Irq_user_routine
        jsr   IrqInit
        lda   #255
        ldx   #Irq_one_frame
        jsr   IrqSync
        _gfxlock.init
        jsr   IrqOn

mainLoop
        jsr   joypad.read
        lda   joypad.held.dpad
        bita  #joypad.0.LEFT
        beq   @right
        ldd   #-$0030
        std   scroll_vel
        bra   @steered
@right
        bita  #joypad.0.RIGHT
        beq   @steered
        ldd   #$0030
        std   scroll_vel
@steered

        ; Scroll advances the camera and works out what has to be repainted ;
        ; DrawTiles does the painting. They sit on either side of the lock,
        ; because only the second one touches the screen.
        jsr   Scroll
        _gfxlock.on
        jsr   DrawTiles
        _gfxlock.off

        inc   $9C01
        ldd   glb_camera_x_pos
        std   $9C02
        _gfxlock.loop
        lbra  mainLoop

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
        INCLUDE "engine/graphics/clear/ClearInterlacedDataMemory.asm"
        INCLUDE "engine/graphics/tilemap/horizontal-scroll/scroll-map-buffered-even.asm"

 ENDSECTION

; The map brings its own section, map.static : its tile references are baked
; by the builder against the tiles' declared region, so they cost nothing at
; load time. The code above reaches map.even/map.odd across sections, which
; stays an ordinary intern relocation.
        INCLUDE "src/assets/maps/testmap.asm"

; a v2 module, which brings its own section
        INCLUDE "engine/system/to8/controller/joypad.asm"
