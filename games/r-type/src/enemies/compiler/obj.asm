;*******************************************************************************
; Compiler — the stage 4 boss, ported 1:1 from the arcade
;
; PORTING SHEET (source: Ghidra `maincpu`, subsystem compiler)
; ------------------------------------------------------------
;   40:A71D create_compiler ............... compiler.Init (frame 0)
;   40:A762 tick_compiler_init_segments ... cpl.OInit
;   40:A982 tick_compiler_combat_monitor .. cpl.OMonitor
;   40:A9C1 tick_compiler_death_sequence .. cpl.ODeath
;   40:AA0F / AB62 / ACE7 the three parts . cpl.PartTick (right, bottom, left)
;   40:AB01 / ADFB laser volleys .......... cpl.Volley
;   40:AE5C rolling laser pair ............ cpl.RollSpawn
;   40:AEFB / AF6F rolling laser phases ... cpl.RollTick
;   40:AC4C tick_compiler_turret .......... cpl.TurretTick
;   40:AFE6 compiler_part_motion_step ..... cpl.Motion
;   40:B062 / B073 destroy cascade ........ cpl.Cascade
;   40:E6AB / E6C0 run_horizontal_laser ... cpl.LaserRun
;   40:F63A try_foe_fire, 40:F8A7 load_fire_preset (the turrets' clock)
;
; THE PORT RUNS IN ARCADE SPACE and ONE ARCADE FRAME AT A TIME, in the
; arcade's list order (orchestrator 0x1000, left lasers 0x3FFF, left part
; 0x4000, bottom part 0x4010, turrets 0x4011/0x4012, right lasers 0x401F,
; right part 0x4020, rolling lasers 0xC000). The order is not cosmetic: the
; three parts move in LOCKSTEP — a part whose segment is over waits, still,
; until the other two are done too (the orchestrator raises [+0x34] only on
; the frame where the union of the expiries reaches 7), and a laser spawned
; by a part only ticks the next frame when it sits before that part in the
; list, the same frame when it sits after (the rolling lasers).
; Positions are the arcade's 16.8, velocities its 8.8; the scripts, the
; configurations and the cascade lists are a RAW copy of the ROM
; (tables.asm), read address for address — after its last script a part
; goes on reading the segments that follow in ROM, and so does this port.
; Only the publication converts to the screen, once per render.
;
; RANDOM NUMBERS: the arcade's random_ax stream is shared with the boss's
; starfield (star_ctor draws three per star): this port cannot reproduce the
; stream, only its own draws. Every draw goes through cpl.Draw; the bench
; stops at compiler.Drawn and writes the value the arcade's caller got
; (tools/fidelity/). In game, cpl.Rand is a private copy of random_ax.
;
; DISPLAY: the actors are PUPPETS — objects of the five ObjIDs that only
; show an image and carry a box. The manager creates them, places them and
; tells them to go (cpl.Publish); they never think.
;
; DEVIATIONS (V2-DEVIATION):
; - collision runs once per render (engine), and a part has one box, not a
;   main box plus sub-boxes (40:AA6D..AA91);
; - palettes are global: the hit flash hides the part on the arcade's flash
;   frames, the dome keeps the author's pulse (dome-pulse.asm);
; - the rolling laser probes the TO8 terrain maps (terrainCollision), not
;   the arcade's tile RAM. During the fight the TO8 neither draws nor probes
;   the gum chains (plainBackdrop, stage-main.asm) the arcade keeps on
;   screen: a segment the arcade loses on a chain flies on here (26 in the
;   idle fight of the fidelity bench, which feeds those deaths as an input);
; - sounds: the explosion objects carry them; the cascade keeps its draws.
;*******************************************************************************

; --- the puppets: ext_variables -----------------------------------------------
AABB_0        equ ext_variables      ; 9 bytes
pp.show       equ ext_variables+9    ; 1 = DisplaySprite this render
pp.kill       equ ext_variables+10   ; 1 = remove the box and go
pp.list       equ ext_variables+11   ; 11,12 the box's list (0 = no box)

; --- record layouts (page data) ------------------------------------------------
P.st      equ 0      ; 0 gone, 1 live, 2 cascade
P.x       equ 1      ; 1,2 int  (+4)
P.xf      equ 3      ;     frac (+3)
P.y       equ 4      ; 4,5 int  (+8)
P.yf      equ 6      ;     frac (+7)
P.cfg     equ 7      ; 7,8 config cursor, arcade address (+0x10)
P.cur     equ 9      ; 9,10 script cursor, arcade address (+0x12)
P.vx      equ 11     ; 11,12 (+0x38)
P.vy      equ 13     ; 13,14 (+0x3A)
P.dur     equ 15     ; 15,16 (+0x3C)
P.c20     equ 17     ; cadence reload (+0x20)
P.c22     equ 18     ; 18,19 cadence countdown (+0x22)
P.f28     equ 20     ; 20,21 fade counter (+0x28)
P.h32     equ 22     ; hit cooldown (+0x32)
P.w34     equ 23     ; 23,24 left part: rolling-laser window (+0x34)
P.bit     equ 25     ; 1 right, 2 bottom, 4 left
P.pup     equ 26     ; 26,27 the puppet
P.cl      equ 28     ; 28,29 cascade cursor, arcade address (+0x10)
P.cl0     equ 30     ; 30,31 cascade list start (+0x12)
P.life    equ 32     ; cascade lifetime (+0x20)
P.pp      equ 33     ; box potential seen last render
P.SZ      equ 34

T.st      equ 0      ; 0 none, 1 live
T.par     equ 1      ; 1,2 the part record
T.ox      equ 3      ; 3,4 offset x (+0x30)
T.oy      equ 5      ; 5,6 offset y (+0x32)
T.x       equ 7      ; 7,8
T.y       equ 9      ; 9,10
T.fire    equ 11     ; the fire gate (+0x16)
T.dir     equ 12     ; direction code (0..$3C)
T.c26     equ 13     ; 13,14 fire clock (+0x26)
T.thr     equ 15     ; 15,16 (+0x2A)
T.rst     equ 17     ; 17,18 (+0x2C)
T.pup     equ 19     ; 19,20
T.pre     equ 21     ; its fire preset ($30 / $40)
T.SZ      equ 22

