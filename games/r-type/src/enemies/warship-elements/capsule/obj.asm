;*******************************************************************************
; La CAPSULE DE SURVIE du vaisseau, et les DETACHABLES (stage 3)
;
; FICHE DE PORTAGE (base Ghidra `maincpu`, subsystem warship)
; -------------------------------------------------------------------------
;   40:d39e create_escape_capsule  40:d3c9 phase 0 (en place, lasers)
;   40:d47f la bascule  40:d4cd phase 1 (ejection)  40:d518 phase 2 (derive)
;   40:cfe9 la petite capsule  40:d095 le triangle  40:d0ff leur tick commun
;   1000:7b46 la boite de la capsule  7a8c celle des detachables
;
; LA CAPSULE A TROIS VIES SUCCESSIVES, et c'est ce qui la distingue de tout le
; reste du vaisseau :
;   0. EN PLACE, vissee a la coque, 20 PV. Toutes les 64 trames elle lache
;      DEUX LASERS horizontaux vers la gauche — mais SEULEMENT si le joueur
;      est dans sa fourchette de hauteur (16 px au-dessus, 48 en dessous).
;      Hors de la fourchette elle ne tire pas : ce n'est pas une tourelle qui
;      vise, c'est un canon fixe qui attend le bon moment.
;   1. EJECTION : au bout de 1056 trames OU quand ses PV tombent, elle se
;      DETACHE et monte. Elle ne meurt pas, elle s'en va.
;   2. DERIVE : elle part vers la gauche jusqu'a sortir du cadre.
;
; LES DETACHABLES (petite capsule, triangle) partagent un seul tick : ils
; restent colles a la couche, encaissent, et disparaissent. Leur seule
; difference est leur image et leur identifiant de score.
;
; ECARTS v2 : position dans le repere de la couche ; pas de sons ; la cascade
; de treize explosions de la capsule (d55d) devient une grosse explosion.
;*******************************************************************************
capsule.AABB    equ ext_variables      ; 0..8
capsule.mapX    equ ext_variables+9    ; 9,10
capsule.y0      equ ext_variables+11   ; 11,12
capsule.cam0    equ ext_variables+13   ; 13,14
capsule.clock   equ ext_variables+15   ; 15,16 le compte de phase
capsule.fire    equ ext_variables+17   ; 17    la cadence de laser

capsule.HP      equ 20                 ; 40:d3a6
capsule.PHASE0  equ 1056               ; 40:d3a2 : 0x420 trames en place
capsule.EJECT   equ 96                 ; 40:d4d1 : 96 trames de montee
capsule.UPVEL   equ -96                ; -128 arcade en 8.8, axe inverse

capsule.Object
        lda   routine,u
        asla
        ldx   #capsule.Routines
        jmp   [a,x]
capsule.Routines
        fdb   capsule.Init
        fdb   capsule.InPlace
        fdb   capsule.Eject
        fdb   capsule.Drift
        fdb   capsule.Deleted

capsule.Init
        jsr   layer.evenX
        std   capsule.mapX,u
        ldd   x_pos,u
        subd  glb_camera_x_pos
        addd  capsule.mapX,u
        std   capsule.mapX,u
        ldd   y_pos,u
        std   capsule.y0,u
        ldd   mscroll.camera.y
        std   capsule.cam0,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldb   #6
        stb   priority,u
        _Collision_AddAABB capsule.AABB,AABB_list_ennemy
        lda   #capsule.HP
        sta   capsule.AABB+AABB.p,u
        ldd   #capsule.BOX
        std   capsule.AABB+AABB.rx,u
        ldd   #capsule.PHASE0
        std   capsule.clock,u
        clr   capsule.fire,u
        ldx   #set_escape_capsule_0
        stx   image_set,u
        inc   routine,u

