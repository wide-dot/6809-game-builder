;*******************************************************************************
; Object manager — bench
;
; Exercises the v1 object manager imported 1:1 : the slot pool, the run list
; and its edge cases, per-object page mounting, and the two helpers R-Type
; stage 1 uses alongside them (ObjectMoveSync, RunPgSubRoutine, ObjectDp).
;
; It draws nothing. Every check writes to a fixed table, which is what makes
; the edge cases assertable at all — an object deleting itself mid-walk, or
; spawning a child mid-walk, leaves nothing on screen to look at.
;
; Witnesses at $9C00, the bench convention (docs/lang/en/benches.md) :
; $CA, TESTS, $0D once done, a byte per test ($01 pass), a word per test.
;   T1  InitStack hands out a slot, the list heads follow it
;   T2  the pool is finite : the fifth request on four slots is refused
;   T3  RunObjects walks the list in order
;   T4  an object deletes itself mid-walk and the walk carries on
;   T5  an object spawns a child mid-walk and the child runs the same pass
;   T6  UnloadObject_x unlinks from the middle of the list
;   T7  a freed slot comes back on the next load
;   T8  unloading clears the object's data
;   T9  an object living in its own page is mounted and run
;   T10 ObjectMoveSync applies velocity once per elapsed frame
;   T11 ObjectDp_Clear wipes the user direct page and stops where it must
;   T12 RunPgSubRoutine runs in another page and restores the caller's
;       (word : the parameter the callee echoed back)
;   T13 AnimateSpriteSync spends elapsed frames, not calls
;   T14 moveByScript walks a script and applies its steps
;   T15 and it too spends elapsed frames, not calls
;   T16 AABB collision : the potential matrix, and the list surgery
;   T17 ObjectWave spawns on the game clock, with frame drop carried
;   T18 AutoScroll moves the camera in 8.8, stops at its limit
;   T19 AnimateSpriteSync is AnimateSprite once per elapsed frame
;   T20 ObjectMoveAndFallSync is k frames of a move then a fall
;   T21 ManagedObjects_ClearAll clears the pool and frees the slots in use
;   T22 InitStack empties the run list
;   T23 LoadObject_x / UnloadObject_x : the object in X, U kept
;   T24 UnloadObject_u at both ends of the list, every register kept
;   T25 ObjectMove : a borrow and a carry across the pixel
;   T26 ObjectMoveSync : negative velocities across the pixel
;   T27 AnimateSprite : $FE n goes back, $FF restarts
;   T28 AnimateSprite : $FD, $FC, $FB, $FA
;   T29 AnimateSprite : the object's flips, the other render flags kept
;   T30 AnimateSpriteSync : a command after the image runs at once, and the
;       look-ahead past $FF / $FE reads the image shown, not the script's end
;   T31 MarkObjGone, MarkObjGone2, MarkObjGone3 : kept in the window, deleted
;       past it with the respawn entry freed
;*******************************************************************************

; the paged unit's entry points : resolved at load time, so the game mode
; never spells out where that page ended up
obj.paged.run   EXTERNAL
obj.paged.sub   EXTERNAL
wave.data       EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"

        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.macro.asm"

        INCLUDE "src/common/result.const.asm"
        INCLUDE "src/assets/game-modes/to8/main/ram_data.asm"

 opt c,ct

R.t01 equ res.base+0
R.t02 equ res.base+1
R.t03 equ res.base+2
R.t04 equ res.base+3
R.t05 equ res.base+4
R.t06 equ res.base+5
R.t07 equ res.base+6
R.t08 equ res.base+7
R.t09 equ res.base+8
R.t10 equ res.base+9
R.t11 equ res.base+10
R.t12 equ res.base+11
R.t13 equ res.base+12
R.t14 equ res.base+13
R.t15 equ res.base+14
R.t16 equ res.base+15
R.t17 equ res.base+16
R.t18 equ res.base+17
R.t19 equ res.base+18
R.t20 equ res.base+19
R.t21 equ res.base+20
R.t22 equ res.base+21
R.t23 equ res.base+22
R.t24 equ res.base+23
R.t25 equ res.base+24
R.t26 equ res.base+25
R.t27 equ res.base+26
R.t28 equ res.base+27
R.t29 equ res.base+28
R.t30 equ res.base+29
R.t31 equ res.base+30
W.t12 equ res.sums+2*11

respawn_index equ ext_variables+6         ; the game's field, MarkObjGone reads it

        ; the scene loads this file at its attributed place and jumps
        ; to its first byte, so main has to be the first thing emitted

main
        ldx   #result
        ldb   #3+3*TESTS
!       clr   ,x+
        decb
        bne   <
        lda   #result.MAGIC
        sta   res.magic
        lda   #TESTS
        sta   res.count

; ---------------------------------------------------------------------------
; T1 : InitStack hands out a slot, and the list heads follow it
; ---------------------------------------------------------------------------
        jsr   ManagedObjects_ClearAll
        jsr   InitStack
        jsr   LoadObject_u
        beq   t1ko                         ; z=1 : no slot was free
        cmpu  #Dynamic_Object_RAM
        bne   t1ko                         ; InitStack pushes the slots from the
                                           ; top down, so the bottom one is on
                                           ; top of the free stack and goes first
        cmpu  object_list_first
        bne   t1ko
        cmpu  object_list_last
        bne   t1ko
        lda   #$01
        sta   R.t01
t1ko

; ---------------------------------------------------------------------------
; T2 : the pool is finite. Three more loads fit, the fifth must be refused —
; and refused by saying so, not by handing out memory that is not there.
; ---------------------------------------------------------------------------
        jsr   LoadObject_u
        beq   t2ko
        jsr   LoadObject_u
        beq   t2ko
        jsr   LoadObject_u
        beq   t2ko
        jsr   LoadObject_u
        bne   t2ko                         ; z=0 would mean a fifth slot appeared
        lda   #$01
        sta   R.t02
t2ko

; ---------------------------------------------------------------------------
; T3 : RunObjects walks the list in the order objects were linked. Three
; tracers, each carrying its own tag in its extension area.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        lda   #objid.tracer
        ldb   #$11
        jsr   bench.newObject
        lda   #objid.tracer
        ldb   #$22
        jsr   bench.newObject
        lda   #objid.tracer
        ldb   #$33
        jsr   bench.newObject
        jsr   RunObjects
        ldx   #t3want
        ldb   #3
        jsr   bench.traceIs
        tsta
        bne   t3ko
        lda   #$01
        sta   R.t03
t3ko

; ---------------------------------------------------------------------------
; T4 : an object deletes itself while RunObjects is walking the list. The
; walk has to carry on to the object behind it — RunObjects saves the next
; pointer before each call precisely because the slot holding it is about to
; be cleared.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        lda   #objid.tracer
        ldb   #$11
        jsr   bench.newObject
        lda   #objid.suicide
        ldb   #$22
        jsr   bench.newObject
        lda   #objid.tracer
        ldb   #$33
        jsr   bench.newObject
        jsr   RunObjects
        ldx   #t4want
        ldb   #3
        jsr   bench.traceIs
        tsta
        bne   t4ko
        jsr   bench.traceReset
        jsr   RunObjects                   ; the list is one shorter now
        ldx   #t4again
        ldb   #2
        jsr   bench.traceIs
        tsta
        bne   t4ko
        lda   #$01
        sta   R.t04
