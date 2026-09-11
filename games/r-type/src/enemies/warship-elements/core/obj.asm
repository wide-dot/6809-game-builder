;*******************************************************************************
; LE NOYAU DU VAISSEAU — le boss du stage 3 — et le feu qu'il crache
;
; FICHE DE PORTAGE (base Ghidra `maincpu`, subsystem warship) :
; doc/analyse-boss-stage3-2026-09.md
;   40:dcc0 la creation (PV 20)         40:dce6 ferme, dormant (1536 trames)
;   40:dd25 glisse (+1/-1 px, 36)       40:dd8a s'ouvre (8 poses, 63)
;   40:ddf4 OUVERT, vulnerable (128)    40:df44 se ferme (63)
;   40:df85 le recul                    40:df95 pompe et crache (63)
;   40:de61 la mort                     40:dec9 la cascade (1000:80ce)
;   40:e00f / e060 le feu               1000:81ca, 81d2, 81f2 les boites
;
; UN CYCLE : ferme 1536 trames, puis il glisse de 13 px vers la droite (36),
; s'ouvre (63), reste OUVERT 128 trames — le seul moment ou les tirs comptent —
; se referme (63), recule de 13 px (36), pompe et crache du feu (63), et
; recommence a glisser. Hors phase ouverte la boite est INVINCIBLE (p < 0) :
; le tir touche et meurt, le noyau n'en garde rien — l'arcade sauve et
; restaure damage_taken autour de sa collision. 20 PV, 10 000 points.
;
; SA MORT finit le stage : globals.bossDefeated (le geste du gomander, et du
; pilote en fin de script), la cascade commune bosscascade (table generee,
; core/explosions.asm, slot ObjID_bosscascade), une explosion sur lui.
;
; ECARTS ASSUMES (09/09/2026) :
;  - le flash de coup arcade est un echange de palette (0x39 -> 0x55, six
;    trames, une trame sur deux) : ici la pose ouverte existe en DEUX jeux,
;    convertis chacun sous sa palette arcade (core_open, core_open_flash), et
;    le noyau alterne entre les deux pendant ces six trames ;
;  - a la mort, l'arcade n'efface RIEN : la boucle de 256 cases (c544/de86)
;    abat la PRIORITE des cases de la bande du noyau (mot d'attribut AND $F),
;    ce qui fait passer le noyau et ses explosions DEVANT la coque — relu le
;    10/09/2026 ; ici le noyau est un sprite au-dessus de la couche, il n'y a
;    rien a faire. La coque, elle, se detruit zone par zone : part.Wreck ;
;  - difficulte fixe (politique v1) : 128 trames ouvert, un feu par 8 trames ;
;  - le feu n'a pas de son de lancement (0x5d, sans equivalent v2) ;
;  - le feu choisit son image par l'identite du slot objet (e06c) : ici un
;    compteur tournant, meme diversite.
;
; LA COLLISION JOUEUR suit l'arcade (dd51 v2 / de2b v3_skip_player) : hors
; phase ouverte le noyau est dans la liste ennemie — il tue le joueur au
; contact et absorbe les tirs ; en phase ouverte il passe dans la liste des
; POINTS FAIBLES (AABB_list_target), que seules les armes rencontrent.
;
; IL EST DESSINE PAR LE MANAGER DE TRANCHES (wsmgr) au rang du fond, comme les
; autres gros sprites mobiles : 24x24, quatre tranches par pose
; (core/slices.asm), page imgCore, l'ancre est le centre de sa boite.
;
; SOUS LA COQUE PAR DES POSES ROGNEES (decision auteur, 11/09/2026 —
; doc/etude-noyau-sans-cache-2026-09.md). L'arcade dessine le noyau DERRIERE
; le plan de tuiles : au repos il remplit exactement sa cavite, et sa glissade
; le fait passer SOUS la masse de coque de droite. Notre couche est peinte
; avant les sprites ; jusqu'au 10/09 un morceau de coque (core-cover, six
; tranches, ~3 100 cycles par rendu) etait repeint par-dessus lui. Desormais
; la coque est retiree DES POSES (tools/gen_core_clip.py) : la glissade montre
; la pose fermee 0 rognee a chaque ecart pair (core.SlideSets), et les poses
; glissees — ouverture, ouvert, flash de coup — n'ont que leurs dix colonnes
; visibles. Rien n'est repeint, et l'ouverture, dont l'oeil est sous la
; coque, se reduit a six tranches distinctes pour huit poses.
;*******************************************************************************
        INCLUDE "src/enemies/warship-elements/core/clip.equ"

