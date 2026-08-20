; ---------------------------------------------------------------------------
; Object — stage 1 opening sequence (player fly-in)
;
; input REG : [u] pointer to Object Status Table (OST)
; ---------------------------------------------------------------------------
; ARCADE PORT (20/08/2026) — replaces the v1 initlevel1 phases, which were a
; loose mimic of the arcade entry, paced in RENDER LOOP TOURS: on the overlay
; renderer (flat full-window clear cost, ~2.9 frames/tour on the empty intro
; scene) the hidden phase stretched from ~90 to ~145 frames and the whole
; flight ran at 2/3 speed. This version is paced on gfxlock.frame.gameCount
; (frame-drop compensated) and follows the arcade script exactly.
;
; Arcade source (Ghidra maincpu, MCP asm-ark):
;   run_stage_clear_pilot 0x40:1F1B — installed for the player slot when the
;   alive gate [0x10] == 2 (fresh game and stage chaining) ; script cells at
;   0x1000:10C2, 8 bytes each: [time_threshold, x_delta 8.8, ship recipe,
;   flame recipe], advanced against frame_time (0x2F4B). Stage 1 clock epoch
;   0x600 (object_wave_stage1 first record, checkpoint 0 seed).
;     1F28  MOV word ptr [BP+0x4],0x120   ; spawn X — OFF SCREEN LEFT
;     1F2D  MOV word ptr [BP+0x8],0x110   ; spawn Y
;   Timeline (frames from stage start, thresholds 0x640/0x66D/0x672/0x6B1):
;     hold  64 f  at x=0x120 (screen -4.25 TO8 px), big flame, drawn clipped
;     zoom  45 f  at +4.0 arcade px/f = +1.5 TO8 px/f  -> screen x ~63
;     pause  5 f
;     drift 63 f  at -1.5 arcade px/f = -0.5625 TO8 px/f -> screen x ~28
;     hand-over: [0x10]:=1, run_player_one installed (0x1F66)
;   Death respawn (create_player_one 0x1FE5) has NO fly-in: fixed (0x1B0,
;   0x100) — the v2 checkpoint blink path is untouched.
;
; Not ported, visible in the arcade script and left out on purpose:
;   - the ship pose strip 0x1312->0x12FA stepping every 9 f during the zoom
;     (v2 SetVerticalAnim keeps the neutral frame, y_vel = 0) ;
;   - the flame recipe steps 0x1138/0x1150/0x1168 -> off at zoom+36 f : the
;     v2 engineflames object plays its own strip ; it is loaded at zoom start
;     and extinguished (routine Delete) at the pause, the v1 gesture ;
;   - the off-screen hold is HIDDEN here (subtype -1): the v2 renderer drops
;     a partially visible sprite instead of clipping it, so the arcade's
;     7-px nose peek cannot be shown — the ship pops at the left edge a few
;     frames into the zoom, already at full entry speed.
;
; State, on this object's own OST record:
;   subtype,u  sub-phase 0 hold / 1 zoom / 2 pause / 3 drift
;   x_pos,u    ship screen x, signed 8.8 (the ship is screen-anchored: the
;              player's x_pos is rewritten from the camera every tick)
;   y_pos,u    phase timer, frames left (byte)
;   anim,u     gameCount anchor of the last tick
; ---------------------------------------------------------------------------

; V2-DEVIATION: l'entree v1 s'appelle Object, un nom trop generique pour la
; frontiere de lien — meme ecart que l'eclair d'emission et le HUD.
initlevel1.Object
        lda   routine,u
        asla
        ldx   #Routines
        jmp   [a,x]

Routines
        fdb   IntroInit
        fdb   IntroTick
        fdb   AlreadyDeleted

intro.SX0     equ   $FBC0              ; screen x 8.8 at hold: -4.25 px (arcade 0x120)
intro.Y       equ   105                ; arcade 0x110 (respawn 0x100 <-> 93, +16 arcade px * 0.75)
intro.durations
        fcb   64,45,5,63               ; hold, zoom, pause, drift (0x640/0x66D/0x672/0x6B1 - 0x600)
intro.vel
        fdb   $0000                    ; hold
        fdb   $0180                    ; zoom  : +1.5 px/f (arcade +4.0 * 0.375)
        fdb   $0000                    ; pause
        fdb   -$0090                   ; drift : -0.5625 px/f (arcade -1.5 * 0.375)

* ---------------------------------------------------------------------------
* PLAYER 1 LEVEL 1 INTRO
* ---------------------------------------------------------------------------

IntroInit
        inc   routine,u
        clr   subtype,u                ; sub-phase 0 : hold
        lda   #-1
        sta   player1+subtype          ; ship hidden while off screen
        ldd   #intro.SX0
        std   x_pos,u
        lda   intro.durations
        sta   y_pos,u
        ldd   gfxlock.frame.gameCount
        std   anim,u
        rts

IntroTick
        ldd   gfxlock.frame.gameCount  ; game frames elapsed since last tick —
        ldx   anim,u                   ; the whole sequence is frame-drop
        std   anim,u                   ; compensated by construction
        pshs  x
        subd  ,s++
        tstb
        beq   IntroPlace               ; no game frame elapsed: just re-anchor
IntroStep
        pshs  b
        dec   y_pos,u                  ; phase timer
        beq   IntroAdvance
IntroMove
        ldb   subtype,u                ; sx += vel[phase]
        aslb
        ldx   #intro.vel
        ldd   b,x
        addd  x_pos,u
        std   x_pos,u
        puls  b
        decb
        bne   IntroStep
        bra   IntroPlace

IntroAdvance
        inc   subtype,u
        lda   subtype,u
        cmpa  #4
        beq   IntroHandOver
        ldx   #intro.durations         ; reload the timer for the new phase
        ldb   a,x
        stb   y_pos,u
        cmpa  #1
        beq   IntroEnterZoom
        cmpa  #2
        bne   IntroMove                    ; drift: no side effect
        ; enter pause : extinguish the engine flames (arcade turns the flame
        ; recipe off at zoom+36 f ; the v1 gesture is routine := Delete here)
        ldx   #0
engineflames equ *-2
        beq   IntroMove                    ; pool was full at zoom, no flames
        lda   #2                       ; engineflames Delete
        sta   routine,x
        bra   IntroMove

IntroEnterZoom
        lda   #-2
        sta   player1+subtype          ; visible, not controlled
        jsr   LoadObject_x             ; the engine flames ride along
        beq   IntroMove                    ; pool full : enter without flames
        stx   engineflames
        lda   #ObjID_engineflames
        sta   id,x
        bra   IntroMove

IntroHandOver
        puls  b                        ; drop the loop counter: the intro ends
        clr   player1+subtype          ; arcade 0x1F66: gate := 1, control handed
        bsr   IntroPlace               ; leave the ship at the arcade hand-over
        inc   routine,u                ; point (screen x ~28, y 105)
        jmp   DeleteObject

IntroPlace
        ; The arcade pilot holds SCREEN coordinates: re-derive the player's
        ; playfield position from the camera every tick, whatever the scroll
        ; and the Live drift-compensation did in between.
        ldb   x_pos,u                  ; signed integer part of sx
        sex
        addd  glb_camera_x_pos
        std   player1+x_pos
        ldd   #intro.Y
        std   player1+y_pos
        rts

AlreadyDeleted
        rts
