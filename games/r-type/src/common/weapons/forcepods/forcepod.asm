; ---------------------------------------------------------------------------
; forcePod
;
; input REG : [u] pointer to Object Status Table (OST)
; ---------
;
; arcade original code:
; INITIAL STATE
; -------------------
; up rotation
;
; FLOATING
; -------------------
; pod direction (up: up rotation, down: down rotation, no vertical velocity: keep last rotation)
; pod min - frameDuration: 4, rotation based on pod last vertical velocity
; pod mid - frameDuration: 4, rotation based on pod last vertical velocity, flipped rear/front
; pod max - frameDuration: 8, rotation based on pod last vertical velocity
;
; ATTACHED
; -------------------
; player direction (up: up rotation, down: down rotation, no vertical velocity: left: up rotation, right: down rotation)
; pod min - frameDuration: 4, rotation based on player direction
; pod mid - frameDuration: 4, rotation based on player direction, image flipped rear/front
; pod max - frameDuration: 8, rotation based on player direction
;
; EJECTED
; -------------------
; pod min - frameDuration: 2, down rotation
; pod mid - frameDuration: 2, down rotation, flipped rear/front
; pod max - frameDuration: 2, down rotation
; ---------------------------------------------------------------------------

        ; TODO SHOULD IMPLEMENT A WHATEVER KEYBOARD PRESS TO EJECT FORCEPOD
        ; THAT WILL not update E7C3 !!!!!!!!!!!!! UNLIKE ROM CODE !!!

        ; TODO _Collision_RemoveAABB when downgrade forcepod (player one respawns)

; V2-DEVIATION: les en-tetes communs sont portes par l'unite hote
; (forcepod.unit.asm), comme pour tout fichier v1 enveloppe.
; V2-DEVIATION: la lecture de la MANETTE passe a l'API v2, comme pour le joueur
; (player1.asm) : le module joypad est un KEPT-V2 deja resident, c'est lui qui
; impose son vocabulaire. Renommage PUR — memes bits, memes cycles :
;   Fire_Press -> joypad.pressed.fire, c1_button_B_mask -> joypad.0.B
; Cas de migration : docs/lang/en/migration/kept-v2-api.md
;
; Includes v1 retires :
; INCLUDE "./engine/macros.asm"
; INCLUDE "./engine/collision/macros.asm"
; INCLUDE "./engine/collision/struct_AABB.equ"
; INCLUDE "./objects/player1/player1.equ"
; INCLUDE "./objects/player1/forcepods/forcepod.equ"
; INCLUDE "./objects/soundFX/soundFX.const.asm"
; INCLUDE "./engine/sound/soundFX.macro.asm"
; INCLUDE "./objects/foefire/obj_emitter-flash.equ"

AABB_0            equ ext_variables    ; AABB struct (9 bytes)
mount_side        equ ext_variables+9  ; 1 byte (0: front, 1: rear)
return_to_ship    equ ext_variables+10 ; 1 byte
power_level       equ ext_variables+11 ; 1 byte

Object
        lda   routine,u
        cmpa  #rtnid.RunFloating
        blo   ForcePodDispatch         ; Init : la position n'est pas encore posee
        cmpa  #rtnid.Dormant
        bhs   ForcePodDispatch         ; en sommeil : le pod n'est pas dans le champ
        pshs  a
        bsr   ForcePodGumSweep
        puls  a
ForcePodDispatch
        asla
        ldx   #Routines
        jmp   [a,x]

; ---------------------------------------------------------------------------
; ForcePodGumSweep — le pod LABOURE la couche destructible
; ---------------------------------------------------------------------------
; arcade : erase_green_ball_block4x4_stage4 0x40:2702, appele par les TROIS
; etats du pod (0x2534 flottant, 0x259F accroche, 0x262F ejecte) A CHAQUE
; TRAME. La borne y pose quatre grappes 2x2 aux quatre coins (+-8,+-8), qui se
; recouvrent : la surface reelle est un bloc de 4x4 cellules centre sur le pod.
; « Le pod n'est jamais detruit : sa portee est infinie, il laboure. »
;
; UN SEUL APPEL, ICI. Les trois etats convergent sur ce dispatch, et le
; balayage part de la position de la TRAME PRECEDENTE : le segment couvert est
; donc exactement le trajet du pod pendant la trame, deplacement de la camera
; compris. C'est ce qui rend la compensation gratuite — le pod peut avoir
; parcouru quatre cellules pendant que l'ecran n'en affichait qu'une, la
; surface balayee est la meme et le cout aussi.
;
; V2-DEVIATION: la borne balaie aussi en Y (le bloc suit le pod qui suit le
; vaisseau). Ici la rangee est celle de l'ARRIVEE seule : le bloc fait quatre
; rangees, soit 24 px, et la derive verticale d'une trame en vaut huit au pire
; — elle tient dans le bloc. Le balayage reste sur le chemin rapide de
; clearRect (r0 == r1), celui qui ne parcourt pas le segment.
; V2-DEVIATION: la garde d'entree arcade (pos_x >= 0x140, le pod a gauche de la
; bande visible) n'est pas reprise : pscroll.sweep rabote deja ses deux bords
; sur le ruban.
; ---------------------------------------------------------------------------
ForcePodGumSweep
        ldd   stage.gum.hook
        addd  #6                       ; +6 : effacer un rectangle balaye
        std   @call
        ldd   x_pos,u
        ldy   gum_prev_x               ; le depart : la trame d'avant
        std   gum_prev_x
        subd  #6                       ; le coin haut-gauche : deux cellules a
        tfr   d,x                      ; gauche du centre
        leay  -6,y
        ldb   y_pos+1,u
        subb  #12                      ; ... et deux rangees au-dessus
        bhs   >
        clrb                           ; le pod colle au haut du champ
!       lda   #$44                     ; bloc 4 x 4 cellules
        jsr   >0
@call   equ   *-2
        rts

