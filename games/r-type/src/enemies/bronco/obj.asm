;*******************************************************************************
; bronco — the stage 7 boss, ported 1:1 from the arcade
;
; PORTING SHEET (source: Ghidra `maincpu`, subsystem bronco)
; ------------------------------------------------------------
;   40:B7FB create_bronco ................. bronco.Init (frame 0)
;   40:B805 tick_bronco_init_subentities .. bro.MInit
;   40:B8D5 tick_bronco_lifecycle_manager . bro.MLife
;   40:B950 tick_bronco_pre_end_countdown . bro.MPre
;   40:B997 / B9FD run_bronco (segments) .. bro.Seg
;   40:BA4E segment destroy ............... bro.SegDie
;   40:BAA7 helper_state_dispatcher ....... bro.Disp
;   40:BB40..BC63 the state installers .... bro.Install
;   40:BC95 tick_bronco_segment_state ..... bro.Debris (the falling junk)
;   40:BD32 helper_periodic_spawner ....... bro.Spawn
;   40:BDB2 helper_chaser ................. bro.Chaser
;   40:BE43 helper_bullet_spawner ......... bro.Shoot (the engine's foe fire)
;   40:BE81 helper_main_attack ............ bro.Main
;   40:BFE8 helper_main_attack_fade ....... bro.Fade
;   40:C03F / C069 main attack sub-child .. bro.Sub
;   40:F5C1 move_by_script ................ bro.MoveScript
;   40:1D89 set_direction_to .............. bro.Dir
;   40:5811 create_bonus (the rare junk) .. bro.BonusDrop
;
; THE PORT RUNS IN ARCADE SPACE and ONE ARCADE FRAME AT A TIME, in the list
; order of the arcade (priorities 0x0F00 junk, 0x1000 sub-children, 0x2000
; chasers, 0xA100 segments, 0xA110 dispatcher, 0xA120 spawner, 0xA130 main
; attack, 0xA200 manager). A record born in a frame ticks from the next one,
; as on the arcade (its creator always sits after it in the list). Positions
; are the arcade's 16.8, speeds its 8.8, tables a copy of the ROM
; (tables.asm, tools/gen_bronco.py). Only the publication converts.
;
; RANDOM NUMBERS: the stream is shared with the stage's wave (the pata-patas,
; the rockets), so every draw goes through bro.Draw and the bench writes the
; arcade's value at bronco.Drawn (tools/fidelity/, the Compiler's method).
; In game bro.Rand is a private copy of random_ax.
;
; THE PICTURES are arcade CELLS, a cell shared by several poses compiled
; once: the main attacker's head (its four arms move), the chaser's head
; (its nine legs turn). The small junk IS the bug (two frames of lib.bug,
; loaded in stage 7). Images live on several pages: the publication fills
; RESIDENT slots [on, x, y, imageset, page] that bronco.DrawAll (stage 7
; main) draws, mounting each cell's page.
;
; DEVIATIONS (V2-DEVIATION):
; - collision runs once per render (engine). The segments take no damage
;   (40:B9D4 resets it every frame): invincible boxes. The main attacker's
;   160 points do not fit a potential: its box is refilled each render and
;   the loss counted in A.dmg;
; - the pursuer and geld junk are their arcade cells re-converted on the
;   stage 7 palette (their own PNGs carry stage 5 and stage 4 colours);
; - palettes are not swapped (body pulses, 0x55 flash: the white cells);
; - explosions: the segments' twelve staggered blasts (40:BA4E) keep their
;   draws but show three; the fade (40:BFE8) shows one blast in eight;
; - when the arcade's object pool is full, an explosion that cannot be
;   allocated skips its draws (the fade, 40:C006): 21 frames of the bench's
;   kill. Here the draws always happen; they only place blasts;
; - the rare junk's bonus (40:5811) becomes the engine's option box, type
;   = arcade bonus id / 2;
; - music and sound commands: the bossmusic object and the explosions.
;*******************************************************************************

; --- states -------------------------------------------------------------------
bro.M_INIT    equ 1                  ; 40:B805
bro.M_LIFE    equ 2                  ; 40:B8D5
bro.M_PRE     equ 3                  ; 40:B950
bro.M_GONE    equ 4

; --- a segment (the ceiling lamps), 40:B997 -------------------------------------
G.st          equ 0                  ; 0 none, 1 run, 2 alt (40:B9FD)
G.x           equ 1                  ; 1,2 (+4)
G.c30         equ 3                  ; 3,4 (+0x30)
G.c20         equ 5                  ; 5,6 phase (+0x20)
G.SZ          equ 7
bro.NSEG      equ 5

; --- a piece of junk, 40:BC95 ---------------------------------------------------
R.st          equ 0                  ; 0 free, 1 new (installer next), 2 falling
R.inst        equ 1                  ; installer rank (bro.I_*)
R.x           equ 2                  ; 2,3 (+4)
R.y           equ 4                  ; 4,5 int (+8)
R.yf          equ 6                  ; frac (+7)
R.vy          equ 7                  ; 7,8 (+0x20)
R.p22         equ 9                  ; 9,10 its recipe, arcade address (+0x22)
R.p24         equ 11                 ; 11,12 its box, arcade address (+0x24)
R.f26         equ 13                 ; two cells (+0x26)
R.hp          equ 14                 ; (+0x2F)
R.f32         equ 15                 ; the rare one: a bonus (+0x32)
R.f33         equ 16                 ; animated (+0x33)
R.pp          equ 17                 ; box potential seen last render
R.SZ          equ 18
bro.NDEB      equ 14

; --- a chaser, 40:BDB2 ----------------------------------------------------------
C.st          equ 0
C.x           equ 1                  ; 1,2
C.y           equ 3                  ; 3,4 int
C.yf          equ 5
C.c30         equ 6                  ; 6,7
C.leg         equ 8                  ; the leg cell of the last frame
C.SZ          equ 9
bro.NCH       equ 4

; --- a sub-child of the main attack, 40:C03F ------------------------------------
B.st          equ 0                  ; 1 phase 1, 2 phase 2
B.x           equ 1                  ; 1,2
B.y           equ 3                  ; 3,4
B.s12         equ 5                  ; 5,6 script, arcade address
B.s14         equ 7                  ; 7,8 segment cursor, arcade address
B.s16         equ 9                  ; image byte (+0x16)
B.s17         equ 10                 ; bytes per frame (+0x17)
B.img         equ 11                 ; its picture: a junk rank
B.p34         equ 12                 ; 12,13 the arcade's image pointer (+0x34)
B.SZ          equ 14
bro.NSUB      equ 3

; --- the boxes (resident, stage 7 main) and the slots ------------------------
bro.BX_SEG    equ 0
bro.BX_MAIN   equ 5                  ; primary, then secondary at 6
bro.BX_DEB    equ 7
bro.BX_CH     equ bro.BX_DEB+bro.NDEB
bro.BX_SUB    equ bro.BX_CH+bro.NCH
bro.NBOX      equ bro.BX_SUB+bro.NSUB
bro.SL_DEB    equ 0                  ; draw order: the arcade's priorities
bro.SL_SUB    equ bro.NDEB
bro.SL_CH     equ bro.SL_SUB+bro.NSUB     ; two cells a chaser
bro.SL_SEG    equ bro.SL_CH+2*bro.NCH
bro.SL_MAIN   equ bro.SL_SEG+bro.NSEG     ; arm, then head
bro.NSLOT     equ bro.SL_MAIN+2
bro.SLOTSZ    equ 6                  ; [on, x, y, imageset(2), page]

bro.MAIN_HP   equ $A0                ; 40:BF71
bro.MAIN_P    equ 100                ; the refilled potential of its boxes

; installers, by rank (bro.Dispatch)
bro.I_GEN     equ 5                  ; ranks 0..5: 616C..61A8, jitter on bit 3
bro.I_STRONG  equ 6                  ; 61B4
bro.I_RARE    equ 7                  ; 61C0
bro.I_ANIM    equ 8                  ; 61CC
bro.I_SMALL   equ 9                  ; 622C
bro.I_RED     equ 10                 ; 6238

