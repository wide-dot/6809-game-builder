;*******************************************************************************
; ending — the end of the game, ported 1:1 from the arcade
;
; PORTING SHEET (source: Ghidra `maincpu`)
; ----------------------------------------
;   wave entries of stage 8, after the core:
;     $0DE8 ObjID_starfield (variant 3) ... starfield.init (common)
;     $0F28 40:FB10 the fleet ............. ending.FleetNew
;     $0F78 40:FB9C six cycling palettes .. not ported (see below)
;     $1130 40:EEAB the credits director .. ending.Dir
;   40:FB53 a ship of the fleet ........... ending.Ship
;   40:EEB5 / EF09 / EF1E / EF83 / EF97 ... ending.Dir phases 1 to 5
;   40:ED93 blit_text_string_fg ........... ending.Write (a row of rowText)
;
; THE PORT RUNS IN ARCADE SPACE and ONE ARCADE FRAME AT A TIME. Its clock is
; the arcade's: it starts at ending.gc0, the frame the core's bg fade starts
; (its death + 0x260, written by the core), and the wave's creations fall at
; their arcade frames — the wave clock follows the scroll (0xC0 a frame once
; the core is dead), so they are fixed offsets from there. List order: the
; director (0x0100) before the ships (0xFF70); a record ticks from the frame
; after its creation.
;
; THE TEXT is a fg tilemap that scrolls up (0x2EC4/0x2EC6, 9.8, 0.5 px a
; frame from 0x40:EF13): the director writes descriptors in rows, the stage 8
; main draws the rows (ending.rowText) at (8 (row - 16) - Y) mod 512 with the
; HUD's font (its strings are resident: text.asm).
;
; DEVIATIONS (V2-DEVIATION):
; - the six cycling palettes (40:FBED, the ships' shimmer) are not ported:
;   each ship keeps its colour (images/fleet, one picture per palette);
; - the starfield is the engine's (common), variant 3, not the arcade's 91
;   stars (40:E430);
; - the text is the HUD's 4 px font: a line is 4 px a glyph where the arcade
;   is 3 (its 8 px at 3/8), placed at the arcade's column and kept whole on
;   the playfield; a line is drawn when it is whole on the playfield;
; - the director's wait (40:EF09, the fg loader catching up its target) is
;   its measured length: three frames;
; - the bg palette fade of the ENJOY line (40:EF7A) is not played; the
;   blackout (40:EF89) is a palette fade to black;
; - the "bonus game" is stage 1 again, score kept, at difficulty 2 (the
;   second round, set by the stage 8 hand-over as 40:EE7B does);
; - the ending of the second round (globals.loop, 40:EF5D) is the arcade's
;   0x120-frame wait, then the blackout and the stage's GAME OVER sequence
;   (message, ranking, no continue) instead of the arcade's banner over the
;   stars.
;*******************************************************************************

ending.T_STARS equ 16800-16698          ; the starfield, wave $0DE8
ending.T_FLEET equ 17013-16698          ; the fleet, wave $0F28
ending.T_DIR   equ 17360-16698          ; the director, wave $1130

; --- a ship, 40:FB53 ------------------------------------------------------------
S.st          equ 0                     ; 0 none, 1 flying
S.x           equ 1                     ; 1,2 int (+4), 3 frac (+3)
S.y           equ 4                     ; 4,5 int (+8), 6 frac (+7)
S.p           equ 7                     ; 7,8 its script entry, arcade (+0x10)
S.c           equ 9                     ; 9,10 its frame count (+0x12)
S.col         equ 11                    ; its colour rank (+0x06)
S.pose        equ 12                    ; the pose of its last frame, 0..2
S.SZ          equ 13
ending.NSHIP  equ 18

; --- the director, 40:EEB5.. ---------------------------------------------------
ending.D_P1   equ 1                     ; 40:EEB5
ending.D_P2   equ 2                     ; 40:EF09
ending.D_P3   equ 3                     ; 40:EF1E
ending.D_P4   equ 4                     ; 40:EF83
ending.D_P5   equ 5                     ; 40:EF97
ending.D_DONE equ 6

ending.SLOTSZ equ 6                     ; [on, x, y, imageset(2), unused]

;*******************************************************************************
; THE MANAGER (spawned by the stage 8 main when the dissolve is over)
;*******************************************************************************
ending.Object
        lda   routine,u
        bne   ending.Live
        ldx   #ending.Data              ; Init
        ldd   #ending.DataEnd-ending.Data
@clr    clr   ,x+
        subd  #1
        bne   @clr
        ldx   #ending.Slots
        ldb   #ending.NSHIP
!       clr   ,x
        leax  ending.SLOTSZ,x
        decb
        bne   <
        ldd   ending.gc0                ; the arcade frame of the bg fade
        std   ending.gc
        std   ending.g0
        jsr   LoadObject_x              ; the fleet's grouped renderer
        beq   >
        lda   #ObjID_ending_render
        sta   id,x
!       inc   routine,u
ending.Seeded                       ; test hook: gc final
        rts

ending.Live
        ldb   gfxlock.frameDrop.count
        pshs  u
        stb   ending.nfr
        beq   @pub
@f      jsr   ending.Frame
        dec   ending.nfr
        bne   @f
@pub    jsr   ending.Publish
        puls  u
ending.Sample                       ; test hook: a render's state is final
        lda   ending.dst
        cmpa  #ending.D_DONE
        bne   @rts
        ; the round ends: the bonus game (1) or, in the second round (40:EF5D
        ; second_loop), the game over (2). The bonus game is the next round:
        ; 40:EE7B increments the player's round counter (0x2F42 -> second_
        ; loop), which counts the continues too — it spends the quota (no
        ; continue in the second round, 40:12c1) — and the difficulty follows
        lda   #2
        tst   globals.loop
        bne   @set
        inc   globals.loop
        inc   game.continueUsed
        _difficulty.update
        lda   #1
