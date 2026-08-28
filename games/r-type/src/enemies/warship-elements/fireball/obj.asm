;*******************************************************************************
; La BOULE DE FEU de la proue, et son eclat de bouche (stage 3)
;
; FICHE DE PORTAGE (base Ghidra `maincpu`, subsystem warship)
; -------------------------------------------------------------------------
;   40:d7b9 l'init (charge 12 trames, ponte de l'eclat)   40:d807 le vol
;   40:d789 l'eclat de bouche (15 trames, 8 poses)
;   40:d86d/d892 la dissipation — NON PORTEE, voir l'ecart
;   1000:7e4e la boite
;
; LA CHARGE : douze trames INVISIBLE, collee a la bouche du canon (la couche
; la porte), pendant que l'eclat joue par-dessus. Puis le vol : la vitesse
; posee a la ponte, JAMAIS corrigee — et sans suivre le defilement, comme
; les tirs (l'arcade n'applique que la vitesse en vol).
; Le scintillement : la pose et son alternat, une bascule toutes les 4 trames.
;
; LE DECOR L'ARRETE : sonde des DEUX plans (le fond est solide sur ce stage —
; la silhouette du vaisseau), comme le missile du joueur.
;
; ECART ASSUME (28/08/2026) : pas de dissipation dediee. Les recettes arcade
; deplacent la bouffee le long de la paroi sur 64-80 px : un canevas v2 de
; 48-60 lignes, rejete EN BLOC par le culling au ras des parois — la ou,
; precisement, elle joue. La boule meurt en explosion standard ; l'export
; amont (catalog fireball-dissipate-a/b) attend un convertisseur a ancres
; par pose.
;*******************************************************************************
fireball.AABB   equ ext_variables      ; 0..8 — la liste des tirs ennemis
fireball.mapX   equ ext_variables+9    ; 9,10
fireball.y0     equ ext_variables+11   ; 11,12
fireball.cam0   equ ext_variables+13   ; 13,14
fireball.charge equ ext_variables+15   ; 15   la charge, 12 trames
fireball.alt    equ ext_variables+16   ; 16   l'alternat de scintillement
fireball.pose   equ ext_variables+17   ; 17   sa pose — PAS dans subtype, qui
                                       ;      porte la famille du groupe
                                       ;      (seme par la tourelle, subtype
                                       ;      porte la pose)

fireball.CHARGE equ 12                 ; d7bd : douze trames invisible

fireball.Object
        lda   routine,u
        asla
        ldx   #fireball.Routines
        jmp   [a,x]
fireball.Routines
        fdb   fireball.Init
        fdb   fireball.Charge
        fdb   fireball.Flight
        fdb   fireball.Deleted

fireball.Init
        jsr   layer.evenX
        std   fireball.mapX,u
        ldd   x_pos,u
        subd  glb_camera_x_pos
        addd  fireball.mapX,u
        std   fireball.mapX,u
        ldd   y_pos,u
        std   fireball.y0,u
        ldd   mscroll.camera.y
        std   fireball.cam0,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldb   #4
        stb   priority,u
        _Collision_AddAABB fireball.AABB,AABB_list_foefire
        lda   #1
        sta   fireball.AABB+AABB.p,u   ; un tir ennemi : un point de degat
        ldd   #fireball.BOX
        std   fireball.AABB+AABB.rx,u
        lda   #fireball.CHARGE
        sta   fireball.charge,u
        lda   #1
        sta   routine,u
        ; --- l'eclat de bouche, au bout du canon (d7c3) ---------------------
        ; l'ecart vaut seize fois le pas par trame : vitesse 8.8 / 16
        jsr   LoadObject_x
        beq   @rts
        lda   #ObjID_warship_fire
        sta   id,x
        clr   routine,x
        lda   #fire.MUZZLE
        sta   subtype,x
        ldd   x_vel,u
        asra
        rorb
        asra
        rorb
        asra
        rorb
        asra
        rorb
        addd  x_pos,u
        std   x_pos,x
        ldd   y_vel,u
        asra
        rorb
        asra
        rorb
        asra
        rorb
        asra
        rorb
        addd  y_pos,u
        std   y_pos,x
        clr   x_pos+2,x
        clr   y_pos+2,x
@rts    rts                            ; invisible : la charge commence

; --- la charge : collee au canon, invisible, l'eclat joue par-dessus --------
fireball.Charge
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   layer.drop
        jsr   layer.evenX
        pshs  d
        ldd   fireball.mapX,u
        subd  ,s++
        addd  glb_camera_x_pos
        std   x_pos,u
        ldd   fireball.y0,u
        ldx   fireball.cam0,u
        jsr   layer.followY
        std   y_pos,u
        jsr   fireball.Box
        lda   fireball.charge,u
        suba  layer.drop+1
        bhi   >
        inc   routine,u                ; la charge est finie : le vol
        rts
!       sta   fireball.charge,u
        rts

