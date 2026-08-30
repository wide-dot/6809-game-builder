;*******************************************************************************
; LE MANAGER DES TIRS ENNEMIS — un objet pour toutes les balles du jeu
;
; POURQUOI. Une balle coutait un SLOT D'OST ENTIER (117 octets) et, a chaque
; trame, un dispatch d'objet complet, un decodage d'imageset complet et DEUX A
; TROIS MONTAGES DE PAGE — l'enveloppe, pas le dessin. Sur un sprite de 8x8
; l'enveloppe pese proportionnellement enorme, et c'est ce qui rend le cas
; favorable. Analyse et mesures : doc/analyse-bullet-manager.md.
;
; LE POINT DE BASCULE EST UNIQUE. Les neuf familles d'ennemis qui tirent
; passent toutes par `tryFoeFire` (resident), qui appelle `createFoeFire`.
; Celui-ci arme desormais un slot au lieu d'allouer un OST : AUCUN code
; d'ennemi ne change.
;
; L'IDENTIFIANT NE CHANGE PAS NON PLUS. `foefire.Object` designe ce manager, et
; ObjID_foefire (13) est son identifiant : les neuf tables d'index de stage
; pointent deja le bon symbole et la bonne page, il n'y a rien a renumeroter.
;
; TOUT VIT DANS UNE SEULE PAGE — la table, `createFoeFire`, le manager, son
; dessin et ses images. C'est la condition qui supprime les montages :
; BuildSprites monte la page d'images de l'objet avant d'appeler sa routine de
; dessin, et `tryFoeFire` monte la meme page pour appeler `createFoeFire`.
; Aucun octet resident n'est necessaire, et rien ici n'appelle une autre page.
;
; LES COLLISIONS RESTENT CELLES DU MOTEUR. `Collision_AddAABB` lie de la
; MEMOIRE QUELCONQUE, pas forcement un OST, et `Collision_Do` ne lit ni n'ecrit
; que la structure AABB — jamais l'objet derriere. Le manager possede donc ses
; boites dans sa table et les inscrit dans `AABB_list_foefire` exactement comme
; avant : le joueur encaisse, et le force pod arrete les tirs, sans qu'une
; ligne de moteur soit reecrite ni qu'une regle soit reimplementee.
;
; L'ANIMATION EST PARTAGEE (decision auteur). Chaque balle portait SA phase,
; incrementee et masquee a chaque trame. Or les balles sont LE MEME SPRITE :
; deux phases differentes ne se distinguent pas a l'oeil, personne ne peut dire
; en regardant l'ecran si le cycle est commun. C'etait de l'etat sans
; signification observable. Un seul compteur, la meme pose pour toutes : par
; balle et par trame, cela retire un `inc`, un `andb`, un `stb`, une lecture de
; table et un `std image_set` — et cela ne charge plus qu'UNE adresse de
; routine compilee pour tout le lot.
;
; ECART ASSUME : les balles perdent leurs variantes pre-decalees (`shifts=0,1`)
; et avancent donc par pas de 2 px a l'horizontale, comme les gerbes des
; reacteurs. C'est ce qui permet de blitter par `adr_*_ND0` sans rejouer le
; choix de variante du moteur. A valider a l'ecran ; le retour en arriere est
; local (une seconde table de routines et un test de parite).
;*******************************************************************************

        INCLUDE "src/enemies/_shared/bullets/bullets.equ"

;-------------------------------------------------------------------------------
; LA TABLE — un slot par balle, dans la page du manager
;
; +0  AABB    9  la boite du moteur : p, rx, ry, cx, cy, prev, next
; +9  used    1  slot occupe (0 = libre)
; +10 delay   1  trames restantes avant que la balle se montre
; +11 x       3  position playfield 16.8
; +14 y       3
; +17 vx      2  vitesse 8.8 signee
; +19 vy      2
;-------------------------------------------------------------------------------
; Les offsets de slot et les ancres residentes vivent dans bullets.equ :
; le rechargement de checkpoint (stage-main) en a besoin autant que nous.

