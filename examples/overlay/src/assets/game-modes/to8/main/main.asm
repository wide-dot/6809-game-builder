;*******************************************************************************
; Overlay sprites — bench
;
; Unit test of the overlay sprite pack (engine/graphics/sprite/overlay-mode) :
; DisplaySprite registers, BuildSprites draws, nothing saves or restores the
; background. The bench runs once, sequentially, interrupts masked : each test
; resets the priority structure, the two bench objects and the whole visible
; VRAM, then registers one or two sprites, calls BuildSprites and probes the
; result — the OST (a drawn sprite gets its hide flag set, a rejected one does
; not), the row extent of what was written, and a 16 bit checksum of both
; plane windows.
;
; The checksums are the differential handle : two builds of this example that
; differ only by the engine's BuildSprites must produce the same $9C00 block,
; checksums included. That is how an optimisation pass on the renderer is
; validated — byte for byte against the previous version, without a screen.
;
; Coverage : the whole single-sprite path. Both plane address paths (ram1 and
; ram2), the shifted variant, the missing-frame fallback, the four screen
; bound rejections, hidden objects, unregistration, back-to-front priority
; order, the priority 1 tail, playfield coordinates (accept, reject, and the
; borrow/wrap conversion with non zero camera offsets), the three mirror
; subsets, the xloop flag, and a negative screen line — an origin above the
; first line, its image under it — in playfield and screen coordinates and
; at line 0 one line up (t23..t25), the multisprite path (t26..t30), the
; priority lists DisplaySprite and DeleteObject keep (t31..t39), and the
; vertical wrap (BuildSprites.YWRAP, t40..t42 : the define on, its mask $FF,
; t01..t39 are the define off's).
;
; Results at $9C00, loader-ut convention :
;   +0 : $CA once the game mode runs, +1 : TESTS, +2 : $0D once completed
;   +3.. : $01 per passing test (t01..t42), then one word per test, the VRAM
;   checksum it recorded (0 if none) — docs/lang/en/benches.md
;*******************************************************************************

set_glyph  EXTERNAL
set_marker EXTERNAL
set_drop EXTERNAL
set_probe_12x12 EXTERNAL
set_probe_12x13 EXTERNAL
set_probe_12x14 EXTERNAL
set_probe_12x15 EXTERNAL
set_probe_13x12 EXTERNAL
set_probe_13x13 EXTERNAL
set_probe_13x14 EXTERNAL
set_probe_13x15 EXTERNAL
set_probe_14x12 EXTERNAL
set_probe_14x13 EXTERNAL
set_probe_14x14 EXTERNAL
set_probe_14x15 EXTERNAL
set_probe_15x12 EXTERNAL
set_probe_15x13 EXTERNAL
set_probe_15x14 EXTERNAL
set_probe_15x15 EXTERNAL

 SECTION code

        ; v1 engine dialect (1:1 imported files)
        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/thomson/graphics/mode/gfxmode.macro.asm"

        ; v2 kept features : loader/scenes, ram paging
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.macro.asm"

        ; object sizing and RAM placement, the game's to declare (equates only)
        INCLUDE "src/assets/game-modes/to8/main/ram_data.asm"

 opt c,ct

; results, one equate per test — the number is the test's rank
R.t01   equ res.base+0    ; glyph imageset : draw-only slots, sizes, mirrors
R.t02   equ res.base+1    ; marker imageset : single draw routine
R.t03   equ res.base+2    ; drawn, even x, ram1 address path
R.t04   equ res.base+3    ; row extent of t03
R.t05   equ res.base+4    ; drawn, ram2 address path, row extent
R.t06   equ res.base+5    ; drawn, odd x, shifted variant
R.t07   equ res.base+6    ; drawn, odd x, missing-frame fallback
R.t08   equ res.base+7    ; rejected, off screen left
R.t09   equ res.base+8    ; rejected, off screen right
R.t10   equ res.base+9    ; rejected, off screen top
R.t11   equ res.base+10   ; rejected, off screen bottom
R.t12   equ res.base+11   ; hidden object skipped
R.t13   equ res.base+12   ; unregistration, list surgery
R.t14   equ res.base+13   ; back-to-front priority order
R.t15   equ res.base+14   ; priority change 2->1 and the priority 1 tail
R.t16   equ res.base+15   ; playfield coordinates, accepted
R.t17   equ res.base+16   ; playfield coordinates, behind the camera
R.t18   equ res.base+17   ; playfield borrow path, camera offsets 48/28
R.t19   equ res.base+18   ; x mirror draws a different picture
R.t20   equ res.base+19   ; y mirror differs from plain and x mirror
R.t21   equ res.base+20   ; xy mirror differs from all three
R.t22   equ res.base+21   ; xloop skips the horizontal bounds
R.t23   equ res.base+22   ; negative screen line, playfield coordinates
R.t24   equ res.base+23   ; negative screen line, screen coordinates
R.t25   equ res.base+24   ; line 0, one line up : line -1
R.t26   equ res.base+25   ; multisprite : two children, the single path's picture
R.t27   equ res.base+26   ; multisprite : a child rejected by each bound
R.t28   equ res.base+27   ; multisprite : a child without an image skipped
R.t29   equ res.base+28   ; multisprite : negative screen line
R.t30   equ res.base+29   ; multisprite : line 0, one line up
R.t31   equ res.base+30   ; lists : three objects registered in order
R.t32   equ res.base+31   ; lists : the middle one moved to another priority
R.t33   equ res.base+32   ; lists : unregistered (priority 0), then registered again
R.t34   equ res.base+33   ; lists : the head deleted
R.t35   equ res.base+34   ; lists : the middle, then the tail deleted
R.t36   equ res.base+35   ; lists : an object never registered deleted
R.t37   equ res.base+36   ; lists : DisplaySprite clears the hide flag
R.t38   equ res.base+37   ; lists : DisplaySprite keeps every register
R.t39   equ res.base+38   ; lists : DisplaySprite without an image registers nothing
R.t40   equ res.base+39   ; wrap : a sprite past the playfield's top, the camera at its bottom
R.t41   equ res.base+40   ; wrap : a sprite past its bottom, the camera at its top
R.t42   equ res.base+41   ; wrap off ($FF) : t40's sprite rejected

; checksum slots, same rank ; the plain mirror reference uses a spare slot
S.t03   equ res.sums+2*2
S.t05   equ res.sums+2*4
S.t06   equ res.sums+2*5
S.t07   equ res.sums+2*6
S.t08   equ res.sums+2*7
S.t09   equ res.sums+2*8
S.t10   equ res.sums+2*9
S.t11   equ res.sums+2*10
S.t12   equ res.sums+2*11
S.t13   equ res.sums+2*12
S.t14   equ res.sums+2*13
S.t15   equ res.sums+2*14
S.t16   equ res.sums+2*15
S.t17   equ res.sums+2*16
S.t18   equ res.sums+2*17
S.t19   equ res.sums+2*18
S.t20   equ res.sums+2*19
S.t21   equ res.sums+2*20
S.t22   equ res.sums+2*21
S.t23   equ res.sums+2*22
S.t24   equ res.sums+2*23
S.t25   equ res.sums+2*24
S.t26   equ res.sums+2*25
S.t27   equ res.sums+2*26
S.t28   equ res.sums+2*27
S.t29   equ res.sums+2*28
S.t30   equ res.sums+2*29
S.t40   equ res.sums+2*39
S.t41   equ res.sums+2*40
S.t42   equ res.sums+2*41
S.plain equ res.sums+2*TESTS   ; unmirrored glyph at the mirror tests' position
S.ref26 equ res.sums+2*TESTS+2 ; t26's two glyphs drawn by the single path

; a multisprite object's children : x, y, imageset (sub2_x_pos onward)
CHILD   equ obj1+sub2_x_pos

        ; the scene loads this file at the game mode region address and jumps
        ; to its first byte : main has to be the first thing emitted, so every
        ; table lives after the code

main
        jsr   InitGlobals          ; clears the dp page : camera at 0/0, the
                                   ; overlay convention (no DrawSprites, so
                                   ; the ifdef offsets stay untouched)
        orcc  #$50                 ; the bench is single threaded : no IRQ,
                                   ; no gfxlock, one buffer, full determinism

        ; 160x200 in 16 colours, so the drawn bytes mean what the encoders
        ; meant. Every probe reads the plane windows directly : no palette
        ; and no display page are set, what the monitor shows is noise.
        _gfxmode.setBM16
        _ram.data.set #2           ; screen buffer 0 at the data window

        lda   #$CA                 ; the game mode is running
        sta   res.magic
        lda   #TESTS
        sta   res.count

        ; capture the y1 offsets of both imagesets : the row extent probes
        ; derive their expected first line from the real index, so the bench
        ; survives an art change without editing a constant
        _ram.cart.set #assets.sprites.page
        ldx   #set_glyph
        lda   ,x                   ; unmirrored sub set offset
        leay  a,x
        ldb   image_subset_y1_offset,y
        sex
        std   bench.gly_y1off
        ldx   #set_marker
        lda   ,x
        leay  a,x
        ldb   image_subset_y1_offset,y
        sex
        std   bench.mrk_y1off
        ldx   #set_drop
        lda   ,x
        leay  a,x
        ldb   image_subset_y1_offset,y
        sex
        std   bench.drp_y1off

; ---------------------------------------------------------------------------
; t01 — glyph imageset : draw-only encoders leave the B slots empty, both
; shifts exist, the three mirror subsets exist, sizes read back
; ---------------------------------------------------------------------------
t01
        ldx   #set_glyph
        ldd   image_x_size,x       ; sizes are the bounding box minus one
        cmpa  #11
        lbne  t02
        cmpb  #23
        lbne  t02
        lda   1,x                  ; x mirror subset offset
        lbeq  t02
        lda   2,x                  ; y mirror subset offset
        lbeq  t02
        lda   3,x                  ; xy mirror subset offset
        lbeq  t02
        lda   ,x                   ; unmirrored subset : B0, D0, B1, D1
        leay  a,x
        lda   ,y                   ; B0 — no background erase routine exists
        lbne  t02
        lda   1,y                  ; D0
        lbeq  t02
        lda   3,y                  ; D1, the shifted draw
        lbeq  t02
        lda   #1
        sta   R.t01

; ---------------------------------------------------------------------------
; t02 — marker imageset : one draw routine, shift 0 only
; ---------------------------------------------------------------------------
t02
        ldx   #set_marker
        ldd   image_x_size,x
        cmpa  #3
        lbne  t03
        cmpb  #3
        lbne  t03
        lda   ,x
        leay  a,x
        lda   ,y                   ; B0 absent
        lbne  t03
        lda   1,y                  ; D0 present
        lbeq  t03
        lda   3,y                  ; D1 absent : the fallback test relies on it
        lbne  t03
        lda   #1
        sta   R.t02

; ---------------------------------------------------------------------------
; t03/t04 — glyph at (100,100) : even x, bit1 of x0 clear, the ram1 address
; path. Drawn (hide set), checksum recorded, then the row extent
; ---------------------------------------------------------------------------
t03
        jsr   bench.reset
        ldd   #100*256+100
        jsr   bench.glyph1
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t05                  ; not drawn : t03 and t04 both fail
        jsr   bench.vramsum
        std   S.t03
        lbeq  t05
        lda   #1
        sta   R.t03
        ; the box occupies exactly lines F..F+23, nothing outside
        ldd   #100-28
        addd  bench.gly_y1off
        tfr   b,a
        ldb   #24
        jsr   bench.rowextent
        tsta
        lbne  t05
        lda   #1
        sta   R.t04

; ---------------------------------------------------------------------------
; t05 — glyph at (102,100) : bit1 of x0 set, the ram2 address path
; ---------------------------------------------------------------------------
t05
        jsr   bench.reset
        ldd   #102*256+100
        jsr   bench.glyph1
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t06
        jsr   bench.vramsum
        std   S.t05
        lbeq  t06
        ldd   #100-28
        addd  bench.gly_y1off
        tfr   b,a
        ldb   #24
        jsr   bench.rowextent
        tsta
        lbne  t06
        lda   #1
        sta   R.t05

; ---------------------------------------------------------------------------
; t06 — glyph at (101,100) : odd position, the pack picks a shifted variant
; ---------------------------------------------------------------------------
t06
        jsr   bench.reset
        ldd   #101*256+100
        jsr   bench.glyph1
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t07
        jsr   bench.vramsum
        std   S.t06
        lbeq  t07
        lda   #1
        sta   R.t06

; ---------------------------------------------------------------------------
; t07 — marker at (101,100) : odd position but no shifted routine exists, the
; @nodefinedframe fallback picks the shift 0 one and adjusts the parity
; ---------------------------------------------------------------------------
t07
        jsr   bench.reset
        ldu   #obj1
        ldd   #101*256+100
        std   xy_pixel,u
        lda   #2
        sta   id,u
        ldx   #set_marker
        stx   image_set,u
        lda   #2
        sta   priority,u
        jsr   DisplaySprite
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t08
        jsr   bench.vramsum
        std   S.t07
        lbeq  t08
        ldd   #100-28
        addd  bench.mrk_y1off
        tfr   b,a
        ldb   #4
        jsr   bench.rowextent
        tsta
        lbne  t08
        lda   #1
        sta   R.t07

; ---------------------------------------------------------------------------
; t08..t11 — the four screen bound rejections : not drawn, VRAM untouched
; ---------------------------------------------------------------------------
t08
        jsr   bench.reset
        ldd   #49*256+100          ; x1 lands left of the screen frame
        jsr   bench.glyph1
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbmi  t09
        jsr   bench.vramsum
        std   S.t08
        lbne  t09
        lda   #1
        sta   R.t08
t09
        jsr   bench.reset
        ldd   #205*256+100         ; x2 lands right of the screen frame
        jsr   bench.glyph1
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbmi  t10
        jsr   bench.vramsum
        std   S.t09
        lbne  t10
        lda   #1
        sta   R.t09
t10
        jsr   bench.reset
        ldd   #100*256+30          ; y1 lands above the screen frame
        jsr   bench.glyph1
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbmi  t11
        jsr   bench.vramsum
        std   S.t10
        lbne  t11
        lda   #1
        sta   R.t10
t11
        jsr   bench.reset
        ldd   #100*256+226         ; y2 lands below the screen frame
        jsr   bench.glyph1
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbmi  t12
        jsr   bench.vramsum
        std   S.t11
        lbne  t12
        lda   #1
        sta   R.t11

; ---------------------------------------------------------------------------
; t12 — a hidden object is skipped before anything else is looked at
; ---------------------------------------------------------------------------
t12
        jsr   bench.reset
        ldd   #100*256+100
        jsr   bench.glyph1
        ldu   #obj1
        lda   render_flags,u
        ora   #render_hide_mask
        sta   render_flags,u
        jsr   BuildSprites
        jsr   bench.vramsum
        std   S.t12
        lbne  t13
        lda   #1
        sta   R.t12

; ---------------------------------------------------------------------------
; t13 — two objects at the same priority, the second unregistered through
; DisplaySprite_priority 0 : list surgery, then only the first is drawn
; ---------------------------------------------------------------------------
t13
        jsr   bench.reset
        ldd   #100*256+60
        jsr   bench.glyph1
        ldu   #obj2
        ldd   #100*256+140
        std   xy_pixel,u
        lda   #1
        sta   id,u
        ldx   #set_glyph
        stx   image_set,u
        lda   #2
        sta   priority,u
        jsr   DisplaySprite
        ldu   #obj2
        lda   #0
        jsr   DisplaySprite_priority
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t14
        ldu   #obj2
        lda   render_flags,u
        lbmi  t14                  ; the unregistered object must not be drawn
        ldb   #112                 ; a line obj2's box would have covered
        jsr   bench.rowdirty
        tsta
        lbne  t14
        jsr   bench.vramsum
        std   S.t13
        lbeq  t14
        lda   #1
        sta   R.t13

; ---------------------------------------------------------------------------
; t14 — priority order : the marker at priority 8 (back) fully covered by the
; glyph at priority 2 (front), same position as t03. Back is drawn first, so
; the final picture — and its checksum — is the glyph alone
; ---------------------------------------------------------------------------
t14
        jsr   bench.reset
        ldu   #obj2
        ldd   #100*256+100
        std   xy_pixel,u
        lda   #2
        sta   id,u
        ldx   #set_marker
        stx   image_set,u
        lda   #8
        sta   priority,u
        jsr   DisplaySprite
        ldd   #100*256+100
        jsr   bench.glyph1
        jsr   BuildSprites
        ldu   #obj2
        lda   render_flags,u
        lbpl  t15                  ; the marker must have been drawn, then covered
        jsr   bench.vramsum
        std   S.t14
        cmpd  S.t03
        lbne  t15
        lda   #1
        sta   R.t14

; ---------------------------------------------------------------------------
; t15 — priority change 2 -> 1 through DisplaySprite_priority, then the
; priority 1 entry, the jmp tail of BuildSprites' walk
; ---------------------------------------------------------------------------
t15
        jsr   bench.reset
        ldd   #100*256+100
        jsr   bench.glyph1
        ldu   #obj1
        lda   #1
        jsr   DisplaySprite_priority
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t16
        jsr   bench.vramsum
        std   S.t15
        lbeq  t16
        lda   #1
        sta   R.t15

; ---------------------------------------------------------------------------
; t16 — playfield coordinates : camera at 500, sprite at 560, accepted and
; drawn at x0 = 60 ; the expected first line is y_pos + y1off (camera y = 0)
; ---------------------------------------------------------------------------
t16
        jsr   bench.reset
        ldd   #500
        std   glb_camera_x_pos
        ldd   #0
        std   glb_camera_y_pos
        ldu   #obj1
        lda   #1
        sta   id,u
        ldx   #set_glyph
        stx   image_set,u
        lda   #2
        sta   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldd   #560
        std   x_pos,u
        ldd   #100
        std   y_pos,u
        jsr   DisplaySprite
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t17
        jsr   bench.vramsum
        std   S.t16
        lbeq  t17
        ldd   #100
        addd  bench.gly_y1off
        tfr   b,a
        ldb   #24
        jsr   bench.rowextent
        tsta
        lbne  t17
        lda   #1
        sta   R.t16

; ---------------------------------------------------------------------------
; t17 — playfield coordinates, sprite behind the camera : rejected
; ---------------------------------------------------------------------------
t17
        jsr   bench.reset          ; the camera stays at 500
        ldu   #obj1
        lda   #1
        sta   id,u
        ldx   #set_glyph
        stx   image_set,u
        lda   #2
        sta   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldd   #460
        std   x_pos,u
        ldd   #100
        std   y_pos,u
        jsr   DisplaySprite
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbmi  t18
        jsr   bench.vramsum
        std   S.t17
        lbne  t18
        lda   #1
        sta   R.t17

; ---------------------------------------------------------------------------
; t18 — playfield conversion with camera offsets 48/28 (the v1 screen frame
; convention) : x_pos 440 against camera 500 accepts through the doubled
; offset margin, and the screen conversion takes the borrow path (subb #$60,
; one line up) — the wrap the offsets exist to allow
; ---------------------------------------------------------------------------
t18
        jsr   bench.reset
        ldd   #48
        std   glb_camera_x_offset
        ldd   #28
        std   glb_camera_y_offset
        ldu   #obj1
        lda   #1
        sta   id,u
        ldx   #set_glyph
        stx   image_set,u
        lda   #2
        sta   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldd   #440
        std   x_pos,u
        ldd   #100
        std   y_pos,u
        jsr   DisplaySprite
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t18end
        jsr   bench.vramsum
        std   S.t18
        lbeq  t18end
        lda   #1
        sta   R.t18
t18end
        ; restore the overlay convention before the remaining tests
        ldd   #0
        std   glb_camera_x_offset
        std   glb_camera_y_offset
        std   glb_camera_x_pos

; ---------------------------------------------------------------------------
; t19..t21 — the three mirror subsets each draw, and each draws a different
; picture : the glyph is asymmetric on both axes on purpose. The unmirrored
; reference is redrawn at the same position first
; ---------------------------------------------------------------------------
t19
        jsr   bench.reset
        ldd   #100*256+60
        jsr   bench.glyph1
        jsr   BuildSprites
        jsr   bench.vramsum
        std   S.plain
        ; x mirror
        jsr   bench.reset
        ldd   #100*256+60
        jsr   bench.glyph1
        ldu   #obj1
        lda   render_flags,u
        ora   #render_xmirror_mask
        sta   render_flags,u
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t20
        jsr   bench.vramsum
        std   S.t19
        lbeq  t20
        cmpd  S.plain
        lbeq  t20                  ; same picture as unmirrored : fail
        lda   #1
        sta   R.t19
t20
        jsr   bench.reset
        ldd   #100*256+60
        jsr   bench.glyph1
        ldu   #obj1
        lda   render_flags,u
        ora   #render_ymirror_mask
        sta   render_flags,u
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t21
        jsr   bench.vramsum
        std   S.t20
        lbeq  t21
        cmpd  S.plain
        lbeq  t21
        cmpd  S.t19
        lbeq  t21
        lda   #1
        sta   R.t20
t21
        jsr   bench.reset
        ldd   #100*256+60
        jsr   bench.glyph1
        ldu   #obj1
        lda   render_flags,u
        ora   #render_xmirror_mask|render_ymirror_mask
        sta   render_flags,u
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t22
        jsr   bench.vramsum
        std   S.t21
        lbeq  t22
        cmpd  S.plain
        lbeq  t22
        cmpd  S.t19
        lbeq  t22
        cmpd  S.t20
        lbeq  t22
        lda   #1
        sta   R.t21

; ---------------------------------------------------------------------------
; t22 — xloop : x = 40 is off screen left, the flag skips the horizontal
; bounds and the position conversion wraps to the right edge, one line up
; ---------------------------------------------------------------------------
t22
        jsr   bench.reset
        ldd   #40*256+100
        jsr   bench.glyph1
        ldu   #obj1
        lda   render_flags,u
        ora   #render_xloop_mask
        sta   render_flags,u
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t23
        jsr   bench.vramsum
        std   S.t22
        lbeq  t23
        lda   #1
        sta   R.t22

; ---------------------------------------------------------------------------
; t23 — a negative screen line, playfield coordinates : the drop at y -4,
; its image y1off lines under its origin, drawn on its own rows
; ---------------------------------------------------------------------------
t23
        jsr   bench.reset
        ldd   #0
        std   glb_camera_x_pos
        std   glb_camera_y_pos
        ldu   #obj1
        lda   #1
        sta   id,u
        ldx   #set_drop
        stx   image_set,u
        lda   #2
        sta   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldd   #100
        std   x_pos,u
        ldd   #-4
        std   y_pos,u
        jsr   DisplaySprite
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t24
        jsr   bench.vramsum
        std   S.t23
        lbeq  t24
        ldd   #-4
        addd  bench.drp_y1off
        tfr   b,a
        ldb   #12
        jsr   bench.rowextent
        tsta
        lbne  t24
        lda   #1
        sta   R.t23

; ---------------------------------------------------------------------------
; t24 — the same in screen coordinates : y_pixel 24, line -4
; ---------------------------------------------------------------------------
t24
        jsr   bench.reset
        ldu   #obj1
        lda   #1
        sta   id,u
        ldx   #set_drop
        stx   image_set,u
        lda   #2
        sta   priority,u
        ldd   #148*256+24
        std   xy_pixel,u
        jsr   DisplaySprite
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t25
        jsr   bench.vramsum
        std   S.t24
        lbeq  t25
        ldd   #24-28
        addd  bench.drp_y1off
        tfr   b,a
        ldb   #12
        jsr   bench.rowextent
        tsta
        lbne  t25
        lda   #1
        sta   R.t24

; ---------------------------------------------------------------------------
; t25 — t18's borrow with the origin on line 0 (y -28) : line -1, each row
; drawn one line up
; ---------------------------------------------------------------------------
t25
        jsr   bench.reset
        ldd   #48
        std   glb_camera_x_offset
        ldd   #28
        std   glb_camera_y_offset
        ldd   #500
        std   glb_camera_x_pos
        ldd   #0
        std   glb_camera_y_pos
        ldu   #obj1
        lda   #1
        sta   id,u
        ldx   #set_drop
        stx   image_set,u
        lda   #2
        sta   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldd   #440
        std   x_pos,u
        ldd   #-28
        std   y_pos,u
        jsr   DisplaySprite
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t25end
        jsr   bench.vramsum
        std   S.t25
        lbeq  t25end
        ldd   bench.drp_y1off
        decb
        tfr   b,a
        ldb   #12
        jsr   bench.rowextent
        tsta
        lbne  t25end
        lda   #1
        sta   R.t25
t25end
        ldd   #0
        std   glb_camera_x_offset
        std   glb_camera_y_offset
        std   glb_camera_x_pos

; ---------------------------------------------------------------------------
; t26 — multisprite : two glyph children at (60,100) and (100,100), camera at
; 0/0 ; both drawn, and the picture is the one two single playfield sprites
; draw at the same places
; ---------------------------------------------------------------------------
t26
        jsr   bench.reset
        ldd   #0
        std   glb_camera_y_pos
        ldx   #set_glyph
        ldd   #60
        std   CHILD
        ldd   #100
        std   CHILD+2
        stx   CHILD+4
        std   CHILD+6
        std   CHILD+8
        stx   CHILD+10
        ldb   #2
        jsr   bench.multi
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t27
        jsr   bench.vramsum
        std   S.t26
        lbeq  t27
        ldd   #100
        addd  bench.gly_y1off
        tfr   b,a
        ldb   #24
        jsr   bench.rowextent
        tsta
        lbne  t27
        jsr   bench.reset
        ldd   #100
        std   bench.ty
        ldy   #set_glyph
        ldx   #obj1
        ldd   #60
        jsr   bench.single
        ldy   #set_glyph           ; DisplaySprite does not keep Y
        ldx   #obj2
        ldd   #100
        jsr   bench.single
        jsr   BuildSprites
        jsr   bench.vramsum
        std   S.ref26
        cmpd  S.t26
        lbne  t27
        lda   #1
        sta   R.t26

; ---------------------------------------------------------------------------
; t27 — multisprite : four children, each out by one bound (left, right, top,
; bottom) : the object is walked (hide set), nothing is drawn
; ---------------------------------------------------------------------------
t27
        jsr   bench.reset
        ldx   #set_glyph
        ldd   #0
        std   CHILD
        ldd   #100
        std   CHILD+2
        stx   CHILD+4
        ldd   #156
        std   CHILD+6
        ldd   #100
        std   CHILD+8
        stx   CHILD+10
        ldd   #60
        std   CHILD+12
        ldd   #4
        std   CHILD+14
        stx   CHILD+16
        ldd   #60
        std   CHILD+18
        ldd   #196
        std   CHILD+20
        stx   CHILD+22
        ldb   #4
        jsr   bench.multi
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t28
        jsr   bench.vramsum
        std   S.t27
        lbne  t28
        lda   #1
        sta   R.t27

; ---------------------------------------------------------------------------
; t28 — multisprite : a child without an image between two glyphs : skipped,
; the two others drawn, t26's picture
; ---------------------------------------------------------------------------
t28
        jsr   bench.reset
        ldx   #set_glyph
        ldd   #60
        std   CHILD
        ldd   #100
        std   CHILD+2
        stx   CHILD+4
        ldd   #80
        std   CHILD+6
        ldd   #100
        std   CHILD+8
        ldd   #0
        std   CHILD+10
        ldd   #100
        std   CHILD+12
        std   CHILD+14
        stx   CHILD+16
        ldb   #3
        jsr   bench.multi
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t29
        jsr   bench.vramsum
        std   S.t28
        lbeq  t29
        cmpd  S.ref26
        lbne  t29
        lda   #1
        sta   R.t28

; ---------------------------------------------------------------------------
; t29 — multisprite, a negative screen line : t23's drop as a child
; ---------------------------------------------------------------------------
t29
        jsr   bench.reset
        ldd   #100
        std   CHILD
        ldd   #-4
        std   CHILD+2
        ldx   #set_drop
        stx   CHILD+4
        ldb   #1
        jsr   bench.multi
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t30
        jsr   bench.vramsum
        std   S.t29
        lbeq  t30
        ldd   #-4
        addd  bench.drp_y1off
        tfr   b,a
        ldb   #12
        jsr   bench.rowextent
        tsta
        lbne  t30
        lda   #1
        sta   R.t29

; ---------------------------------------------------------------------------
; t30 — multisprite, line 0 one line up : t25's drop as a child
; ---------------------------------------------------------------------------
t30
        jsr   bench.reset
        ldd   #48
        std   glb_camera_x_offset
        ldd   #28
        std   glb_camera_y_offset
        ldd   #500
        std   glb_camera_x_pos
        ldd   #440
        std   CHILD
        ldd   #-28
        std   CHILD+2
        ldx   #set_drop
        stx   CHILD+4
        ldb   #1
        jsr   bench.multi
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t30end
        jsr   bench.vramsum
        std   S.t30
        lbeq  t30end
        ldd   bench.drp_y1off
        decb
        tfr   b,a
        ldb   #12
        jsr   bench.rowextent
        tsta
        lbne  t30end
        lda   #1
        sta   R.t30
t30end
        ldd   #0
        std   glb_camera_x_offset
        std   glb_camera_y_offset
        std   glb_camera_x_pos

; ---------------------------------------------------------------------------
; t31..t39 — the priority lists : a doubly linked list per priority, its
; first and last objects in Tbl_Priority_First_Entry / Last_Entry. The
; objects come from the dynamic pool (DeleteObject gives them back to it).
; ---------------------------------------------------------------------------
t31
        jsr   bench.reset
        jsr   bench.pool
        tsta
        lbne  t32
        ldu   #O1
        jsr   bench.prio3
        ldu   #O2
        jsr   bench.prio3
        ldu   #O3
        jsr   bench.prio3
        ldb   #3
        ldx   #L.t31
        jsr   bench.list
        tsta
        lbne  t32
        lda   #1
        sta   R.t31
t32
        ldu   #O2                  ; t31's lists : O2 from 3 to 5
        lda   #5
        jsr   DisplaySprite_priority
        ldb   #3
        ldx   #L.t32a
        jsr   bench.list
        tsta
        lbne  t33
        ldb   #5
        ldx   #L.t32b
        jsr   bench.list
        tsta
        lbne  t33
        lda   #1
        sta   R.t32
t33
        ldu   #O1                  ; out of list 3, then in again : last
        clra
        jsr   DisplaySprite_priority
        ldb   #3
        ldx   #L.t33a
        jsr   bench.list
        tsta
        lbne  t34
        ldu   #O1
        jsr   bench.prio3
        ldb   #3
        ldx   #L.t33b
        jsr   bench.list
        tsta
        lbne  t34
        lda   #1
        sta   R.t33
t34
        ldu   #O3                  ; list 3 is O3, O1 : the head goes
        jsr   DeleteObject
        ldb   #3
        ldx   #L.t34
        jsr   bench.list
        tsta
        lbne  t35
        lda   O3+id                ; cleared
        lbne  t35
        lda   #1
        sta   R.t34
t35
        jsr   bench.reset
        jsr   bench.pool
        tsta
        lbne  t36
        ldu   #O1
        jsr   bench.prio3
        ldu   #O2
        jsr   bench.prio3
        ldu   #O3
        jsr   bench.prio3
        ldu   #O2                  ; the middle
        jsr   DeleteObject
        ldb   #3
        ldx   #L.t35a
        jsr   bench.list
        tsta
        lbne  t36
        ldu   #O3                  ; the tail
        jsr   DeleteObject
        ldb   #3
        ldx   #L.t34
        jsr   bench.list
        tsta
        lbne  t36
        lda   #1
        sta   R.t35
t36
        jsr   bench.reset
        jsr   bench.pool
        tsta
        lbne  t37
        ldu   #O1
        jsr   bench.prio3
        ldu   #O2                  ; loaded, never displayed
        jsr   DeleteObject
        ldb   #3
        ldx   #L.t34
        jsr   bench.list
        tsta
        lbne  t37
        ldd   Tbl_Priority_First_Entry  ; the unused entry 0 untouched
        lbne  t37
        ldd   Tbl_Priority_Last_Entry
        lbne  t37
        lda   O2+id
        lbne  t37
        lda   #1
        sta   R.t36
t37
        jsr   bench.reset
        jsr   bench.pool
        tsta
        lbne  t38
        lda   #render_hide_mask
        sta   O1+render_flags
        ldu   #O1
        jsr   bench.prio3
        lda   O1+render_flags
        lbmi  t38
        lda   #1
        sta   R.t37
t38
        jsr   bench.reset
        jsr   bench.pool
        tsta
        lbne  t39
        ldu   #O1
        lda   #3
        sta   priority,u
        ldd   #$5AA5
        ldx   #$1234
        ldy   #$4321
        jsr   DisplaySprite
        cmpd  #$5AA5
        lbne  t39
        cmpx  #$1234
        lbne  t39
        cmpy  #$4321
        lbne  t39
        cmpu  #O1
        lbne  t39
        lda   #1
        sta   R.t38
t39
        jsr   bench.reset
        jsr   bench.pool
        tsta
        lbne  benchdone
        ldd   #0
        std   O1+image_set
        ldu   #O1
        lda   #3
        sta   priority,u
        jsr   DisplaySprite
        ldb   #3
        ldx   #L.empty
        jsr   bench.list
        tsta
        lbne  benchdone
        lda   #1
        sta   R.t39

; ---------------------------------------------------------------------------
; t40 — the vertical wrap (mask $07) : camera at 500/2040, the sprite at
; 560/92 (2040+100-2048) is 100 lines below the camera round the 2048 :
; t16's picture
; ---------------------------------------------------------------------------
t40
        jsr   bench.reset
        lda   #$07
        sta   BuildSprites.yWrapMask
        ldd   #500
        std   glb_camera_x_pos
        ldd   #2040
        std   glb_camera_y_pos
        ldd   #92
        jsr   bench.glyph560
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t41
        jsr   bench.vramsum
        std   S.t40
        cmpd  S.t16
        lbne  t41
        lda   #1
        sta   R.t40

; ---------------------------------------------------------------------------
; t41 — the other way : camera at 500/1990, the sprite at 560/42 is
; 100 lines below it round the 2048 : t16's picture
; ---------------------------------------------------------------------------
t41
        jsr   bench.reset
        ldd   #1990
        std   glb_camera_y_pos
        ldd   #42
        jsr   bench.glyph560
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbpl  t42
        jsr   bench.vramsum
        std   S.t41
        cmpd  S.t16
        lbne  t42
        lda   #1
        sta   R.t41

; ---------------------------------------------------------------------------
; t42 — the wrap off (mask $FF, the default) : t40's sprite is 1948 lines
; above the camera, rejected
; ---------------------------------------------------------------------------
t42
        jsr   bench.reset
        lda   #$FF
        sta   BuildSprites.yWrapMask
        ldd   #2040
        std   glb_camera_y_pos
        ldd   #92
        jsr   bench.glyph560
        jsr   BuildSprites
        ldu   #obj1
        lda   render_flags,u
        lbmi  benchdone
        jsr   bench.vramsum
        std   S.t42
        lbne  benchdone
        lda   #1
        sta   R.t42
        bra   benchdone

; obj1, the glyph at x 560, y D, playfield coordinates, registered
bench.glyph560
        ldu   #obj1
        std   y_pos,u
        lda   #1
        sta   id,u
        ldx   #set_glyph
        stx   image_set,u
        lda   #2
        sta   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldd   #560
        std   x_pos,u
        jmp   DisplaySprite

benchdone
        lda   #$0D
        sta   res.done
        jsr   bench.sweep
        bra   *

; ---------------------------------------------------------------------------
; Le balayage d'ancrage : les 16 sondes opaques (largeur ET hauteur 12..15,
; un pas de 1 px — toutes les classes mod 4), chacune dessinee par sa routine
; bdraw PUIS par sa routine draw, appelees DIRECTEMENT a la meme adresse
; ecran fixe (aucun runtime entre les deux). La bbox VRAM mesuree au pixel
; pres dit ou chaque encodeur ANCRE son image : le diff des deux colonnes,
; par (l,h), est la loi de centrage. Motif : le PUSH FIRE du title (64 px de
; large, draw) atterrit 2 px a gauche de la ligne tapee que sa version v1
; (bdraw) recouvrait exactement.
; ---------------------------------------------------------------------------
PROBE.LOC2 equ $C000+100*40+20     ; ligne 100, colonne 20 — loin des bords