t4ko

; ---------------------------------------------------------------------------
; T5 : an object spawns a child while the walk is in progress. The child is
; linked at the end of the list, so it must run in this same pass.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        lda   #objid.parent
        ldb   #$11
        jsr   bench.newObject
        jsr   RunObjects
        ldx   #t5want
        ldb   #2
        jsr   bench.traceIs
        tsta
        bne   t5ko
        lda   #$01
        sta   R.t05
t5ko

; ---------------------------------------------------------------------------
; T6 : UnloadObject_x takes an object out of the middle of the list, and the
; two around it stay linked to each other.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        lda   #objid.tracer
        ldb   #$11
        jsr   bench.newObject
        lda   #objid.tracer
        ldb   #$22
        jsr   bench.newObject
        stu   t6mid
        lda   #objid.tracer
        ldb   #$33
        jsr   bench.newObject
        ldx   t6mid
        jsr   UnloadObject_x
        jsr   RunObjects
        ldx   #t6want
        ldb   #2
        jsr   bench.traceIs
        tsta
        bne   t6ko
        lda   #$01
        sta   R.t06
t6ko

; ---------------------------------------------------------------------------
; T7 : the freed slot comes back. The free list is a stack, so the address
; just released is the next one handed out.
; ---------------------------------------------------------------------------
        jsr   LoadObject_u
        beq   t7ko
        cmpu  t6mid
        bne   t7ko
        lda   #$01
        sta   R.t07
t7ko

; ---------------------------------------------------------------------------
; T8 : unloading clears the object's data. A recycled slot must not carry the
; previous occupant's id, flags or position into its next life.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        lda   #objid.tracer
        ldb   #$44
        jsr   bench.newObject
        stu   t8slot
        ldx   #object_size                 ; dirty every byte of the structure
        ldb   #$FF
!       stb   ,u+
        leax  -1,x
        bne   <
        ldu   t8slot
        jsr   UnloadObject_u
        ldu   t8slot
        ldx   #object_size
!       ldb   ,u+
        bne   t8ko
        leax  -1,x
        bne   <
        lda   #$01
        sta   R.t08
t8ko

; ---------------------------------------------------------------------------
; T9 : an object whose code lives in another page. RunObjects reads its page
; from Obj_Index_Page, mounts it over the cartridge window, and only then
; calls it.
;
; The window is deliberately left pointing at another page first : without the
; mount there is no object code at that address at all, so this test cannot
; pass by accident. The object reports a byte that exists only in its own
; unit, which also rules out a stale mount left by something else.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        _ram.cart.set #$05                 ; some other page
        jsr   bench.newPaged
        jsr   RunObjects
        lda   result.paged
        cmpa  #$5A                         ; the paged unit's magic
        bne   t9ko
        ldu   t9slot
        lda   ext_variables,u              ; and it ran exactly once
        cmpa  #$01
        bne   t9ko
        lda   #$01
        sta   R.t09
t9ko

; ---------------------------------------------------------------------------
; T10 : ObjectMoveSync applies the velocity once per elapsed frame, so a
; dropped frame is compensated rather than lost. All of R-Type's timing rests
; on that, so the bench checks the multiplication and not just the addition —
; and checks the subpixel, since velocity is s8.8.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        lda   #objid.tracer
        ldb   #$11
        jsr   bench.newObject
        ldd   #$0100
        std   x_pos,u
        clr   x_sub,u
        ldd   #$0200
        std   y_pos,u
        clr   y_sub,u
        ldd   #$0180                       ; +1.5 pixel per frame
        std   x_vel,u
        ldd   #$FF00                       ; -1.0 pixel per frame
        std   y_vel,u
        lda   #3
        sta   gfxlock.frameDrop.count
        jsr   ObjectMoveSync
        clr   gfxlock.frameDrop.count
        ldd   x_pos,u
        cmpd  #$0104                       ; $0100.00 + 3 * $01.80 = $0104.80
        bne   t10ko
        lda   x_sub,u
        cmpa  #$80
        bne   t10ko
        ldd   y_pos,u
        cmpd  #$01FD                       ; $0200 - 3 * $01
        bne   t10ko
        lda   #$01
        sta   R.t10
t10ko

; ---------------------------------------------------------------------------
; T11 : ObjectDp_Clear wipes the user direct page and stops at dp_extreg,
; which it shares with the engine.
; ---------------------------------------------------------------------------
        ldx   #dp
        lda   #$FF
!       sta   ,x+
        cmpx  #dp_extreg
        bne   <
        sta   ,x                           ; the first byte past the range
        jsr   ObjectDp_Clear
        ldx   #dp
!       lda   ,x+
        bne   t11ko
        cmpx  #dp_extreg
        bne   <
        lda   ,x                           ; must have been left alone
        cmpa  #$FF
        bne   t11ko
        clr   ,x
        lda   #$01
        sta   R.t11
t11ko

; ---------------------------------------------------------------------------
; T12 : RunPgSubRoutine calls into another page and puts back the page the
; caller was using. That restore is what lets a mounted object call another
; one without pulling its own code out from under itself.
; ---------------------------------------------------------------------------
        _ram.cart.set #$05                 ; the caller's page
        lda   #map.RAM_OVER_CART+assets.objects.page
        sta   PSR_Page
        ldd   #obj.paged.sub
        std   PSR_Address
        ldb   #$3C                         ; a parameter to echo back
        jsr   RunPgSubRoutine
        _GetCartPageA
        cmpa  #map.RAM_OVER_CART+$05       ; the caller's page is back
        bne   t12ko
        lda   result.pgsub
        cmpa  #$5A                         ; the callee ran, from its own page
        bne   t12ko
        lda   result.pgsub+1
        cmpa  #$3C                         ; and got its parameter
        bne   t12ko
        lda   #$01
        sta   R.t12
        ldd   #$003C
        std   W.t12
t12ko

