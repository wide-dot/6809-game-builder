;*******************************************************************************
; Les tourelles MULTIPLES du vaisseau (stage 3) — 4 exemplaires, 4 montages
;
; FICHE DE PORTAGE (base Ghidra `maincpu`, subsystem warship)
; -------------------------------------------------------------------------
;   40:db63..db8f les quatre vignettes (anim, patron de tir)
;   40:db94 l'init commun (4 PV)   40:dbb5 le tick   40:dc63 le tir
;   1000:80c6 la boite, partagee   tables : voir tables.asm, GENERE
;
; DEUX TRAITS PROPRES, releves sur les plates :
;   . l'animation est TEMPORELLE, pas de visee : quatre poses qui tournent
;     comme un barillet, seize trames chacune, sur l'horloge de jeu ;
;   . le tir est un PATRON : toutes les seize trames une phase avance
;     (0,1,2,3), et chaque phase tire son vecteur — la phase 1 en tire DEUX
;     (les entrees 1 et 4, le « multi » du nom). Cinq balles par cycle de 64.
; Les balles sont le tir ennemi generique (run_foe_fire = notre foefire),
; pondu au point (dx,dy) du patron avec un delai de visibilite de 4.
;
; ECARTS v2 : position dans le repere de la couche ; pas de sons ; pas de
; clignotement de coup.
;*******************************************************************************
multi.AABB      equ ext_variables      ; 0..8
multi.mapX      equ ext_variables+9    ; 9,10
multi.y0        equ ext_variables+11   ; 11,12
multi.cam0      equ ext_variables+13   ; 13,14
multi.acc       equ ext_variables+15   ; 15  l'accumulateur de cadence (16)
multi.phase     equ ext_variables+16   ; 16  la phase du patron, 0..3
multi.mount     equ ext_variables+17   ; 17  le montage — PAS dans subtype,
                                       ;     qui porte la famille du groupe

multi.HP        equ 4                  ; 40:db98 MOV byte ptr [BP+0x2f],0x4

multi.Object
        lda   routine,u
        asla
        ldx   #multi.Routines
        jmp   [a,x]
multi.Routines
        fdb   multi.Init
        fdb   multi.Live
        fdb   multi.Deleted

multi.Init
        jsr   layer.evenX
        std   multi.mapX,u
        ldd   x_pos,u
        subd  glb_camera_x_pos
        addd  multi.mapX,u
        std   multi.mapX,u
        ldd   y_pos,u
        std   multi.y0,u
        ldd   mscroll.camera.y
        std   multi.cam0,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldb   #6
        stb   priority,u
        _Collision_AddAABB multi.AABB,AABB_list_ennemy
        lda   #multi.HP
        sta   multi.AABB+AABB.p,u
        ldd   #multi.BOX
        std   multi.AABB+AABB.rx,u
        clr   multi.acc,u
        clr   multi.phase,u
        ; le montage arrive dans subtype et demenage : subtype porte
        ; desormais la FAMILLE du groupe (voir fire.Object)
        lda   subtype,u
        sta   multi.mount,u
        inc   routine,u
        ; PAS DE RTS : elle vit des sa premiere trame

multi.Live
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   layer.drop
        lda   multi.AABB+AABB.p,u
        lbeq  multi.Boom

        ; --- la couche la porte ---------------------------------------------
        jsr   layer.evenX
        pshs  d
        ldd   multi.mapX,u
        subd  ,s++
        addd  glb_camera_x_pos
        std   x_pos,u
        ldd   multi.y0,u
        ldx   multi.cam0,u
        jsr   layer.followY
        std   y_pos,u

        ; --- la fenetre ------------------------------------------------------
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   multi.AABB+AABB.cx,u
        cmpd  #layer.XGONE
        lbhi  multi.Vanish
        ldd   y_pos,u
        stb   multi.AABB+AABB.cy,u
        addd  #6
        cmpd  #204+6
        lbhi  multi.Vanish

        ; --- le barillet : quatre poses de seize trames, sur l'horloge -------
        ldd   gfxlock.frame.gameCount
        andb  #$30                     ; dbc7 : (compteur & $30) — seize trames
        lsrb
        lsrb
        lsrb                           ; ... par pose, offset fdb
        lda   multi.mount,u
        asla
        ldx   #multi.Anims
        ldx   a,x
        ldd   b,x
        std   image_set,u

        ; --- le patron de tir : une phase toutes les seize trames ------------
        lda   multi.acc,u
        adda  layer.drop+1
@tire   cmpa  #16
        blo   @garde
        suba  #16
        pshs  a
        jsr   multi.Fire
        puls  a
        bra   @tire
@garde  sta   multi.acc,u
        jmp   DisplaySprite

; -----------------------------------------------------------------------------
; Une phase du patron (dc63) : la 1 tire les vecteurs 1 ET 4, les autres le
; leur. La balle est le foefire generique, au point de ponte du patron.
; -----------------------------------------------------------------------------
multi.Fire
        lda   multi.phase,u
        inca
        anda  #3
        sta   multi.phase,u
        deca                           ; A = la phase qui tire (0..3)
        anda  #3
        beq   @v0
        cmpa  #1
        beq   @deux
        cmpa  #2
        beq   @v2
        ldb   #12                      ; phase 3 : vecteur 3
        bra   @un
@v0     clrb                           ; phase 0 : vecteur 0
        bra   @un
@v2     ldb   #8                       ; phase 2 : vecteur 2
        bra   @un
@deux   ldb   #4                       ; phase 1 : les vecteurs 1 ET 4 —
        bsr   @un                      ; le tir « multi »
        ldb   #16
@un     pshs  b                        ; le patron se recharge a CHAQUE tir :
        lda   multi.mount,u                ; le premier appel de la phase 1 a
        asla                           ; consomme X
        ldx   #multi.Fires
        ldx   a,x
        puls  b
        abx
        pshs  x
        jsr   LoadObject_x
        tfr   x,y
        puls  x
        cmpy  #0
        beq   @rts
        lda   #ObjID_foefire
        sta   id,y
        clr   routine,y
        ldd   ,x                       ; le vecteur de la phase
        std   x_vel,y
        ldd   2,x
        std   y_vel,y
        ; X pointe le vecteur ; le point de ponte est en queue de patron,
        ; a 20-B... plus simple : le patron le porte a +20 de sa base, et
        ; B a ete consomme par abx — on repart du patron
        lda   multi.mount,u
        asla
        pshs  x
        ldx   #multi.Fires
        ldx   a,x
        ldb   20,x                     ; dx, signe
        sex
        addd  x_pos,u
        pshs  d
        ldb   21,x                     ; dy, signe
        sex
        addd  y_pos,u
        std   y_pos,y
        clr   y_pos+2,y
        puls  d
        std   x_pos,y
        clr   x_pos+2,y
        puls  x
        lda   #4                       ; dc99 : quatre trames invisibles
        sta   fireDisplayDelay,y
@rts    rts

multi.Boom
        ldb   #warship_multi_turret_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        beq   multi.Vanish
        _ldd  ObjID_explosion,explosion.subtype.smallx2
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
multi.Vanish
        lda   #2
        sta   routine,u
        _Collision_RemoveAABB multi.AABB,AABB_list_ennemy
        jmp   DeleteObject
multi.Deleted
        rts

        INCLUDE "src/enemies/warship-elements/multiturret/tables.asm"