Z.st      equ 0      ; 0 free, 1 born this frame, 2 flying
Z.side    equ 1      ; 0 right (0x401F), 1 left (0x3FFF)
Z.x       equ 2      ; 2,3
Z.xf      equ 4
Z.y       equ 5      ; 5,6
Z.vx      equ 7      ; 7,8
Z.pup     equ 9      ; 9,10
Z.SZ      equ 11
cpl.NLASER equ 6

W.st      equ 0      ; 0 free, 1 phase 1, 2 phase 2
W.x       equ 1      ; 1,2
W.xf      equ 3
W.y       equ 4      ; 4,5
W.yf      equ 6
W.vx      equ 7      ; 7,8
W.w20     equ 9      ; 9,10 vertical speed AND lifetime (+0x20)
W.pup     equ 11     ; 11,12
W.spr     equ 13     ; its pose, fixed for its life
W.SZ      equ 14
cpl.NROLL equ 8

; orchestrator states
O_INIT    equ 1
O_MON     equ 2
O_DEATH   equ 3
O_GONE    equ 4

Object
        lda   routine,u
        asla
        ldx   #Routines
        jmp   [a,x]
Routines
        fdb   compiler.Init
        fdb   compiler.Live
        fdb   cpl.Puppet

;*******************************************************************************
; THE MANAGER
;*******************************************************************************

; 40:A71D create_compiler — the creation frame (frame 0)
compiler.Init
        ldb   wave_frame_drop,u          ; aliases anim_frame_duration
        stb   cpl.pending
        ldx   #cpl.Data
        ldd   #cpl.DataEnd-cpl.Data
@clr    clr   ,x+
        subd  #1
        bne   @clr
        ; a744: both scroll axes stop (restored at the end of the death)
        ldd   scroll_vel
        std   cpl.savedVel
        ldd   #0
        std   scroll_vel
        ; the arcade counter at this frame and a seed (the bench rewrites both)
        ldd   gfxlock.frame.gameCount
        subb  cpl.pending
        sbca  #0
        std   cpl.gc
        ldd   #$0501
        std   cpl.rng
        lda   #3
        sta   cpl.rng+2
        jsr   cpl.PlayerArcade
        ; a728: the variant, (random + player y + player x) & 7, as a byte
        ; offset into the slot table (stride 8)
        jsr   cpl.Draw
        addd  cpl.ply
        addd  cpl.plx
        andb  #7
        lslb
        lslb
        lslb
        stb   cpl.v10
        ldd   #7                         ; a73f death mask
        std   cpl.f30
        lda   #O_INIT
        sta   cpl.ost
        inc   routine,u
compiler.Seeded                      ; test hook: gc and the seed are final
        ldb   cpl.pending
        bra   cpl.Advance

compiler.Live
        jsr   cpl.PlayerArcade
        jsr   cpl.HitWatch
        ldb   gfxlock.frameDrop.count
cpl.Advance
        pshs  u
        stb   cpl.nfr
        beq   @pub
@f      jsr   cpl.Frame
        dec   cpl.nfr
        bne   @f
@pub    jsr   cpl.Publish
        puls  u
compiler.Sample                      ; test hook: a render's state is final
        rts

;*******************************************************************************
; ONE ARCADE FRAME, in list order
;*******************************************************************************
cpl.Frame
        ldd   cpl.gc                     ; 40:0219 / 021D
        addd  #1
        std   cpl.gc
        bitb  #$FF
        bne   >
        bita  #1
        bne   >
        ldd   #$0501
        std   cpl.rng
        lda   #3
        sta   cpl.rng+2
!
compiler.Tick                        ; test hook: frame cpl.gc, before any actor
        lda   cpl.ost                    ; the orchestrator, 0x1000
        cmpa  #O_INIT
        bne   >
        jsr   cpl.OInit
        bra   @o
!       cmpa  #O_MON
        bne   >
        jsr   cpl.OMonitor
        bra   @o
!       cmpa  #O_DEATH
        bne   @o
        jsr   cpl.ODeath
@o      lda   #1                         ; the left lasers, 0x3FFF
        jsr   cpl.LaserRun
        ldy   #cpl.Parts+2*P.SZ          ; the left part, 0x4000
        jsr   cpl.PartTick
        ldy   #cpl.Parts+1*P.SZ          ; the bottom part, 0x4010
        jsr   cpl.PartTick
        ldy   #cpl.Turrets               ; the turrets: 0x4011, then the two
        ldb   #3                         ; 0x4012, the newest first
@t      pshs  b
        jsr   cpl.TurretTick
        leay  T.SZ,y
        puls  b
        decb
        bne   @t
        clra                             ; the right lasers, 0x401F
        jsr   cpl.LaserRun
        ldy   #cpl.Parts                 ; the right part, 0x4020
        jsr   cpl.PartTick
        ldy   #cpl.Rolls                 ; the rolling lasers, 0xC000
        ldb   #cpl.NROLL
@r      pshs  b
        lda   W.st,y
        beq   >
        jsr   cpl.RollTick
!       leay  W.SZ,y
        puls  b
        decb
        bne   @r
        ; the newly born lasers are flying from now on
        ldy   #cpl.Lasers
        ldb   #cpl.NLASER
@z      lda   Z.st,y
        cmpa  #1
        bne   >
        inc   Z.st,y
!       leay  Z.SZ,y
        decb
        bne   @z
        rts

;*******************************************************************************
; THE ORCHESTRATOR
;*******************************************************************************

; 40:A762 — the three parts and the three turrets
cpl.OInit
        ldy   #cpl.Parts                 ; RIGHT, 0x4020
        lda   #1
        ldb   #0
        jsr   cpl.PartNew
        ldy   #cpl.Parts+P.SZ            ; BOTTOM, 0x4010
        lda   #2
        ldb   #2
        jsr   cpl.PartNew
        ; a843: its two turrets, preset 0x30 then 0x40
        ldx   #cpl.Turrets               ; b1 is list slot 0
        ldd   #-32
        std   cpl.wT
        ldd   #-40
        std   cpl.wT2
        lda   #$30
        jsr   cpl.TurretNew
        ldx   #cpl.Turrets+2*T.SZ        ; b2 is list slot 2 (older 0x4012)
        ldd   #-24
        std   cpl.wT
        ldd   #-64
        std   cpl.wT2
        lda   #$40
        jsr   cpl.TurretNew
        ldy   #cpl.Parts+2*P.SZ          ; LEFT, 0x4000
        lda   #4
        ldb   #4
        jsr   cpl.PartNew
        ldx   #cpl.Turrets+T.SZ          ; its turret, list slot 1 (newer 0x4012)
        ldd   #-72
        std   cpl.wT
        ldd   #24
        std   cpl.wT2
        lda   #$30
        jsr   cpl.TurretNew
        clr   cpl.f32                    ; a972
        clr   cpl.f32+1
        clr   cpl.f34
        lda   #O_MON
        sta   cpl.ost
        rts

