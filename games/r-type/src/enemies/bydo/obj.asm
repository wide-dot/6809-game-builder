;*******************************************************************************
; bydo — the Bydo core, the stage 8 boss, ported 1:1 from the arcade
;
; PORTING SHEET (source: Ghidra `maincpu`, subsystems bydo_core and win)
; ----------------------------------------------------------------------
;   40:C0CA run_bydo ....................... bydo.Core (timeline 1000:6416)
;   40:C180 _death_init .................... bydo.Death
;   40:C1EB / C238 / C275 the death phases . bydo.Ph1 / Ph2 / Ph3
;   40:C284 the explosion cascade .......... bydo.Cascade
;   40:EAA9 bydo_clear_chamber_tilemap ..... the wreck stamp (tilemap.stamp)
;   40:C37F / C39C / C3EE the mouth ........ bydo.Mouth (phases A and B)
;   40:C30A..C335 the head patches ......... bydo.A_HEAD .. bydo.A_REST
;   40:9758..9801 create_win_a..d .......... bydo.WinNew
;   40:983B run_win / 98A8 aim mode ........ bydo.Win
;   40:F5C1 move_by_script ................. bydo.MoveScript
;   40:1D89 set_direction_to ............... bydo.Dir
;
; THE PORT RUNS IN ARCADE SPACE and ONE ARCADE FRAME AT A TIME, in the list
; order of the arcade (priorities 0x1D00 mouth, 0x8040 wins, 0xC800 core,
; 0xEF00 cascade). A record born in a frame ticks from the next one when its
; creator sits after it (the mouth, the wins), in the same frame when it sits
; before (the cascade). Positions are the arcade's 16.8, speeds its 8.8,
; tables a copy of the ROM (tables.asm, tools/gen_bydo.py). Only the
; publication converts.
;
; THE CORE IS A CLOCK: its body is the stage map, its frame counter (+0x30)
; walks a timeline of calls — the wins, the mouth, the head's frames, the
; scroll halt — and it dies at 0x2000 (the timeout) or after 0x500 frames of
; Force in its mouth (0xBC0 on). The wins are invulnerable, they only kill
; by contact; at the core's death the game freezes four frames and they
; vanish.
;
; RANDOM NUMBERS: only the cascade draws, from a stream shared with the
; stage's wave: every draw goes through bydo.Draw, the bench writes the
; arcade's value at bydo.Drawn. In game bydo.Rand is a private random_ax.
;
; THE PICTURES. The head and the tentacles are not sprites on the arcade:
; they are tile recipes written in the BACKGROUND tile RAM (40:C335 8x8 cells,
; 40:C434 7x6), with the priority bit set — in front of the sprites. Here
; they are opaque compiled images (tools/arcade_to_sprites.py --opaque) drawn
; AFTER the tiles by the stage's front hook (stage.frameFront, stage 8 main,
; bydo.DrawFront), at their place on the map: their screen x follows the
; camera, not the arcade x. The wins are the engine's sprites of
; src/enemies/win, drawn by a grouped renderer (bydo.DrawAll).
;
; DEVIATIONS (V2-DEVIATION):
; - collision runs once per render (engine); the Force-in-mouth test reads
;   the Force pod's box once per render, every frame of the render uses it;
; - the wins and the mouth are boxes of the engine: the wins in the
;   unkillable list (contact kills, nothing hurts them), the mouth an
;   invincible enemy box (shots absorbed, contact kills);
; - the mouth's hit flash (40:C149, a bg palette blackout) and the "mouth
;   bites the Force" tiles (40:C10E) are not drawn;
; - the patches are culled until they are wholly on screen (they slide in
;   during the last 0x7E frames of scroll);
; - at the death the game freeze (4 frames) and the fg wipe (40:C1BC) touch
;   the family only; the Force pod is not withdrawn ([0x3E] = 0). The chamber
;   clear (40:EAA9) is the wreck, a stamp on the map (stage8.maps, columns
;   55-59, its seams included: tools/gen_bydo_wreck.py), and the patches go;
; - after the death the scroll runs 1.5x faster, over the map's blank tail
;   (map/in.png, 120 px wide: the arcade's map has nothing after the
;   chamber); the stage plays the ending (src/stages/08/ending/) once black;
;   the core publishes its clock's start (ending.gc0, the bg fade's frame);
; - sounds: the cascade's explosions carry the drawn sound; the boss music
;   (0x19, 40:C2F0) and the ending's (0x1A, 40:C210) are played by the stage;
;   the other effects (win entries, fireball, stinger) are not;
; - the bg fade (40:C238) is the palette fade to black of the stage
;   (stage.deathFadeOut), the ship's colours with it; the end route then
;   clears to black and the palette comes back (endlevel, FADE_ENDING).
;*******************************************************************************

; --- core states ----------------------------------------------------------------
bydo.C_RUN    equ 1                  ; 40:C0CA
bydo.C_PH1    equ 2                  ; 40:C1EB
bydo.C_PH2    equ 3                  ; 40:C238
bydo.C_PH3    equ 4                  ; 40:C275
bydo.C_GONE   equ 5

; --- the timeline's actions (tools/gen_bydo.py, ACTIONS) --------------------------
bydo.A_WIN_A  equ 0
bydo.A_WIN_D  equ 3
bydo.A_MOUTH  equ 4
bydo.A_HEAD   equ 5
bydo.A_HALT   equ 6
bydo.A_SFX    equ 7
bydo.A_CLOSE  equ 8
bydo.A_FIRE_A equ 9
bydo.A_FIRE_D equ 12
bydo.A_REST   equ 13
bydo.A_FREE   equ 14