core.AABB   equ ext_variables      ; 0..8
core.mapX   equ ext_variables+9    ; 9,10  l'abscisse de couche, au repos de la phase
core.y0     equ ext_variables+11   ; 11,12
core.cam0   equ ext_variables+13   ; 13,14
core.timer  equ ext_variables+15   ; 15,16 le compte de la phase, en trames
core.flash  equ ext_variables+17   ; 17    phase 4 : le flash de coup ; phase 6 : l'accumulateur de tir
core.dir    equ ext_variables+18   ; 18    phase 2 : +1 glisse a droite, -1 recule
core.hp     equ ext_variables+19   ; 19    les PV, gardes hors phase ouverte

core.CLOSED  equ 1536              ; dcc0 : 0x600 trames de dormance
core.SLIDE   equ 36                ; dce6/df85 : 0x24
core.ANIM    equ 63                ; dd72/de56 : 0x3f
core.OPEN    equ 128               ; ddd3 : 0x80 (0x40 en difficile — non retenu)
core.PUMP    equ 63                ; df95 : 0x3f
core.FIRE    equ 8                 ; dfc9 : masque 7, un feu toutes les 8 trames
; core.SLIDEPX : clip.equ (14 : l'ancre impaire de 13 etait rendue a 14)
core.FLASH   equ 2                 ; de30 : six trames de flash, une sur deux — ici DEUX
                                   ; RENDUS (un rendu compense ~7 trames : six trames
                                   ; n'en feraient pas un), le premier sous la palette
core.BOX     equ warship_core_hitbox_x*256+warship_core_hitbox_y
core.OPENBOX equ warship_core_open_hitbox_x*256+warship_core_hitbox_y
core.OPENCTR equ 4                 ; 1000:81d2 : x[-32..12], le centre RECULE de 10 px arcade

; le groupe : bit 0 du sous-type (families.equ)
boss.Object
        lda   subtype,u
        anda  #1
        lbne  corefire.Object
core.Object
        lda   routine,u
        asla
        ldx   #core.Routines
        jmp   [a,x]
core.Routines
        fdb   core.Init
        fdb   core.Closed              ; 1 ferme, dormant
        fdb   core.Slide               ; 2 glisse (s'ouvre) ou recule
        fdb   core.Opening             ; 3 l'animation d'ouverture
        fdb   core.Open                ; 4 OUVERT, vulnerable
        fdb   core.Closing             ; 5 l'animation de fermeture
        fdb   core.Pump                ; 6 ferme, pompe et crache
        fdb   core.Deleted

core.Init
        jsr   layer.evenX
        std   core.mapX,u
        ldd   x_pos,u
        subd  glb_camera_x_pos
        addd  core.mapX,u
        std   core.mapX,u
        ldd   y_pos,u
        std   core.y0,u
        ldd   mscroll.camera.y
        std   core.cam0,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldb   #8                       ; le fond, comme tout ce que wsmgr dessine
        stb   priority,u
        _Collision_AddAABB core.AABB,AABB_list_ennemy
        lda   #-1                      ; ferme : invincible, le tir meurt sur lui
        sta   core.AABB+AABB.p,u
        lda   #warship_core_hitdamage
        sta   core.hp,u
        ldd   #core.BOX
        std   core.AABB+AABB.rx,u
        ldd   #core.CLOSED
        std   core.timer,u
        clr   core.flash,u
        inc   routine,u
        ; PAS DE RTS : il vit des sa premiere trame

; --- phase 0 (dce6) : ferme, dormant --------------------------------------
core.Closed
        lbsr  core.Tick
        lbne  core.Vanish
        lbsr  core.ShowClosed
        lbsr  core.Elapse
        bne   @rts
        lda   #1                       ; dce6 : glisse a droite en s'ouvrant
        sta   core.dir,u
core.ToSlide                           ; (aussi depuis la fermeture et la pompe)
        ldd   #core.SLIDE
        std   core.timer,u
        lda   #2
        sta   routine,u
@rts    rts

; --- phase 1 (dd25) : glisse de 1 px arcade par trame, signe par dir --------
core.Slide
        lbsr  core.Tick
        lbne  core.Vanish
        ; la derive acquise : 3/8 px TO8 par trame ecoulee
        ldd   #core.SLIDE
        subd  core.timer,u             ; D = trames ecoulees (0..36)
        lda   #3
        mul                            ; D = ecoulees x 3 (<= 108, en B)
        lsrb
        lsrb
        lsrb                           ; B = la derive, 0..13
        ; LA POSE ROGNEE SUIT LE RENDU (mesure toje, 11/09/2026) : le moteur
        ; dessine une ancre impaire a la colonne paire SUIVANTE, et l'ancre de
        ; repos est paire (couche et camera paires). L'ecart dessine depuis le
        ; repos est donc la derive arrondie au pair superieur a l'aller, et
        ; SLIDEPX moins la derive arrondie au pair inferieur au retour (l'ancre
        ; courante est alors repos + SLIDEPX). La boite suit l'ecart dessine.
        tst   core.dir,u
        bmi   @recul
        incb
        andb  #$FE                     ; d = (derive + 1) & ~1
        pshs  b
        bra   >
@recul  andb  #$FE
        negb
        addb  #core.SLIDEPX            ; d = SLIDEPX - (derive & ~1)
        pshs  b
        subb  #core.SLIDEPX            ; ... rapporte a l'ancre courante
!       addb  core.AABB+AABB.cx,u
        stb   core.AABB+AABB.cx,u
        puls  b                        ; d pair, 0..SLIDEPX : l'index x 2
        ldx   #core.SlideSets
        abx
        ldx   ,x
        lbsr  core.Show
        lbsr  core.Elapse
        bne   @rts
        ; la glissade est acquise dans la couche
        ldb   #core.SLIDEPX
        lda   core.dir,u
        bpl   >
        negb
!       sex
        addd  core.mapX,u
        std   core.mapX,u
        lda   core.dir,u
        lbmi  core.ToPump              ; le recul mene a la pompe (dd77 : bit 15)
        ldd   #core.ANIM
        std   core.timer,u
        lda   #3
        sta   routine,u
@rts    rts

; --- phase 2 (dd8a) : les huit poses d'ouverture, une par 8 trames ----------
core.Opening
        lbsr  core.Tick
        lbne  core.Vanish
        ldd   #core.ANIM
        subd  core.timer,u             ; ecoulees 0..63
        lsrb
        lsrb
        andb  #%1110                   ; (ecoulees / 8) x 2
        ldx   #core.OpenSets
        abx
        ldx   ,x
        lbsr  core.Show
        lbsr  core.Elapse
        bne   @rts
        ; OUVERT (ddd3) : la boite s'elargit a gauche, les coups comptent, et
        ; seules les armes la rencontrent (de2b : v3_skip_player)
        ldd   #core.OPEN
        std   core.timer,u
        clr   core.flash,u
        _Collision_RemoveAABB core.AABB,AABB_list_ennemy
        _Collision_CleanLinksAABB core.AABB ; changer de liste : les liens vierges (macros.asm)
        lda   core.hp,u
        sta   core.AABB+AABB.p,u
        ldd   #core.OPENBOX
        std   core.AABB+AABB.rx,u
        _Collision_AddAABB core.AABB,AABB_list_target
        lda   #4
        sta   routine,u
@rts    rts

; --- phase 3 (ddf4) : OUVERT, vulnerable ------------------------------------
core.Open
        lbsr  core.Tick
        lbne  core.Vanish
        ; le centre de la boite ouverte est en retrait (81d2)
        lda   core.AABB+AABB.cx,u
        suba  #core.OPENCTR
        sta   core.AABB+AABB.cx,u
        ; les coups : la passe de collision a baisse p
        lda   core.AABB+AABB.p,u
        lble  core.Die
        cmpa  core.hp,u
        beq   >
        sta   core.hp,u                ; touche : le flash (de30)
        ldb   #core.FLASH
        stb   core.flash,u
!       lda   core.flash,u
        beq   @show
        deca                           ; un rendu de moins
        sta   core.flash,u
        anda  #1
        beq   @show
        ldx   #core.sl.core_open_flash.0 ; de16 : la palette de flash, un rendu sur deux
        bra   @draw
@show   ldx   #core.sl.core_open.0
@draw   lda   Img_Page_Index+ObjID_warship_boss
        sta   wsmgr.page
        lda   core.AABB+AABB.cx,u
        adda  #core.OPENCTR            ; l'ancre de l'image, pas le centre de la boite
        ldb   core.AABB+AABB.cy,u
        jsr   wsmgr.Draw
@count  lbsr  core.Elapse
        bne   @rts
        ; se referme (de56) : invincible a nouveau, la boite du corps, et de
        ; retour dans la liste ennemie (dd51 : v2, le joueur y est)
        _Collision_RemoveAABB core.AABB,AABB_list_target
        _Collision_CleanLinksAABB core.AABB
        lda   #-1
        sta   core.AABB+AABB.p,u
        ldd   #core.BOX
        std   core.AABB+AABB.rx,u
        _Collision_AddAABB core.AABB,AABB_list_ennemy
        ldd   #core.ANIM
        std   core.timer,u
        lda   #5
        sta   routine,u
@rts    rts

; --- phase 2 ter (df44) : les huit poses a rebours ---------------------------
core.Closing
        lbsr  core.Tick
        lbne  core.Vanish
        ldb   core.timer+1,u           ; 63..1 -> poses 7..0
        lsrb
        lsrb
        andb  #%1110
        ldx   #core.OpenSets
        abx
        ldx   ,x
        lbsr  core.Show
        lbsr  core.Elapse
        bne   @rts
        lda   #-1                      ; df85 : recule, et la branche « pompe »
        sta   core.dir,u
        lbra  core.ToSlide
@rts    rts

core.ToPump
        ldd   #core.PUMP
        std   core.timer,u
        clr   core.flash,u             ; l'accumulateur de tir
        lda   #6
        sta   routine,u
        rts

; --- phase 2 bis (df95) : ferme, pompe, un feu toutes les 8 trames ----------
core.Pump
        lbsr  core.Tick
        lbne  core.Vanish
        lbsr  core.ShowClosed
        lda   core.flash,u
        adda  layer.drop+1
@tire   cmpa  #core.FIRE
        blo   @garde
        suba  #core.FIRE
        pshs  a
        lbsr  core.Fire
        puls  a
        bra   @tire
@garde  sta   core.flash,u
        lbsr  core.Elapse
        bne   @rts
        lda   #1                       ; dff1 : la prochaine glissade ouvre
        sta   core.dir,u
        lbra  core.ToSlide
@rts    rts

; --- les services -----------------------------------------------------------
; core.Tick — la trame : compensation, la couche, la boite. Z=1 si le noyau
; est dans la fenetre, Z=0 s'il est parti (la borne des pieces, layer.XGONE).
core.Tick
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   layer.drop
        jsr   layer.evenX
        pshs  d
        ldd   core.mapX,u
        subd  ,s++
        addd  glb_camera_x_pos
        std   x_pos,u
        ldd   core.y0,u
        ldx   core.cam0,u
        jsr   layer.followY
        std   y_pos,u
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   core.AABB+AABB.cx,u
        cmpd  #layer.XGONE
        bhi   @part
        ldd   y_pos,u
        stb   core.AABB+AABB.cy,u
        addd  #6
        cmpd  #204+6
        bhi   @part
        orcc  #$04
        rts
@part   andcc #$FB
        rts

; core.Elapse — le compte de la phase descend des trames ecoulees. Z=1 echu.
core.Elapse
        ldd   core.timer,u
        subd  layer.drop
        ble   @echu
        std   core.timer,u
        andcc #$FB
        rts
@echu   ldd   #0
        std   core.timer,u
        orcc  #$04
        rts

; core.Show — X = la liste des tranches de la pose, a l'ancre de la boite
core.Show
        lda   Img_Page_Index+ObjID_warship_boss
        sta   wsmgr.page
        lda   core.AABB+AABB.cx,u
        ldb   core.AABB+AABB.cy,u
        jmp   wsmgr.Draw

; core.ShowClosed — les quatre poses fermees, une par 8 trames de jeu
; (dce6 : compteur & 0x18)
core.ShowClosed
        ldb   gfxlock.frame.gameCount+1
        lsrb
        lsrb
        andb  #%110
        ldx   #core.ClosedSets
        abx
        ldx   ,x
        bra   core.Show

; core.Fire (e00f) — un feu, vitesse au hasard, lance vers le HAUT (l'axe
; arcade monte : vy 0x280..0x47f positif = 2,5 a 4,5 px/trame en montant)
core.Fire
        jsr   LoadObject_x
        beq   @rts
        lda   #ObjID_warship_boss
        sta   id,x
        clr   routine,x
        lda   #boss.FIRE
        sta   subtype,x
        ldd   x_pos,u
        subd  #4                       ; e02c : -10 arcade
        std   x_pos,x
        ldd   y_pos,u
        subd  #12                      ; e033 : +16 arcade, 12 px au-dessus
        std   y_pos,x
        clr   x_pos+2,x
        clr   y_pos+2,x
        jsr   RandomNumber             ; D au hasard
        pshs  a,b
        ; vx : +-(0x80..0x17f) arcade -> +-(48..144) en 8.8 : 48 + r x 3/8
        ldb   ,s
        lda   #3
        mul
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        addd  #48
        std   x_vel,x
        lda   1,s
        anda  #$20                     ; e047 : random & 0x20 -> vers la gauche
        beq   >
        ldd   #0
        subd  x_vel,x
        std   x_vel,x
!       ; vy : 0x280 + (r & 0x1ff) arcade, x 0,75 -> 480 + r9 x 3/4, vers le haut
        ldd   ,s
        anda  #1
        std   layer.tmp
        aslb
        rola
        addd  layer.tmp                ; r9 x 3
        lsra
        rorb
        lsra
        rorb                           ; / 4
        addd  #480
        coma
        comb
        addd  #1                       ; l'ecran descend : negatif
        std   y_vel,x
        puls  a,b
        ; la variante d'image : un compteur tournant (l'arcade : le slot)
        lda   core.fireVar
        inca
        sta   core.fireVar
        anda  #3
        sta   corefire.var,x
@rts    rts

; --- la mort (de61) ----------------------------------------------------------
core.Die
        ldb   #warship_core_scoreIdx   ; de7b : 0x871c = index 13, 10 000 points
        jsr   AwardScore
        lda   #1
        sta   globals.bossDefeated     ; de73 : le maitre enchaine sur la fin
        ; la cascade (dea2) : l'enfant commun, a la position du noyau, +4 arcade
        jsr   LoadObject_x
        beq   >
        lda   #ObjID_bosscascade
        sta   id,x
        clr   routine,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        subd  #3
        std   y_pos,x
!       ; le noyau lui-meme explose (dec3 : e7b6, SFX 0x53)
        jsr   LoadObject_x
        beq   core.Vanish
        _ldd  ObjID_explosion,explosion.subtype.smallx3+explosion.sfx.big
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
core.Vanish
        lda   routine,u
        cmpa  #4                       ; ouvert : la boite est chez les points faibles
        beq   >
        _Collision_RemoveAABB core.AABB,AABB_list_ennemy
        bra   @gone
!       _Collision_RemoveAABB core.AABB,AABB_list_target
@gone   lda   #7
        sta   routine,u
        jmp   DeleteObject
core.Deleted
        rts

core.fireVar    fcb 0

core.ClosedSets                        ; 1000:812e : les quatre poses fermees
        fdb   core.sl.core_closed.0,core.sl.core_closed.1
        fdb   core.sl.core_closed.2,core.sl.core_closed.3
core.SlideSets                         ; l'ecart dessine d = 0, 2, .., SLIDEPX : la pose
        fdb   core.sl.core_closed.0    ;  fermee 0 rognee de d (gen_core_clip.py)
        fdb   core.sl.core_closed.4,core.sl.core_closed.5,core.sl.core_closed.6
        fdb   core.sl.core_closed.7,core.sl.core_closed.8,core.sl.core_closed.9
        fdb   core.sl.core_closed.10
core.OpenSets                          ; 1000:815e : les huit poses d'ouverture
        fdb   core.sl.core_opening.0,core.sl.core_opening.1
        fdb   core.sl.core_opening.2,core.sl.core_opening.3
        fdb   core.sl.core_opening.4,core.sl.core_opening.5
        fdb   core.sl.core_opening.6,core.sl.core_opening.7

        INCLUDE "src/enemies/warship-elements/core/slices.asm"

;*******************************************************************************
; LE FEU DU NOYAU (40:e060) : une fontaine — lance vers le haut, freine de
; 1/16 px arcade par trame, retombe sur la coque ou sur le joueur. Un point
; de degat, le decor l'arrete (les deux plans, comme la boule de feu), une
; petite explosion a l'impact (e0c3 : SFX 0x50, e7ae).
;*******************************************************************************
corefire.AABB   equ ext_variables      ; 0..8 — la liste des tirs ennemis
corefire.var    equ ext_variables+9    ; 9    la variante d'image

corefire.GRAVITY equ 12                ; e0a2 : 0x10 arcade par trame, x 0,75 -> 12 en 8.8
corefire.BOX     equ warship_corefire_hitbox_x*256+warship_corefire_hitbox_y

corefire.Object
        lda   routine,u
        asla
        ldx   #corefire.Routines
        jmp   [a,x]
corefire.Routines
        fdb   corefire.Init
        fdb   corefire.Live
        fdb   corefire.Deleted

corefire.Init
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldb   #4
        stb   priority,u
        _Collision_AddAABB corefire.AABB,AABB_list_foefire
        lda   #warship_corefire_hitdamage
        sta   corefire.AABB+AABB.p,u
        ldd   #corefire.BOX
        std   corefire.AABB+AABB.rx,u
        inc   routine,u
        ; PAS DE RTS : il vole des sa premiere trame

corefire.Live
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   layer.drop
        lda   corefire.AABB+AABB.p,u   ; le joueur l'a pris (e0a0) : il eclate
        beq   @mur
        ; la gravite (e0a2) : 12/256 px par trame, vers le bas
        ldb   layer.drop+1
        lda   #corefire.GRAVITY
        mul
        addd  y_vel,u
        std   y_vel,u
        ldd   x_vel,u
        leax  x_pos,u
        jsr   layer.AddPos
        ldd   y_vel,u
        leax  y_pos,u
        jsr   layer.AddPos
        ; la fenetre
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   corefire.AABB+AABB.cx,u
        cmpd  #159
        lbhi  corefire.Vanish
        ldd   y_pos,u
        stb   corefire.AABB+AABB.cy,u
        addd  #6
        cmpd  #204+6
        lbhi  corefire.Vanish
        ; le decor l'arrete (e087) — les deux plans, comme la boule de feu
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
@mur    ; e0c3 : une petite explosion
        jsr   LoadObject_x
        beq   corefire.Vanish
        _ldd  ObjID_explosion,explosion.subtype.smallx2+explosion.sfx.small
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
        bra   corefire.Vanish
@vole   ldb   corefire.var,u
        aslb
        ldx   #corefire.Sets
        abx
        ldx   ,x
        stx   image_set,u
        jmp   DisplaySprite

corefire.Vanish
        lda   #2
        sta   routine,u
        _Collision_RemoveAABB corefire.AABB,AABB_list_foefire
        jmp   DeleteObject
corefire.Deleted
        rts

corefire.Sets                          ; 1000:81da : les quatre variantes
        fdb   set_core_fire_0,set_core_fire_1,set_core_fire_2,set_core_fire_3
