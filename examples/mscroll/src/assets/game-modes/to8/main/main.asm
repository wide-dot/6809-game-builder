;*******************************************************************************
; Multidirectional scroll (mscroll) — example
;
; mscroll is a v2 fork of the v1 vertical scroll (the pristine import lives
; in engine/graphics/tilemap/vscroll/). The example scrolls a generated test
; pattern — every tile of the map is unique and every pixel line encodes its
; own (column, row, line) coordinates as nibbles, see tools/gen_mire.py —
; through a cycling code buffer of stack pushes. Vertically, only the lines
; that enter the screen are rewritten in the buffer ; horizontally the
; window rotates hscroll-style (entry chunk + S offset + RAMA/RAMB swap,
; 2px steps, ribbon seam assumed) and the entering 8px tile columns are fed
; into their buffer slot — the map is wider AND taller than the screen,
; scrolled freely on both axes. The map geometry comes from the .equ written
; by the builder's <mscroll> element.
; See docs/lang/fr/etude-mscroll-2026-08.md.
;
; Direct controls : a held direction moves the camera at constant speed,
; releasing stops dead — no inertia. Button A held = fast (2 px/frame),
; button B held = slow (0.5 px/frame), nothing = 1 px/frame. The map drifts
; diagonally on its own until the first input, so the example says something
; with nothing plugged in. The map wraps vertically (v1 behaviour, an
; infinite loop) and clamps horizontally at its edges.
;*******************************************************************************

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.macro.asm"
        INCLUDE "engine/system/thomson/graphics/mode/gfxmode.macro.asm"
        INCLUDE "engine/graphics/tilemap/mscroll/mscroll.macro.asm"

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

        ; the test pattern's palette
        ldd   #Pal_mire
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow

        ; the scroll : map, tileset, code buffers, camera. The geometry
        ; equates come from the generated mire.mscroll.equ.
        _mscroll.setMap #objid.map
        _mscroll.setMapHeight #mire.MAP_HEIGHT
        _mscroll.setMapWidth #mire.MAP_WIDTH
        _mscroll.setMapRowShift #mire.ROWSHIFT
        _mscroll.setTileset512 objid.tilesA,objid.tilesB
        _mscroll.setTileLut
        _mscroll.setBuffer #objid.bufA,#objid.bufB
        _mscroll.setCameraPos #0
        _mscroll.setCameraSpeed ctrlspeed
        _mscroll.setCameraPosX #0
        _mscroll.setCameraSpeedX ctrlspeedx
        ; VIEWPORT SETTINGS AND THE TOP-LINE OVERFLOW. When the window is
        ; between two 16px positions the blast enters the code buffer in the
        ; middle of a line : the leftover of the topmost line (up to 9 chunks
        ; = 36 bytes per plane) is pushed BEFORE the start of the band zone.
        ; Where those bytes land is a project decision, made here by the two
        ; viewport settings (start line, height) :
        ;   plane A : below $C000+start*40 — with start=0 the overflow falls
        ;     in the 192 free bytes between the RAMB half end ($BF40) and
        ;     $C000 : always safe ;
        ;   plane B : below $A000+start*40 — with start=0 it spills into the
        ;     resident page. The engine only reserves 12 bytes there
        ;     (glb_ram_end = $A000-12) : this full-height bench accepts that
        ;     the next globals (glb_register_s, glb_screen_location_*,
        ;     glb_camera_* — all unused here) get trashed. A game keeping a
        ;     full-height band must reserve 36 bytes below $A000, or start
        ;     the band one line down.
        _mscroll.setViewport #0,#200

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
        ; stops dead. A held = fast (2 px/frame), B held = slow (0.5),
        ; nothing = 1 px/frame. The demo drifts on its own until the FIRST
        ; input (attract), so it shows something with nothing plugged in.
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
        ldx   #$0100
        bita  #joypad.0.A
        beq   >
        ldx   #$0200
!       bita  #joypad.0.B
        beq   >
        ldx   #$0080
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
@apply  _mscroll.setCameraSpeed ctrlspeed
        _mscroll.setCameraSpeedX ctrlspeedx
@run
        _gfxlock.on
        jsr   mscroll.do                   ; blast the buffer where the camera is
        jsr   mscroll.move                 ; advance the camera, feed new lines
        _gfxlock.off

        inc   $9C00                        ; a frame counter, so a stall is visible
        _gfxlock.loop
        lbra  mainLoop

ctrlspeed fdb $0080                        ; the demo drift : half a pixel per
ctrlspeedx fdb $0080                       ; frame, down-right, until an input
ctrlmag    fdb $0100                       ; current speed magnitude
demo.attract fcb 1                         ; cleared by the first dpad input

userIRQ
        jsr   gfxlock.bufferSwap.check
        jmp   PalUpdateNow

;*******************************************************************************
; object index — where the map, tilesets and code buffers ended up
;*******************************************************************************
; mscroll reads pages and addresses out of these tables, the v1 way. All five
; are raw binaries at a literal attributed place, published as equates next to
; the file ids in the directory's entries.asm : nothing to relocate.
;
; The buffer and map pages carry RAM_OVER_CART because mscroll mounts them in
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
mscroll.BUFFER_LINES equ 201

;*******************************************************************************
; engine
;*******************************************************************************
        INCLUDE "engine/InitGlobals.asm"
        INCLUDE "engine/irq/Irq.asm"
        INCLUDE "engine/palette/PalUpdateNow.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.asm"
        INCLUDE "engine/graphics/clear/ClearInterlacedDataMemory.asm"
        INCLUDE "engine/graphics/tilemap/mscroll/mscroll.asm"

 ENDSECTION

; a v2 module, which brings its own section
        INCLUDE "engine/system/to8/controller/joypad.asm"
