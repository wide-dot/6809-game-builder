;*******************************************************************************
; Les REACTEURS du vaisseau (stage 3) — celui de queue, et les quatre du ventre
;
; FICHE DE PORTAGE (base Ghidra `maincpu`, subsystem warship)
; -------------------------------------------------------------------------
;   40:cbef create_rear_reactor   40:cc1b son tick   40:cee6 ses flammes
;   40:cf6c/cf7c/cf8c les trois events  40:cf9c la balle blanche
;   40:d8b7..d8de les quatre vignettes de ventre  40:d8e8 leur init
;   40:d90e leur tick  40:dac8/db02 leur bouffee
;   1000:7e56 le script d'orientation  7e9a les directions  tables.asm
;
; LE REACTEUR DE QUEUE est la premiere piece de tout le combat (entree 0 du
; script de spawn). Son corps encaisse 20 PV et orchestre un CYCLE DE 256
; TRAMES : a chaque tour il lache sa bouffee d'ejection — les flammes geantes,
; un enfant a duree de vie — et, trois fois par tour de 64 trames, une BALLE
; BLANCHE. Les trois balles partent avec des vecteurs differents (vers le bas,
; vers le haut, tout droit et deux fois plus vite) : l'arcade couvre ainsi
; trois hauteurs de passage.
;
; LES QUATRE REACTEURS DE VENTRE sont l'inverse : aucune initiative propre,
; ils suivent un SCRIPT D'ORIENTATION commun (1000:7e56) qui leur dit, a des
; seuils absolus, vers ou pointer et quand lacher une bouffee. Ils naissent a
; des instants differents mais doivent tourner ENSEMBLE — d'ou la reference
; commune : l'age du MAITRE, que le spawner depose dans chaque piece a sa
; naissance (warship.age0). C'est la seule facon de recaler une choregraphie
; absolue sur une piece nee en cours de route.
;
; ECARTS v2 : position dans le repere de la couche (layer.asm) ; pas de sons ;
; pas de clignotement de coup ; l'epave de remplacement d'un reacteur de
; ventre (la cascade c9a0..c9c4) attend la tranche 3, comme celle des
; sous-parties — le reacteur meurt en explosion et laisse la coque intacte.
;*******************************************************************************

;===============================================================================
; LE REACTEUR DE QUEUE
;===============================================================================
rreactor.AABB   equ ext_variables      ; 0..8
rreactor.mapX   equ ext_variables+9    ; 9,10
rreactor.y0     equ ext_variables+11   ; 11,12
rreactor.cam0   equ ext_variables+13   ; 13,14
rreactor.cycle  equ ext_variables+15   ; 15  le compteur de cycle (256)

rreactor.HP     equ 20                 ; 40:cbf3 : 20 PV (250 au second tour)

; react.Show — INSCRIRE une piece du groupe chez le manager des pieces
; mobiles (wsmgr.asm), qui la dessine par tranches de 16x12 au fond.
; X = la liste des tranches de la pose (reactor/slices.asm), A = x et B = y
; ecran 0-base — ceux de la boite pour les pieces qui en ont une. La page des
; descripteurs est celle du groupe, Img_Page_Index de son identifiant.
react.Show
        pshs  a
        lda   Img_Page_Index+ObjID_warship_react
        sta   wsmgr.page
        puls  a
        jmp   wsmgr.Draw

rreactor.Object
        lda   routine,u
        asla
        ldx   #rreactor.Routines
        jmp   [a,x]
rreactor.Routines
        fdb   rreactor.Init
        fdb   rreactor.Live
        fdb   rreactor.Deleted

rreactor.Init
        jsr   layer.evenX
        std   rreactor.mapX,u
        ldd   x_pos,u
        subd  glb_camera_x_pos
        addd  rreactor.mapX,u
        std   rreactor.mapX,u
        ldd   y_pos,u
        std   rreactor.y0,u
        ldd   mscroll.camera.y
        std   rreactor.cam0,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldb   #8                       ; PRIORITE DE FOND (09/09/2026, decision auteur) :
                                       ; les pieces mobiles du vaisseau derriere tout autre sprite
        stb   priority,u
        _Collision_AddAABB rreactor.AABB,AABB_list_ennemy
        lda   #rreactor.HP
        sta   rreactor.AABB+AABB.p,u
        ldd   #rreactor.BODYBOX
        std   rreactor.AABB+AABB.rx,u
        clr   rreactor.cycle,u
        inc   routine,u

