;*******************************************************************************
; Compiled sprites — bench
;
; Walks the whole path : PNG compiled by gfxcomp, loaded as a direntry of its
; own, reached through the imageset index resolved by the load time linker,
; then drawn by the v1 sprite runtime imported 1:1.
;
; Frame order is r-type's (game-mode/01/main.asm) :
;   RunObjects / CheckSpritesRefresh / gfxlock.on / EraseSprites /
;   UnsetDisplayPriority / DrawSprites / gfxlock.off / gfxlock.loop
;
; Results at $9C00, loader-ut convention :
;   +0 : $CA once the game mode runs
;   +1 : $01 the shell imageset index reads back as expected
;   +2 : $01 the launcher imageset index reads back as expected
;   +3 : $01 the sprite reached the screen buffer
;   +4 : $01 a background cell was allocated for it
;   +5 : frame counter, so a stuck main loop is visible
;   +6 : head of the free cell list, must hold still (no leak)
;   +8 : $01 once the animation has been seen on both of its frames
;   +9 : $01 the compressed image's imageset entry reads back as expected
;   +10: $01 the compressed image was drawn, and drawn as an overlay
;
; The compressed image is a full width band, and that is not incidental : a
; zx0 image is decompressed straight onto the screen in one contiguous run,
; so it covers every byte of every line it spans. It is a background format.
;*******************************************************************************

set_shell    EXTERNAL
set_launcher EXTERNAL
set_band     EXTERNAL
Ani_shell    EXTERNAL

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

        ; the memory layout of this target, generated from <layout>
        INCLUDE "gen/layout.asm"

        ; object sizing and RAM placement, the game's to declare (equates only)
        INCLUDE "src/assets/game-modes/to8/main/ram_data.asm"

 opt c,ct

        ; the scene loads this file at the game mode region address and jumps
        ; to its first byte : main has to be the first thing emitted, so every
        ; table lives after the code

main
        jsr   InitGlobals
        ldd   #userIRQ
        std   Irq_user_routine
        jsr   IrqInit
        jsr   IrqSet50Hz

        ; install the sprites' palette : Pal_current is a pointer, so there is
        ; nothing to copy — clearing PalRefresh is what asks for the push
        ldd   #Pal_sprites
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow
        _gfxlock.init
        jsr   InitDrawSprites              ; camera offsets, required

        ; Blank both screen buffers : what boot leaves in video memory is noise,
        ; and it drowns the sprite the bench exists to show. The routine writes
        ; through the data window, so the page has to be mounted there first,
        ; and it blasts through S, so interrupts have to be off.
        jsr   IrqOff
        _ram.data.set #2                   ; screen buffer 0
        ldx   #$0000                       ; colour 0, four pixels at a time
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
        _ram.cart.set #sprites.page

        ; imageset header : [n][x][y][xy] sub set offsets, then x_size,
        ; y_size, center_offset. A missing mirror falls back to an existing
        ; one, so every offset is non zero as soon as one variant exists.
        ldx   #set_shell
        lda   ,x                           ; unmirrored sub set offset
        beq   @shellko
        lda   4,x                          ; x_size
        cmpa  #11
        bne   @shellko
        lda   5,x                          ; y_size
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

        ldx   #set_band
        lda   ,x                           ; unmirrored sub set offset
        beq   @bandsetko
        ; The sizes are the bounding box minus one, so this 160x24 image reads
        ; back as 159 by 23. It is deliberately full width : a zx0 image is a
        ; background, not a sprite. The encoder drops transparency and emits a
        ; contiguous run of the plane buffer, so the decompressor overwrites
        ; every byte of every line it spans, whatever the image's own width.
        ldb   4,x                          ; x_size
        cmpb  #159
        bne   @bandsetko
        ldb   5,x                          ; y_size
        cmpb  #23
        bne   @bandsetko
        ; inside the sub set, the four variant offsets are B0, D0, B1, D1.
        ; A zx0 image is filed under D0 and nowhere else : that entry has to
        ; exist, and the background erase one has to be absent.
        leax  a,x                          ; a still holds the sub set offset
        lda   ,x                           ; B0, the background erase variant
        bne   @bandsetko
        lda   1,x                          ; D0, the one the runtime will pick
        beq   @bandsetko
        lda   #$01
        sta   $9C09