@set    sta   ending.done
        jmp   UnloadObject_u
@rts    rts

;*******************************************************************************
; ONE ARCADE FRAME
;*******************************************************************************
ending.Frame
        ldd   ending.gc
        addd  #1
        std   ending.gc
        ldd   ending.speed              ; the engine first: the fg goes up
        addb  ending.yf
        stb   ending.yf
        adca  ending.y+1
        sta   ending.y+1
        lda   ending.y
        adca  #0
        anda  #1                        ; 9 bits (0x2EC6 holds bit 8)
        sta   ending.y
ending.Tick                         ; test hook: frame ending.gc, before any actor
        lda   ending.dst                ; 0x0100 the director
        beq   >
        jsr   ending.Dir
!       ldy   #ending.Ships             ; 0xFF70 the ships
@s      lda   S.st,y
        beq   >
        jsr   ending.Ship
!       leay  S.SZ,y
        cmpy  #ending.ShipsEnd
        blo   @s
        ldd   ending.gc                 ; the wave's creations, at their frames
        subd  ending.g0
        cmpd  #ending.T_STARS
        bne   >
        ldy   #3                        ; variant 3, the final cinematic
        lda   #map.RAM_OVER_CART+common.starfield.page
        ldx   #starfield.init
        jmp   paged.call
!       cmpd  #ending.T_FLEET
        lbeq  ending.FleetNew
        cmpd  #ending.T_DIR
        bne   @rts
        lda   #ending.D_P1
        sta   ending.dst
@rts    rts

;*******************************************************************************
; THE FLEET — 40:FB10 (creation), 40:FB53 (a ship)
;*******************************************************************************
ending.FleetNew
        ldx   #ending.Fleet
        ldy   #ending.Ships