; ---------------------------------------------------------------------------
; T13 : AnimateSpriteSync spends its budget in elapsed frames, not in calls.
; Eight calls reporting one dropped frame each must land on the same displayed
; frame as four calls reporting two — that is the point of the variant, and it
; is what keeps r-type's waves and boss in step with the arcade timings they
; were measured against.
;
; Both are primed with a load first : the call that loads an animation counts
; one frame, the current one, whatever the drop (the frames before it belong
; to the previous animation), so the regimes are compared past it.
;
; The animation table is a fake : AnimateSprite stores a frame's value into
; image_set,u and never dereferences it, so recognisable numbers say more here
; than real imageset addresses would.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        lda   #objid.tracer
        ldb   #$11
        jsr   bench.newObject
        stu   t13a
        jsr   bench.animReset
        clr   gfxlock.frameDrop.count
        ldb   #1
        jsr   bench.animSteps              ; prime : load the animation, consume nothing
        lda   #1
        sta   gfxlock.frameDrop.count
        ldb   #8
        jsr   bench.animSteps              ; 8 calls x 1 frame = 8 frames

        lda   #objid.tracer
        ldb   #$22
        jsr   bench.newObject
        stu   t13b
        jsr   bench.animReset
        clr   gfxlock.frameDrop.count
        ldb   #1
        jsr   bench.animSteps              ; same priming
        lda   #2
        sta   gfxlock.frameDrop.count
        ldb   #4
        jsr   bench.animSteps              ; 4 calls x 2 frames = 8 frames
        clr   gfxlock.frameDrop.count

        ldu   t13a
        ldx   t13b
        lda   anim_frame,u
        cmpa  anim_frame,x
        bne   t13ko
        ldd   image_set,u
        cmpd  image_set,x
        bne   t13ko
        cmpd  #$1111                       ; and it did leave the first frame
        beq   t13ko
        lda   #$01
        sta   R.t13
t13ko

; ---------------------------------------------------------------------------
; T14 : moveByScript reads a script and turns it into movement. Each byte of a
; segment is a bitfield — bit 5 moves on x, bit 6 makes it negative, bit 3 and
; bit 4 do the same on y, bit 2 ends the segment — and anim_frame_duration is
; how many of those bytes are consumed per frame.
;
; The steps land in x_vel/y_vel, are applied to the position at the end of the
; frame, and are then cleared : it is an accumulator, not a velocity. So the
; position tells the whole story and the bench reads it there.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        lda   #objid.tracer
        ldb   #$11
        jsr   bench.newObject
        stu   t13a
        jsr   bench.scriptReset
        ldb   #1
        jsr   moveByScript.runByB          ; one elapsed frame : one step
        ldu   t13a
        ldd   x_pos,u
        cmpd  #$0101                       ; $0100 + one POSXSTEP
        bne   t14ko
        lda   x_sub,u
        bne   t14ko
        ldb   #1
        jsr   moveByScript.runByB
        ldb   #1
        jsr   moveByScript.runByB
        ldu   t13a
        ldd   x_pos,u
        cmpd  #$0103                       ; three steps in
        bne   t14ko
        lda   #$01
        sta   R.t14
t14ko

; ---------------------------------------------------------------------------
; T15 : and it spends elapsed frames rather than calls, like everything else
; whose timing r-type calibrated against the arcade. One call reporting three
; dropped frames has to move exactly as far as three calls reporting one.
;
; A fourth frame then reads the end of segment byte, which sends the reader to
; the next word of the script — the zero that ends it. moveByScript.anim.end is
; how a script tells its caller it is over, and it costs its own frame : the
; three move commands do not include it.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        lda   #objid.tracer
        ldb   #$22
        jsr   bench.newObject
        stu   t13b
        jsr   bench.scriptReset
        lda   #3
        sta   gfxlock.frameDrop.count
        jsr   moveByScript.runByFrameDrop  ; one call, three elapsed frames
        clr   gfxlock.frameDrop.count
        ldu   t13b
        ldd   x_pos,u
        cmpd  #$0103                       ; same place as T14 reached in three
        bne   t15ko
        lda   x_sub,u
        bne   t15ko
        ldb   #1                           ; the fourth frame reads the end marker
        jsr   moveByScript.runByB
        lda   moveByScript.anim.end        ; the script announced its end
        cmpa  #$01
        bne   t15ko
        ldu   t13b
        ldd   x_pos,u
        cmpd  #$0103                       ; and that frame moved nothing
        bne   t15ko
        lda   #$01
        sta   R.t15
t15ko

; ---------------------------------------------------------------------------
; T16 : AABB collision. Two lists, boxes added by the object macros, one
; detection pass, and the potential matrix does the arithmetic : a hit
; subtracts the smaller potential from the larger, an invincible box (<0)
; never changes, a weak box (127) dies on contact without harming.
;
; The boxes are bare memory here — no objects behind them — because the pass
; only reads the AABB structs and the lists.
; ---------------------------------------------------------------------------
        ; two overlapping boxes, 10 vs 4 : the strong one wins with 6 left
        ldu   #box1
        jsr   bench.aabbReset
        lda   #10
        sta   AABB.p,u
        ldu   #box2
        jsr   bench.aabbReset
        lda   #4
        sta   AABB.p,u
        ldu   #box1
        _Collision_AddAABB 0,AABB_list_a
        ldu   #box2
        _Collision_AddAABB 0,AABB_list_b
        _Collision_Do AABB_list_a,AABB_list_b
        lda   box1+AABB.p
        cmpa  #6
        lbne  t16ko
        lda   box2+AABB.p
        lbne  t16ko

        ; an invincible box (-1) clears the other and keeps its own value
        ldu   #box1
        jsr   bench.aabbReset
        lda   #-1
        sta   AABB.p,u
        ldu   #box2
        jsr   bench.aabbReset
        lda   #50
        sta   AABB.p,u
        _Collision_Do AABB_list_a,AABB_list_b
        lda   box1+AABB.p
        cmpa  #-1
        lbne  t16ko
        lda   box2+AABB.p
        lbne  t16ko

        ; a weak box (127) dies on contact and does no harm
        ldu   #box1
        jsr   bench.aabbReset
        lda   #20
        sta   AABB.p,u
        ldu   #box2
        jsr   bench.aabbReset
        lda   #127
        sta   AABB.p,u
        _Collision_Do AABB_list_a,AABB_list_b
        lda   box1+AABB.p
        cmpa  #20
        lbne  t16ko
        lda   box2+AABB.p
        lbne  t16ko

        ; boxes apart : nothing moves. cx is the centre, rx the half width —
        ; centres 60 apart with half widths 5+5 cannot touch
        ldu   #box1
        jsr   bench.aabbReset
        lda   #10
        sta   AABB.p,u
        ldu   #box2
        jsr   bench.aabbReset
        lda   #10
        sta   AABB.p,u
        lda   #100
        sta   AABB.cx,u
        _Collision_Do AABB_list_a,AABB_list_b
        lda   box1+AABB.p
        cmpa  #10
        lbne  t16ko
        lda   box2+AABB.p
        cmpa  #10
        lbne  t16ko

        ; list surgery : three boxes in list a, remove the middle one, the
        ; pass must still see the two others (they collide with box2)
        ldu   #box1
        jsr   bench.aabbReset
        lda   #1
        sta   AABB.p,u
        ldu   #box3
        jsr   bench.aabbReset
        lda   #1
        sta   AABB.p,u
        ldu   #box4
        jsr   bench.aabbReset
        lda   #1
        sta   AABB.p,u
        ldu   #box3
        _Collision_AddAABB 0,AABB_list_a
        ldu   #box4
        _Collision_AddAABB 0,AABB_list_a
        ldu   #box3
        _Collision_RemoveAABB 0,AABB_list_a
        ldu   #box2
        jsr   bench.aabbReset
        lda   #100
        sta   AABB.p,u
        _Collision_Do AABB_list_a,AABB_list_b
        lda   box2+AABB.p
        cmpa  #98                          ; two hits of 1, not three
        lbne  t16ko
        lda   box3+AABB.p
        cmpa  #1                           ; the removed box was not touched
        lbne  t16ko
        lda   #$01
        sta   R.t16