capsule.InPlace
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   layer.drop
        lda   capsule.AABB+AABB.p,u
        lbeq  capsule.Detach           ; a bout de PV : elle s'ejecte, pas plus

        jsr   layer.evenX
        pshs  d
        ldd   capsule.mapX,u
        subd  ,s++
        addd  glb_camera_x_pos
        std   x_pos,u
        ldd   capsule.y0,u
        ldx   capsule.cam0,u
        jsr   layer.followY
        std   y_pos,u
        jsr   capsule.Box
        lbne  capsule.Vanish

        ldd   capsule.clock,u
        subd  layer.drop
        lble  capsule.Detach           ; l'heure est venue
        std   capsule.clock,u

        ; LE JOUEUR EST-IL A PORTEE ? 16 px au-dessus, 48 en dessous (d409)
        ldd   player1+y_pos
        subd  y_pos,u
        cmpd  #-16
        blt   @pas
        cmpd  #48
        bgt   @pas
        lda   capsule.fire,u
        adda  layer.drop+1
        sta   capsule.fire,u
        anda  #$3F
        cmpa  layer.drop+1
        bhs   @pas                     ; le tour de 64 n'a pas ete franchi
        ldb   #0
        jsr   capsule.Laser
        ldb   #1
        jsr   capsule.Laser
@pas    jmp   DisplaySprite

capsule.Laser
        aslb
        ldx   #capsule.Beams
        abx
        pshs  x
        jsr   LoadObject_x
        tfr   x,y
        puls  x
        cmpy  #0
        beq   @rts
        lda   #ObjID_warship_react
        sta   id,y
        clr   routine,y
        lda   #react.LASER
        sta   subtype,y
        ldb   ,x
        sex
        addd  x_pos,u
        std   x_pos,y
        ldb   1,x
        sex
        addd  y_pos,u
        std   y_pos,y
        clr   x_pos+2,y
        clr   y_pos+2,y
@rts    rts

capsule.Detach
        lda   #capsule.HP
        sta   capsule.AABB+AABB.p,u
        ldd   #capsule.EJECT
        std   capsule.clock,u
        lda   #2
        sta   routine,u
        rts

capsule.Eject
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   layer.drop
        lda   capsule.AABB+AABB.p,u
        lbeq  capsule.Boom
        ldd   #capsule.UPVEL
        leax  y_pos,u
        jsr   layer.AddPos
        jsr   capsule.Box
        lbne  capsule.Vanish
        ldd   capsule.clock,u
        subd  layer.drop
        bgt   >
        lda   #3                       ; la montee est finie : elle derive
        sta   routine,u
        jmp   DisplaySprite
!       std   capsule.clock,u
        jmp   DisplaySprite

capsule.Drift
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   layer.drop
        lda   capsule.AABB+AABB.p,u
        lbeq  capsule.Boom
        ldd   #-256                    ; d518 : un pixel par trame vers la gauche
        leax  x_pos,u
        jsr   layer.AddPos
        jsr   capsule.Box
        lbne  capsule.Vanish
        jmp   DisplaySprite

capsule.Box
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   capsule.AABB+AABB.cx,u
        cmpd  #layer.XGONE
        bhi   @part
        ldd   y_pos,u
        stb   capsule.AABB+AABB.cy,u
        addd  #6
        cmpd  #204+6
        bhi   @part
        orcc  #$04
        rts
@part   andcc #$FB
        rts

capsule.Boom
        ldb   #warship_capsule_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        beq   capsule.Vanish
        _ldd  ObjID_explosion,explosion.subtype.big.brown
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
capsule.Vanish
        lda   #4
        sta   routine,u
        _Collision_RemoveAABB capsule.AABB,AABB_list_ennemy
        jmp   DeleteObject
capsule.Deleted
        rts

; Les deux faisceaux : leur ecart de ponte (d433/d45c), converti
capsule.Beams
        fcb   -18,-3                   ; le bas  : arcade (-48, -4)
        fcb   -22,-12                  ; le haut : arcade (-60, -16)

;===============================================================================
; LE LASER HORIZONTAL de la capsule (40:e6ab)
;===============================================================================
claser.AABB     equ ext_variables      ; 0..8
claser.anim     equ ext_variables+9    ; 9

claser.VEL      equ -288               ; arcade -768 en 8.8, x 0,375

claser.Object
        lda   routine,u
        asla
        ldx   #claser.Routines
        jmp   [a,x]
claser.Routines
        fdb   claser.Init
        fdb   claser.Live
        fdb   claser.Deleted