bronco.boxes  EXTERNAL               ; resident, bro.NBOX * sizeof{AABB}
bronco.slots  EXTERNAL               ; resident, bro.NSLOT * bro.SLOTSZ

;*******************************************************************************
; THE MANAGER
;*******************************************************************************
bronco.Object
        lda   routine,u
        asla
        ldx   #bro.Routines
        jmp   [a,x]
bro.Routines
        fdb   bronco.Init
        fdb   bronco.Live
        fdb   bronco.Done

; 40:B7FB create_bronco — the creation frame (frame 0)
bronco.Init
        ldb   wave_frame_drop,u          ; aliases anim_frame_duration
        stb   bro.pending
        ldx   #bro.Data
        ldd   #bro.DataEnd-bro.Data
@clr    clr   ,x+
        subd  #1
        bne   @clr
        ldx   #bronco.slots              ; nothing published yet
        ldb   #bro.NSLOT
!       clr   ,x
        leax  bro.SLOTSZ,x
        decb
        bne   <
        lda   #bro.M_INIT                ; b7fe tick = the init
        sta   bro.mst
        ldd   gfxlock.frame.gameCount    ; the arcade counter (bench rewrites)
        subb  bro.pending
        sbca  #0
        std   bro.gc
        ldd   #$0501
        std   bro.rng
        lda   #3
        sta   bro.rng+2
        jsr   LoadObject_x               ; the grouped renderer
        beq   >
        lda   #ObjID_bronco_render
        sta   id,x
        stx   bro.rnd
!       inc   routine,u
bronco.Seeded                        ; test hook: gc, seed, scroll phase final
        ldb   bro.pending
        bra   bro.Advance

bronco.Live
        jsr   bro.PlayerArcade
        jsr   bro.HitWatch
        ldb   gfxlock.frameDrop.count
bro.Advance
        pshs  u
        stb   bro.nfr
        beq   @pub
@f      jsr   bro.Frame
        dec   bro.nfr
        bne   @f
@pub    jsr   bro.Publish
        puls  u
bronco.Sample                        ; test hook: a render's state is final
        lda   bro.mst
        cmpa  #bro.M_GONE
        bne   @rts
        lda   #2
        sta   routine,u
@rts    rts

bronco.Done
        jmp   UnloadObject_u

;*******************************************************************************
; ONE ARCADE FRAME
;*******************************************************************************
bro.Frame
        ldd   bro.gc                     ; 40:0219 / 021D
        addd  #1
        std   bro.gc
        bitb  #$FF
        bne   >
        bita  #1
        bne   >
        ldd   #$0501
        std   bro.rng
        lda   #3
        sta   bro.rng+2
!       clr   bro.scroll                 ; the autoscroll, 0x80 a frame: the
        lda   bro.halted                 ; world moves 1 px every other frame
        bne   bronco.Tick
        lda   bro.sacc
        adda  #$80
        sta   bro.sacc
        bcc   bronco.Tick
        dec   bro.scroll                 ; -1
bronco.Tick                          ; test hook: frame bro.gc, before any actor
        ldy   #bro.Debris                ; 0x0F00
@d      lda   R.st,y
        beq   >
        jsr   bro.DebTick
!       leay  R.SZ,y
        cmpy  #bro.DebrisEnd
        blo   @d
        ldy   #bro.Subs                  ; 0x1000
@s      lda   B.st,y
        beq   >
        jsr   bro.Sub
!       leay  B.SZ,y
        cmpy  #bro.SubsEnd
        blo   @s
        ldy   #bro.Chasers               ; 0x2000
@c      lda   C.st,y
        beq   >
        jsr   bro.Chaser
!       leay  C.SZ,y
        cmpy  #bro.ChasersEnd
        blo   @c
        ldy   #bro.Segs                  ; 0xA100
@g      lda   G.st,y
        beq   >
        jsr   bro.Seg
!       leay  G.SZ,y
        cmpy  #bro.SegsEnd
        blo   @g
        lda   bro.dst                    ; 0xA110
        beq   >
        jsr   bro.Disp
!       lda   bro.sst                    ; 0xA120
        beq   >
        jsr   bro.Spawn
!       lda   bro.ast                    ; 0xA130
        beq   >
        jsr   bro.Main
!       lda   bro.mst                    ; 0xA200
        cmpa  #bro.M_INIT
        lbeq  bro.MInit
        cmpa  #bro.M_LIFE
        lbeq  bro.MLife
        cmpa  #bro.M_PRE
        lbeq  bro.MPre
        rts

;*******************************************************************************
; THE MANAGER — 40:B805 / B8D5 / B950
;*******************************************************************************
bro.MInit
        ldy   #bro.Segs                  ; b81c five lamps, 0x40 apart
        ldd   #$02D0
        std   bro.px
        ldd   #$03C0
        std   bro.py
@g      lda   #1
        sta   G.st,y
        ldd   bro.px
        std   G.x,y
        addd  #$40
        std   bro.px
        ldd   bro.py
        std   G.c20,y
        subd  #$20
        std   bro.py
        clr   G.c30,y
        clr   G.c30+1,y
        tfr   y,d
        subd  #bro.Segs
        jsr   bro.SegBoxIn
        leay  G.SZ,y
        cmpy  #bro.SegsEnd
        blo   @g
        lda   #1                         ; b855 the dispatcher
        sta   bro.dst
        ldd   #0
        std   bro.dc30
        ldd   #$611E
        std   bro.dcur
        ldd   #$20
        std   bro.dc32
        std   bro.dc34
        std   bro.dc36
        lda   #1                         ; b879 the spawner
        sta   bro.sst
        ldd   #0
        std   bro.sc20
        ldd   #$627C
        std   bro.scur
        lda   #1                         ; b891 the main attack
        sta   bro.ast
        ldd   #$02E8
        std   bro.ax
        clr   bro.axf                    ; leftover in the arcade (the bench)
        ldd   #$0110
        std   bro.ay
        ldd   #$FFFF
        std   bro.ac30
        ldd   #$017F
        std   bro.ac32
        clr   bro.af3d
        ldd   #0
        std   bro.admg
        lda   #bro.M_LIFE                ; b8cf
        sta   bro.mst
        rts

bro.MLife
        ldd   bro.c10                    ; b8dc
        addd  #1
        std   bro.c10
        cmpd  #$02E0                     ; b8df the scroll halts
        bne   >
        lda   #1
        sta   bro.halted
        ldd   scroll_vel
        std   bro.savedVel
        ldd   #0
        std   scroll_vel
        ldd   bro.c10
!       cmpd  #$1120                     ; b919 the end signal, every frame on
        blo   >
        lda   #$FF
        sta   bro.f30
!       ldd   bro.c10                    ; b929
        cmpd  #$1160
        beq   @pre
        lda   bro.f31                    ; b930 the main attack fell
        bne   @pre
        rts
@pre    ldd   #$C0                       ; b945
        std   bro.c32
        lda   #bro.M_PRE
        sta   bro.mst
        rts

bro.MPre
        ldd   bro.c32                    ; b957 the end-level flag at 0x40
        cmpd  #$40
        bne   >
        lda   #1
        sta   globals.bossDefeated
!       ldd   bro.c32
        subd  #1
        std   bro.c32
        bne   @rts
        lda   #1                         ; b976 the freeze, the scroll back
        sta   bro.freeze
        lda   #bro.M_GONE
        sta   bro.mst
        ldd   bro.savedVel
        std   scroll_vel
@rts    rts

;*******************************************************************************
; THE SEGMENTS — 40:B997 run_bronco, Y = the record
;*******************************************************************************
bro.Seg
        lda   bro.freeze                 ; b99d the freeze: unload
        lbne  bro.SegOut
        ldb   bro.scroll                 ; b997 + scroll_amount
        sex
        addd  G.x,y
        std   G.x,y
        ldd   G.c30,y                    ; b9a7
        addd  #1
        std   G.c30,y
        lda   G.st,y
        cmpa  #2
        beq   @alt
        lda   bro.f30                    ; b9e5 the end signal: turn back
        beq   >
        ldd   #0
        std   G.c30,y
        lda   #2
        sta   G.st,y
        rts