@n      lda   #1
        sta   S.st,y
        ldd   ,x                        ; +0x10 its script
        std   S.p,y
        ldd   #$0120                    ; fb34 x = 0x120 (the frac: a leftover)
        std   S.x,y
        clr   S.x+2,y
        ldd   2,x                       ; fb39 y
        std   S.y,y
        clr   S.y+2,y
        clr   S.c,y
        clr   S.c+1,y
        lda   4,x
        sta   S.col,y
        lda   #1
        sta   S.pose,y
        leax  5,x
        leay  S.SZ,y
        cmpx  #ending.FleetEnd
        blo   @n
        rts

; Y = the ship
ending.Ship
        ldd   S.c,y                     ; fb53
        addd  #1
        std   S.c,y
        ldd   S.p,y
        std   ending.wP                 ; this frame's entry
        addd  #8                        ; fb59 the next entry's start
        jsr   ending.RomW
        cmpd  S.c,y
        bhi   >                         ; fb60 not reached yet
        ldd   S.p,y
        addd  #8
        std   S.p,y
!       ldd   ending.wP                 ; fb66 vx
        addd  #2
        jsr   ending.RomW
        leax  S.x,y
        jsr   ending.Move
        ldd   ending.wP                 ; fb6f vy
        addd  #4
        jsr   ending.RomW
        leax  S.y,y
        jsr   ending.Move
        ldd   ending.wP                 ; fb78 its picture
        addd  #6
        jsr   ending.RomW
        std   ending.wT
        ldx   #ending.Poses
        clrb
!       ldu   ,x++
        cmpu  ending.wT
        beq   >
        incb
        cmpb  #2
        blo   <
!       stb   S.pose,y
        ldd   S.x,y                     ; fb83 off on the right
        cmpd  #$02E0
        blo   @rts
        clr   S.st,y
@rts    rts

; D = arcade address in the script range -> D = the word there (LE)
ending.RomW
        subd  #ending.SCRIPT_LO
        addd  #ending.Scripts
        tfr   d,x
        ldb   ,x
        lda   1,x
        rts

; X = position (int:2, frac:1), D = signed 8.8
ending.Move
        pshs  a
        addb  2,x
        stb   2,x
        puls  b
        sex
        adcb  1,x
        adca  ,x
        std   ,x
        rts

;*******************************************************************************
; THE DIRECTOR — 40:EEB5 .. EF97
;*******************************************************************************
ending.Dir
        lda   ending.dst
        cmpa  #ending.D_P1
        beq   ending.P1
        cmpa  #ending.D_P2
        beq   ending.P2
        cmpa  #ending.D_P3
        beq   ending.P3
        cmpa  #ending.D_P4
        lbeq  ending.P4
        cmpa  #ending.D_P5
        lbeq  ending.P5
        rts

ending.P1
        lda   #1                        ; eeb5 the HUD band off (0x2EBE = 0)
        sta   ending.hudOff
        clr   ending.y                  ; eec8 Y = 0xF0.00 (0x2EC4 = 0xF000)
        lda   #$F0
        sta   ending.y+1
        clr   ending.yf
        jsr   ending.Clear              ; eedc init_fg_tilemap
        lda   #ending.D_FIRST0          ; eee2 the first two lines
        jsr   ending.Write
        lda   #ending.D_FIRST1
        jsr   ending.Write
        clr   ending.d10                ; eef4 the table, its first entry
        clr   ending.d10+1
        ldd   #$0030
        std   ending.d12
        ldd   #$0560
        std   ending.d14
        lda   #2                        ; ef09 waits three frames (measured)
        sta   ending.wait
        lda   #ending.D_P2
        sta   ending.dst
        rts

ending.P2
        lda   ending.wait               ; ef09 the fg loader catches up
        beq   >
        dec   ending.wait
        rts
!       ldd   #$0080                    ; ef13 the text goes up, 0.5 px
        std   ending.speed
        lda   #ending.D_P3
        sta   ending.dst