; --- a win, 40:983B -------------------------------------------------------------
W.st          equ 0                  ; 0 none, 1 script, 2 aim (40:98A8)
W.x           equ 1                  ; 1,2 int (+4), 3 frac (+3)
W.y           equ 4                  ; 4,5 int (+8), 6 frac (+7)
W.s12         equ 7                  ; 7,8 script, arcade address
W.s14         equ 9                  ; 9,10 segment cursor, arcade address
W.s16         equ 11                 ; image byte (+0x16)
W.s17         equ 12                 ; bytes per frame (+0x17)
W.c20         equ 13                 ; the picture, 0..2 (+0x20)
W.c22         equ 14                 ; 14,15 the chase counter (+0x22)
W.SZ          equ 16
bydo.NWIN     equ 4

; --- boxes (resident, stage 8 main) and slots -----------------------------------
bydo.BX_WIN   equ 0
bydo.BX_MOUTH equ bydo.NWIN
bydo.NBOX     equ bydo.BX_MOUTH+1
bydo.SL_WIN   equ 0                  ; drawn by bydo.DrawAll
bydo.SL_TENT  equ bydo.NWIN          ; drawn by bydo.DrawFront: tentacles,
bydo.SL_HEAD  equ bydo.SL_TENT+1     ; then the head
bydo.NSLOT    equ bydo.SL_HEAD+1
bydo.SLOTSZ   equ 6                  ; [on, x, y, imageset(2), page]

; the patches' corner on the screen, at camera 0 (0-based; x = this - camera):
; the map pixel of their cells (arcade 1856 and 1792 px, 88 and 96 px down)
; times 3/8 and 3/4, plus the playfield's 8 and 10
bydo.HEAD_X   equ 696+8
bydo.HEAD_Y   equ 66+10
bydo.TENT_X   equ 672+8
bydo.TENT_Y   equ 72+10
; a slot holds the picture's ANCHOR: the corner minus the imageset's x1, y1
; (gen/enemies/stage8-bydo*/index.asm — every frame of a set has the same)
bydo.HEAD_AX  equ 11
bydo.HEAD_AY  equ 23
bydo.TENT_AX  equ 10
bydo.TENT_AY  equ 17

bydo.MOUTH_X  equ $029D              ; 1000:64B4 around (0x28C, 0x100):
bydo.MOUTH_Y  equ $0100              ; x -14..48, y -48..48
bydo.MOUTH_R  equ 12*256+36          ; rx, ry (x 3/8, y 3/4)
bydo.WIN_R    equ 4*256+8            ; 1000:438C +-10

bydo.boxes    EXTERNAL               ; resident, bydo.NBOX * sizeof{AABB}
bydo.slots    EXTERNAL               ; resident, bydo.NSLOT * bydo.SLOTSZ

