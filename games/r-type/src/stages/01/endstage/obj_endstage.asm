; ---------------------------------------------------------------------------
; Object (mounted) - Dobkeratops end of stage sequencer
;
; Mounted from the level 01 main loop. Carries the end of stage logic
; (arcade: run_dobkeratops parent tick, run_end_stage_sequence and
; EndLevelAutoPilot) outside of the resident main code space.
; Shared state lives in resident RAM (main.* variables).
;
; input  REG : [b] command: endstage.TICK, endstage.INIT or endstage.BLIT
; output REG : [b] status (TICK only): endstage.STATUS_NONE or
;                  endstage.STATUS_JINGLE (main must start the jingle,
;                  the ymm object cannot be mounted from here)
; ---------------------------------------------------------------------------
; V2-DEVIATION : en-tete porte par l'enveloppe unit.
;        INCLUDE "./engine/macros.asm"
; V2-DEVIATION : en-tete porte par l'enveloppe unit.
;        INCLUDE "./engine/collision/struct_AABB.equ"
; V2-DEVIATION : en-tete porte par l'enveloppe unit.
;        INCLUDE "./engine/objects/palette/fade/fade.equ"

SCORE_HOLD_FRAMES equ 50     ; pause ecran noir entre la fin du fade-out pixel

Object
        tstb
        beq   Tick
        cmpb  #endstage.INIT
        beq   InitSequence
        jmp   Blit

* ---------------------------------------------------------------------------
* reset boss sequencing state (level start and checkpoint reload)
* ---------------------------------------------------------------------------

InitSequence
        ; « jamais » : seul allEyesDead pose la vraie date, a la FIN de la
        ; derniere sequence d'effacement (contrat arcade). L'ancienne valeur
        ; ERASE_NERV_START+DELAY etait la date du TIMEOUT free-life : quand
        ; les nerfs mouraient par lui, machoire/monstre/queue (gardes sur ce
        ; timestamp) partaient pendant les effacements — allEyesDead prend le
        ; MIN et ne pouvait pas la repousser. Le corps, garde sur eyesAlive,
        ; attendait, lui : le boss se demembrait (vu en video, 31/08).
        ldd   #$FFFF
        std   main.timestamp.moveAlienStart
        ldd   #timestamp.MOVEALIEN_DIST*256       ; distance the body owes to the butee (8.8)
        std   main.dobkeratops.move.left
        clr   terrainCollision.bgByteOff          ; boss-follow bg collision offset starts at 0
        clr   terrainCollision.bgBitShift
        ldd   #$ffff
        std   main.dobkeratops.move.frame
        ldd   #0                                  ; MUST be cleared: the body stops calling
        std   main.dobkeratops.move.step          ;   followDobkeratops once on the butee, so the
                                                  ;   last non-zero step stays latched. The tailmgr
                                                  ;   reads move.step directly -> without this the
                                                  ;   19 tails drift left from their spawn on the
                                                  ;   next try (checkpoint reload / GAME OVER
                                                  ;   restart, which do not reload this RAM).
        ldd   #0
        std   main.endstage.counter
        clr   main.endstage.phase
        clr   main.dobkeratops.halfDamage
        clr   main.dobkeratops.nervesErasing
        clr   main.dobkeratops.explode
        clr   globals.bossDefeated
        clr   terrainCollision.disabled         ; debut niveau : terrain actif (re-arme apres fin de stage)
        clr   main.endstage.scoreArmed
        clr   main.endstage.scoreDone
        lda   #SCORE_HOLD_FRAMES               ; arme la pause ecran noir post fade-out
        sta   scoreHold.timer
        rts

scoreHold.timer fcb 0  ; phase 3->4: ~0.5 s black-screen hold before the score readout

* ---------------------------------------------------------------------------
* end of stage sequencing (arcade: run_dobkeratops parent tick)
* ---------------------------------------------------------------------------

Tick
        ; hold the camera at the boss room until the victory scroll-out (phase >= 2):
        ; cap the scroll at bossStopX. The Scroll applies the cap per buffer, so the
        ; boss room frames at exactly the same position on both (no frame-drop
        ; overshoot, and the X0-only eraser sprites keep their even parity).
        lda   main.endstage.phase
        cmpa  #2
        bhs   @scrollFree
        ldd   #endstage.bossStopX
        std   scroll_max
@scrollFree
        ldd   main.endstage.counter
        bne   @run                          ; sequence already armed
        lda   main.dobkeratops.explode       ; boss killed AND the nerve erase is done?
        bne   @arm
        ldx   gfxlock.frame.gameCount           ; boss escapes (arcade: +0x3E timeout expires)
        cmpx  #timestamp.BOSS_ESCAPE
        blo   @none
        ; engagement timeout with the boss still alive (only reachable when the player
        ; survived the butee, e.g. blink invincibility). Route it through the NORMAL
        ; teardown instead of just arming the countdown: monster.WaitEndStage sees
        ; bossDefeated and runs MonsterKill (explosions, explode flag, room erase,
        ; delete). Without it the body would stay painted during the scroll-out.
        lda   #1
        sta   globals.bossDefeated
