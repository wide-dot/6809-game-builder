;*******************************************************************************
; gouger — SQUELETTE, mais avec sa FICHE DE PORTAGE complete (releve 25/08/2026)
;
; L'ennemi DOMINANT du stage 2 : 29 des 34 spawns de cast. Il se tient sur le
; decor — plafond ou sol — puis plonge en diagonale vers l'intrus.
;
; FICHE DE PORTAGE (source : base Ghidra `maincpu`, subsystem enemy_gouger)
; -------------------------------------------------------------------------
;   40:6f89 create_gouger .............. le spawner
;   40:6fd0 run_gouger ................. le tick, machine a TROIS etats
;   40:7048 .... phase B, la plongee
;   40:7106 .... phase C, le recul apres un coup (0x17 = 23 trames)
;   40:70e3 .... la mort ; 40:7155 .... le retrait silencieux
;   40:7168 draw_gouger_with_hit_blink . le clignotement de coup
;   40:f9f0 load_gouger_preset ......... les quatre variantes
;   1000:9384 la table des variantes (4 x 7 mots)
;   1000:93bc la case +0x34 (4 mots)
;   1000:307e..30fe les quatre tables de poses (16 mots = 8 poses x2)
;   1000:31ee l'AABB
;
; CE QUE PORTE LE DESCRIPTEUR DE WAVE. Le 5e octet, et lui seul (le subtype
; vaut $00 sur les 29 lignes) :
;   bits 0-1 -> la VARIANTE de mouvement (load_gouger_preset, CL & 3) : d'ou il
;               part (plafond ou sol) et dans quel sens il file.
;   bits 2-3 -> le DECLENCHEUR, en +0x34 (load_motion_param_preset_4). Ses
;               quatre valeurs sont $FFFF, $0080, $0180, $0200 :
;                 $FFFF -> bit 15 arme : il plonge quand le joueur se presente
;                          dans la direction gravee en +0x36 ;
;                 sinon -> c'est un COMPTE A REBOURS en trames (128, 384, 512),
;                          decremente a chaque tour, et il plonge a zero sans
;                          se soucier du joueur.
; Les quatre variantes sont toutes employees par la wave.
;
; LES QUATRE VARIANTES, et elles tombent une a une sur nos dossiers d'images :
;
;   var  y      vx      vy     traine x  traine y  poses     images
;   ---  -----  ------  -----  --------  --------  --------  -------------
;    0   $0178  +1.500  -2.000   +0.375    -0.500  1000:30DE  top-LEFT
;    1   $0178  -1.500  -2.000   -0.375    -0.500  1000:30BE  top-RIGHT
;    2   $0098  +1.500  +2.000   +0.375    +0.500  1000:309E  bottom-LEFT
;    3   $0098  -1.500  +2.000   -0.375    +0.500  1000:307E  bottom-RIGHT
;
; ATTENTION AU NOM DES DOSSIERS : gauche et droite sont l'INVERSE de ce que le
; signe de vx laisse croire. La correspondance n'est pas deduite, elle est
; MESUREE — les fichiers sources portent l'adresse arcade de leur meta-sprite
; (000_013116.png…), et ces adresses sont exactement celles que la base de la
; variante enumere. Le nom decrit vraisemblablement le coin d'ou le gouger
; EMERGE, pas son sens de deplacement : au plafond, celui qui part vers la
; gauche arrive bien du coin haut-droit.
; Se fier au signe de vx aurait donne a chaque variante l'art d'une autre
; direction — silencieux au build, penible a l'ecran.
;
; L'axe Y arcade monte : $0178 (376) est donc le PLAFOND et $0098 (152) le
; SOL — les variantes 0 et 1 descendent (vy negatif), les 2 et 3 montent.
; X est fixe a $02D0, juste a droite de l'ecran. Les deux ordonnees sont
; RAMENEES dans le cadre chez nous, faute de decoupe : voir gouger.PresetY.
;
; LES POSES. La table d'une variante fait seize mots, mais ce sont HUIT slots
; repetes deux fois — et le cycle fait un aller-retour :
;   30FE 312E 315E 318E 315E 312E 30FE 31BE   (var 3, les autres sont
;                                              identiques a l'adresse pres)
; L'index arcade vaut (anim & 0x3C) >> 1, soit un slot toutes les QUATRE
; trames ; ramene a nos images : slot = (anim >> 2) & 7. La plongee, elle,
; force l'offset 4 — donc le SLOT 2, fixe.
;
; MAIS CES HUIT SLOTS NE FONT PAS HUIT IMAGES. L'aller-retour repasse par les
; memes poses : n'en sont importees que les DISTINCTES
; (arcade_to_sprites.py --dedup, ecrit le 25/08/2026 pour ca). Chaque dossier
; porte sa table slot -> pose dans cycle.txt :
;
;   top-right     5 poses   0 1 2 3 2 1 0 4
;   top-left      5 poses   0 1 2 3 2 1 0 4
;   bottom-right  4 poses   0 1 2 3 2 1 0 3   <- sa 8e pose est identique a la 4e
;   bottom-left   5 poses   0 1 2 3 2 1 0 4
;
; 19 sprites au lieu de 32, soit 41 % de moins, sans rien perdre.
;
; LA POSE MANQUANTE DE bottom-right VIENT DE LA ROM, pas de l'export — verifie.
; Un descripteur fait 48 octets, soit QUATRE tranches de douze, une par
; variante (d'ou les ecarts de 0x0C entre 30FE, 310A, 3116, 3122). Pour la
; variante 3, les tranches des slots 3 et 7 sont identiques octet pour octet
; (tuiles 0x0524 et 0x0530 des deux cotes), alors que les tranches des trois
; autres variantes different bien (0x0530/0x0524 contre 0x0540/0x0534). La
; donnee d'origine repete cette pose pour cette direction-la, c'est tout. La table de
; bottom-right differe d'une entree : le code objet porte donc DEUX tables, pas
; une. Verification independante : les doublons attendus depuis la table arcade
; se retrouvaient exactement dans les images converties avant deduplication.
;
; Chaque pose est un META-SPRITE de DEUX sprites (write_2_sprites) : nos PNG
; 24x48 sont les deux tranches deja composees.
;
; ET ON LES RECOUPE EN DEUX, horizontalement. Pas par gout de la fidelite :
; BuildSprites rejette EN BLOC un sprite qui deborde de l'ecran, la ou l'arcade
; le decoupe. Le gouger attend a demi enterre dans la paroi (15 au plafond,
; 183 au sol, ancre au centre d'un sprite de 48) : il debordait donc TOUJOURS
; et n'etait pas dessine du tout pendant sa phase d'attente, qui est
; l'essentiel de sa vie. Coupe, seule la moitie enfouie est rejetee.
;   plafond 15 : haute -6 -> rejetee     basse 15..36   -> dessinee
;   sol    183 : haute 162..183 -> ok    basse 183..207 -> rejetee
; Un objet PARENT porte la moitie top, un objet ENFANT la basse. L'enfant ne
; decide de rien : le parent lui ecrit position et image a chaque trame. Les
; deux portent le MEME y_pos — les demi-images restent sur un canevas 24x48
; dont une moitie est effacee (tools/gen_gouger_halves.py), et gfxcomp derive
; l'ancre du centre de ce canevas. Aucun decalage a ecrire nulle part.
; Cout mesure : 34 887 octets contre 34 445 avant la coupe, soit +442 pour 23
; routines de plus (un LEAU et un RTS chacune). Et le RANGEMENT s'ameliore :
; huit unites de ~4,4 Ko se logent dans les creux de l'arene la ou quatre de
; ~9 Ko forcaient leurs propres pages — cinq pages au lieu de six.
;
; LE FLASH DE COUP : une image blanche par orientation, quatre en tout
; (images/hit/{tl,tr,bl,br}, dans l'ordre des variantes), coupees en deux comme
; le reste. C'est la POSE 2 qui est blanchie — celle que la plongee fige, donc
; la plus vue. Voir tools/gen_gouger_hit.py puis gen_gouger_halves.py.
;
; LA MACHINE A TROIS ETATS
;
;   A — cache. Il defile avec la carte et attend son declencheur (voir plus
;       haut : direction du joueur, ou compte a rebours). Plafond ou sol ne se
;       lit PAS ici mais dans la variante — la plate Ghidra pretendait le
;       contraire, elle est corrigee.
;       Son dessin n'est pas une animation : l'index est reconstruit depuis la
;       base a chaque trame, donc rien ne s'accumule. Il montre la POSE 1, sauf
;       UNE trame sur 64 — quand (+0x34 & $3F) vaut zero — ou il montre la
;       POSE 2 : un sursaut d'une trame. Seules les variantes a compte a
;       rebours sursautent ; celle qui guette le joueur ne passe jamais par la.
;       Cette pose d'attente est la seule du gouger compilee avec sa variante
;       pre-decalee d'un pixel — il est immobile sur un decor qui defile. Elle
;       n'est PAS dupliquee pour autant : l'animation se sert de la meme image
;       et le code eteint la variante par la parite. Voir gouger.Snap.
;       La collision, la mort et le recul sont deja actifs dans cette phase,
;       ainsi que la fenetre de visibilite (voir gouger.Frame). Il nait a
;       166, juste a droite du cadre : DANS la fenetre, qui s'arrete a 167 —
;       quelques pixels plus loin et il se retirait a la naissance.
;
;   B — la plongee. Chaque trame : x_pos += scroll_amount (verrou de defilement),
;       puis SONDE DU DECOR au centre.
;         . case VIDE  -> vitesse PRIMAIRE (+0x30/+0x32) et pose FIXE (2).
;         . case SOLIDE-> vitesse de TRAINEE (+0x38/+0x3A), animation, et le
;                         son 0x5F toutes les 0x20 trames.
;       ATTENTION : la plate Ghidra affirmait l'inverse. Le desassemblage est
;       sans ambiguite — `CMP AX,0xFA0 / JZ 0x7086`, et 0x7086 prend la vitesse
;       primaire. Or 0xFA0 est la case VIDE (seule case franchissable, cf. la
;       fiche de probe_foreground_tile) : le gouger RAMPE sur le decor en
;       s'animant, et PLONGE quand il n'y a plus rien sous lui. La plate est
;       corrigee dans la base.
;
;   C — le recul, 0x17 = 23 trames apres chaque coup encaisse. Il continue de
;       defiler et de s'animer, et clignote une trame sur quatre.
;
; PV = 10 (le spawner ecrase la table de difficulte par un $0A inconditionnel).
; Mort : son 0x53, score $86F8, puis grosse explosion gris-brun (40:e817).
; Retrait silencieux hors cadre, mais SEULEMENT si aucun coup n'a ete encaisse
; cette trame — le test de visibilite est dans cette branche-la.
;
; LA SONDE, cote v2. L'arcade lit l'index de tuile et le compare a 0xFA0 ;
; nous avons terrainCollision.do, qui rend B != 0 sur du solide :
;       ldd   <x>  / std terrainCollision.sensor.x
;       ldd   <y>  / std terrainCollision.sensor.y
;       ldb   #1   / jsr terrainCollision.do / tstb
; B = 0 vaut donc « case vide » et rend exactement le test arcade.
;
; CE QUI DEMANDERA UN ARBITRAGE
; - le clignotement de coup passe par un echange de palette d'objet ; la
;   palette TO8 est globale au stage. Meme choix que pour le serpent :
;   une image blanche, ou rien.
; - les sons (0x5F traine, 0x57 coup, 0x53 mort) : aucun ennemi de ce portage
;   n'a de son a ce jour.
; - 46 demi-sprites compiles : 38 100 octets MESURES sur cinq pages, partagees
;   avec le reste de l'arene. La seconde variante de la pose d'attente en pese
;   3 213 ; la DUPLIQUER en aurait coute le quadruple, c'est ce que gouger.Snap
;   evite. Elle n'est compilee que pour la moitie qui SORT de la paroi — celle
;   qui y est enfouie n'est jamais dessinee en attente, donc ne s'y cale pas.
;   Cette derniere economie grave la geometrie dans le build : le generateur
;   d'images la verifie et casse si elle change. L'estimation par octet-par-pixel du serpent en
;   annoncait 11,7 Ko — trois fois moins : le cout d'un sprite compile suit le
;   REMPLISSAGE, pas la surface du cadre. Une entree de repertoire par
;   direction ET par moitie, le cast n'ayant pas la place.
; - un slot d'OST et un sprite de plus par gouger vivant. Trois gougers
;   simultanes releves, donc six sprites ; la passe en tient seize. A surveiller
;   quand wick et brood arriveront, pas avant.
; - PAS de variante decalee d'un pixel pour les poses d'ANIMATION, vu la taille
;   des sprites — meme choix que pour l'outslay. Seule la pose d'attente en a
;   une, et pour une raison precise : elle est la seule que le gouger tienne
;   IMMOBILE sur un decor qui defile. Le cycle de reptation la reutilise sans
;   scintiller parce que gouger.Snap y eteint la variante.
;*******************************************************************************

; -----------------------------------------------------------------------------
; L'ETAT, dans ext_variables (20 octets disponibles)
; -----------------------------------------------------------------------------
AABB_0          equ ext_variables      ; 0..8   la boite
gouger.var      equ ext_variables+9    ; 9      la variante, 0..3
gouger.trig     equ ext_variables+10   ; 10,11  le declencheur : $FFFF = guetter
                                       ;        le joueur, sinon compte a rebours
gouger.anim     equ ext_variables+12   ; 12,13  le compteur d'animation
gouger.recoil   equ ext_variables+14   ; 14     le compte a rebours du recul
gouger.prevP    equ ext_variables+15   ; 15     le potentiel du tour precedent
gouger.blink    equ ext_variables+16   ; 16     1 = blanc cette trame
gouger.child    equ ext_variables+17   ; 17,18  l'OST de la moitie bottom, 0 si
                                       ;        aucun slot n'etait libre
gouger.snap     equ ext_variables+19   ; 19     1 = un pixel a rendre a la vraie
                                       ;        position, voir gouger.Snap
; Cote ENFANT, le meme espace porte tout autre chose : il n'a pas de boite.
gouger.hParent  equ ext_variables      ; 0,1    l'OST de son parent

gouger.RECOIL   equ 23                 ; 0x17 trames de jeu, comme l'arcade

gouger.Object
        lda   routine,u
        asla
        ldx   #gouger.Routines
        jmp   [a,x]
gouger.Routines
        fdb   gouger.Init
        fdb   gouger.Hidden            ; phase A
        fdb   gouger.Dive              ; phase B
        fdb   gouger.Recoil            ; phase C
        fdb   gouger.Deleted

; -----------------------------------------------------------------------------
gouger.Init
        ldb   subtype_w+1,u            ; le 5e octet du descripteur de wave
        pshs  b
        andb  #3                       ; bits 0-1 : la variante
        stb   gouger.var,u
        aslb
        ldx   #gouger.PresetY
        abx
        ldd   ,x
        std   y_pos,u
        ldd   glb_camera_x_pos
        addd  #166                     ; juste a droite du cadre, comme l'arcade
        std   x_pos,u
        clr   x_pos+2,u                ; la fraction repart nette
        clr   y_pos+2,u
        puls  b                        ; bits 2-3 : le declencheur
        lsrb
        lsrb
        andb  #3
        aslb
        ldx   #gouger.PresetTrig
        abx
        ldd   ,x
        std   gouger.trig,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        _Collision_AddAABB AABB_0,AABB_list_ennemy
        lda   #gouger_hitdamage
        sta   AABB_0+AABB.p,u
        sta   gouger.prevP,u
        _ldd  gouger_hitbox_x,gouger_hitbox_y
        std   AABB_0+AABB.rx,u
        ldb   #6
        stb   priority,u
        ; L'IDENTIFIANT BASCULE ICI, et une seule fois. Les 23 sprites du
        ; gouger pesent plus de deux pages, donc chaque direction a son
        ; direntry — or Img_Page_Index ne donne qu'UNE page d'images par
        ; identifiant. La variante etant figee a la naissance, l'objet prend
        ; l'id de sa direction et n'en change plus. Meme motif que la tete et
        ; la queue du serpent.
        ldb   gouger.var,u
        ldx   #gouger.Ids
        abx
        lda   ,x
        sta   id,u
        ldd   #0
        std   gouger.anim,u
        std   gouger.child,u           ; pas encore d'enfant
        clr   gouger.recoil,u
        clr   gouger.blink,u
        clr   gouger.snap,u            ; un OST se recycle : ne rien heriter
        inc   routine,u
        ; --- LA MOITIE BOTTOM, un objet a part entiere ---------------------
        ; Elle ne decide de rien : le parent lui ecrit sa position et son image
        ; a chaque trame (gouger.Draw). Elle existe parce que BuildSprites
        ; rejette EN BLOC un sprite qui deborde de l'ecran — coupe en deux, le
        ; gouger a demi enterre montre au moins sa moitie hors paroi. Les deux
        ; objets portent le MEME y_pos : l'ancre de chaque demi-image, derivee
        ; du centre du canevas par gfxcomp, place chacune a sa hauteur.
        ; LoadObject_x accroche en FIN de liste, donc l'enfant tourne apres son
        ; parent des cette trame — et le parent n'a pas encore dessine, d'ou la
        ; garde sur image_set cote enfant.
        jsr   LoadObject_x
        beq   @seul                    ; plus de slot : il vivra en demi-teinte
        ldb   gouger.var,u
        ldy   #gouger.ChildIds
        lda   b,y
        sta   id,x
        lda   #1
        sta   routine,x                ; l'enfant n'a pas d'etat d'init
        lda   #render_playfieldcoord_mask
        sta   render_flags,x
        lda   #6
        sta   priority,x
        clr   image_set,x              ; rien a montrer avant le premier dessin
        clr   image_set+1,x
        stu   gouger.hParent,x
        stx   gouger.child,u
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
@seul   rts

; -----------------------------------------------------------------------------
; PHASE A — cache. Il defile avec la carte (coordonnees playfield : la camera
; s'en charge, la ou l'arcade ajoute scroll_amount a la main) et attend son
; declencheur. Il est deja touchable.
; -----------------------------------------------------------------------------
gouger.Hidden
        jsr   gouger.Frame
        lbne  gouger.Gone
        ldd   gouger.trig,u
        bmi   @regard                  ; bit 15 arme : il guette le joueur
        subd  gouger.drop              ; sinon : un compte a rebours de JEU
        bhi   @attend
        ldd   #0
        std   gouger.trig,u
        bra   @plonge
@attend std   gouger.trig,u
        andb  #$3F                     ; le sursaut : une trame sur 64
        bne   @pose1
        ldb   #2
        bra   @dessine
@pose1  ldb   #1
        bra   @dessine
@regard ldb   gouger.var,u
        aslb
        ldx   #gouger.Compass
        abx
        ldd   ,x
        pshs  d                        ; la direction attendue
        ldx   #player1
        jsr   setDirectionTo           ; rend la direction dans Y
        tfr   y,d
        cmpd  ,s++
        beq   @plonge
        ldb   #1                       ; il guette : toujours la pose 1
        bra   @dessine
@plonge lda   #2
        sta   routine,u
        ldb   #1                       ; encore contre la paroi cette trame
@dessine
        jsr   gouger.Draw
        jmp   DisplaySprite

; -----------------------------------------------------------------------------
; PHASE B — la sonde de decor decide de tout : case VIDE il plonge a la vitesse
; primaire sur une pose fixe, case SOLIDE il rampe en s'animant.
; -----------------------------------------------------------------------------
gouger.Dive
        jsr   gouger.Frame
        lbne  gouger.Gone
        ldd   x_pos,u
        std   terrainCollision.sensor.x
        ldd   y_pos,u
        std   terrainCollision.sensor.y
        ldb   #1
        jsr   terrainCollision.do
        tstb
        bne   @rampe
        ldx   #gouger.VelPrim          ; case vide : la plongee
        jsr   gouger.Move
        ldb   #2                       ; la pose que l'arcade fige
        bra   @dessine
@rampe  ldx   #gouger.VelTrail         ; case solide : la reptation
        jsr   gouger.Move
        jsr   gouger.Anim
@dessine
        pshs  b                        ; le calage APRES la sonde et le
        jsr   gouger.Snap              ; deplacement, AVANT le dessin — c'est
        puls  b                        ; lui qui recopie x_pos chez l'enfant
        jsr   gouger.Draw
        jmp   DisplaySprite

; -----------------------------------------------------------------------------
; PHASE C — le recul, 23 trames de jeu apres un coup encaisse.
; -----------------------------------------------------------------------------
gouger.Recoil
        jsr   gouger.Frame
        lbne  gouger.Gone
        lda   gouger.recoil,u
        suba  gouger.drop+1
        bhi   @encore
        clra
        sta   gouger.recoil,u
        lda   #2                       ; fini : retour a la plongee
        sta   routine,u
        lda   AABB_0+AABB.p,u
        sta   gouger.prevP,u           ; ... en prenant acte du coup
        bra   @suite
@encore sta   gouger.recoil,u
@suite  jsr   gouger.Anim
        pshs  b
        jsr   gouger.Snap              ; le recul s'anime aussi : meme calage
        puls  b
        jsr   gouger.Draw
        jmp   DisplaySprite

; -----------------------------------------------------------------------------
; L'ouverture de trame, commune aux trois phases : le compte de trames de jeu,
; le verdict de mort, le coup encaisse, la boite et la sortie de cadre.
; Z = 0 s'il faut s'en aller.
; -----------------------------------------------------------------------------
gouger.Frame
        ; Rendre d'abord le pixel emprunte par le calage de la trame
        ; precedente : tout ce qui suit — boite de collision, sonde de decor,
        ; deplacement — travaille sur la position VRAIE. Sans cette restitution
        ; le calage se cumulerait et le gouger deriverait vers la gauche.
        lda   gouger.snap,u
        beq   >
        clr   gouger.snap,u
        ldd   x_pos,u
        addd  #1
        std   x_pos,u
!       ldb   gfxlock.frameDrop.count
        bne   >
        incb                           ; miroir du garde de runByFrameDrop
!       clra
        std   gouger.drop
        lda   AABB_0+AABB.p,u
        beq   @mort
        cmpa  gouger.prevP,u           ; un coup depuis le tour precedent ?
        bhs   @cadre
        sta   gouger.prevP,u
        lda   #1
        sta   gouger.blink,u           ; une trame blanche
        lda   routine,u
        cmpa  #3
        beq   @cadre                   ; deja en recul : on ne le relance pas
        lda   #gouger.RECOIL
        sta   gouger.recoil,u
        lda   #3
        sta   routine,u
; La fenetre de visibilite, portee de is_visible_range (40:1d6b) : l'arcade
; garde un objet dont le CENTRE tient dans le cadre elargi de 20 pixels arcade
; sur chacun des quatre bords. On reprend la MARGE, pas les coordonnees : le
; cadre du portage ne couvre pas la meme largeur de monde que celui de l'arcade
; (160 px larges en coordonnees playfield contre 384 arcade, soit 0,417 et non
; le 0,375 des vitesses et des boites). Marges : 20 x 0,375 = 8 en X,
; 20 x 0,75 = 15 en Y.
;   X : -8..167 (le cadre va de 0 a 159)   Y : -15..214 (de 0 a 199)
; Les trois phases la partagent, comme en arcade — et comme en arcade elle ne
; s'evalue que si l'objet n'est ni mort ni touche cette trame.
@cadre  ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u
        addd  #8
        bmi   @part                    ; sorti par la gauche
        cmpd  #167+8
        bgt   @part                    ; ... ou par la droite
        ldd   y_pos,u
        stb   AABB_0+AABB.cy,u
        addd  #15
        bmi   @part                    ; sorti par le haut
        cmpd  #214+15
        bgt   @part                    ; ... ou par le bas
        orcc  #$04                     ; Z = 1 : il reste
        rts
@mort   ldb   #gouger_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        beq   @part
        _ldd  ObjID_explosion,explosion.subtype.big
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
@part   andcc #$FB                     ; Z = 0 : il s'en va
        rts

gouger.Gone
        ; L'enfant part AVEC le parent, dans la meme trame : le laisser mourir
        ; de lui-meme au tour suivant laisserait une demi-carcasse a l'ecran.
        ; UnloadObject_u sait qu'il peut etre le prochain de la marche et
        ; recale object_list_next — supprimer un autre objet en pleine passe
        ; est prevu par le moteur.
        ldx   gouger.child,u
        beq   >
        lda   #2
        sta   routine,x
        pshs  u                        ; DeleteObject prend l'objet en U, et le
        leau  ,x                       ; rend intact — c'est notre U a nous qu'il
        jsr   DeleteObject             ; faut remettre. Pas de _api de plus pour
        puls  u                        ; ca : un export coute a chaque chargement.
!       lda   #4
        sta   routine,u
        _Collision_RemoveAABB AABB_0,AABB_list_ennemy
        jmp   DeleteObject
gouger.Deleted
        rts

; -----------------------------------------------------------------------------
; LA MOITIE BOTTOM. Elle ne porte ni boite, ni horloge, ni decision : son parent
; lui ecrit position et image. Elle ne fait que verifier qu'il est encore la.
; Le controle est double parce qu'un OST se RECYCLE : l'identifiant seul dirait
; encore « gouger » si un autre gouger avait pris le slot, d'ou la verification
; que le parent nous reconnait pour enfant. C'est le geste du suiveur du
; serpent, avec la reciproque en plus.
; -----------------------------------------------------------------------------
gouger.Half
        ldx   gouger.hParent,u
        lda   id,x
        suba  #ObjID_gouger_tl
        cmpa  #3
        bhi   @orphelin                ; le slot du parent a change de main
        cmpu  gouger.child,x
        bne   @orphelin                ; ... ou il ne nous reconnait plus
        ldd   image_set,u
        beq   @attend                  ; le parent n'a pas encore dessine
        jmp   DisplaySprite
@attend rts
@orphelin
        lda   #2
        sta   routine,u
        jmp   DeleteObject

; -----------------------------------------------------------------------------
; L'animation : une horloge de JEU. B rend le slot du cycle, 0..7.
; -----------------------------------------------------------------------------
gouger.Anim
        ldd   gouger.anim,u
        addd  gouger.drop
        std   gouger.anim,u
        lsrb                           ; une pose toutes les quatre trames
        lsrb
        andb  #7
        rts

; -----------------------------------------------------------------------------
; Le dessin : B = le SLOT du cycle. La table de la variante le ramene a une
; pose, puis la pose a un set. Une trame blanche l'emporte sur tout.
; -----------------------------------------------------------------------------
gouger.Draw
        lda   gouger.blink,u
        beq   @normal
        clr   gouger.blink,u           ; une seule trame
        ldb   gouger.var,u
        aslb
        ldx   #gouger.HitSets
        abx
        ldx   ,x
        stx   image_set,u
        ldb   gouger.var,u
        aslb
        ldx   #gouger.HitSetsBottom
        abx
        ldx   ,x
        bra   gouger.Child
@normal pshs  b
        ldb   gouger.var,u
        aslb
        ldx   #gouger.Cycles
        abx
        ldx   ,x                       ; X = la table slot -> pose
        puls  b
        ldb   b,x                      ; B = la pose
        aslb
        pshs  b
        ldb   gouger.var,u
        aslb
        ldx   #gouger.PoseSets
        abx
        ldx   ,x                       ; X = les moities TOP de la variante
        ldb   ,s
        abx
        ldx   ,x
        stx   image_set,u
        ldb   gouger.var,u
        aslb
        ldx   #gouger.PoseSetsBottom
        abx
        ldx   ,x                       ; X = les moities BOTTOM
        puls  b
        abx
        ldx   ,x
        bra   gouger.Child

; X = l'image de la moitie bottom. On la depose chez l'enfant avec la position :
; il ne calcule rien, et les deux moities ne peuvent pas diverger d'une trame.
gouger.Child
        ldy   gouger.child,u
        beq   @seul
        stx   image_set,y
        ldd   x_pos,u
        std   x_pos,y
        ldd   y_pos,u
        std   y_pos,y
@seul   rts

; -----------------------------------------------------------------------------
; Deplacer des deux vitesses 8.8 pointees par X, compensees du frame-drop.
; Le produit vitesse x n tient sur seize bits (384 x 8 = 3072) et le calcul
; tronque a seize bits est juste en complement a deux — meme raison que pour le
; vol libre du serpent, voir slither/obj.asm.
; -----------------------------------------------------------------------------
gouger.Move
        ldb   gouger.var,u
        aslb
        aslb                           ; quatre octets par variante
        abx
        pshs  x
        ldd   ,x
        leax  x_pos,u
        jsr   gouger.AddPos
        puls  x
        ldd   2,x
        leax  y_pos,u
; D = vitesse 8.8 signee, X = le champ position (haut, bas, fraction)
gouger.AddPos
        pshs  a                        ; l'octet haut de la vitesse
        lda   gouger.drop+1
        mul                            ; D = octet bas x n
        std   gouger.tmp
        puls  a
        ldb   gouger.drop+1
        mul                            ; D = octet haut x n
        tfr   b,a                      ; ... decale de huit bits
        clrb
        addd  gouger.tmp               ; le delta complet, tronque a 16 bits
        pshs  d
        ldb   ,s                       ; son octet haut : le signe
        sex
        sta   @a+1
        puls  d
        addd  1,x                      ; les deux octets bas de la position
        std   1,x
        lda   ,x
@a      adca  #$00
        sta   ,x
        rts

; -----------------------------------------------------------------------------
; LE CALAGE, qui evite de dupliquer la pose d'attente.
;
; La pose 1 est la seule compilee avec sa variante PRE-DECALEE d'un pixel : le
; gouger en attente est immobile sur un decor qui defile d'un pixel a la fois,
; et sans elle le moteur replie sur la routine non decalee en corrigeant la
; position (BSP_parityFallback) — il tremblait d'un pixel sur la roche, une
; trame sur deux. Les autres poses n'ont pas cette variante : les melanger dans
; le cycle de reptation ferait scintiller l'animation.
;
; Plutot que d'avoir DEUX images de la pose 1, on eteint la variante decalee la
; ou elle gene : il suffit que la parite ecarte le moteur de ce choix. Le calcul
; se lit dans BuildSprites :
;     B = octet bas de (x_pos - camera)
;     eorb <_image_center_parity+1   ; = center_offset etendu au signe
;     andb #1 / aslb / orb #1        ; 1 -> non decalee, 3 -> decalee
; center_offset vaut $FF sur les 46 demi-images du gouger — verifie, il ne
; depend pas de leur largeur ici — donc la parite retenue est l'INVERSE de
; celle de (x_pos - camera), et le moteur prend la variante NON decalee quand
;     (x_pos - camera) est IMPAIR.
; D'ou : en phase d'attente on ne touche a rien et la pose 1 se cale au pixel ;
; des que le gouger s'anime, on force cette difference impaire et toutes les
; poses, elle comprise, retombent sur la grille paire — exactement ce que le
; repli du moteur faisait deja, mais de facon uniforme.
;
; Le pixel emprunte est RENDU en tete de trame suivante (gouger.Frame) : la
; position vraie n'est jamais alteree, et la collision comme la sonde de decor
; la voient intacte.
; Parent et enfant partagent x_pos et le meme center_offset : un seul calage
; sert les deux moities.
; Une seule des deux porte reellement la variante decalee — celle qui sort de
; la paroi, top au sol et bottom au plafond. L'autre n'est pas dessinee en
; attente et le calage l'ecarte le reste du temps : sa variante ne pouvait
; jamais etre choisie. gen_gouger_halves.py verifie ce rejet a chaque
; regeneration de l'art.
; -----------------------------------------------------------------------------
gouger.Snap
        ldd   x_pos,u
        subd  glb_camera_x_pos
        andb  #1
        bne   >                        ; deja impair : variante non decalee
        ldd   x_pos,u
        subd  #1
        std   x_pos,u
        inc   gouger.snap,u
!       rts

gouger.drop     fdb 0                  ; trames de jeu de ce tour
gouger.tmp      fdb 0

; -----------------------------------------------------------------------------
; LES TABLES. Tout vient du releve arcade — voir la fiche en tete de fichier.
; -----------------------------------------------------------------------------
; y = (396 - y_arcade) x 0.75, conversion deduite du preset commun 1930c et
; verifiee sur ses six valeurs. Le sprite fait 48 de haut et son ancre est au
; centre : le gouger deborde du cadre, il est a demi enterre dans le decor.
; Les ordonnees arcade, telles quelles : la coupe en deux moities rend le
; recadrage inutile. A 15 comme a 183, seule la moitie ENFOUIE est rejetee par
; BuildSprites, et la moitie hors paroi s'affiche a sa vraie place.
;   plafond 15 : haute -6 -> rejetee   basse 15..36  -> dessinee
;   sol    183 : haute 162..183 -> ok  basse 183..207 -> rejetee
gouger.PresetY
        fdb   15   ; var 0, plafond ($0178)
        fdb   15   ; var 1, plafond
        fdb   183  ; var 2, sol ($0098)
        fdb   183  ; var 3, sol
; $FFFF = guetter le joueur ; sinon un compte a rebours en trames
gouger.PresetTrig
        fdb   $FFFF,128,384,512
; la direction attendue, gravee en +0x36 par le prereglage
gouger.Compass
        fdb   $0018,$0028,$0008,$0038
; vitesses a l'echelle du jeu (x 0.375 en x, x 0.75 en y). L'axe Y arcade
; MONTE, le notre descend : le signe de vy est donc inverse.
gouger.VelPrim
        fdb    144,384  ; var 0 : plafond, vers la droite
        fdb   -144,384  ; var 1 : plafond, vers la gauche
        fdb    144,-384  ; var 2 : sol, vers la droite
        fdb   -144,-384  ; var 3 : sol, vers la gauche
gouger.VelTrail
        fdb     36,96
        fdb    -36,96
        fdb     36,-96
        fdb    -36,-96
; le cycle slot -> pose, tel que --dedup l'a ecrit dans cycle.txt
gouger.CycA
        fcb   0,1,2,3,2,1,0,4
gouger.CycB
        fcb   0,1,2,3,2,1,0,3          ; bottom-right : sa 8e pose = la 4e
gouger.Cycles
        fdb   gouger.CycA  ; var 0, top-left
        fdb   gouger.CycA  ; var 1, top-right
        fdb   gouger.CycA  ; var 2, bottom-left
        fdb   gouger.CycB  ; var 3, bottom-right
; Deux jeux de tables, la moitie TOP pour le parent et la BASSE pour son
; enfant. Le suffixe _h / _b est celui des repertoires d'images ; le cycle
; slot -> pose est le meme des deux cotes, une moitie n'a pas sa propre
; animation.
; LES JEUX D'IMAGES, moitie TOP pour le parent et BOTTOM pour son enfant.
; Le cycle slot -> pose est le meme des deux cotes, une moitie n'a pas sa
; propre animation.
; LA POSE 1 VIENT D'UNE AUTRE ENTREE — c'est la pose d'attente, seule a porter
; sa variante pre-decalee (voir gouger.Snap). L'avoir sortie du repertoire
; principal y a renumerote les quatre autres, le suffixe suivant l'ordinal dans
; l'entree et non le nom du fichier : d'ou le _1.._3 pour les poses 2..4. La
; correspondance est ecrite ici et nulle part ailleurs.
gouger.PoseSets
        fdb   gouger.SetsTLtop,gouger.SetsTRtop
        fdb   gouger.SetsBLtop,gouger.SetsBRtop
gouger.PoseSetsBottom
        fdb   gouger.SetsTLbottom,gouger.SetsTRbottom
        fdb   gouger.SetsBLbottom,gouger.SetsBRbottom
gouger.SetsTLtop
        fdb   set_gouger_tl_top_0        ; pose 0
        fdb   set_gouger_tl_top_idle_0   ; pose 1 — l attente
        fdb   set_gouger_tl_top_1        ; pose 2
        fdb   set_gouger_tl_top_2        ; pose 3
        fdb   set_gouger_tl_top_3        ; pose 4
gouger.SetsTRtop
        fdb   set_gouger_tr_top_0        ; pose 0
        fdb   set_gouger_tr_top_idle_0   ; pose 1 — l attente
        fdb   set_gouger_tr_top_1        ; pose 2
        fdb   set_gouger_tr_top_2        ; pose 3
        fdb   set_gouger_tr_top_3        ; pose 4
gouger.SetsBLtop
        fdb   set_gouger_bl_top_0        ; pose 0
        fdb   set_gouger_bl_top_idle_0   ; pose 1 — l attente
        fdb   set_gouger_bl_top_1        ; pose 2
        fdb   set_gouger_bl_top_2        ; pose 3
        fdb   set_gouger_bl_top_3        ; pose 4
gouger.SetsBRtop
        fdb   set_gouger_br_top_0        ; pose 0
        fdb   set_gouger_br_top_idle_0   ; pose 1 — l attente
        fdb   set_gouger_br_top_1        ; pose 2
        fdb   set_gouger_br_top_2        ; pose 3
gouger.SetsTLbottom
        fdb   set_gouger_tl_bottom_0        ; pose 0
        fdb   set_gouger_tl_bottom_idle_0   ; pose 1 — l attente
        fdb   set_gouger_tl_bottom_1        ; pose 2
        fdb   set_gouger_tl_bottom_2        ; pose 3
        fdb   set_gouger_tl_bottom_3        ; pose 4
gouger.SetsTRbottom
        fdb   set_gouger_tr_bottom_0        ; pose 0
        fdb   set_gouger_tr_bottom_idle_0   ; pose 1 — l attente
        fdb   set_gouger_tr_bottom_1        ; pose 2
        fdb   set_gouger_tr_bottom_2        ; pose 3
        fdb   set_gouger_tr_bottom_3        ; pose 4
gouger.SetsBLbottom
        fdb   set_gouger_bl_bottom_0        ; pose 0
        fdb   set_gouger_bl_bottom_idle_0   ; pose 1 — l attente
        fdb   set_gouger_bl_bottom_1        ; pose 2
        fdb   set_gouger_bl_bottom_2        ; pose 3
        fdb   set_gouger_bl_bottom_3        ; pose 4
gouger.SetsBRbottom
        fdb   set_gouger_br_bottom_0        ; pose 0
        fdb   set_gouger_br_bottom_idle_0   ; pose 1 — l attente
        fdb   set_gouger_br_bottom_1        ; pose 2
        fdb   set_gouger_br_bottom_2        ; pose 3
gouger.HitSets
        fdb   set_gouger_hit_tl_top_0,set_gouger_hit_tr_top_0
        fdb   set_gouger_hit_bl_top_0,set_gouger_hit_br_top_0
gouger.HitSetsBottom
        fdb   set_gouger_hit_tl_bottom_0,set_gouger_hit_tr_bottom_0
        fdb   set_gouger_hit_bl_bottom_0,set_gouger_hit_br_bottom_0
; l'identifiant de chaque direction : c'est lui qui porte la page d'images
gouger.Ids
        fcb   ObjID_gouger_tl,ObjID_gouger_tr
        fcb   ObjID_gouger_bl,ObjID_gouger_br
gouger.ChildIds
        fcb   ObjID_gouger_tl_bottom,ObjID_gouger_tr_bottom
        fcb   ObjID_gouger_bl_bottom,ObjID_gouger_br_bottom
