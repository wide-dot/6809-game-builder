; ---------------------------------------------------------------------------
; Object (mounted) - generic end of stage sequencer (stages without a real
; boss yet)
;
; The stage 1 protocol (obj_endstage.asm), stripped of everything
; Dobkeratops : no boss room camera cap, no boss body state, no room-erase
; blit. The stand-in boss battle is a HOLD : once the camera reaches the end
; of the map, a timeout runs (the boss music started just before, seeded by
; the wave marker) and its expiry counts as the victory — the exact
; BOSS_ESCAPE gesture of stage 1. Then the shared sequence : countdown,
; clear jingle + ship autopilot, pixel fade to black, score readout, DONE.
;
; input  REG : [b] command: endstage.TICK, endstage.INIT or endstage.BLIT
; output REG : [b] status (TICK only): endstage.STATUS_NONE,
;                  endstage.STATUS_JINGLE (main starts the jingle, the ymm
;                  player cannot be mounted from here) or STATUS_DONE
; ---------------------------------------------------------------------------

SCORE_HOLD_FRAMES equ 50     ; pause ecran noir entre la fin du fade-out pixel
                             ; et le releve de score (meme valeur que stage 1)

Object
        tstb
        beq   Tick
        cmpb  #endstage.INIT
        beq   InitSequence
        jmp   Blit

* ---------------------------------------------------------------------------
* reset the sequence state (level start and checkpoint reload)
* ---------------------------------------------------------------------------

InitSequence
        ldd   #0
        std   main.endstage.counter
        clr   main.endstage.phase
        clr   globals.bossDefeated
        clr   main.endstage.scoreArmed
        clr   main.endstage.scoreDone
        clr   terrainCollision.disabled     ; debut niveau : terrain actif
        ldd   #endlevel.BOSS_HOLD           ; arme le combat de substitution
        std   bossHold.timer
        lda   #SCORE_HOLD_FRAMES            ; arme la pause ecran noir post fade-out
        sta   scoreHold.timer
        rts

bossHold.timer  fdb 0  ; frames left in the stand-in boss battle hold
scoreHold.timer fcb 0  ; phase 3->4: ~0.5 s black-screen hold before the readout

* ---------------------------------------------------------------------------
* end of stage sequencing
* ---------------------------------------------------------------------------

Tick
        ldd   main.endstage.counter
        lbne  @run                          ; sequence already armed
        ; a REAL boss has finished : it raises globals.bossDefeated itself and
        ; that alone arms the sequence (stage 2's gomander does this on both
        ; its exits). Nothing sets the flag in the stages that still rely on
        ; the stand-in below, so this test is inert for them.
        lda   globals.bossDefeated
        bne   @beaten
        ; no sequence yet : the stand-in boss battle — camera at the end of
        ; the map, then the hold ; its expiry counts as the victory
        ldd   glb_camera_x_pos
        cmpd  scroll_max
        blo   @none                         ; still scrolling the level
        ldd   bossHold.timer
        subd  gfxlock.frameDrop.count_w
        ble   @beaten
        std   bossHold.timer
@none   ldb   #endstage.STATUS_NONE
        rts
@beaten
        ; hold expired : the boss is deemed beaten (stage 1's BOSS_ESCAPE
        ; routes the same way) — arm the countdown and the invulnerability
        lda   #1
        sta   globals.bossDefeated
        ldd   #endstage.DURATION
        std   main.endstage.counter
        lda   #endstage.SHIP_INVINCIBLE
        sta   player1+ext_variables+AABB.p
        bra   @none
@run
        ; ship cannot die during the end sequence — negative potential, the
        ; invincible box (see obj_endstage.asm for the full reasoning)
        lda   #endstage.SHIP_INVINCIBLE
        sta   player1+ext_variables+AABB.p
        ldd   main.endstage.counter         ; reload: the lda clobbered A
        subd  gfxlock.frameDrop.count_w
        bgt   >
        ldd   #1                            ; floor, sequence stays latched
!       std   main.endstage.counter
        tst   main.endstage.phase
        bne   @pilot
        ; phase 0: free play until T-$10, then jingle + ship autopilot
        cmpd  #endstage.JINGLE
        bhi   @none2
        inc   main.endstage.phase
        lda   #-2
        sta   player1+subtype               ; autopilot: no control, ship displayed
        jsr   AutoPilot
        ldb   #endstage.STATUS_JINGLE       ; main starts the stage clear jingle
        rts
@pilot
        jsr   AutoPilot
        lda   main.endstage.phase
        cmpa  #2
        beq   @glide
        bhi   @phase34
        ; phase 1: hold until the countdown expires. The camera is already at
        ; the end of the map (no boss room to scroll past) : no cap to lift,
        ; the glide condition of phase 2 is immediately satisfiable.
        ldd   main.endstage.counter
        cmpd  #1
        bhi   @none2
        inc   main.endstage.phase
        bra   @none2
