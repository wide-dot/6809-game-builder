;*******************************************************************************
; LE BYDO SHOT DE L'OUTSLAY — le projectile de la salve en etoile
;
; L'arcade ne tire PAS le bullet commun ici. Le tir en etoile de l'outslay
; (95a3) installe son propre tick, outslay_bydo_shot_tick (95f1), avec sa
; propre table de recipes (1000:417e) et sa propre AABB (1000:4196) :
;
;   * quatre tuiles DISTINCTES (09fe, 09ff, 0af0, 0af1), la boule bydo qui
;     enfle de 6x6 a 12x12 — la ou le bullet commun (84ae) n'a que deux
;     tuiles, 00dc et 00dd, miroitees pour ses frames 3 et 4 ;
;   * un rayon de collision de 4, le double du bullet commun.
;
; On l'avait mappe sur ObjID_foefire faute d'avoir extrait l'art. C'est
; repare : `outslay/images/bydo-shot` sort de l'export arcade, converti sur
; la palette du CORPS qui le tire (meme palette 0x3f cote arcade).
;
; CADENCE — le detail qui ne se devine pas. Le tick fait
; `(global_counter & 6) * 3` sur un pas de 6 octets, soit quatre images
; tenues 2 trames, periode 8. Mais surtout il n'ajoute PAS `(BP >> 3)`,
; contrairement au bullet commun qui s'en sert pour desynchroniser ses
; instances : les huit tirs d'une salve battent donc EN PHASE. La table
; etant en `fdb`, `andb #6` donne directement le decalage — pas de calcul.
;
; PROFONDEUR. L'arcade lui donne la priorite 0xf000 contre 0xa000 au bullet
; commun : il passe donc devant. Ici priority 2, la bande des tirs ennemis,
; qui le met deja devant le serpent (rangs 5/6/7) et devant le vaisseau
; (rang 3) — rien du stage 2 ne rend la distinction avec 0xa000 visible.
;
; Comme le bullet commun, il meurt sur le terrain, hors champ, ou quand sa
; boite est desarmee par un tir joueur ; et comme lui il ne se consume PAS
; en touchant le joueur (l'arcade pose le drapeau de mort et laisse filer).
; L'explosion de fin n'est pas portee, pas plus que pour foefire.
;*******************************************************************************

outslay.shotAABB equ ext_variables      ; struct AABB (9 octets)

outslay.Shot
        lda   routine,u
        asla
        ldx   #outslay.ShotTab
        jmp   [a,x]
outslay.ShotTab
        fdb   outslay.ShotInit
        fdb   outslay.ShotLive
        fdb   outslay.ShotDeleted

outslay.ShotInit
        ldb   #2
        stb   priority,u
        lda   render_flags,u            ; le tir vit dans le PLAYFIELD : il
        ora   #render_playfieldcoord_mask ; derive avec la camera, contrairement
        sta   render_flags,u            ; au serpent qui est pilote par script
        inc   routine,u

        _Collision_AddAABB outslay.shotAABB,AABB_list_foefire
        leax  outslay.shotAABB,u
        lda   #outslay_shot_hitdamage
        sta   AABB.p,x
        _ldd  outslay_shot_hitbox_x,outslay_shot_hitbox_y
        std   AABB.rx,x

outslay.ShotLive
        ; -- l'image, EN PHASE pour toute la salve (95f1 n'ajoute pas BP>>3) --
        ldb   gfxlock.frame.count+1
        andb  #6                        ; 0/2/4/6 = deja le decalage d'un fdb
        ldx   #outslay.ShotImages
        abx
        ldd   ,x
        std   image_set,u

        ; -- le deplacement, en phase avec la cadence reelle ------------------
        lda   gfxlock.frameDrop.count
        sta   glb_d0_b
        ldd   #0
!       addd  x_vel,u
        dec   glb_d0_b
        bne   <
        jsr   moveXPos8.8

        lda   gfxlock.frameDrop.count
        sta   glb_d0_b
        ldd   #0
!       addd  y_vel,u
        dec   glb_d0_b
        bne   <
        jsr   moveYPos8.8

        jsr   DisplaySprite

        ; -- le terrain : premier plan, puis fond si le stage le declare dur --
        ldd   x_pos,u
        std   terrainCollision.sensor.x
        ldd   y_pos,u
        std   terrainCollision.sensor.y
        ldb   #1                        ; foreground
        jsr   terrainCollision.do
        tstb
        bne   outslay.ShotDestroy
        lda   globals.backgroundSolid
        beq   >
        ldd   x_pos,u
        std   terrainCollision.sensor.x
        ldd   y_pos,u
        std   terrainCollision.sensor.y
        ldb   #0                        ; background
        jsr   terrainCollision.do
        tstb
        bne   outslay.ShotDestroy
!
        ; -- hors champ ------------------------------------------------------
        ldd   x_pos,u
        cmpd  glb_camera_x_pos
        ble   outslay.ShotDestroy
        subd  #160-8/2
        cmpd  glb_camera_x_pos
        bge   outslay.ShotDestroy
        ldd   y_pos,u
        ble   outslay.ShotDestroy
        cmpd  #160
        bge   outslay.ShotDestroy

        ; -- la boite : desarmee = touchee ------------------------------------
        leax  outslay.shotAABB,u
        lda   AABB.p,x
        beq   outslay.ShotDestroy

        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB.cx,x
        ldb   y_pos+1,u
        stb   AABB.cy,x
        rts

outslay.ShotDestroy
        inc   routine,u
        _Collision_RemoveAABB outslay.shotAABB,AABB_list_foefire
        jmp   DeleteObject

outslay.ShotDeleted
        rts

outslay.ShotImages
        fdb   set_outslay_shot_0
        fdb   set_outslay_shot_1
        fdb   set_outslay_shot_2
        fdb   set_outslay_shot_3
