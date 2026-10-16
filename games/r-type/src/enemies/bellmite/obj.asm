;*******************************************************************************
; bellmite — the stage 5 boss, ported 1:1 from the arcade
;
; PORTING SHEET (source: Ghidra `maincpu`, subsystem bellmite)
; ------------------------------------------------------------
;   40:B1D8 create_bellmite ............... bellmite.Init (frame 0)
;   40:B1FA tick_bellmite_init_satellites . bm.ParentInit (frame 1)
;   40:B2DC tick_bellmite_combat .......... bm.ParentCombat
;   40:B3CC destroy path .................. bm.ParentDestroy
;   40:B40A end_boss_after_stage5_boss .... bm.ParentEnd
;   40:B473 run_bellmite (timeout) ........ bm.ParentRun
;   40:B491 tick_bellmite_death_helper .... bm.Helper
;   40:B521 tick_bellmite_satellite_orbit . bm.SatOrbit
;   40:B5BB / B6AE post-kill countdown .... bm.SatPostKill
;   40:B5CD / B6C4 post-scroll-out ........ bm.SatScrollOut
;   40:B5D3 satellite destroy with score .. bm.SatDestroy
;   40:B5FC satellite silent unload ....... bm.SatUnload
;   40:B60F / B645 attack ................. bm.SatAttack
;   40:B719 satellite paint ............... bm.SatPaint (flash countdown)
;   40:B75A closest check ................. bm.SatClosest
;   40:B797 drift correction .............. bm.SatDrift
;   40:EDE9 random_ax ..................... bm.Rand (private copy, see below)
;   40:1D89 set_direction_to .............. bm.Direction
;   40:B4B5 / B4C9 explosion cascade: DEAD CODE in the arcade (no caller,
;     no pointer to B4B5 anywhere in the ROM) — not ported.
;
; THE PORT RUNS IN ARCADE SPACE. Positions, velocities, thresholds and
; tables are the arcade's own (x to the right, y UP, 16.8 positions, 8.8
; velocities); only the publication converts to the screen, every render:
;     x_screen = 8 + ((x - 320) * 3) >> 3      y_screen = 297 - (y * 3) >> 2
; This is what makes the port checkable: the TO8 trace of these records is
; compared byte for byte with the MAME trace (tools/fidelity/). The earlier
; bosses converted velocities to TO8 units, and the rounding drifted (the
; Compiler still does).
;
; ONE ARCADE FRAME AT A TIME. bm.Frame is exactly one arcade game frame for
; the whole family, in the arcade's list order (parent, satellites 1..37 by
; priority, then the death helper). Live runs it frameDrop.count times per
; render: every rule (drift every 8 frames, collision gate 1 frame in 4,
; attack period, timeouts) keeps its arcade cadence, and the random draws
; happen in the arcade's order.
;
; THE RANDOM GENERATOR IS THE ARCADE'S. During the fight every draw of
; random_ax comes from this family (measured on the MAME trace: every
; transition of the state 0x2F28 is explained by the satellites' drift, the
; rerolls and the reseed), and the game reseeds it to (5,1,3) when the global
; counter crosses a multiple of 512. bm.gc mirrors that counter (seeded from
; gfxlock.frame.gameCount at the spawn) and bm.rng is a private copy of the
; state. A test harness writes the arcade's values at bellmite.Seeded and
; the fight replays frame for frame.
;
; 37 SATELLITES, NOT 12. The plate of 40:B1FA says 12; the spawn loop tests
; the NEXT entry for the sentinel and the table has 37 (MAME counts 37 alive).
; The parent is shielded while 12 or more are alive (40:B397): 26 must die
; before it can be hit.
;
; RENDERING: one grouped renderer (ObjID_bellmite_render) draws the parent
; then the satellites in priority order (the higher the arcade priority, the
; more in front) — the slither/bug pattern. Boxes live in RESIDENT memory
; (bellmite.boxes, in the stage 5 main): Collision_Do walks them with another
; page mounted.
;
; DEVIATIONS (V2-DEVIATION):
; - collision runs once per render (engine), not per arcade frame; the arcade
;   gate (40:B577, one frame in four per satellite) is kept on the DEATH
;   test, which is where it changes the timing;
; - palettes (0x1D, 0x69, 0x55) are not swapped: the flash shows the white
;   images when the arcade would paint the 0x55 palette;
; - music 0x19 is the bossmusic object's; SFX 0x57 is the engine's hit sound;
;   the death helper keeps its random draw (sync) but plays nothing, the
;   explosion objects carry the sound;
; - bg scroll 0x60 (40:B1F0): stage 5 has no background plane on the TO8;
; - palette_blackout_15_bg at 0x90 (40:B418): not ported yet.
;*******************************************************************************

; --- the parent: state values ------------------------------------------------
bm.P_NONE     equ 0
bm.P_INIT     equ 1                  ; 40:B1FA
bm.P_COMBAT   equ 2                  ; 40:B2DC
bm.P_RUN      equ 3                  ; 40:B473
bm.P_END      equ 4                  ; 40:B40A
bm.P_GONE     equ 5                  ; unloaded

; --- the satellites: state values --------------------------------------------
bm.S_FREE     equ 0
bm.S_ORBIT    equ 1                  ; 40:B521
bm.S_ATTACK   equ 2                  ; 40:B645
bm.S_POSTKILL equ 3                  ; 40:B6AE
bm.S_SCROLL   equ 4                  ; 40:B6C4