; La position du pod a la trame precedente. Il n'y a qu'UN pod : c'est une
; variable d'unite, comme rotation ou target_x_pos juste en dessous.
gum_prev_x        fdb   0

Routines
        fdb   Init
        fdb   RunFloating
        fdb   RunEjected
        fdb   RunAttached
        fdb   Dormant         ; appended last (index rtnid.Dormant) - static idle slot

; local routine-index aliases (kept for the in-bank code below); the shared
; rtnid.* constants (forcepod.equ) are the source of truth, used here and by main.asm
Init_rtn        equ rtnid.Init
RunFloating_rtn equ rtnid.RunFloating
RunEjected_rtn  equ rtnid.RunEjected
RunAttached_rtn equ rtnid.RunAttached

; Dormant : the static slot idles here (no draw, no logic) until the player
; collects the force-pod bonus, at which point pow_optionbox sets routine=rtnid.Init.
; The pod returns here (instead of being freed) when it is lost/unloaded.
Dormant
        rts

; internal variables
last_mount_side   fcb   0
offset_frame      fcb   0
rotation          fcb   0 ; negative value for up rotation, positive value for down rotation
target_x_pos      fdb   0
impact_min        fcb   0
impact_x_f_row0   fcb   0
impact_x_f_row1   fcb   0
impact_x_b_row1   fcb   0
impact_x_f_row2   fcb   0
upper_solid_tiles fcb   0
lower_solid_tiles fcb   0
closed_path       fcb   0
counterair_lock   fcb   0 ; cadence du counter-air (20 trames). Le rebond n'en a pas besoin :
                          ; sa cadence vient de glb.slotsState (obj_reboundlaser), qui bloque
                          ; toute nouvelle volee ~114-118 trames, six fois plus contraignant.

Init
        ; clean OST : slot statique re-active apres une mort -> on repart d'un slot FRAIS.
        ; efface tout l'etat d'affichage reserve stale (mapping_frame, listes de priorite
        ; par-buffer, bgdata, rsv_render_flags...) qui empechait le rendu a la re-acquisition
        ; (la logique/tir tournait mais aucun sprite). On re-pose l'id (CheckSpritesRefresh
        ; le lit pour la page image) ; la routine est reposee par l'inc en fin d'Init.
        tfr   u,x
        clra
        ldb   #object_size
@clrOST sta   ,x+
        decb
        bne   @clrOST
        lda   #ObjID_forcepod
        sta   id,u

        ldd   #0
        sta   mount_side,u
        sta   player1+forcepod_mount_side
        sta   return_to_ship,u
        sta   last_mount_side
        sta   offset_frame
        sta   power_level,u            ; no level, force animation to be set
        std   target_x_pos
        sta   counterair_lock

        lda   #-1
        sta   rotation                 ; default to up rotation

        ldb   #2
        stb   priority,u
        ; render_flags PROPRE (pas de ora) : l'OST force pod est un slot statique re-seede
        ; Dormant a la mort, jamais clear. Le delete double-buffer de la mort laisse
        ; render_todelete_mask ($20) pose ; un ora le preserverait -> CheckSpritesRefresh
        ; skippe le sprite (hide|todelete) alors que DisplaySprite l'ajoute quand meme a la
        ; liste -> la logique/tir tourne mais aucun sprite rendu a la re-acquisition.
        lda   #render_playfieldcoord_mask
        sta   render_flags,u

        ldd   glb_camera_x_pos
        subd  #9-6
        std   x_pos,u  
        ldd   #96+5
        std   y_pos,u

        _Collision_AddAABB AABB_0,AABB_list_forcepod

        lda   #255                      ; set damage potential for this hitbox
        sta   AABB_0+AABB.p,u
        jsr   checkForcePodUpdate                
        jsr   UpdateCollisionBox

        ldd   x_pos,u                   ; amorcer le balayage de gommes : sans ca
        std   gum_prev_x                ; le premier partirait de la position que
                                        ; le pod avait a sa vie precedente

        ; OU FINIT CET INIT — flottant, ou deja accroche (25/08/2026).
        ;
        ; Ramasse en jeu, le pod nait FLOTTANT devant le vaisseau et s'accroche
        ; en le rejoignant : c'est le geste arcade, et `inc routine,u` (0 -> 1)
        ; le disait. Mais l'entree d'un nouveau STAGE re-active le meme slot
        ; statique pour un pod que le joueur possede DEJA : le refaire naitre
        ; flottant lui ferait retraverser l'ecran pour rien. Comme sur la borne,
        ; le pod n'est PAS rappele en fin de stage — il reste ou il est — et
        ; c'est le stage suivant qui le remet accroche (decision auteur).
        ;
        ; Le signal est `player1+forcepod_attached`, pose par la restauration
        ; d'armement APRES checkpoint.load (donc apres le dernier balayage de la
        ; page directe). A la mort comme au ramassage il vaut zero, et l'ancien
        ; comportement tient mot pour mot.
        lda   player1+forcepod_attached
        beq   @floating
        lda   #RunAttached_rtn
        sta   routine,u
        rts
@floating
        inc   routine,u
        rts

RunFloating
        clr   mount_side,u
        clr   player1+forcepod_mount_side

        ldd   y_vel,u
        beq   >
        sta   rotation                 ; rotation is the sign of the vertical velocity
!
        ldb   joypad.pressed.fire      ; V2-DEVIATION : Fire_Press
        andb  #joypad.0.B                ; V2-DEVIATION : c1_button_B_mask
        beq   >
        lda   #1
        sta   return_to_ship,u         ; flag forcepod as returning to ship
!
        lda   return_to_ship,u
        beq   >

        ; if forcepod is returning to player1
        ; horizontal tracking is delayed by 30 frames
        ldx   player_pos_ring_buffer_ptr
        leax  4,x
        cmpx  #player_pos_ring_buffer+4*32
        bne   @skip_cycling
        ldx   #player_pos_ring_buffer
