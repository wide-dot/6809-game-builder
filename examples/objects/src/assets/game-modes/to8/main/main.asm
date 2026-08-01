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
; result table ($9C00) :
;   +0  : $CA magic (the bench is running)
;   +1  : T1  InitStack hands out a slot, the list heads follow it
;   +2  : T2  the pool is finite : the fifth request on four slots is refused
;   +3  : T3  RunObjects walks the list in order
;   +4  : T4  an object deletes itself mid-walk and the walk carries on
;   +5  : T5  an object spawns a child mid-walk and the child runs the same pass
;   +6  : T6  UnloadObject_x unlinks from the middle of the list
;   +7  : T7  a freed slot comes back on the next load
;   +8  : T8  unloading clears the object's data
;   +9  : T9  an object living in its own page is mounted and run
;   +10 : T10 ObjectMoveSync applies velocity once per elapsed frame
;   +11 : T11 ObjectDp_Clear wipes the user direct page and stops where it must
;   +12 : T12 RunPgSubRoutine runs in another page and restores the caller's
;   +13 : (byte) the parameter RunPgSubRoutine's callee echoed back
;   +14 : T13 AnimateSpriteSync spends elapsed frames, not calls
;   +15 : T14 moveByScript walks a script and applies its steps
;   +16 : T15 and it too spends elapsed frames, not calls
;   +31 : $00 running, $0D all passed, $E0+n : n test(s) failed
;*******************************************************************************

; the paged unit's entry points : resolved at load time, so the game mode
; never spells out where that page ended up
obj.paged.run   EXTERNAL
obj.paged.sub   EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"

        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.macro.asm"

        INCLUDE "gen/layout.asm"
        INCLUDE "src/common/result.const.asm"
        INCLUDE "src/assets/game-modes/to8/main/ram_data.asm"

 opt c,ct

        ; the scene loads this file at the game mode region address and jumps
        ; to its first byte, so main has to be the first thing emitted

main
        ldx   #result
        ldb   #32
!       clr   ,x+
        decb
        bne   <
        lda   #result.MAGIC
        sta   result

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
        sta   result+1
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
        sta   result+2
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
        sta   result+3
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
        sta   result+4
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
        sta   result+5
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
        sta   result+6
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
        sta   result+7
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
        sta   result+8
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
        sta   result+9                     ; replace the magic with the verdict
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
        sta   result+10
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
        sta   result+11
t11ko

; ---------------------------------------------------------------------------
; T12 : RunPgSubRoutine calls into another page and puts back the page the
; caller was using. That restore is what lets a mounted object call another
; one without pulling its own code out from under itself.
; ---------------------------------------------------------------------------
        _ram.cart.set #$05                 ; the caller's page
        lda   #map.RAM_OVER_CART+objects.page
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
        sta   result+12
        lda   #$3C
        sta   result+13
t12ko

; ---------------------------------------------------------------------------
; T13 : AnimateSpriteSync spends its budget in elapsed frames, not in calls.
; Eight calls reporting one dropped frame each must land on the same displayed
; frame as four calls reporting two — that is the point of the variant, and it
; is what keeps r-type's waves and boss in step with the arcade timings they
; were measured against.
;
; Both are primed with a drop of zero first. The call that loads an animation
; is not comparable between the two regimes : it consumes its own frame drop
; on the spot, so a regime reporting two starts one frame further along.
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
        sta   result+14
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
        sta   result+15
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
        sta   result+16
t15ko

; ---------------------------------------------------------------------------
; verdict
; ---------------------------------------------------------------------------
        ldx   #result+1
        clrb
verdict.loop
        cmpx  #result+13                   ; +13 carries a value, not a verdict
        beq   verdict.next
        lda   ,x
        cmpa  #$01
        beq   verdict.next
        incb
verdict.next
        leax  1,x
        cmpx  #result+17
        bne   verdict.loop
        tstb
        bne   verdict.failed
        lda   #result.DONE_OK
        bra   verdict.write
verdict.failed
        addb  #result.DONE_KO
        tfr   b,a
verdict.write
        sta   result+31
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

; put the object on the fake animation, at its first frame
bench.animReset
        ldd   #anim.table
        std   anim,u
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

; a fake animation : three frames of four elapsed frames each, then reset.
; The duration byte sits before the label because AnimateSprite reads it at
; -1,x. The frame values are never dereferenced, only stored into image_set.
           fcb   4
anim.table
           fdb   $1111
           fdb   $2222
           fdb   $3333
           fcb   $FF                       ; _resetAnim

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

trace      equ   $9D00

;*******************************************************************************
; object indexes — the game's side of the object/code contract
;*******************************************************************************
; v1 generated these during its global placement pass : per object id, the
; page its code sits in and its entry point. v2 has no object pipeline yet
; (roadmap item 7), so the bench writes them by hand — which is what makes the
; paged entry the interesting one : its address is an EXTERNAL the load time
; linker resolves, and its page comes from the declared layout.

objid.tracer  equ 1
objid.suicide equ 2
objid.parent  equ 3
objid.paged   equ 4

Obj_Index_Page
        fcb   $00                                    ; id 0 : free slot
        fcb   map.RAM_OVER_CART+gamemode.page        ; tracer
        fcb   map.RAM_OVER_CART+gamemode.page        ; suicide
        fcb   map.RAM_OVER_CART+gamemode.page        ; parent
        fcb   map.RAM_OVER_CART+objects.page         ; paged : its own page

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
        fcb   map.RAM_OVER_CART+gamemode.page
        fcb   map.RAM_OVER_CART+gamemode.page
        fcb   map.RAM_OVER_CART+gamemode.page
        fcb   map.RAM_OVER_CART+objects.page

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
        INCLUDE "engine/object-management/RunObjects.asm"
        INCLUDE "engine/object-management/ObjectMoveSync.asm"
        INCLUDE "engine/object-management/ObjectDp.asm"
        INCLUDE "engine/object-management/RunPgSubRoutine.asm"

 ENDSECTION