; --- a satellite record (page data) ------------------------------------------
S.st          equ 0                  ; state
S.x           equ 1                  ; 1,2 int   (arcade +4)
S.xf          equ 3                  ; frac      (arcade +3)
S.y           equ 4                  ; 4,5 int   (arcade +8)
S.yf          equ 6                  ; frac      (arcade +7)
S.ox          equ 7                  ; 7,8 orbit offset x (+0x20)
S.oy          equ 9                  ; 9,10 orbit offset y (+0x22)
S.dx          equ 11                 ; drift x, signed (+0x24)
S.dy          equ 12                 ; drift y, signed (+0x26)
S.vx          equ 13                 ; 13,14 attack velocity (+0x30)
S.vy          equ 15                 ; 15,16 (+0x32)
S.c36         equ 17                 ; post-kill countdown (+0x36)
S.c38         equ 18                 ; closest-check exclusion (+0x38)
S.seed        equ 19                 ; animation seed, low byte (+0x12)
S.fl          equ 20                 ; hit flash (+0x3D)
S.id          equ 21                 ; 1..37 (+0x18 & 0x3F)
S.pp          equ 22                 ; box potential seen last render
S.SZ          equ 24

bm.SLOTSZ     equ 5                  ; [on, x_pixel, y_pixel, routine(2)]
bm.NSLOT      equ bellmite.NSAT+1    ; slot 0 = the parent

bm.SAT_HP     equ 14                 ; 40:B59D damage >= 0x0E
bm.PARENT_HP  equ 40                 ; 40:B2AD HP_max 0x28
bm.SHIELD     equ 12                 ; 40:B397 parent shielded while >= 12

bellmite.boxes EXTERNAL              ; resident, bm.NSLOT * sizeof{AABB}

;*******************************************************************************
; THE MANAGER
;*******************************************************************************
bellmite.Object
        lda   routine,u
        asla
        ldx   #bm.Routines
        jmp   [a,x]
bm.Routines
        fdb   bellmite.Init
        fdb   bellmite.Live
        fdb   bellmite.Done

; -----------------------------------------------------------------------------
; Init — 40:B1D8 create_bellmite, the creation frame (frame 0)
; -----------------------------------------------------------------------------
bellmite.Init
        ; wave_frame_drop ALIASES anim_frame_duration: read it first
        ldb   wave_frame_drop,u
        stb   bm.pending
        ; the family's state, cleared: a checkpoint replays the stage without
        ; reloading this page
        ldx   #bm.Data
        ldd   #bm.DataEnd-bm.Data
@clr    clr   ,x+
        subd  #1
        bne   @clr
        lda   #bm.P_INIT                 ; b1db : first tick = init satellites
        sta   bm.pst
        ; b1e8 : halt the foreground autoscroll (restored at the end, 40:B44E)
        ldd   scroll_vel
        std   bm.savedVel
        ldd   #0
        std   scroll_vel
        ; the arcade global counter at this frame, and the random state: the
        ; arcade reseeded at the last multiple of 512 and nothing else draws
        ; in this stretch of the stage (MAME: (5,1,3) at the spawn)
        ldd   gfxlock.frame.gameCount
        subb  bm.pending
        sbca  #0
        std   bm.gc
        ldd   #$0501
        std   bm.rng
        lda   #3
        sta   bm.rng+2
        ; the grouped renderer
        jsr   LoadObject_x
        beq   >
        lda   #ObjID_bellmite_render
        sta   id,x
!       inc   routine,u
bellmite.Seeded                      ; test hook: bm.gc / bm.rng are final here
        ldb   bm.pending
        bra   bm.Advance

; -----------------------------------------------------------------------------
; Live — run the arcade frames elapsed since the last render, then publish
; -----------------------------------------------------------------------------
bellmite.Live
        jsr   bm.HitWatch
        ldb   gfxlock.frameDrop.count
bm.Advance                           ; B = arcade frames to run
        pshs  u
        stb   bm.nfr
        beq   @pub
@frame  jsr   bm.Frame
        dec   bm.nfr
        bne   @frame
@pub    jsr   bm.Publish
        puls  u
bellmite.Sample                      ; test hook: one render's state is final
        ; the family is over when the parent is gone, every satellite is
        ; free and the death helper has run out
        lda   bm.pst
        cmpa  #bm.P_GONE
        bne   @rts
        lda   bm.helper
        bne   @rts
        ldx   #bm.Sats
        ldb   #bellmite.NSAT
@l      lda   S.st,x
        bne   @rts
        leax  S.SZ,x
        decb
        bne   @l
        lda   #2
        sta   routine,u
@rts    rts

bellmite.Done
        jmp   UnloadObject_u             ; never displayed itself

;*******************************************************************************
; ONE ARCADE FRAME
;*******************************************************************************
bm.Frame
        ; 40:0219 ++global_counter, 40:021D reseed every 512 frames
        ldd   bm.gc
        addd  #1
        std   bm.gc
        bitb  #$FF
        bne   >
        bita  #$01
        bne   >
        ldd   #$0501                     ; 40:EDD9 init_random_seed
        std   bm.rng
        lda   #3
        sta   bm.rng+2
!
bellmite.Tick                        ; test hook: frame bm.gc, before any actor
        ; the parent (priority 0x7D00 runs first)
        lda   bm.pst
        asla
        ldx   #bm.ParentTicks
        jsr   [a,x]
        ; the satellites, in priority order 0x7D01..0x7D25
        ldy   #bm.Sats
@sat    lda   S.st,y
        beq   @next
        asla
        ldx   #bm.SatTicks
        jsr   [a,x]
@next   leay  S.SZ,y
        cmpy  #bm.SatsEnd
        blo   @sat
        ; the death helper (priority 0xC000)
        lda   bm.helper
        beq   >
        jsr   bm.Helper
!       rts

bm.ParentTicks
        fdb   bm.Nop
        fdb   bm.ParentInit
        fdb   bm.ParentCombat
        fdb   bm.ParentRun
        fdb   bm.ParentEnd
        fdb   bm.Nop