!       lda   bro.f31                    ; b9eb the main attack fell
        lbne  bro.SegDie
        rts
@alt    ldd   G.x,y                      ; ba46 gone past x 0x120
        cmpd  #$0120
        lblo  bro.SegOut
        rts

; 40:BA4E twelve explosions, each with its draw (three shown)
bro.SegDie
        lda   #12
        sta   bro.wN
@e      jsr   bro.Draw                   ; ba6c
        lda   bro.wN
        cmpa  #12
        beq   @show
        cmpa  #8
        beq   @show
        cmpa  #4
        bne   @n
@show   ldb   #12
        subb  bro.wN
        aslb
        aslb
        ldx   #bro.SegBoom
        abx
        ldd   ,x
        addd  G.x,y
        std   bro.wDX
        ldd   2,x
        addd  #$0160
        tfr   d,x
        ldd   bro.wDX
        ldu   #explosion.subtype.smallx3+explosion.sfx.none
        jsr   bro.Boom
@n      dec   bro.wN
        bne   @e
bro.SegOut
        clr   G.st,y
        tfr   y,d
        subd  #bro.Segs
        jmp   bro.SegBoxOut

;*******************************************************************************
; THE DISPATCHER — 40:BAA7
;*******************************************************************************
bro.Disp
        lda   bro.freeze
        lbne  @out
        ldd   bro.dc30                   ; bab1
        addd  #1
        std   bro.dc30
        cmpd  #$0360
        lblo  @tail
        ldd   bro.dc36                   ; babb
        subd  #1
        std   bro.dc36
        bne   @c34
        ldd   #$40
        std   bro.dc36
        ldd   bro.dc32
        subd  #1
        cmpd  #8
        bhs   >
        ldd   #8
!       std   bro.dc32
@c34    ldd   bro.dc34                   ; bad3
        subd  #1
        std   bro.dc34
        bne   @tail
        ldd   bro.dc32
        std   bro.dc34
        jsr   bro.Draw                   ; bade
        andb  #$3E
        lsrb
        ldx   #bro.Dispatch
        lda   b,x
        sta   bro.wX                     ; the installer
        jsr   bro.DebFree                ; baee load_managed_object
        beq   @adv                       ; no room: the cursor still moves
        lda   #1
        sta   R.st,x
        lda   bro.wX
        sta   R.inst,x
        ldd   bro.dcur
        subd  #$611E
        ldu   #bro.DebrisX
        ldd   d,u
        std   R.x,x
        ldd   #$0168                     ; bafc
        std   R.y,x
        clr   R.yf,x                     ; leftover in the arcade (the bench)
        ldd   bro.dc32                   ; bb01 -(0x400 - period * 16)
        aslb
        rola
        aslb
        rola
        aslb
        rola
        aslb
        rola
        subd  #$0400
        std   R.vy,x
@adv    ldd   bro.dcur                   ; bb20
        subd  #$611E
        ldu   #bro.DebrisX+2
        ldd   d,u
        cmpd  #$8000
        beq   >
        ldd   bro.dcur
        addd  #2
        bra   @cur
!       ldd   #$611E
@cur    std   bro.dcur
@tail   ldd   bro.f30                    ; bb34 a WORD test: +0x30 or +0x31
        beq   @rts
@out    clr   bro.dst
@rts    rts

; X = a free junk record, Z set if none
bro.DebFree
        ldx   #bro.Debris
@l      lda   R.st,x
        beq   @ok
        leax  R.SZ,x
        cmpx  #bro.DebrisEnd
        blo   @l
        clra                             ; Z = 1
        rts
@ok     lda   #1
        rts

;*******************************************************************************
; THE JUNK — 40:BB40..BC63 the installers, 40:BC95 the fall
;*******************************************************************************
bro.DebTick
        lda   bro.freeze
        lbne  bro.DebOut
        lda   R.st,y
        cmpa  #1
        beq   bro.Install
        leax  R.y,y                      ; bc9c move_y_pos_8_8
        ldd   R.vy,y
        jsr   bro.Move
        jsr   bro.DebBox                 ; bcdd damage >= HP ?
        lda   AABB.p,x
        beq   @die
        ldd   R.y,y                      ; bce5 Y below 0xB0: the floor
        cmpd  #$00B0
        blo   @land
        lda   bro.f31                    ; bcec the main attack fell
        bne   @die
        rts
@die    pshs  y                          ; bd03 score 0x86E8
        ldb   #0
        jsr   AwardScore
        puls  y
@land   lda   R.f32,y                    ; bd1a the rare one: a bonus
        beq   >
        jsr   bro.Draw                   ; bd26
        andb  #7
        jsr   bro.BonusDrop
        bra   bro.DebOut
!       ldd   R.x,y                      ; bd20 explosion_small_x2
        ldx   R.y,y
        ldu   #explosion.subtype.smallx2+explosion.sfx.medium
        jsr   bro.Boom
bro.DebOut
        clr   R.st,y
        jmp   bro.DebBoxOut

bro.Install
        lda   R.inst,y
        cmpa  #bro.I_GEN
        bhi   @other
        ldb   #12                        ; 616C + 12 * rank
        mul
        addd  #$616C
        std   R.p22,y
        jsr   bro.Draw                   ; bb4d bit 3: the second picture
        bitb  #8
        beq   @plain
        ldd   R.p22,y
        addd  #6
        std   R.p22,y
@plain  ldd   #$6244
        std   R.p24,y
        clr   R.f26,y
        lda   #1
        sta   R.hp,y
        clr   R.f32,y
        clr   R.f33,y
        lbra  @in
@other  cmpa  #bro.I_STRONG
        bne   >
        ldd   #$61B4                     ; bbae
        std   R.p22,y
        ldd   #$6254
        std   R.p24,y
        lda   #1
        sta   R.f26,y
        lda   #$0C
        sta   R.hp,y
        clr   R.f32,y
        clr   R.f33,y
        bra   @in
!       cmpa  #bro.I_RARE
        bne   >
        jsr   bro.Draw                   ; bbc6 one in eight
        addd  bro.gc
        andb  #7
        lbne  bro.DebOut                 ; bc04 no luck: unloaded
        ldd   #$61C0
        std   R.p22,y
        jsr   bro.Draw                   ; bbdc bit 2: the second picture
        bitb  #4
        beq   @rare
        ldd   R.p22,y
        addd  #6
        std   R.p22,y
@rare   ldd   #$6244
        std   R.p24,y
        clr   R.f26,y
        lda   #1
        sta   R.hp,y
        sta   R.f32,y
        clr   R.f33,y
        bra   @in
!       cmpa  #bro.I_ANIM
        bne   >
        ldd   #$61CC                     ; bc08
        std   R.p22,y
        ldd   #$6244
        std   R.p24,y
        clr   R.f26,y
        lda   #1
        sta   R.hp,y
        sta   R.f33,y
        clr   R.f32,y
        bra   @in
!       ldx   #$622C                     ; bc31 / bc63: bit 1 of a draw
        ldu   #$624C
        cmpa  #bro.I_SMALL
        beq   >
        ldx   #$6238
        ldu   #$6244
!       stx   R.p22,y
        stu   R.p24,y
        jsr   bro.Draw                   ; bc3e / bc70
        bitb  #2
        beq   >
        ldd   R.p22,y
        addd  #6
        std   R.p22,y
!       clr   R.f26,y
        lda   #1
        sta   R.hp,y
        clr   R.f32,y
        clr   R.f33,y
@in     lda   #2                         ; install the fall (bc95)
        sta   R.st,y
        lda   R.hp,y
        sta   R.pp,y
        jmp   bro.DebBoxIn

