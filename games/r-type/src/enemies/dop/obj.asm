;*******************************************************************************
; dopswarm — the stage 6 boss, a swarm of Dops, ported 1:1 from the arcade
;
; PORTING SHEET (source: Ghidra `maincpu`, subsystems dop_swarm_boss, enemy_dop)
; ------------------------------------------------------------------------------
;   40:B0E1 create_dop_swarm_boss ......... dopswarm.Init (frame 0)
;   40:B111 tick_dop_swarm_boss_manager ... dsw.Manager
;   40:B18F end_boss_after_dop_swarm ...... dsw.EndArm
;   40:B1AC tick_dop_swarm_end_countdown .. dsw.End
;   40:5F3C run_dop ....................... dsw.Dop
;   40:6048 dop_die / 40:6035 unload ...... dsw.DopDie / dsw.DopUnload
;   40:6081 collision_with_dop ............ dsw.HitWatch + the two boxes
;   40:1E6C probe_foreground_tile ......... dsw.Solid (see THE TERRAIN)
;
; THE BOSS IS THE SWARM. A manager releases sixteen Dops at (0x200, 0x190),
; one every 100 frames (the script at 1000:C5E3), and ends the stage at frame
; 0x800 whatever the player did: killing Dops scores, it does not shorten the
; fight. A Dop walks along one of four "lanes" (right, down, left, up) at a
; fixed speed and turns — clockwise for variant A, the other way for B — when
; one of three look-ahead probes finds a solid tile. It never draws a random
; number: its whole path is written in the tile map.
;
; THE PORT RUNS IN ARCADE SPACE and ONE ARCADE FRAME AT A TIME, in the
; arcade's list order (the manager 0x1000, then the Dops 0x4030). Positions are
; the arcade's 16.8, speeds its 8.8, tables a raw copy of the ROM (tables.asm,
; tools/gen_dopswarm.py). Only the publication converts to the screen.
;
; THE TERRAIN. The probe reads the stage 6 collision map, one bit per arcade
; 8x8 tile — the arena is its last 48 columns, from column 335, rows aligned
; with the arcade's. tools/fidelity/models/dopswarm_model.py replays the whole
; MAME fight on that map and on a dump of the arcade's tile RAM: the two give
; the same answers. The map lives in the collision region, in the cartridge
; window this code runs from: the arena's slice is assembled here from the
; same file (INCLUDEBIN with offsets, no copy of the asset). The camera of
; the fight is the arcade's (x = 124, its sub-tile remainder 4 folded in).
;
; DEVIATIONS (V2-DEVIATION):
; - collision runs once per render (engine); the arcade's front box takes no
;   damage (40:6088 saves and restores it): here it is an INVINCIBLE box
;   (negative potential), the rear one carries the 10 points;
; - palettes are not swapped: the blink shows ONE whitened picture a facing
;   (pose 0, the port's hit-flash idiom — sixteen poses do not fit the page)
;   where the arcade paints palette 0x51; the 64-frame body pulse (40:5F3C)
;   is not played;
; - music 0x19/0x1A/0x1B: the bossmusic object and the end sequence carry
;   them; the palette blackout of 40:B199 is the end sequence's fade;
; - the arcade freezes the whole game at 0x800 (0x2FC4); here only the swarm
;   stops, the end sequence takes over at the end-level flag.
;*******************************************************************************

; --- the manager: state values ------------------------------------------------
dsw.M_RUN     equ 1                  ; 40:B111
dsw.M_END     equ 2                  ; 40:B1AC
dsw.M_GONE    equ 3                  ; unloaded

; --- a Dop record (page data) -------------------------------------------------
D.st          equ 0                  ; 0 free, 1 live
D.x           equ 1                  ; 1,2 int   (arcade +4)
D.xf          equ 3                  ; frac      (arcade +3)
D.y           equ 4                  ; 4,5 int   (arcade +8)
D.yf          equ 6                  ; frac      (arcade +7)
D.lane        equ 7                  ; 0..3 (+0x20)
D.A           equ 8                  ; turn clockwise (+0x1E)
D.B           equ 9                  ; facing left, look-ahead B (+0x2E)
D.vs          equ 10                 ; speed set offset (+0x22)
D.bl          equ 11                 ; hit blink (+0x11)
D.show        equ 12                 ; 1 = the last frame painted the blink
D.pp          equ 13                 ; rear box potential seen last render
D.id          equ 14                 ; record index: its boxes and its slot
D.SZ          equ 15

dsw.NDOP      equ 8                  ; at most five live at once (400 frames)
dsw.SLOTSZ    equ 5                  ; [on, x_pixel, y_pixel, routine(2)]

dsw.HP        equ 10                 ; 40:B169 HP_max
dsw.BLINK     equ $1F                ; 40:60B5
dsw.END       equ $0800              ; 40:B11B
dsw.COUNT     equ $90                ; 40:B1A1

; the boxes, from 1000:2B20 (arcade px, scaled 3/8 and 3/4): the armored
; front and the pink rear, centred on the Dop's x + offset
dsw.FRONT_RX  equ 12                 ; -36..28 : 64 px wide
dsw.FRONT_RY  equ 18                 ; -24..24
dsw.FRONT_DX  equ 4                  ; centre -4 (A) / +4 (B), arcade px
dsw.REAR_RX   equ 2                  ; 28..40 : 12 px wide
dsw.REAR_RY   equ 10                 ; -14..14
dsw.REAR_DX   equ 34                 ; centre +34 (A) / -34 (B), arcade px

; the probe's frame: the arcade camera of the fight (sub-tile remainder 4),
; and the first map column of the slice assembled below
dsw.CAM_SUB   equ 4
dsw.COL0      equ 328                ; = byte 41 of a 48-byte map row
dsw.SLICE     equ 7                  ; bytes per row: columns 328..383
dsw.ROWS      equ 30

dopswarm.boxes EXTERNAL              ; resident, 2 * dsw.NDOP * sizeof{AABB}

;*******************************************************************************
; THE MANAGER
;*******************************************************************************
dopswarm.Object
        lda   routine,u
        asla
        ldx   #dsw.Routines
        jmp   [a,x]
dsw.Routines
        fdb   dopswarm.Init
        fdb   dopswarm.Live
        fdb   dopswarm.Done

; -----------------------------------------------------------------------------
; Init — 40:B0E1 create_dop_swarm_boss, the creation frame (frame 0)
; -----------------------------------------------------------------------------
dopswarm.Init
        ldb   wave_frame_drop,u          ; aliases anim_frame_duration
        stb   dsw.pending
        ldx   #dsw.Data                  ; a checkpoint replays the stage
        ldd   #dsw.DataEnd-dsw.Data      ; without reloading this page
@clr    clr   ,x+
        subd  #1
        bne   @clr
        lda   #dsw.M_RUN                 ; b0e7 tick = the manager
        sta   dsw.st
        ldd   #dsw.Script                ; b0ec the script, the cursor at 0
        std   dsw.ptr
        ldd   scroll_vel                 ; b0f6 the scroll halts
        std   dsw.savedVel
        ldd   #0
        std   scroll_vel
        ; the arcade global counter at this frame (the bench rewrites it)
        ldd   gfxlock.frame.gameCount
        subb  dsw.pending
        sbca  #0
        std   dsw.gc
        ; the grouped renderer
        jsr   LoadObject_x
        beq   >
        lda   #ObjID_dopswarm_render
        sta   id,x
!       inc   routine,u
dopswarm.Seeded                      ; test hook: dsw.gc is final here
        ldb   dsw.pending
        bra   dsw.Advance

; -----------------------------------------------------------------------------
; Live — run the arcade frames elapsed since the last render, then publish
; -----------------------------------------------------------------------------
dopswarm.Live
        jsr   dsw.HitWatch
        ldb   gfxlock.frameDrop.count
dsw.Advance                          ; B = arcade frames to run
        pshs  u
        stb   dsw.nfr
        beq   @pub
@frame  jsr   dsw.Frame
        dec   dsw.nfr
        bne   @frame
@pub    jsr   dsw.Publish
        puls  u
dopswarm.Sample                      ; test hook: one render's state is final
        lda   dsw.st
        cmpa  #dsw.M_GONE
        bne   @rts
        lda   #2                         ; every Dop left with the freeze
        sta   routine,u
@rts    rts

dopswarm.Done
        jmp   UnloadObject_u             ; never displayed itself

;*******************************************************************************
; ONE ARCADE FRAME
;*******************************************************************************
dsw.Frame
        ldd   dsw.gc                     ; 40:0219 ++global_counter
        addd  #1
        std   dsw.gc
dopswarm.Tick                        ; test hook: frame dsw.gc, before any actor
        lda   dsw.st                     ; the manager (priority 0x1000)
        cmpa  #dsw.M_RUN
        bne   >
        jsr   dsw.Manager
        bra   @dops
!       cmpa  #dsw.M_END
        bne   @dops
        jsr   dsw.End
@dops   ldy   #dsw.Dops                  ; the Dops (0x4030), a newborn too
@l      lda   D.st,y
        beq   @n
        jsr   dsw.Dop
@n      leay  D.SZ,y
        cmpy  #dsw.DopsEnd
        blo   @l
        rts

; -----------------------------------------------------------------------------
; 40:B111 the manager
; -----------------------------------------------------------------------------
dsw.Manager
        ldd   dsw.cur                    ; b111 ++cursor
        addd  #1
        std   dsw.cur
        cmpd  #dsw.END                   ; b11b
        bhs   dsw.EndArm
        ldx   dsw.ptr                    ; b122 the next entry due ?
        cmpd  ,x
        blo   @rts
        ldd   2,x                        ; b12d its token
        std   dsw.wT
        leax  4,x                        ; b18a the cursor moves on, spawned
        stx   dsw.ptr                    ; or not
        ldy   #dsw.Dops                  ; b138 load_managed_object
        clrb
@f      lda   D.st,y
        beq   @new
        incb
        leay  D.SZ,y
        cmpy  #dsw.DopsEnd
        blo   @f
@rts    rts
@new    stb   D.id,y                     ; its index: its boxes, its slot
        inc   D.st,y
        clr   D.A,y                      ; b13e token & 0x100 -> variant A
        lda   dsw.wT
        bita  #$01
        beq   >
        inc   D.A,y
!       clr   D.B,y                      ; b14b token & 0x40 -> variant B
        ldb   dsw.wT+1
        bitb  #$40
        beq   >
        inc   D.B,y
!       lsrb                             ; b158 load_state_preset_4 :
        lsrb                             ; bits 4-5 of the token
        lsrb
        lsrb
        andb  #3
        ldx   #dsw.VelSet
        lda   b,x
        sta   D.vs,y
        ldd   #$0200                     ; b15b (0x200, 0x190)
        std   D.x,y
        ldd   #$0190
        std   D.y,y
        clr   D.xf,y                     ; leftovers in the arcade (the bench)
        clr   D.yf,y
        lda   #1                         ; b165 lane 1: down
        sta   D.lane,y
        clr   D.bl,y                     ; b175
        clr   D.show,y
        lda   #dsw.HP                    ; b169
        sta   D.pp,y
        jmp   dsw.BoxesIn

; -----------------------------------------------------------------------------
; 40:B18F end_boss_after_dop_swarm, then 40:B1AC the 144-frame countdown
; -----------------------------------------------------------------------------
dsw.EndArm
        ldd   #dsw.COUNT                 ; b1a1
        std   dsw.c30
        lda   #dsw.M_END                 ; b1a6
        sta   dsw.st
        lda   #1                         ; b18f game_tick_disable: the Dops
        sta   dsw.freeze                 ; unload this very frame
        rts

dsw.End
        ldd   dsw.c30                    ; b1ac
        subd  #1
        std   dsw.c30
        beq   @fin
        cmpd  #$0080                     ; b1b1 the end-level flag
        bne   @rts
        lda   #1
        sta   globals.bossDefeated
@rts    rts
@fin    lda   #dsw.M_GONE                ; b1c8 the autoscroll restarts
        sta   dsw.st
        ldd   dsw.savedVel
        std   scroll_vel
        rts

;*******************************************************************************
; THE DOP — 40:5F3C run_dop, Y = the record all along
;*******************************************************************************
dsw.Dop
        lda   dsw.freeze                 ; 5f5c the freeze: silent unload
        lbne  dsw.DopUnload
        lda   D.lane,y                   ; 5f66 the speed of this lane
        asla
        asla
        adda  D.vs,y
        ldx   #dsw.Vel
        leax  a,x
        pshs  x
        ldd   ,x
        leax  D.x,y
        jsr   dsw.Move
        puls  x
        ldd   2,x
        leax  D.y,y
        jsr   dsw.Move
        ; 5f84 + scroll_amount: zero, the manager halted the scroll
        ; 5f96 the blink: counted on the frames where blink & frame bits
        ; ((counter & 0x18) >> 1) is not zero
        clr   D.show,y
        lda   D.bl,y
        beq   @col
        ldb   dsw.gc+1
        andb  #$18
        lsrb
        stb   dsw.wT
        anda  dsw.wT
        beq   @col
        dec   D.bl,y                     ; 5fa9
        lda   D.bl,y
        bita  #4                         ; 5fac bit 2 clear: the blink picture
        bne   @col
        inc   D.show,y
@col    lda   D.id,y                     ; 5fca damage >= 10 ?
        jsr   dsw.RearBox
        lda   AABB.p,x
        lbeq  dsw.DopDie
        ldd   D.x,y                      ; 5fd0 is_visible_range
        subd  #300
        cmpd  #424
        lbhs  dsw.DopUnload
        ldd   D.y,y
        subd  #124
        cmpd  #280
        lbhs  dsw.DopUnload
        ; 5fd5 the look-ahead: three probes, the position kept
        lda   D.lane,y
        asla
        asla
        asla
        tst   D.B,y
        beq   >
        adda  #$20
!       ldx   #dsw.Look
        leax  a,x
        ldd   D.x,y                      ; 6003 the first step
        addd  ,x
        std   dsw.px
        ldd   D.y,y
        addd  2,x
        std   dsw.py
        lda   #3                         ; 6009
        sta   dsw.wN
@probe  ldd   dsw.px                     ; 6012 only below x 0x2C0
        cmpd  #$02C0
        bhs   @step
        jsr   dsw.Solid
        bne   @turn                      ; 6025 a solid tile ahead
@step   ldd   dsw.px                     ; 601f the next step
        addd  4,x
        std   dsw.px
        ldd   dsw.py
        addd  6,x
        std   dsw.py
        dec   dsw.wN
        bne   @probe
        rts
@turn   lda   D.lane,y                   ; 606b A turns up the lanes, B down
        tst   D.A,y
        beq   >
        inca
        bra   @and
!       deca
@and    anda  #3
        sta   D.lane,y
        rts

; 40:6048 dop_die: score, the big grey-brown explosion
dsw.DopDie
        pshs  y
        ldb   #dop_scoreIdx              ; 6057 score 0x8708
        jsr   AwardScore
        jsr   LoadObject_x               ; 6065 tick := 0xE817
        puls  y
        beq   dsw.DopUnload
        _ldd  ObjID_explosion,explosion.subtype.big.brown+explosion.sfx.big
        std   id,x
        pshs  y
        ldd   D.x,y
        ldy   D.y,y
        jsr   dsw.ToScreen
        puls  y
        pshs  b
        tfr   a,b
        clra
        addd  glb_camera_x_pos
        std   x_pos,x
        puls  b
        clra
        std   y_pos,x
; 40:6035 the silent unload
dsw.DopUnload
        clr   D.st,y
        jmp   dsw.BoxesOut

; -----------------------------------------------------------------------------
; 40:1E6C probe_foreground_tile on the stage map — Z clear when the cell
; holding (dsw.px, dsw.py) is solid. X kept.
;   column = ((x + 4 - 320) asr 3) + 335, row = (0x17F - y) >> 3 (0 above)
; -----------------------------------------------------------------------------
dsw.Solid
        pshs  x
        ldd   dsw.px
        addd  #dsw.CAM_SUB-320
        asra
        rorb
        asra
        rorb
        asra
        rorb
        addd  #335-dsw.COL0              ; the column in the slice
        cmpd  #dsw.SLICE*8
        bhs   @empty
        stb   dsw.wX
        ldd   #$017F
        subd  dsw.py
        bcc   >
        ldd   #0                         ; 1e9a above the map: row 0
!       lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        cmpd  #dsw.ROWS
        bhs   @empty
        lda   #dsw.SLICE
        mul
        ldx   #dsw.Map
        abx
        ldb   dsw.wX
        lsrb
        lsrb
        lsrb
        abx
        ldb   dsw.wX
        andb  #7
        lda   #$80
!       tstb
        beq   >
        lsra
        decb
        bra   <
!       anda  ,x
        puls  x,pc
@empty  clra                             ; Z set: no wall
        puls  x,pc

;*******************************************************************************
; THE TOOLS
;*******************************************************************************

; move_x/y_pos_8_8: X = the position (int:2, frac:1), D = signed 8.8
dsw.Move
        pshs  a
        addb  2,x
        stb   2,x
        puls  b
        sex
        adcb  1,x
        adca  ,x
        std   ,x
        rts

; D = arcade x, Y = arcade y -> A = x, B = y on the screen (0-based, clamped)
dsw.ToScreen
        subd  #320
        std   dsw.wT
        aslb
        rola
        addd  dsw.wT                     ; *3
        asra
        rorb
        asra
        rorb
        asra
        rorb                             ; sar 3
        addd  #8
        jsr   dsw.Clamp
        stb   dsw.wX
        tfr   y,d
        std   dsw.wT
        aslb
        rola
        addd  dsw.wT
        asra
        rorb
        asra
        rorb                             ; (y*3) sar 2
        std   dsw.wT
        ldd   #297
        subd  dsw.wT
        jsr   dsw.Clamp
        lda   dsw.wX
        rts

dsw.Clamp
        tsta
        beq   @rts
        bmi   @lo
        ldb   #255
        rts
@lo     clrb
@rts    rts

; A = record index -> X = its front box (2n) / its rear box (2n+1)
dsw.FrontBox
        asla
        bra   dsw.BoxN
dsw.RearBox
        asla
        inca
dsw.BoxN
        ldb   #sizeof{AABB}
        mul
        addd  #dopswarm.boxes
        tfr   d,x
        rts

; both boxes of the record Y join the enemy list, cleaned first (manager-owned
; boxes: prev and next MUST be blank, see the bug manager)
dsw.BoxesIn
        lda   D.id,y
        jsr   dsw.FrontBox
        ldd   #dsw.FRONT_RX*256+dsw.FRONT_RY
        std   dsw.wT
        lda   #-1                        ; invincible: shots die on it
        jsr   dsw.BoxInsert
        lda   D.id,y
        jsr   dsw.RearBox
        ldd   #dsw.REAR_RX*256+dsw.REAR_RY
        std   dsw.wT
        lda   #dsw.HP
; X = the box, A = its potential, dsw.wT = rx:ry
dsw.BoxInsert
        pshs  a,u,y
        ldb   #sizeof{AABB}
!       clr   ,x+
        decb
        bne   <
        leax  -sizeof{AABB},x
        ldd   dsw.wT
        sta   AABB.rx,x
        stb   AABB.ry,x
        lda   #220                       ; parked off screen until published
        sta   AABB.cx,x
        sta   AABB.cy,x
        lda   ,s
        sta   AABB.p,x
        ldy   #AABB_list_ennemy
        jsr   Collision_AddAABB
        puls  a,u,y,pc

dsw.BoxesOut
        lda   D.id,y
        jsr   dsw.FrontBox
        jsr   dsw.BoxRemove
        lda   D.id,y
        jsr   dsw.RearBox
dsw.BoxRemove
        pshs  u,y
        ldy   #AABB_list_ennemy
        sty   Collision_Remove_1
        sty   Collision_Remove_3
        leay  2,y
        sty   Collision_Remove_2
        jsr   Collision_RemoveAABB
        puls  u,y,pc

; -----------------------------------------------------------------------------
; HitWatch — once per render, before the frames: a rear potential that dropped
; is a hit (40:60B5 latches the blink for 0x1F frames)
; -----------------------------------------------------------------------------
dsw.HitWatch
        ldy   #dsw.Dops
@l      lda   D.st,y
        beq   @n
        lda   D.id,y
        jsr   dsw.RearBox
        lda   AABB.p,x
        cmpa  D.pp,y
        bhs   @n
        sta   D.pp,y
        lda   #dsw.BLINK
        sta   D.bl,y
@n      leay  D.SZ,y
        cmpy  #dsw.DopsEnd
        blo   @l
        rts

;*******************************************************************************
; PUBLICATION — once per render: slots for the renderer, boxes for the engine
;*******************************************************************************
dsw.Publish
        ldy   #dsw.Dops
        ldu   #dsw.Slots
@d      lda   D.st,y
        bne   >
        clr   ,u
        lbra  @n
!       pshs  y
        ldd   D.x,y
        ldy   D.y,y
        jsr   dsw.ToScreen
        puls  y
        std   dsw.wXY
        ; 5f96 the picture: (counter & 0x18) >> 3, facing right (A) or left
        ; (B), the white one on a blink frame
        lda   dsw.gc+1
        anda  #$18
        lsra
        lsra                             ; *2 (fdb table)
        ldx   #dsw.SetsR
        tst   D.B,y
        beq   >
        ldx   #dsw.SetsL
!       tst   D.show,y
        beq   >
        clra                             ; the blink: one picture a facing
        leax  8,x
!       ldx   a,x
        pshs  y
        tfr   u,y
        ldd   dsw.wXY
        jsr   dsw.SlotPublish
        puls  y
        ; 6081 the boxes only once the Dop is in (x < 0x2B0)
        ldd   D.x,y
        cmpd  #$02B0
        bhs   @park
        ldd   #dsw.FRONT_DX              ; the front: -4 (A) / +4 (B)
        tst   D.B,y
        bne   >
        ldd   #-dsw.FRONT_DX
!       addd  D.x,y
        pshs  y
        ldy   D.y,y
        jsr   dsw.ToScreen
        puls  y
        std   dsw.wXY
        lda   D.id,y
        jsr   dsw.FrontBox
        ldd   dsw.wXY
        jsr   dsw.BoxPlace
        ldd   #-dsw.REAR_DX              ; the rear: +34 (A) / -34 (B)
        tst   D.B,y
        bne   >
        ldd   #dsw.REAR_DX
!       addd  D.x,y
        pshs  y
        ldy   D.y,y
        jsr   dsw.ToScreen
        puls  y
        std   dsw.wXY
        lda   D.id,y
        jsr   dsw.RearBox
        ldd   dsw.wXY
        jsr   dsw.BoxPlace
        bra   @n
@park   lda   D.id,y
        jsr   dsw.FrontBox
        ldd   #220*256+220
        jsr   dsw.BoxPlace
        lda   D.id,y
        jsr   dsw.RearBox
        ldd   #220*256+220
        jsr   dsw.BoxPlace
@n      leay  D.SZ,y
        leau  dsw.SLOTSZ,u
        cmpy  #dsw.DopsEnd
        lblo  @d
        rts

; A = x, B = y (screen 0-based), X = imageset, Y = slot
dsw.SlotPublish
        adda  #screen_left
        addb  #screen_top
        pshs  a,b
        _sprite.cull dsw.SlotPublish.off
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
dsw.SlotPublish.off
        clr   ,y
        puls  a,b,pc

; the box X centred on (A, B), screen 0-based ; parked off screen when the
; centre clamps
dsw.BoxPlace
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

dsw.SetsR
        fdb   set_dop_right_0,set_dop_right_1,set_dop_right_2,set_dop_right_3
        fdb   set_dop_righthit
dsw.SetsL
        fdb   set_dop_left_0,set_dop_left_1,set_dop_left_2,set_dop_left_3
        fdb   set_dop_lefthit

;*******************************************************************************
; THE GROUPED RENDERER — a fake imageset whose routine draws every lit slot
; (the Bellmite pattern)
;*******************************************************************************
dsw.FakeImg
        fcb   dsw.FakeSub-dsw.FakeImg,dsw.FakeSub-dsw.FakeImg
        fcb   dsw.FakeSub-dsw.FakeImg,dsw.FakeSub-dsw.FakeImg
        fcb   8,8,0
dsw.FakeSub
        fcb   0
        fcb   dsw.FakeMf-dsw.FakeSub
        fcb   0
        fcb   dsw.FakeMf-dsw.FakeSub
        fcb   0,0
dsw.FakeMf
        fcb   0                          ; page, patched by the renderer
        fdb   dsw.DrawAll

dopswarm.Render
        lda   routine,u
        bne   @live
        _GetCartPageA
        ldb   id,u
        ldx   #Img_Page_Index
        sta   b,x                        ; the engine will mount OUR page
        sta   dsw.FakeMf
        ldd   #dsw.FakeImg
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
@live   lda   dsw.st                     ; the swarm is over: so is its picture
        cmpa  #dsw.M_GONE
        bne   >
        jmp   DeleteObject
!       jmp   DisplaySprite

dsw.DrawAll
        ldx   #dsw.Slots
        stx   dsw.dp
@loop   ldx   dsw.dp
        lda   ,x
        beq   @next
        ldd   1,x                        ; A = x_pixel, B = y_pixel
        jsr   DRS_XYToAddress
        ldx   dsw.dp
        ldx   3,x
        ldu   <glb_screen_location_2
        jsr   ,x                         ; the routine consumes U
@next   ldx   dsw.dp
        leax  dsw.SLOTSZ,x
        stx   dsw.dp
        cmpx  #dsw.SlotsEnd
        blo   @loop
        rts

;*******************************************************************************
; THE ARENA — columns 328..383 of the stage 6 collision map, 30 rows
; (src/stages/06/terrain/level6_fc.bin, 48 bytes a row: bytes 41..47)
;*******************************************************************************
dsw.Map
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",0*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",1*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",2*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",3*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",4*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",5*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",6*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",7*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",8*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",9*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",10*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",11*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",12*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",13*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",14*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",15*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",16*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",17*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",18*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",19*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",20*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",21*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",22*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",23*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",24*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",25*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",26*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",27*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",28*48+41,7
        INCLUDEBIN "src/stages/06/terrain/level6_fc.bin",29*48+41,7

;*******************************************************************************
; THE DATA (page) — cleared at every Init
;*******************************************************************************
dsw.dp       fdb   0
dsw.nfr      fcb   0
dsw.pending  fcb   0
dsw.savedVel fdb   0

dsw.Data
dsw.gc       fdb   0                     ; the arcade global counter (0x2EB6)
dsw.st       fcb   0                     ; manager state
dsw.cur      fdb   0                     ; the cursor (+0x12)
dsw.ptr      fdb   0                     ; the next script entry (+0x10)
dsw.c30      fdb   0                     ; the end countdown (+0x30)
dsw.freeze   fcb   0                     ; 0x2FC4 game_tick_disable
dsw.px       fdb   0                     ; the probe point
dsw.py       fdb   0
dsw.wN       fcb   0
dsw.wT       fdb   0
dsw.wX       fcb   0
dsw.wXY      fdb   0
dsw.Dops     fill  0,dsw.NDOP*D.SZ
dsw.DopsEnd
dsw.Slots    fill  0,dsw.NDOP*dsw.SLOTSZ
dsw.SlotsEnd
dsw.DataEnd

        INCLUDE "src/enemies/dop/tables.asm"
