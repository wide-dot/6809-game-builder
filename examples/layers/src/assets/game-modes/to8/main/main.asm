;*******************************************************************************
; Two planes, 16 sprites ($26 bench)
;
; Same skeleton as examples/sprites, redrawn for the 1bpp background-erase
; pack : $26 superposition (320x200, 1 bit per pixel per plane), a 16-sprite
; swarm on RAMA (in front), background tilemap on RAMB (green, scrolled
; alone). RAMA holds sprites only, so the clear1 encoder erases by clearing
; instead of backing up (CLEAR1BPP below) : no background cells at all.
; 1bpp code is byte-aligned, so each sprite ships eight pre-shifted variants
; (tools/mk_shifts.py) : the shared run routine picks variant (X-x1_0)&7
; and byte column (X-x1_s)>>3, giving pixel-exact horizontal moves.
; Frame order is r-type's :
;   RunObjects / CheckSpritesRefresh / gfxlock.on / EraseSprites /
;   UnsetDisplayPriority / DrawSprites / gfxlock.off / gfxlock.loop
; x_pixel stays a BYTE column for the engine (108..147 visible) ; the game
; keeps pixel X in obj_x and derives both. y_pixel is pixels like BM16.
; Results at $9C00, loader-ut convention :
;   +0 : $CA once the game mode runs
;   +1 : $01 when 16 sprites are drawn (count, expect $10)
;   +2 : display_plane of sprite 0 (expect 0 = RAMA)
;   +5 : frame counter, so a stuck main loop is visible
;   +6 : head of the free cell list, must hold still (no leak)
;   +9 : scroll position LSB, must advance
;*******************************************************************************
set_knight_s0    EXTERNAL
set_knight_s1    EXTERNAL
set_knight_s2    EXTERNAL
set_knight_s3    EXTERNAL
set_knight_s4    EXTERNAL
set_knight_s5    EXTERNAL
set_knight_s6    EXTERNAL
set_knight_s7    EXTERNAL
set_ghost_s0 EXTERNAL
set_ghost_s1 EXTERNAL
set_ghost_s2 EXTERNAL
set_ghost_s3 EXTERNAL
set_ghost_s4 EXTERNAL
set_ghost_s5 EXTERNAL
set_ghost_s6 EXTERNAL
set_ghost_s7 EXTERNAL
set_dragon_s0     EXTERNAL
set_dragon_s1     EXTERNAL
set_dragon_s2     EXTERNAL
set_dragon_s3     EXTERNAL
set_dragon_s4     EXTERNAL
set_dragon_s5     EXTERNAL
set_dragon_s6     EXTERNAL
set_dragon_s7     EXTERNAL
 SECTION code
        ; v2 compatibility bridge : anything resolved at load time expects
        ; the v2 names, the v1 dialect provides IrqOn/IrqOff
irq.on  EXPORT
irq.on  equ   IrqOn
irq.off EXPORT
irq.off equ   IrqOff
        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.macro.asm"
        INCLUDE "engine/graphics/tilemap/vscroll/vscroll.macro.asm"
        INCLUDE "engine/system/thomson/graphics/mode/gfxmode.macro.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.macro.asm"
        INCLUDE "src/assets/game-modes/to8/main/ram_data.asm"
 opt c,ct
        ; the scene loads this file at the game mode region address and jumps
        ; to its first byte : main has to be the first thing emitted, so every
        ; table lives after the code