@arm
        ldd   #endstage.DURATION
        std   main.endstage.counter
        lda   #endstage.SHIP_INVINCIBLE     ; arm the invulnerability on the arming frame too
        sta   player1+ext_variables+AABB.p
@none
        ldb   #endstage.STATUS_NONE
        rts
@run
        ; ship cannot die during the end sequence (arcade: HitPlayerOne gated by
        ; stage_unload_request). It MUST be a negative potential (invincible box):
        ; 127 is the ship's normal "weak" value, which Collision_Do clears on the
        ; first contact - and this Tick runs AFTER the collision pass and after
        ; player1 in the main loop, so restoring 127 could never save the frame.
        ; Invincible boxes are never modified by Collision_Do nor by TM_Collide.
        lda   #endstage.SHIP_INVINCIBLE
        sta   player1+ext_variables+AABB.p
        ldd   main.endstage.counter         ; reload: the lda above clobbered A (high byte of D)
        subd  gfxlock.frameDrop.count_w
        bgt   >
        ldd   #1                            ; floor the countdown, sequence stays latched
!       std   main.endstage.counter
        tst   main.endstage.phase
        bne   @pilot
        ; phase 0: free gameplay until T-$10
        cmpd  #endstage.JINGLE
        bhi   @none
        ; T-$10: jingle + ship autopilot (arcade: end_level_sequence_flag = -1)
        inc   main.endstage.phase
        lda   #-2
        sta   player1+subtype               ; autopilot: no control, ship still displayed
        ; LA CHARGE DU FAISCEAU S'ETEINT ICI (02/09/2026, decision auteur) : le
        ; relachement vit dans le bloc de controle du joueur, saute des cette
        ; phase — un bouton tenu au passage laissait l'objet beamcharge
        ; s'animer sur le vaisseau et la jauge du HUD pleine jusqu'a la
        ; coupure. beam_value a zero : la jauge se vide (le HUD la lit) et
        ; l'objet beamcharge se supprime seul a son prochain tour.
        clr   player1+beam_value
        clr   player1+is_charging
        ; LE FORCE POD NE RENTRE PAS. Comme sur la borne, il reste ou il est
        ; pendant toute la sequence de fin — un rappel avait ete essaye ici le
        ; 25/08/2026 et rendait mal a l'ecran (decision auteur). Il n'y a rien
        ; a faire : le stage suivant le fait renaitre accroche de toute facon,
        ; puisque c'est l'etat que checkpoint.armament lui donne.
        jsr   AutoPilot
        ldb   #endstage.STATUS_JINGLE       ; main starts the stage clear jingle
        rts
@pilot
        jsr   AutoPilot
        lda   main.endstage.phase
        cmpa  #2
        beq   @glide                        ; phase 2: glide until the camera reaches the exit
        bhi   @phase34                      ; phase 3 (fade) / 4 (score readout): wait, then leave
        ; phase 1: hold autopilot until the countdown expires, then resume the scroll
        ldd   main.endstage.counter
        cmpd  #1
        bhi   @none                         ; countdown still running
        ; T-0: resume the level scroll - lift the cap to the real map end so the
        ; camera glides past the boss room toward the exit corridor (arcade scroll-out)
        inc   main.endstage.phase
        ldd   #map_width-viewport_width
        std   scroll_max
        ldd   #$0030
        std   scroll_vel
        bra   @none