ending.P3
        ldd   ending.d12                ; ef1e a line every 0x40 frames
        subd  #1
        std   ending.d12
        bne   @d14
        ldd   #$0040
        std   ending.d12
        ldx   #ending.Lines
        ldd   ending.d10
        leax  d,x
        addd  #1
        std   ending.d10
        lda   ,x
        cmpa  #$FF
        beq   @end
        jsr   ending.Write
        bra   @d14
@end    ldd   #0                        ; ef3f the table is over: the text
        std   ending.speed              ; stops
        ldd   #$FFFF
        std   ending.d12
@d14    ldd   ending.d14                ; ef49
        subd  #1
        std   ending.d14
        bne   @rts
        clr   ending.y                  ; ef4f Y = 0
        clr   ending.y+1
        clr   ending.yf
        tst   globals.loop              ; ef5d second_loop: no bonus game,
        bne   @over                     ; the game over sequence (efad)
        lda   #ending.D_ENJOY           ; ef64 ENJOY THE BONUS GAME AGAIN
        jsr   ending.Write
        ldd   #$0080
        std   ending.d10
        lda   #ending.D_P4
        sta   ending.dst
@rts    rts
@over   ldd   #$0120                    ; efad: 0x120 frames, then the game
        std   ending.d10                ; over (the stage's own sequence,
        lda   #ending.D_P4              ; after the blackout)
        sta   ending.dst
        rts

ending.P4
        ldd   ending.d10                ; ef83
        subd  #1
        std   ending.d10
        bne   @rts
        lda   #1                        ; ef89 the blackout
        sta   ending.black
        ldd   #$0040
        std   ending.d10
        lda   #ending.D_P5
        sta   ending.dst
@rts    rts

ending.P5
        ldd   ending.d10                ; ef97
        subd  #1
        std   ending.d10
        bne   @rts
        jsr   ending.Clear              ; ef9d init_fg_tilemap
        lda   #ending.D_DONE
        sta   ending.dst
@rts    rts

; A = descriptor rank: its row gets its string (or nothing: a blank line)
ending.Write
        ldx   #ending.Desc
        asla
        leax  a,x
        ldb   ,x                        ; its row
        lda   1,x                       ; its string rank + 1
        ldx   #ending.rowText
        sta   b,x
        rts

ending.Clear
        ldx   #ending.rowText
        ldb   #64
!       clr   ,x+
        decb
        bne   <
        rts

;*******************************************************************************
; PUBLICATION — once per render
;*******************************************************************************
ending.Publish
        ldd   ending.y                  ; the text's scroll, int (9 bits)
        std   ending.textY
        ldu   #ending.Slots
        ldy   #ending.Ships
@s      clr   ,u
        lda   S.st,y
        beq   @n
        ldd   S.x,y
        pshs  y
        ldy   S.y,y
        jsr   ending.ToScreen
        puls  y
        adda  #screen_left
        addb  #screen_top
        std   1,u
        lda   S.col,y                   ; its picture: colour * 3 + pose
        ldb   #3
        mul
        addb  S.pose,y
        aslb
        ldx   #ending.FleetSets
        ldx   b,x
        stx   3,u
        lda   #1
        sta   ,u
@n      leau  ending.SLOTSZ,u
        leay  S.SZ,y
        cmpy  #ending.ShipsEnd
        blo   @s
        rts

; D = arcade x, Y = arcade y -> A = x, B = y on the screen (0-based, clamped)
ending.ToScreen
        subd  #320
        std   ending.wT
        aslb
        rola
        addd  ending.wT
        asra
        rorb
        asra
        rorb
        asra
        rorb
        addd  #8
        jsr   ending.Clamp
        stb   ending.wX
        tfr   y,d
        std   ending.wT
        aslb
        rola
        addd  ending.wT
        asra
        rorb
        asra
        rorb
        std   ending.wT
        ldd   #297
        subd  ending.wT
        jsr   ending.Clamp
        lda   ending.wX
        rts

ending.Clamp
        tsta
        beq   @rts
        bmi   @lo
        ldb   #255
        rts
@lo     clrb
@rts    rts

;*******************************************************************************
; THE GROUPED RENDERER — every lit ship slot; this page is the one
; BuildSprites mounted to call it (the fake picture names it)
;*******************************************************************************
ending.FakeImg
        fcb   ending.FakeSub-ending.FakeImg,ending.FakeSub-ending.FakeImg
        fcb   ending.FakeSub-ending.FakeImg,ending.FakeSub-ending.FakeImg
        fcb   8,8,0
ending.FakeSub
        fcb   0
        fcb   ending.FakeMf-ending.FakeSub
        fcb   0
        fcb   ending.FakeMf-ending.FakeSub
        fcb   0,0
ending.FakeMf
        fcb   0                          ; page, patched by the renderer
        fdb   ending.DrawAll

ending.Render
        lda   routine,u
        bne   @live
        _GetCartPageA
        ldb   id,u
        ldx   #Img_Page_Index
        sta   b,x
        sta   ending.FakeMf
        ldd   #ending.FakeImg
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
@live   lda   ending.dst
        cmpa  #ending.D_DONE
        bne   >
        jmp   DeleteObject
!       jmp   DisplaySprite

ending.DrawAll
        ldx   #ending.Slots
@loop   lda   ,x
        beq   @next
        stx   ending.wS
        ldd   1,x
        ldx   3,x                        ; its imageset
        pshs  a,b
        _sprite.cull ending.DrawAll.off
        lda   ,s
        suba  imgset.center,x
        ldb   1,s
        pshs  x
        jsr   DRS_XYToAddress
        puls  x
        ; a ship moves by ONE pixel: the variant shifted by 1 px (ND1, its
        ; routine at 17) on the odd x, as BuildSprites picks it (x ^ centre)
        lda   ,s
        eora  imgset.center,x
        bita  #1
        bne   >
        ldx   14,x                       ; ND0
        bra   @draw
!       ldx   17,x                       ; ND1
@draw   ldu   <glb_screen_location_2
        jsr   ,x
ending.DrawAll.off
        leas  2,s
        ldx   ending.wS
@next   leax  ending.SLOTSZ,x
        cmpx  #ending.SlotsEnd
        blo   @loop
        rts

;*******************************************************************************
; THE PICTURES
;*******************************************************************************
ending.FleetSets
        fdb   set_fleet_0,set_fleet_1,set_fleet_2,set_fleet_3,set_fleet_4,set_fleet_5
        fdb   set_fleet_6,set_fleet_7,set_fleet_8,set_fleet_9,set_fleet_10,set_fleet_11
        fdb   set_fleet_12,set_fleet_13,set_fleet_14,set_fleet_15,set_fleet_16,set_fleet_17

;*******************************************************************************
; THE DATA (page) — cleared at every Init
;*******************************************************************************
ending.nfr    fcb   0
ending.Slots  fill  0,ending.NSHIP*ending.SLOTSZ
ending.SlotsEnd

ending.Data
ending.gc     fdb   0                    ; the arcade global counter (0x2EB6)
ending.g0     fdb   0                    ; the frame of the bg fade
ending.y      fdb   0                    ; the text's Y, int (0x2EC6:0x2EC4 hi)
ending.yf     fcb   0                    ; its frac (0x2EC4 lo)
ending.speed  fdb   0                    ; 0x2EF0
ending.dst    fcb   0                    ; the director
ending.d10    fdb   0                    ; +0x10 (the table: a rank here)
ending.d12    fdb   0                    ; +0x12
ending.d14    fdb   0                    ; +0x14
ending.wait   fcb   0
ending.wP     fdb   0
ending.wT     fdb   0
ending.wX     fcb   0
ending.wS     fdb   0
ending.Ships  fill  0,ending.NSHIP*S.SZ
ending.ShipsEnd
ending.DataEnd

        INCLUDE "src/stages/08/ending/tables.asm"