bench.sweep
        ldy   #probe.sets
        ldx   #res.sweep
        stx   bench.outp
        ldx   #res.sweep.hdr
        stx   bench.hdrp
        lda   #16
        sta   bench.count
@probe
        ldx   ,y++
        pshs  y
        ; l'en-tete de l'imageset : parite du centre, x1, y1
        _ram.cart.set #assets.sprites.page
        lda   image_center_offset,x
        ldy   bench.hdrp
        sta   ,y+
        pshs  x
        lda   ,x                       ; offset du sous-ensemble non miroir
        leax  a,x
        lda   image_subset_x1_offset,x
        sta   ,y+
        lda   image_subset_y1_offset,x
        sta   ,y+
        sty   bench.hdrp
        puls  x
        ; le sous-ensemble, puis les deux variantes : B0 (0) et D0 (1)
        lda   ,x
        leax  a,x                      ; X = sous-ensemble
        ldb   #0
        jsr   probe.one
        ldb   #1
        jsr   probe.one
        puls  y
        dec   bench.count
        bne   @probe
        lda   #$CB
        sta   res.sweep.done
        rts

; une variante d'une sonde : VRAM au noir, appel direct de la routine
; generee a l'adresse fixe, bbox mesuree et rangee (4 octets).
; in : X = sous-ensemble, B = variante (0 = bdraw, 1 = draw)
probe.one
        pshs  b,x
        jsr   bench.reset
        _ram.cart.set #assets.sprites.page
        ldx   1,s                      ; le sous-ensemble
        ldb   ,s                       ; la variante
        lda   b,x
        lbeq  @absent
        leax  a,x                      ; X = la structure de variante
        lda   page_draw_routine,x
        _SetCartPageA
        ldx   draw_routine,x
        ; l'adresse ecran fixe, posee comme BuildSprites l'aurait fait (ram1)
        ldd   #PROBE.LOC2
        std   glb_screen_location_2
        subd  #$2000
        std   glb_screen_location_1
        ldu   glb_screen_location_2
        ldy   #bench.bgcell.top        ; bdraw y sauve le fond (S descend de la)
        jsr   ,x
        jsr   bench.bbox
        ldx   bench.outp
        lda   bench.bb
        sta   ,x+
        lda   bench.bb+1
        sta   ,x+
        lda   bench.bb+2
        sta   ,x+
        lda   bench.bb+3
        sta   ,x+
        stx   bench.outp
        puls  b,x
        rts