; Y = the part record, A = its death bit, B = its offset in the slot (0/2/4)
cpl.PartNew
        sta   P.bit,y
        coma                             ; a770: the bit leaves the mask
        anda  cpl.f30+1
        sta   cpl.f30+1
        lda   #1
        sta   P.st,y
        clra
        addb  cpl.v10                    ; a775: variant slot + part offset
        addd  #$5ABA
        jsr   cpl.RomW                   ; D = the config's address
        std   P.cfg,y
        jsr   cpl.RomW                   ; D = its first script (5B54)
        std   P.cur,y
        jsr   cpl.RomX                   ; X = the script
        ldd   ,x                         ; a786 the first segment
        std   P.vx,y
        ldd   2,x
        std   P.vy,y
        ldd   4,x
        std   P.dur,y
        ldd   #$0100                     ; a79a (0x100, 0x108)
        std   P.x,y
        ldd   #$0108
        std   P.y,y
        clr   P.xf,y                     ; leftovers in the arcade: the bench
        clr   P.yf,y                     ; writes them (compiler.Tick)
        clr   P.h32,y
        clr   P.f28,y
        clr   P.f28+1,y
        clr   P.w34,y
        clr   P.w34+1,y
        pshs  x                          ; a7c9 / a8f6: the cadence by
        ldx   #cpl.Cadence               ; difficulty
        ldb   globals.difficulty
        lda   b,x
        puls  x
        sta   P.c20,y                    ; a7d6 / a903: right and left only
        tfr   a,b
        clra
        std   P.c22,y
        lda   #40                        ; a7a4 HP_max 0x28
        sta   P.pp,y
        rts

; X = the turret record, Y = its part, A = its fire preset, cpl.wT/wT2 = the
; offsets. f8a7 load_fire_preset: counter = (random * 4) & (threshold - 1)
cpl.TurretNew
        sta   T.pre,x
        lda   #1
        sta   T.st,x
        sty   T.par,x
        ldd   cpl.wT
        std   T.ox,x
        ldd   cpl.wT2
        std   T.oy,x
        clr   T.fire,x                   ; a leftover in the arcade (the bench)
        pshs  u                          ; f8a7: its preset's row at the
        ldb   globals.difficulty         ; difficulty (8E10 + diff*96)
        aslb
        aslb
        aslb
        ldu   #cpl.TurretPre
        leau  b,u
        lda   T.pre,x
        cmpa  #$30
        beq   >
        leau  4,u
!       ldd   ,u
        std   T.thr,x
        ldd   2,u
        std   T.rst,x
        puls  u
        pshs  x
        jsr   cpl.Draw                   ; f8e4
        puls  x
        aslb                             ; f8e7 * 4
        rola
        aslb
        rola
        pshs  d
        ldd   T.thr,x
        subd  #1
        anda  ,s
        andb  1,s
        leas  2,s
        std   T.c26,x
        rts

; 40:A982
cpl.OMonitor
        clr   cpl.f34                    ; a989
        ldd   cpl.f30                    ; a98e (f30 | f32) == 7 ?
        ora   cpl.f32
        orb   cpl.f32+1
        cmpd  #7
        bne   >
        lda   #1                         ; a99b
        sta   cpl.f34
        clr   cpl.f32
        clr   cpl.f32+1
!       ldb   cpl.f30+1                  ; a9a5 (f30 & 7) == 7 ?
        andb  #7
        cmpb  #7
        bne   >
        ldd   #$0100                     ; a9b1
        std   cpl.c36
        lda   #O_DEATH
        sta   cpl.ost
!       rts

; 40:A9C1 — 256 frames
cpl.ODeath
        ldd   cpl.c36
        cmpd  #$0080                     ; a9c8: end_level_sequence_flag
        bne   >
        lda   #1
        sta   globals.bossDefeated
!       ldd   cpl.c36                    ; a9f0
        subd  #1
        std   cpl.c36
        bne   >
        lda   #O_GONE                    ; a9f6: the autoscroll restarts
        sta   cpl.ost
        ldd   cpl.savedVel
        std   scroll_vel
!       rts

;*******************************************************************************
; THE PARTS — Y = the record
;*******************************************************************************
cpl.PartTick
        lda   P.st,y
        lbeq  @rts
        cmpa  #2
        lbeq  cpl.Cascade
        lda   P.bit,y
        cmpa  #1
        bne   >
        lda   #0                         ; aa19 the right part fires first
        jsr   cpl.Volley
!       jsr   cpl.Motion                 ; aa3d / ab8d / ad12
        lda   P.h32,y                    ; aa40 hit cooldown
        beq   >
        dec   P.h32,y
!       ldd   P.f28,y                    ; aa66 the fade path: nothing else
        bne   @rts
        lda   P.bit,y
        cmpa  #4
        bne   @dmg
        lda   #1                         ; ad42 the left part's weapons
        jsr   cpl.Volley
        ldd   P.y,y                      ; ad45 part high enough ?
        cmpd  #$00B8
        bhs   @low
        ldd   P.w34,y                    ; ad4c
        addd  #1
        std   P.w34,y
        cmpd  #$0040
        bhs   @dmg
        bitb  #$0F
        bne   @dmg
        jsr   cpl.RollSpawn              ; ad5c
        bra   @dmg
@low    clr   P.w34,y                    ; ad62
        clr   P.w34+1,y
@dmg    jsr   cpl.PartBox                ; aa9a damage >= HP_max ?
        lda   AABB.p,x
        bne   @rts
        ; aadb destroy with score + cascade
        lda   P.bit,y
        ora   cpl.f30+1
        sta   cpl.f30+1
        pshs  y
        ldb   #compiler_scoreIdx         ; 0x8714
        jsr   AwardScore
        puls  y
        ldb   P.bit,y                    ; aafb / ac45 / adf5 the list
        ldx   #cpl.BoomLists
        lsrb
        aslb
        ldd   b,x
        std   P.cl,y
        std   P.cl0,y
        lda   #$40                       ; b06d
        sta   P.life,y
        lda   #2
        sta   P.st,y