@bandsetko

        ; one object, the shell sprite, near the middle of the screen.
        ; render_flags leaves render_playfieldcoord unset, so the engine takes
        ; the position as screen coordinates and never looks at x_pos/y_pos ;
        ; a scrolling game sets that flag and gives playfield coordinates.
        ldu   #sprite1
        lda   #1                           ; id 1, the entry of the object indexes
        sta   id,u
        ; screen coordinates are offset so that positions just off screen stay
        ; representable in a byte : the visible area is screen_left..right by
        ; screen_top..bottom, and a sprite is dropped as out of range as soon
        ; as its bounding box leaves it
        lda   #screen_left+70              ; x_pixel
        sta   x_pixel,u
        lda   #screen_top+90               ; y_pixel
        sta   y_pixel,u
        ldx   #set_shell
        stx   image_set,u
        lda   #2                           ; priority 2 : a moving sprite, front
        sta   priority,u
        ldd   #Ani_shell                   ; positive : a direct address
        std   anim,u

        ; The compressed image. render_overlay_mask is what makes it work at
        ; all : it tells CheckSpritesRefresh to look the image up in the draw
        ; slot — the only one a zx0 image is filed under — and it tells the
        ; runtime not to back up the background, which a decompressor writing
        ; straight to the screen could not restore anyway. Nothing erases it,
        ; so it simply stays put frame after frame.
        ldu   #sprite2
        lda   #2                           ; id 2
        sta   id,u
        lda   #render_overlay_mask
        sta   render_flags,u
        lda   #screen_left+79              ; a full width band : it spans exactly the
                                           ; visible width, so this is the only
                                           ; position that is not out of range
        sta   x_pixel,u
        lda   #screen_top+140
        sta   y_pixel,u
        ldx   #set_band
        stx   image_set,u
        lda   #3                           ; priority 3 : behind the shell
        sta   priority,u

        ldx   #sprite1                     ; register both in the run list
        stx   object_list_first
        ldx   #sprite2
        stx   run_object_next+sprite1

mainLoop
        jsr   RunObjects
        jsr   CheckSpritesRefresh

        _gfxlock.on
        jsr   EraseSprites
        jsr   UnsetDisplayPriority
        jsr   DrawSprites
        _gfxlock.off

        inc   $9C05                        ; the main loop is alive

        ldu   #sprite1

        ; the runtime decided to draw : in range and display flag set
        lda   rsv_render_flags,u
        bita  #rsv_render_outofrange_mask
        bne   @notdrawn
        bita  #rsv_render_displaysprite_mask
        beq   @notdrawn
        lda   #$01
        sta   $9C03
@notdrawn

        ; a drawn sprite owns a background cell until the next erase pass
        ldd   rsv_bgdata_0,u
        bne   @cell
        ldd   rsv_bgdata_1,u
        beq   @nocell
@cell   lda   #$01
        sta   $9C04
@nocell

        ; head of the free cell list of buffer 0 : allocate and free must
        ; balance out, so a leak shows up here as a drift frame after frame
        ldd   Lst_FreeCellFirstEntry_0
        std   $9C06

        ; the animation has to reach both of its frames
        ldd   image_set,u
        cmpd  #set_shell
        bne   @notframe0
        lda   #$01
        sta   @seen0+1
@notframe0
        cmpd  #set_launcher
        bne   @notframe1
        lda   #$01
        sta   @seen1+1
@notframe1
@seen0  lda   #$00
        beq   @animko
@seen1  lda   #$00
        beq   @animko
        lda   #$01
        sta   $9C08
@animko

        ; the compressed sprite : drawn, and recorded as an overlay. The second
        ; half is the point — it is the bit EraseSprites reads to decide not to
        ; call an erase routine, and a zx0 image has none to call. Note this is
        ; not rsv_bgdata : DrawSprites stores the draw routine's U there for
        ; every sprite, overlay or not, so it says nothing either way.
        ldu   #sprite2
        lda   rsv_render_flags,u
        bita  #rsv_render_outofrange_mask
        bne   @bandko
        bita  #rsv_render_displaysprite_mask
        beq   @bandko
        lda   rsv_prev_render_flags_0,u
        ora   rsv_prev_render_flags_1,u
        bita  #rsv_prev_render_overlay_mask
        beq   @bandko
        lda   #$01
        sta   $9C0A
@bandko
        _gfxlock.loop
        lbra  mainLoop                     ; the loop body outgrew a short branch

; the object's run routine, reached through Obj_Index_Address with u on the
; OST. The bench sprite does not move, but DisplaySprite still has to run
; every frame : it registers the object in the priority structure of the
; buffer being drawn, and there is one structure per buffer.
ObjectRun
        jsr   AnimateSprite
        jsr   DisplaySprite
        rts

; the compressed sprite has no animation : its image never changes
ObjectRunBall
        jsr   DisplaySprite
        rts

userIRQ
        jsr   PalUpdateNow
        jsr   gfxlock.bufferSwap.check
        rts

        ; object indexes : emitted data, hence placed after the entry point
        INCLUDE "src/assets/game-modes/to8/main/obj_index.asm"

        INCLUDE "engine/InitGlobals.asm"
        INCLUDE "engine/irq/Irq.asm"
        INCLUDE "engine/palette/PalUpdateNow.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.asm"
        INCLUDE "engine/graphics/clear/ClearInterlacedDataMemory.asm"
        INCLUDE "engine/graphics/animation/AnimateSprite.asm"
        INCLUDE "engine/object-management/RunObjects.asm"
        ; The decompressor a zx0 image needs, before the sprite pack : the pack
        ; ends on 'ifndef' rts stubs for the extended encoders, so whichever of
        ; them a game actually uses has to be defined by then. A game with no
        ; compressed image leaves this line out and pays nothing.
        INCLUDE "engine/graphics/codec/zx0_mega.asm"
        INCLUDE "engine/graphics/sprite/sprite-background-erase-ext-pack.asm"

 ENDSECTION
