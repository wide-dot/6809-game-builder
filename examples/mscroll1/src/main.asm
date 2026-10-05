;*******************************************************************************
; Multidirectional scroll, one bit per pixel (mscroll1) — example
;
; Mode $24 (320x200, RAMA alone, two colours). A generated 8192x1024 test
; pattern (tools/gen_mire.py) — a two-level map : layout -> 128x128 chunks ->
; 16x16 blocks — scrolled through mscroll1's cycling code buffer. The
; window moves by 8 px steps (camera.x rounded down) and 1 px vertically.
; See docs/lang/fr/etude-mscroll1-2026-10.md.
;
; Direct controls : a held direction moves the camera at constant speed,
; releasing stops dead. Button A held = fast (4 px/frame), button B held =
; slow (1 px/frame), nothing = 2 px/frame. The map drifts diagonally on its
; own until the first input. The map wraps vertically and clamps
; horizontally at its edges.
;
; mscroll1.mask blacks what the blast cannot get right : the overlap byte at
; the right of every line and the band's top line — 312 x 199 px are shown.
;
; Witnesses at $9C00 : +0 frame counter (a stall is visible).
;*******************************************************************************

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.macro.asm"
        INCLUDE "engine/system/thomson/graphics/mode/gfxmode.macro.asm"
        INCLUDE "engine/graphics/tilemap/mscroll1/mscroll1.macro.asm"

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

        ; 320x200, one bit per pixel, RAMA alone
        _gfxmode.setLayer1

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

        ldd   #Pal_mono
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow

        ; the scroll : map, tileset, code buffer, viewport, camera, then the
        ; buffer is filled by feeding the 20 window columns
        _mscroll1.setMap #objid.map,#mire.LAYOUT_STRIDE,#mire.CHUNKS_OFFSET
        _mscroll1.setMapHeight #mire.MAP_HEIGHT
        _mscroll1.setMapWidth #mire.MAP_WIDTH
        _mscroll1.setTileset #objid.tiles
        _mscroll1.setBuffer #objid.buffer
        ; full height : the top line's leftover (up to 36 bytes) is pushed
        ; below $C000, into the end of the RAMB zone, unused in $24
        _mscroll1.setViewport #0,#200
        _mscroll1.setCameraPos #0
        _mscroll1.setCameraPosX #0
        _mscroll1.setCameraSpeed ctrlspeed
        _mscroll1.setCameraSpeedX ctrlspeedx
        jsr   mscroll1.init

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
        ; direct controls : a held direction is a constant speed, releasing
        ; stops dead. The demo drifts on its own until the FIRST input.
        jsr   joypad.read
        lda   joypad.held.dpad
        anda  #joypad.0.DPAD
        bne   @steer
        tst   demo.attract
        bne   @run                         ; no input yet : keep the demo drift
        ldd   #0                           ; released : stop dead
        std   ctrlspeed
        std   ctrlspeedx
        bra   @apply
@steer  clr   demo.attract
        ; speed magnitude from the buttons (both held : slow wins)
        lda   joypad.held.fire
        ldx   #$0200
        bita  #joypad.0.A
        beq   >
        ldx   #$0400
!       bita  #joypad.0.B
        beq   >
        ldx   #$0100
!       stx   ctrlmag
        ; vertical
        lda   joypad.held.dpad
        bita  #joypad.0.UP
        beq   @down
        ldd   ctrlmag
        _negd
        bra   @sety
@down   bita  #joypad.0.DOWN
        beq   @zeroy
        ldd   ctrlmag
        bra   @sety
@zeroy  ldd   #0
@sety   std   ctrlspeed
        ; horizontal
        lda   joypad.held.dpad
        bita  #joypad.0.LEFT
        beq   @right
        ldd   ctrlmag
        _negd
        bra   @setx
@right  bita  #joypad.0.RIGHT
        beq   @zerox
        ldd   ctrlmag
        bra   @setx
@zerox  ldd   #0
@setx   std   ctrlspeedx
@apply  _mscroll1.setCameraSpeed ctrlspeed
        _mscroll1.setCameraSpeedX ctrlspeedx
@run
        _gfxlock.on
        jsr   mscroll1.do                  ; blast the buffer where the camera is
        jsr   mscroll1.mask                ; black the overlap byte and the top line
        jsr   mscroll1.move                ; advance the camera, feed new lines
        _gfxlock.off

        inc   $9C00                        ; a frame counter, so a stall is visible
        _gfxlock.loop
        lbra  mainLoop

ctrlspeed fdb $0080                        ; the demo drift : half a pixel per
ctrlspeedx fdb $0100                       ; frame down, one right, until an input
ctrlmag    fdb $0200                       ; current speed magnitude
demo.attract fcb 1                         ; cleared by the first dpad input

userIRQ
        jsr   gfxlock.bufferSwap.check
        jmp   PalUpdateNow

Pal_mono
        fdb   $0000                        ; 0 : paper, black
        fdb   $FF0F                        ; 1 : ink, white
        fill  0,28

;*******************************************************************************
; object index — where the map, tileset and code buffer ended up
;*******************************************************************************
; mscroll1 reads pages and addresses out of these tables, the v1 way. All
; three are raw binaries at a literal attributed place, published as equates
; next to the file ids in the directory's entries.asm.
;
; The buffer and map pages carry RAM_OVER_CART because mscroll1 mounts them
; in cartridge space (_SetCartPageA) ; the tileset page is mounted in the
; data window ($E7E5, page number only) and stays plain.

objid.map    equ 1
objid.tiles  equ 2
objid.buffer equ 3

Obj_Index_Page
        fcb   $00
        fcb   map.RAM_OVER_CART+assets.map.page
        fcb   assets.tiles.page
        fcb   map.RAM_OVER_CART+assets.buffer.page

Obj_Index_Address
        fdb   $0000
        fdb   assets.map.address
        fdb   assets.tiles.address
        fdb   assets.buffer.address

; 200 lines of view plus the extra line of the cycle
mscroll1.BUFFER_LINES equ 201

;*******************************************************************************
; engine
;*******************************************************************************
        INCLUDE "engine/InitGlobals.asm"
        INCLUDE "engine/irq/Irq.asm"
        INCLUDE "engine/palette/PalUpdateNow.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.asm"
        INCLUDE "engine/graphics/clear/ClearInterlacedDataMemory.asm"
        INCLUDE "engine/graphics/tilemap/mscroll1/mscroll1.asm"

 ENDSECTION

; a v2 module, which brings its own section
        INCLUDE "engine/system/to8/controller/joypad.asm"