; La table, le battement et le temps mort sont RESIDENTS — bullets.equ dit
; pourquoi, et le rechargement de checkpoint (stage-main) les remet a neuf.
; bullet.beat / bullet.idle : RESIDENTS, voir bullets.equ.
bullet.frame    fcb 0                  ; LE compteur d'animation, partage
bullet.di       fcb 0                  ; le parcours du TICK
bullet.sp       fdb 0
bullet.dj       fcb 0                  ; celui du DESSIN — SEPARE : deux
bullet.dp       fdb 0                  ; parcours qui partagent leur compteur
                                       ; sont un depassement de table en
                                       ; puissance, et un depassement ici ecrit
                                       ; par-dessus les variables qui suivent —
                                       ; dont la POSE, que le dessin appelle
bullet.drop     fdb 0
bullet.tmp      fdb 0
bullet.pose     fdb 0                  ; la routine compilee de la trame

;*******************************************************************************
; L'ARMEMENT — appele par createFoeFire, dans cette page
;
; Entree : X = le slot n'est pas encore choisi ; D = x playfield, Y = y
; playfield, et les vitesses dans bullet.tmp*. Voir createFoeFire, qui est
; l'unique appelant et prepare tout.
; Sortie : C=0 si la table etait pleine (l'arcade ne tire pas non plus quand
; son pool est plein).
;*******************************************************************************
bullet.Reset
        ; Slots libres, boites sans potentiel ni liens, temps mort a zero, une
        ; pose valide avant le premier tick (BuildSprites peut nous appeler des
        ; cette trame). Les tetes de liste appartiennent au moteur : c'est
        ; Collision_ClearLists qui les vide, avec la table — ici on ne remet a
        ; neuf que NOTRE etat, pour la renaissance en cours de partie.
        ldx   #bullet.Slots
        ldb   #bullet.SLOTS
!       clr   bullet.used,x
        clr   bullet.AABB+AABB.p,x
        clr   bullet.AABB+AABB.prev,x
        clr   bullet.AABB+AABB.prev+1,x
        clr   bullet.AABB+AABB.next,x
        clr   bullet.AABB+AABB.next+1,x
        leax  bullet.SLOTSZ,x
        decb
        bne   <
        clr   bullet.idle
        ldd   bullet.Poses
        std   bullet.pose
        rts

bullet.Arm
        ; LES PARAMETRES SE METTENT A L'ABRI TOUT DE SUITE. Ni D ni Y ne
        ; survivent a ce qui suit : le test de battement lit une horloge dans
        ; D, et la recherche de slot compte dans B. La premiere version les
        ; laissait a decouvert — les balles naissaient donc a une abscisse
        ; aberrante et mouraient au test de fenetre des leur premiere trame
        ; (29/08/2026). C'est la meme etourderie que le `mul` de la tourelle de
        ; proue : un registre qu'on croit tenir et qu'une routine intermediaire
        ; a repris.
        pshs  d,y
        ; LE MANAGER D'ABORD : un slot arme que personne ne ferait vivre
        ; resterait occupe pour toujours. Meme precaution que les gerbes.
        ;
        ; PAS UN SIMPLE DRAPEAU, pose ici et efface par le manager quand il se
        ; retire : les deux gestes tombent dans la MEME passe de RunObjects des
        ; que la derniere balle meurt, et il naissait alors des managers EN
        ; CASCADE — jusqu'a six tours dans une seule trame de jeu, donc des
        ; balles six fois trop rapides. Le manager DATE son passage, et cette
        ; date fait foi : elle survit a son retrait, a une purge d'objets et a
        ; un changement de stage.
        ldd   bullet.beat              ; le sentinel « mort » court-circuite
        cmpd  #bullet.DEAD             ; l'arithmetique : voir bullets.equ
        beq   @naitre
        ldd   gfxlock.frame.count
        subd  bullet.beat
        cmpd  #bullet.BEAT
        bls   @vivant
@naitre jsr   LoadObject_x
        beq   @plein
        lda   #ObjID_foefire
        sta   id,x
        clr   routine,x
        ldd   gfxlock.frame.count      ; vivant des maintenant, sinon deux tirs
        std   bullet.beat              ; de la meme trame en creeraient deux
        ; LA TABLE REPART VIERGE — ICI, avant d'armer la balle de CE tir.
        ; Un wipe APRES l'armement (l'ancienne naissance differee) detruisait
        ; le slot arme en laissant sa boite chainee. L'ordre wipe-puis-arme
        ; est le contrat.
        bsr   bullet.Reset