t16ko

; ---------------------------------------------------------------------------
; T17 : ObjectWave reads its wave from a mounted page and spawns on the game
; clock. Entries are [timestamp][id][subtype], end marker $FFFF. A spawn late
; by n frames carries n in wave_frame_drop, which is how a wave stays in step
; with the arcade timeline across dropped frames.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        lda   #map.RAM_OVER_CART+assets.objects.page
        sta   object_wave_data_page
        ldd   #wave.data
        std   object_wave_data_start
        ldd   #0
        std   gfxlock.frame.gameCount
        jsr   ObjectWave_Init

        ; clock at 4 : the t=5 entry must not fire yet
        ldd   #4
        std   gfxlock.frame.gameCount
        jsr   ObjectWave
        ldd   object_list_first
        lbne  t17ko

        ; clock at 5 : one spawn, on time (drop 0)
        ldd   #5
        std   gfxlock.frame.gameCount
        jsr   ObjectWave
        ldu   object_list_first
        lbeq  t17ko
        lda   id,u
        cmpa  #objid.tracer
        lbne  t17ko
        ldd   subtype_w,u
        cmpd  #$1234
        lbne  t17ko
        lda   wave_frame_drop,u
        lbne  t17ko

        ; clock jumps to 12 : the t=10 entry fires 2 frames late
        ldd   #12
        std   gfxlock.frame.gameCount
        jsr   ObjectWave
        ldu   object_list_first
        ldu   run_object_next,u
        lbeq  t17ko
        ldd   subtype_w,u
        cmpd  #$5678
        lbne  t17ko
        lda   wave_frame_drop,u
        cmpa  #2
        lbne  t17ko

        ; and the end marker holds : a later clock spawns nothing more
        ldd   #$4000
        std   gfxlock.frame.gameCount
        jsr   ObjectWave
        ldu   object_list_first
        ldu   run_object_next,u
        ldu   run_object_next,u
        lbne  t17ko
        lda   #$01
        sta   R.t17
t17ko
        ldd   #0
        std   gfxlock.frame.gameCount

; ---------------------------------------------------------------------------
; T18 : AutoScroll moves the camera by an 8.8 step with a carried remainder,
; and stops itself at the declared limit. CheckCameraMove turns the move into
; the tiles-need-redrawing flag, once per buffer.
; ---------------------------------------------------------------------------
        ldd   #$0100
        std   glb_camera_x_pos
        ldd   #$0000
        std   glb_camera_x_min
        ldd   #$0110
        std   glb_camera_x_max
        lda   #scroll_state_right
        sta   glb_auto_scroll_state
        ldd   #100
        std   glb_auto_scroll_frames
        ldd   #$0180                       ; 1.5 pixel per frame
        std   glb_auto_scroll_step
        jsr   AutoScroll                   ; +1 (remainder .5)
        jsr   AutoScroll                   ; +2 (remainder 0)
        ldd   glb_camera_x_pos
        cmpd  #$0103
        lbne  t18ko
        ; sixteen more frames would pass the max : it must stop there
!       jsr   AutoScroll
        lda   glb_auto_scroll_state
        bne   <
        ldd   glb_camera_x_pos
        cmpd  #$0110                       ; capped run leaves the camera at max
        bhi   t18ko
        ; the camera moved : CheckCameraMove must raise the redraw flag once
        clr   gfxlock.backBuffer.id
        jsr   CheckCameraMove
        lda   glb_camera_move
        cmpa  #1
        lbne  t18ko
        jsr   CheckCameraMove              ; same camera, same buffer : quiet
        lda   glb_camera_move
        lbne  t18ko
        lda   #$01
        sta   R.t18
t18ko

; ---------------------------------------------------------------------------
; T19 : AnimateSpriteSync is AnimateSprite once per elapsed frame. At one frame
; per call the two are the same routine ; at two frames per call the overshoot
; is carried, each image lasting the script's D+1 frames, as on the Mega
; Drive. Ten frames of the fake animation (D = 4, an image every five frames) :
; AnimateSprite ten calls, AnimateSpriteSync ten calls of one frame and five
; calls of two, each after a call of its own that loads the animation.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        lda   #objid.tracer
        ldb   #$11
        jsr   bench.newObject
        stu   t19a
        jsr   bench.animReset
        ldb   #1
        jsr   bench.animStepsPlain         ; load
        ldb   #10
        jsr   bench.animStepsPlain         ; ten frames

        lda   #objid.tracer
        ldb   #$22
        jsr   bench.newObject
        stu   t19b
        jsr   bench.animReset
        lda   #1
        sta   gfxlock.frameDrop.count
        ldb   #1
        jsr   bench.animSteps              ; load
        ldb   #10
        jsr   bench.animSteps              ; ten calls x 1 frame

        lda   #objid.tracer
        ldb   #$33
        jsr   bench.newObject
        stu   t19c
        jsr   bench.animReset
        lda   #2
        sta   gfxlock.frameDrop.count
        ldb   #1
        jsr   bench.animSteps              ; load : the drop before it is not its own
        ldb   #5
        jsr   bench.animSteps              ; five calls x 2 frames
        clr   gfxlock.frameDrop.count

        ldu   t19a
        ldd   image_set,u
        cmpd  #$3333                       ; ten frames past the load : the third image
        lbne  t19ko
        lda   anim_frame_duration,u
        cmpa  #4                           ; just loaded, its D+1 frames ahead
        lbne  t19ko
        ldx   t19b
        jsr   t19same
        lbne  t19ko
        ldx   t19c
        jsr   t19same
        lbne  t19ko
        lda   #$01
        sta   R.t19
t19ko

; ---------------------------------------------------------------------------
; T20 : ObjectMoveAndFallSync over k elapsed frames is k frames of Sonic 2's
; ObjectMoveAndFall : the position takes the velocity, then the velocity the
; acceleration. Per case, k frames in one call against k calls of one frame,
; to the subpixel, then against the values worked out by hand : a fall
; (g = $38, k = 3), a negative acceleration (g = -$18), and seven frames.
; ObjectMoveSync then the acceleration added k times would miss g*k(k-1)/2.
; ---------------------------------------------------------------------------
        ldx   #t20case1
        jsr   t20run
        lbne  t20ko
        ldx   #t20case2
        jsr   t20run
        lbne  t20ko
        ldx   #t20case3
        jsr   t20run
        lbne  t20ko
        lda   #$01
        sta   R.t20
t20ko

; ---------------------------------------------------------------------------
; T21 : ManagedObjects_ClearAll clears the pool and frees the slots in use.
; The pool full and dirty, one ClearAll alone : every byte zero, the list
; empty, and four slots to hand out again, not five.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        jsr   bench.fill
        lbeq  t21ko
        ldx   #Dynamic_Object_RAM
        lda   #$FF
