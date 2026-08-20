;*******************************************************************************
; Vertical scroll (vscroll) — example
;
; vscroll is the v1 vertical scroll, imported 1:1 (see engine/v1-manifest.csv).
; The example scrolls a 160x640 map — the stage 3 battleship of R-Type, at
; TO8 scale, with generated position markers — up and down through a cycling
; code buffer of stack pushes. Only the lines that enter the screen are
; rewritten in the buffer ; the whole buffer is blasted every rendered frame.
; Asset formats (map packing, tileset layout) : the module's vscroll.md.
;
; Up and down on the joypad or keyboard steer, up to two pixels per frame.
; The map starts drifting on its own so the example says something with
; nothing plugged in. The map wraps on itself (v1 behaviour, an infinite
; level loop) : the border rows meeting is the wrap, not a defect.
;*******************************************************************************

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.macro.asm"
        INCLUDE "engine/system/thomson/graphics/mode/gfxmode.macro.asm"
        INCLUDE "engine/graphics/tilemap/vscroll/vscroll.macro.asm"

        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/controller/joypad.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.macro.asm"

 opt c,ct

        ; the scene loads this at the game mode region and jumps to its first
        ; byte, so main has to be the first thing emitted

main
        jsr   InitGlobals
        jsr   joypad.init

        ; 160x200 in 16 colours. Without this the machine stays in its boot
        ; mode and the map's bytes get read as 320x200x2, which shreds it.
        _gfxmode.setBM16

        ; Blank both screen buffers : what boot leaves in video memory is
        ; noise. The routine writes through the data window, so the page has
        ; to be mounted there first, and it blasts through S : interrupts off.
        jsr   IrqOff
        _ram.data.set #2                   ; screen buffer 0
        ldx   #$0000
        jsr   ClearInterlacedEvenDataMemory
        ldx   #$0000
        jsr   ClearInterlacedOddDataMemory
        _ram.data.set #3                   ; screen buffer 1
        ldx   #$0000
        jsr   ClearInterlacedEvenDataMemory
        ldx   #$0000
        jsr   ClearInterlacedOddDataMemory

        ; the ship's own palette
        ldd   #Pal_ship
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow

        ; the scroll : map, tileset, code buffers, camera. Same call sequence
        ; as the v1 vscroll projects.
        _vscroll.setMap #objid.map
        _vscroll.setMapHeight #640
        _vscroll.setTileset256 objid.tilesA,objid.tilesB
        _vscroll.setTileNb #256
        _vscroll.setBuffer #objid.bufA,#objid.bufB
        _vscroll.setCameraPos #0
        _vscroll.setCameraSpeed ctrlspeed
        _vscroll.setViewport #0,#200

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
        ; steering, capped at two pixels per frame either way
        jsr   joypad.read
        lda   joypad.held.dpad
        bita  #joypad.0.UP
        beq   @down
        ldx   ctrlspeed
        leax  -$0010,x
        cmpx  #-$0200
        bge   @store
        ldx   #-$0200
        bra   @store
@down
        bita  #joypad.0.DOWN
        beq   @steered
        ldx   ctrlspeed
        leax  $0010,x
        cmpx  #$0200
        ble   @store
        ldx   #$0200
@store  stx   ctrlspeed
        _vscroll.setCameraSpeed ctrlspeed
@steered

        _gfxlock.on
        jsr   vscroll.do                   ; blast the buffer where the camera is
        jsr   vscroll.move                 ; advance the camera, feed new lines
        _gfxlock.off

        inc   $9C00                        ; a frame counter, so a stall is visible
        _gfxlock.loop
        lbra  mainLoop

ctrlspeed fdb $0080                        ; half a pixel per frame, downward

userIRQ
        jsr   gfxlock.bufferSwap.check
        jmp   PalUpdateNow

;*******************************************************************************
; object index — where the map, tilesets and code buffers ended up
;*******************************************************************************
; vscroll reads pages and addresses out of these tables, the v1 way. All five
; are raw binaries at a literal attributed place, published as equates next to
; the file ids in the directory's entries.asm : nothing to relocate.
;
; The buffer and map pages carry RAM_OVER_CART because vscroll mounts them in
; cartridge space (_SetCartPageA) ; the tileset pages are mounted in the data
; window ($E7E5, page number only) and stay plain.

objid.map    equ 1
objid.tilesA equ 2
objid.tilesB equ 3
objid.bufA   equ 4
objid.bufB   equ 5

Obj_Index_Page
        fcb   $00
        fcb   map.RAM_OVER_CART+assets.map.page
        fcb   assets.tilesA.page
        fcb   assets.tilesB.page
        fcb   map.RAM_OVER_CART+assets.bufA.page
        fcb   map.RAM_OVER_CART+assets.bufB.page

Obj_Index_Address
        fdb   $0000
        fdb   assets.map.address
        fdb   assets.tilesA.address
        fdb   assets.tilesB.address
        fdb   assets.bufA.address
        fdb   assets.bufB.address

; 200 lines from the start view plus the extra line of the buffer objects
vscroll.BUFFER_LINES equ 201

;*******************************************************************************
; engine
;*******************************************************************************
        INCLUDE "engine/InitGlobals.asm"
        INCLUDE "engine/irq/Irq.asm"
        INCLUDE "engine/palette/PalUpdateNow.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.asm"
        INCLUDE "engine/graphics/clear/ClearInterlacedDataMemory.asm"
        INCLUDE "engine/graphics/tilemap/vscroll/vscroll.asm"

 ENDSECTION

; a v2 module, which brings its own section
        INCLUDE "engine/system/to8/controller/joypad.asm"