bm.SatTicks
        fdb   bm.Nop
        fdb   bm.SatOrbit
        fdb   bm.SatAttack
        fdb   bm.SatPostKill
        fdb   bm.SatScrollOut
bm.Nop  rts

;*******************************************************************************
; THE PARENT
;*******************************************************************************

; -----------------------------------------------------------------------------
; 40:B1FA tick_bellmite_init_satellites
; -----------------------------------------------------------------------------
bm.ParentInit
        clr   bm.n38                     ; b1fa
        ldd   #$0260                     ; b1ff parent.X
        std   bm.px
        ldd   #$0060                     ; b204 parent.Y
        std   bm.py
        clr   bm.pxf
        clr   bm.pyf
        ldx   #bellmite.SatOffsets
        ldy   #bm.Sats
        lda   #1
        sta   bm.wN
@spawn  lda   #bm.S_ORBIT
        sta   S.st,y
        ldd   ,x                         ; b227 x_offset
        std   S.ox,y
        addd  bm.px                      ; b22d satellite.X = parent.X + offset
        std   S.x,y
        ldd   2,x
        std   S.oy,y
        addd  bm.py
        std   S.y,y
        clr   S.xf,y
        clr   S.yf,y
        clr   S.dx,y                     ; b240
        clr   S.dy,y
        clr   S.c38,y                    ; b255
        clr   S.fl,y                     ; b271
        lda   bm.wN
        sta   S.id,y
        pshs  x
        jsr   bm.Rand                    ; b25a [+0x12] = random_ax
        stb   S.seed,y
        ; the box joins the engine list, cleaned first (manager-owned boxes)
        lda   bm.wN
        jsr   bm.BoxPtrA
        lda   #bm.SAT_HP
        sta   S.pp,y
        jsr   bm.BoxInsert
        puls  x
        inc   bm.n38                     ; b221
        leax  4,x
        leay  S.SZ,y
        inc   bm.wN
        lda   bm.wN
        cmpa  #bellmite.NSAT+1
        blo   @spawn
        ; b285 parent init
        ldd   #0
        std   bm.pvx                     ; b29b
        ldd   #$0200
        std   bm.pvy                     ; b29e +2.0 px/f upward
        ldd   #$0040
        std   bm.c24                     ; b2a3
        ldd   #$0C80
        std   bm.c26                     ; b2a8 lifetime
        clr   bm.f30                     ; b2b5..b2be
        clr   bm.f32
        clr   bm.f34
        ldd   #0
        std   bm.d36
        clr   bm.pfl
        ldd   #bellmite.PERIOD           ; b2c9 phase period (difficulty 0)
        std   bm.c10
        ldd   #$0100
        std   bm.c12                     ; b2d1
        lda   #bm.P_COMBAT               ; b2d6
        sta   bm.pst
bellmite.Spawned                     ; test hook: the records exist. The arcade
        rts                          ; does NOT clear the fractions (+3, +7) of
                                     ; a recycled record: they are leftovers of
                                     ; its previous occupant, an input of the
                                     ; fight like the seed. 0 here; the bench
                                     ; writes the arcade's.

; -----------------------------------------------------------------------------
; 40:B2DC tick_bellmite_combat
; -----------------------------------------------------------------------------
bm.ParentCombat
        ldx   #bm.px                     ; b2dc move_x/y_pos_8_8
        ldd   bm.pvx
        jsr   bm.Move
        ldx   #bm.py
        ldd   bm.pvy
        jsr   bm.Move
        lda   bm.pfl                     ; b2eb paint: hit flash countdown
        beq   >
        dec   bm.pfl
!       ldd   bm.c24                     ; b310
        subd  #1
        std   bm.c24
        bne   @nonav
@reroll jsr   bm.Rand                    ; b315 NAVIGATION RE-ROLL
        andb  #$1F
        lslb
        lslb
        ldx   #bellmite.Targets
        abx
        ldd   ,x                         ; b321 target.X
        subd  bm.px
        std   bm.wDX
        bpl   >
        coma
        comb
        addd  #1                         ; b332 NEG
!       std   bm.wT
        ldd   2,x                        ; b326 target.Y
        subd  bm.py
        std   bm.wDY
        bpl   >
        coma
        comb
        addd  #1
!       addd  bm.wT
        cmpd  #$0058                     ; b341 minimum distance
        blo   @reroll                    ; unsigned, as JC
        ldd   bm.wDX                     ; b346 v = d*2 - (d sar 1)
        jsr   bm.Times15
        std   bm.pvx
        ldd   bm.wDY
        jsr   bm.Times15
        std   bm.pvy
        ldd   #$00CC                     ; b362
        std   bm.c24
@nonav  lda   bm.f30                     ; b367 consume the signal
        beq   >
        clr   bm.f30
        lda   bm.f32
        beq   >
        sta   bm.f34                     ; b37a closest satellite -> attack
!       ldd   bm.c12                     ; b37d phase reload
        subd  #1
        std   bm.c12
        bne   >
        ldd   bm.c10
        std   bm.c12
        lda   #1
        sta   bm.f30                     ; b388 broadcast
        clr   bm.f32
        ldd   #$FFFF
        std   bm.d36                     ; b392
!       lda   bm.n38                     ; b397 shielded while >= 12
        cmpa  #bm.SHIELD
        bhs   @life
        ; the parent can be hit: its box joins the list the first time
        lda   bm.pbox
        bne   >
        inc   bm.pbox
        clra
        jsr   bm.BoxPtrA
        lda   #bm.PARENT_HP
        sta   bm.ppp
        jsr   bm.BoxInsert