@rts    rts
cpl.BoomLists                        ; indexed by bit/2*2: right, bottom, -, left
        fdb   $58EE,$594E,$59A6,$59A6

; 40:AFE6 compiler_part_motion_step, Y = the part
cpl.Motion
        ldd   P.dur,y
        beq   @exp
        subd  #1                         ; afed
        std   P.dur,y
        leax  P.x,y
        ldd   P.vx,y
        jsr   cpl.Move
        leax  P.y,y
        ldd   P.vy,y
        jmp   cpl.Move
@exp    ldb   P.bit,y                    ; afff the deferred signal
        orb   cpl.f32+1
        stb   cpl.f32+1
        lda   cpl.f34                    ; b005 armed ?
        beq   @rts
        ldd   P.cur,y                    ; b00c next segment
        addd  #6
        std   P.cur,y
        jsr   cpl.RomX
        ldd   ,x
        cmpd  #$8000                     ; b016 the loop sentinel
        bne   @load
        ldd   P.cfg,y                    ; b01b next script of the config
        addd  #2
        std   P.cfg,y
        jsr   cpl.RomW
        cmpd  #0
        beq   @term
        std   P.cur,y                    ; b029
@load   ldd   P.cur,y                    ; b02c double tempo
        jsr   cpl.RomX
        ldd   ,x
        aslb
        rola
        std   P.vx,y
        ldd   2,x
        aslb
        rola
        std   P.vy,y
        ldd   4,x
        lsra
        rorb
        std   P.dur,y
@rts    rts
@term   ldd   #$0200                     ; b04a the terminator
        std   P.vx,y
        ldd   #0
        std   P.vy,y
        lda   P.bit,y                    ; b057 the real death signal
        ora   cpl.f30+1
        sta   cpl.f30+1
        ldd   P.cfg,y                    ; b05a
        subd  #2
        std   P.cfg,y
        ldd   P.f28,y                    ; b05e
        addd  #1
        std   P.f28,y
        rts

; 40:AB01 (A = 0) / 40:ADFB (A = 1), Y = the part
cpl.Volley
        sta   cpl.wSide
        ldd   cpl.plx                    ; ab01 player at or right of the part
        cmpd  P.x,y
        blo   @rts
        ldd   cpl.ply                    ; ab09 the vertical window
        addd  #$0010
        subd  P.y,y
        blo   @rts
        tst   cpl.wSide
        bne   >
        subd  #$0050
        bra   @w
!       subd  #$0030
@w      bhs   @rts
        ldd   P.c22,y                    ; ab19 the cadence
        subd  #1
        std   P.c22,y
        bne   @rts
        clra                             ; ab1e
        ldb   P.c20,y
        std   P.c22,y
        jsr   cpl.LaserFree              ; ab2a load_managed_object
        beq   @nofree
        ldd   P.x,y                      ; ab2f / ae29
        tst   cpl.wSide
        bne   >
        addd  #$0050
        bra   @x
!       addd  #$0010
@x      std   Z.x,x
        clr   Z.xf,x                     ; the arcade leaves its leftover
        pshs  x
        jsr   cpl.Draw                   ; ab38 / ae32
        puls  x
        andb  #$0E
        ldu   #cpl.PoolR
        tst   cpl.wSide
        beq   >
        ldu   #cpl.PoolL
!       ldd   b,u
        addd  P.y,y
        std   Z.y,x
        ldb   globals.difficulty         ; ab4c / ae46: by difficulty
        aslb
        ldu   #cpl.LaserVx
        ldd   b,u                        ; ab54
        std   Z.vx,x
        lda   cpl.wSide
        sta   Z.side,x
        lda   #1
        sta   Z.st,x
@rts    rts
@nofree pshs  x                          ; no room: the draw still happens,
        jsr   cpl.Draw                   ; the stream stays in step
        puls  x,pc

; X = a free laser record, Z clear if none
cpl.LaserFree
        ldx   #cpl.Lasers
        ldb   #cpl.NLASER
@l      lda   Z.st,x
        beq   @ok
        leax  Z.SZ,x
        decb
        bne   @l
        clrb                             ; Z = 1
        rts
@ok     lda   #1                         ; Z = 0
        rts

; 40:AE5C — two segments, Y = the left part
cpl.RollSpawn
        ldd   #-8                        ; ae5c the first one
        bsr   cpl.RollOne
        ldd   #-$28                      ; aea7 the second one
; D = its x offset from the part
cpl.RollOne
        std   cpl.wT
        jsr   cpl.Draw                   ; ae84 / aecf
        std   cpl.wT2
        jsr   cpl.Draw                   ; ae9c / aee7
        std   cpl.wDX
        jsr   cpl.RollFree
        beq   @rts
        ldd   P.x,y                      ; ae72 / aebd
        addd  cpl.wT
        std   W.x,x
        clr   W.xf,x                     ; leftover in the arcade (the bench)
        ldd   P.y,y                      ; ae7b +0x38
        addd  #$0038
        std   W.y,x
        clr   W.yf,x
        ldb   cpl.wT2                    ; ae89 vx = AH + 0x80 ...
        clra
        addd  #$0080
        pshs  d
        lda   cpl.wT2+1                  ; ae91 ... negated on AL bit 5
        anda  #$20
        puls  d
        beq   >
        coma
        comb
        addd  #1
!       std   W.vx,x
        lda   cpl.wDX+1                  ; aea1 ((AL << 8 | AH) & 0x1FF) + 0x280
        anda  #1
        ldb   cpl.wDX
        addd  #$0280
        std   W.w20,x
        lda   #1
        sta   W.st,x
        lda   cpl.rollPose               ; its pose: the arcade takes it from
        inca                             ; the record's address, we cycle
        anda  #3
        sta   cpl.rollPose
        sta   W.spr,x
@rts    rts

; X = a free rolling record, Z clear if none
cpl.RollFree
        ldx   #cpl.Rolls
        ldb   #cpl.NROLL
@l      lda   W.st,x
        beq   @ok
        leax  W.SZ,x
        decb
        bne   @l
        clrb                             ; Z = 1
        rts
