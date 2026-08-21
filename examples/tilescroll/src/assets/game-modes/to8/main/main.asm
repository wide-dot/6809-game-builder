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
;   +4 : $01 terrain : checkPosition hits the wall
;   +5 : $01 terrain : misses in the open, and everywhere when disabled
;   +6 : $01 terrain : the x scan reports the wall's left edge (80)
;*******************************************************************************

; the tile references live in the generated map tables, which declare their
; own externals — see the <tilemap> elements of the config

        ; the terrain unit follows the scroll through these
scroll_tile_pos          EXPORT
scroll_tile_pos_offset24 EXPORT

        ; and reads its resident state through these
terrainCollision.sensor.x   EXPORT
terrainCollision.sensor.y   EXPORT
terrainCollision.impact.x   EXPORT
terrainCollision.disabled   EXPORT
terrainCollision.bgFlag     EXPORT
terrainCollision.bgByteOff  EXPORT
terrainCollision.bgBitShift EXPORT
terrainCollision.bgColTmp   EXPORT

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.macro.asm"
        INCLUDE "engine/system/thomson/graphics/mode/gfxmode.macro.asm"
        INCLUDE "engine/objects/collision/terrainCollision.macro.asm"

        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/controller/joypad.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.macro.asm"


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
        lda   #map.RAM_OVER_CART+assets.gm.main.page
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

        ; L'ANIMATION DE DECOR. Le rectangle 2x2 en (4,2) de la carte cycle
        ; sur quatre images, huit trames video chacune, et repart en sens
        ; inverse au bout — un aller-retour continu rend une image sautee ou
        ; repetee visible a l'oeil.
        ;
        ; L'etat vit dans un OST : c'est le modele du moteur, une animation
        ; appartient a l'objet qui la pilote. Cet exemple n'a pas d'objets,
        ; d'ou le bloc bidon ci-dessous — `tilemap.animate` ne touche que les
        ; octets 12 a 14, seize suffisent donc, et le banc exerce quand meme
        ; le vrai chemin.
        ldu   #patch.ost
        clr   tanim.flags,u
        ldx   #patch
        lda   #patch.FRAMES
        ldb   #patch.HOLD
        jsr   tilemap.anim.arm

        ; terrain collision : point the resident wrappers at the mounted unit
        _terrainCollision.init objid.terrain

        ; --- the wall is at map column 3, tiles 24..26 of the row : solid
        ; pixels 80..82 whatever y. Everything below derives from that. ---

        ; a probe on the wall : column (80-8)/24 = 3, tile 0, mask $80
        ldd   #80
        std   terrainCollision.sensor.x
        ldd   #40
        std   terrainCollision.sensor.y
        clrb                               ; map 0
        jsr   terrainCollision.do
        tstb
        beq   @terr1ko
        lda   #$01
        sta   $9C04
@terr1ko

        ; a probe in the open, then the same wall probe with the terrain
        ; disabled : both must miss
        ldd   #40
        std   terrainCollision.sensor.x
        clrb
        jsr   terrainCollision.do
        tstb
        bne   @terr2ko
        inc   terrainCollision.disabled
        ldd   #80
        std   terrainCollision.sensor.x
        clrb
        jsr   terrainCollision.do
        tstb
        bne   @terr2ko
        clr   terrainCollision.disabled
        lda   #$01
        sta   $9C05
@terr2ko

        ; the rightward scan from the open : first solid tile's left edge is
        ; column 3, tile 0 -> 3*24 + 0*3 + 8 = 80
        ldd   #16
        std   terrainCollision.sensor.x
        clrb
        jsr   terrainCollision.xAxis.doRight
        ldd   terrainCollision.impact.x
        cmpd  #80
        bne   @terr3ko
        lda   #$01
        sta   $9C06
@terr3ko

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

        ; Le decor anime, hors du verrou comme Scroll : l'objet fait avancer
        ; SON horloge et empile une demande quand l'image change ; c'est
        ; tilemap.flush, plus bas, qui applique. Au bout de la sequence on
        ; repart dans l'autre sens.
        ldu   #patch.ost
        ldx   #patch
        lda   #patch.FRAMES
        ldb   #patch.HOLD
        jsr   tilemap.animate
        bne   >
        ldu   #patch.ost
        lda   tanim.flags,u
        eora  #tanim.BACKWARD
        sta   tanim.flags,u
        ldx   #patch
        lda   #patch.FRAMES
        ldb   #patch.HOLD
        jsr   tilemap.anim.arm
!
        ; Le drain : UNE fois par trame, il monte la page de la carte et
        ; applique tout ce qui s'est accumule. Le seul endroit qui pagine.
        jsr   tilemap.flush
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
; object index — where the terrain unit lives. Both values come from the
; attributed-place equates entries.asm publishes, so there is nothing here
; for the linker to resolve.
;*******************************************************************************
objid.terrain equ 1

Obj_Index_Page
        fcb   $00
        fcb   map.RAM_OVER_CART+assets.terrain.page

Obj_Index_Address
        fdb   $0000
        fdb   assets.terrain.address

;*******************************************************************************
; engine
;*******************************************************************************
        INCLUDE "engine/InitGlobals.asm"
        INCLUDE "engine/irq/Irq.asm"
        INCLUDE "engine/palette/PalUpdateNow.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.asm"
        INCLUDE "engine/graphics/clear/ClearInterlacedDataMemory.asm"
        INCLUDE "engine/graphics/tilemap/horizontal-scroll/scroll-map-buffered-even.asm"
        INCLUDE "engine/graphics/tilemap/patch/tilemap-patch.asm"
        INCLUDE "engine/objects/collision/terrainCollision.main.asm"

 ENDSECTION

; The map tables are generated by the <tilemap> elements of the config from
; src/assets/maps/map.bin, in their own map.static section : tile references
; are baked by the builder against the tiles' declared region, so they cost
; nothing at load time. The code above reaches map.even/map.odd across
; sections, which stays an ordinary intern relocation. Only the geometry
; comes from source :
patch       EXTERNAL
patch.ost   rmb 16                     ; l'OST bidon, cf. le commentaire ci-dessus

        INCLUDE "gen/assets/maps/patch.const.asm"

        INCLUDE "src/assets/maps/map.const.asm"

; a v2 module, which brings its own section
        INCLUDE "engine/system/to8/controller/joypad.asm"