@absent
        ldx   bench.outp               ; variante manquante : marqueur, la
        lda   #$EE                     ; table reste alignee
        sta   ,x+
        sta   ,x+
        sta   ,x+
        sta   ,x+
        stx   bench.outp
        puls  b,x
        rts

; la bbox de toute la VRAM visible : bench.bb = [premier px, dernier px,
; premiere ligne, derniere ligne] — $FF/$FF/0/0 si vide. Pixel exact par
; nibble ; plan $C000 = pixels 4i/4i+1, plan $A000 = 4i+2/4i+3.
bench.bbox
        lda   #$FF
        sta   bench.bb
        sta   bench.bb+2
        clr   bench.bb+1
        clr   bench.bb+3
        clr   bench.hit
        ldb   #0
@l      jsr   bench.bbline
        incb
        cmpb  #200
        blo   @l
        rts

bench.bbline                           ; B = ligne ; met a jour bench.bb
        pshs  b
        lda   #40
        mul
        addd  #$C000
        tfr   d,x
        ldb   #0
@lc     lda   ,x+
        beq   @nc
        pshs  b,x
        aslb
        aslb                           ; px de base du nibble haut : 4i
        jsr   bench.bbpx
        puls  b,x
@nc     incb
        cmpb  #40
        blo   @lc
        ldb   ,s
        lda   #40
        mul
        addd  #$A000
        tfr   d,x
        ldb   #0