@glide
        ; arm the fade only when BOTH buffers rest at the cap — the exact
        ; condition of Scroll's early-out (see obj_endstage.asm, the residue
        ; measured when DrawTiles repaints over the dissolve)
        ldx   scroll_max
        cmpx  buffer_x_pos
        bne   >
        cmpx  buffer_x_pos+2
        bne   >
        inc   main.endstage.phase
        jsr   InitFadeOut
!       bra   @none2
@phase34
        ; phase 3: the dissolve runs in Blit ; phase 4: the HUD readout runs
        lda   main.endstage.phase
        cmpa  #4
        blo   @none2
        lda   #1                            ; keep ship/pod painted on BOTH pages
        sta   <glb_force_sprite_refresh
        lda   main.endstage.scoreDone
        beq   @none2
        ; readout + hold done : black the palette before the cut, silence the
        ; sound chips, and let the stage hand over
        ldd   #Pal_black
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow
        jsr   IrqOff
        jsr   ResetSN
        jsr   ResetYM
        ldb   #endstage.STATUS_DONE
        rts
@none2  ldb   #endstage.STATUS_NONE
        rts

* ---------------------------------------------------------------------------
* end-level autopilot + frame-drop scaling - verbatim from obj_endstage.asm
* ---------------------------------------------------------------------------

AutoPilot
        ldd   #0
        std   player1+x_vel
        std   player1+y_vel
        ldd   player1+x_pos
        subd  glb_camera_x_pos
        subd  #endstage.RALLY_X
        bmi   @shipLeft
        cmpd  #endstage.DEADBAND
        blo   @yAxis
        ldd   #scale.XN1PX
        bsr   VelScale
        std   player1+x_vel
        bra   @yAxis
@shipLeft
        cmpd  #-endstage.DEADBAND
        bgt   @yAxis
        ldd   #scale.XP1PX
        bsr   VelScale
        std   player1+x_vel
@yAxis
        ldd   player1+y_pos
        subd  glb_camera_y_pos
        subd  #endstage.RALLY_Y
        bmi   @shipAbove
        cmpd  #endstage.DEADBAND
        blo   @done
        ldd   #scale.YN1PX
        bsr   VelScale
        std   player1+y_vel
        rts
@shipAbove
        cmpd  #-endstage.DEADBAND
        bgt   @done
        ldd   #scale.YP1PX
        bsr   VelScale
        std   player1+y_vel
@done   rts

VelScale
        std   vel.base
        ldb   gfxlock.frameDrop.count
        bne   >
        ldb   #1
!       stb   vel.cnt
        ldd   #0
@l      addd  vel.base
        dec   vel.cnt
        bne   @l
        rts
vel.base fdb 0
vel.cnt  fcb 0

* ---------------------------------------------------------------------------
* Sound chip silence - verbatim from obj_endstage.asm (game-mode 00 LaunchGame)
* ---------------------------------------------------------------------------

ResetSN
        lda   #$9F
        sta   SN76489.D
        nop
        nop
        lda   #$BF
        sta   SN76489.D
        nop
        nop
        lda   #$DF
        sta   SN76489.D
        nop
        nop
        lda   #$FF
        sta   SN76489.D
        rts

ResetYM
        ldd   #$200E
        stb   YM2413.A
        nop                                 ; (wait of 2 cycles)
        ldb   #0                            ; (wait of 2 cycles)
        sta   YM2413.D                      ; note off for all drums
        lda   #$20                          ; (wait of 2 cycles)
        brn   *                             ; (wait of 3 cycles)
@a      exg   a,b                           ; (wait of 8 cycles)
        exg   a,b                           ; (wait of 8 cycles)
        sta   YM2413.A
        nop
        inca
        stb   YM2413.D
        cmpa  #$29                          ; (wait of 2 cycles)
        bne   @a                            ; (wait of 3 cycles)
        rts

* ---------------------------------------------------------------------------
* Blit - phase 3 drives the pixel dissolve inside the gfx lock ; no boss
* room to erase here, the other phases have nothing to paint
* ---------------------------------------------------------------------------

Blit
        lda   main.endstage.phase
        cmpa  #3
        beq   BlitPhase3
        rts

BlitPhase3
        lda   FadeCnt
        beq   @scoreHold                    ; fade done on both pages
        lda   #1
        sta   <glb_force_sprite_refresh     ; redraw ship/pod over the erase
        jmp   FadeOut
@scoreHold
        ldb   scoreHold.timer
        beq   @toReadout
        subb  gfxlock.frameDrop.count
        bls   @toReadout
        stb   scoreHold.timer
        lda   #1
        sta   <glb_force_sprite_refresh
        rts
@toReadout
        lda   #1
        sta   <glb_force_sprite_refresh
        lda   #1
        sta   main.endstage.scoreArmed      ; HUD: (re)seed the readout
        lda   #4
        sta   main.endstage.phase
        rts

* ---------------------------------------------------------------------------
* Fondu au noir par tramage (phase 3) — le module engine, testable hors
* R-Type (game-mode fadetest). Fournit InitFadeOut / FadeOut / FadeCnt.
* ---------------------------------------------------------------------------
        INCLUDE "./engine/graphics/fade/pixel-fade.asm"