@skip_cycling
        ldd   ,x
        addd  glb_camera_x_pos
        bra   @continue
!
        ; if forcepod is not returning to player1
        ; horizontal tracking targets 2 preset positions
        ldd   player1+x_pos
        subd  glb_camera_x_pos
        tfr   d,x
        ldd   #36+6                    ; left target position
        cmpx  #69+6                    ; pivot point
        bge   >
        ldd   #93+6                    ; right target position
!
        addd  glb_camera_x_pos
@continue
        std   target_x_pos
        jsr   HorizontalTracking
        jsr   VerticalTracking
        jsr   checkForcePodUpdate
        jsr   UpdateCollisionBox

        ; TODO collision to green balls of level 4

        ; collision to player1
        lda   #6                       ; player one x radius
        adda  AABB_0+AABB.rx,u
        asla
        sta   @rx
        asra
        adda  player1+p1_AABB_0+AABB.cx
        suba  AABB_0+AABB.cx,u
        cmpa  #0
@rx     equ   *-1 
        bhi   >
        lda   #6                       ; player one y radius
        adda  AABB_0+AABB.ry,u
        asla
        sta   @ry
        asra
        adda  player1+p1_AABB_0+AABB.cy
        suba  AABB_0+AABB.cy,u
        cmpa  #0
@ry     equ   *-1 
        bhi   >
        ; rear side mount
        lda   #1
        sta   mount_side,u
        sta   player1+forcepod_mount_side
        sta   last_mount_side
        lda   render_flags,u
        anda  #^render_xmirror_mask
        ora   #1
        sta   render_flags,u
        ;        
        ldd   x_pos,u
        subd  player1+x_pos
        bcs   @rear
        ; front side mount
        clra
        sta   mount_side,u
        sta   player1+forcepod_mount_side
        sta   last_mount_side      
        lda   render_flags,u
        anda  #^render_xmirror_mask
        ora   #0
        sta   render_flags,u          
@rear
        lda   #RunAttached_rtn
        sta   routine,u
        lda   #1
        sta   player1+forcepod_attached
!
        lda   #255                      ; set damage potential for this hitbox
        sta   AABB_0+AABB.p,u
        jsr   checkForcePodUpdate
        jsr   UpdateCollisionBox
        ; enemy contact is applied by the shared, frame-drop-gated WeaponContactTick
        ; (collision phase, main.asm) — arcade: pod+bits share one 1/16-frame gate.
        jsr   AnimateForcePodSync
        jsr   DisplaySprite
        jmp   ForcePodDetachedFire

HorizontalTracking
        ; reinit forcepod to initial position if out of screen on left
        ldd   glb_camera_x_pos
        subd  #12-6
        cmpd  x_pos,u
        ble   >
        addd  #3+6
        std   x_pos,u  
        ldd   #96+5
        std   y_pos,u
!
        ; check if the forcepod hits a wall
        ldd   x_pos,u        
        addd  #3
        std   terrainCollision.sensor.x
        ldd   y_pos,u        
        std   terrainCollision.sensor.y    

        ldb   #1 ; foreground
        jsr   terrainCollision.do
        tstb
        bne   @rts
        lda   globals.backgroundSolid
        beq   >
        ldb   #0 ; background
        jsr   terrainCollision.do
        tstb
        bne   @rts
!
        ; if no wall hit, continue horizontal tracking
        ldd   glb_camera_x_pos
        subd  glb_camera_x_pos_old        
        addd  x_pos,u
        std   x_pos,u        
        ldx   gfxlock.frameDrop.count_w ; take number of elapsed frame since last render and multiply by velocity
@loop
        ldd   target_x_pos
        subd  x_pos,u
        beq   @rts
        ; compute velocity
        bcc   >
        ldd   #$ff70
        bra   @move
!       ldd   #$0090
@move
        std   x_vel,u
        ; update x position
        sta   @a                       ; given the actual speed of forcepod, a is already $00 or $ff
        ldd   x_pos+1,u                ; x_pos must be followed by x_sub in memory
        addd  x_vel,u
        std   x_pos+1,u                ; update low byte of x_pos and x_sub byte
        lda   x_pos,u
        adca  #$00                     ; (dynamic) parameter is modified by the result of sign extend
@a      equ   *-1
        sta   x_pos,u                  ; update high byte of x_pos
        leax  -1,x
        bne   @loop
@rts    rts

VerticalTracking
        ; check terrain collision
        ; there are 3 rows of 9 sensors to check for collision
        ; middle row is centered on the forcepod vertically and is tested against background and foreground
        ; top and bottom rows are tested against foreground only
        ; sensors are positioned from the left edge of the forcepod, so offset to forcepod x positions are:
        ; -8 0 +8 +16 +24 +32 +40 +48 +56 (0 is the x center of forcepod)
        ; in arcade, test are made from left to right, by testing the column of sensors, when a collision is detected it stops
        ; and find a path vertically to avoid the collision
        ; for our code it is faster to test row by row

        ; middle row
        ldd   x_pos,u
        subd  #3
        std   terrainCollision.sensor.x
        ldd   y_pos,u
        std   terrainCollision.sensor.y
        ldb   #1 ; foreground
        jsr   terrainCollision.xAxis.doRight
        ldd   terrainCollision.impact.x
        beq   @noIpct
        subd  terrainCollision.sensor.x
        addd  #3
        cmpd  #9*3
        blo   >
@noIpct ldb   #-1
!       stb   impact_x_f_row1

        lda   globals.backgroundSolid
        beq   @noIpct
        clrb  ; background
        jsr   terrainCollision.xAxis.doRight
        ldd   terrainCollision.impact.x
        beq   @noIpct
        subd  terrainCollision.sensor.x
        addd  #3
        cmpd  #9*3
        blo   >