; B = arcade bonus type (0..7): the engine's option box (40:5811)
bro.BonusDrop
        pshs  y
        aslb                             ; (type << 2) + (counter & 2), bytes
        lda   bro.gc+1                   ; of words: the high byte
        anda  #2
        lsra
        pshs  a
        addb  ,s+
        ldx   #bro.Bonus
        ldb   b,x
        lsrb                             ; arcade id / 2 = the box's type
        stb   bro.wX
        jsr   LoadObject_x
        puls  y
        beq   @rts
        ldb   #ObjID_pow_optionbox
        lda   bro.wX
        cmpa  #5
        bne   >
        ldb   #ObjID_bitdevice
!       stb   id,x
        sta   subtype,x
        pshs  y
        ldd   R.x,y
        ldy   R.y,y
        jsr   bro.ToScreen
        puls  y
        jmp   bro.SpawnAt
@rts    rts

;*******************************************************************************
; THE SPAWNER — 40:BD32, and THE CHASERS — 40:BDB2
;*******************************************************************************
bro.Spawn
        lda   bro.freeze
        bne   @out
        ldd   bro.sc20                   ; bd3c
        addd  #1
        std   bro.sc20
        cmpd  #$0360
        blo   @tail
        bitb  #$7F                       ; bd49 every 128 frames
        bne   @tail
        ldd   bro.scur
        subd  #$627C
        ldu   #bro.ChaserX
        leau  d,u
        ldd   ,u
        cmpd  #$8000
        beq   @adv
        std   bro.wT
        ldx   #bro.Chasers               ; bd5f load_managed_object
@f      lda   C.st,x
        beq   @new
        leax  C.SZ,x
        cmpx  #bro.ChasersEnd
        blo   @f
        bra   @adv
@new    inc   C.st,x
        ldd   bro.wT
        std   C.x,x
        ldd   #$0090                     ; bd75
        std   C.y,x
        clr   C.yf,x                     ; leftover in the arcade (the bench)
        ldd   #0
        std   C.c30,x
        pshs  u
        tfr   x,d
        subd  #bro.Chasers
        jsr   bro.ChBoxIn
        puls  u
@adv    ldd   2,u                        ; bd96 the next word 0: wrap
        bne   >
        ldd   #$627C
        bra   @cur
!       ldd   bro.scur
        addd  #2
@cur    std   bro.scur
@tail   ldd   bro.f30                    ; bda6 a WORD test: +0x30 or +0x31
        beq   @rts
@out    clr   bro.sst
@rts    rts

bro.Chaser
        lda   bro.freeze
        lbne  bro.ChOut
        ldd   C.c30,y                    ; bdb9 >= 0xC0: down
        cmpd  #$00C0
        blo   >
        leax  C.y,y
        ldd   #$FF00
        jsr   bro.Move
!       ldd   C.c30,y                    ; bdc6 < 0x40: up
        cmpd  #$0040
        bhs   >
        leax  C.y,y
        ldd   #$0100
        jsr   bro.Move
!       ldd   C.c30,y                    ; bdd2 the two shots
        cmpd  #$0060
        beq   @shot
        cmpd  #$00A0
        bne   @dir
@shot   jsr   bro.Shoot
@dir    ldd   C.x,y                      ; bde5 the leg toward the player
        std   bro.px
        ldd   C.y,y
        std   bro.py
        jsr   bro.Dir
        lsrb
        lsrb
        ldx   #bro.ChLegs
        lda   b,x
        sta   C.leg,y
        jsr   bro.ChBox                  ; bdfd damage >= HP ?
        lda   AABB.p,x
        beq   @die
        lda   bro.f31                    ; be05
        bne   @die
        ldd   C.c30,y                    ; be0e
        addd  #1
        std   C.c30,y
        cmpd  #$0100
        beq   bro.ChOut
        rts
@die    pshs  y                          ; be26 score 0x86F4
        ldb   #3
        jsr   AwardScore
        puls  y
        ldd   C.x,y
        ldx   C.y,y
        ldu   #explosion.subtype.smallx2+explosion.sfx.turret
        jsr   bro.Boom
bro.ChOut
        clr   C.st,y
        tfr   y,d
        subd  #bro.Chasers
        jmp   bro.ChBoxOut

; 40:BE43 the engine's foe fire, from the chaser's place (the renderer's
; object stands in as the shooter)
bro.Shoot
        ldu   bro.rnd
        beq   @rts
        pshs  y
        ldd   x_pos,u
        std   bro.wDX
        ldd   y_pos,u
        std   bro.wDY
        ldd   C.x,y
        ldy   C.y,y
        jsr   bro.ToScreen
        jsr   bro.SpawnAtU
        lda   #3                         ; be73 [+0x20] = 3
        sta   fireDisplayDelay,u
        ldx   #player1
        stx   FoeFireTarget
        lda   Obj_Index_Page+ObjID_createFoeFire
        sta   PSR_Page
        ldd   Obj_Index_Address+2*ObjID_createFoeFire
        std   PSR_Address
        jsr   RunPgSubRoutine
        ldu   bro.rnd
        ldd   bro.wDX
        std   x_pos,u
        ldd   bro.wDY
        std   y_pos,u
        puls  y
@rts    rts

;*******************************************************************************
; THE MAIN ATTACK — 40:BE81, 40:BFE8 the fade
;*******************************************************************************
bro.Main
        lda   bro.freeze
        lbne  @out
        lda   bro.ast
        cmpa  #2
        lbeq  bro.Fade
        ldd   bro.ac30                   ; be8b dormant until 0x500
        addd  #1
        std   bro.ac30
        cmpd  #$0500
        blo   @rts
        ldd   bro.ac32                   ; be98
        cmpd  #$0100
        blo   >
        lda   bro.f30
        bne   @out
!       ldd   bro.ac32                   ; beab
        addd  #1
        std   bro.ac32
        cmpd  #$0180
        blo   @act
        ldd   #0
        std   bro.ac32
        jsr   bro.SubNew                 ; beba
@act    ldd   bro.ac32                   ; beff idle past 0x100
        cmpd  #$0100
        bhs   @rts
        andb  #$F0                       ; bf14 x speed, 16 steps of 16
        lsrb
        lsrb
        lsrb
        ldx   #bro.MainVx
        ldd   b,x
        ldx   #bro.ax
        jsr   bro.Move
        lda   bro.af3d                   ; bf35 the flash countdown
        beq   >
        dec   bro.af3d
!       ldd   bro.admg                   ; bf92 damage >= 0xA0 ?
        cmpd  #bro.MAIN_HP
        bhs   @die
@rts    rts
@die    lda   #$FF                       ; bfae the broadcast
        sta   bro.f31
        lda   #2                         ; bfc4 the fade, 0x80 frames
        sta   bro.ast
        ldd   #$80
        std   bro.ac30
        jmp   bro.MainBoxOut
@out    clr   bro.ast                    ; bf9b
        jmp   bro.MainBoxOut

bro.Fade
        lda   bro.gc+1                   ; bfe8 every 4 frames
        bita  #3
        bne   >
        jsr   bro.Draw                   ; bfef the sound of a blast
!       jsr   bro.Draw                   ; c008 x 0x140 + (random & 0x1FF)
        anda  #1
        addd  #$0140
        std   bro.wDX
        jsr   bro.Draw                   ; c014 y
        stb   bro.wX
        andb  #$7F
        clra
        addd  #$0080
        tst   bro.wX
        bpl   >
        addd  #$00A0
!       tfr   d,x
        lda   bro.gc+1                   ; one blast in eight is shown
        anda  #7
        bne   >
        ldd   bro.wDX
        ldu   #explosion.subtype.smallx3+explosion.sfx.none
        jsr   bro.Boom
!       ldd   bro.ac30                   ; c035
        subd  #1
        std   bro.ac30
        bne   @rts
        clr   bro.ast
@rts    rts

; 40:BEBA a sub-child at the main attack - (0x30, 0x18)
bro.SubNew
        ldx   #bro.Subs