@ok     lda   #1                         ; Z = 0
        rts

; 40:B073 the cascade walker, Y = the part
cpl.Cascade
        ldb   cpl.gc+1
        bitb  #1
        bne   @life
        bitb  #3                         ; b07a every 4 frames: SFX 0x52/0x53
        bne   >
        jsr   cpl.Draw
!       jsr   cpl.Draw                   ; b09b 25%: the big explosion
        andb  #6
        stb   cpl.wX
        pshs  y
        jsr   LoadObject_x
        puls  y
        beq   @next
        lda   #explosion.subtype.smallx3+explosion.sfx.cascade2
        ldb   cpl.wX
        bne   >
        lda   #explosion.subtype.big.brown+explosion.sfx.cascade2
!       ldb   #ObjID_explosion
        exg   a,b
        std   id,x
        pshs  x
        ldd   P.cl,y                     ; b0a7 at part + offset
        jsr   cpl.RomX
        ldd   ,x
        addd  P.x,y
        std   cpl.wDX
        ldd   2,x
        addd  P.y,y
        tfr   d,x
        ldd   cpl.wDX
        jsr   cpl.ToScreen               ; A = x, B = y (screen)
        puls  x
        jsr   cpl.SpawnAt
@next   ldd   P.cl,y                     ; b0bd
        addd  #4
        std   P.cl,y
        jsr   cpl.RomX
        ldd   ,x
        cmpd  #$8000
        bne   @life
        ldd   P.cl0,y                    ; b0ca wrap
        std   P.cl,y
@life   dec   P.life,y                   ; b0d7
        bne   >
        clr   P.st,y
!       rts

; X = a new object, A = x, B = y (screen, 0-based): its playfield position
cpl.SpawnAt
        pshs  b
        tfr   a,b
        clra
        addd  glb_camera_x_pos
        std   x_pos,x
        puls  b
        clra
        std   y_pos,x
        rts

;*******************************************************************************
; THE TURRETS — 40:AC4C, Y = the record
;*******************************************************************************
cpl.TurretTick
        lda   T.st,y
        beq   @rts
        lda   T.fire,y                   ; ac4c try_foe_fire if the gate is up
        beq   @pos
        ldd   T.c26,y                    ; f63a
        addd  #1
        std   T.c26,y
        cmpd  T.thr,y
        beq   @shot
        cmpd  T.rst,y
        blo   @pos
        ldd   #0
        std   T.c26,y
@shot   jsr   cpl.Shoot
@pos    ldx   T.par,y                    ; ac56 parent + offset
        ldd   P.x,x
        addd  T.ox,y
        std   T.x,y
        ldd   P.y,x
        addd  T.oy,y
        std   T.y,y
        jsr   cpl.DirToPlayer            ; ac6e
        stb   T.dir,y
        lsrb
        lsrb
        ldx   #cpl.TurretFire
        lda   b,x
        sta   T.fire,y
        ldx   T.par,y                    ; acad parent still itself ?
        lda   P.st,x
        cmpa  #1
        beq   @rts
        clr   T.st,y                     ; acce the turret blows up
        pshs  y
        jsr   LoadObject_x
        puls  y
        beq   @rts
        _ldd  ObjID_explosion,explosion.subtype.smallx2+explosion.sfx.turret
        std   id,x
        pshs  x
        ldd   T.x,y
        ldx   T.y,y
        jsr   cpl.ToScreen
        puls  x
        jmp   cpl.SpawnAt
@rts    rts

; create_foe_fire from the turret's puppet, at the turret's position of the
; previous frame (the arcade fires before it moves)
cpl.Shoot
        ldx   T.pup,y
        beq   @rts
        pshs  y,u
        ldd   T.x,y
        ldx   T.y,y
        jsr   cpl.ToScreen
        ldu   T.pup,y
        jsr   cpl.SpawnAtU
        ldu   T.pup,y
        lda   #3
        sta   fireDisplayDelay,u
        ldx   #player1
        stx   FoeFireTarget
        lda   Obj_Index_Page+ObjID_createFoeFire
        sta   PSR_Page
        ldd   Obj_Index_Address+2*ObjID_createFoeFire
        std   PSR_Address
        jsr   RunPgSubRoutine
        puls  y,u
@rts    rts

cpl.SpawnAtU
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
; THE LASERS — 40:E6AB / E6C0, A = the side to run (0 right, 1 left)
;*******************************************************************************
cpl.LaserRun
        sta   cpl.wSide
        ldy   #cpl.Lasers
        ldb   #cpl.NLASER
@l      pshs  b
        lda   Z.st,y
        cmpa  #2                         ; born this frame: not yet
        bne   @n
        lda   Z.side,y
        cmpa  cpl.wSide
        bne   @n
        leax  Z.x,y                      ; e6c0 move
        ldd   Z.vx,y
        jsr   cpl.Move
        ldd   Z.x,y
        ldx   Z.y,y
        jsr   cpl.Visible
        beq   @n
        clr   Z.st,y                     ; off screen: unload
@n      leay  Z.SZ,y
        puls  b
        decb
        bne   @l
        rts

;*******************************************************************************
; THE ROLLING LASER — 40:AEFB / AF6F, Y = the segment
;*******************************************************************************
cpl.RollTick
        leax  W.x,y
        ldd   W.vx,y
        jsr   cpl.Move
        leax  W.y,y
        ldd   W.w20,y
        jsr   cpl.Move
        lda   W.st,y
        cmpa  #2
        bne   >
        ldd   W.w20,y                    ; af7b phase 2: SUB before the probe
        subd  #$0010
        std   W.w20,y
!       jsr   cpl.RollTerrain            ; af22 the probe
        bne   @kill
        ldd   W.x,y                      ; af30
        ldx   W.y,y
        jsr   cpl.Visible
        bne   @kill
        lda   W.st,y
        cmpa  #1
        bne   @rts
        ldd   W.w20,y                    ; af49 SUB after; JC -> phase 2
        subd  #$0010
        bhs   >
        ldd   #0
        std   W.w20,y
        lda   #2
        sta   W.st,y
        rts
!       std   W.w20,y
@rts    rts
@kill   clr   W.st,y
        rts