!       clra                             ; b3ae damage >= HP_max ?
        jsr   bm.BoxPtrA
        lda   AABB.p,x
        lbeq  bm.ParentDestroy
@life   ldd   bm.c26                     ; b3c0 lifetime
        subd  #1
        std   bm.c26
        bne   >
        lda   #bm.P_RUN                  ; b3c6 install run_bellmite
        sta   bm.pst
!       rts

; 40:B3CC destroy path
bm.ParentDestroy
        jsr   bm.ParentBoxOut            ; b3cc clear missile homing
        ldb   #bellmite_scoreIdx         ; b3d2 score 0x8710
        pshs  y
        jsr   AwardScore
        puls  y
        lda   #$40                       ; b3e3 death helper lifetime
        sta   bm.helper
        jsr   LoadObject_x               ; b3ee big explosion at self pos
        beq   bm.ParentEndArm
        _ldd  ObjID_explosion,explosion.subtype.big.brown+explosion.sfx.big
        std   id,x
        ldd   bm.px
        ldy   bm.py
        jsr   bm.ToScreen                ; A = x, B = y (screen, 0-based)
        pshs  b
        tfr   a,b
        clra
        addd  glb_camera_x_pos
        std   x_pos,x
        puls  b
        clra
        std   y_pos,x
bm.ParentEndArm
        ldd   #$0100                     ; b3ff [+0x3e] = 0x100
        std   bm.c3e
        lda   #bm.P_END                  ; b404 install b40a
        sta   bm.pst
        rts

; -----------------------------------------------------------------------------
; 40:B473 run_bellmite — the timeout scroll-out
; -----------------------------------------------------------------------------
bm.ParentRun
        ldx   #bm.px                     ; b47a +4.0 px/f
        ldd   #$0400
        jsr   bm.Move
        ldd   bm.px                      ; b486
        cmpd  #$02E0
        blo   >
        bra   bm.ParentEndArm            ; b48d
!       rts

; -----------------------------------------------------------------------------
; 40:B40A end_boss_after_stage5_boss — 256 frames, invisible
; -----------------------------------------------------------------------------
bm.ParentEnd
        ldd   bm.c3e
        cmpd  #$0080                     ; b41e : SFX 0x1A/0x1C and
        bne   >                          ;        end_level_sequence_flag
        lda   #1
        sta   globals.bossDefeated
!       ldd   bm.c3e                     ; b434
        subd  #1
        std   bm.c3e
        bne   >
        lda   #bm.P_GONE                 ; b43a unload
        sta   bm.pst
        ldd   bm.savedVel                ; b44e restart the autoscroll
        std   scroll_vel
!       rts

; -----------------------------------------------------------------------------
; 40:B491 tick_bellmite_death_helper — its draw keeps the generator in step
; -----------------------------------------------------------------------------
bm.Helper
        lda   bm.gc+1                    ; b498 every 4 frames
        bita  #3
        bne   >
        jsr   bm.Rand                    ; b49f SFX 0x52 + (random & 1)
!       dec   bm.helper                  ; b4ab
        rts

;*******************************************************************************
; THE SATELLITES — Y = the record, all along
;*******************************************************************************

; -----------------------------------------------------------------------------
; 40:B521 tick_bellmite_satellite_orbit
; -----------------------------------------------------------------------------
bm.SatOrbit
        ; b521 desired = parent + orbit offset + drift, even, then +-2 px
        ldb   S.dx,y
        sex
        addd  S.ox,y
        addd  bm.px
        andb  #$FE                       ; b52d
        subd  S.x,y
        beq   @y
        bmi   @left
        ldd   S.x,y                      ; b53e
        addd  #2
        bra   @sx
@left   ldd   S.x,y                      ; b537
        subd  #2
@sx     std   S.x,y
@y      ldb   S.dy,y
        sex
        addd  S.oy,y
        addd  bm.py
        andb  #$FE
        subd  S.y,y
        beq   @paint
        bmi   @down
        ldd   S.y,y
        addd  #2
        bra   @sy
@down   ldd   S.y,y
        subd  #2
@sy     std   S.y,y
@paint  jsr   bm.SatPaint                ; b560
        jsr   bm.SatDrift                ; b563
        lda   bm.f34                     ; b569 parent.[+0x34] == own id ?
        cmpa  S.id,y
        lbeq  bm.SatAttackInit           ; b571
        jsr   bm.SatClosest              ; b574
        jsr   bm.SatGate                 ; b577 one frame in four
        bne   >
        jsr   bm.SatDead                 ; b59d damage >= 0x0E
        lbeq  bm.SatDestroy
!       lda   bm.pst                     ; b5ab parent in end_stage ?
        cmpa  #bm.P_END
        beq   bm.SatPostKillInit
        cmpa  #bm.P_RUN                  ; b5b4 parent in scroll-out ?
        beq   bm.SatScrollOutInit
        rts

; 40:B5BB staggered countdown: own index + 4
bm.SatPostKillInit
        lda   S.id,y
        anda  #$3F
        adda  #4
        sta   S.c36,y
        lda   #bm.S_POSTKILL
        sta   S.st,y
        rts

; 40:B5CD
bm.SatScrollOutInit
        lda   #bm.S_SCROLL
        sta   S.st,y
        rts

; -----------------------------------------------------------------------------
; 40:B60F attack mode init — then 40:B645 tick
; -----------------------------------------------------------------------------
bm.SatAttackInit
        lda   #$C0                       ; b60f 192 frames of exclusion
        sta   S.c38,y
        lda   #bm.S_ATTACK               ; b614
        sta   S.st,y
        clr   bm.f34                     ; b619
        jsr   bm.Direction               ; b621 B = code 0..$3C
        ldx   #bellmite.AttackVel        ; b62e difficulty 0
        abx
        ldd   ,x
        std   S.vx,y
        ldd   2,x
        std   S.vy,y
        rts