rreactor.Live
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   layer.drop
        lda   rreactor.AABB+AABB.p,u
        lbeq  rreactor.Boom

        jsr   layer.evenX
        pshs  d
        ldd   rreactor.mapX,u
        subd  ,s++
        addd  glb_camera_x_pos
        std   x_pos,u
        ldd   rreactor.y0,u
        ldx   rreactor.cam0,u
        jsr   layer.followY
        std   y_pos,u

        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   rreactor.AABB+AABB.cx,u
        cmpd  #layer.XGONE
        lbhi  rreactor.Vanish
        ldd   y_pos,u
        stb   rreactor.AABB+AABB.cy,u
        addd  #6
        cmpd  #204+6
        lbhi  rreactor.Vanish

        ; --- le cycle de 256 trames et ses quatre declencheurs ---------------
        ; L'arcade teste `(compteur + k) mod 64 == 0` a trois valeurs de k, et
        ; le tour complet a l'enroulement de l'octet. Avec la compensation de
        ; trame le compteur SAUTE : on FRANCHIT les seuils au lieu de les
        ; atteindre, comme la ponte du brood.
        lda   rreactor.cycle,u
        sta   rreactor.was
        adda  layer.drop+1
        sta   rreactor.cycle,u
        cmpa  rreactor.was
        bhs   >
        jsr   rreactor.Flames          ; l'octet a boucle : le tour est fini
!       ldb   #0
@evt    pshs  b
        ldx   #rreactor.Slots
        abx
        lda   ,x                       ; la phase du declencheur
        jsr   rreactor.Crossed
        bne   >
        puls  b
        pshs  b
        jsr   rreactor.Bullet
!       puls  b
        incb
        cmpb  #3
        blo   @evt
        ; PLUS DE SPRITE A LUI (09/09/2026) : 36x24, six tranches chez wsmgr.
        ; Le corps ne change jamais de pose.
        ldx   #react.sl.rear_reactor.0
        lda   rreactor.AABB+AABB.cx,u
        ldb   rreactor.AABB+AABB.cy,u
        jmp   react.Show

; A = la phase visee ; Z = 1 si elle vient d'etre franchie dans ce pas.
; Le tour de 64 peut s'enrouler dans le meme pas — d'ou les deux cas.
rreactor.Crossed
        sta   rreactor.tmp             ; la phase visee
        lda   rreactor.was
        anda  #$3F
        sta   rreactor.wm              ; le depart, dans le tour
        lda   rreactor.cycle,u
        anda  #$3F
        sta   rreactor.nm              ; l'arrivee
        cmpa  rreactor.wm
        blo   @roule
        lda   rreactor.tmp             ; pas d'enroulement : strictement entre
        cmpa  rreactor.wm
        bls   @non
        cmpa  rreactor.nm
        bhi   @non
        bra   @oui
@roule  lda   rreactor.tmp             ; enroule : au-dela du depart OU en deca
        cmpa  rreactor.wm              ; de l'arrivee
        bhi   @oui
        cmpa  rreactor.nm
        bhi   @non
@oui    orcc  #$04
        rts
@non    andcc #$FB
        rts

; B = l'index de l'evenement (0..2) : sa balle blanche
rreactor.Bullet
        pshs  b
        lda   #6
        mul                            ; six octets par entree ; le produit
        pshs  b                        ; tient dans B — le mettre a l'abri,
        ldx   #rreactor.Shots          ; `mul` rend D et un `lda` ecraserait A
        puls  b
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
        lda   #react.WBULLET
        sta   subtype,y
        ldd   ,x                       ; vx 8.8
        std   x_vel,y
        ldd   2,x                      ; vy 8.8
        std   y_vel,y
        ldb   4,x                      ; l'ecart de ponte, signe
        sex
        addd  x_pos,u
        std   x_pos,y
        ldb   5,x
        sex
        addd  y_pos,u
        std   y_pos,y
        clr   x_pos+2,y
        clr   y_pos+2,y