; Z = 0 when the segment touches the terrain (fg, or the gum field)
cpl.RollTerrain
        ldd   W.x,y
        ldx   W.y,y
        jsr   cpl.ToScreen
        pshs  b
        tfr   a,b
        clra
        addd  glb_camera_x_pos
        std   terrainCollision.sensor.x
        puls  b
        clra
        std   terrainCollision.sensor.y
        pshs  y,u
        ldb   #1                         ; foreground
        jsr   terrainCollision.do
        tstb
        bne   @hit
        lda   globals.backgroundSolid
        beq   @hit
        ldb   #0                         ; background
        jsr   terrainCollision.do
        tstb
@hit    puls  y,u,pc

;*******************************************************************************
; THE TOOLS
;*******************************************************************************

; every draw passes here: the bench stops at compiler.Drawn and writes D
cpl.Draw
        jsr   cpl.Rand
compiler.Drawn
        rts

; 40:EDE9 random_ax — D = AH:AL (A = the old c, B = the new a)
cpl.Rand
        ldd   cpl.rng+1
        pshs  b
        sta   cpl.rng+2
        adda  ,s
        ldb   cpl.rng
        stb   cpl.rng+1
        sta   cpl.rng
        tfr   a,b
        puls  a,pc

; D = arcade address in cpl.ROM -> X
cpl.RomX
        subd  #cpl.ROM.BASE
        addd  #cpl.ROM
        tfr   d,x
        rts

; D = arcade address -> D = the word there
cpl.RomW
        jsr   cpl.RomX
        ldd   ,x
        rts

; X = position (int:2, frac:1), D = signed 8.8 (move_x_pos_8_8)
cpl.Move
        pshs  a
        addb  2,x
        stb   2,x
        puls  b
        sex
        adcb  1,x
        adca  ,x
        std   ,x
        rts

; is_visible_range 40:1D6B — D = x, X = y; Z = 1 when visible
cpl.Visible
        subd  #300
        blo   @no
        cmpd  #424
        bhs   @no
        tfr   x,d
        subd  #124
        blo   @no
        cmpd  #280
        bhs   @no
        clra                             ; Z = 1
        rts
@no     lda   #1                         ; Z = 0
        rts

; set_direction_to 40:1D89, from the turret Y to the player — B = code
cpl.DirToPlayer
        ldd   T.y,y
        addd  #8
        cmpd  cpl.ply
        blo   @above
        ldd   T.y,y
        subd  #8
        cmpd  cpl.ply
        bhs   @below
        ldd   T.x,y
        cmpd  cpl.plx
        bhs   >
        ldb   #$10
        rts
!       ldb   #$30
        rts
@above  ldd   T.x,y
        addd  #8
        cmpd  cpl.plx
        blo   @ne
        ldd   T.x,y
        subd  #8
        cmpd  cpl.plx
        bhs   @nw
        clrb
        rts
@below  ldd   T.x,y
        addd  #8
        cmpd  cpl.plx
        blo   @se
        ldd   T.x,y
        subd  #8
        cmpd  cpl.plx
        bhs   @sw
        ldb   #$20
        rts
@ne     ldd   cpl.plx
        subd  T.x,y
        std   cpl.wT
        ldd   cpl.ply
        subd  T.y,y
        ldx   #cpl.DirNE
        bra   @quad
@nw     ldd   T.x,y
        subd  cpl.plx
        std   cpl.wT
        ldd   cpl.ply
        subd  T.y,y
        ldx   #cpl.DirNW
        bra   @quad
@se     ldd   cpl.plx
        subd  T.x,y
        std   cpl.wT
        ldd   T.y,y
        subd  cpl.ply
        ldx   #cpl.DirSE
        bra   @quad
@sw     ldd   T.x,y
        subd  cpl.plx
        std   cpl.wT
        ldd   T.y,y
        subd  cpl.ply
        ldx   #cpl.DirSW
@quad   std   cpl.wT2
        ldd   cpl.wT
        subd  cpl.wT2
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
cpl.DirNE fcb   $04,$08,$0C
cpl.DirNW fcb   $3C,$38,$34
cpl.DirSE fcb   $1C,$18,$14
cpl.DirSW fcb   $24,$28,$2C

; D = x, X = y (arcade) -> A = x, B = y (screen, 0-based, clamped 0..255)
cpl.ToScreen
        subd  #320
        std   cpl.wT
        aslb
        rola
        addd  cpl.wT
        asra
        rorb
        asra
        rorb
        asra
        rorb
        addd  #8
        jsr   cpl.Clamp
        stb   cpl.wX
        tfr   x,d
        std   cpl.wT
        aslb
        rola
        addd  cpl.wT
        asra
        rorb
        asra
        rorb
        std   cpl.wT
        ldd   #297
        subd  cpl.wT
        jsr   cpl.Clamp
        lda   cpl.wX
        rts

cpl.Clamp
        tsta
        beq   @rts
        bmi   @lo
        ldb   #255
        rts
@lo     clrb
@rts    rts

; the player in arcade units: x = 320 + 2v + (v*171 >> 8) with v = xs - 8,
; y = w + (w*171 >> 9) with w = 297 - ys (exact, see bellmite/obj.asm)
cpl.PlayerArcade
        ldd   player1+x_pos
        subd  glb_camera_x_pos
        subd  #8
        bpl   >
        ldd   #0
!       tsta
        beq   >
        ldb   #255
!       stb   cpl.wX
        lda   #171
        mul
        tfr   a,b
        clra
        std   cpl.wT
        ldb   cpl.wX
        clra
        aslb
        rola
        addd  cpl.wT
        addd  #320
        std   cpl.plx
        ldb   player1+y_pos+1
        clra
        std   cpl.wT
        ldd   #297
        subd  cpl.wT
        std   cpl.wT
        lda   #171
        mul
        tst   cpl.wT
        beq   >
        addd  #171*256
!       lsra
        tfr   a,b
        clra
        addd  cpl.wT
        std   cpl.ply
        rts

; X = the part's box (in its puppet), or a dummy box without puppet
cpl.PartBox
        ldx   P.pup,y
        beq   @none
        leax  AABB_0,x
        rts
@none   ldx   #cpl.NoBox
        rts
cpl.NoBox fcb 40,0,0,0,0,0,0,0,0          ; p = 40: a part without puppet lives