;*******************************************************************************
; THE CORE OBJECT (the wave's entry)
;*******************************************************************************
bydo.Object
        lda   routine,u
        asla
        ldx   #bydo.Routines
        jmp   [a,x]
bydo.Routines
        fdb   bydo.Init
        fdb   bydo.Live
        fdb   bydo.Done

; the wave's creation: the arcade frame 0 (+0x30 = 0, the first tick next)
bydo.Init
        ldb   wave_frame_drop,u          ; aliases anim_frame_duration
        stb   bydo.pending
        ldx   #bydo.Data
        ldd   #bydo.DataEnd-bydo.Data
@clr    clr   ,x+
        subd  #1
        bne   @clr
        ldx   #bydo.slots                ; nothing published yet
        ldb   #bydo.NSLOT
!       clr   ,x
        leax  bydo.SLOTSZ,x
        decb
        bne   <
        lda   #bydo.C_RUN
        sta   bydo.cst
        ldd   #bydo.Timeline
        std   bydo.cur
        lda   #$FF
        sta   bydo.headImg
        sta   bydo.tentImg
        ldd   gfxlock.frame.gameCount    ; the arcade counter (bench rewrites)
        subb  bydo.pending
        sbca  #0
        std   bydo.gc
        ldd   #$0501
        std   bydo.rng
        lda   #3
        sta   bydo.rng+2
        jsr   LoadObject_x               ; the grouped renderer (the wins)
        beq   >
        lda   #ObjID_bydo_render
        sta   id,x
!       inc   routine,u
bydo.Seeded                          ; test hook: gc, seed, scroll phase final
        ldb   bydo.pending
        bra   bydo.Advance

bydo.Live
        jsr   bydo.PlayerArcade
        jsr   bydo.ForceWatch
        ldb   gfxlock.frameDrop.count
bydo.Advance
        pshs  u
        stb   bydo.nfr
        beq   @pub
@f      jsr   bydo.Frame
        dec   bydo.nfr
        bne   @f
@pub    jsr   bydo.Publish
        puls  u
bydo.Sample                          ; test hook: a render's state is final
        lda   bydo.cst
        cmpa  #bydo.C_GONE
        bne   @rts
        lda   #2
        sta   routine,u
@rts    rts

bydo.Done
        jmp   UnloadObject_u

;*******************************************************************************
; ONE ARCADE FRAME
;*******************************************************************************
bydo.Frame
        ldd   bydo.gc                    ; 40:0219 / 021D
        addd  #1
        std   bydo.gc
        bitb  #$FF
        bne   >
        bita  #1
        bne   >
        ldd   #$0501
        std   bydo.rng
        lda   #3
        sta   bydo.rng+2
!       clr   bydo.scroll                ; the background autoscroll (0x2ED4),
        lda   bydo.halted                ; 0x80 a frame: 1 px every other one
        bne   bydo.Tick
        lda   bydo.sacc
        adda  #$80
        sta   bydo.sacc
        bcc   bydo.Tick
        dec   bydo.scroll                ; -1
bydo.Tick                            ; test hook: frame bydo.gc, before any actor
        lda   bydo.mst                   ; 0x1D00
        beq   >
        jsr   bydo.Mouth
!       ldy   #bydo.Wins                 ; 0x8040
@w      lda   W.st,y
        beq   >
        jsr   bydo.Win
!       leay  W.SZ,y
        cmpy  #bydo.WinsEnd
        blo   @w
        jsr   bydo.Core                  ; 0xC800
        lda   bydo.kst                   ; 0xEF00
        beq   @rts
        jmp   bydo.Cascade
@rts    rts

;*******************************************************************************
; THE CORE — 40:C0CA
;*******************************************************************************
bydo.Core
        lda   bydo.cst
        cmpa  #bydo.C_RUN
        beq   bydo.Run
        cmpa  #bydo.C_PH1
        lbeq  bydo.Ph1
        cmpa  #bydo.C_PH2
        lbeq  bydo.Ph2
        cmpa  #bydo.C_PH3
        lbeq  bydo.Ph3
        rts

bydo.Run
        ldd   bydo.c30                   ; c0ca the clock
        addd  #1
        std   bydo.c30
        ldx   bydo.cur                   ; c0d3 the timeline's next call
        cmpd  ,x
        blo   >
        ldb   2,x
        leax  3,x
        stx   bydo.cur
        inc   bydo.ci
        jsr   bydo.Act
!       ldd   bydo.c30                   ; c0e2 the mouth is open to the Force
        cmpd  #$0BC0
        blo   @tmo
        ldd   #$028C                     ; c0ec
        std   bydo.x
        ldd   #$0100
        std   bydo.y
        lda   bydo.fin                   ; c0fc the Force in the mouth box
        beq   @tmo
        ldd   bydo.f38                   ; c101
        addd  #1
        std   bydo.f38
        cmpd  #$0500                     ; c126
        lbhs  bydo.Death
@tmo    ldd   bydo.c30                   ; c16d the timeout
        cmpd  #$2000
        lbhs  bydo.Death
        rts

; B = action rank (bydo.A_*)
bydo.Act
        cmpb  #bydo.A_WIN_D
        lbls  bydo.WinNew
        cmpb  #bydo.A_MOUTH
        bne   >
        lda   #1                         ; c37f the mouth's child
        sta   bydo.mst
        ldd   #$02C4
        std   bydo.mx
        ldd   #0
        std   bydo.mc20
        rts
!       cmpb  #bydo.A_HEAD
        bne   >
        ldd   #$02C4                     ; c30a the head, at rest
        std   bydo.x
        ldd   #$0124
        std   bydo.y
        clr   bydo.headImg
        rts
!       cmpb  #bydo.A_HALT
        bne   >
        lda   #1                         ; c2f6 the scroll halts
        sta   bydo.halted
        ldd   scroll_vel
        std   bydo.savedVel
        ldd   #0
        std   scroll_vel
        rts
!       cmpb  #bydo.A_CLOSE
        bne   >
        lda   #$FF                       ; c37a the mouth closes
        sta   bydo.f36
        rts
!       cmpb  #bydo.A_SFX
        bne   >
        lda   #1                         ; c2f0 0x19: the boss music (the
        sta   globals.nextGameMode       ; stage plays it, bossmusic's flag)
        rts
!       cmpb  #bydo.A_FIRE_A
        blo   @rts
        cmpb  #bydo.A_REST
        bhi   >
        subb  #bydo.A_FIRE_A-1           ; c31b..c335 a head frame: rest,
        cmpb  #bydo.A_REST-bydo.A_FIRE_A+1 ; fireball a to d
        bne   @img
        clrb
@img    stb   bydo.headImg
        ldd   #$0284
        std   bydo.x
        ldd   #$0124
        std   bydo.y
        rts
!       cmpb  #bydo.A_FREE
        bne   @rts
        lda   #$FF                       ; c305 the wins are free
        sta   bydo.f33
@rts    rts                              ; 15 the music, 16 never

; c180 — the death: the broadcast, the score, the cascade, the freeze
bydo.Death
        lda   #1                         ; c1c9 the priority bits of the whole
        sta   globals.tilesBehind        ; bg are cleared: the map (and its
        ldd   bydo.gc                    ; patches) go UNDER the explosions;
        addd  #$0180+$00E0               ; the ending's clock: the bg fade
                                         ; falls at c21c + 0xE0 (40:C238)
        std   ending.gc0
        lda   #$FF
        sta   bydo.f32
        ldb   #14                        ; c197 score 0x8720
        jsr   AwardScore
        lda   #1                         ; c19d the cascade, 0x160 frames
        sta   bydo.kst
        ldd   #$0160
        std   bydo.kc20
        ldd   #$0180                     ; c1db
        std   bydo.c30
        lda   #bydo.C_PH1
        sta   bydo.cst
        lda   #1                         ; c1e5 the game freezes
        sta   bydo.freeze
        rts

bydo.Ph1
        ldd   bydo.c30                   ; c1eb four frames later, the thaw
        cmpd  #$017C
        bne   >
        clr   bydo.freeze
!       cmpd  #$0080                     ; c1f7 the chamber is cleared:
        bne   >                          ; the patches go, the wreck is
        lda   #$FF                       ; stamped on the map (40:EAA9)
        sta   bydo.headImg
        sta   bydo.tentImg
        pshs  u
        ldx   #wreck
        jsr   tilemap.stamp
        puls  u
        lda   #1                         ; c210 0x1A: the ending's music
        sta   ending.music
!       ldd   bydo.c30
        subd  #1
        std   bydo.c30
        bne   @rts
        lda   #1                         ; c21c the end of the game: the
        sta   globals.bossDefeated       ; end-level flag, a faster scroll
        ldd   bydo.savedVel
        lsra
        rorb
        addd  bydo.savedVel              ; 0xC0 for 0x80: x 3/2
        std   scroll_vel
        ldd   #$00E0
        std   bydo.c10
        lda   #bydo.C_PH2
        sta   bydo.cst
@rts    rts

bydo.Ph2
        ldd   bydo.c10                   ; c238 the fade, 0xE0 frames on
        subd  #1
        std   bydo.c10
        bne   @rts
        pshs  u                          ; c23e the bg goes black: the
        jsr   stage.deathFadeOut         ; palette, the ending route waits
        puls  u                          ; for THIS fade (globals.endFade)
        lda   #1
        sta   globals.endFade
        ldd   #$0040
        std   bydo.c10
        lda   #bydo.C_PH3
        sta   bydo.cst
@rts    rts

bydo.Ph3
        ldd   bydo.c10                   ; c275 then 0x40 frames, and out
        subd  #1
        std   bydo.c10
        bne   @rts
        lda   #bydo.C_GONE
        sta   bydo.cst
@rts    rts

;*******************************************************************************
; THE CASCADE — 40:C284, two big explosions every 4 frames
;*******************************************************************************
bydo.Cascade
        lda   bydo.gc+1                  ; c284 global_counter & 3
        bita  #3
        bne   @dec
        jsr   bydo.Draw                  ; c28b the sound: & 6, 0 = silence
        andb  #6
        lsrb
        ldx   #bydo.CascadeSfx
        ldb   b,x
        stb   bydo.wS
        jsr   bydo.Draw                  ; c2ad X = 0x220 + random
        clra
        addd  #$0220
        std   bydo.wT2
        jsr   bydo.Draw                  ; c2b8 Y = 0xA0 + random
        clra
        addd  #$00A0
        tfr   d,x
        ldb   bydo.wS                    ; the first blast carries the sound
        clra
        addd  #explosion.subtype.big.brown
        tfr   d,u
        ldd   bydo.wT2
        jsr   bydo.Boom
        jsr   bydo.Draw                  ; c2ce X = 0x240 + (random & 0x7F)
        andb  #$7F
        clra
        addd  #$0240
        std   bydo.wT2
        jsr   bydo.Draw                  ; c2da Y = 0xD0 + (random & 0x7F)
        andb  #$7F
        clra
        addd  #$00D0
        tfr   d,x
        ldd   bydo.wT2
        ldu   #explosion.subtype.big.brown+explosion.sfx.none
        jsr   bydo.Boom
@dec    ldd   bydo.kc20                  ; c2e6
        subd  #1
        std   bydo.kc20
        bne   @rts
        clr   bydo.kst
@rts    rts
bydo.CascadeSfx                      ; the arcade's 0x50 + (r & 6) / 2
        fcb   explosion.sfx.none,explosion.sfx.medium
        fcb   explosion.sfx.turret,explosion.sfx.big

;*******************************************************************************
; THE MOUTH — 40:C39C (A) / C3EE (B)
;*******************************************************************************
bydo.Mouth
        lda   bydo.f32                   ; c39f a WORD test of +0x32:
        ora   bydo.f33                   ; the death and the release
        beq   >
        clr   bydo.mst
        rts
!       lda   bydo.mst
        cmpa  #1
        bne   @b
        lda   bydo.mc20+1                ; c3a6 every 64 frames, the close
        bita  #$3F                       ; signal is polled
        bne   @a
        lda   bydo.f36
        beq   @a
        ldd   #$007F                     ; c3e4 phase B
        std   bydo.mc20
        lda   #2
        sta   bydo.mst
        bra   @b
@a      jsr   bydo.MouthScroll           ; c3ba
        ldd   bydo.mc20
        addd  #1
        std   bydo.mc20
        bitb  #7                         ; c3c6 a recipe every 8 frames
        bne   >
        andb  #$38
        lsrb
        lsrb
        lsrb
        ldx   #bydo.MouthA
        ldb   b,x
        stb   bydo.tentImg
!       lda   bydo.freeze                ; c3dc
        beq   @rts
        clr   bydo.mst
@rts    rts
@b      jsr   bydo.MouthScroll           ; c3f8
        ldd   bydo.mc20
        bitb  #7                         ; c401
        bne   >
        andb  #$78
        lsrb
        lsrb
        lsrb
        ldx   #bydo.MouthB
        ldb   b,x
        stb   bydo.tentImg
!       ldd   bydo.mc20                  ; c417
        subd  #1
        std   bydo.mc20
        bne   >
        clr   bydo.f36                   ; c427 back to phase A
        lda   #1
        sta   bydo.mst
        rts
!       lda   bydo.freeze
        beq   @rts2
        clr   bydo.mst
@rts2   rts

bydo.MouthScroll
        ldb   bydo.scroll                ; x += the background's delta
        sex
        addd  bydo.mx
        std   bydo.mx
        rts

;*******************************************************************************
; THE WINS — 40:9758..9801, 983B, 98A8
;*******************************************************************************
; B = 0..3: create_win_a..d, in the first free record
bydo.WinNew
        ldy   #bydo.Wins
@f      lda   W.st,y
        beq   @new
        leay  W.SZ,y
        cmpy  #bydo.WinsEnd
        blo   @f
        rts                              ; the pool is full: no win
@new    lda   #1
        sta   W.st,y
        aslb
        aslb
        ldx   #bydo.WinInit
        abx
        ldd   ,x                         ; its script
        std   W.s12,y
        jsr   bydo.RomW
        std   W.s14,y
        lda   2,x
        sta   W.s17,y
        ldb   3,x
        lda   #2                         ; x 0x278 or 0x2A0
        std   W.x,y
        clr   W.x+2,y
        cmpb  #$78
        bne   @lo
        ldd   #$0090                     ; y 0x90 for the first, 0x108
        bra   @y
@lo     ldd   #$0108
@y      std   W.y,y
        clr   W.y+2,y
        clr   W.c20,y
        clr   W.s16,y
        clr   W.c22,y
        clr   W.c22+1,y
        tfr   y,d                        ; its box: contact only
        subd  #bydo.Wins
        jsr   bydo.WinRank
        jsr   bydo.BoxN
        ldd   #bydo.WIN_R
        std   bydo.wT
        lda   #$FF
        ldy   #AABB_list_ennemy_unkillable
        jmp   bydo.BoxIn
bydo.WinInit                         ; {script, bytes per frame, x low}
        fdb   $A872
        fcb   3,$78
        fdb   $A90C
        fcb   8,$A0
        fdb   $A96C
        fcb   8,$A0
        fdb   $A9F6
        fcb   8,$A0

; Y = the win
bydo.Win
        lda   W.st,y
        cmpa  #1
        bne   @aim
        jsr   bydo.MoveScript            ; 983b
        bcc   >
        lda   W.s17,y                    ; 9840 the script ended
        cmpa  #4
        blo   >
        dec   W.s17,y
!       jsr   bydo.WinPic                ; 9849
        lda   bydo.freeze                ; 9871
        bne   bydo.WinOut
        lda   bydo.f32                   ; 987e the death: it explodes
        bne   @boom
        lda   bydo.f33                   ; 9882 the release: the chase
        beq   @rts
        clr   W.c22,y
        clr   W.c22+1,y
        lda   #2
        sta   W.st,y
@rts    rts
@boom   ldd   W.x,y
        ldx   W.y,y
        ldu   #explosion.subtype.smallx2+explosion.sfx.small
        jsr   bydo.Boom
        bra   bydo.WinOut
@aim    lda   bydo.freeze                ; 98a8
        bne   bydo.WinOut
        ldd   W.x,y                      ; 98af the direction to the player
        std   bydo.px
        ldd   W.y,y
        std   bydo.py
        jsr   bydo.Dir
        stb   bydo.wN
        ldd   W.c22,y                    ; 98b8
        addd  #1
        std   W.c22,y
        ldx   #bydo.AimA
        cmpd  #$0080
        blo   >
        ldx   #bydo.AimB
!       ldb   bydo.wN
        abx
        pshs  x
        ldd   ,x                         ; 98c5 vx, 8.8
        leax  W.x,y
        jsr   bydo.Move
        puls  x
        ldd   2,x                        ; 98cd vy
        leax  W.y,y
        jsr   bydo.Move
bydo.WinPic
        inc   W.c20,y                    ; 9858 the picture cycles 0..2
        lda   W.c20,y
        cmpa  #3
        bne   >
        clr   W.c20,y
!       rts

bydo.WinOut                          ; 9892 a silent unload
        clr   W.st,y
        tfr   y,d
        subd  #bydo.Wins
        jsr   bydo.WinRank
        jsr   bydo.BoxN
        jmp   bydo.BoxOut

bydo.WinRank                         ; D = offset -> A = rank
        lda   #-1
!       inca
        subb  #W.SZ
        bcc   <
        rts

;*******************************************************************************
; move_by_script — 40:F5C1, Y = the win (x, y: int then frac)
;*******************************************************************************
bydo.MoveScript
        lda   W.s17,y
        sta   bydo.wN
@byte   ldd   W.s14,y
        jsr   bydo.RomX
        lda   ,x
        bita  #$80                       ; f5cc SetImage
        beq   >
        anda  #$1F
        sta   W.s16,y
        bra   @next
!       bita  #$40                       ; f5d0
        beq   @px
        bita  #$20
        beq   @y
        pshs  a
        ldd   W.x,y                      ; f5f5 -x
        subd  #1
        std   W.x,y
        puls  a
        bra   @y
@px     bita  #$20
        beq   @y
        pshs  a
        ldd   W.x,y                      ; f5d8 +x
        addd  #1
        std   W.x,y
        puls  a
@y      bita  #$10
        beq   @py
        bita  #$08
        beq   @ey
        pshs  a
        ldd   W.y,y                      ; f5fe -y
        subd  #1
        std   W.y,y
        puls  a
        bra   @ey
@py     bita  #$08
        beq   @ey
        pshs  a
        ldd   W.y,y                      ; f5e3 +y
        addd  #1
        std   W.y,y
        puls  a
@ey     bita  #$04                       ; f5e6 end of segment
        bne   @seg
        ldd   W.s14,y
        addd  #1
        std   W.s14,y
        dec   bydo.wN
        bne   @byte
        andcc #$FE                       ; f5ef not over
        rts
@next   ldd   W.s14,y                    ; f60b an image is not a move
        addd  #1
        std   W.s14,y
        bra   @byte
@seg    ldd   W.s12,y                    ; f60e the next command
        addd  #2
        std   W.s12,y
        jsr   bydo.RomW
        cmpd  #0
        beq   @jump
        cmpa  #$F0
        bne   >
        stb   W.s17,y                    ; f621 bytes per frame
        bra   @seg
!       std   W.s14,y                    ; f626 a new segment
        andcc #$FE
        rts
@jump   ldd   W.s12,y                    ; f62b the script that follows
        addd  #2
        jsr   bydo.RomW
        std   W.s12,y
        jsr   bydo.RomW
        std   W.s14,y
        orcc  #1                         ; f638 over
        rts

; D = arcade address in the script ranges -> X ; (D unchanged)
bydo.RomX
        pshs  d
        ldx   #bydo.Ranges
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
bydo.RomW
        pshs  x
        jsr   bydo.RomX
        ldb   ,x
        lda   1,x
        puls  x,pc

;*******************************************************************************
; THE TOOLS
;*******************************************************************************

; every draw passes here: the bench stops at bydo.Drawn and writes D
bydo.Draw
        jsr   bydo.Rand
bydo.Drawn
        rts

bydo.Rand
        ldd   bydo.rng+1
        pshs  b
        sta   bydo.rng+2
        adda  ,s
        ldb   bydo.rng
        stb   bydo.rng+1
        sta   bydo.rng
        tfr   a,b
        puls  a,pc

; X = position (int:2, frac:1), D = signed 8.8
bydo.Move
        pshs  a
        addb  2,x
        stb   2,x
        puls  b
        sex
        adcb  1,x
        adca  ,x
        std   ,x
        rts

; 40:1D89 set_direction_to, from (bydo.px, bydo.py) to the player -> B
bydo.Dir
        ldd   bydo.py
        addd  #8
        cmpd  bydo.ply
        blo   @above
        ldd   bydo.py
        subd  #8
        cmpd  bydo.ply
        bhs   @below
        ldd   bydo.px
        cmpd  bydo.plx
        bhs   >
        ldb   #$10
        rts
!       ldb   #$30
        rts
@above  ldd   bydo.px
        addd  #8
        cmpd  bydo.plx
        blo   @ne
        ldd   bydo.px
        subd  #8
        cmpd  bydo.plx
        bhs   @nw
        clrb
        rts
@below  ldd   bydo.px
        addd  #8
        cmpd  bydo.plx
        blo   @se
        ldd   bydo.px
        subd  #8
        cmpd  bydo.plx
        bhs   @sw
        ldb   #$20
        rts
@ne     ldd   bydo.plx
        subd  bydo.px
        std   bydo.wT
        ldd   bydo.ply
        subd  bydo.py
        ldx   #bydo.DirNE
        bra   @quad
@nw     ldd   bydo.px
        subd  bydo.plx
        std   bydo.wT
        ldd   bydo.ply
        subd  bydo.py
        ldx   #bydo.DirNW
        bra   @quad
@se     ldd   bydo.plx
        subd  bydo.px
        std   bydo.wT
        ldd   bydo.py
        subd  bydo.ply
        ldx   #bydo.DirSE
        bra   @quad
@sw     ldd   bydo.px
        subd  bydo.plx
        std   bydo.wT
        ldd   bydo.py
        subd  bydo.ply
        ldx   #bydo.DirSW
@quad   std   bydo.wT2
        ldd   bydo.wT
        subd  bydo.wT2
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
bydo.DirNE fcb  $04,$08,$0C
bydo.DirNW fcb  $3C,$38,$34
bydo.DirSE fcb  $1C,$18,$14
bydo.DirSW fcb  $24,$28,$2C

; the player in arcade units (exact on its pinned point, see Bellmite)
bydo.PlayerArcade
        ldd   player1+x_pos
        subd  glb_camera_x_pos
        subd  #8
        bpl   >
        ldd   #0
!       tsta
        beq   >
        ldb   #255
!       stb   bydo.wX
        lda   #171
        mul
        tfr   a,b
        clra
        std   bydo.wT
        ldb   bydo.wX
        clra
        aslb
        rola
        addd  bydo.wT
        addd  #320
        std   bydo.plx
        ldb   player1+y_pos+1
        clra
        std   bydo.wT
        ldd   #297
        subd  bydo.wT
        std   bydo.wT
        lda   #171
        mul
        tst   bydo.wT
        beq   >
        addd  #171*256
!       lsra
        tfr   a,b
        clra
        addd  bydo.wT
        std   bydo.ply
        rts

; D = arcade x, Y = arcade y -> A = x, B = y on the screen (0-based, clamped)
bydo.ToScreen
        subd  #320
        std   bydo.wT
        aslb
        rola
        addd  bydo.wT
        asra
        rorb
        asra
        rorb
        asra
        rorb
        addd  #8
        jsr   bydo.Clamp
        stb   bydo.wX
        tfr   y,d
        std   bydo.wT
        aslb
        rola
        addd  bydo.wT
        asra
        rorb
        asra
        rorb
        std   bydo.wT
        ldd   #297
        subd  bydo.wT
        jsr   bydo.Clamp
        lda   bydo.wX
        rts

bydo.Clamp
        tsta
        beq   @rts
        bmi   @lo
        ldb   #255
        rts
@lo     clrb
@rts    rts

; D = arcade x, X = arcade y, U = explosion subtype: one engine explosion
bydo.Boom
        pshs  y,u
        std   bydo.wDX
        stx   bydo.wDY
        jsr   LoadObject_x
        beq   @rts
        lda   #ObjID_explosion
        ldb   3,s                        ; the subtype (low byte of U)
        std   id,x
        pshs  x
        ldd   bydo.wDX
        ldy   bydo.wDY
        jsr   bydo.ToScreen
        puls  x
        pshs  b
        tfr   a,b
        clra
        addd  glb_camera_x_pos
        std   x_pos,x
        puls  b
        clra
        std   y_pos,x
@rts    puls  y,u,pc

;*******************************************************************************
; THE FORCE IN THE MOUTH — once per render, the Force pod's boxes against
; the mouth box (1000:64B4), the engine's overlap test (collision-do.asm)
;*******************************************************************************
bydo.ForceWatch
        clr   bydo.fin
        ldd   #bydo.MOUTH_X
        ldy   #bydo.MOUTH_Y
        jsr   bydo.ToScreen
        std   bydo.wXY
        ldx   AABB_list_forcepod
        beq   @rts
@box    lda   AABB.p,x
        beq   @next
        lda   AABB.rx,x
        adda  #bydo.MOUTH_R/256
        asla
        sta   @rx
        asra
        adda  bydo.wXY
        suba  AABB.cx,x
        cmpa  #0
@rx     equ   *-1
        bhi   @next
        lda   AABB.ry,x
        adda  #bydo.MOUTH_R&255
        asla
        sta   @ry
        asra
        adda  bydo.wXY+1
        suba  AABB.cy,x
        cmpa  #0
@ry     equ   *-1
        bhi   @next
        inc   bydo.fin
        rts
@next   ldx   AABB.next,x
        bne   @box
@rts    rts

;*******************************************************************************
; THE BOXES — manager-owned, resident (bydo.boxes): prev and next MUST be
; blank before Collision_AddAABB (see the bug manager)
;*******************************************************************************
; A = box rank -> X
bydo.BoxN
        ldb   #sizeof{AABB}
        mul
        addd  #bydo.boxes
        tfr   d,x
        rts

; X = the box, A = its potential, Y = its list, bydo.wT = rx:ry
bydo.BoxIn
        pshs  a,u,y
        ldb   #sizeof{AABB}
!       clr   ,x+
        decb
        bne   <
        leax  -sizeof{AABB},x
        ldd   bydo.wT
        sta   AABB.rx,x
        stb   AABB.ry,x
        lda   #220
        sta   AABB.cx,x
        sta   AABB.cy,x
        lda   ,s
        sta   AABB.p,x
        jsr   Collision_AddAABB
        puls  a,u,y,pc

; X = the box, Y = its list (its potential 0 = not in the list)
bydo.BoxOut
        pshs  u,y
        lda   AABB.p,x
        beq   @rts
        sty   Collision_Remove_1
        sty   Collision_Remove_3
        leay  2,y
        sty   Collision_Remove_2
        jsr   Collision_RemoveAABB
        clr   AABB.p,x
@rts    puls  u,y,pc

; the box X centred on (A, B), screen 0-based; parked off screen when the
; centre clamps
bydo.BoxPlace
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
; PUBLICATION — once per render: resident slots and box places
;*******************************************************************************
bydo.Publish
        ldu   #bydo.slots
        ldy   #bydo.Wins                 ; --- the wins
@w      clr   ,u
        lda   W.st,y
        beq   @wn
        ldd   W.x,y
        pshs  y
        ldy   W.y,y
        jsr   bydo.ToScreen
        puls  y
        std   bydo.wXY
        ldb   W.c20,y                    ; drawn before the step: c20 - 1
        addb  #2
        cmpb  #3
        blo   >
        subb  #3
!       aslb
        ldx   #bydo.WinSets
        ldx   b,x
        lda   #map.RAM_OVER_CART+bydo.PG
        jsr   bydo.Slot
        tfr   y,d
        subd  #bydo.Wins
        jsr   bydo.WinRank
        jsr   bydo.BoxN
        ldd   bydo.wXY
        jsr   bydo.BoxPlace
@wn     leau  bydo.SLOTSZ,u
        leay  W.SZ,y
        cmpy  #bydo.WinsEnd
        blo   @w
        clr   ,u                         ; --- the tentacles: their corner on
        ldb   bydo.tentImg               ; the map
        cmpb  #$FF
        beq   >
        aslb
        ldx   #bydo.TentSets
        ldx   b,x
        ldd   #bydo.TENT_X+bydo.TENT_AX
        subd  glb_camera_x_pos
        tsta
        bne   >
        lda   #bydo.TENT_Y+bydo.TENT_AY
        exg   a,b
        std   bydo.wXY
        lda   #map.RAM_OVER_CART+bydo.PG
        jsr   bydo.Slot
!       leau  bydo.SLOTSZ,u              ; --- the head
        clr   ,u
        ldb   bydo.headImg
        cmpb  #$FF
        beq   >
        aslb
        ldx   #bydo.HeadSets
        ldx   b,x
        ldd   #bydo.HEAD_X+bydo.HEAD_AX
        subd  glb_camera_x_pos
        tsta
        bne   >
        lda   #bydo.HEAD_Y+bydo.HEAD_AY
        exg   a,b
        std   bydo.wXY
        lda   #map.RAM_OVER_CART+bydo.PG_HEAD
        jsr   bydo.Slot
!       lda   #bydo.BX_MOUTH             ; --- the mouth box, 0xBC0 on
        jsr   bydo.BoxN
        lda   bydo.cst
        cmpa  #bydo.C_RUN
        bne   @mout
        ldd   bydo.c30
        cmpd  #$0BC0
        blo   @rts
        lda   AABB.p,x
        bne   @mplace
        ldd   #bydo.MOUTH_R
        std   bydo.wT
        lda   #$FF                       ; invincible: shots absorbed
        ldy   #AABB_list_ennemy
        jsr   bydo.BoxIn
@mplace ldd   #bydo.MOUTH_X
        ldy   #bydo.MOUTH_Y
        pshs  x
        jsr   bydo.ToScreen
        puls  x
        jmp   bydo.BoxPlace
@mout   ldy   #AABB_list_ennemy
        jmp   bydo.BoxOut
@rts    rts

; U = the slot, X = the imageset, A = its page, bydo.wXY = 0-based place
bydo.Slot
        sta   5,u
        stx   3,u
        ldd   bydo.wXY
        adda  #screen_left
        addb  #screen_top
        std   1,u
        lda   #1
        sta   ,u
        rts

;*******************************************************************************
; THE GROUPED RENDERER — its picture is bydo.DrawAll (stage 8 main,
; resident): the lit win slots, its page mounted
;*******************************************************************************
bydo.FakeImg
        fcb   bydo.FakeSub-bydo.FakeImg,bydo.FakeSub-bydo.FakeImg
        fcb   bydo.FakeSub-bydo.FakeImg,bydo.FakeSub-bydo.FakeImg
        fcb   8,8,0
bydo.FakeSub
        fcb   0
        fcb   bydo.FakeMf-bydo.FakeSub
        fcb   0
        fcb   bydo.FakeMf-bydo.FakeSub
        fcb   0,0
bydo.FakeMf
        fcb   0                          ; page, patched by the renderer
        fdb   bydo.DrawAll

bydo.DrawAll EXTERNAL

bydo.Render
        lda   routine,u
        bne   @live
        _GetCartPageA
        ldb   id,u
        ldx   #Img_Page_Index
        sta   b,x
        sta   bydo.FakeMf
        ldd   #bydo.FakeImg
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
@live   lda   bydo.cst
        cmpa  #bydo.C_GONE
        bne   >
        jmp   DeleteObject
!       jmp   DisplaySprite

;*******************************************************************************
; THE PICTURES — imagesets
;*******************************************************************************
bydo.WinSets
        fdb   set_bydo_win_0,set_bydo_win_1,set_bydo_win_2
bydo.HeadSets
        fdb   set_bydo_head_0,set_bydo_head_1,set_bydo_head_2
        fdb   set_bydo_head_3,set_bydo_head_4
bydo.TentSets
        fdb   set_bydo_tentacle_0,set_bydo_tentacle_1,set_bydo_tentacle_2
        fdb   set_bydo_tentacle_3,set_bydo_tentacle_4,set_bydo_tentacle_5
        fdb   set_bydo_tentacle_6,set_bydo_tentacle_7

;*******************************************************************************
; THE DATA (page) — cleared at every Init
;*******************************************************************************
bydo.nfr      fcb   0
bydo.pending  fcb   0
bydo.savedVel fdb   0

bydo.Data
bydo.gc       fdb   0                    ; the arcade global counter (0x2EB6)
bydo.rng      fcb   0,0,0                ; random_ax state
bydo.sacc     fcb   0                    ; the background autoscroll's fraction
bydo.scroll   fcb   0                    ; this frame's delta (0x2ED4)
bydo.halted   fcb   0
bydo.freeze   fcb   0                    ; 0x2FC4 game_tick_disable
bydo.fin      fcb   0                    ; the Force is in the mouth box
bydo.plx      fdb   0                    ; the player, arcade units
bydo.ply      fdb   0
bydo.cst      fcb   0                    ; the core
bydo.c30      fdb   0
bydo.cur      fdb   0                    ; its next timeline entry
bydo.ci       fcb   0                    ; ... its rank (+0x34 = 0x6416 + 4 ci)
bydo.x        fdb   0
bydo.y        fdb   0
bydo.f32      fcb   0                    ; the death
bydo.f33      fcb   0                    ; the release of the wins
bydo.f36      fcb   0                    ; the mouth closes
bydo.f38      fdb   0                    ; frames of Force in the mouth
bydo.c10      fdb   0
bydo.headImg  fcb   0                    ; the head patch, $FF none
bydo.tentImg  fcb   0                    ; the tentacles patch, $FF none
bydo.mst      fcb   0                    ; the mouth: 1 A, 2 B
bydo.mx       fdb   0
bydo.mc20     fdb   0
bydo.kst      fcb   0                    ; the cascade
bydo.kc20     fdb   0
bydo.px       fdb   0
bydo.py       fdb   0
bydo.wN       fcb   0
bydo.wS       fcb   0
bydo.wT       fdb   0
bydo.wT2      fdb   0
bydo.wDX      fdb   0
bydo.wDY      fdb   0
bydo.wX       fcb   0
bydo.wXY      fdb   0
bydo.Wins     fill  0,bydo.NWIN*W.SZ
bydo.WinsEnd
bydo.DataEnd

        INCLUDE "src/enemies/bydo/tables.asm"