@glide
        ; Armer le fondu SEULEMENT quand le scroll est reellement a l'arret, c'est a
        ; dire quand les DEUX buffers ont ete rendus a la butee. Le critere naif
        ; "glb_camera_x_pos >= map_width-viewport_width" est atteint une a deux trames
        ; trop tot : Scroll n'enregistre qu'un buffer par trame (buffer_x_pos /
        ; buffer_x_pos+2) et ne s'arrete qu'une fois les deux au cap. Tant qu'il tourne,
        ; glb_camera_move reste pose et DrawTiles - appele APRES Blit dans la boucle
        ; principale - repeint la tuilerie par-dessus la cellule que FadeOut vient
        ; d'effacer. Le fondu ne repassant jamais sur une cellule deja traitee, celle-ci
        ; restait visible jusqu'a la fin. Mesure en emulation : page 3 privee de la
        ; cellule coord 0,0, page 2 intacte, et le residu epousait le decor NON VIDE,
        ; les tuiles vides etant sautees par DrawTiles.
        ; On reprend donc la condition exacte de la sortie anticipee de Scroll.
        ldx   scroll_max
        cmpx  buffer_x_pos
        bne   >
        cmpx  buffer_x_pos+2
        bne   >                             ; un buffer n'a pas encore rattrape
        ; scroll fige sur les deux pages : glb_camera_move sera nul des la trame
        ; suivante, DrawTiles ne repeindra plus rien. On peut dissoudre.
        ; ... et le VAISSEAU a l'arret. Depuis que la boucle n'efface plus le
        ; champ sous le fondu (stage-main.asm, garde stage.frame.faded), la
        ; dissolution est CUMULATIVE : elle masque chaque cellule une seule
        ; fois par page, et tout ce qui est repeint apres elle y reste grave.
        ; Un vaisseau encore en vol laisserait donc sa trainee peinte sur le
        ; noir jusqu'au releve de score. AutoPilot vient de tourner juste
        ; au-dessus : des vitesses nulles = dans la zone morte, donc arrive.
        ; L'autopilote converge toujours (1 px par trame, sans obstacle), la
        ; condition ne peut pas bloquer la sequence.
        ldd   player1+x_vel
        bne   >
        ldd   player1+y_vel
        bne   >
        inc   main.endstage.phase
        jsr   InitFadeOut
!       bra   @none
@phase34
        ; phase 3: the dissolve runs in Blit; phase 4: the HUD score readout runs (driven by
        ; main, drawn by the HUD). Wait for the Blit/HUD state machine, then leave the level.
        lda   main.endstage.phase
        cmpa  #4
        lblo  @none                         ; phase 3: still dissolving -> wait  ; forme longue : la cible est au-dela de 127 octets
        ; phase 4 : plus rien a forcer (02/09/2026). glb_force_sprite_refresh
        ; etait pose ici pour que vaisseau et pod restent peints sur les deux
        ; pages ; en overlay BuildSprites redessine tout a chaque trame et ne
        ; lit plus ce drapeau — l'ecriture etait morte. Ce que la sequence
        ; laisse a l'ecran sous le fondu est decide par la boucle
        ; (stage-main.asm, garde stage.frame.faded), pas ici.
@scoreWait
        lda   main.endstage.scoreDone        ; phase 4: wait for readout + 3 s hold to finish
        lbeq  @none                          ; (main loop keeps running -> the pod animates)
        ; readout + hold done: black the palette FIRST so the cut to the loading screen is
        ; hidden -> clean fade-to-black return to the title (same idiom as Level01_Start /
        ; the message black-out). PalUpdateNow writes the hardware registers synchronously,
        ; so it takes effect before we stop the IRQ just below.
        ldd   #Pal_black
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow
        ; leave the level (LoadGameModeNow is resident and never returns)
        jsr   IrqOff
        ; silence the sound chips before the loading screen
        ; (arcade: quiet during the load - same as game-mode 00 LaunchGame)
        jsr   ResetSN
        jsr   ResetYM
; V2-DEVIATION : la v1 quitte par LoadGameModeNow et ne revient jamais. La v2
; n'a pas de modes de jeu — on sort d'un stage en changeant de SCENE, ce que
; seul le stage sait faire. On rend donc le statut, comme pour le jingle juste
; au-dessus, et c'est stage.endTick qui passe la main.
;        lda   #GmID_title                   ; TODO: tunnel game mode once registered (arcade: stage 2)
;        sta   globals.nextGameMode
;        lda   #GmID_loading
;        sta   GameMode
;        ldb   #GmID_level01
;        stb   glb_Cur_Game_Mode
;        jmp   LoadGameModeNow
        ldb   #endstage.STATUS_DONE
        rts

* ---------------------------------------------------------------------------
* end-level autopilot (arcade: EndLevelAutoPilot in run_player_one)
* rally the ship toward the center point at 1 arcade-px/frame, scaled to the
* Thomson playfield: scale.X*1PX = 0.375 px/frame, scale.Y*1PX = 0.75 px/frame
* (the canonical arcade->TO8 ratio). One axis-aligned step per frame, dead band.
* ---------------------------------------------------------------------------

AutoPilot
        ldd   #0
        std   player1+x_vel
        std   player1+y_vel
        ldd   player1+x_pos
        subd  glb_camera_x_pos
        subd  #endstage.RALLY_X
        bmi   @shipLeft
        cmpd  #endstage.DEADBAND_X
        blo   @yAxis
        ldd   #scale.XN1PX                  ; ship right of rally point: fly left (0.375 px/frame)
        bsr   VelScale
        std   player1+x_vel
        bra   @yAxis