!       sta   ,x+
        cmpx  #Dynamic_Object_RAM_End
        bne   <
        jsr   ManagedObjects_ClearAll
        ldx   #Dynamic_Object_RAM
!       lda   ,x+
        lbne  t21ko
        cmpx  #Dynamic_Object_RAM_End
        bne   <
        ldd   object_list_first
        lbne  t21ko
        ldd   object_list_last
        lbne  t21ko
        jsr   bench.fill
        lbeq  t21ko                        ; a slot was lost
        jsr   LoadObject_u
        lbne  t21ko
        lda   #$01
        sta   R.t21
t21ko

; ---------------------------------------------------------------------------
; T22 : InitStack empties the run list along with the free stack.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        jsr   bench.fill
        jsr   InitStack
        ldd   object_list_first
        lbne  t22ko
        ldd   object_list_last
        lbne  t22ko
        jsr   LoadObject_u
        lbeq  t22ko
        cmpu  #Dynamic_Object_RAM
        lbne  t22ko
        jsr   ManagedObjects_ClearAll      ; the slots T22 left dirty
        lda   #$01
        sta   R.t22
t22ko

; ---------------------------------------------------------------------------
; T23 : the X variants. LoadObject_x hands the slot out in X and keeps U, a
; full pool says so with U kept ; UnloadObject_x keeps X and U, and the slot
; it freed is the next one out.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        ldu   #$1234
        jsr   LoadObject_x
        lbeq  t23ko
        cmpx  #Dynamic_Object_RAM
        lbne  t23ko
        cmpu  #$1234
        lbne  t23ko
        stx   t23x
        jsr   LoadObject_x
        jsr   LoadObject_x
        jsr   LoadObject_x
        lbeq  t23ko
        jsr   LoadObject_x
        lbne  t23ko                        ; the fifth refused
        cmpu  #$1234
        lbne  t23ko
        ldx   t23x
        jsr   UnloadObject_x
        cmpx  t23x
        lbne  t23ko
        cmpu  #$1234
        lbne  t23ko
        ldd   object_list_first
        cmpd  #Dynamic_Object_RAM+object_size
        lbne  t23ko
        jsr   LoadObject_x
        lbeq  t23ko
        cmpx  t23x
        lbne  t23ko
        lda   #$01
        sta   R.t23
t23ko

; ---------------------------------------------------------------------------
; T24 : UnloadObject_u at the head then at the tail of a list of three : the
; middle one is left alone in the list, unlinked both ways, and every
; register comes back as it went in.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        jsr   LoadObject_u
        stu   t24a
        jsr   LoadObject_u
        stu   t24b
        jsr   LoadObject_u
        stu   t24c
        ldu   t24a
        ldd   #$1357
        ldx   #$2468
        ldy   #$369C
        jsr   UnloadObject_u
        cmpd  #$1357
        lbne  t24ko
        cmpx  #$2468
        lbne  t24ko
        cmpy  #$369C
        lbne  t24ko
        cmpu  t24a
        lbne  t24ko
        ldu   t24c
        jsr   UnloadObject_u
        ldd   object_list_first
        cmpd  t24b
        lbne  t24ko
        ldd   object_list_last
        cmpd  t24b
        lbne  t24ko
        ldu   t24b
        ldd   run_object_prev,u
        lbne  t24ko
        ldd   run_object_next,u
        lbne  t24ko
        lda   #$01
        sta   R.t24
t24ko

; ---------------------------------------------------------------------------
; T25 : ObjectMove adds a s8.8 velocity to a 16.8 position. x : $0100.40 by
; -0.5 borrows from the pixel ; y : $01FF.C0 by +0.5 carries into it.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        lda   #objid.tracer
        ldb   #$11
        jsr   bench.newObject
        ldd   #$0100
        std   x_pos,u
        lda   #$40
        sta   x_sub,u
        ldd   #$FF80
        std   x_vel,u
        ldd   #$01FF
        std   y_pos,u
        lda   #$C0
        sta   y_sub,u
        ldd   #$0080
        std   y_vel,u
        jsr   ObjectMove
        ldd   x_pos,u
        cmpd  #$00FF
        lbne  t25ko
        lda   x_sub,u
        cmpa  #$C0
        lbne  t25ko
        ldd   y_pos,u
        cmpd  #$0200
        lbne  t25ko
        lda   y_sub,u
        cmpa  #$40
        lbne  t25ko
        lda   #$01
        sta   R.t25
t25ko

; ---------------------------------------------------------------------------
; T26 : ObjectMoveSync over two frames, both velocities negative. x :
; $0100.00 by 2 x -0.75 = $00FE.80 ; y : $0200.80 by 2 x -0.125 = $0200.40,
; the negative product carrying back into the same pixel.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        lda   #objid.tracer
        ldb   #$11
        jsr   bench.newObject
        ldd   #$0100
        std   x_pos,u
        clr   x_sub,u
        ldd   #$FF40
        std   x_vel,u
        ldd   #$0200
        std   y_pos,u
        lda   #$80
        sta   y_sub,u
        ldd   #$FFE0
        std   y_vel,u
        lda   #2
        sta   gfxlock.frameDrop.count
        jsr   ObjectMoveSync
        clr   gfxlock.frameDrop.count
        ldd   x_pos,u
        cmpd  #$00FE
        lbne  t26ko
        lda   x_sub,u
        cmpa  #$80
        lbne  t26ko
        ldd   y_pos,u
        cmpd  #$0200
        lbne  t26ko
        lda   y_sub,u
        cmpa  #$40
        lbne  t26ko
        lda   #$01
        sta   R.t26
t26ko

; ---------------------------------------------------------------------------
; T27 : AnimateSprite, D = 0 : an image per call. $FE 2 goes back two images
; and shows the one it lands on ; $FF restarts on the first.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        lda   #objid.tracer
        ldb   #$11
        jsr   bench.newObject
        ldx   #anim.fe
        jsr   bench.animSet
        ldy   #AnimateSprite
        ldb   #7
        jsr   bench.animTrace
        lda   #objid.tracer
        ldb   #$22
        jsr   bench.newObject
        ldx   #anim.ff
        jsr   bench.animSet
        ldy   #AnimateSprite
        ldb   #4
        jsr   bench.animTrace
        ldx   #t27want
        ldb   #11
        jsr   bench.traceIs
        tsta
        lbne  t27ko
        lda   #$01
        sta   R.t27
t27ko

