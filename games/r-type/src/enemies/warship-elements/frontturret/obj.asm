;*******************************************************************************
; Les tourelles de PROUE du vaisseau (stage 3) — 6 exemplaires, 6 variantes
;
; FICHE DE PORTAGE (base Ghidra `maincpu`, subsystem warship)
; -------------------------------------------------------------------------
;   40:d596..d5dc les six vignettes (poses, table de tir) — c et e partagent
;                 leurs poses, chacune a SA table de tir
;   40:d5e1 l'init commun (14 PV, graine de cadence aleatoire)
;   40:d608 le tick : visee 16 directions, tir aux 128 trames
;   1000:7e46 la boite     tables : voir tables.asm, GENERE depuis la ROM
;
; La visee est celle des tourelles autonomes (roue de 16, poses palindromiques
; dedupliquees). LE TIR est le trait propre : toutes les 128 trames — avec une
; graine ALEATOIRE par tourelle, pour que les six ne tirent pas en salve — la
; table de tir de la variante donne, PAR DIRECTION VISEE, la vitesse 8.8 de la
; boule de feu et sa paire de poses. Une entree nulle est la PORTE D'ARC :
; dans ces directions la tourelle ne tire pas.
;
; ECARTS v2 : position dans le repere de la couche (layer.asm) ; pas de sons ;
; pas de clignotement de coup (campagne hit a part).
;*******************************************************************************
fturret.AABB    equ ext_variables      ; 0..8
fturret.mapX    equ ext_variables+9    ; 9,10
fturret.y0      equ ext_variables+11   ; 11,12
fturret.cam0    equ ext_variables+13   ; 13,14
fturret.cnt     equ ext_variables+15   ; 15  le compteur de cadence (128)

fturret.HP      equ 14                 ; 40:d5e5 MOV byte ptr [BP+0x2f],0xe

fturret.Object
        lda   routine,u
        asla
        ldx   #fturret.Routines
        jmp   [a,x]
fturret.Routines
        fdb   fturret.Init
        fdb   fturret.Live
        fdb   fturret.Deleted

fturret.Init
        jsr   layer.evenX
        std   fturret.mapX,u
        ldd   x_pos,u
        subd  glb_camera_x_pos
        addd  fturret.mapX,u
        std   fturret.mapX,u
        ldd   y_pos,u
        std   fturret.y0,u
        ldd   mscroll.camera.y
        std   fturret.cam0,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldb   #6
        stb   priority,u
        _Collision_AddAABB fturret.AABB,AABB_list_ennemy
        lda   #fturret.HP
        sta   fturret.AABB+AABB.p,u
        ldd   #fturret.BOX
        std   fturret.AABB+AABB.rx,u
        jsr   RandomNumber             ; d5f9 : la graine de cadence — les six
        stb   fturret.cnt,u            ; tourelles ne tirent pas en salve
        inc   routine,u
        ; PAS DE RTS : elle vit des sa premiere trame

fturret.Live
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   layer.drop
        lda   fturret.AABB+AABB.p,u
        lbeq  fturret.Boom

        ; --- la couche la porte ---------------------------------------------
        jsr   layer.evenX
        pshs  d
        ldd   fturret.mapX,u
        subd  ,s++
        addd  glb_camera_x_pos
        std   x_pos,u
        ldd   fturret.y0,u
        ldx   fturret.cam0,u
        jsr   layer.followY
        std   y_pos,u

        ; --- la fenetre ------------------------------------------------------
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   fturret.AABB+AABB.cx,u
        cmpd  #159
        lbhi  fturret.Vanish
        ldd   y_pos,u
        stb   fturret.AABB+AABB.cy,u
        addd  #6
        cmpd  #204+6
        lbhi  fturret.Vanish

        ; --- la visee : la roue de la variante ------------------------------
        ldx   #player1
        jsr   setDirectionTo
        tfr   y,d
        pshs  b                        ; la direction (multiple de 4), pour le tir
        lda   subtype,u
        asla
        ldx   #fturret.Wheels
        ldx   a,x
        asrb                           ; direction/2 : l'offset des tables fdb
        ldd   b,x
        std   image_set,u

        ; --- le tir : toutes les 128 trames, au franchissement --------------
        lda   fturret.cnt,u
        tfr   a,b
        addb  layer.drop+1
        stb   fturret.cnt,u
        anda  #$7F
        adda  layer.drop+1
        cmpa  #$80
        blo   @pas
        ; la direction visee choisit l'entree (6 octets chacune)
        puls  b                        ; la direction, multiple de 4
        lsrb                           ; /4 -> l'index 0..15...
        lsrb
        lda   #6
        mul                            ; ... x6 -> l'offset, qui tient
        pshs  b                        ; dans B (90 au plus) : le mettre
        lda   subtype,u                ; a l'abri, car le calcul de la
        asla                           ; table ECRASE A — donc le poids
        ldx   #fturret.Fires           ; fort de D, et un `leax d,x`
        ldx   a,x                      ; sautait alors subtype*256
        puls  b                        ; octets hors table.
        abx
        lda   4,x                      ; la pose de la boule
        cmpa  #$FF
        beq   @rts                     ; porte d'arc : pas de tir par ici
        pshs  x
        jsr   LoadObject_x
        tfr   x,y                      ; Y = l'enfant
        puls  x
        cmpy  #0
        beq   @rts
        lda   #ObjID_warship_fireball
        sta   id,y
        clr   routine,y
        ldd   ,x                       ; vx
        std   x_vel,y
        ldd   2,x                      ; vy
        std   y_vel,y
        lda   4,x
        sta   subtype,y                ; la pose...
        lda   5,x
        sta   fireball.alt,y           ; ... et son alternat de scintillement
        ldd   x_pos,u
        std   x_pos,y
        ldd   y_pos,u
        std   y_pos,y
        clr   x_pos+2,y
        clr   y_pos+2,y
@rts    jmp   DisplaySprite
@pas    puls  b
        jmp   DisplaySprite

fturret.Boom
        ldb   #warship_turret_front_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        beq   fturret.Vanish
        _ldd  ObjID_explosion,explosion.subtype.smallx2
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
fturret.Vanish
        lda   #2
        sta   routine,u
        _Collision_RemoveAABB fturret.AABB,AABB_list_ennemy
        jmp   DeleteObject
fturret.Deleted
        rts

        INCLUDE "src/enemies/warship-elements/frontturret/tables.asm"
