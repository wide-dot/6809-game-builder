;*******************************************************************************
; dop — the stage 6 wave's Dops (45 lines), ported 1:1 from the arcade
;
; PORTING SHEET (source: Ghidra `maincpu`, subsystem enemy_dop)
; ------------------------------------------------------------------------------
;   40:5EED create_dop ...................... dop.Init
;   40:F9B5 load_state_preset_4 ............. the speed set (1000:931C)
;   40:F9C9 load_dop_preset_position_and_direction  start (1000:9324)
;   40:5F3C run_dop ......................... dop.Run, one arcade frame
;   40:6081 collision_with_dop .............. the two boxes (dop.Publish)
;   40:6048 dop_die / 40:6035 unload ........ dop.Die / dop.Gone
;
; THE SAME CRITTER AS THE BOSS'S (src/enemies/dop/obj.asm, its sheet tells the
; walk): four lanes, a speed per lane, three look-ahead probes, a turn on a
; solid tile. What differs for a wave Dop: its start comes from a preset
; (token bits 0-3), its speed set from token bits 4-5, its turn and facing
; from bits 8 and 6, and the scroll drags it (5F84 adds scroll_amount).
;
; WORLD COORDINATES. The arcade keeps a SCREEN x and adds scroll_amount every
; frame; its foreground camera is floor(g/2) on this stage (one column every
; two frames, 0x2EC1 traced under MAME), halted at 2684 by the swarm. So the
; screen x plus the camera — the WORLD x — only changes by the Dop's own
; speed, and the probe's cell is floor((world x - 320) / 8) of the stage map.
; The port keeps the world x (arcade px, 16.8) and the arcade y.
;
; THE WALK IS PRECOMPUTED. Nothing in it is random: the speed is fixed, the
; map is fixed, the camera is min(g/2, 2684) — the whole path of a wave Dop
; follows from its birth frame and its token. tools/gen_stage6_paths.py
; replays run_dop offline (its model, dop6_model.py, matched the MAME trace
; of the stage on every frame: positions and lanes of the 37 Dops it holds)
; and writes the turns and the exit only (src/stages/06/paths.asm, a path a
; birth, the checkpoint's births included). A frame here is a move and a
; frame compare: the three probes a frame cost the stage half its rate.
;
; THE PICTURE is the boss's (stage6.dopswarm, its page in Img_Page_Index):
; four poses a facing, the blink one whitened picture a facing. The boxes
; live in resident RAM (dops.boxes, stage 6 main), two per slot.
;
; DEVIATIONS: as the boss's (collision once per render, the armored front an
; invincible box, palettes not swapped, the 64-frame body pulse not played).
;*******************************************************************************

dop.wx        equ ext_variables      ; 0..2 world x, 16.8 arcade px
dop.wy        equ ext_variables+3    ; 3..5 y, 16.8 arcade px (up)
dop.lane      equ ext_variables+6    ; 0..3 (+0x20)
dop.B         equ ext_variables+8    ; facing left, look-ahead B (+0x2E)
dop.vs        equ ext_variables+9    ; speed set offset (+0x22)
dop.bl        equ ext_variables+10   ; hit blink (+0x11)
dop.pp        equ ext_variables+11   ; rear box potential seen last render
dop.slot      equ ext_variables+12   ; its boxes in dops.boxes
dop.show      equ ext_variables+13   ; the last frame painted the blink
; THE PATH (src/stages/06/paths.asm, tools/gen_stage6_paths.py): the walk
; replayed offline on the stage map, one entry {frame, lane} a turn — the
; frame's move, then the turn, as 606b — and {frame, $FF} where the arcade's
; is_visible_range (5fd0) drops it. No probe is left at run time.
dop.path      equ ext_variables+14   ; 14,15 the next entry
dop.next      equ ext_variables+16   ; 16,17 its frame

dop.NSLOT     equ 8                  ; six live at most (traced at g 1696)
dop.CAMSTOP   equ 2684               ; the swarm halts the camera (5368/2)
dop.GC0LO     equ 56003&255          ; the arcade counter at stage clock 0
dop.HP        equ 10                 ; 5f1a damage_max
dop.BLINK     equ $1F                ; 60b5
; the boxes, from 1000:2B20 (arcade px, scaled 3/8 and 3/4) — the boss's
dop.FRONT_RX  equ 12                 ; -36..28 : 64 px wide
dop.FRONT_RY  equ 18                 ; -24..24
dop.FRONT_DX  equ 4                  ; centre -4 (A) / +4 (B), arcade px
dop.REAR_RX   equ 2                  ; 28..40 : 12 px wide
dop.REAR_RY   equ 10                 ; -14..14
dop.REAR_DX   equ 34                 ; centre +34 (A) / -34 (B), arcade px