; ---------------------------------------------------------------------------
; T28 : the other commands. $FD switches to another script from the next
; call, the image kept ; $FC moves to the next routine and steps over itself ;
; $FB restarts and clears the secondary routine ; $FA, the script's end,
; moves the secondary routine on at each call.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        lda   #objid.tracer
        ldb   #$11
        jsr   bench.newObject
        stu   t28a
        ldx   #anim.fd
        jsr   bench.animSet
        lda   #$55
        sta   routine_secondary,u
        ldy   #AnimateSprite
        ldb   #7
        jsr   bench.animTrace
        ldu   t28a
        lda   routine,u
        cmpa  #1                           ; one $FC
        lbne  t28ko
        lda   routine_secondary,u
        lbne  t28ko                        ; cleared by $FB
        lda   #objid.tracer
        ldb   #$22
        jsr   bench.newObject
        stu   t28a
        ldx   #anim.fa
        jsr   bench.animSet
        ldy   #AnimateSprite
        ldb   #3
        jsr   bench.animTrace
        ldu   t28a
        lda   routine_secondary,u
        cmpa  #2                           ; $FA, twice
        lbne  t28ko
        ldx   #t28want
        ldb   #10
        jsr   bench.traceIs
        tsta
        lbne  t28ko
        lda   #$01
        sta   R.t28
t28ko

; ---------------------------------------------------------------------------
; T29 : AnimateSprite copies the object's flips (status_flags) onto the
; sprite's (render_flags) and leaves the other render flags as they were.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        lda   #objid.tracer
        ldb   #$11
        jsr   bench.newObject
        ldx   #anim.fe
        jsr   bench.animSet
        lda   #%01110000|render_xmirror_mask
        sta   render_flags,u
        lda   #status_yflip_mask
        sta   status_flags,u
        jsr   AnimateSprite
        lda   render_flags,u
        cmpa  #%01110000|render_ymirror_mask
        lbne  t29ko
        lda   #$01
        sta   R.t29
t29ko

; ---------------------------------------------------------------------------
; T30 : AnimateSpriteSync looks one entry past the image it shows. A $FC
; there runs in the same call, not one image late. Past a $FF or a $FE the
; image shown is the one the command lands on, and the entry after it is
; what counts : each script is followed by a byte $FC, the D of a next
; script, which a look-ahead from the command's own entry would run.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        lda   #1
        sta   gfxlock.frameDrop.count
        lda   #objid.tracer
        ldb   #$11
        jsr   bench.newObject
        stu   t30a
        ldx   #anim.la
        jsr   bench.animSet
        ldy   #AnimateSpriteSync
        ldb   #2
        jsr   bench.animTrace
        ldu   t30a
        lda   routine,u
        cmpa  #1                           ; the $FC after the second image
        lbne  t30ko
        lda   anim_frame,u
        cmpa  #3                           ; stepped over
        lbne  t30ko
        lda   #objid.tracer
        ldb   #$22
        jsr   bench.newObject
        stu   t30a
        ldx   #anim.lf
        jsr   bench.animSet
        ldy   #AnimateSpriteSync
        ldb   #3
        jsr   bench.animTrace
        ldu   t30a
        lda   routine,u
        lbne  t30ko                        ; nothing read past the $FF
        lda   #objid.tracer
        ldb   #$33
        jsr   bench.newObject
        stu   t30a
        ldx   #anim.le
        jsr   bench.animSet
        ldy   #AnimateSpriteSync
        ldb   #3
        jsr   bench.animTrace
        ldu   t30a
        lda   routine,u
        lbne  t30ko                        ; nor past the $FE
        ldx   #t30want
        ldb   #8
        jsr   bench.traceIs
        tsta
        lbne  t30ko
        lda   #$01
        sta   R.t30
t30ko
        clr   gfxlock.frameDrop.count

; ---------------------------------------------------------------------------
; T31 : MarkObjGone keeps an object whose coarse x is within the window
; ($120 from the coarse camera) and deletes it past it, behind the camera
; too, freeing its respawn entry (bit 7) ; MarkObjGone2 takes the x in D,
; MarkObjGone3 does nothing in the window. DisplaySprite and DeleteObject
; are the bench's : they count.
; ---------------------------------------------------------------------------
        jsr   bench.reset
        ldd   #$0100
        std   glb_camera_x_pos_coarse
        clr   bench.displayed
        clr   bench.deleted
        lda   #$FF
        sta   Obj_respawn_data+5
        lda   #$80
        sta   Obj_respawn_data
        ldd   #$0150                       ; in the window
        jsr   bench.goneObject
        jsr   MarkObjGone
        ldd   #$0300                       ; MarkObjGone2 : D in the window
        jsr   bench.goneObject
        ldd   #$0150
        jsr   MarkObjGone2
        ldd   #$0150                       ; MarkObjGone3 in the window
        jsr   bench.goneObject
        jsr   MarkObjGone3
        lda   bench.displayed
        cmpa  #2
        lbne  t31ko
        lda   bench.deleted
        lbne  t31ko
        ldd   #$0300                       ; past the window, respawn entry 5
        jsr   bench.goneObject
        lda   #5
        sta   respawn_index,u
        jsr   MarkObjGone
        lda   Obj_respawn_data+5
        cmpa  #$7F
        lbne  t31ko
        ldd   #$00C0                       ; behind the camera, no respawn entry
        jsr   bench.goneObject
        jsr   MarkObjGone3
        lda   Obj_respawn_data
        cmpa  #$80                         ; entry 0 : not the table's
        lbne  t31ko
        lda   bench.deleted
        cmpa  #2
        lbne  t31ko
        clrb                               ; the three kept, the two deleted gone
        ldu   object_list_first
!       beq   >
        incb
        ldu   run_object_next,u
        bra   <
!       cmpb  #3
        lbne  t31ko
        lda   #$01
        sta   R.t31
t31ko

        lda   #result.DONE
        sta   res.done
done    bra   done

t3want   fcb   $11,$22,$33
t4want   fcb   $11,$22,$33
t4again  fcb   $11,$33
t5want   fcb   $11,$99            ; the parent, then the child it spawned
t6want   fcb   $11,$33

;*******************************************************************************
; bench helpers
;*******************************************************************************

; a clean pool, a clean list, a clean trace
bench.reset
        jsr   ManagedObjects_ClearAll
        jsr   InitStack
bench.traceReset
        ldx   #trace
        stx   trace.ptr
        ldb   #16
!       clr   ,x+
        decb
        bne   <
        rts

; a = object id, b = tag -> u = the new object, z=1 if the pool was full
bench.newObject
        sta   bench.id
        stb   bench.tag
        jsr   LoadObject_u
        beq   bench.newObject.rts
        lda   bench.tag
        sta   ext_variables,u
        lda   bench.id
        sta   id,u                         ; id is never zero here, so z=0
bench.newObject.rts
        rts

; -> the object whose code lives in the other page
bench.newPaged
        jsr   LoadObject_u
        beq   bench.newPaged.rts
        stu   t9slot
        clr   ext_variables,u
        lda   #objid.paged
        sta   id,u
bench.newPaged.rts
        rts

; x = expected bytes, b = count -> a = 0 if the trace matches exactly
bench.traceIs
        ldy   #trace
bench.traceIs.loop
        lda   ,y+
        cmpa  ,x+
        bne   bench.traceIs.ko
        decb
        bne   bench.traceIs.loop
        lda   ,y                           ; and nothing was traced past the end
        bne   bench.traceIs.ko
        clra
        rts
bench.traceIs.ko
        lda   #$FF
        rts

; -> the pool full, z=1 if a slot was refused
bench.fill
        ldb   #nb_dynamic_objects