@vivant
        ldx   #bullet.Slots
        ldb   #bullet.SLOTS
@cherche
        tst   bullet.used,x
        beq   @libre
        leax  bullet.SLOTSZ,x
        decb
        bne   @cherche
@plein  puls  d,y
        andcc #$FE                     ; table pleine : pas de tir, comme
        rts                            ; l'arcade quand son pool est plein
@libre  inc   bullet.used,x
        puls  d,y                      ; on les retrouve intacts
        std   bullet.x,x
        clr   bullet.x+2,x
        sty   bullet.y,x
        clr   bullet.y+2,x
        ; LES LIENS DE LA BOITE SE NETTOIENT AVANT L'INSERTION. Le contrat
        ; implicite de Collision_AddAABB est une boite aux liens VIERGES : il
        ; insere en queue et ne touche pas next (queue.next = X ; X.next reste
        ; tel quel). Les objets du pool l'ont gratuitement — LoadObject zere
        ; leur OST — mais un slot de cette table se REUTILISE, et RemoveAABB
        ; laisse les vieux pointeurs en place : reinsere sans nettoyage, la
        ; queue de liste pointait un maillon d'une chaine anterieure — LISTE
        ; CIRCULAIRE, et Collision_Do ne rendait plus jamais la main (gel du
        ; 29/08/2026, cycle photographie maillon par maillon).
        ldd   #0
        std   bullet.AABB+AABB.prev,x
        std   bullet.AABB+AABB.next,x
        ; la boite : meme rayon et meme potentiel que la balle-objet d'avant
        lda   #1
        sta   bullet.AABB+AABB.p,x
        _ldd  bullet.RADIUS,bullet.RADIUS
        std   bullet.AABB+AABB.rx,x
        _Collision_AddAABB_x bullet.AABB,AABB_list_foefire
        orcc  #$01
        rts

; bullet.ArmV — armer une balle A VECTEUR EXPLICITE, depuis N'IMPORTE QUELLE
; PAGE. C'est l'entree des tireurs qui ne veulent pas d'un preset de direction :
; la tourelle multiple du vaisseau tire en gerbe, chaque coup avec son propre
; vecteur. Ils l'atteignent par RunPgSubRoutine, qui monte cette page — le meme
; chemin que createFoeFire.
;   X = abscisse de ponte, Y = ordonnee, U = l'OST du tireur, qui porte le
;   vecteur dans ses champs x_vel/y_vel : neuf octets de parametres ne tiennent
;   pas dans les registres, et l'OST est resident donc lisible d'ici.
;   A n'est pas utilisable en entree : RunPgSubRoutine l'ecrase (PSR_Param).
bullet.ArmV
        tfr   x,d
        jsr   bullet.Arm
        bcc   @rts
        ldd   x_vel,u
        std   bullet.vx,x
        ldd   y_vel,u
        std   bullet.vy,x
        lda   #bullet.MULTIDELAY
        sta   bullet.delay,x
@rts    rts

;*******************************************************************************
; L'OBJET — il fait vivre les balles ; le dessin se passe dans la routine que
; BuildSprites appelle.
;*******************************************************************************
foefire.Object
        lda   routine,u
        bne   bullet.Live
        ; La premiere trame : se rendre indelogeable, comme outslay.Render.
        _GetCartPageA
        ldb   id,u
        ldx   #Img_Page_Index
        sta   b,x                      ; le moteur montera NOTRE page
        sta   bullet.FakeMf
        ldd   #bullet.FakeImg
        std   image_set,u
        clr   render_flags,u           ; coordonnees ecran, boite garee au
        lda   #120                     ; centre : jamais eliminee hors-champ
        sta   x_pixel,u
        lda   #135
        sta   y_pixel,u
        ldb   #2                       ; la priorite des balles d'avant
        stb   priority,u
        ; PAS DE REMISE A NEUF ICI. Cette naissance est DIFFEREE (RunObjects) :
        ; bullet.Arm a deja arme la balle du tir qui nous a fait naitre. Wiper
        ; la table maintenant remettait son `used` a zero en laissant sa boite
        ; chainee tete de liste — le tir suivant reutilisait le slot et
        ; reinserait la MEME boite : queue.next = elle-meme, liste circulaire,
        ; Collision_Do ne rend plus la main (gel du 30/08/2026, cam figee a
        ; 128 des la premiere salve du stage 1, coupable photographie par
        ; watchpoint sur slot0.used). La remise a neuf vit dans bullet.Reset,
        ; que Arm appelle AVANT d'armer — l'ordre est la seule chose qui
        ; compte.
        inc   routine,u
        jmp   DisplaySprite