@noIpct ldb   #-1
!       stb   impact_x_b_row1

        ; bottom row
        ldd   y_pos,u
        addd  #6
        std   terrainCollision.sensor.y
        ldb   #1 ; foreground
        jsr   terrainCollision.xAxis.doRight
        ldd   terrainCollision.impact.x
        beq   @noIpct
        subd  terrainCollision.sensor.x
        addd  #3        
        cmpd  #9*3
        blo   >
@noIpct ldb   #-1
!       stb   impact_x_f_row2

        ; top row
        ldd   y_pos,u
        subd  #6
        std   terrainCollision.sensor.y
        ldb   #1 ; foreground
        jsr   terrainCollision.xAxis.doRight
        ldd   terrainCollision.impact.x
        beq   @noIpct
        subd  terrainCollision.sensor.x
        addd  #3        
        cmpd  #9*3
        blo   >
@noIpct ldb   #-1
!       stb   impact_x_f_row0

        ; resolution ...
        ; testing for background collision first
        ldb   impact_x_b_row1
        bmi   >                                    ; skip if no background collision
        ldb   impact_x_f_row1                      ; if a background collision is detected, should check if foreground collision is closer
        lbmi  VerticalTracking.backgroundCollision ; if no foreground collision, use background collision
        cmpb  impact_x_b_row1                      ; compare foreground and background collision
        ble   >                                    ; if foreground collision is closer, skip background collision and continue with foreground collision
        jmp   VerticalTracking.backgroundCollision
!
        ; testing for foreground collision
        ; keep lowest value that is > 0
        lda   #-1
        sta   impact_min        ; row 0 test
        ldb   impact_x_f_row0
        bmi   >
        stb   impact_min
!       
        ldb   impact_x_f_row1 ; row 1 test
        bmi   >
        lda   impact_min
        bmi   @store1
        cmpb  impact_min
        bge   >
@store1 stb   impact_min
!
        ldb   impact_x_f_row2 ; row 2 test
        bmi   >
        lda   impact_min
        bmi   @store2
        cmpb  impact_min
        bge   >
@store2 stb   impact_min
!
        clra
        ldb   impact_min
        bmi   >
        jmp   VerticalTracking.foregroundCollision
!
        ; no collision detected, continue
        ; I choosed to not implement arcade code here, for simplicity sake.
        ; Instead of making a "pause" one frame on two in vertical velocity,
        ; I simply divided the speed by two
        ; vertical tracking
        lda   return_to_ship,u
        bne   >
        ldd   x_pos,u
        addd  #2
        subd  target_x_pos
        bcs   VerticalTracking.clampPosition
        subd  #4
        bcc   VerticalTracking.clampPosition
!
        ldx   player_pos_ring_buffer_ptr
        leax  4,x
        cmpx  #player_pos_ring_buffer+4*32
        bne   >
        ldx   #player_pos_ring_buffer
!
        ldd   2,x
        std   @old_player_y_pos
        ldx   gfxlock.frameDrop.count_w ; take number of elapsed frame since last render and multiply by velocity
@loop
        ldd   #0000
@old_player_y_pos equ *-2
        subd  y_pos,u
        bcc   >
        cmpd  #-2
        bge   VerticalTracking.clampPosition
        ldd   #$ff40
        bra   VerticalTracking.updatePosition
!               
        cmpd  #2
        ble   VerticalTracking.clampPosition
        ldd   #$00c0
VerticalTracking.updatePosition
        std   y_vel,u
        ; update y position
        sta   @a                       ; given the actual speed of forcepod, a is already $00 or $ff
        ldd   y_pos+1,u                ; y_pos must be followed by y_sub in memory
        addd  y_vel,u
        std   y_pos+1,u                ; update low byte of y_pos and y_sub byte
        lda   y_pos,u
        adca  #$00                     ; (dynamic) parameter is modified by the result of sign extend
@a      equ   *-1
        sta   y_pos,u                  ; update high byte of y_pos
        leax  -1,x
        bne   @loop
VerticalTracking.clampPosition
        ; clamp vertical position to screen bounds
        ldd   y_pos,u
        cmpd  #11+7
        bhs   >
        ldd   #11+7
        std   y_pos,u
        rts
!
        cmpd  #11+viewport_height-7
        bls   >
        ldd   #11+viewport_height-7
        std   y_pos,u
!
        rts

VerticalTracking.foregroundCollision
        ; offset in pixels to detected wall is already in d
        addd  x_pos,u
        subd  #3
        std   terrainCollision.sensor.x

        ldd   #0
        std   upper_solid_tiles ; and lower_solid_tiles
        sta   closed_path

        ldd   y_pos,u
@loopUp
        subd  #6
        std   terrainCollision.sensor.y        
        cmpd  #11
        bge   >
        inc   closed_path
        bra   @continue
!
        ; count upper solid tiles from tile impact
        inc   upper_solid_tiles
        ldb   #1 ; foreground
        jsr   terrainCollision.do
        tstb
        beq   @continue
        ldd   terrainCollision.sensor.y
        bra   @loopUp
@continue
        ldd   y_pos,u
@loopDown
        addd  #6
        std   terrainCollision.sensor.y
        cmpd  #11+viewport_height
        blt   >
        lda   closed_path
        adda  #2
        sta   closed_path
        bra   @end
!
        ; count lower solid tiles from tile impact
        inc   lower_solid_tiles
        ldb   #1 ; foreground
        jsr   terrainCollision.do
        tstb
        beq   @end
        ldd   terrainCollision.sensor.y
        bra   @loopDown
@end
        lda   closed_path
        beq   @fastestPath ; branch if both upper and lower direction have a path        
        cmpa  #3 ; solid tiles detected both up to top and bottom screen border
        bne   >
        rts ; doing more in arcade, but found it pointless, so we stop here
!       cmpa  #1
        beq   >
        ldd   #$ff40        
        bra   VerticalTracking.applyVelocity
!       ldd   #$00c0        
        bra   VerticalTracking.applyVelocity
@fastestPath
        lda   upper_solid_tiles
        cmpa  lower_solid_tiles
        bhi   <
        ldd   #$ff40