main
        jsr   InitGlobals
        jsr   InitStack                        ; free-slot stack for Load/Unload
        ; 320x200 two planes : RAMA + RAMB shown together, one bit per pixel
        ; each. Without this the machine stays in its boot mode and reads the
        ; 1bpp bytes as 320x200 two-colour groups instead.
        _gfxmode.set2Layers
        ldd   #userIRQ
        std   Irq_user_routine
        jsr   IrqInit
        jsr   IrqSet50Hz
        ; install the palette : Pal_current is a pointer, so there is nothing
        ; to copy — clearing PalRefresh is what asks for the push
        ldd   #Pal_layers
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow
        _gfxlock.init
        jsr   InitDrawSprites              ; camera offsets, required
        ; vertical dungeon scroll, v1 layout 1bpp : 20 tiles of 16px per
        ; line, 640px map looping under a 200px viewport, from the bottom up
        _vscroll.setMap #objid.map
        _vscroll.setMapHeight #640
        _vscroll.setTileset256 objid.tilesA,objid.tilesB
        _vscroll.setTileNb #9
        _vscroll.setBuffer #objid.bufB,#objid.bufB
        _vscroll.setPlanes #2                ; RAMB-only background, sprites on RAMA
        _vscroll.setCameraPos #440
        _vscroll.setCameraSpeed #$FF00     ; -1 pixel per frame, upward
        _vscroll.setViewport #0,#200
        ; Blank both screen buffers : what boot leaves in video memory is noise.
        ; ClearInterlacedDataMemory fills both 8K planes with X, whatever the
        ; video mode, so one colour clears RAMA and RAMB together.
        jsr   IrqOff
        _ram.data.set #2                   ; screen buffer 0
        ldx   #$0000                       ; colour 0 on both planes
        jsr   ClearInterlacedEvenDataMemory
        ldx   #$0000
        jsr   ClearInterlacedOddDataMemory
        _ram.data.set #3                   ; screen buffer 1
        ldx   #$0000
        jsr   ClearInterlacedEvenDataMemory
        ldx   #$0000
        jsr   ClearInterlacedOddDataMemory
        jsr   IrqOn
        lda   #$CA                         ; the game mode is running
        sta   $9C00
        ; the compiled sprites live in a page mapped over the cartridge
        ; window, so mount it before reading anything of theirs
        _ram.cart.set #assets.sprites.page
        ; imageset sanity : every s0 set exists and its box reads back
        ldx   #set_knight_s0
        lda   ,x
        beq   @knightko
        lda   4,x                          ; x_size : trimmed box reads 12
        cmpa  #12
        bne   @knightko
        lda   5,x                          ; y_size : trimmed box reads 13
        cmpa  #13
        bne   @knightko
        lda   #$01
        sta   $9C04                        ; imageset geometry as generated
@knightko
        ; s0 x1 per image : the pre-shift pick derives every variant from it
        ldy   #set_knight_s0
        ldb   ,y
        leay  b,y
        ldb   image_subset_x1_offset,y
        stb   knight_x1_0
        ldy   #set_ghost_s0
        ldb   ,y
        leay  b,y
        ldb   image_subset_x1_offset,y
        stb   ghost_x1_0
        ldy   #set_dragon_s0
        ldb   ,y
        leay  b,y
        ldb   image_subset_x1_offset,y
        stb   dragon_x1_0
        ; the swarm : 16 objects sharing ObjectRunSwarm, spread over lanes so
        ; overlaps stay rare. i drives everything : image i%3, pixel start
        ; from multiplicative spreads, bounce directions, gating, priority.
        ldu   #Dynamic_Object_RAM
        clrb                               ; i = 0
        clr   swarm_img
        clr   swarm_prio
@spawn  stb   swarm_i
        clrb                               ; pool RAM is not zeroed : wipe the
@clear  clr   b,u                          ; whole slot (base, ext, rsvd), or
        incb                               ; garbage buf_priority/dps links hang
        cmpb  #object_size                 ; the first frames
        blo   @clear
        lda   #1
        sta   id,u                         ; every object runs ObjectRunSwarm
        clr   display_plane,u              ; RAMA, in front of the scroll
        clr   obj_tick,u
        clr   obj_dir,u
        ldd   #888                         ; xmin, pixel floor for every variant
        std   obj_xmin,u
        ldd   #1144                        ; xmax, byte box stays <= 147
        std   obj_xmax,u
        lda   #40
        sta   obj_ymin,u
        lda   #180
        sta   obj_ymax,u
        lda   swarm_img                    ; image 0,1,2 : base table + x1_0
        cmpa  #1
        beq   @imgghost
        cmpa  #2
        beq   @imgdragon
        ldx   #KnightSets
        stx   obj_imgbase,u
        ldb   knight_x1_0
        bra   @imgdone
@imgghost
        ldx   #GhostSets
        stx   obj_imgbase,u
        ldb   ghost_x1_0
        bra   @imgdone
@imgdragon
        ldx   #DragonSets
        stx   obj_imgbase,u
        ldb   dragon_x1_0
@imgdone
        stb   obj_x1_0,u
        ldx   ,x                           ; image_set starts at the s0 variant
        stx   image_set,u
        lda   swarm_img
        inca
        cmpa  #3
        blo   @imgkeep
        clra