@f      lda   B.st,x
        beq   @new
        leax  B.SZ,x
        cmpx  #bro.SubsEnd
        blo   @f
        rts                              ; no room: no draw either (bec3)
@new    lda   #1
        sta   B.st,x
        ldd   bro.ax
        subd  #$30
        std   B.x,x
        ldd   bro.ay
        subd  #$18
        std   B.y,x
        jsr   bro.Draw                   ; bedf its picture
        andb  #6
        lsrb
        ldu   #bro.SubImg
        lda   b,u
        sta   B.img,x
        ldb   #6                         ; the arcade's pointer, for the bench
        mul
        addd  #$616C
        std   B.p34,x
        ldd   #$A7FC                     ; beef script 0xA7FC
        std   B.s12,x
        pshs  x                          ; (RomW walks X)
        jsr   bro.RomW
        puls  x
        std   B.s14,x
        clr   B.s16,x                    ; a leftover in the arcade (the bench)
        lda   #1
        sta   B.s17,x
        tfr   x,d
        subd  #bro.Subs
        jmp   bro.SubBoxIn

;*******************************************************************************
; THE SUB-CHILD — 40:C03F / C069, Y = the record
;*******************************************************************************
bro.Sub
        lda   bro.freeze
        bne   bro.SubOut
        jsr   bro.MoveScript             ; c046
        bcs   @end
        jsr   bro.SubBox                 ; c054 hit: destroyed with score
        lda   AABB.p,x
        beq   @hit
        rts
@end    lda   B.st,y                     ; c05a phase 1 over: phase 2
        cmpa  #1
        bne   @gone
        lda   #2
        sta   B.st,y
        lda   #3
        sta   B.s17,y
        rts
@hit    pshs  y                          ; c084 score 0x871C
        ldb   #13
        jsr   AwardScore
        puls  y
@gone   ldd   B.x,y                      ; c08d explosion_small_x2
        ldx   B.y,y
        ldu   #explosion.subtype.smallx2+explosion.sfx.none
        jsr   bro.Boom
bro.SubOut
        clr   B.st,y
        tfr   y,d
        subd  #bro.Subs
        jmp   bro.SubBoxOut

; 40:F5C1 move_by_script, Y = the sub-child; C set when the script ended
bro.MoveScript
        lda   B.s17,y
        sta   bro.wN
@byte   ldd   B.s14,y
        jsr   bro.RomX
        lda   ,x
        bita  #$80                       ; f5cc SetImage
        beq   >
        anda  #$1F
        sta   B.s16,y
        bra   @next
!       bita  #$40                       ; f5d0
        beq   @px
        bita  #$20
        beq   @y
        pshs  a
        ldd   B.x,y                      ; f5f5 -x
        subd  #1
        std   B.x,y
        puls  a
        bra   @y
@px     bita  #$20
        beq   @y
        pshs  a
        ldd   B.x,y                      ; f5d8 +x
        addd  #1
        std   B.x,y
        puls  a
@y      bita  #$10
        beq   @py
        bita  #$08
        beq   @ey
        pshs  a
        ldd   B.y,y                      ; f5fe -y
        subd  #1
        std   B.y,y
        puls  a
        bra   @ey
@py     bita  #$08
        beq   @ey
        pshs  a
        ldd   B.y,y                      ; f5e3 +y
        addd  #1
        std   B.y,y
        puls  a
@ey   bita  #$04                       ; f5e6 end of segment
        bne   @seg
        ldd   B.s14,y
        addd  #1
        std   B.s14,y
        dec   bro.wN
        bne   @byte
        andcc #$FE                       ; f5ef not over
        rts
@next   ldd   B.s14,y                    ; f60b an image is not a move
        addd  #1
        std   B.s14,y
        bra   @byte
@seg    ldd   B.s12,y                    ; f60e the next command
        addd  #2
        std   B.s12,y
        jsr   bro.RomW
        cmpd  #0
        beq   @jump
        cmpa  #$F0
        bne   >
        stb   B.s17,y                    ; f621 bytes per frame
        bra   @seg
!       std   B.s14,y                    ; f626 a new segment
        andcc #$FE
        rts
@jump   ldd   B.s12,y                    ; f62b the script that follows
        addd  #2
        jsr   bro.RomW
        std   B.s12,y
        jsr   bro.RomW
        std   B.s14,y
        orcc  #1                         ; f638 over
        rts

; D = arcade address in the script ranges -> X ; (D unchanged)
bro.RomX
        pshs  d
        ldx   #bro.Ranges
@r      ldd   ,s
        subd  ,x                         ; offset in this range
        cmpd  2,x
        blo   @in
        leax  6,x
        bra   @r
@in     addd  4,x
        tfr   d,x
        puls  d,pc

; D = arcade address -> D = the word there (little-endian, as in ROM)
bro.RomW
        jsr   bro.RomX
        ldb   ,x
        lda   1,x
        rts

;*******************************************************************************
; THE TOOLS
;*******************************************************************************

; every draw passes here: the bench stops at bronco.Drawn and writes D
bro.Draw
        jsr   bro.Rand
bronco.Drawn
        rts

bro.Rand
        ldd   bro.rng+1
        pshs  b
        sta   bro.rng+2
        adda  ,s
        ldb   bro.rng
        stb   bro.rng+1
        sta   bro.rng
        tfr   a,b
        puls  a,pc

; X = position (int:2, frac:1), D = signed 8.8
bro.Move
        pshs  a
        addb  2,x
        stb   2,x
        puls  b
        sex
        adcb  1,x
        adca  ,x
        std   ,x
        rts

; 40:1D89 set_direction_to, from (bro.px, bro.py) to the player -> B
bro.Dir
        ldd   bro.py
        addd  #8
        cmpd  bro.ply
        blo   @above
        ldd   bro.py
        subd  #8
        cmpd  bro.ply
        bhs   @below
        ldd   bro.px
        cmpd  bro.plx
        bhs   >
        ldb   #$10
        rts
!       ldb   #$30
        rts
@above  ldd   bro.px
        addd  #8
        cmpd  bro.plx
        blo   @ne
        ldd   bro.px
        subd  #8
        cmpd  bro.plx
        bhs   @nw
        clrb
        rts
@below  ldd   bro.px
        addd  #8
        cmpd  bro.plx
        blo   @se
        ldd   bro.px
        subd  #8
        cmpd  bro.plx
        bhs   @sw
        ldb   #$20
        rts
@ne     ldd   bro.plx
        subd  bro.px
        std   bro.wT
        ldd   bro.ply
        subd  bro.py
        ldx   #bro.DirNE
        bra   @quad
@nw     ldd   bro.px
        subd  bro.plx
        std   bro.wT
        ldd   bro.ply
        subd  bro.py
        ldx   #bro.DirNW
        bra   @quad
@se     ldd   bro.plx
        subd  bro.px
        std   bro.wT
        ldd   bro.py
        subd  bro.ply
        ldx   #bro.DirSE
        bra   @quad
@sw     ldd   bro.px
        subd  bro.plx
        std   bro.wT
        ldd   bro.py
        subd  bro.ply
        ldx   #bro.DirSW
@quad   std   bro.wT2
        ldd   bro.wT
        subd  bro.wT2
        addd  #$0020
        cmpd  #$0040
        blo   @diag
        tsta
        bmi   @vert
        ldb   2,x
        rts
@diag   ldb   1,x
        rts
@vert   ldb   ,x
        rts
bro.DirNE fcb   $04,$08,$0C
bro.DirNW fcb   $3C,$38,$34
bro.DirSE fcb   $1C,$18,$14
bro.DirSW fcb   $24,$28,$2C
; 1000:625C the chaser's leg by direction / 4 (rank of 0x629E + 12 n)
bro.ChLegs fcb  8,3,2,1,0,0,0,0,0,4,4,4,4,5,6,7

; the player in arcade units (exact on its pinned point, see Bellmite)
bro.PlayerArcade
        ldd   player1+x_pos
        subd  glb_camera_x_pos
        subd  #8
        bpl   >
        ldd   #0