bullet.Live
        ldd   gfxlock.frame.count      ; LE BATTEMENT — voir bullet.Arm
        cmpd  #bullet.DEAD             ; la trame du wrap ne doit pas dater
        bne   >                        ; le battement du sentinel « mort »
        subd  #1
!       std   bullet.beat
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   bullet.drop
        ; LE COMPTEUR D'ANIMATION, UNE FOIS POUR TOUTES
        lda   bullet.frame
        adda  bullet.drop+1
        sta   bullet.frame
        lsra                           ; deux trames par pose, comme avant
        anda  #3
        asla
        ldx   #bullet.Poses
        ldd   a,x
        std   bullet.pose
;
        lda   #bullet.SLOTS
        sta   bullet.di
        ldx   #bullet.Slots
        stx   bullet.sp
@slot   ldx   bullet.sp
        tst   bullet.used,x
        lbeq  @suiv
;
        ; --- la boite a-t-elle perdu son potentiel ? (force pod, joueur) -----
        tst   bullet.AABB+AABB.p,x
        lbeq  @mort
;
        ; --- le deplacement, en DEUX MUL et non en additions repetees -------
        ; L'objet d'avant ajoutait sa vitesse `frameDrop` fois dans une boucle,
        ; deux fois par balle et par trame. A la cadence mesuree du stage 3
        ; (6,6 fps de jeu reel) frameDrop vaut 7 a 8 : une quinzaine d'`addd`
        ; par balle. Les pieces du vaisseau font le meme calcul avec deux mul
        ; (layer.AddPos) — c'est cet idiome-la.
        leay  bullet.x,x
        ldd   bullet.vx,x
        lbsr  bullet.AddPos
        ldx   bullet.sp
        leay  bullet.y,x
        ldd   bullet.vy,x
        lbsr  bullet.AddPos
        ldx   bullet.sp
;
        ; --- le decor : avant-plan, et fond si le stage le declare solide ----
        ldd   bullet.x,x
        std   terrainCollision.sensor.x
        ldd   bullet.y,x
        std   terrainCollision.sensor.y
        ldb   #1
        jsr   terrainCollision.do
        tstb
        lbne  @mort
        lda   globals.backgroundSolid
        beq   @dehors
        ldx   bullet.sp
        ldd   bullet.x,x
        std   terrainCollision.sensor.x
        ldd   bullet.y,x
        std   terrainCollision.sensor.y
        ldb   #0
        jsr   terrainCollision.do
        tstb
        lbne  @mort
;
@dehors ldx   bullet.sp
        ; --- la fenetre, aux memes bornes que la balle-objet -----------------
        ldd   bullet.x,x
        cmpd  glb_camera_x_pos
        lble  @mort
        subd  #160-8/2
        cmpd  glb_camera_x_pos
        lbge  @mort
        ldd   bullet.y,x
        lble  @mort
        cmpd  #160
        lbge  @mort
;
        ; --- la boite suit la balle -----------------------------------------
        ldd   bullet.x,x
        subd  glb_camera_x_pos
        stb   bullet.AABB+AABB.cx,x
        ldb   bullet.y+1,x
        stb   bullet.AABB+AABB.cy,x
        ; --- le delai d'apparition ------------------------------------------
        lda   bullet.delay,x
        beq   @suiv
        suba  bullet.drop+1
        bhi   >
        clra
!       sta   bullet.delay,x
        bra   @suiv
@mort   ldx   bullet.sp
        clr   bullet.used,x
        clr   bullet.AABB+AABB.p,x
        _Collision_RemoveAABB_x bullet.AABB,AABB_list_foefire