bm.SatAttack
        leax  S.x,y                      ; b64c
        ldd   S.vx,y
        jsr   bm.Move
        leax  S.y,y
        ldd   S.vy,y
        jsr   bm.Move
        jsr   bm.SatPaint                ; b658
        jsr   bm.SatDead                 ; b66c (no gate in this tick)
        lbeq  bm.SatDestroy
        lda   bm.pst                     ; b682 parent in scroll-out ?
        cmpa  #bm.P_RUN
        lbeq  bm.SatUnload               ; b688 silent
        ldd   S.x,y                      ; b68b window X [0x150, 0x2B0)
        cmpd  #$0150
        blo   @orbit
        cmpd  #$02B0
        bhs   @orbit
        ldd   S.y,y                      ; b699 window Y [0xA0, 0x178)
        cmpd  #$00A0
        blo   @orbit
        cmpd  #$0178
        bhs   @orbit
        rts
@orbit  lda   #bm.S_ORBIT                ; b6a8 back to formation
        sta   S.st,y
        rts

; -----------------------------------------------------------------------------
; 40:B6AE tick_bellmite_satellite_post_kill
; -----------------------------------------------------------------------------
bm.SatPostKill
        jsr   bm.SatPaint                ; b6ae
        dec   S.c36,y                    ; b6bb
        lbeq  bm.SatDestroy              ; b6c0
        rts

; -----------------------------------------------------------------------------
; 40:B6C4 tick_bellmite_satellite_post_scroll_out — the offset * 24 as 8.8
; -----------------------------------------------------------------------------
bm.SatScrollOut
        ldd   S.ox,y                     ; b6ce
        jsr   bm.Times24
        leax  S.x,y
        jsr   bm.Move
        ldd   S.oy,y
        jsr   bm.Times24
        leax  S.y,y
        jsr   bm.Move
        jsr   bm.SatPaint                ; b6f2
        jsr   bm.SatDead                 ; b706 (no gate)
        lbeq  bm.SatDestroy
        ; b710 is_visible_range: X in [300, 724), Y in [124, 404)
        ldd   S.x,y
        subd  #300
        blo   bm.SatUnload
        cmpd  #424
        bhs   bm.SatUnload
        ldd   S.y,y
        subd  #124
        blo   bm.SatUnload
        cmpd  #280
        bhs   bm.SatUnload
        rts

; -----------------------------------------------------------------------------
; 40:B5D3 destroy with score / 40:B5FC silent unload
; -----------------------------------------------------------------------------
bm.SatDestroy
        dec   bm.n38                     ; b5d6
        pshs  y
        ldb   #bellmite_satellite_scoreIdx     ; b5e1 score 0x86F0
        jsr   AwardScore
        jsr   LoadObject_x               ; b5f6 explosion_small_x2
        puls  y
        beq   bm.SatUnload
        _ldd  ObjID_explosion,explosion.subtype.smallx2+explosion.sfx.turret
        std   id,x
        pshs  y
        ldd   S.x,y
        ldy   S.y,y
        jsr   bm.ToScreen                ; X kept
        puls  y
        pshs  b
        tfr   a,b
        clra
        addd  glb_camera_x_pos
        std   x_pos,x
        puls  b
        clra
        std   y_pos,x
bm.SatUnload
        clr   S.st,y
        lda   S.id,y
        jsr   bm.BoxPtrA
        jmp   bm.BoxRemove

; -----------------------------------------------------------------------------
; 40:B719 paint — only the flash countdown lives in the frame; the picture is
; published once per render (bm.Publish)
; -----------------------------------------------------------------------------
bm.SatPaint
        lda   S.fl,y
        beq   >
        dec   S.fl,y
!       rts

; -----------------------------------------------------------------------------
; 40:B75A closest check
; -----------------------------------------------------------------------------
bm.SatClosest
        lda   S.c38,y                    ; b75a exclusion window
        beq   >
        dec   S.c38,y
        rts
!       lda   bm.f30                     ; b76a parent signal
        beq   @rts
        ldd   bm.plx                     ; b771 |player.x - x|
        subd  S.x,y
        bpl   >
        coma
        comb
        addd  #1
!       std   bm.wT
        ldd   bm.ply                     ; b77b |player.y - y|
        subd  S.y,y
        bpl   >
        coma
        comb
        addd  #1
!       addd  bm.wT                      ; b786
        cmpd  bm.d36                     ; b788 unsigned
        bhs   @rts
        std   bm.d36
        lda   S.id,y                     ; b790
        sta   bm.f32
@rts    rts

; -----------------------------------------------------------------------------
; 40:B797 drift correction, every 8 frames
; -----------------------------------------------------------------------------
bm.SatDrift
        lda   bm.gc+1                    ; b797
        bita  #7
        bne   @rts
        leax  S.dx,y
        bsr   @one
        leax  S.dy,y
@one    jsr   bm.Rand                    ; b79e
        lsrb                             ; b7a1 (random >> 1) & 3, - 2
        andb  #3
        subb  #2
        bne   >
        ldb   #2                         ; b7ab 0 -> +2
!       addb  ,x
        bpl   @pos                       ; b7b1 sign of the result
        cmpb  #-4                        ; b7b3 clamp at -4
        bge   @st
        ldb   #-4
        bra   @st
@pos    cmpb  #4                         ; b7c1 clamp at +4
        blo   @st
        ldb   #4
@st     stb   ,x
@rts    rts

; Z=1 when the arcade gate opens: (counter & 3) == (own priority & 3)
bm.SatGate
        lda   bm.gc+1
        eora  S.id,y
        anda  #3
        rts