; --- le vol : la vitesse seule, le scintillement, le decor ------------------
fireball.Flight
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   layer.drop
        ldd   x_vel,u
        leax  x_pos,u
        jsr   layer.AddPos
        ldd   y_vel,u
        leax  y_pos,u
        jsr   layer.AddPos
        ; la fenetre
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   fireball.AABB+AABB.cx,u
        cmpd  #159
        lbhi  fireball.Vanish
        ldd   y_pos,u
        stb   fireball.AABB+AABB.cy,u
        addd  #6
        cmpd  #204+6
        lbhi  fireball.Vanish
        ; le decor l'arrete — les deux plans, comme le missile du joueur
        ldd   x_pos,u
        std   terrainCollision.sensor.x
        ldd   y_pos,u
        std   terrainCollision.sensor.y
        ldb   #1
        jsr   terrainCollision.do
        tstb
        bne   @mur
        lda   globals.backgroundSolid
        beq   @vole
        ldb   #0
        jsr   terrainCollision.do
        tstb
        beq   @vole
@mur    ; ECART : l'explosion standard tient lieu de dissipation
        jsr   LoadObject_x
        beq   fireball.Vanish
        _ldd  ObjID_explosion,explosion.subtype.smallx2
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
        bra   fireball.Vanish
@vole   ; le scintillement : pose/alternat, bascule toutes les 4 trames (d81b)
        ldd   gfxlock.frame.gameCount
        andb  #4
        beq   >
        ldb   fireball.alt,u
        bra   @pose
!       ldb   fireball.pose,u
@pose   aslb
        ldx   #fireball.Sets
        abx
        ldx   ,x
        stx   image_set,u
        jmp   DisplaySprite

fireball.Box
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   fireball.AABB+AABB.cx,u
        ldd   y_pos,u
        stb   fireball.AABB+AABB.cy,u
        rts

fireball.Vanish
        lda   #3
        sta   routine,u
        _Collision_RemoveAABB fireball.AABB,AABB_list_foefire
        jmp   DeleteObject
fireball.Deleted
        rts

; Les 22 poses de la boule, dans l'ordre des recettes arcade (1000:7d32) —
; les tables de tir les designent par paires (pose, alternat).
fireball.Sets
        fdb   set_fire_ball_0,set_fire_ball_1,set_fire_ball_2,set_fire_ball_3
        fdb   set_fire_ball_4,set_fire_ball_5,set_fire_ball_6,set_fire_ball_7
        fdb   set_fire_ball_8,set_fire_ball_9,set_fire_ball_10,set_fire_ball_11
        fdb   set_fire_ball_12,set_fire_ball_13,set_fire_ball_14,set_fire_ball_15
        fdb   set_fire_ball_16,set_fire_ball_17,set_fire_ball_18,set_fire_ball_19
        fdb   set_fire_ball_20,set_fire_ball_21

;*******************************************************************************
; L'ECLAT DE BOUCHE (40:d789) : quinze trames au bout du canon, colle a la
; couche, huit poses par les bits 1-3 de la vie qui descend. Pas de boite.
;*******************************************************************************
muzzle.mapX     equ ext_variables      ; 0,1
muzzle.y0       equ ext_variables+2    ; 2,3
muzzle.cam0     equ ext_variables+4    ; 4,5
muzzle.life     equ ext_variables+6    ; 6

muzzle.Object
        lda   routine,u
        asla
        ldx   #muzzle.Routines
        jmp   [a,x]
muzzle.Routines
        fdb   muzzle.Init
        fdb   muzzle.Live
        fdb   muzzle.Deleted

muzzle.Init
        jsr   layer.evenX
        std   muzzle.mapX,u
        ldd   x_pos,u
        subd  glb_camera_x_pos
        addd  muzzle.mapX,u
        std   muzzle.mapX,u
        ldd   y_pos,u
        std   muzzle.y0,u
        ldd   mscroll.camera.y
        std   muzzle.cam0,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldb   #4
        stb   priority,u
        lda   #15                      ; d7ee : quinze trames de vie
        sta   muzzle.life,u
        inc   routine,u

muzzle.Live
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   layer.drop
        jsr   layer.evenX
        pshs  d
        ldd   muzzle.mapX,u
        subd  ,s++
        addd  glb_camera_x_pos
        std   x_pos,u
        ldd   muzzle.y0,u
        ldx   muzzle.cam0,u
        jsr   layer.followY
        std   y_pos,u
        lda   muzzle.life,u
        suba  layer.drop+1
        bls   @fin
        sta   muzzle.life,u
        anda  #$0E                     ; d78f : la pose par les bits 1-3
        ldx   #muzzle.Sets
        ldx   a,x
        stx   image_set,u
        jmp   DisplaySprite
@fin    lda   #2
        sta   routine,u
        jmp   DeleteObject
muzzle.Deleted
        rts

        INCLUDE "src/enemies/warship-elements/fireball/tables.asm"
