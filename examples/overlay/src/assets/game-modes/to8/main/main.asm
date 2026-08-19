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
; subsets and the xloop flag. The multisprite path is out of scope : R-Type
; does not use it and it is kept strictly 1:1 with v1.
;
; Results at $9C00, loader-ut convention :
;   +$00 : $CA once the game mode runs
;   +$01..+$16 : $01 per passing test (t01..t22)
;   +$1F : $0D once the sequence completed
;   +$20.. : one word per test, the VRAM checksum it recorded (0 if none)
;*******************************************************************************

set_glyph  EXTERNAL
set_marker EXTERNAL

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
S.plain equ res.sums+2*22 ; unmirrored glyph at the mirror tests' position

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
        lbpl  benchdone
        jsr   bench.vramsum
        std   S.t22
        lbeq  benchdone
        lda   #1
        sta   R.t22

benchdone
        lda   #$0D
        sta   res.done
        bra   *

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
        INCLUDE "engine/graphics/sprite/sprite-overlay-pack.asm"

 ENDSECTION