dop.Object
        lda   routine,u
        asla
        ldx   #dop.Routines
        jmp   [a,x]
dop.Routines
        fdb   dop.Init
        fdb   dop.Live
        fdb   dop.Deleted

; -----------------------------------------------------------------------------
; 40:5EED create_dop — born on frame g, it ticks from g + 1
; -----------------------------------------------------------------------------
dop.Init
        ldb   wave_frame_drop,u        ; the lateness, BEFORE anything else
        stb   dop.late
        ldd   subtype_w,u              ; the token, BEFORE render_flags
        std   dop.tok
        ; a slot for its boxes
        ldb   #1
        clr   dop.slot,u
@slot   bitb  dops.used
        beq   @free
        inc   dop.slot,u
        aslb
        bne   @slot
        jmp   DeleteObject             ; no slot (never traced: six at most)
@free   orb   dops.used
        stb   dops.used
        clr   dop.B,u                  ; 5f09 token & 0x40 -> B (5efc the
        ldb   dop.tok+1                ; turn, token & 0x100: in the path)
        bitb  #$40
        beq   >
        inc   dop.B,u
!       lsrb                           ; f9b5 bits 4-5: the speed set
        lsrb
        lsrb
        lsrb
        andb  #3
        ldx   #dsw.VelSet
        lda   b,x
        sta   dop.vs,u
        ldb   dop.tok+1                ; f9c9 bits 0-3: the start
        andb  #$0F
        lda   #6
        mul
        ldx   #dsw.Preset
        abx
        ldd   gfxlock.frame.gameCount  ; the birth frame
        subb  dop.late
        sbca  #0
        std   dop.g
        jsr   dop.Cam
        addd  ,x                       ; screen x + camera = world x
        std   dop.wx,u
        clr   dop.wx+2,u
        ldd   2,x
        std   dop.wy,u
        clr   dop.wy+2,u
        lda   5,x
        sta   dop.lane,u
        clr   dop.bl,u
        clr   dop.show,u
        ldx   #dop.Paths               ; the path of this birth
        jsr   dop.FindPath
        stx   dop.path,u
        ldd   ,x
        std   dop.next,u
        lda   #dop.HP
        sta   dop.pp,u
        jsr   dop.BoxesIn
        ldb   #4
        stb   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        inc   routine,u
        ldb   dop.late
        bra   dop.Run

dop.Live
        jsr   dop.HitWatch
        lda   dop.slot,u               ; 5fca damage >= 10 ? (the boxes are
        jsr   dop.RearBox              ; judged once a render)
        lda   AABB.p,x
        lbeq  dop.Die
        ldb   gfxlock.frameDrop.count
        bne   dop.Run
        incb
dop.Run
        stb   dop.n
        lbeq  dop.Publish
@frame  ldd   gfxlock.frame.gameCount  ; the frame replayed
        subb  dop.n
        sbca  #0
        addd  #1
        std   dop.g
        jsr   dop.Walk                 ; 5f66 the lane's speed (5f84: the
        clr   dop.show,u               ; world x leaves the scroll out)
        lda   dop.bl,u
        beq   >
        jsr   dop.Blink
!       ldd   dop.g                    ; 606b the turn, 5fd0 the exit
        cmpd  dop.next,u
        blo   @next
        ldx   dop.path,u
        lda   2,x
        cmpa  #$FF
        lbeq  dop.Gone
        sta   dop.lane,u
        leax  3,x
        stx   dop.path,u
        ldd   ,x
        std   dop.next,u
@next   dec   dop.n
        bne   @frame
        jmp   dop.Publish
dop.Deleted
        rts

; 5f96 the blink: counted on the frames where blink & frame bits
; ((counter & 0x18) >> 1) is not zero; A = dop.bl
; -----------------------------------------------------------------------------
dop.Blink
        ldb   dop.g+1
        addb  #dop.GC0LO
        andb  #$18
        lsrb
        stb   dop.t
        anda  dop.t
        beq   @rts
        dec   dop.bl,u                 ; 5fa9
        lda   dop.bl,u
        bita  #4                       ; 5fac bit 2 clear: the blink picture
        bne   @rts
        inc   dop.show,u
@rts    rts