@rts    puls  b
        rts

; Les flammes geantes : un enfant a duree de vie, ne au bout du reacteur
rreactor.Flames
        jsr   LoadObject_x
        beq   @rts
        lda   #ObjID_warship_react
        sta   id,x
        clr   routine,x
        lda   #react.RFLAME
        sta   subtype,x
        ldd   x_pos,u
        subd  #42                      ; cc6f : 111 px arcade a gauche
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
        clr   x_pos+2,x
        clr   y_pos+2,x
@rts    rts

rreactor.Boom
        ldb   #warship_reactor_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        beq   rreactor.Vanish
        _ldd  ObjID_explosion,explosion.subtype.big.brown+explosion.sfx.turret
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
rreactor.Vanish
        lda   #2
        sta   routine,u
        _Collision_RemoveAABB rreactor.AABB,AABB_list_ennemy
        jmp   DeleteObject
rreactor.Deleted
        rts

rreactor.was    fcb 0
rreactor.tmp    fcb 0
rreactor.wm     fcb 0
rreactor.nm     fcb 0

; Les trois declencheurs : la phase du tour de 64 ou chacun tombe (l'arcade
; teste (compteur + 7 / +14 / +20) mod 64 == 0, soit 57, 50 et 44).
rreactor.Slots
        fcb   57,50,44