@imgkeep
        sta   swarm_img
        lda   swarm_prio                   ; priority cycles 0..6 -> 2..8
        adda  #2
        sta   priority,u
        lda   swarm_prio
        inca
        cmpa  #7
        blo   @priokeep
        clra
@priokeep
        sta   swarm_prio
        lda   #91                          ; x0 = 888 + (i*91 mod 256)
        ldb   swarm_i
        mul
        clra
        addb  #$78
        adca  #3
        std   obj_x,u
        lda   #53                          ; y0 = 44 + (i*53 mod 128)
        ldb   swarm_i
        mul
        andb  #127
        addb  #44
        stb   y_pixel,u
        lda   swarm_i                      ; dx = +1/-1 alternating
        anda  #1
        beq   @dxneg
        ldb   #1
        bra   @dxdone
@dxneg  ldb   #-1
@dxdone stb   obj_dx,u
        lda   swarm_i                      ; dy : fall, rise, or static lanes
        anda  #6
        cmpa  #2
        beq   @dyplus
        cmpa  #4
        beq   @dyminus
        clrb
        bra   @dydone
@dyplus ldb   #1
        bra   @dydone
@dyminus
        ldb   #-1
@dydone stb   obj_dy,u
        lda   swarm_i                      ; half the swarm moves every 4th tick :
        anda  #8                           ; still between two frames of the same
        beq   @gate0                       ; buffer, so CSR sees them unchanged and
        lda   #3                           ; the dirty bitmap upgrade path runs
        bra   @gatedone
@gate0  clra
@gatedone
        sta   obj_gate,u
        ldd   obj_x,u                      ; rough first byte column, the run
        lsra                               ; routine sets the exact one before
        rorb                               ; CSR ever looks
        lsra
        rorb
        lsra
        rorb
        stb   x_pixel,u
        clr   rsv_render_flags,u           ; pool RAM is not zeroed : engine rsv
        clr   rsv_prev_render_flags_0,u    ; flags start clean, or the first
        clr   rsv_prev_render_flags_1,u    ; frames erase garbage as if on screen
        ldx   swarm_prev                   ; chain the run list
        beq   @firstobj
        stx   run_object_prev,u
        stu   run_object_next,x
        bra   @nextobj
@firstobj
        stu   object_list_first
        ldd   #0
        std   run_object_prev,u
@nextobj
        stu   swarm_prev
        leau  object_size,u
        ldb   swarm_i
        incb
        cmpb  #16
        bhs   @spawned
        lbra  @spawn
@spawned
        ldu   swarm_prev                   ; terminate the run list
        ldd   #0
        std   run_object_next,u
mainLoop
        jsr   RunObjects
        jsr   CheckSpritesRefresh
        _gfxlock.on
        jsr   vscroll.do                   ; blast the scroll where the camera is
        jsr   vscroll.move                 ; advance the camera, feed new lines
        jsr   EraseSprites
        jsr   UnsetDisplayPriority
        jsr   DrawSprites
        _gfxlock.off
        inc   $9C05                        ; the main loop is alive
        ldd   vscroll.camera.y
        stb   $9C09                        ; scroll position LSB, must advance
        ldu   #Dynamic_Object_RAM          ; drawn count, expect 16
        ldx   #16
        clrb
@count  lda   rsv_render_flags,u
        bita  #rsv_render_outofrange_mask
        bne   @nextc
        bita  #rsv_render_displaysprite_mask
        beq   @nextc
        incb
@nextc  leau  object_size,u
        leax  -1,x
        bne   @count
        stb   $9C01
        ldu   #Dynamic_Object_RAM          ; plane of object 0, expect RAMA
        lda   display_plane,u
        sta   $9C02
        ldd   Lst_FreeCellFirstEntry_0     ; no leak while sprites cross
        std   $9C06
        _gfxlock.loop
        lbra  mainLoop                     ; the loop body outgrew a short branch
; ObjectRunSwarm : every object shares it, behaviour is per-object data.
; Gated move (obj_gate masks the tick), bounce inside the bounds, then the
; pre-shift pick : variant (X-x1_0)&7, byte column (X-x1_s)>>3. A variant
; change is a mapping_frame change, so CSR erases and draws as usual.
ObjectRunSwarm
        inc   obj_tick,u
        lda   obj_tick,u
        anda  obj_gate,u
        bne   @place
        ldb   obj_dx,u                     ; X, signed, never 0 here
        beq   @movY
        sex
        addd  obj_x,u
        std   obj_x,u
        cmpd  obj_xmin,u
        bge   @xhi
        ldd   obj_xmin,u
        std   obj_x,u
        neg   obj_dx,u
        bra   @movY