!       tsta
        beq   >
        ldb   #255
!       stb   bro.wX
        lda   #171
        mul
        tfr   a,b
        clra
        std   bro.wT
        ldb   bro.wX
        clra
        aslb
        rola
        addd  bro.wT
        addd  #320
        std   bro.plx
        ldb   player1+y_pos+1
        clra
        std   bro.wT
        ldd   #297
        subd  bro.wT
        std   bro.wT
        lda   #171
        mul
        tst   bro.wT
        beq   >
        addd  #171*256
!       lsra
        tfr   a,b
        clra
        addd  bro.wT
        std   bro.ply
        rts

; D = arcade x, Y = arcade y -> A = x, B = y on the screen (0-based, clamped)
bro.ToScreen
        subd  #320
        std   bro.wT
        aslb
        rola
        addd  bro.wT
        asra
        rorb
        asra
        rorb
        asra
        rorb
        addd  #8
        jsr   bro.Clamp
        stb   bro.wX
        tfr   y,d
        std   bro.wT
        aslb
        rola
        addd  bro.wT
        asra
        rorb
        asra
        rorb
        std   bro.wT
        ldd   #297
        subd  bro.wT
        jsr   bro.Clamp
        lda   bro.wX
        rts

bro.Clamp
        tsta
        beq   @rts
        bmi   @lo
        ldb   #255
        rts
@lo     clrb
@rts    rts

; D = arcade x, X = arcade y, U = explosion subtype: one engine explosion
bro.Boom
        pshs  y,u
        std   bro.wDX
        stx   bro.wDY
        jsr   LoadObject_x
        beq   @rts
        lda   #ObjID_explosion
        ldb   3,s                        ; the subtype (low byte of U)
        std   id,x
        pshs  x
        ldd   bro.wDX
        ldy   bro.wDY
        jsr   bro.ToScreen
        puls  x
        jsr   bro.SpawnAt
@rts    puls  y,u,pc

; X = a new object, A = x, B = y (screen, 0-based): its playfield position
bro.SpawnAt
        pshs  b
        tfr   a,b
        clra
        addd  glb_camera_x_pos
        std   x_pos,x
        puls  b
        clra
        std   y_pos,x
        rts

bro.SpawnAtU
        pshs  b
        tfr   a,b
        clra
        addd  glb_camera_x_pos
        std   x_pos,u
        puls  b
        clra
        std   y_pos,u
        rts

;*******************************************************************************
; THE BOXES — manager-owned, resident (bronco.boxes): prev and next MUST be
; blank before Collision_AddAABB (see the bug manager)
;*******************************************************************************
; A = box rank -> X
bro.BoxN
        ldb   #sizeof{AABB}
        mul
        addd  #bronco.boxes
        tfr   d,x
        rts

; X = the box, A = its potential, bro.wT = rx:ry
bro.BoxIn
        pshs  a,u,y
        ldb   #sizeof{AABB}
!       clr   ,x+
        decb
        bne   <
        leax  -sizeof{AABB},x
        ldd   bro.wT
        sta   AABB.rx,x
        stb   AABB.ry,x
        lda   #220
        sta   AABB.cx,x
        sta   AABB.cy,x
        lda   ,s
        sta   AABB.p,x
        ldy   #AABB_list_ennemy
        jsr   Collision_AddAABB
        puls  a,u,y,pc

; X = the box (its potential 0 = not in the list)
bro.BoxOut
        pshs  u,y
        ldy   #AABB_list_ennemy
        sty   Collision_Remove_1
        sty   Collision_Remove_3
        leay  2,y
        sty   Collision_Remove_2
        jsr   Collision_RemoveAABB
        puls  u,y,pc

bro.SegBoxIn                         ; D = offset: rank = offset / G.SZ
        jsr   bro.SegRank
        adda  #bro.BX_SEG
        jsr   bro.BoxN
        ldd   #3*256+1                   ; 6116: a thin line, x -32..-16
        std   bro.wT
        lda   #-1                        ; never hurt (40:B9D4)
        jmp   bro.BoxIn
bro.SegBoxOut
        jsr   bro.SegRank
        adda  #bro.BX_SEG
        jsr   bro.BoxN
        jmp   bro.BoxOut
bro.SegRank
        lda   #-1
!       inca
        subb  #G.SZ
        bcc   <
        rts

bro.DebBox                           ; Y = the junk -> X = its box
        tfr   y,d
        subd  #bro.Debris
        jsr   bro.DebRank
        adda  #bro.BX_DEB
        jmp   bro.BoxN
bro.DebRank
        lda   #-1
!       inca
        subb  #R.SZ
        bcc   <
        rts
bro.DebBoxIn
        jsr   bro.DebBox
        ldd   #4*256+8                   ; 6244: +-10
        std   bro.wT
        lda   R.inst,y
        cmpa  #bro.I_STRONG
        bne   >
        ldd   #6*256+12                  ; 6254: +-16
        std   bro.wT
!       lda   R.inst,y
        cmpa  #bro.I_SMALL
        bne   >
        ldd   #2*256+4                   ; 624C: +-5
        std   bro.wT
!       lda   R.hp,y
        jmp   bro.BoxIn
bro.DebBoxOut
        jsr   bro.DebBox
        jmp   bro.BoxOut

bro.ChBox                            ; Y = the chaser -> X = its box
        tfr   y,d
        subd  #bro.Chasers
        jsr   bro.ChRank
        adda  #bro.BX_CH
        jmp   bro.BoxN
bro.ChRank
        lda   #-1
!       inca
        subb  #C.SZ
        bcc   <
        rts
bro.ChBoxIn                          ; D = offset of the new chaser
        jsr   bro.ChRank
        adda  #bro.BX_CH
        jsr   bro.BoxN
        ldd   #2*256+10                  ; 630A: x +-6, y -22..6
        std   bro.wT
        lda   #2                         ; bd64 HP 2
        jmp   bro.BoxIn
bro.ChBoxOut
        jsr   bro.ChRank
        adda  #bro.BX_CH
        jsr   bro.BoxN
        jmp   bro.BoxOut

bro.SubBox
        tfr   y,d
        subd  #bro.Subs
        jsr   bro.SubRank
        adda  #bro.BX_SUB
        jmp   bro.BoxN
bro.SubRank
        lda   #-1
!       inca
        subb  #B.SZ
        bcc   <
        rts
bro.SubBoxIn
        jsr   bro.SubRank
        adda  #bro.BX_SUB
        jsr   bro.BoxN
        ldd   #4*256+8                   ; 6244
        std   bro.wT
        lda   #1                         ; v1: one hit
        jmp   bro.BoxIn
bro.SubBoxOut
        jsr   bro.SubRank
        adda  #bro.BX_SUB
        jsr   bro.BoxN
        jmp   bro.BoxOut

bro.MainBoxIn
        lda   #bro.BX_MAIN
        jsr   bro.BoxN
        ldd   #4*256+10                  ; 63C6.. : x -40..-16
        std   bro.wT
        lda   #bro.MAIN_P
        jsr   bro.BoxIn
        lda   #bro.BX_MAIN+1
        jsr   bro.BoxN
        ldd   #2*256+8                   ; 63BE: x +-6, y -10..11
        std   bro.wT
        lda   #bro.MAIN_P
        jmp   bro.BoxIn
bro.MainBoxOut
        lda   bro.amb
        beq   @rts
        clr   bro.amb
        lda   #bro.BX_MAIN
        jsr   bro.BoxN
        jsr   bro.BoxOut
        lda   #bro.BX_MAIN+1
        jsr   bro.BoxN
        jmp   bro.BoxOut
@rts    rts

; -----------------------------------------------------------------------------
; HitWatch — once per render, before the frames: the main attack's boxes are
; refilled and their loss counted (40:BF8E arms the 5-frame flash)
; -----------------------------------------------------------------------------
bro.HitWatch
        lda   bro.amb
        beq   @rts
        clr   bro.wN
        lda   #bro.BX_MAIN
        bsr   @one
        lda   #bro.BX_MAIN+1
        bsr   @one
        lda   bro.wN
        beq   @rts
        lda   #5
        sta   bro.af3d