VerticalTracking.applyVelocity
        std   y_vel,u
        ldx   gfxlock.frameDrop.count_w ; take number of elapsed frame since last render and multiply by velocity
        sta   @a                       ; given the actual speed of forcepod, a is already $00 or $ff
@loop
        ldd   y_pos+1,u                ; y_pos must be followed by y_sub in memory
        addd  y_vel,u
        std   y_pos+1,u                ; update low byte of y_pos and y_sub byte
        lda   y_pos,u
        adca  #$00                     ; (dynamic) parameter is modified by the result of sign extend
@a      equ   *-1
        sta   y_pos,u                  ; update high byte of y_pos
        leax  -1,x
        bne   @loop
        jmp   VerticalTracking.clampPosition

VerticalTracking.backgroundCollision
        clra
        ldb   impact_x_b_row1
        addd  x_pos,u
        subd  #3
        std   terrainCollision.sensor.x

        ldd   #0
        std   upper_solid_tiles ; and lower_solid_tiles

        ldd   y_pos,u
@loopUp
        subd  #6
        std   terrainCollision.sensor.y        
        cmpd  #11
        blt   @continue
        ;
        ; count upper solid tiles from tile impact
        inc   upper_solid_tiles
        ldb   #0 ; background
        jsr   terrainCollision.do
        tstb
        beq   @continue
        ldd   terrainCollision.sensor.y
        bra   @loopUp
@continue
        ldd   y_pos,u
@loopDown
        addd  #6
        std   terrainCollision.sensor.y
        cmpd  #11+viewport_height
        bge   @end
        ;
        ; count lower solid tiles from tile impact
        inc   lower_solid_tiles
        ldb   #0 ; background
        jsr   terrainCollision.do
        tstb
        beq   @end
        ldd   terrainCollision.sensor.y
        bra   @loopDown
@end
        lda   upper_solid_tiles
        cmpa  lower_solid_tiles
        bhi   >
        ldd   #$ff40
        jmp   VerticalTracking.applyVelocity
!       ldd   #$00c0        
        jmp   VerticalTracking.applyVelocity

RunEjected
        clr   rotation

        lda   joypad.pressed.fire
        anda  #joypad.0.B
        beq   >
        lda   #1
        sta   return_to_ship,u
!
        clr   mount_side,u
        clr   player1+forcepod_mount_side
        ldx   gfxlock.frameDrop.count_w ; take number of elapsed frame since last render and multiply by velocity
@loop
        pshs  x
        ; move forcepod based on velocity
        ldb   x_vel,u
        sex                            ; velocity is positive or negative, take care of that
        sta   @a
        ldd   x_pos+1,u                ; x_pos must be followed by x_sub in memory
        addd  x_vel,u
        std   x_pos+1,u                ; update low byte of x_pos and x_sub byte
        lda   x_pos,u
        adca  #$00                     ; (dynamic) parameter is modified by the result of sign extend
@a      equ   *-1
        sta   x_pos,u                  ; update high byte of x_pos
         ; check if the forcepod hits a wall
        ldd   x_pos,u        
        std   terrainCollision.sensor.x
        ldd   y_pos,u        
        std   terrainCollision.sensor.y    
        ldb   #1 ; foreground
        jsr   terrainCollision.do
        tstb
        bne   @floating
        lda   globals.backgroundSolid
        beq   >
        ldb   #0 ; background
        jsr   terrainCollision.do
        tstb
        bne   @floating
!       ; check if the forcepod hits screen edges
        ldd   x_pos,u
        subd  glb_camera_x_pos
        cmpd  #140
        bge   @floating
        cmpd  #14
        blt   @floating
        ;
        puls  x
        leax  -1,x
        bne   @loop        
        bra   >
@floating      
        puls  x
        lda   #RunFloating_rtn
        sta   routine,u
!
        jsr   checkForcePodUpdate
        jsr   UpdateCollisionBox
        ; enemy contact is applied by the shared, frame-drop-gated WeaponContactTick
        ; (collision phase, main.asm) — arcade: pod+bits share one 1/16-frame gate.
        jsr   AnimateForcePodSyncEjected
        jsr   DisplaySprite
        jmp   ForcePodDetachedFire

RunAttached
        ldd   #9
        tst   mount_side,u
        beq   >
        ldd   #-9
!        
        addd  player1+x_pos
        std   x_pos,u
        ldd   player1+y_pos
        std   y_pos,u

        ldd   player1+y_vel
        beq   >
        sta   rotation                 ; rotation is the sign of the vertical velocity
        bra   @end
!       ldd   player1+x_vel
        beq   @end
        sta   rotation                 ; use horizontal velocity if no vertical velocity
@end
        jsr   checkForcePodUpdate
        jsr   UpdateCollisionBox
        ; enemy contact is applied by the shared, frame-drop-gated WeaponContactTick
        ; (collision phase, main.asm) — arcade: pod+bits share one 1/16-frame gate.

        ; L'effacement du champ de gommes n'est PAS ici : il est pose une fois
        ; pour les trois etats, en tete du dispatch (ForcePodGumSweep).

        lda   joypad.pressed.fire
        anda  #joypad.0.B
        beq   @continue
        ldd   #$360
        tst   mount_side,u
        beq   >
        ldd   #$fca0
!       std   x_vel,u
        clr   return_to_ship,u
        lda   #RunEjected_rtn
        sta   routine,u
        clr   player1+forcepod_attached
        ldb   #2 ; reset frame duration to fixed speed for ejected forcepod
        stb   anim_frame_duration,u
        ;
        ; instanciate flame effect
        lda   #ObjID_emitter_flash
        jsr   LoadObject_x
        beq   @continue
        sta   id,x
        ldd   #$00f6                   ; a=0 front, b=-10 distance from parent object
        tst   mount_side,u
        beq   >
        inca                           ; a=1 back
        negb                           ; b=10 distance from parent object