@la     lda   ,x+
        beq   @na
        pshs  b,x
        aslb
        aslb
        addb  #2                       ; 4i+2
        jsr   bench.bbpx
        puls  b,x
@na     incb
        cmpb  #40
        blo   @la
        puls  b
        lda   bench.hit                ; la ligne portait un pixel :
        beq   @rts                     ; etendre les bornes de lignes
        clr   bench.hit
        cmpb  bench.bb+2
        bhs   >
        stb   bench.bb+2
!       cmpb  bench.bb+3
        bls   @rts
        stb   bench.bb+3
@rts    rts

bench.bbpx                             ; A = octet non nul, B = px du nibble haut
        inc   bench.hit
        pshs  b
        bita  #$F0
        bne   >
        incb                           ; nibble haut vide : le min est le bas
!       cmpb  bench.bb
        bhs   >
        stb   bench.bb
!       puls  b
        bita  #$0F
        beq   >
        incb                           ; nibble bas occupe : le max est le bas
!       cmpb  bench.bb+1
        bls   >
        stb   bench.bb+1
!       rts

probe.sets
        fdb   set_probe_12x12,set_probe_12x13,set_probe_12x14,set_probe_12x15
        fdb   set_probe_13x12,set_probe_13x13,set_probe_13x14,set_probe_13x15
        fdb   set_probe_14x12,set_probe_14x13,set_probe_14x14,set_probe_14x15
        fdb   set_probe_15x12,set_probe_15x13,set_probe_15x14,set_probe_15x15