@shipLeft
        cmpd  #-endstage.DEADBAND_X
        bgt   @yAxis
        ldd   #scale.XP1PX                  ; ship left of rally point: fly right (0.375 px/frame)
        bsr   VelScale
        std   player1+x_vel
@yAxis
        ldd   player1+y_pos
        subd  glb_camera_y_pos
        subd  #endstage.RALLY_Y
        bmi   @shipAbove
        cmpd  #endstage.DEADBAND_Y
        blo   @done
        ldd   #scale.YN1PX                  ; ship below rally point: fly up toward it (0.75 px/frame)
        bsr   VelScale
        std   player1+y_vel
        rts
@shipAbove
        cmpd  #-endstage.DEADBAND_Y
        bgt   @done
        ldd   #scale.YP1PX                  ; ship above rally point: fly down toward it (0.75 px/frame)
        bsr   VelScale
        std   player1+y_vel
@done   rts

* D = D * gfxlock.frameDrop.count - the autopilot velocity is applied once
* per rendered frame by ObjectMove, so it must absorb the dropped frames
* (same compensation as everywhere else)
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
* Sound chip silence (verbatim from game-mode 00 LaunchGame)
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
* Boss erase (arcade: run_boss_erase_tile_background)
*
* L'arcade efface le corps du boss tuile par tuile ; ici le clearBlast
* nettoie le champ chaque trame — une piece qui cesse de se dessiner
* disparait seule, il n'y a rien a effacer. Ne restent que les phases 3
* (dissolve) et 4 (readout) ; le rectangle noir de salle a ete retire le
* 31/08/2026 (il mordait le decor pendant le scroll de fin).
* ---------------------------------------------------------------------------

Blit
        ; phase 3: pixel-dissolve to black (here, in-lock, before DrawSprites - so the sprite
        ; background backups capture the dissolved pixels). phase 4: playfield clear for the
        ; double-buffer score readout. phases 0-2: boss-room rectangle wipe (@notFade).
        lda   main.endstage.phase
        cmpa  #3
        lbeq  BlitPhase3
        cmpa  #4
        lbeq  BlitPhase4
@notFade
        ; phases 0-2 : PLUS RIEN (31/08/2026, decision auteur). Le rectangle
        ; noir de salle etait l'heritage bg-erase — en overlay le clearBlast
        ; efface le champ chaque trame : une piece du boss qui cesse de se
        ; dessiner disparait seule. Le rectangle, pose en coordonnees ECRAN
        ; sur 4 trames pendant que la camera glisse, mordait le decor deplace
        ; (lignes 23-178, plafond et sol compris) que la tilemap ne repeint
        ; pas : les trous voyageurs du scroll de fin, vus en video.
        rts

* ---------------------------------------------------------------------------
* phase 3 -> 4: drive the dissolve, then arm the score readout.
* The pixel fade-out now runs in double buffering, so it blacks BOTH video pages on
* its own - no explicit buffer clear is needed before the readout (it used to be
* single-buffered, hence the old @clearHidden / BlitPhase4 page wipes, now dropped).
* ---------------------------------------------------------------------------
BlitPhase3
        lda   FadeCnt
        beq   @scoreHold                    ; fade done (both pages, double-buffered) -> hold, then score
        jmp   FadeOut
@scoreHold
        ; fade done on both pages: hold ~0.5 s on the black screen before the score readout
        ; (let the dissolve land before the digits spin up) ; frame-drop
        ; compensated like the other endstage timers.
        ldb   scoreHold.timer
        beq   @toReadout                     ; hold elapsed (or disabled) -> arm the readout
        subb  gfxlock.frameDrop.count
        bls   @toReadout                     ; reached 0 this frame -> arm now
        stb   scoreHold.timer
        rts
@toReadout
        ; both pages already black (double-buffered fade): NO glb_camera_move so the level
        ; stays off ; arm the HUD readout
        lda   #1
        sta   main.endstage.scoreArmed      ; HUD: (re)seed the readout from the stage score
        lda   #4
        sta   main.endstage.phase
        rts

BlitPhase4
        ; nothing to do: the double-buffered fade already blacked both pages, so there is no
        ; buffer clear here anymore (the readout is drawn by the HUD each frame, ship/pod kept
        ; on both pages by the per-frame sprite refresh forced from the Tick).
        rts

* ---------------------------------------------------------------------------


* ---------------------------------------------------------------------------
* Fondu au noir par tramage (phase 3). Extrait dans le moteur pour etre
* reutilisable et surtout TESTABLE hors R-Type : le game-mode fadetest exerce
* exactement ce code. Fournit InitFadeOut / FadeOut / FadeCnt / FadeLen.
* ---------------------------------------------------------------------------
        INCLUDE "./engine/graphics/fade/pixel-fade.asm"