!       sta   subtype,x
        sex                            ; sign extend b to a word
        std   emitterFlash.x_offset,x     
        lda   #1
        sta   emitterFlash.delay,x    
        stu   emitterFlash.parent,x        
@continue
        jsr   AnimateForcePodSync
        jsr   DisplaySprite

ForcePodAttachedFire     
        lda   counterair_lock
        suba  gfxlock.frameDrop.count
        bpl   >
        lda   #0
!       sta   counterair_lock

        ; LES REFLETS DU COUNTER-AIR partent sur le bouton TENU, pas sur le
        ; front : sur la borne chaque reflet a son slot d'arme, qui retire des
        ; que son objet a fini (force_pod_fire_held). Palier 2 et 3.
        lda   globals.forcepodtype
        cmpa  #2
        bne   >
        lda   power_level,u
        cmpa  #2
        blo   >
        ldb   joypad.held.fire
        andb  #joypad.0.A
        beq   >
        lbsr  ForcePodReflections
!
        ldb   joypad.pressed.fire
        andb  #joypad.0.A
        beq   @rts
        ; FIX arme : niveau = PUISSANCE (0 no pod, 1 pod sans laser, 2 faible, 3 fort) ;
        ;            l'ARME est choisie par le TYPE (couleur du bonus), comme l'arcade
        ;            (apply_bonus_pickup: player_one_laser_type = bonus_type ; dispatch [tier][type]).
        lda   power_level,u            ; = forcepodlevel (palier de puissance)
        cmpa  #2
        blo   @rts                     ; niveau 0/1 -> pas de laser (le faible/fort = longueur, lue par l'objet laser depuis forcepodlevel)
        lda   globals.forcepodtype     ; choix de l'arme par le TYPE, pas le niveau
        cmpa  #2
        beq   @counterairlaser         ; type 2 = counter-air (rouge)
        cmpa  #1
        beq   @groundlaser             ; type 1 = counter-ground (jaune)
        ; type 0 = rebound (bleu)
@reboundlaser
        jsr   LoadObject_x
        beq   @rts
        lda   #ObjID_forcepod_reboundlaser
        bra   >  
@groundlaser
        ; Un seul objet est cree : sa routine 0 met le second faisceau au monde
        ; et devient le premier. Elle porte aussi la garde de cadence — pas de
        ; nouvelle volee tant qu'une tete vit.
        jsr   LoadObject_x
        beq   @rts
        lda   #ObjID_forcepod_groundlaser
        bra   >
@counterairlaser
        ; LE PALIER FAIT L'ARME (tables de tir du pod 0x1B80.., type
        ; counter-air, pod accroche) : au palier 2 la borne ne cree QUE les
        ; reflets — deux aux coins du pod, un par bit — et aucune tete ; au
        ; palier 3 les deux tetes et les reflets des bits, sans les coins.
        ; Le laser rouge « faible » de l'arcade, ce sont ces deux etincelles.
        lda   power_level,u
        cmpa  #3
        blo   @rts                     ; palier 2 : pas de tete
        lda   counterair_lock
        bne   @rts
        jsr   LoadObject_x
        beq   @rts
        lda   #20
        sta   counterair_lock
        lda   #ObjID_forcepod_counterairlaser
!
        sta   id,x
        lda   mount_side,u
        sta   subtype,x
@rts    rts

; ---------------------------------------------------------------------------
; ForcePodReflections — les etincelles secondaires du counter-air, 1:1 arcade
; ---------------------------------------------------------------------------
; ARCADE (tables de tir du pod, type counter-air, pod accroche) : quatre
; ANCRAGES — coin haut-droit du pod (pod_x - 0x10, pod_y + 8 : au DESSUS,
; l'axe arcade monte), coin bas-droit (pod_y - 8), bit du haut, bit du bas —
; les coins au palier 2 seulement, les bits aux deux paliers, un bit devant
; etre VIVANT. Chaque ancrage a DEUX slots d'arme (create_counter_air_
; reflection_* 0x404CD3..0x404E0E) :
;   - le PRINCIPAL (slots 2, 3, 4, 5) : tant que le bouton est tenu, il tire
;     des que son objet a fini — son enregistrement redevient le slot idle
;     a l'unload, et l'idle retire a la trame suivante ;
;   - l'ALT (slots 10, 11, 12, 13) : memes conditions, PLUS « l'enregistrement
;     huit slots en arriere » — le principal du meme ancrage — ne porte pas
;     0x4E0F, le point d'entree de run_counter_air_reflection, qu'un
;     enregistrement ne garde que de sa creation a son premier tick. Le
;     principal etant servi avant lui, l'alt part la trame SUIVANTE.
; D'ou, vaisseau immobile, deux reflets par bit alignes en x et decales
; d'une trame (8 px arcade, 3 des notres), jamais trois. Chez nous : deux
; OST retenus par ancrage (reflect.slots), un objet n'est cru que si id +
; ancrage (subtype bits 2-3) + routine < AlreadyDeleted concordent.
; Le principal est servi avant l'alt, comme les slots de la borne.
;   [u] = pod OST ; bouton tenu, type counter-air et palier >= 2 deja testes
; ---------------------------------------------------------------------------
ForcePodReflections
        ldy   #@anchors
        clr   reflect.idx
@loop
        ; l'ancrage est-il ouvert a ce palier ?
        lda   5,y                      ; 2 = coins, au palier 2 seulement
        beq   >
        cmpa  power_level,u
        lbne  @next
!       ldx   1,y                      ; l'OST d'ancrage (0 = le pod lui-meme)
        beq   >
        lda   routine,x
        cmpa  #bitdev.rtnid.ActiveTick ; le bit doit etre VIVANT
        lbne  @next