@suiv   ldd   bullet.sp
        addd  #bullet.SLOTSZ
        std   bullet.sp
        dec   bullet.di
        lbne  @slot
        ; LE MANAGER NE SE RETIRE PAS. Il l'a fait, et c'etait la source de
        ; tout : se retirer sur une trame sans balle, alors qu'un ennemi peut
        ; tirer plus loin dans la MEME passe de RunObjects, faisait naitre des
        ; managers EN CASCADE — jusqu'a six tours dans une trame de jeu, donc
        ; des balles six fois trop rapides (29/08/2026). Un temps mort avant
        ; retrait n'a fait que ralentir la cascade sans la supprimer : tant
        ; qu'un retrait peut tomber entre deux tirs, la course existe.
        ; Il vit donc du premier tir du stage jusqu'a la purge. Cela coute UN
        ; slot d'OST sur soixante, la ou il en rend jusqu'a vingt-quatre.
        jmp   DisplaySprite
;
; bullet.AddPos — Y pointe un champ 24 bits (16.8), D = vitesse 8.8 signee,
; compensee de bullet.drop. Deux mul non signes, produit tronque juste en
; complement a deux — le calcul de layer.AddPos, mot pour mot.
bullet.AddPos
        pshs  a
        lda   bullet.drop+1
        mul
        std   bullet.tmp
        puls  a
        ldb   bullet.drop+1
        mul
        tfr   b,a
        clrb
        addd  bullet.tmp
        pshs  d
        ldb   ,s
        sex
        sta   @a+1
        puls  d
        addd  1,y
        std   1,y
        lda   ,y
@a      adca  #$00
        sta   ,y
        rts

;*******************************************************************************
; LE FAUX IMAGESET — c'est lui qui fait appeler notre routine par BuildSprites.
; Meme forme que celui de l'outslay et du manager des gerbes.
;*******************************************************************************
bullet.FakeImg
        fcb   bullet.FakeSub-bullet.FakeImg,bullet.FakeSub-bullet.FakeImg
        fcb   bullet.FakeSub-bullet.FakeImg,bullet.FakeSub-bullet.FakeImg
        fcb   8,8,0
bullet.FakeSub
        fcb   0
        fcb   bullet.FakeMf-bullet.FakeSub
        fcb   0
        fcb   bullet.FakeMf-bullet.FakeSub
        fcb   0,0
bullet.FakeMf
        fcb   0                        ; page, patchee a l'Init
        fdb   bullet.DrawAll

;*******************************************************************************
; LE DESSIN — appele par BuildSprites, notre page montee, sans OST sous la main
; (c'est pourquoi la table est statique). UNE SEULE POSE pour toutes les
; balles : elle a ete choisie une fois par le tick.
;*******************************************************************************
bullet.DrawAll
        lda   #bullet.SLOTS
        sta   bullet.dj
        ldx   #bullet.Slots
        stx   bullet.dp
@slot   ldx   bullet.dp
        tst   bullet.used,x
        beq   @suiv
        tst   bullet.delay,x           ; pas encore visible
        bne   @suiv
        ; l'ecran, dans le repere du moteur
        ldd   bullet.x,x
        subd  glb_camera_x_pos
        cmpd  #screen_right-screen_left
        bhi   @suiv                    ; hors bande : rien a peindre
        addb  #screen_left
        pshs  b
        ldb   bullet.y+1,x
        addb  #screen_top
        lda   ,s+
        jsr   DRS_XYToAddress           ; A = x, B = y, repere DRS
        ldu   <glb_screen_location_2
        ldy   bullet.pose
        beq   @suiv                    ; pose non encore choisie (le dessin
        jsr   ,y                       ; peut preceder le premier tick)
@suiv   ldd   bullet.dp
        addd  #bullet.SLOTSZ
        std   bullet.dp
        dec   bullet.dj
        bne   @slot
        rts
;
; Les quatre poses, dans l'ordre de la chaine d'origine. Ce sont les ROUTINES
; COMPILEES : le manager blitte en direct, il ne pose pas d'imageset.
bullet.Poses
        fdb   adr_foefire_0_ND0,adr_foefire_1_ND0
        fdb   adr_foefire_2_ND0,adr_foefire_3_ND0