!       jsr   LoadObject_u
        beq   >
        decb
        bne   <
        andcc #%11111011                   ; z=0 : every slot handed out
!       rts

; d = x position -> u = a new tracer there
bench.goneObject
        pshs  d
        lda   #objid.tracer
        ldb   #$11
        jsr   bench.newObject
        puls  d
        std   x_pos,u
        rts

; MarkObjGone's two ends, counted
DisplaySprite
        inc   bench.displayed
        rts
DeleteObject
        inc   bench.deleted
        jmp   UnloadObject_u

; b = calls, y = AnimateSprite or AnimateSpriteSync -> after each call, the
; image's high byte appended to the trace
bench.animTrace
        stb   bench.animN
        sty   bench.animFn
        pshs  u
!       ldu   ,s
        jsr   [bench.animFn]
        ldu   ,s
        lda   image_set,u
        jsr   trace.put
        dec   bench.animN
        bne   <
        puls  u,pc

; put the object on the fake animation, at its first frame
bench.animReset
        ldx   #anim.table
; x = a script -> the object on it, at its first frame
bench.animSet
        stx   anim,u
        clr   anim_frame,u
        clr   anim_frame_duration,u
        clr   anim_flags,u
        ldd   #0
        std   prev_anim,u
        std   image_set,u
        rts

; b = number of calls -> that many AnimateSpriteSync steps on u.
; The counter lives in memory and u is reloaded every turn : AnimateSprite
; uses B and Y freely, and says nothing about what it preserves.
bench.animSteps
        stb   bench.animN
        pshs  u
!       ldu   ,s
        jsr   AnimateSpriteSync
        dec   bench.animN
        bne   <
        puls  u,pc

; b = number of calls -> that many AnimateSprite steps on u
bench.animStepsPlain
        stb   bench.animN
        pshs  u
!       ldu   ,s
        jsr   AnimateSprite
        dec   bench.animN
        bne   <
        puls  u,pc

; u, x = two animated objects -> z set if they show the same image, at the
; same frame of the script, with the same time left on it
t19same
        lda   anim_frame,u
        cmpa  anim_frame,x
        bne   >
        lda   anim_frame_duration,u
        cmpa  anim_frame_duration,x
        bne   >
        ldd   image_set,u
        cmpd  image_set,x
!       rts

; x = a T20 case -> z set if it passed
t20run
        stx   t20case
        jsr   bench.reset
        lda   #objid.tracer
        ldb   #$11
        jsr   bench.newObject
        stu   t20a
        ldx   t20case
        jsr   t20init
        lda   #objid.tracer
        ldb   #$22
        jsr   bench.newObject
        stu   t20b
        ldx   t20case
        jsr   t20init
        ldx   t20case                      ; a : k frames in one call
        lda   10,x
        sta   gfxlock.frameDrop.count
        sta   t20n
        ldd   8,x
        ldu   t20a
        jsr   ObjectMoveAndFallSync
        lda   #1                           ; b : k calls of one frame
        sta   gfxlock.frameDrop.count
!       ldx   t20case
        ldd   8,x
        ldu   t20b
        jsr   ObjectMoveAndFallSync
        dec   t20n
        bne   <
        clr   gfxlock.frameDrop.count
        ldu   t20a                         ; a = b, from x_pos to y_vel
        ldx   t20b
        leau  x_pos,u
        leax  x_pos,x
        ldb   #y_vel+2-x_pos
!       lda   ,u+
        cmpa  ,x+
        bne   t20run.rts
        decb
        bne   <
        ldu   t20a                         ; a = the values worked out by hand
        ldx   t20case
        ldd   x_pos,u
        cmpd  12,x
        bne   t20run.rts
        lda   x_sub,u
        cmpa  14,x
        bne   t20run.rts
        ldd   y_pos,u
        cmpd  15,x
        bne   t20run.rts
        lda   y_sub,u
        cmpa  17,x
        bne   t20run.rts
        ldd   y_vel,u
        cmpd  18,x
t20run.rts
        rts

; u = object, x = T20 case : its position, subpixels cleared, and velocity
t20init
        ldd   ,x
        std   x_pos,u
        clr   x_sub,u
        ldd   2,x
        std   x_vel,u
        ldd   4,x
        std   y_pos,u
        clr   y_sub,u
        ldd   6,x
        std   y_vel,u
        rts

; put the object on the bench script, at its first segment.
; moveByScript.initialize would do this through a per object LUT ; v2 can name
; the script directly, which is what its own comment says to expect.
bench.scriptReset
        ldd   #script.table
        std   anim,u
        ldd   #script.segment
        std   sub_anim,u
        lda   #1
        sta   anim_frame_duration,u        ; one move command per frame
        ldd   #$0100
        std   x_pos,u
        clr   x_sub,u
        ldd   #$0200
        std   y_pos,u
        clr   y_sub,u
        ldd   #0
        std   x_vel,u
        std   y_vel,u
        ldd   #script.callback
        std   moveByScript.callback
        clr   moveByScript.anim.end
        rts

; moveByScript calls this once per elapsed frame, with the caller's page back
script.callback
        rts

; u = box -> zeroed, then given the shared geometry : centre (40,40), half
; extents 5x5, links cleared. Tests override what they need.
bench.aabbReset
        ldd   #0
        std   AABB.prev,u
        std   AABB.next,u
        sta   AABB.p,u
        lda   #5
        sta   AABB.rx,u
        sta   AABB.ry,u
        lda   #40
        sta   AABB.cx,u
        sta   AABB.cy,u
        rts

; a = byte to append to the trace
trace.put
        pshs  x
        ldx   trace.ptr
        sta   ,x+
        stx   trace.ptr
        puls  x,pc

;*******************************************************************************
; the objects
;*******************************************************************************

; writes its tag to the trace
obj.tracer
        lda   ext_variables,u
        jsr   trace.put
        rts

; writes its tag, then takes itself out of the run list
obj.suicide
        lda   ext_variables,u
        jsr   trace.put
        jsr   UnloadObject_u
        rts

; writes its tag, then links a child behind it. The child is a tracer with a
; tag of its own ; being linked at the end of the list, it runs in this pass.
obj.parent
        lda   ext_variables,u
        jsr   trace.put
        pshs  u
        jsr   LoadObject_u
        beq   obj.parent.rts
        lda   #$99
        sta   ext_variables,u
        lda   #objid.tracer
        sta   id,u
obj.parent.rts
        puls  u,pc

;*******************************************************************************
; bench state
;*******************************************************************************

bench.id   fcb   0
bench.tag  fcb   0
t6mid      fdb   0
t8slot     fdb   0
t9slot     fdb   0
trace.ptr  fdb   trace

bench.animN fcb  0
t13a       fdb   0
t13b       fdb   0
t19a       fdb   0
t19b       fdb   0
t19c       fdb   0
t20a       fdb   0
t20b       fdb   0
t20case    fdb   0
t20n       fcb   0
t23x       fdb   0
t24a       fdb   0
t24b       fdb   0
t24c       fdb   0
t28a       fdb   0
t30a       fdb   0
bench.animFn    fdb 0
bench.displayed fcb 0
bench.deleted   fcb 0