!
        ldb   reflect.idx
        aslb
        aslb                           ; deux mots par ancrage
        ldx   #reflect.slots
        abx
        stx   reflect.cur
        ; --- le slot PRINCIPAL : tire des qu'il est libre ---
        ldx   ,x
        lbsr  ReflectAlive
        beq   @alt                     ; son objet vit encore : occupe
        clr   reflect.lag              ; le principal nait sur l'ancrage
        lbsr  ReflectSpawn
        pshs  x
        ldx   reflect.cur
        puls  d
        std   ,x
@alt
        ; --- le slot ALT : libre ; s'il suit un principal NE CE RENDU, il
        ; nait une trame de vol en arriere ---
        ; La garde arcade compare l'enregistrement du principal a 0x4E0F, le
        ; point d'ENTREE de run_counter_air_reflection, qu'il ne porte
        ; qu'entre sa creation et son premier tick : l'alt part donc LA TRAME
        ; SUIVANTE, 8 px arcade derriere, puis les deux vivent chacun leur
        ; vie. Le pod ne tourne qu'au rendu : attendre le rendu suivant
        ; ecarterait les deux de frameDrop trames (vu a la sonde : 5). On
        ; fait naitre l'alt dans le meme rendu, un pas de vol en arriere —
        ; le resultat de la borne a toute cadence.
        ldx   reflect.cur
        ldx   2,x
        lbsr  ReflectAlive
        lbeq  @next                    ; l'alt vit encore : occupe
        clr   reflect.lag
        ldx   reflect.cur
        ldx   ,x
        lbsr  ReflectAlive
        bne   >                        ; pas de principal : rien ne retarde
        tsta
        bne   >                        ; principal plus vieux : rien non plus
        inc   reflect.lag              ; principal ne ce rendu : une trame de retard
!       lbsr  ReflectSpawn
        pshs  x
        ldx   reflect.cur
        puls  d
        std   2,x
@next   leay  6,y
        inc   reflect.idx
        tst   ,y
        lbpl  @loop
        rts
        ; variante, OST d'ancrage (0 = pod), decalage y, palier (0 = tous)
@anchors
        fcb   0                        ; coin haut-droit du pod
        fdb   0,-6
        fcb   2
        fcb   1                        ; coin bas-droit du pod
        fdb   0,6
        fcb   2
        fcb   0                        ; bit du haut
        fdb   bitdevTopOST,0
        fcb   0
        fcb   1                        ; bit du bas
        fdb   bitdevBotOST,0
        fcb   0
        fcb   -1                       ; fin

; ---------------------------------------------------------------------------
; ReflectAlive — l'OST retenu porte-t-il encore le reflet de cet ancrage ?
;   [x] = OST retenu (0 = aucun) ; reflect.idx = l'ancrage
;   sortie : Z=1 vivant, A = sa routine (0 Init, 1 Live, 2 Fade) ; Z=0 sinon
; ---------------------------------------------------------------------------
ReflectAlive
        cmpx  #0
        beq   @no
        lda   id,x
        cmpa  #ObjID_forcepod_counterairreflect
        bne   @no
        lda   subtype,x
        lsra
        lsra
        cmpa  reflect.idx
        bne   @no
        lda   routine,x
        cmpa  #3                       ; AlreadyDeleted : le slot est rendu
        bhs   @no
        clrb                           ; Z=1, A intact
        rts
@no     ldb   #1                       ; Z=0
        rts

; ---------------------------------------------------------------------------
; ReflectSpawn — un reflet de cet ancrage nait
;   [u] = pod OST, [y] = l'entree d'ancrage ; sortie : [x] = l'OST, 0 si aucun
; ---------------------------------------------------------------------------
ReflectSpawn
        jsr   LoadObject_x
        bne   >
        ldx   #0
        rts
!       lda   #ObjID_forcepod_counterairreflect
        sta   id,x
        lda   reflect.idx
        asla
        asla                           ; bits 2-3 = ancrage
        ora   ,y                       ; | variante
        ldb   mount_side,u
        aslb                           ; bit 1 = derriere
        pshs  b
        ora   ,s+
        sta   subtype,x
        pshs  y
        ldy   1,y
        bne   @bit
        ldd   x_pos,u                  ; un coin du pod
        subd  #6
        std   x_pos,x
        ldd   y_pos,u
        ldy   ,s
        addd  3,y                      ; -+6
        std   y_pos,x
        puls  y
        bra   ReflectLag
@bit    ldd   x_pos,y                  ; sur le bit
        std   x_pos,x
        ldd   y_pos,y
        std   y_pos,x
        puls  y
        ; fall through
        ; la trame de retard de l'alt : un pas de vol EN ARRIERE (vers le pod)
ReflectLag
        tst   reflect.lag
        beq   @rts
        ldd   x_pos,x
        subd  #REFLECT_STEP
        tst   mount_side,u
        beq   >
        addd  #2*REFLECT_STEP          ; pod derriere : le vol va a gauche
!       std   x_pos,x
@rts    rts

; les deux reflets retenus par ancrage (principal, alt), et l'index de boucle
reflect.slots     fdb   0,0,0,0,0,0,0,0
reflect.cur       fdb   0
reflect.idx       fcb   0
reflect.lag       fcb   0
REFLECT_STEP      equ   3             ; = CR_STEP du reflet (8 px arcade x 0,375)

ForcePodDetachedFire
        ldb   joypad.pressed.fire
        andb  #joypad.0.A
        beq   @rts
        ldb   power_level,u
        decb
        beq   @level1
        decb
        beq   @level2
        decb
        bne   @rts
@level3
        clra
        jsr   InstancateForcePodDetachedFire
        lda   #4
        jsr   InstancateForcePodDetachedFire
@level2
        lda   #1
        jsr   InstancateForcePodDetachedFire
        lda   #3
        jsr   InstancateForcePodDetachedFire
        rts
@level1
        lda   #2
        jsr   InstancateForcePodDetachedFire
@rts    rts

InstancateForcePodDetachedFire
        sta   @a
        jsr   LoadObject_x
        beq   @rts
        lda   #ObjID_forcepod_simplefire
        sta   id,x
        lda   #0