@xhi    cmpd  obj_xmax,u
        ble   @movY
        ldd   obj_xmax,u
        std   obj_x,u
        neg   obj_dx,u
@movY   ldb   obj_dy,u                     ; Y, signed byte
        beq   @place
        addb  y_pixel,u
        stb   y_pixel,u
        cmpb  obj_ymin,u                   ; unsigned : y goes up to 180
        bhs   @yhi
        ldb   obj_ymin,u
        stb   y_pixel,u
        neg   obj_dy,u
        bra   @place
@yhi    cmpb  obj_ymax,u
        bls   @place
        ldb   obj_ymax,u
        stb   y_pixel,u
        neg   obj_dy,u
@place  ldb   obj_x1_0,u                   ; variant s = (X-x1_0)&7, low bytes
        sex                                ; only : the mod-8 needs no borrow
        std   swarm_tmp
        ldd   obj_x,u
        subd  swarm_tmp
        andb  #7
        stb   obj_s,u
        ldx   obj_imgbase,u                ; image_set = base[s]
        lslb
        ldx   b,x
        stx   image_set,u
        ldd   obj_x,u                      ; byte column = (X-x1_0-s)>>3,
        subd  swarm_tmp                    ; a multiple of 8 by construction
        subb  obj_s,u
        sbca  #0
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        stb   x_pixel,u
        jmp   DisplaySprite
userIRQ
        jsr   PalUpdateNow
        jsr   gfxlock.bufferSwap.check
        rts
        ; hand-written palette : $26 shows three entries only (0 background,
        ; 1 RAMA ink, 2 RAMB ink), so png2pal's reordered table is useless
        ; here. Words are GR-first ($f000 renders green, $0f00 red).
        ; Lives in the game mode unit : Pal_current is read under interrupt.
Pal_layers
        fdb   $0000                     ; 0 : background, black
        fdb   $0f00                     ; 1 : RAMA ink (sprites), renders red
        fdb   $f000                     ; 2 : RAMB ink (dungeon), renders green
        fdb   $0000
        fdb   $0000
        fdb   $0000
        fdb   $0000
        fdb   $0000
        fdb   $0000
        fdb   $0000
        fdb   $0000
        fdb   $0000
        fdb   $0000
        fdb   $0000
        fdb   $0000
        fdb   $0000
        ; pre-shift variant sets per image, s0..s7, picked by (X-x1_0)&7
KnightSets
        fdb   set_knight_s0
        fdb   set_knight_s1
        fdb   set_knight_s2
        fdb   set_knight_s3
        fdb   set_knight_s4
        fdb   set_knight_s5
        fdb   set_knight_s6
        fdb   set_knight_s7
GhostSets
        fdb   set_ghost_s0
        fdb   set_ghost_s1
        fdb   set_ghost_s2
        fdb   set_ghost_s3
        fdb   set_ghost_s4
        fdb   set_ghost_s5
        fdb   set_ghost_s6
        fdb   set_ghost_s7
DragonSets
        fdb   set_dragon_s0
        fdb   set_dragon_s1
        fdb   set_dragon_s2
        fdb   set_dragon_s3
        fdb   set_dragon_s4
        fdb   set_dragon_s5
        fdb   set_dragon_s6
        fdb   set_dragon_s7
        ; swarm spawn state and scratch, written once at init
swarm_tmp fdb 0
swarm_prev fdb 0
swarm_i fcb 0
swarm_img fcb 0
swarm_prio fcb 0
knight_x1_0 fcb 0
ghost_x1_0 fcb 0
dragon_x1_0 fcb 0
        ; object indexes : emitted data, hence placed after the entry point
        INCLUDE "src/assets/game-modes/to8/main/obj_index.asm"
        INCLUDE "engine/InitGlobals.asm"
        INCLUDE "engine/irq/Irq.asm"
        INCLUDE "engine/palette/PalUpdateNow.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.asm"
        INCLUDE "engine/graphics/clear/ClearInterlacedDataMemory.asm"
        INCLUDE "engine/object-management/RunObjects.asm"
        INCLUDE "engine/graphics/tilemap/vscroll/vscroll.asm"
CLEAR1BPP equ 1
        INCLUDE "engine/graphics/sprite/sprite-background-erase-1bpp-pack.asm"
 ENDSECTION