; Z=1 when the satellite has taken its 14 points (box potential at 0)
bm.SatDead
        lda   S.id,y
        jsr   bm.BoxPtrA
        lda   AABB.p,x
        rts

;*******************************************************************************
; THE TOOLS
;*******************************************************************************

; 40:EDE9 random_ax — out: B = AL (the new a), A = AH (the old c)
bm.Rand
        ldd   bm.rng+1                   ; A = b, B = c
        pshs  b
        sta   bm.rng+2                   ; c := b
        adda  ,s                         ; new a = b + c
        ldb   bm.rng
        stb   bm.rng+1                   ; b := a
        sta   bm.rng                     ; a := new a
        tfr   a,b
        puls  a,pc

; move_x/y_pos_8_8: X = the position (int:2, frac:1), D = signed 8.8
bm.Move
        pshs  a
        addb  2,x                        ; the fraction
        stb   2,x
        puls  b                          ; the integer part of the step
        sex
        adcb  1,x
        adca  ,x
        std   ,x
        rts

; D = D*2 - (D sar 1)  (40:B34C)
bm.Times15
        std   bm.wT
        asra
        rorb
        std   bm.wT2
        ldd   bm.wT
        aslb
        rola
        subd  bm.wT2
        rts

; D = D*24 (40:B6CE: *8, then *16 + *8)
bm.Times24
        aslb
        rola
        aslb
        rola
        aslb
        rola
        std   bm.wT
        aslb
        rola
        addd  bm.wT
        rts

; 40:1D89 set_direction_to, from satellite Y to the player — B = code
bm.Direction
        ldd   S.y,y                      ; 1d95 from.y + 8 - to.y : CY = above
        addd  #8
        subd  bm.ply
        blo   @above
        ldd   S.y,y                      ; 1d9e from.y - 8 - to.y : NC = below
        subd  #8
        subd  bm.ply
        bhs   @below
        ldd   S.x,y                      ; 1da7 same row
        subd  bm.plx
        bhs   >
        ldb   #$10                       ; E
        rts
!       ldb   #$30                       ; W
        rts
@above  ldd   S.x,y                      ; 1db5
        addd  #8
        subd  bm.plx
        blo   @ne
        ldd   S.x,y
        subd  #8
        subd  bm.plx
        bhs   @nw
        clrb                             ; N
        rts
@below  ldd   S.x,y                      ; 1dca
        addd  #8
        subd  bm.plx
        blo   @se
        ldd   S.x,y
        subd  #8
        subd  bm.plx
        bhs   @sw
        ldb   #$20                       ; S
        rts
@ne     ldd   bm.plx                     ; 1de0 |dx| = to.x - from.x
        subd  S.x,y
        std   bm.wT
        ldd   bm.ply                     ;      |dy| = to.y - from.y
        subd  S.y,y
        ldx   #bm.DirNE
        bra   @quad
@nw     ldd   S.x,y                      ; 1e03 |dx| = from.x - to.x
        subd  bm.plx
        std   bm.wT
        ldd   bm.ply
        subd  S.y,y
        ldx   #bm.DirNW
        bra   @quad
@se     ldd   bm.plx                     ; 1e26
        subd  S.x,y
        std   bm.wT
        ldd   S.y,y                      ;      |dy| = from.y - to.y
        subd  bm.ply
        ldx   #bm.DirSE
        bra   @quad
@sw     ldd   S.x,y                      ; 1e49
        subd  bm.plx
        std   bm.wT
        ldd   S.y,y
        subd  bm.ply
        ldx   #bm.DirSW
@quad   std   bm.wT2                     ; AX = |dx| - |dy| + 0x20
        ldd   bm.wT
        subd  bm.wT2
        addd  #$0020
        cmpd  #$0040                     ; unsigned : the diagonal band
        blo   @diag
        tsta                             ; bit 15 : bent toward the vertical
        bmi   @vert
        ldb   2,x                        ; horizontal
        rts
@diag   ldb   1,x
        rts
@vert   ldb   ,x
        rts
;                vertical, diagonal, horizontal
bm.DirNE fcb   $04,$08,$0C
bm.DirNW fcb   $3C,$38,$34
bm.DirSE fcb   $1C,$18,$14
bm.DirSW fcb   $24,$28,$2C

; x_screen = 8 + ((x - 320) * 3) >> 3 ; y_screen = 297 - (y * 3) >> 2
; in: D = x, Y = y (arcade, 16 bits) ; out: A = x, B = y (screen, 0-based,
; clamped to 0..255 — the callers cull)
bm.ToScreen
        subd  #320
        std   bm.wT
        aslb
        rola
        addd  bm.wT                      ; *3
        asra
        rorb
        asra
        rorb
        asra
        rorb                             ; sar 3
        addd  #8
        jsr   bm.Clamp
        stb   bm.wX
        tfr   y,d
        std   bm.wT
        aslb
        rola
        addd  bm.wT
        asra
        rorb
        asra
        rorb                             ; (y*3) sar 2
        std   bm.wT
        ldd   #297
        subd  bm.wT
        jsr   bm.Clamp
        lda   bm.wX
        rts

; D -> B in 0..255 (negative -> 0, above 255 -> 255)
bm.Clamp
        tsta
        beq   @rts
        bmi   @lo
        ldb   #255
        rts
@lo     clrb
@rts    rts

; X = the box of slot A (0 = parent, n = satellite n)
bm.BoxPtrA
        ldb   #sizeof{AABB}
        mul
        addd  #bellmite.boxes
        tfr   d,x
        rts