t27want    fcb   $A1,$A2,$A3,$A2,$A3,$A2,$A3,$B1,$B2,$B1,$B2
t28want    fcb   $C1,$C1,$C2,$C2,$C3,$C3,$C2,$C5,$C5,$C5
t30want    fcb   $D1,$D2,$E1,$E2,$E1,$E1,$E2,$E2

; T20 cases : x_pos, x_vel, y_pos, y_vel, g, k, a pad byte, then what k
; frames of ObjectMoveAndFall leave : x_pos, x_sub, y_pos, y_sub, y_vel
t20case1   fdb   $0050,$0123,$0100,$FC00,$0038 ; y : $0100.00 -3*$400 +3*$38
           fcb   3,0
           fdb   $0053
           fcb   $69
           fdb   $00F4
           fcb   $A8
           fdb   $FCA8
t20case2   fdb   $0010,$FF80,$0080,$0200,$FFE8 ; g < 0 : the velocity falls upwards
           fcb   3,0
           fdb   $000E
           fcb   $80
           fdb   $0085
           fcb   $B8
           fdb   $01B8
t20case3   fdb   $0000,$0000,$0200,$FB00,$0038 ; seven frames : 7*-$500 + 21*$38
           fcb   7,0
           fdb   $0000
           fcb   $00
           fdb   $01E1
           fcb   $98
           fdb   $FC88

; a fake animation : three frames of four elapsed frames each, then reset.
; The duration byte sits before the label because AnimateSprite reads it at
; -1,x. The frame values are never dereferenced, only stored into image_set.
           fcb   4
anim.table
           fdb   $1111
           fdb   $2222
           fdb   $3333
           fcb   $FF                       ; _resetAnim

; the scripts of T27 to T30, D = 0 : an image per call
           fcb   0
anim.fe    fdb   $A1A1,$A2A2,$A3A3
           fcb   $FE,2                     ; back two images
           fcb   0
anim.ff    fdb   $B1B1,$B2B2
           fcb   $FF,0
           fcb   0
anim.fd    fdb   $C1C1
           fcb   $FD
           fdb   anim.fd2
           fcb   0
anim.fd2   fdb   $C2C2
           fcb   $FC,0
           fdb   $C3C3
           fcb   $FB,0
           fcb   0
anim.fa    fdb   $C5C5
           fcb   $FA,0
           fcb   0
anim.la    fdb   $D1D1,$D2D2
           fcb   $FC,0
           fdb   $D3D3
           fcb   0
anim.lf    fdb   $E1E1,$E2E2
           fcb   $FF,0
           fcb   $FC,0                     ; a next script's D, a $FC to a look-ahead
           fcb   0
anim.le    fdb   $E1E1,$E2E2
           fcb   $FE,1
           fcb   $FC,0

; The bench script : three steps along +x, then the end of segment marker,
; then the end of script word. A byte is  img|xneg|xmov|ypos|ymov|endseg .
script.segment
           fcb   %00100000               ; x += POSXSTEP
           fcb   %00100000
           fcb   %00100000
           fcb   %00000100               ; end of segment
script.table
           fdb   script.segment
           fdb   $0000                   ; end of script...
           fdb   script.table            ; ...and where to resume

; the AABB lists and boxes of T16. A list head is [first][last].
AABB_list_a fdb   0,0
AABB_list_b fdb   0,0
box1        fill  0,sizeof{AABB}
box2        fill  0,sizeof{AABB}
box3        fill  0,sizeof{AABB}
box4        fill  0,sizeof{AABB}

trace      equ   $9D00

;*******************************************************************************
; object indexes — the game's side of the object/code contract
;*******************************************************************************
; v1 generated these during its global placement pass : per object id, the
; page its code sits in and its entry point. v2 has no object pipeline yet
; (roadmap item 7), so the bench writes them by hand — which is what makes the
; paged entry the interesting one : its address is an EXTERNAL the load time
; linker resolves or the builder bakes, and its page comes from the
; attributed-place equates entries.asm publishes.

objid.tracer  equ 1
objid.suicide equ 2
objid.parent  equ 3
objid.paged   equ 4

Obj_Index_Page
        fcb   $00                                    ; id 0 : free slot
        fcb   map.RAM_OVER_CART+assets.gm.main.page        ; tracer
        fcb   map.RAM_OVER_CART+assets.gm.main.page        ; suicide
        fcb   map.RAM_OVER_CART+assets.gm.main.page        ; parent
        fcb   map.RAM_OVER_CART+assets.objects.page         ; paged : its own page

Obj_Index_Address
        fdb   $0000
        fdb   obj.tracer
        fdb   obj.suicide
        fdb   obj.parent
        fdb   obj.paged.run

; AnimateSprite mounts the page holding the animation table the same way it
; mounts an object's code, and reads Ani_Asd_Index only when anim,u is
; negative — a signed offset into a per object table of animations. The bench
; points anim,u straight at its table, so that path is never taken ; the
; symbol still has to resolve.
Ani_Page_Index
        fcb   $00
        fcb   map.RAM_OVER_CART+assets.gm.main.page
        fcb   map.RAM_OVER_CART+assets.gm.main.page
        fcb   map.RAM_OVER_CART+assets.gm.main.page
        fcb   map.RAM_OVER_CART+assets.objects.page

Ani_Asd_Index
        fdb   $0000
        fdb   $0000
        fdb   $0000
        fdb   $0000
        fdb   $0000

;*******************************************************************************
; engine
;*******************************************************************************
        INCLUDE "engine/graphics/buffer/gfxlock.asm"
        ; the four steps a script's move commands are worth. r-type uses
        ; subpixel values ; the bench uses one whole pixel so the arithmetic
        ; is the thing being read, not the fixed point.
moveByScript.POSXSTEP equ $0100
moveByScript.NEGXSTEP equ -$0100
moveByScript.POSYSTEP equ $0100
moveByScript.NEGYSTEP equ -$0100

        INCLUDE "engine/graphics/animation/AnimateSprite.asm"
        INCLUDE "engine/graphics/animation/AnimateSpriteSync.asm"
        INCLUDE "engine/graphics/animation/moveByScript.asm"
        INCLUDE "engine/collision/collision.asm"
        INCLUDE "engine/object-management/ObjectWave-subtype.asm"
        INCLUDE "engine/graphics/camera/AutoScroll.asm"
        INCLUDE "engine/graphics/camera/CheckCameraMove.asm"
        INCLUDE "engine/object-management/RunObjects.asm"
        INCLUDE "engine/object-management/ObjectMove.asm"
        INCLUDE "engine/object-management/ObjectMoveSync.asm"
        INCLUDE "engine/object-management/MarkObjGone.asm"
        INCLUDE "engine/object-management/ObjectMoveAndFallSync.asm"
        INCLUDE "engine/object-management/ObjectDp.asm"
        INCLUDE "engine/object-management/RunPgSubRoutine.asm"

 ENDSECTION