; ---------------------------------------------------------------------------
; helpers
; ---------------------------------------------------------------------------

; register the glyph in obj1 at screen position D (A = x, B = y), priority 2
bench.glyph1
        ldu   #obj1
        std   xy_pixel,u
        lda   #1
        sta   id,u
        ldx   #set_glyph
        stx   image_set,u
        lda   #2
        sta   priority,u
        jmp   DisplaySprite

; object U registered at priority 3
bench.prio3
        lda   #3
        jmp   DisplaySprite_priority

; the dynamic pool emptied and its four objects loaded (id 1, the glyph), O1
; to O4 in that order ; out : A = 0 when LoadObject_u gave them so
bench.pool
        ldd   #0
        ldx   #Dynamic_Object_RAM
!       std   ,x++
        cmpx  #Dynamic_Object_RAM_End
        blo   <
        std   object_list_first
        std   object_list_last
        jsr   InitStack
        ldy   #bench.pool.order
@load   jsr   LoadObject_u
        beq   @fail
        cmpu  ,y++
        bne   @fail
        lda   #1
        sta   id,u
        ldx   #set_glyph
        stx   image_set,u
        cmpy  #bench.pool.order+8
        blo   @load
        clra
        rts
@fail   lda   #1
        rts
bench.pool.order fdb O1,O2,O3,O4