; Insert the box X, cleaned, at the potential in A (manager-owned boxes:
; prev and next MUST be blank, see the bug manager)
bm.BoxInsert
        pshs  a,u,y
        ldb   #sizeof{AABB}
!       clr   ,x+
        decb
        bne   <
        leax  -sizeof{AABB},x
        lda   #bellmite_hitbox_x
        sta   AABB.rx,x
        lda   #bellmite_hitbox_y
        sta   AABB.ry,x
        lda   #220                       ; parked off screen until published
        sta   AABB.cx,x
        sta   AABB.cy,x
        lda   ,s
        sta   AABB.p,x
        ldy   #AABB_list_ennemy
        jsr   Collision_AddAABB
        puls  a,u,y,pc

bm.BoxRemove
        pshs  u,y
        ldy   #AABB_list_ennemy
        sty   Collision_Remove_1
        sty   Collision_Remove_3
        leay  2,y
        sty   Collision_Remove_2
        jsr   Collision_RemoveAABB
        puls  u,y,pc

bm.ParentBoxOut
        lda   bm.pbox
        beq   >
        clr   bm.pbox
        clra
        jsr   bm.BoxPtrA
        jmp   bm.BoxRemove
!       rts

; -----------------------------------------------------------------------------
; HitWatch — once per render, before the frames: a potential that dropped is
; a hit (the arcade arms +0x3D = 8 on the hit frame); the player position, in
; arcade units, for the frames to come
; -----------------------------------------------------------------------------
bm.HitWatch
        lda   bm.pbox
        beq   @sats
        clra
        jsr   bm.BoxPtrA
        lda   AABB.p,x
        cmpa  bm.ppp
        bhs   @sats
        sta   bm.ppp
        lda   #8
        sta   bm.pfl
@sats   ldy   #bm.Sats
@l      lda   S.st,y
        beq   @n
        lda   S.id,y
        jsr   bm.BoxPtrA
        lda   AABB.p,x
        cmpa  S.pp,y
        bhs   @n
        sta   S.pp,y
        lda   #8
        sta   S.fl,y
@n      leay  S.SZ,y
        cmpy  #bm.SatsEnd
        blo   @l
        ; the player, back in arcade units: v = xs - 8 (0-based screen),
        ; x = 320 + v*8/3 = 320 + 2v + (v*171 >> 8) ; w = 297 - ys,
        ; y = w*4/3 = w + (w*171 >> 9) — both exact over their range
        ; (checked for v in 0..255, w in 0..299). Exact images when the ship
        ; sits where x-320 is a multiple of 8 and y a multiple of 4.
        ldd   player1+x_pos
        subd  glb_camera_x_pos
        subd  #8
        bpl   >
        ldd   #0
!       tsta
        beq   >
        ldb   #255
!       stb   bm.wX
        lda   #171
        mul
        tfr   a,b                        ; v*171 >> 8
        clra
        std   bm.wT
        ldb   bm.wX
        clra
        aslb
        rola                             ; 2v
        addd  bm.wT
        addd  #320
        std   bm.plx
        ldb   player1+y_pos+1
        clra
        std   bm.wT
        ldd   #297
        subd  bm.wT                      ; w
        std   bm.wT
        lda   #171
        mul                              ; wl*171
        tst   bm.wT
        beq   >
        addd  #171*256                   ; + wh*171*256 (w <= 297 : no carry)
!       lsra                             ; >> 9 = A >> 1
        tfr   a,b
        clra
        addd  bm.wT
        std   bm.ply
        rts

;*******************************************************************************
; PUBLICATION — once per render: slots for the renderer, boxes for the engine
;*******************************************************************************
bm.Publish
        ; the parent: painted in combat and in the scroll-out
        ldy   #bm.Slots
        clr   ,y
        lda   bm.pst
        cmpa  #bm.P_COMBAT
        beq   >
        cmpa  #bm.P_RUN
        bne   @sats
!       ldd   bm.px
        pshs  y
        ldy   bm.py
        jsr   bm.ToScreen
        puls  y
        std   bm.wXY
        ldx   #set_bellmite_body_0
        lda   bm.pfl                     ; b2f4 flash on odd frames
        beq   >
        lda   bm.gc+1
        bita  #1
        beq   >
        ldx   #set_bellmite_bodyhit_0
!       ldd   bm.wXY
        jsr   bm.SlotPublish
        lda   bm.pbox
        beq   @sats
        clra
        jsr   bm.BoxPtrA
        ldd   bm.wXY
        jsr   bm.BoxPlace
@sats   ldy   #bm.Sats
        ldu   #bm.Slots+bm.SLOTSZ
@s      lda   S.st,y
        bne   >
        clr   ,u
        bra   @n
!       pshs  y
        ldd   S.x,y
        ldy   S.y,y
        jsr   bm.ToScreen
        puls  y
        std   bm.wXY
        ; b719 frame = ((counter + seed) & 0x18) >> 3, flash on odd sums
        lda   bm.gc+1
        adda  S.seed,y
        sta   bm.wT
        anda  #$18
        lsra
        lsra                             ; *2 (fdb table)
        ldx   #bm.SatSets
        tst   S.fl,y
        beq   >
        ldb   bm.wT
        bitb  #1
        beq   >
        ldx   #bm.SatHitSets
!       ldx   a,x
        pshs  y
        tfr   u,y
        ldd   bm.wXY
        jsr   bm.SlotPublish
        puls  y
        lda   S.id,y
        jsr   bm.BoxPtrA
        ldd   bm.wXY
        jsr   bm.BoxPlace
@n      leay  S.SZ,y
        leau  bm.SLOTSZ,u
        cmpy  #bm.SatsEnd
        blo   @s
        rts