@rts    rts
@one    jsr   bro.BoxN
        lda   AABB.p,x
        ldb   #bro.MAIN_P
        stb   AABB.p,x
        nega
        adda  #bro.MAIN_P                ; the loss
        beq   @none
        sta   bro.wN
        tfr   a,b
        clra
        addd  bro.admg
        std   bro.admg
@none   rts

;*******************************************************************************
; PUBLICATION — once per render: resident slots and box places
;*******************************************************************************
bro.Publish
        ; the main attack's boxes join once it wakes (0x500)
        lda   bro.ast
        cmpa  #1
        bne   >
        ldd   bro.ac30
        cmpd  #$0500
        blo   >
        lda   bro.amb
        bne   >
        inc   bro.amb
        jsr   bro.MainBoxIn
!       ldu   #bronco.slots
        ldy   #bro.Debris                ; --- the junk
@d      clr   ,u
        lda   R.st,y
        cmpa  #2
        bne   @dn
        ldd   R.x,y
        pshs  y
        ldy   R.y,y
        jsr   bro.ToScreen
        puls  y
        std   bro.wXY
        jsr   bro.DebImg                 ; X = imageset, A = page
        jsr   bro.Slot
        jsr   bro.DebBox
        ldd   bro.wXY
        jsr   bro.BoxPlace
@dn     leau  bro.SLOTSZ,u
        leay  R.SZ,y
        cmpy  #bro.DebrisEnd
        blo   @d
        ldy   #bro.Subs                  ; --- the sub-children
@s      clr   ,u
        lda   B.st,y
        beq   @sn
        ldd   B.x,y
        pshs  y
        ldy   B.y,y
        jsr   bro.ToScreen
        puls  y
        std   bro.wXY
        ldb   B.img,y
        jsr   bro.JunkImg
        jsr   bro.Slot
        jsr   bro.SubBox
        ldd   bro.wXY
        jsr   bro.BoxPlace
@sn     leau  bro.SLOTSZ,u
        leay  B.SZ,y
        cmpy  #bro.SubsEnd
        blo   @s
        ldy   #bro.Chasers               ; --- the chasers: head and leg
@c      clr   ,u
        clr   bro.SLOTSZ,u
        lda   C.st,y
        beq   @cn
        ldd   C.x,y
        pshs  y
        ldy   C.y,y
        jsr   bro.ToScreen
        puls  y
        std   bro.wXY
        ldx   #set_bronco_chaser_head_0
        lda   #map.RAM_OVER_CART+bro.PG_CHASER
        jsr   bro.Slot
        leau  bro.SLOTSZ,u
        ldb   C.leg,y
        aslb
        ldx   #bro.ChLegSets
        ldx   b,x
        lda   #map.RAM_OVER_CART+bro.PG_CHASER
        jsr   bro.Slot
        leau  -bro.SLOTSZ,u
        jsr   bro.ChBox
        ldd   bro.wXY
        addb  #6                         ; 630A: centred 8 arcade px below
        jsr   bro.BoxPlace
@cn     leau  2*bro.SLOTSZ,u
        leay  C.SZ,y
        cmpy  #bro.ChasersEnd
        blo   @c
        ldy   #bro.Segs                  ; --- the lamps
@g      clr   ,u
        lda   G.st,y
        beq   @gn
        ldd   G.x,y
        pshs  y
        ldy   #$0160
        jsr   bro.ToScreen
        puls  y
        std   bro.wXY
        jsr   bro.SegFrame               ; B = 0..3
        aslb
        ldx   #bro.SegSets
        ldx   b,x
        lda   #map.RAM_OVER_CART+bro.PG_MAIN
        jsr   bro.Slot
        tfr   y,d
        subd  #bro.Segs
        jsr   bro.SegRank
        adda  #bro.BX_SEG
        jsr   bro.BoxN
        ldd   bro.wXY
        suba  #9                         ; 6116: x -32..-16, y +32
        subb  #24
        jsr   bro.BoxPlace
@gn     leau  bro.SLOTSZ,u
        leay  G.SZ,y
        cmpy  #bro.SegsEnd
        blo   @g
        clr   ,u                         ; --- the main attack: arm and head
        clr   bro.SLOTSZ,u
        lda   bro.ast
        cmpa  #1
        bne   @rts
        ldd   bro.ac30
        cmpd  #$0500
        blo   @rts
        ldd   bro.ac32
        cmpd  #$0100
        bhs   @rts
        ldd   bro.ax
        ldy   bro.ay
        jsr   bro.ToScreen
        std   bro.wXY
        jsr   bro.MainPose               ; B = 0..3
        stb   bro.wX
        aslb
        ldx   #bro.ArmSets
        lda   bro.af3d                   ; bf3e the flash, odd frames
        beq   >
        lda   bro.gc+1
        bita  #1
        beq   >
        ldx   #bro.ArmFlashSets
!       ldx   b,x
        lda   #map.RAM_OVER_CART+bro.PG_MAIN
        jsr   bro.Slot
        leau  bro.SLOTSZ,u
        ldx   #set_bronco_main_head_0
        lda   bro.af3d
        beq   >
        lda   bro.gc+1
        bita  #1
        beq   >
        ldx   #set_bronco_main_head_flash_0
!       lda   #map.RAM_OVER_CART+bro.PG_MAIN
        jsr   bro.Slot
        lda   #bro.BX_MAIN               ; the boxes: primary (pose) y - 16,
        jsr   bro.BoxN                   ; secondary
        ldd   bro.wXY
        suba  #10                        ; x -40..-16
        ldb   bro.wX
        ldy   #bro.MainBoxDy
        ldb   b,y
        addb  bro.wXY+1
        jsr   bro.BoxPlace
        lda   #bro.BX_MAIN+1
        jsr   bro.BoxN
        ldd   bro.wXY
        jsr   bro.BoxPlace
@rts    rts