; is the list of priority B exactly the objects at X (words, 0 ended), first
; to last, linked both ways, its last entry the last of them ? out : A = 0
bench.list
        pshs  b,x,y,u
        aslb
        ldy   #Tbl_Priority_First_Entry
        ldu   b,y
        ldy   #0                   ; the previous one
@loop   ldd   ,x++
        beq   @end
        pshs  d
        cmpu  ,s++
        bne   @fail
        cmpy  rsv_priority_prev_obj,u
        bne   @fail
        tfr   u,y
        ldu   rsv_priority_next_obj,u
        bra   @loop
@end    cmpu  #0
        bne   @fail
        ldb   ,s
        aslb
        ldx   #Tbl_Priority_Last_Entry
        cmpy  b,x
        bne   @fail
        clra
        puls  b,x,y,u,pc
@fail   lda   #1
        puls  b,x,y,u,pc

L.t31   fdb   O1,O2,O3,0
L.t32a  fdb   O1,O3,0
L.t32b  fdb   O2,0
L.t33a  fdb   O3,0
L.t33b  fdb   O3,O1,0
L.t34   fdb   O1,0
L.t35a  fdb   O1,O3,0
L.empty fdb   0

; obj1 as a multisprite object of B children (filled at CHILD), priority 2
bench.multi
        ldu   #obj1
        stb   mainspr_childsprites,u
        lda   #1
        sta   id,u
        lda   #render_subobjects_mask|render_playfieldcoord_mask
        sta   render_flags,u
        lda   #2
        jmp   DisplaySprite_priority