; A = x, B = y (screen 0-based), X = imageset, Y = slot
bm.SlotPublish
        adda  #screen_left
        addb  #screen_top
        pshs  a,b
        _sprite.cull bm.SlotPublish.off
        lda   ,s
        suba  imgset.center,x
        sta   1,y
        lda   1,s
        sta   2,y
        ldd   14,x
        std   3,y
        lda   #1
        sta   ,y
        puls  a,b,pc
bm.SlotPublish.off
        clr   ,y
        puls  a,b,pc

; the box X centred on (A, B), screen 0-based ; parked off screen when the
; centre clamps (an off-screen satellite must not meet a player shot)
bm.BoxPlace
        cmpa  #250
        bhs   @park
        cmpb  #250
        bhs   @park
        sta   AABB.cx,x
        stb   AABB.cy,x
        rts
@park   lda   #220
        sta   AABB.cx,x
        sta   AABB.cy,x
        rts

bm.SatSets
        fdb   set_bellmite_sat_0,set_bellmite_sat_1
        fdb   set_bellmite_sat_2,set_bellmite_sat_3
bm.SatHitSets
        fdb   set_bellmite_sathit_0,set_bellmite_sathit_1
        fdb   set_bellmite_sathit_2,set_bellmite_sathit_3

;*******************************************************************************
; THE GROUPED RENDERER — the slither pattern: a fake imageset whose routine
; draws every lit slot, parent first (the lowest arcade priority)
;*******************************************************************************
bm.FakeImg
        fcb   bm.FakeSub-bm.FakeImg,bm.FakeSub-bm.FakeImg
        fcb   bm.FakeSub-bm.FakeImg,bm.FakeSub-bm.FakeImg
        fcb   8,8,0
bm.FakeSub
        fcb   0
        fcb   bm.FakeMf-bm.FakeSub
        fcb   0
        fcb   bm.FakeMf-bm.FakeSub
        fcb   0,0
bm.FakeMf
        fcb   0                          ; page, patched by the renderer
        fdb   bm.DrawAll

bellmite.Render
        lda   routine,u
        bne   @live
        _GetCartPageA
        ldb   id,u
        ldx   #Img_Page_Index
        sta   b,x                        ; the engine will mount OUR page
        sta   bm.FakeMf
        ldd   #bm.FakeImg
        std   image_set,u
        clr   render_flags,u
        lda   #120                       ; proxy parked mid screen: never culled
        sta   x_pixel,u
        lda   #135
        sta   y_pixel,u
        ldb   #5                         ; behind the ship (3)
        stb   priority,u
        inc   routine,u
        jmp   DisplaySprite
@live   lda   bm.pst                     ; the family is over: so is its picture
        cmpa  #bm.P_GONE
        bne   >
        lda   bm.helper
        bne   >
        ldx   #bm.Slots
        ldb   #bm.NSLOT
@l      lda   ,x
        bne   >
        leax  bm.SLOTSZ,x
        decb
        bne   @l
        jmp   DeleteObject
!       jmp   DisplaySprite

bm.DrawAll
        ldx   #bm.Slots
        stx   bm.dp
@loop   ldx   bm.dp
        lda   ,x
        beq   @next
        ldd   1,x                        ; A = x_pixel, B = y_pixel
        jsr   DRS_XYToAddress
        ldx   bm.dp
        ldx   3,x
        ldu   <glb_screen_location_2
        jsr   ,x                         ; the routine consumes U
@next   ldx   bm.dp
        leax  bm.SLOTSZ,x
        stx   bm.dp
        cmpx  #bm.SlotsEnd
        blo   @loop
        rts

;*******************************************************************************
; THE DATA (page) — cleared at every Init
;*******************************************************************************
bm.dp       fdb   0
bm.nfr      fcb   0
bm.pending  fcb   0
bm.savedVel fdb   0

bm.Data
bm.gc       fdb   0                      ; the arcade global counter (0x2EB6)
bm.rng      fcb   0,0,0                  ; random_ax state a, b, c (0x2F28)
bm.pst      fcb   0                      ; parent state
bm.px       fdb   0                      ; parent X int (+4)
bm.pxf      fcb   0                      ;          frac (+3)
bm.py       fdb   0                      ; parent Y int (+8)
bm.pyf      fcb   0                      ;          frac (+7)
bm.pvx      fdb   0                      ; +0x20
bm.pvy      fdb   0                      ; +0x22
bm.c24      fdb   0                      ; navigation phase
bm.c26      fdb   0                      ; lifetime
bm.c12      fdb   0                      ; phase reload countdown
bm.c10      fdb   0                      ; phase period
bm.f30      fcb   0                      ; the broadcast (0xFFFF -> 1)
bm.f32      fcb   0                      ; closest satellite id
bm.f34      fcb   0                      ; the chosen one
bm.d36      fdb   0                      ; best distance
bm.n38      fcb   0                      ; satellites alive
bm.c3e      fdb   0                      ; end countdown
bm.pfl      fcb   0                      ; parent hit flash
bm.pbox     fcb   0                      ; parent box in the list
bm.ppp      fcb   0                      ; parent potential seen last render
bm.helper   fcb   0                      ; death helper lifetime
bm.plx      fdb   0                      ; the player, arcade units
bm.ply      fdb   0
bm.wN       fcb   0
bm.wT       fdb   0
bm.wT2      fdb   0
bm.wDX      fdb   0
bm.wDY      fdb   0
bm.wX       fcb   0
bm.wXY      fdb   0
bm.Sats     fill  0,bellmite.NSAT*S.SZ
bm.SatsEnd
bm.Slots    fill  0,bm.NSLOT*bm.SLOTSZ
bm.SlotsEnd
bm.DataEnd

        INCLUDE "src/enemies/bellmite/tables.asm"