; Leur balle : fdb vx, vy en 8.8 puis fcb l'ecart de ponte, signe. Vecteurs
; arcade -768/+768, -768/-768 et -1536/0 — convertis par la formule de la
; table (x 0,375, y 0,75 avec inversion d'axe).
rreactor.Shots
        fdb   -288,-576
        fcb   -10,6                    ; #0 vers le BAS
        fdb   -288,576
        fcb   -9,0                     ; #1 vers le HAUT
        fdb   -576,0
        fcb   -10,0                    ; #2 tout droit, deux fois plus vite

;===============================================================================
; LES QUATRE REACTEURS DE VENTRE
;===============================================================================
breactor.AABB   equ ext_variables      ; 0..8
breactor.mapX   equ ext_variables+9    ; 9,10
breactor.y0     equ ext_variables+11   ; 11,12
breactor.cam0   equ ext_variables+13   ; 13,14
breactor.cur    equ ext_variables+15   ; 15,16 le curseur dans le script
breactor.orient equ ext_variables+17   ; 17    l'orientation courante — PAS
                                       ;       dans subtype : celui-ci porte
                                       ;       la famille du groupe
; (l'age de reference n'est pas ici : c'est warship.age0, +18, que le spawner
;  a depose a la naissance — voir spawner.asm)

; LE MOIGNON REUTILISE LE CURSEUR DE SCRIPT : les vingt octets d'extension
; sont tous pris (ext_variables_size = 20, ram.const.asm), et l'octet 20 est
; la RESERVE du moteur de sprites — y loger le compteur de bouffee le faisait
; reecrire a chaque rendu, une bouffee par rendu (vecu le 10/09/2026). Le
; script ne sert plus une fois le reacteur mort.
breactor.puffT  equ breactor.cur       ; 15    trames avant la prochaine bouffee
breactor.HP     equ 18                 ; 40:d8ec : 18 PV
breactor.STUBHP equ 10                 ; 40:da9e : le moignon en feu, 10 PV
breactor.PUFF_PERIOD equ 128           ; 40:da61 : une bouffee par 128 trames

breactor.Object
        lda   routine,u
        asla
        ldx   #breactor.Routines
        jmp   [a,x]
breactor.Routines
        fdb   breactor.Init
        fdb   breactor.Live
        fdb   breactor.Stub
        fdb   breactor.Deleted

breactor.Init
        jsr   layer.evenX
        std   breactor.mapX,u
        ldd   x_pos,u
        subd  glb_camera_x_pos
        addd  breactor.mapX,u
        std   breactor.mapX,u
        ldd   y_pos,u
        std   breactor.y0,u
        ldd   mscroll.camera.y
        std   breactor.cam0,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldb   #6
        stb   priority,u
        _Collision_AddAABB breactor.AABB,AABB_list_ennemy
        lda   #breactor.HP
        sta   breactor.AABB+AABB.p,u
        ldd   #breactor.BOX
        std   breactor.AABB+AABB.rx,u
        ldd   #breactor.script         ; le curseur, au debut du script commun
        std   breactor.cur,u
        clr   breactor.orient,u
        inc   routine,u

breactor.Live
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   layer.drop
        lda   breactor.AABB+AABB.p,u
        lbeq  breactor.Boom

        ; L'AGE DU MAITRE avance : c'est lui la reference du script, pas le
        ; notre — les quatre reacteurs naissent a des instants differents.
        ldd   warship.age0,u
        addd  layer.drop
        std   warship.age0,u
        jsr   breactor.Track           ; la couche nous porte

        ; --- le script : autant d'entrees echues que l'age en a franchies ----
        ldx   breactor.cur,u
@lit    ldd   ,x
        cmpd  #-1
        beq   @pose                    ; le script est fini : la pose tient
        cmpd  warship.age0,u
        bhi   @garde                   ; pas encore : les suivantes non plus
        lda   2,x                      ; l'orientation
        sta   breactor.orient,u
        lda   3,x                      ; l'ordre de bouffee
        beq   >
        pshs  x
        jsr   breactor.Flame
        puls  x
!       leax  4,x
        bra   @lit
@garde  stx   breactor.cur,u
@pose   lda   breactor.orient,u
        asla
        ldx   #breactor.Sets
        ldx   a,x
        stx   image_set,u
        jmp   DisplaySprite

; breactor.Track — la couche nous porte : position et boite, et la sortie du
; champ nous retire (la pile de l'appelant rendue avant).
breactor.Track
        jsr   layer.evenX
        pshs  d
        ldd   breactor.mapX,u
        subd  ,s++
        addd  glb_camera_x_pos
        std   x_pos,u
        ldd   breactor.y0,u
        ldx   breactor.cam0,u
        jsr   layer.followY
        std   y_pos,u
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   breactor.AABB+AABB.cx,u
        cmpd  #layer.XGONE
        bhi   @gone
        ldd   y_pos,u
        stb   breactor.AABB+AABB.cy,u
        addd  #6
        cmpd  #204+6
        bhi   @gone
        rts
@gone   leas  2,s
        jmp   breactor.Vanish

; La bouffee d'ejection, orientee comme nous.
breactor.Flame
        ; LA GERBE N'EST PLUS UN OBJET : elle arme un slot du manager, qui
        ; dessine les quatre tranches lui-meme (reactor/flamemgr.asm). Quatre
        ; reacteurs tirant ensemble faisaient seize objets ; ils n'en font plus
        ; aucun, et la gerbe ne se fait plus rejeter en bloc au bas de bande.
        ; ELLE NE NAIT PAS SUR LA BUSE, ELLE NAIT DEVANT : l'arcade (40:dac8)
        ; ajoute un ecart lu par ZONE d'orientation. Sans lui la gerbe est
        ; centree sur le reacteur et deborde de moitie sur la coque — c'est ce
        ; qu'on voyait le 28/08/2026.
        ldb   breactor.orient,u
        lsrb                           ; la zone : 0-1 bas, 2-3 droite,
        andb  #3                       ; 4-5 gauche
        pshs  b                        ; elle sert deux fois
        aslb
        ldy   #breactor.FlameOff
        leay  b,y
        ldb   ,y                       ; dx signe
        sex
        addd  x_pos,u
        pshs  d
        ldb   1,y                      ; dy signe
        sex
        addd  y_pos,u
        tfr   d,y
        puls  x
        lda   ,s+                      ; la zone
        jmp   flamemgr.Arm

breactor.Boom
        ldb   #warship_reactor_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        beq   >
        _ldd  ObjID_explosion,explosion.subtype.big.brown+explosion.sfx.turret
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
        ; LA PIECE D'EPAVE (40:da0a, 10/09/2026) : le reacteur mort decouvre
        ; une sous-partie de coque de plus (rang part.REACTOR0 + le sien), a
        ; (x - 12, y + [BP+0x24]) arcade — une boite de 12 PV dont la mort
        ; blitte l'epave de la zone au-dessus du reacteur (part/obj.asm).
!       jsr   LoadObject_x
        beq   breactor.ToStub
        lda   #ObjID_warship_part
        sta   id,x
        clr   routine,x
        lda   subtype,u
        lsra
        lsra
        lsra
        lsra                           ; le rang du reacteur (react.VARIANT)
        ldy   #part.ReactorDy
        ldb   a,y
        pshs  b
        adda  #part.REACTOR0
        sta   subtype,x
        ldd   x_pos,u
        addd  #part.REACTOR_DX
        std   x_pos,x
        clr   x_pos+2,x
        ldd   y_pos,u
        puls  b
        sex
        pshs  d
        ldd   y_pos,u
        addd  ,s++
        std   y_pos,x
        clr   y_pos+2,x
        ; LE MOIGNON EN FEU (40:da49) : le reacteur ne s'efface pas, il reste
        ; a sa place en socle eventre, avec 10 PV neufs dans la meme boite,
        ; une bouffee toutes les 128 trames a une phase tiree au sort, et il
        ; explose quand sa piece d'epave tombe (le bit 27+rang du bitmap des
        ; patches, pose a l'instant meme ou l'epave s'applique) ou sous les
        ; dix coups.
breactor.ToStub
        lda   #breactor.STUBHP
        sta   breactor.AABB+AABB.p,u
        jsr   RandomNumber
        andb  #breactor.PUFF_PERIOD-1
        stb   breactor.puffT,u
        lda   #2
        sta   routine,u
        rts

breactor.Stub
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   layer.drop
        lda   breactor.AABB+AABB.p,u
        lbeq  breactor.StubBoom
        lda   subtype,u                ; le bit 27+rang : octet 3, bit 3+rang
        lsra
        lsra
        lsra
        lsra
        ldb   #$08
@bit    tsta
        beq   >
        aslb
        deca
        bra   @bit
!       bitb  bship.patch.done+3
        lbne  breactor.StubBoom        ; la piece est tombee : le moignon saute
        jsr   breactor.Track
        lda   breactor.puffT,u
        suba  layer.drop+1
        bhi   >
        pshs  a
        jsr   breactor.Puff
        puls  a
        adda  #breactor.PUFF_PERIOD
!       sta   breactor.puffT,u
        ldx   #set_bottom_reactor_wreckage_0
        stx   image_set,u
        jmp   DisplaySprite

; La bouffee du moignon : la zone 3, 12 lignes sous le socle (40:da7d).
breactor.Puff
        ldb   #3*2
        ldy   #breactor.FlameOff
        leay  b,y
        ldb   ,y
        sex
        addd  x_pos,u
        pshs  d
        ldb   1,y
        sex
        addd  y_pos,u
        tfr   d,y
        puls  x
        lda   #flamemgr.PUFF
        jmp   flamemgr.Arm

breactor.StubBoom
        jsr   LoadObject_x
        beq   breactor.Vanish
        _ldd  ObjID_explosion,explosion.subtype.smallx2+explosion.sfx.turret
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
breactor.Vanish
        lda   #3
        sta   routine,u
        _Collision_RemoveAABB breactor.AABB,AABB_list_ennemy
        jmp   DeleteObject
breactor.Deleted
        rts

        INCLUDE "src/enemies/warship-elements/reactor/tables.asm"
; Les listes de tranches des gros sprites du groupe — dans la page du cast,
; la ou les pieces les designent (generees par tools/gen_warship_slices.py).
        INCLUDE "src/enemies/warship-elements/reactor/slices.asm"