claser.Init
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldb   #4
        stb   priority,u
        _Collision_AddAABB claser.AABB,AABB_list_foefire
        lda   #1
        sta   claser.AABB+AABB.p,u
        _ldd  3,2
        std   claser.AABB+AABB.rx,u
        clr   claser.anim,u
        inc   routine,u

claser.Live
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   layer.drop
        ldd   #claser.VEL
        leax  x_pos,u
        jsr   layer.AddPos
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   claser.AABB+AABB.cx,u
        cmpd  #159
        lbhi  claser.Vanish
        ldd   y_pos,u
        stb   claser.AABB+AABB.cy,u
        addd  #6
        cmpd  #204+6
        lbhi  claser.Vanish
        lda   claser.anim,u
        adda  layer.drop+1
        sta   claser.anim,u
        lsra
        lsra
        anda  #3
        asla
        ldx   #claser.Sets
        ldx   a,x
        stx   image_set,u
        jmp   DisplaySprite

claser.Vanish
        lda   #2
        sta   routine,u
        _Collision_RemoveAABB claser.AABB,AABB_list_foefire
        jmp   DeleteObject
claser.Deleted
        rts

claser.Sets
        fdb   set_horizontal_laser_0,set_horizontal_laser_1
        fdb   set_horizontal_laser_2,set_horizontal_laser_3

;===============================================================================
; LES DETACHABLES : petite capsule et triangle, un seul tick (40:d0ff)
;===============================================================================
detach.AABB     equ ext_variables      ; 0..8
detach.mapX     equ ext_variables+9    ; 9,10
detach.y0       equ ext_variables+11   ; 11,12
detach.cam0     equ ext_variables+13   ; 13,14
detach.kind     equ ext_variables+15   ; 15    0 = petite capsule, 1 = triangle
                                       ;       (subtype porte la famille)

detach.HP       equ 10

detach.Object
        lda   routine,u
        asla
        ldx   #detach.Routines
        jmp   [a,x]
detach.Routines
        fdb   detach.Init
        fdb   detach.Live
        fdb   detach.Deleted

detach.Init
        jsr   layer.evenX
        std   detach.mapX,u
        ldd   x_pos,u
        subd  glb_camera_x_pos
        addd  detach.mapX,u
        std   detach.mapX,u
        ldd   y_pos,u
        std   detach.y0,u
        ldd   mscroll.camera.y
        std   detach.cam0,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldb   #6
        stb   priority,u
        _Collision_AddAABB detach.AABB,AABB_list_ennemy
        lda   #detach.HP
        sta   detach.AABB+AABB.p,u
        ldd   #detach.BOX
        std   detach.AABB+AABB.rx,u
        lda   subtype,u                ; le creneau de famille distingue
        suba  #react.DETACH            ; les deux detachables : 6 et 7
        anda  #1
        sta   detach.kind,u
        asla
        ldx   #detach.Sets
        ldx   a,x
        stx   image_set,u
        inc   routine,u

detach.Live
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   layer.drop
        lda   detach.AABB+AABB.p,u
        lbeq  detach.Boom
        jsr   layer.evenX
        pshs  d
        ldd   detach.mapX,u
        subd  ,s++
        addd  glb_camera_x_pos
        std   x_pos,u
        ldd   detach.y0,u
        ldx   detach.cam0,u
        jsr   layer.followY
        std   y_pos,u
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   detach.AABB+AABB.cx,u
        cmpd  #layer.XGONE
        lbhi  detach.Vanish
        ldd   y_pos,u
        stb   detach.AABB+AABB.cy,u
        addd  #6
        cmpd  #204+6
        lbhi  detach.Vanish
        jmp   DisplaySprite

detach.Boom
        ldb   #warship_subpart_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        beq   detach.Vanish
        _ldd  ObjID_explosion,explosion.subtype.smallx2
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
detach.Vanish
        lda   #2
        sta   routine,u
        _Collision_RemoveAABB detach.AABB,AABB_list_ennemy
        jmp   DeleteObject
detach.Deleted
        rts

detach.Sets
        fdb   set_small_escape_capsule_0,set_falling_triangle_0