@a      equ *-1        
        sta   subtype,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
@rts    rts

; ---------------------------------------------------------------------------
; UpdateCollisionBox — ACCROCHE, LA BOITE EST BIEN PLUS GROSSE (03/09/2026)
; ---------------------------------------------------------------------------
; ARCADE : deux jeux d'etendues, et le palier n'en pilote qu'un.
;   - flottant : force_pod_collision_data_offsets (0x1000_15BE) indexe par le
;     palier — 4, 7 ou 12 px arcade (blocs 0x15C6 / 0x15CE / 0x15D6), ce que
;     CollisionRadius porte deja converti ;
;   - accroche : UN SEUL bloc, force_pod_attached_hitbox (0x1000_1438) =
;     16 px arcade sur les quatre bords, QUEL QUE SOIT LE PALIER
;     (run_force_pod_attached 0x402581, point 3).
; Chez nous, 16 px arcade valent 6 en x (x0,375) et 12 en y (x0,75) : le pod
; docke balaie donc bien plus large que le meme pod en vol, jusqu'a trois
; fois la surface de sa boite de palier 1.
; ---------------------------------------------------------------------------
UpdateCollisionBox
        lda   player1+forcepod_attached
        beq   @floating
        _ldd  AttachedRadiusX,AttachedRadiusY
        bra   @setRadius
@floating
        ldx   #CollisionRadius          ; load default collision x,y radius
        ldb   power_level,u
        aslb
        ldd   b,x
@setRadius
        std   AABB_0+AABB.rx,u
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u
        ldb   y_pos+1,u
        stb   AABB_0+AABB.cy,u  
        rts

; La boite du pod ACCROCHE : arcade 16 px sur les quatre bords (0x1000_1438),
; soit 6 en x et 12 en y chez nous. Le palier ne la change pas.
AttachedRadiusX equ 6
AttachedRadiusY equ 12

; La boite du pod FLOTTANT, par palier : arcade 4 / 7 / 12 px (0x1000_15C6,
; 0x15CE, 0x15D6) convertis (x0,375 en x, x0,75 en y).
CollisionRadius equ *-2 ; forcepod level begins at 1
        fcb   2,3
        fcb   3,5
        fcb   5,9

ForcePodAnimations equ *-2 ; forcepod level begins at 1
        fdb   Ani_forcepod_0
        fdb   Ani_forcepod_1
        fdb   Ani_forcepod_2

        fcb   6-1 ; frames
        fcb   4-1 ; anim frame duration
Ani_forcepod_0
        fdb   Img_forcepod_0_0
        fdb   Img_forcepod_0_1
        fdb   Img_forcepod_0_2
        fdb   Img_forcepod_0_3
        fdb   Img_forcepod_0_4
        fdb   Img_forcepod_0_5
        fcb   -1

        fcb   6-1 ; frames
        fcb   4-1 ; anim frame duration
Ani_forcepod_1
        fdb   Img_forcepod_1_0
        fdb   Img_forcepod_1_1
        fdb   Img_forcepod_1_2
        fdb   Img_forcepod_1_3
        fdb   Img_forcepod_1_4
        fdb   Img_forcepod_1_5
        fcb   -1

        fcb   4-1 ; frames
        fcb   8-1 ; anim frame duration
Ani_forcepod_2
        fdb   Img_forcepod_2_0
        fdb   Img_forcepod_2_1
        fdb   Img_forcepod_2_2
        fdb   Img_forcepod_2_3
        fcb   -1

checkForcePodUpdate
        ldb   globals.forcepodlevel
        cmpb  power_level,u
        beq   @rts
        stb   power_level,u
        aslb
        ldx   #ForcePodAnimations
        ldd   b,x
        std   anim,u        
@rts    rts     

AnimateForcePodSync
        lda   rotation
        bmi   AnimateForcePodSyncUp

AnimateForcePodSyncDown        
        ldx   anim,u
        cmpx  prev_anim,u
        beq   >
        stx   prev_anim,u
        bra   @resetFWD
!
        ldb   anim_frame_duration,u
        subb  gfxlock.frameDrop.count
        stb   anim_frame_duration,u
        bpl   @rts
@b      ldb   -1,x
        stb   anim_frame_duration,u
        ldb   anim_frame,u
        incb
        stb   anim_frame,u        
        aslb
        ldd   b,x
        cmpa  #-1
        beq   @resetFWD
!       std   image_set,u
@rts    rts
@resetFWD
        clr   anim_frame,u        
        ldd   ,x
        bra   <

AnimateForcePodSyncUp
        ldx   anim,u
        cmpx  prev_anim,u
        beq   >
        stx   prev_anim,u
        bra   @resetRWD
!
        ldb   anim_frame_duration,u
        subb  gfxlock.frameDrop.count
        stb   anim_frame_duration,u
        bpl   @rts
@b      ldb   -1,x
        stb   anim_frame_duration,u
        ldb   anim_frame,u
        decb
        bmi   @resetRWD
        stb   anim_frame,u        
!       aslb
        ldd   b,x
        std   image_set,u
@rts    rts
@resetRWD
        ldb   -2,x
        stb   anim_frame,u        
        bra   <

AnimateForcePodSyncEjected
        ldx   anim,u
        cmpx  prev_anim,u
        beq   >
        stx   prev_anim,u
        bra   @resetFWD
!
        ldb   anim_frame_duration,u
        subb  gfxlock.frameDrop.count
        stb   anim_frame_duration,u
        bpl   @rts
@b      ldb   #2 ; fixed speed for ejected forcepod
        stb   anim_frame_duration,u
        ldb   anim_frame,u
        incb
        stb   anim_frame,u        
        aslb
        ldd   b,x
        cmpa  #-1
        beq   @resetFWD
!       std   image_set,u
@rts    rts
@resetFWD
        clr   anim_frame,u        
        ldd   ,x
        bra   <