; Y = the junk -> X = imageset, A = page (the bug's cells live in lib.bug)
bro.DebImg
        lda   R.inst,y
        cmpa  #bro.I_SMALL
        bne   >
        ldx   #set_bug_2                 ; 622C = bug frame 10, 6232 = frame 6
        ldd   R.p22,y
        cmpd  #$622C
        beq   @bug
        ldx   #set_bug_10
@bug    lda   #map.RAM_OVER_CART+lib.bug.page
        rts
!       ldd   R.p22,y
        cmpd  #$6238                     ; geld 0/1
        blo   >
        subd  #$6238
        ldx   #set_bronco_debris_geld_0
        tstb
        beq   @pg
        ldx   #set_bronco_debris_geld_1
@pg     lda   #map.RAM_OVER_CART+bro.PG_JUNK
        rts
!       cmpd  #$61CC                     ; the pursuer, turning: counter & 0x3C
        bne   >
        ldb   bro.gc+1
        andb  #$3C
        lsrb
        ldx   #bro.PursuerSets
        ldx   b,x
        lda   #map.RAM_OVER_CART+bro.PG_JUNK
        rts
!       cmpd  #$61C0                     ; the rare one (POW, upside down)
        blo   >
        subd  #$61C0
        ldx   #set_bronco_debris_rare_0
        tstb
        beq   @pg
        ldx   #set_bronco_debris_rare_1
        bra   @pg
!       cmpd  #$61B4                     ; the big one: one picture, two cells
        bne   >
        ldx   #set_bronco_debris_strong_0
        bra   @pg
!       subd  #$616C                     ; the junk proper: 12 pictures
        lda   #6
        pshs  a
        clra
@div    cmpb  ,s
        blo   @q
        subb  ,s
        inca
        bra   @div
@q      leas  1,s
        tfr   a,b
; B = junk rank 0..11 -> X imageset, A page
bro.JunkImg
        aslb
        ldx   #bro.JunkSets
        ldx   b,x
        lda   #map.RAM_OVER_CART+bro.PG_JUNK
        rts

; Y = the lamp -> B = its picture (40:B9B0 / BA13)
bro.SegFrame
        ldd   G.c30,y
        pshs  d
        lda   G.st,y
        cmpa  #2
        beq   @alt
        puls  d                          ; run: frame 0 until c20, then 16
        subd  G.c20,y                    ; frames each, frame 3 kept
        bcs   @f0
        subd  #$10
        bcs   @f1
        subd  #$10
        bcs   @f2
        ldb   #3
        rts
@f0     clrb
        rts
@f1     ldb   #1
        rts
@f2     ldb   #2
        rts
@alt    puls  d                          ; alt: 3, 2, 1, then 0
        subd  #$10
        bcs   @a3
        subd  #$10
        bcs   @f2
        subd  #$10
        bcs   @f1
        clrb
        rts
@a3     ldb   #3
        rts

; the main attack's pose: (c32 & 0xF8) >> 3 through 1000:633A
bro.MainPose
        ldb   bro.ac32+1
        lsrb
        lsrb
        lsrb
        ldx   #bro.MainPoses
        ldb   b,x
        rts
bro.MainPoses
        fcb   0,0,0,0,0,0,0,0,0,1,2,3,3,3,2,1
        fcb   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
; 63C6.. the primary box, y -24 .. 2/8/16/24 and the y - 16 shift: centre
; on screen (TO8 px, y down)
bro.MainBoxDy
        fcb   20,18,15,12

; A = page, X = imageset, bro.wXY = place (screen 0-based): fill slot U
bro.Slot
        sta   5,u
        stx   3,u
        ldd   bro.wXY
        adda  #screen_left
        addb  #screen_top
        std   1,u
        lda   #1
        sta   ,u
        rts

; the box X centred on (A, B), screen 0-based; parked off screen when the
; centre clamps
bro.BoxPlace
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

;*******************************************************************************
; THE GROUPED RENDERER — its picture is bronco.DrawAll (stage 7 main,
; resident): every lit slot, its page mounted
;*******************************************************************************
bro.FakeImg
        fcb   bro.FakeSub-bro.FakeImg,bro.FakeSub-bro.FakeImg
        fcb   bro.FakeSub-bro.FakeImg,bro.FakeSub-bro.FakeImg
        fcb   8,8,0
bro.FakeSub
        fcb   0
        fcb   bro.FakeMf-bro.FakeSub
        fcb   0
        fcb   bro.FakeMf-bro.FakeSub
        fcb   0,0
bro.FakeMf
        fcb   0                          ; page, patched by the renderer
        fdb   bronco.DrawAll

bronco.DrawAll EXTERNAL

bronco.Render
        lda   routine,u
        bne   @live
        _GetCartPageA
        ldb   id,u
        ldx   #Img_Page_Index
        sta   b,x
        sta   bro.FakeMf
        ldd   #bro.FakeImg
        std   image_set,u
        clr   render_flags,u
        lda   #120
        sta   x_pixel,u
        lda   #135
        sta   y_pixel,u
        ldb   #5                         ; behind the ship (3)
        stb   priority,u
        inc   routine,u
        jmp   DisplaySprite
@live   lda   bro.mst
        cmpa  #bro.M_GONE
        bne   >
        clr   bro.rnd
        clr   bro.rnd+1
        jmp   DeleteObject
!       jmp   DisplaySprite

;*******************************************************************************
; THE PICTURES — imageset and its page
;*******************************************************************************
bro.SegSets
        fdb   set_bronco_segment_0,set_bronco_segment_1
        fdb   set_bronco_segment_2,set_bronco_segment_3
bro.ArmSets
        fdb   set_bronco_main_arm0_0,set_bronco_main_arm1_0
        fdb   set_bronco_main_arm2_0,set_bronco_main_arm3_0
bro.ArmFlashSets
        fdb   set_bronco_main_arm0_flash_0,set_bronco_main_arm1_flash_0
        fdb   set_bronco_main_arm2_flash_0,set_bronco_main_arm3_flash_0
bro.ChLegSets
        fdb   set_bronco_chaser_leg0_0,set_bronco_chaser_leg1_0,set_bronco_chaser_leg2_0
        fdb   set_bronco_chaser_leg3_0,set_bronco_chaser_leg4_0,set_bronco_chaser_leg5_0
        fdb   set_bronco_chaser_leg6_0,set_bronco_chaser_leg7_0,set_bronco_chaser_leg8_0
bro.JunkSets
        fdb   set_bronco_debris_0,set_bronco_debris_1,set_bronco_debris_2
        fdb   set_bronco_debris_3,set_bronco_debris_4,set_bronco_debris_5
        fdb   set_bronco_debris_6,set_bronco_debris_7,set_bronco_debris_8
        fdb   set_bronco_debris_9,set_bronco_debris_10,set_bronco_debris_11
bro.PursuerSets
        fdb   set_bronco_debris_pursuer_0,set_bronco_debris_pursuer_1
        fdb   set_bronco_debris_pursuer_2,set_bronco_debris_pursuer_3
        fdb   set_bronco_debris_pursuer_4,set_bronco_debris_pursuer_5
        fdb   set_bronco_debris_pursuer_6,set_bronco_debris_pursuer_7
        fdb   set_bronco_debris_pursuer_8,set_bronco_debris_pursuer_9
        fdb   set_bronco_debris_pursuer_10,set_bronco_debris_pursuer_11
        fdb   set_bronco_debris_pursuer_12,set_bronco_debris_pursuer_13
        fdb   set_bronco_debris_pursuer_14,set_bronco_debris_pursuer_15

;*******************************************************************************
; THE DATA (page) — cleared at every Init
;*******************************************************************************
bro.nfr      fcb   0
bro.pending  fcb   0
bro.savedVel fdb   0
bro.rnd      fdb   0                     ; the renderer's object (the shooter)

bro.Data
bro.gc       fdb   0                     ; the arcade global counter (0x2EB6)
bro.rng      fcb   0,0,0                 ; random_ax state
bro.sacc     fcb   0                     ; the autoscroll's fraction
bro.scroll   fcb   0                     ; this frame's scroll_amount
bro.halted   fcb   0
bro.freeze   fcb   0                     ; 0x2FC4 game_tick_disable
bro.plx      fdb   0                     ; the player, arcade units
bro.ply      fdb   0
bro.mst      fcb   0                     ; the manager
bro.c10      fdb   0
bro.f30      fcb   0
bro.f31      fcb   0
bro.c32      fdb   0
bro.dst      fcb   0                     ; the dispatcher
bro.dc30     fdb   0
bro.dcur     fdb   0
bro.dc32     fdb   0
bro.dc34     fdb   0
bro.dc36     fdb   0
bro.sst      fcb   0                     ; the spawner
bro.sc20     fdb   0
bro.scur     fdb   0
bro.ast      fcb   0                     ; the main attack: 1 run, 2 fade
bro.ax       fdb   0
bro.axf      fcb   0
bro.ay       fdb   0
bro.ac30     fdb   0
bro.ac32     fdb   0
bro.af3d     fcb   0
bro.admg     fdb   0                     ; damage taken (+0x1F)
bro.amb      fcb   0                     ; its boxes are in the list
bro.px       fdb   0
bro.py       fdb   0
bro.wN       fcb   0
bro.wT       fdb   0
bro.wT2      fdb   0
bro.wDX      fdb   0
bro.wDY      fdb   0
bro.wX       fcb   0
bro.wXY      fdb   0
bro.Segs     fill  0,bro.NSEG*G.SZ
bro.SegsEnd
bro.Debris   fill  0,bro.NDEB*R.SZ
bro.DebrisEnd
bro.Chasers  fill  0,bro.NCH*C.SZ
bro.ChasersEnd
bro.Subs     fill  0,bro.NSUB*B.SZ
bro.SubsEnd
bro.DataEnd

        INCLUDE "src/enemies/bronco/tables.asm"