; object X as a single playfield sprite of imageset Y at (D, bench.ty),
; priority 2
bench.single
        std   x_pos,x
        ldd   bench.ty
        std   y_pos,x
        sty   image_set,x
        lda   #1
        sta   id,x
        lda   #2
        sta   priority,x
        lda   #render_playfieldcoord_mask
        sta   render_flags,x
        tfr   x,u
        jmp   DisplaySprite

; reset between tests : both bench objects, the priority structure, and the
; whole visible VRAM of both planes (200 lines of 40 bytes each)
bench.reset
        ldd   #0
        ldx   #obj1
!       std   ,x++
        cmpx  #obj1+2*object_size
        blo   <
        ldx   #Tbl_Priority_First_Entry
!       std   ,x++
        cmpx  #Tbl_Priority_First_Entry+2+(nb_priority_levels*2)
        blo   <
        ldx   #Tbl_Priority_Last_Entry
!       std   ,x++
        cmpx  #Tbl_Priority_Last_Entry+2+(nb_priority_levels*2)
        blo   <
        ldx   #$A000
!       std   ,x++
        cmpx  #$A000+200*40
        blo   <
        ldx   #$C000
!       std   ,x++
        cmpx  #$C000+200*40
        blo   <
        rts

; 16 bit rotate-and-add checksum of both plane windows ; out : D (callers
; re-test through std). Rotating before each add makes the sum position
; dependent : a plain additive sum is invariant under pixel permutations,
; and a mirrored sprite really is one — the first run of the bench proved
; it by hashing the x mirror and the plain glyph to the same value.
bench.vramsum
        ldd   #0
        std   bench.tmp
        ldx   #$A000
