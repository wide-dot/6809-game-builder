;*******************************************************************************
; newt — the stage 6 pipe crawler (23 wave lines), ported 1:1 from the arcade
;
; PORTING SHEET (source: Ghidra `maincpu`, subsystem enemy_newt)
; ------------------------------------------------------------------------------
;   40:7294 create_newt ................ newt.Init : fire preset, start
;                                         (1000:93DC), phase (token bit 8) x 2
;   40:72D2 run_newt ................... newt.Step, one arcade frame
;   40:737D draw_newt_with_hit_blink ... the blink (12 frames, 1 in 4 white)
;   40:73A0 align_newt_walk_phase_to_terrain   the turn
;   40:73DB try_newt_fire_and_spawn .... the fire ladder and its shot
;   40:7435 run_newt_fire .............. newt.shot.*
;
; THE WALK. Four phases (left, right, up, down : 1000:329E, 1 px or 0.875 px a
; frame), the scroll dragging it (72D2 adds scroll_amount: world coordinates
; here, as the Dop). Each frame it looks 32 px ahead (1000:32AE) and turns
; back — phase ^ 1 — when that point is off the screen, and AGAIN when the
; cell there is EMPTY (73D1 : JC skips the flip on a solid tile). A Newt
; crawls INSIDE the pipes and turns at their ends; the two tests stack, so a
; point off the screen on a solid cell leaves the phase as it was.
; Its probe often looks past the right edge: there the arcade's tile RAM, a
; 64-column ring refilled a map tile at a time, can still hold the column
; 512 px back (newt6_model.py on the MAME trace of the stage: every Newt's
; position and phase, every frame).
;
; THE WALK IS PRECOMPUTED, as the Dop's (src/enemies/dop/dops.asm): nothing
; in it is random, tools/gen_stage6_paths.py replays it offline, ring
; included, and writes {frame, phase} a turn, {frame, $FF} the exit. A Newt
; stuck at a pipe's end turns back EVERY frame (it jitters in place, up to
; the end of the stage): a run of such turns is one entry, phase + $80, the
; flip then done here after each move until the next entry.
;
; THE SHOT (40:7435) is its own: a dot (1000:327E) that keeps the screen (no
; scroll), harmless to the walls for 8 even frames (it is born in a pipe),
; probing the terrain on the even frames after; the Force absorbs it, the
; ship dies on it. Here it is the same object, born with the Newt's id and
; a marked subtype ($FF high byte).
;
; THE Y FRACTION: create_newt sets the integer only and keeps the fraction
; the record's last owner left — up to one pixel, a turn a frame earlier or
; later, 8 px after. It belongs to the game played: the path brings the one of
; the reference game (the MAME trace), the byte before its first entry.
;
; DEVIATIONS: collision once per render; the blink shows one white silhouette an
; orientation (pose 0, the zoid's idiom); the shot's terrain probe is the
; port's terrain collision (both planes when the stage says so).
;*******************************************************************************

newt.wx       equ ext_variables      ; 0,1 world x, arcade px (= dop.wx) : its
                                     ; speed is 1 px, no fraction
newt.ph       equ ext_variables+2    ; walk phase 0..3 (+0x10), bit 7: jitter
newt.wy       equ ext_variables+3    ; 3..5 y, 16.8 arcade px     (= dop.wy)
newt.cell     equ ext_variables+6    ; pose 0..4 (+0x20 / 6), bit 7: the last
                                     ; frame painted the blink
newt.bl       equ ext_variables+7    ; hit blink (+0x3D)
newt.pp       equ ext_variables+8    ; box potential seen last render
newt.box      equ ext_variables+9    ; 9..17 its AABB
newt.path     equ ext_variables+18   ; 18,19 the next entry of its path

shot.box      equ ext_variables      ; 0..8
shot.vx       equ ext_variables+9    ; 9,10 v2 8.8
shot.vy       equ ext_variables+11   ; 11,12
shot.ttl      equ ext_variables+13   ; 13 the even frames left before probing
shot.ph       equ ext_variables+14   ; 14 its pose phase (the record's place)

newt.HP       equ 2                  ; 72b9 damage_max
newt.BLINK    equ $0C                ; 7329

newt.Object
        lda   routine,u
        asla
        ldx   #newt.Routines
        jmp   [a,x]
newt.Routines
        fdb   newt.Init
        fdb   newt.Live
        fdb   newt.Deleted
        fdb   newt.shot.Live
        fdb   newt.Deleted

; -----------------------------------------------------------------------------
; 40:7294 create_newt — born on frame g, it ticks from g + 1
; -----------------------------------------------------------------------------
newt.Init
        ldb   wave_frame_drop,u        ; the lateness, BEFORE anything else
        stb   newt.late
        lda   subtype_w,u              ; the shot: $FF high byte
        cmpa  #$FF
        lbeq  newt.shot.Init
        ldb   subtype_w+1,u            ; 72a1 the fire preset (token >> 4),
        _loadFirePreset                ; BEFORE render_flags
        lda   subtype_w,u              ; 72a7 (token high & 1) * 2
        anda  #1
        asla
        sta   newt.ph,u
        ldb   subtype_w+1,u            ; 72a4 the start, token bits 0-3
        andb  #$0F
        aslb
        aslb
        ldx   #newt.Start
        abx
        ldd   gfxlock.frame.gameCount  ; the birth frame
        subb  newt.late
        sbca  #0
        std   dop.g
        jsr   dop.Cam
        addd  ,x                       ; screen x + camera = world x
        std   newt.wx,u
        ldd   2,x
        std   newt.wy,u
        clr   newt.cell,u              ; 72b0
        clr   newt.bl,u                ; 72cd
        ldx   #newt.Paths              ; the path of this birth
        jsr   dop.FindPath
        stx   newt.path,u
        lda   -1,x                     ; the y fraction the record held
        sta   newt.wy+2,u
        lda   #newt.HP
        sta   newt.pp,u
        ldb   #4
        stb   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        _Collision_AddAABB newt.box,AABB_list_ennemy
        lda   #newt.HP                 ; 72b9 two hits
        sta   newt.box+AABB.p,u
        _ldd  newt_hitbox_x,newt_hitbox_y
        std   newt.box+AABB.rx,u
        lda   #220                     ; parked until published
        sta   newt.box+AABB.cx,u
        inc   routine,u
        ldb   newt.late
        bra   newt.Run

newt.Live
        lda   newt.box+AABB.p,u        ; 7327 a hit: the blink, 12 frames
        cmpa  newt.pp,u
        bhs   >
        sta   newt.pp,u
        lda   #newt.BLINK
        sta   newt.bl,u
!       ldb   gfxlock.frameDrop.count
        bne   newt.Run
        incb
newt.Run
        stb   newt.n
        lbeq  newt.Publish
@frame  ldd   gfxlock.frame.gameCount  ; the frame replayed
        subb  newt.n
        sbca  #0
        addd  #1
        std   dop.g
        jsr   newt.Step
        lda   routine,u                ; dead or gone this frame
        cmpa  #1
        bne   newt.Deleted
        dec   newt.n
        bne   @frame
        jmp   newt.Publish
newt.Deleted
        rts

; -----------------------------------------------------------------------------
; 40:72D2 run_newt — one arcade frame, dop.g
; -----------------------------------------------------------------------------
newt.Step
        lda   newt.ph,u                ; 72d8 the speed of this phase
        anda  #3
        asla
        asla
        ldx   #newt.Vel
        leax  a,x
        ldb   ,x                       ; x: +-1 px, no fraction
        sex
        addd  newt.wx,u
        std   newt.wx,u
        ldd   2,x
        beq   >
        leax  newt.wy,u
        jsr   dop.Move
!       lda   newt.cell,u              ; 72f1 every 8 frames, the next pose
        anda  #$7F
        ldb   dop.g+1
        addb  #dop.GC0LO
        andb  #7
        bne   @blink
        inca
        cmpa  #5
        bne   @blink
        clra
@blink  ldb   newt.bl,u                ; 737d the blink: 1 frame in 4 white
        beq   @cell
        decb
        stb   newt.bl,u
        bitb  #3
        bne   @cell
        ora   #$80
@cell   sta   newt.cell,u
        jsr   newt.Fire                ; 73db
        lda   newt.box+AABB.p,u        ; 7332 damage >= 2 ?
        lbeq  newt.Die
        lda   newt.ph,u                ; 73a0 the turn: jittering, every frame
        bpl   >
        eora  #1
        sta   newt.ph,u
!       ldx   newt.path,u              ; the turns of the path, 733a the exit
        ldd   dop.g
        cmpd  ,x
        blo   @rts
        lda   2,x
        cmpa  #$FF
        lbeq  newt.Gone
        sta   newt.ph,u
        leax  3,x
        stx   newt.path,u
@rts    rts

; 40:73DB the fire ladder, one frame: ++timer ; == threshold -> fire ; >=
; reset -> timer 0, fire. A preset of 0 does not fire.
newt.Fire
        ldd   fireCounter,u
        addd  #1
        std   fireCounter,u
        cmpb  fireThreshold,u          ; 73e1 (the threshold is a byte here)
        bne   @reset
        tsta
        beq   @shoot
@reset  cmpd  fireReset,u              ; 73e6
        blo   @rts
        ldd   #0
        std   fireCounter,u
@shoot  lda   fireVelocityPreset,u     ; 73f1 no preset, no fire
        beq   @rts
        jsr   LoadObject_x             ; 73fe pool full : bail
        beq   @rts
        lda   id,u
        sta   id,x
        lda   #$FF
        sta   subtype_w,x
        lda   newt.n                   ; it ticks this very frame (0xA000
        sta   wave_frame_drop,x        ; sits behind the Newt) and the rest
        pshs  x
        jsr   dop.Place                ; 7403 the Newt's place
        std   x_pos,u
        ldd   dop.t
        std   y_pos,u
        puls  x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
        clr   x_pos+2,x
        clr   y_pos+2,x
        pshs  x                        ; 7413 aim at the ship : setDirectionTo
        ldx   #player1                 ; (U the shooter, X the target -> Y
        jsr   setDirectionTo           ; the preset rank 0..63)
        lda   #64
        ldb   fireVelocityPreset,u
        decb
        mul
        addd  #newt.FireVel
        leay  d,y
        puls  x
        ldd   ,y
        std   shot.vx,x
        ldd   2,y
        std   shot.vy,x
@rts    rts

; 40:735A death: score 0x86F0, sound 0x52, the small double explosion
newt.Die
        ldb   #newt_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        beq   newt.Gone
        _ldd  ObjID_explosion,explosion.subtype.smallx2+explosion.sfx.turret
        std   id,x
        jsr   dop.Place
        std   x_pos,x
        ldd   dop.t
        std   y_pos,x
; 40:7347 the silent unload
newt.Gone
        lda   #2
        sta   routine,u
        _Collision_RemoveAABB newt.box,AABB_list_ennemy
        jmp   DeleteObject

; once per render: the picture and the box
newt.Publish
        jsr   dop.Place
        std   x_pos,u
        ldd   dop.t
        std   y_pos,u
        lda   newt.ph,u                ; 7310 the poses of this phase
        anda  #3
        ldb   #10
        mul
        ldx   #newt.Sets
        abx
        ldb   newt.cell,u
        aslb
        bcc   >
        ldx   #newt.HitSets            ; the white one, by orientation
        ldb   newt.ph,u
        andb  #2
!       ldd   b,x
        std   image_set,u
        ldd   x_pos,u
        subd  glb_camera_x_pos
        tsta
        beq   >
        ldb   #220                     ; off the screen: parked
!       stb   newt.box+AABB.cx,u
        ldb   y_pos+1,u
        stb   newt.box+AABB.cy,u
        jmp   DisplaySprite

;*******************************************************************************
; THE SHOT — 40:7435 run_newt_fire
;*******************************************************************************
newt.shot.Init
        ldb   #2
        stb   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        _Collision_AddAABB shot.box,AABB_list_foefire
        lda   #1
        sta   shot.box+AABB.p,u
        _ldd  2,2                      ; 3296 : +/-2
        std   shot.box+AABB.rx,u
        lda   #8                       ; 7427 +0x20 := 8
        sta   shot.ttl,u
        tfr   u,d                      ; 7441 the pose phase: the record's
        lsrb                           ; place (BP >> 3)
        lsrb
        lsrb
        stb   shot.ph,u
        lda   #3
        sta   routine,u
        ldb   newt.late
        bra   newt.shot.Run

newt.shot.Live
        ldd   x_pos,u                  ; the screen keeps it: dragged by the
        addd  glb_camera_x_pos         ; camera once a render
        subd  glb_camera_x_pos_old
        std   x_pos,u
        ldb   gfxlock.frameDrop.count
        bne   newt.shot.Run
        incb
newt.shot.Run
        stb   newt.n
        beq   @show
@frame  ldd   gfxlock.frame.gameCount
        subb  newt.n
        sbca  #0
        addd  #1
        std   dop.g
        ldd   shot.vx,u                ; 7435 straight on
        leax  x_pos,u
        jsr   dop.Move
        ldd   shot.vy,u
        leax  y_pos,u
        jsr   dop.Move
        ldb   dop.g+1                  ; 7477 the even frames only
        addb  #dop.GC0LO
        bitb  #1
        bne   @next
        lda   shot.ttl,u               ; 747f the grace, in a pipe
        beq   @probe
        dec   shot.ttl,u
        bra   @next
@probe  ldd   x_pos,u                  ; 748c the walls
        std   terrainCollision.sensor.x
        ldd   y_pos,u
        std   terrainCollision.sensor.y
        ldb   #1
        jsr   terrainCollision.do
        tstb
        bne   newt.shot.Gone
        lda   globals.backgroundSolid
        beq   @next
        ldd   x_pos,u
        std   terrainCollision.sensor.x
        ldd   y_pos,u
        std   terrainCollision.sensor.y
        ldb   #0
        jsr   terrainCollision.do
        tstb
        bne   newt.shot.Gone
@next   dec   newt.n
        bne   @frame
@show   lda   shot.box+AABB.p,u        ; the Force took it
        beq   newt.shot.Gone
        ldd   x_pos,u                  ; 74a1 is_visible_range
        subd  glb_camera_x_pos
        cmpd  #0
        blt   newt.shot.Gone
        cmpd  #160
        bge   newt.shot.Gone
        stb   shot.box+AABB.cx,u
        ldd   y_pos,u
        cmpd  #-3
        blt   newt.shot.Gone
        cmpd  #207
        bge   newt.shot.Gone
        stb   shot.box+AABB.cy,u
        ldb   gfxlock.frame.gameCount+1 ; 7441 (BP >> 3 + counter) & 0x18
        addb  #dop.GC0LO
        addb  shot.ph,u
        andb  #$18
        lsrb
        lsrb
        ldx   #newt.ShotSets
        ldd   b,x
        std   image_set,u
        jmp   DisplaySprite
newt.shot.Gone
        lda   #4
        sta   routine,u
        _Collision_RemoveAABB shot.box,AABB_list_foefire
        jmp   DeleteObject

newt.late     fcb   0
newt.n        fcb   0

; 1000:32BE the poses by phase, five each (left, right, up, down)
newt.Sets
        fdb   set_newt_h_0,set_newt_h_1,set_newt_h_2,set_newt_h_3,set_newt_h_4
        fdb   set_newt_ha_0,set_newt_ha_1,set_newt_ha_2,set_newt_ha_3,set_newt_ha_4
        fdb   set_newt_va_0,set_newt_va_1,set_newt_va_2,set_newt_va_3,set_newt_va_4
        fdb   set_newt_v_0,set_newt_v_1,set_newt_v_2,set_newt_v_3,set_newt_v_4
newt.HitSets
        fdb   set_newt_hit_h_0,set_newt_hit_v_0
newt.ShotSets
        fdb   set_newtfire_0,set_newtfire_1,set_newtfire_2,set_newtfire_3

newt.FireVel                         ; the foe shots' table (createFoeFire)
        INCLUDE "src/common/lib/presets/18f90_preset-fireVelocity.asm"

        INCLUDE "src/enemies/newt/tables.asm"