; once per render, before the frames: a lost potential is a hit (0x1F
; frames of cooldown, aa7a); a rolling segment at 0 was shot or stopped
cpl.HitWatch
        ldy   #cpl.Parts
        ldb   #3
@p      pshs  b
        lda   P.st,y
        cmpa  #1
        bne   @np
        jsr   cpl.PartBox
        lda   AABB.p,x
        cmpa  P.pp,y
        bhs   @np
        sta   P.pp,y
        lda   #$1F
        sta   P.h32,y
@np     leay  P.SZ,y
        puls  b
        decb
        bne   @p
        ldy   #cpl.Rolls
        ldb   #cpl.NROLL
@w      lda   W.st,y
        beq   @nw
        ldx   W.pup,y
        beq   @nw
        lda   AABB_0+AABB.p,x
        bne   @nw
        clr   W.st,y
@nw     leay  W.SZ,y
        decb
        bne   @w
        rts

;*******************************************************************************
; PUBLICATION — once per render: puppets created, placed, shown or released
;*******************************************************************************
cpl.Publish
        clr   weaponPodImmune
        ldy   #cpl.Parts                 ; --- the parts
        ldb   #0
@p      pshs  b
        lda   P.st,y
        cmpa  #1
        bne   @pgone
        lda   #1
        sta   weaponPodImmune            ; a live part: pod immunity (v4)
        ldx   P.pup,y
        bne   >
        lda   #ObjID_compilerpart
        jsr   cpl.PupNew
        beq   @pn
        stx   P.pup,y
        ldb   ,s
        aslb
        ldu   #cpl.images
        ldd   b,u
        std   image_set,x
        ldb   ,s
        ldu   #cpl.prio
        lda   b,u
        sta   priority,x
        lda   #40                        ; a7a4 HP_max 0x28
        sta   cpl.boxP
        ldb   ,s
        aslb
        ldu   #cpl.hitbox
        ldd   b,u
        pshs  y
        ldy   #AABB_list_ennemy
        jsr   cpl.BoxAdd
        puls  y
!       ldd   P.f28,y                    ; the fade path: no more collision
        beq   >
        jsr   cpl.BoxOff
!       ldd   P.x,y
        ldx   P.y,y
        jsr   cpl.ToScreen
        ldx   P.pup,y
        jsr   cpl.Place
        ; the hit flash: the arcade paints the flash palette on gc & 4
        lda   P.h32,y
        beq   @pn
        lda   cpl.gc+1
        bita  #4
        beq   @pn
        clr   pp.show,x
        bra   @pn
@pgone  ldx   P.pup,y                    ; gone or in cascade: no picture
        beq   @pn
        jsr   cpl.PupKill
        clr   P.pup,y
        clr   P.pup+1,y
@pn     leay  P.SZ,y
        puls  b
        incb
        cmpb  #3
        lblo  @p
        ldy   #cpl.Turrets               ; --- the turrets
        ldb   #3
@t      pshs  b
        lda   T.st,y
        bne   >
        ldx   T.pup,y
        beq   @tn
        jsr   cpl.PupKill
        clr   T.pup,y
        clr   T.pup+1,y
        bra   @tn
!       ldx   T.pup,y
        bne   >
        lda   #ObjID_compilerturret
        jsr   cpl.PupNew
        beq   @tn
        stx   T.pup,y
        lda   #cpl.PRIO_TURRET
        sta   priority,x
        pshs  x,y,u                      ; its fire preset: createFoeFire
        tfr   x,u                        ; reads fireVelocityPreset
        ldb   T.pre,y
        _loadFirePreset
        puls  x,y,u
!       ldb   T.dir,y
        lsrb                             ; /4 then *2: a pointer per direction
        ldu   #cpl.turret.images
        ldd   b,u
        std   image_set,x
        ldd   T.x,y
        ldx   T.y,y
        jsr   cpl.ToScreen
        ldx   T.pup,y
        jsr   cpl.Place
        ldu   T.par,y                    ; the parent's flash, ac84
        lda   P.h32,u
        beq   @tn
        lda   cpl.gc+1
        bita  #4
        beq   @tn
        clr   pp.show,x
@tn     leay  T.SZ,y
        puls  b
        decb
        bne   @t
        ldy   #cpl.Lasers                ; --- the lasers
        ldb   #cpl.NLASER
@z      pshs  b
        lda   Z.st,y
        bne   >
        ldx   Z.pup,y
        beq   @zn
        jsr   cpl.PupKill
        clr   Z.pup,y
        clr   Z.pup+1,y
        bra   @zn
!       ldx   Z.pup,y
        bne   >
        lda   #ObjID_compilerlaser
        jsr   cpl.PupNew
        beq   @zn
        stx   Z.pup,y
        lda   #5
        ldb   Z.side,y
        beq   @pr
        lda   #8
@pr     sta   priority,x
        lda   #$FF                       ; never worn out: it only kills
        sta   cpl.boxP
        _ldd  compilerlaser_hitbox_x,compilerlaser_hitbox_y
        pshs  y
        ldy   #AABB_list_ennemy_unkillable
        jsr   cpl.BoxAdd
        puls  y
!       lda   cpl.gc+1                   ; e6c0 the frame: gc & 6
        anda  #6
        ldu   #cpl.laser.images
        ldd   a,u
        std   image_set,x
        ldd   Z.x,y
        ldx   Z.y,y
        jsr   cpl.ToScreen
        ldx   Z.pup,y
        jsr   cpl.Place
@zn     leay  Z.SZ,y
        puls  b
        decb
        bne   @z
        ldy   #cpl.Rolls                 ; --- the rolling lasers
        ldb   #cpl.NROLL
@w      pshs  b
        lda   W.st,y
        bne   >
        ldx   W.pup,y
        beq   @wn
        jsr   cpl.PupKill
        clr   W.pup,y
        clr   W.pup+1,y
        bra   @wn
!       ldx   W.pup,y
        bne   >
        lda   #ObjID_compilerwave
        jsr   cpl.PupNew
        beq   @wn
        stx   W.pup,y
        lda   #cpl.PRIO_WAVE
        sta   priority,x
        ldb   W.spr,y
        aslb
        ldu   #cpl.wave.images
        ldd   b,u
        std   image_set,x
        lda   #1
        sta   cpl.boxP
        _ldd  compilerwave_hitbox_x,compilerwave_hitbox_y
        pshs  y
        ldy   #AABB_list_foefire         ; phase 1: the pod stops it
        jsr   cpl.BoxAdd
        puls  y
