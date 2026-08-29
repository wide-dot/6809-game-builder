;*******************************************************************************
; Les tourelles AUTONOMES du vaisseau (stage 3) — 22 exemplaires
;
; FICHE DE PORTAGE (base Ghidra `maincpu`, subsystem warship)
; -------------------------------------------------------------------------
;   40:e26a install_small_turret_standalone_top     (10 exemplaires)
;   40:e277 install_small_turret_standalone_bottom  ( 7 exemplaires)
;   40:e281 small_turret_standalone_init  40:e2aa son tick
;   40:e361 fire_helper_top  40:e3ca fire_helper_bottom
;   40:e33e sa mort
;   40:e129 install_big_turret_top ( 5 exemplaires)  40:e157 son tick
;   40:e201 son helper de tir      40:e1de sa mort
;   1000:8258 / 8278 / 81fa  les roues de poses (16 -> 9)
;   1000:8304 / 830c / 8250  les boites
;
; « AUTONOME » veut dire sans parent : contrairement aux tourelles de la
; capsule (40:d28f, qui suit son porteur par un renvoi), celle-ci est fixee
; SUR LA COQUE aux coordonnees de sa naissance et ne bouge plus qu'avec elle.
;
; ECART v2 ASSUME — LA POSITION VIT DANS LE REPERE DE LA COUCHE.
; L'arcade pousse a chaque trame le delta de scroll du vaisseau
; (0x2ed4/0x2ed6) dans la position de chaque tourelle. On range plutot la
; position en coordonnees de COUCHE et on derive l'ecran par `carte - camera`
; a l'affichage : resultat identique, compensation de frame-drop gratuite
; (elle est deja dans la camera), et rien ne derive a l'accumulation sur les
; 9 280 trames du script. C'est le geste que le plan de collision de fond a
; adopte le 26/08, pour la meme raison. Doc : doc/warship-parts-plan.md
;
; LA VISEE. `setDirectionTo` rend une direction multiple de 4 sur 64 ; un
; `asrb` en fait l'offset d'une table de SEIZE mots — la roue. L'arcade fait
; le meme geste (`BX >>= 1` sur une direction bornee a 0x20). La roue ne
; designe que NEUF poses, elle est palindromique : voir wheel.asm, genere.
;
; LE TIR passe par le prereglage 1 (`load_fire_preset(CX=0x10)` en arcade,
; soit les bits 4-7 a 1 chez nous) et la cadence commune `tryFoeFire` — les
; deux sont residents et de meme semantique. L'arcade distingue un helper de
; tir par montage (e361 / e3ca), dont la seule difference est la fenetre
; angulaire ; la cadence commune la rend deja par la direction visee.
;
; ABANDONNE : les sons (0x56 coup, 0x52 mort), et l'eclat de coup par palette
; d'objet — meme arbitrage que partout, une image blanche ou rien, et ici
; rien : la tourelle meurt en deux coups.
;*******************************************************************************
; -----------------------------------------------------------------------------
; L'ETAT — la position de couche, que la camera transforme en position ecran
; -----------------------------------------------------------------------------
turret.AABB     equ ext_variables      ; 0..8  la boite
turret.mapX     equ ext_variables+9    ; 9,10  abscisse dans la COUCHE
; L'ORDONNEE NE SE RANGE PAS EN ABSOLU : la camera.y de la couche est
; REPLIEE dans [0,384[ et la choregraphie la fait osciller autour de zero, donc
; une ordonnee absolue saute de 384 px a chaque couture. On garde l'ordonnee
; d'ECRAN a la naissance et la camera de ce moment ; layer.followY mesure la
; derive repliee. Voir warship-elements/layer.asm.
turret.y0       equ ext_variables+11   ; 11,12 ordonnee ECRAN a la naissance
turret.cam0     equ ext_variables+13   ; 13,14 la camera.y de ce moment
turret.wheel    equ ext_variables+15   ; 15,16 sa roue de poses
turret.cy       equ ext_variables+17   ; 17    l'excentrage de la boite, signe

turret.Object
        lda   routine,u
        asla
        ldx   #turret.Routines
        jmp   [a,x]
turret.Routines
        fdb   turret.Init
        fdb   turret.Live
        fdb   turret.Deleted

; -----------------------------------------------------------------------------
; L'init. Le spawner a depose la position ECRAN de naissance dans x_pos/y_pos
; et le montage dans subtype ; on la fige en coordonnees de couche, une fois.
; -----------------------------------------------------------------------------
turret.Init
        ; ecran -> couche : la camera de la couche est l'origine du repere
        jsr   layer.evenX              ; la camera COMME LA COUCHE L'AFFICHE :
        std   turret.mapX,u            ; son pas est de 2 px, l'ancre et la
        ldd   x_pos,u                  ; derivation doivent prendre le meme
        subd  glb_camera_x_pos         ; arrondi qu'elle (layer.asm)
        addd  turret.mapX,u
        std   turret.mapX,u
        ldd   y_pos,u
        std   turret.y0,u
        ldd   mscroll.camera.y
        std   turret.cam0,u

        lda   subtype,u
        asla
        ldx   #turret.Wheels
        ldx   a,x
        stx   turret.wheel,u

        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldb   #6
        stb   priority,u

        _Collision_AddAABB turret.AABB,AABB_list_ennemy
        lda   subtype,u
        cmpa  #turret.BIG
        beq   @grosse
        lda   #warship_small_turret_hitdamage
        sta   turret.AABB+AABB.p,u
        _ldd  warship_small_turret_hitbox_x,warship_small_turret_hitbox_y
        bra   @boite
@grosse lda   #warship_big_turret_hitdamage
        sta   turret.AABB+AABB.p,u
        _ldd  warship_big_turret_hitbox_x,warship_big_turret_hitbox_y
@boite  std   turret.AABB+AABB.rx,u
        ldb   #warship_small_turret_cy
        lda   subtype,u
        beq   @cy                      ; montage HAUT : vers le bas
        cmpa  #turret.BOTTOM
        bne   >
        ldb   #-warship_small_turret_cy ; montage BAS : vers le haut
        bra   @cy
!       ldb   #warship_big_turret_cy
@cy     stb   turret.cy,u

        ; le prereglage de tir 1, comme l'arcade (CX=0x10 -> bits 4-7)
        ldb   #$10
        _loadFirePreset

        inc   routine,u
        ; PAS DE RTS : elle vit des sa premiere trame, comme l'arcade

; -----------------------------------------------------------------------------
; La trame : suivre la couche, viser, tirer, encaisser.
; -----------------------------------------------------------------------------
turret.Live
        lda   turret.AABB+AABB.p,u
        lbeq  turret.Boom              ; PV epuises

        ; --- la couche la porte : sa position d'ecran en decoule -------------
        jsr   layer.evenX              ; le meme arrondi que la couche
        pshs  d
        ldd   turret.mapX,u
        subd  ,s++                     ; -> x ecran, quantifie comme la coque
        addd  glb_camera_x_pos         ; -> x monde, ce que le moteur dessine
        std   x_pos,u
        ldd   turret.y0,u
        ldx   turret.cam0,u
        jsr   layer.followY
        std   y_pos,u

        ; --- la fenetre : sortie par la gauche, elle s'en va ------------------
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   turret.AABB+AABB.cx,u
        cmpd  #layer.XGONE
        lbhi  turret.Vanish
        ldd   y_pos,u
        ; LE CENTRE DE LA BOITE est excentre vers le canon : l'axe y arcade
        ; monte, donc le montage HAUT la porte vers le bas de l'ancre.
        addb  turret.cy,u
        stb   turret.AABB+AABB.cy,u
        subb  turret.cy,u
        addd  #6
        cmpd  #204+6
        lbhi  turret.Vanish

        ; --- la visee : la roue, comme le blaster ---------------------------
        ldx   #player1
        jsr   setDirectionTo
        tfr   y,d
        asrb                           ; direction/2 : l'offset d'une table de
        ldx   turret.wheel,u           ; seize mots
        ldd   b,x
        std   image_set,u

        jsr   tryFoeFire
        jmp   DisplaySprite

; -----------------------------------------------------------------------------
turret.Boom
        ldb   #warship_small_turret_scoreIdx
        lda   subtype,u
        cmpa  #turret.BIG
        bne   >
        ldb   #warship_big_turret_scoreIdx
!       jsr   AwardScore
        jsr   LoadObject_x
        beq   turret.Vanish
        _ldd  ObjID_explosion,explosion.subtype.smallx2
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
turret.Vanish
        lda   #2
        sta   routine,u
        _Collision_RemoveAABB turret.AABB,AABB_list_ennemy
        jmp   DeleteObject
turret.Deleted
        rts

; Les trois montages, dans l'ordre des sous-types poses par le script de spawn
        INCLUDE "src/enemies/warship-elements/turret/turret.equ"
turret.Wheels
        fdb   turret.wheel.small_turret_top
        fdb   turret.wheel.small_turret_bottom
        fdb   turret.wheel.big_turret

        INCLUDE "src/enemies/warship-elements/turret/wheel.asm"
