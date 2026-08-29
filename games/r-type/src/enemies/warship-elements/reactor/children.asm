;*******************************************************************************
; Les enfants des reacteurs : flammes geantes, bouffees de ventre, balle blanche
;
;   40:cee6 les flammes geantes de la queue (cercles d'amorcage puis flammes)
;   40:cf9c la balle blanche      40:dac8/db02 la bouffee d'un reacteur de ventre
;
; Les deux flammes sont des ENFANTS A DUREE DE VIE colles a la couche : elles
; ne blessent pas, elles montrent. La balle, elle, est un tir ennemi ordinaire
; — vitesse figee a la ponte, comme la boule de la proue.
;
; LA BOUFFEE DE VENTRE N'EST PLUS UN OBJET (28/08/2026) : elle arme un slot du
; manager, qui la dessine en quatre tranches depuis sa propre page. Ce qui
; reste ici est le geste d'armement — voir reactor/flamemgr.asm.
;*******************************************************************************

        INCLUDE "src/enemies/warship-elements/reactor/flame.equ"

;--- LES FLAMMES GEANTES DE LA QUEUE -------------------------------------------
; Cycle de 112 trames (cc73) : les seize premieres jouent les CERCLES
; D'AMORCAGE au port, les suivantes les flammes proprement dites, dont les deux
; couches alternent au bit 2 du compteur.
rflame.mapX     equ ext_variables      ; 0,1
rflame.y0       equ ext_variables+2    ; 2,3
rflame.cam0     equ ext_variables+4    ; 4,5
rflame.life     equ ext_variables+6    ; 6

rflame.LIFE     equ 112
rflame.STARTUP  equ 96                 ; au-dessus : les cercles

rflame.Object
        lda   routine,u
        asla
        ldx   #rflame.Routines
        jmp   [a,x]
rflame.Routines
        fdb   rflame.Init
        fdb   rflame.Live
        fdb   rflame.Deleted

rflame.Init
        jsr   layer.evenX
        std   rflame.mapX,u
        ldd   x_pos,u
        subd  glb_camera_x_pos
        addd  rflame.mapX,u
        std   rflame.mapX,u
        ldd   y_pos,u
        std   rflame.y0,u
        ldd   mscroll.camera.y
        std   rflame.cam0,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldb   #4
        stb   priority,u
        lda   #rflame.LIFE
        sta   rflame.life,u
        inc   routine,u

rflame.Live
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   layer.drop
        jsr   layer.evenX
        pshs  d
        ldd   rflame.mapX,u
        subd  ,s++
        addd  glb_camera_x_pos
        std   x_pos,u
        ldd   rflame.y0,u
        ldx   rflame.cam0,u
        jsr   layer.followY
        std   y_pos,u
        lda   rflame.life,u
        suba  layer.drop+1
        bls   @fin
        sta   rflame.life,u
        cmpa  #rflame.STARTUP
        blo   @flamme
        ; les cercles d'amorcage : quatre poses sur les seize trames
        suba  #rflame.STARTUP
        lsra
        lsra
        anda  #3
        asla
        ldx   #rflame.Startup
        ldx   a,x
        stx   image_set,u
        jmp   DisplaySprite
@flamme ; les flammes : deux couches qui alternent au bit 2 (cf00)
        anda  #4
        beq   >
        ldx   #set_reactor_flame_1_0
        bra   @pose
!       ldx   #set_reactor_flame_0_0
@pose   stx   image_set,u
        jmp   DisplaySprite
@fin    lda   #2
        sta   routine,u
        jmp   DeleteObject
rflame.Deleted
        rts

rflame.Startup
        fdb   set_reactor_startup_0,set_reactor_startup_1
        fdb   set_reactor_startup_2,set_reactor_startup_3

;--- LA BOUFFEE D'UN REACTEUR DE VENTRE ----------------------------------------
; Dix poses jouees une fois, orientees comme le reacteur qui l'a lachee : les
; orientations 0-1 crachent droit vers le bas, 2-3 vers la droite, 4-5 vers la
; gauche (le meme decoupage que la table de directions).
; flamemgr.Arm — armer une gerbe. Cote CAST : c'est le reacteur qui appelle,
; et il ne peut pas entrer dans la page du manager. Il ecrit donc dans la table
; RESIDENTE (reactor/flameslots.asm), et fait naitre le manager au premier
; armement. Entree : A = zone (0 bas, 1 droite, 2 gauche), D n'est pas libre —
; X = x_pos playfield de la gerbe, Y = y_pos.
; Silencieuse si la table est pleine, comme l'arcade quand son pool l'est.
flamemgr.Arm
        pshs  a,x,y
        ; LE MANAGER D'ABORD. S'il n'est pas la et que le pool le refuse, on
        ; n'arme rien : un slot arme que personne ne fait vieillir resterait
        ; occupe pour toujours, et la table se remplirait definitivement.
        tst   flamemgr.live
        bne   @vivant
        jsr   LoadObject_x
        beq   @plein
        lda   #ObjID_warship_flamemgr
        sta   id,x
        clr   routine,x
        inc   flamemgr.live
@vivant
        ldx   #flamemgr.Slots
        ldb   #flamemgr.SLOTS
@cherche
        lda   ,x
        beq   @libre
        leax  flamemgr.SLOTSZ,x
        decb
        bne   @cherche
        puls  a,x,y,pc
@libre  lda   #flamemgr.LIFE
        sta   ,x
        lda   ,s                       ; la zone
        sta   1,x
        ; l'ancrage a la couche, le meme que toutes les pieces du vaisseau :
        ; abscisse en repere de couche, et le couple (ecran, camera.y) pour
        ; l'ordonnee — voir warship-elements/layer.asm.
        jsr   layer.evenX
        pshs  d
        ldd   3,s                      ; X empile = x_pos playfield
        subd  glb_camera_x_pos
        addd  ,s++
        std   2,x
        ldd   3,s                      ; Y empile = y_pos
        std   4,x
        ldd   mscroll.camera.y
        std   6,x
@plein  puls  a,x,y,pc

;--- LA BALLE BLANCHE ----------------------------------------------------------
; Un tir ennemi ordinaire : vitesse figee a la ponte, quatre poses qui tournent,
; le decor l'arrete. Elle ne suit PAS la couche (elle s'en detache).
wbullet.AABB    equ ext_variables      ; 0..8
wbullet.anim    equ ext_variables+9    ; 9