; X = the paths {birth, path}, dop.g = the birth -> X = its path (one that
; leaves at once when the birth is not listed)
dop.FindPath
        ldd   dop.g
!       cmpd  ,x
        beq   >
        ldy   ,x++
        leax  2,x
        cmpy  #$FFFF
        bne   <
        ldx   #dop.NoPath
        rts
!       ldx   2,x
        rts
        fcb   0                        ; (a Newt's y fraction)
dop.NoPath
        fdb   0
        fcb   $FF

; one frame of the lane's speed (5f66), X kept
dop.Walk
        pshs  x
        lda   dop.lane,u
        asla
        asla
        adda  dop.vs,u
        ldx   #dsw.Vel
        leax  a,x
        ldd   ,x                       ; one of the two is always zero
        beq   >
        pshs  x
        leax  dop.wx,u
        jsr   dop.Move
        puls  x
!       ldd   2,x
        beq   >
        leax  dop.wy,u
        jsr   dop.Move
!       puls  x,pc

; 40:6048 dop_die: score 0x8708, the big grey-brown explosion
dop.Die
        ldb   #dop_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x             ; 6065 tick := 0xE817
        beq   dop.Gone
        _ldd  ObjID_explosion,explosion.subtype.big.brown+explosion.sfx.big
        std   id,x
        jsr   dop.Place                ; D = x_pos, dop.t = y_pos
        std   x_pos,x
        ldd   dop.t
        std   y_pos,x
; 40:6035 the silent unload
dop.Gone
        jsr   dop.BoxesOut
        lda   #2
        sta   routine,u
        jmp   DeleteObject

; D = frame g -> D = the arcade camera, min(g / 2, 2684)
dop.Cam
        lsra
        rorb
        cmpd  #dop.CAMSTOP
        bls   >
        ldd   #dop.CAMSTOP
!       rts

; move_x/y_pos_8_8: X = the position (int:2, frac:1), D = signed 8.8
dop.Move
        pshs  a
        addb  2,x
        stb   2,x
        puls  b
        sex
        adcb  1,x
        adca  ,x
        std   ,x
        rts

; -----------------------------------------------------------------------------
; HitWatch — once per render: a rear potential that dropped is a hit (60B5
; latches the blink for 0x1F frames)
; -----------------------------------------------------------------------------
dop.HitWatch
        lda   dop.slot,u
        jsr   dop.RearBox
        lda   AABB.p,x
        cmpa  dop.pp,u
        bhs   @rts
        sta   dop.pp,u
        lda   #dop.BLINK
        sta   dop.bl,u
@rts    rts

; -----------------------------------------------------------------------------
; PUBLICATION — once per render: the picture and the two boxes
; -----------------------------------------------------------------------------
dop.Publish
        jsr   dop.Place
        std   x_pos,u
        ldd   dop.t
        std   y_pos,u
        ; 5f96 the picture: (counter & 0x18) >> 3, facing right (A) or left
        ; (B), the white one on a blink frame
        ldb   gfxlock.frame.gameCount+1
        addb  #dop.GC0LO
        andb  #$18
        lsrb
        lsrb                           ; *2 (fdb table)
        ldx   #dop.SetsR
        tst   dop.B,u
        beq   >
        ldx   #dop.SetsL
!       tst   dop.show,u
        beq   >
        clrb                           ; the blink: one picture a facing
        leax  8,x
!       ldd   b,x
        std   image_set,u
        ; 6081 the boxes only once the Dop is in (screen x < 0x2B0)
        ldd   gfxlock.frame.gameCount
        jsr   dop.Cam
        std   dop.cam
        ldd   dop.wx,u
        subd  dop.cam
        std   dop.xs
        cmpd  #$02B0
        bhs   @park
        ldd   #dop.FRONT_DX            ; the front: -4 (A) / +4 (B)
        tst   dop.B,u
        bne   >
        ldd   #-dop.FRONT_DX
!       addd  dop.xs
        jsr   dop.Screen
        pshs  d
        lda   dop.slot,u
        jsr   dop.FrontBox
        puls  d
        jsr   dop.BoxPlace
        ldd   #-dop.REAR_DX            ; the rear: +34 (A) / -34 (B)
        tst   dop.B,u
        bne   >
        ldd   #dop.REAR_DX
!       addd  dop.xs
        jsr   dop.Screen
        pshs  d
        lda   dop.slot,u
        jsr   dop.RearBox
        puls  d
        jsr   dop.BoxPlace
        jmp   DisplaySprite
@park   lda   dop.slot,u
        jsr   dop.FrontBox
        ldd   #220*256+220
        jsr   dop.BoxPlace
        lda   dop.slot,u
        jsr   dop.RearBox
        ldd   #220*256+220
        jsr   dop.BoxPlace
        jmp   DisplaySprite

; the playfield place: D = 3 * (world x - 320) / 8 + 8 (x_pos), dop.t =
; 297 - 3 * y / 4 (y_pos) — the map's own frame, so the Dop sits on its tiles
dop.Place
        ldd   dop.wy,u
        std   dop.t
        aslb
        rola
        addd  dop.t                    ; *3
        asra
        rorb
        asra
        rorb
        std   dop.t
        ldd   #297
        subd  dop.t
        std   dop.t
        ldd   dop.wx,u
        subd  #320
        std   dop.px
        aslb
        rola
        addd  dop.px                   ; *3
        asra
        rorb
        asra
        rorb
        asra
        rorb
        addd  #8
        rts

; D = arcade screen x, dop.wy = y -> A = x, B = y on the screen (0-based,
; clamped to 0..255)
dop.Screen
        subd  #320
        std   dop.px
        aslb
        rola
        addd  dop.px
        asra
        rorb
        asra
        rorb
        asra
        rorb
        addd  #8
        jsr   dop.Clamp
        pshs  b
        ldd   dop.t                    ; y_pos (dop.Place ran before)
        jsr   dop.Clamp
        puls  a,pc

dop.Clamp
        tsta
        beq   @rts
        bmi   @lo
        ldb   #255
        rts
@lo     clrb
@rts    rts

; the box X centred on (A, B), screen 0-based; parked off screen when the
; centre clamps
dop.BoxPlace
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

; A = slot -> X = its front box (2n) / its rear box (2n+1)
dop.FrontBox
        asla
        bra   dop.BoxN
dop.RearBox
        asla
        inca
dop.BoxN
        ldb   #sizeof{AABB}
        mul
        addd  #dops.boxes
        tfr   d,x
        rts

; both boxes of the slot join the enemy list, cleaned first (manager-owned
; boxes: prev and next MUST be blank)
dop.BoxesIn
        lda   dop.slot,u
        jsr   dop.FrontBox
        ldd   #dop.FRONT_RX*256+dop.FRONT_RY
        std   dop.t
        lda   #-1                      ; invincible: shots die on it
        jsr   dop.BoxInsert
        lda   dop.slot,u
        jsr   dop.RearBox
        ldd   #dop.REAR_RX*256+dop.REAR_RY
        std   dop.t
        lda   #dop.HP
; X = the box, A = its potential, dop.t = rx:ry
dop.BoxInsert
        pshs  a,u,y
        ldb   #sizeof{AABB}
!       clr   ,x+
        decb
        bne   <
        leax  -sizeof{AABB},x
        ldd   dop.t
        sta   AABB.rx,x
        stb   AABB.ry,x
        lda   #220                     ; parked off screen until published
        sta   AABB.cx,x
        sta   AABB.cy,x
        lda   ,s
        sta   AABB.p,x
        ldy   #AABB_list_ennemy
        jsr   Collision_AddAABB
        puls  a,u,y,pc

dop.BoxesOut
        lda   dop.slot,u
        jsr   dop.FrontBox
        jsr   dop.BoxRemove
        lda   dop.slot,u
        jsr   dop.RearBox
        jsr   dop.BoxRemove
        ldb   dop.slot,u               ; the slot is free again
        lda   #1
!       tstb
        beq   >
        asla
        decb
        bra   <
!       coma
        anda  dops.used
        sta   dops.used
        rts
dop.BoxRemove
        pshs  u,y
        ldy   #AABB_list_ennemy
        sty   Collision_Remove_1
        sty   Collision_Remove_3
        leay  2,y
        sty   Collision_Remove_2
        jsr   Collision_RemoveAABB
        puls  u,y,pc

dop.SetsR
        fdb   set_dop_right_0,set_dop_right_1,set_dop_right_2,set_dop_right_3
        fdb   set_dop_righthit
dop.SetsL
        fdb   set_dop_left_0,set_dop_left_1,set_dop_left_2,set_dop_left_3
        fdb   set_dop_lefthit

dop.late      fcb   0
dop.n         fcb   0
dop.tok       fdb   0
dop.g         fdb   0
dop.cam       fdb   0
dop.xs        fdb   0
dop.px        fdb   0
dop.t         fdb   0

        INCLUDE "src/enemies/dop/tables.asm"