!       ldd   bench.tmp
        aslb                       ; 16 bit rotate left...
        rola
        adcb  #0                   ; ...the carry comes back as bit 0
        addb  ,x+
        adca  #0
        std   bench.tmp
        cmpx  #$A000+200*40
        blo   <
        ldx   #$C000
!       ldd   bench.tmp
        aslb
        rola
        adcb  #0
        addb  ,x+
        adca  #0
        std   bench.tmp
        cmpx  #$C000+200*40
        blo   <
        ldd   bench.tmp
        rts

; is screen line B (0-199) empty on both planes ? out : A = 0 if empty ;
; B, X, Y preserved
bench.rowdirty
        pshs  b,x,y
        lda   #40
        mul
        addd  #$A000
        tfr   d,x
        leay  $2000,x
        ldb   #40
@loop   lda   ,x+
        bne   @dirty
        lda   ,y+
        bne   @dirty
        decb
        bne   @loop
        clra
@dirty  puls  b,x,y,pc

; the drawn box occupies exactly lines A..A+B-1 : line A-1 empty, every line
; of the box dirty, line A+B empty. out : A = 0 pass
bench.rowextent
        pshs  d                    ; 0,s = first line ; 1,s = count
        ldb   ,s
        decb
        jsr   bench.rowdirty
        tsta
        bne   @fail
        ldb   ,s
@mid    jsr   bench.rowdirty
        tsta
        beq   @fail
        incb
        dec   1,s
        bne   @mid
        jsr   bench.rowdirty
        tsta
        bne   @fail
        clra
        leas  2,s
        rts
@fail   lda   #1
        leas  2,s
        rts

        ; object indexes : emitted data, hence placed after the entry point
        INCLUDE "src/assets/game-modes/to8/main/obj_index.asm"

        INCLUDE "engine/InitGlobals.asm"
        ; RunObjects is here for UnloadObject only : the overlay pack's
        ; DeleteObject calls it, and a pack member must assemble whole
        INCLUDE "engine/object-management/RunObjects.asm"
BuildSprites.YWRAP equ 1               ; t40..t42 (its mask $FF : t01..t39 unchanged)
        INCLUDE "engine/graphics/sprite/sprite-overlay-pack.asm"

 ENDSECTION