!       lda   W.st,y                     ; phase 2: the weapons can shoot it
        cmpa  #2
        bne   >
        ldd   pp.list,x
        cmpd  #AABB_list_ennemy
        beq   >
        jsr   cpl.BoxOff
        lda   #1
        sta   cpl.boxP
        _ldd  compilerwave_hitbox_x,compilerwave_hitbox_y
        pshs  y
        ldy   #AABB_list_ennemy
        jsr   cpl.BoxAdd
        puls  y
!       ldd   W.x,y
        ldx   W.y,y
        jsr   cpl.ToScreen
        ldx   W.pup,y
        jsr   cpl.Place
@wn     leay  W.SZ,y
        puls  b
        decb
        bne   @w
        lda   cpl.ost                    ; the dome, while the boss lives
        cmpa  #O_GONE
        beq   >
        jsr   cpl.dome.tick
!       rts

; A = the ObjID -> X = a new puppet, Z clear if the pool is full
cpl.PupNew
        pshs  a,y
        jsr   LoadObject_x
        beq   @full
        puls  a
        sta   id,x
        lda   #2
        sta   routine,x
        lda   #render_playfieldcoord_mask
        sta   render_flags,x
        clr   pp.show,x
        clr   pp.kill,x
        clr   pp.list,x
        clr   pp.list+1,x
        puls  y
        andcc #$FB                       ; Z = 0
        rts
@full   puls  a,y
        orcc  #4                         ; Z = 1
        rts

; X = the puppet, A = x, B = y (screen 0-based): its position, its box, shown
cpl.Place
        pshs  a,b
        tfr   a,b
        clra
        addd  glb_camera_x_pos
        std   x_pos,x
        clra
        ldb   1,s
        std   y_pos,x
        puls  a,b
        cmpa  #250                       ; the box, parked off screen when the
        bhs   @park                      ; centre clamps
        cmpb  #250
        bhs   @park
        sta   AABB_0+AABB.cx,x
        stb   AABB_0+AABB.cy,x
        bra   @show
@park   lda   #220
        sta   AABB_0+AABB.cx,x
        sta   AABB_0+AABB.cy,x
@show   lda   #1
        sta   pp.show,x
        rts

; X = the puppet: it removes its box and goes, next time it runs
cpl.PupKill
        lda   #1
        sta   pp.kill,x
        clr   pp.show,x
        rts

; X = the puppet, D = rx:ry, Y = the list, cpl.boxP = the potential
cpl.BoxAdd
        pshs  x,y,u
        leax  AABB_0,x
        pshs  d
        ldb   #sizeof{AABB}
!       clr   ,x+
        decb
        bne   <
        leax  -sizeof{AABB},x
        puls  d
        std   AABB.rx,x
        lda   cpl.boxP
        sta   AABB.p,x
        lda   #220
        sta   AABB.cx,x
        sta   AABB.cy,x
        jsr   Collision_AddAABB
        puls  x,y,u
        sty   pp.list,x
        rts

; X = the puppet: its box leaves its list
cpl.BoxOff
        pshs  x,y,u
        ldy   pp.list,x
        beq   @rts
        sty   Collision_Remove_1
        sty   Collision_Remove_3
        leay  2,y
        sty   Collision_Remove_2
        leax  AABB_0,x
        jsr   Collision_RemoveAABB
        ldx   ,s
        clr   pp.list,x
        clr   pp.list+1,x
@rts    puls  x,y,u,pc

;*******************************************************************************
; THE PUPPET — every actor's picture and box; the manager does the thinking
;*******************************************************************************
cpl.Puppet
        lda   pp.kill,u
        beq   >
        tfr   u,x
        jsr   cpl.BoxOff
        jmp   DeleteObject
!       lda   pp.show,u
        beq   >
        jmp   DisplaySprite
!       rts

;*******************************************************************************
; THE DOME — the author's pulse (dome-pulse.asm), on the manager's clock
;*******************************************************************************
cpl.dome.tick
        lda   cpl.dome.left
        suba  gfxlock.frameDrop.count
        bhi   @garde
        ldb   cpl.dome.step
        incb
        cmpb  #cpl.dome.CYCLE
        blo   >
        clrb
!       stb   cpl.dome.step
        aslb
        ldx   #cpl.dome.seq
        abx
        lda   1,x
        sta   cpl.dome.left
        ldb   ,x
        lda   #6
        mul
        ldx   #cpl.dome.pal
        leax  d,x
        pshs  u
        ldu   #Pal_buffer+12*2
        ldy   ,x++
        sty   ,u++
        ldy   ,x++
        sty   ,u++
        ldy   ,x
        sty   ,u
        puls  u
        clr   PalRefresh
        rts
@garde  sta   cpl.dome.left
        rts

;*******************************************************************************
; THE DATA (page), cleared at every Init
;*******************************************************************************
cpl.nfr      fcb   0
cpl.pending  fcb   0
cpl.savedVel fdb   0
cpl.Data
cpl.gc       fdb   0                     ; the arcade global counter
cpl.rng      fcb   0,0,0                 ; random_ax state
cpl.plx      fdb   0                     ; the player, arcade units
cpl.ply      fdb   0
cpl.ost      fcb   0                     ; orchestrator state
cpl.v10      fcb   0                     ; variant slot offset (+0x10)
cpl.f30      fdb   0                     ; death mask (+0x30)
cpl.f32      fdb   0                     ; deferred expiries (+0x32)
cpl.f34      fcb   0                     ; armed (+0x34)
cpl.c36      fdb   0                     ; death countdown (+0x36)
cpl.dome.step fcb  0
cpl.dome.left fcb  0
cpl.wSide    fcb   0
cpl.wX       fcb   0
cpl.wT       fdb   0
cpl.wT2      fdb   0
cpl.wDX      fdb   0
cpl.boxP     fcb   0
cpl.rollPose fcb   0
cpl.Parts    fill  0,3*P.SZ              ; right, bottom, left
cpl.Turrets  fill  0,3*T.SZ              ; list order: bottom #1, left, bottom #2
cpl.Lasers   fill  0,cpl.NLASER*Z.SZ
cpl.Rolls    fill  0,cpl.NROLL*W.SZ
cpl.DataEnd