wbullet.Object
        lda   routine,u
        asla
        ldx   #wbullet.Routines
        jmp   [a,x]
wbullet.Routines
        fdb   wbullet.Init
        fdb   wbullet.Live
        fdb   wbullet.Deleted

wbullet.Init
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldb   #4
        stb   priority,u
        _Collision_AddAABB wbullet.AABB,AABB_list_foefire
        lda   #1
        sta   wbullet.AABB+AABB.p,u
        _ldd  2,3
        std   wbullet.AABB+AABB.rx,u
        clr   wbullet.anim,u
        inc   routine,u

wbullet.Live
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
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   wbullet.AABB+AABB.cx,u
        cmpd  #159
        lbhi  wbullet.Vanish
        ldd   y_pos,u
        stb   wbullet.AABB+AABB.cy,u
        addd  #6
        cmpd  #204+6
        lbhi  wbullet.Vanish
        lda   wbullet.anim,u
        adda  layer.drop+1
        sta   wbullet.anim,u
        lsra
        lsra
        anda  #3
        asla
        ldx   #wbullet.Sets
        ldx   a,x
        stx   image_set,u
        jmp   DisplaySprite

wbullet.Vanish
        lda   #2
        sta   routine,u
        _Collision_RemoveAABB wbullet.AABB,AABB_list_foefire
        jmp   DeleteObject
wbullet.Deleted
        rts

wbullet.Sets
        fdb   set_reactor_white_bullet_0,set_reactor_white_bullet_1
        fdb   set_reactor_white_bullet_2,set_reactor_white_bullet_3
