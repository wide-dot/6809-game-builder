; ---------------------------------------------------------------------------
; Compiler — le boss du stage 4
;
; input REG : [u] pointer to Object Status Table (OST)
; ---------------------------------------------------------------------------
;
; FICHE DE PORTAGE — BLOC 1 : l'orchestrateur et les trois parties
; ================================================================
; arcade : create_compiler 0x40:A71D, tick_compiler_init_segments 0x40:A762,
;          tick_compiler_combat_monitor 0x40:A982, motion_step 0x40:AFE6
; donnees : compiler_variant_slot_table 0x1000:5ABA (8 variantes),
;           compiler_shared_base_motion_script 0x1000:5B54 (l'intro)
;
; CE QUE FAIT LA BORNE, ET CE QUE CE BLOC EN PORTE
; ------------------------------------------------
; Le boss est un vaisseau-mere en TROIS PARTIES MOBILES (droite, bas,
; gauche) qui naissent AU MEME POINT et paraissent d'abord assemblees en une
; seule silhouette — leurs sprites ont des ancres differentes, c'est ce qui
; les emboite. Elles derivent ensemble pendant l'intro, puis chacune part sur
; ses propres scripts.
;
; BLOC 1 (ici) : l'orchestrateur, les trois parties, et l'INTRO — le script
;   partage 0x5B54, un seul segment : vx = +1 px/trame arcade pendant 0x160
;   trames (~5,9 s), vy nul. C'est tout ce qui bouge a ce stade.
; BLOCS SUIVANTS (a venir) : les armes (le laser horizontal de la partie
;   droite, les trois tourelles), les scripts de combat (9 au total, tires
;   par la variante), les PV et la mort en cascade, l'auto-destruction.
;
; ECARTS ASSUMES
; --------------
; V2-DEVIATION: la variante est tiree au sort parmi 8 chez elle
;   ((random + player_x + player_y) & 7) et ne change que l'ORDRE des scripts
;   de combat. Sans scripts de combat, ce bloc n'en a pas besoin : la
;   variante viendra avec eux.
; V2-DEVIATION: pas de selecteur de difficulte en v2 — la cadence d'attaque
;   par difficulte (0x1000:5844) prendra sa premiere valeur, comme le reste
;   du cast.
; ---------------------------------------------------------------------------

AABB_0        equ ext_variables      ; AABB struct (9 bytes)
cpl.part      equ ext_variables+9    ; 0 = droite, 1 = bas, 2 = gauche
cpl.timer     equ ext_variables+10   ; WORD : trames restantes du segment
cpl.vx        equ ext_variables+12   ; WORD : la vitesse du segment (8.8)
; --- l'oscillateur du dome, porte par l'ORCHESTRATEUR (un seul, pas trois) ---
cpl.dome.step equ ext_variables+14     ; l'index dans cpl.dome.seq
cpl.dome.left equ ext_variables+15     ; trames restantes sur cette etape
; Le laser reutilise les cases de la partie : un slot ne porte jamais les deux.
cpl.laser.vx  equ cpl.vx               ; WORD : sa vitesse (8.8), vers la gauche
; La tourelle, elle, garde le lien vers sa piece et ses deux decalages.
cpl.tur.parent equ ext_variables+10    ; WORD : l'OST de la piece porteuse
cpl.tur.offx  equ ext_variables+12     ; son decalage, signe
cpl.tur.offy  equ ext_variables+13
cpl.tur.dir   equ ext_variables+14     ; la direction visee (0,4,8..$3C)
; L'onde du laser roulant : sa vitesse horizontale, et le mot a DOUBLE EMPLOI
; de la borne — vitesse verticale ET compte a rebours de vie.
cpl.wav.vx    equ ext_variables+10     ; WORD, signe
cpl.wav.life  equ ext_variables+12     ; WORD, 8.8 : vitesse y ET duree
; Le combat d'une piece : le souvenir de ses PV (pour voir le coup arriver),
; son compte de clignotement, puis le curseur du chapelet d'explosions.
; --- LES CHAMPS D'UNE PIECE, et il n'y a pas un octet de rab : l'espace
; d'objet en offre onze (ext_variables_size 20, moins les neuf de la boite).
;   9 part | 10-11 timer | 12-13 vx | 14-15 vy | 16 hp.prev | 17 hit
;   18 cfg | 19 cursor
; Le curseur PORTE DEUX CHAMPS : l'index du script dans les bits hauts, celui
; du segment dans les bas — dix-sept segments demandent cinq bits, trois
; scripts en demandent deux, et les deux ne tenaient pas separement.
cpl.hp.prev   equ ext_variables+16     ; PV a la trame precedente
cpl.hit       equ ext_variables+17     ; trames de clignotement restantes
; LE CURSEUR DE COMBAT (AFE6) : la config tiree au spawn, le script courant
; dans cette config, et la position dans ce script.
cpl.vy        equ ext_variables+14     ; OCTET SIGNE : la vitesse y du segment
;   Elle tenait un mot, mais les 9 scripts ne portent que des vitesses dans
;   [-120,+120] (mesure sur la table generee) : la fraction 8.8 d'un mouvement
;   sous le pixel par trame. L'octet ainsi rendu paie le compteur de cadence.
cpl.cad       equ ext_variables+15     ; trames restantes avant la salve
cpl.cfg       equ ext_variables+18     ; index de la config tiree (0..2)
cpl.cursor    equ ext_variables+19     ; script<<5 | segment
cpl.CUR_SEG   equ 31                   ; le masque du segment
cpl.CUR_STEP  equ 32                   ; ce qu'un script vaut dans le curseur
cpl.boom.cur  equ ext_variables+10     ; l'index dans la liste (apres la mort)
cpl.boom.tick equ ext_variables+12     ; trames restantes du chapelet
                                       ; (pas `left` : la liste de la piece
                                       ;  GAUCHE porte deja ce nom)

Object
        lda   routine,u
        asla
        ldx   #Routines
        jmp   [a,x]

Routines
        fdb   BossInit
        fdb   BossWatch
        fdb   PartInit
        fdb   PartLive
        fdb   AlreadyDeleted
        fdb   LaserInit
        fdb   LaserFly
        fdb   TurretInit
        fdb   TurretRun
        fdb   WaveInit
        fdb   WaveFly
        fdb   PartBoom

; ---------------------------------------------------------------------------
; BossInit — A762 : l'orchestrateur engendre ses trois parties
;
; Un seul passage. La borne engendre aussi trois tourelles et pose les PV,
; la cadence et le masque de mort ; tout cela vient avec les blocs suivants.
; Elle n'affiche RIEN elle-meme : ce sont les parties qu'on voit.
; ---------------------------------------------------------------------------
BossInit
        ; 5ABA : LA VARIANTE, tiree UNE SEULE FOIS — voir globals.cplVariant.
        jsr   RandomNumber
        andb  #3
        cmpb  #3
        bne   >
        clrb                           ; le tirage rend 0..3, on replie sur 0..2
!       stb   globals.cplVariant
        clr   globals.cplWave          ; le laser roulant repart au repos
        clr   globals.cplWavePair
        ldb   #3                       ; les trois parties, dans l'ordre
        stb   cpl.part,u               ;   arcade : droite, bas, gauche
@spawn  ldb   cpl.part,u
        decb
        stb   cpl.part,u
        jsr   LoadObject_x             ; un slot pour la partie
        beq   @done                    ; pool plein : le boss sera partiel,
                                       ; comme la borne (elle court-circuite
                                       ; aussi vers le moniteur de combat)
        lda   #ObjID_compilerpart
        sta   id,x
        ldb   cpl.part,u
        stb   subtype_w+1,x            ; la partie que ce slot represente
        ; FIX #1 : le fils partage le dispatch de l'orchestrateur, son etat de
        ; depart doit donc etre POSE — un slot frais a routine=0, c'est-a-dire
        ; BossInit : chaque partie re-engendrait trois parties jusqu'a saturer
        ; le pool, et aucune n'atteignait PartInit (aucun sprite a l'ecran).
        lda   #2                       ; -> PartInit
        sta   routine,x
        ; A768 : les trois naissent AU MEME POINT — ce sont les ancres de
        ; leurs sprites qui les emboitent en une silhouette.
        ldd   #cpl.SPAWN_X
        addd  glb_camera_x_pos
        std   x_pos,x
        ldd   #cpl.SPAWN_Y
        std   y_pos,x
        ; LES TOURELLES DE CETTE PIECE. La borne les cree dans la foulee de
        ; leur porteuse (A762) et leur donne un renvoi vers elle : deux sur la
        ; piece du bas, une sur la gauche, la droite n'en a pas — elle a son
        ; laser. On les cree ici, tant que X porte encore l'OST de la piece.
        bsr   cpl.turrets.spawn
        tst   cpl.part,u
        bne   @spawn
@done   lda   #1                       ; -> BossWatch
        sta   routine,u
        ; L'oscillateur part au repos (etape 0), et pose ses couleurs des
        ; cette trame : la palette du combat vient d'etre echangee, son etape 0
        ; en est deja la valeur — mais la poser ici rend l'orchestrateur seul
        ; maitre du dome, quel que soit l'ordre d'arrivee.
        clr   cpl.dome.step,u
        clr   cpl.dome.left,u
        bra   cpl.dome.tick

; ---------------------------------------------------------------------------
; cpl.turrets.spawn — A7xx : les tourelles portees par la piece courante
; ---------------------------------------------------------------------------
; entree : [x] l'OST de la piece, [u] l'orchestrateur (cpl.part = son numero)
; La table dit, pour chacune des trois : la piece qui la porte, ses deux
; decalages et son motif de tir. X survit — l'appelant s'en sert encore.
; ---------------------------------------------------------------------------
cpl.turrets.spawn
        pshs  x,y
        ldy   #cpl.turrets.tbl
        ldb   #cpl.TURRETS
@one    lda   ,y                       ; la piece porteuse de cette tourelle
        cmpa  cpl.part,u
        bne   @next
        pshs  b,y
        jsr   LoadObject_x             ; X = la tourelle... et on perd la piece
        beq   @skip
        lda   #ObjID_compilerturret
        sta   id,x
        lda   #7                       ; -> TurretInit
        sta   routine,x
        ; La pile, apres `pshs b,y` : B en 0,s ; la table en 1,s ; l'OST de la
        ; piece (empile a l'entree) en 3,s. Se tromper d'un cran ici ne fait
        ; rien naitre du tout — vecu.
        ldy   1,s                      ; la table, remise de la pile
        lda   1,y
        sta   cpl.tur.offx,x
        lda   2,y
        sta   cpl.tur.offy,x
        lda   3,y
        sta   subtype_w+1,x            ; le motif de tir, lu par TurretInit
        ldd   3,s                      ; l'OST de la piece, sauve a l'entree
        std   cpl.tur.parent,x
@skip   puls  b,y
@next   leay  4,y
        decb
        bne   @one
        puls  x,y
        rts

; ---------------------------------------------------------------------------
; BossWatch — A982 : le moniteur de combat
;
; BLOC 1 : il ne fait encore que l'OSCILLATION DU DOME. La borne y compte les
; trois drapeaux de mort et arme la sequence finale quand les trois tombent ;
; cela vient avec le bloc « degats et mort ».
; ---------------------------------------------------------------------------
BossWatch
        ; A982 : LE MONITEUR DE COMBAT. La borne attend que les trois bits de
        ; mort soient la, puis deroule une sequence de 256 trames — fondu de
        ; palette, deux bruitages, drapeau de fin de niveau, et relance du
        ; scroll pour la transition. Chez nous l'objet de fin generique
        ; (common/flow/endlevel) fait tout cela des qu'on leve
        ; globals.bossDefeated : c'est le geste que le stage 3 pose deja pour
        ; son cuirasse, et le seul attendu d'un vrai boss.
        ; V2-DEVIATION : la sequence de 256 trames de la borne, avec ses
        ; jalons a 0xB0 et 0x80, n'est pas rejouee — l'objet de fin a la
        ; sienne, calee sur le reste du jeu.
        lda   globals.compilerDead
        cmpa  #3
        blo   cpl.dome.tick
        lda   globals.bossDefeated
        bne   cpl.dome.tick            ; deja leve : on n'y revient pas
        lda   #1
        sta   globals.bossDefeated
cpl.dome.tick
        lda   cpl.dome.left,u
        suba  gfxlock.frameDrop.count  ; le decompte suit l'horloge de jeu
        bhi   @garde                   ; l'etape court toujours
        ; --- etape suivante ---------------------------------------------
        ldb   cpl.dome.step,u
        incb
        cmpb  #cpl.dome.CYCLE
        blo   >
        clrb                           ; le ping-pong reboucle
!       stb   cpl.dome.step,u
        aslb                           ; deux octets par entree : etape, duree
        ldx   #cpl.dome.seq
        abx
        lda   1,x                      ; la duree de la nouvelle etape
        sta   cpl.dome.left,u
        ; --- poser les trois couleurs -----------------------------------
        ; Les cases MATERIELLES 12, 13, 14 sont consecutives et reservees a
        ; nous seuls (arcade_to_sprites --reserver) : trois mots d'affilee
        ; dans Pal_buffer, a l'offset 12*2. C'est tout le cout de l'effet.
        ldb   ,x                       ; l'etape a jouer
        lda   #6                       ; trois mots par etape
        mul                            ; d = etape * 6
        ldx   #cpl.dome.pal
        leax  d,x
        ; U PORTE L'OST : on ne l'ecrase qu'ici, quand plus aucune variable
        ; d'objet n'est a lire, et on le rend avant de sortir.
        pshs  u
        ldu   #Pal_buffer+12*2         ; la premiere des trois cases
        ldy   ,x++
        sty   ,u++
        ldy   ,x++
        sty   ,u++
        ldy   ,x
        sty   ,u
        puls  u
        clr   PalRefresh               ; PalUpdateNow les posera cette trame
        rts
@garde  sta   cpl.dome.left,u
        rts

; ---------------------------------------------------------------------------
; PartInit — A76E : une partie, posee et armee sur le script d'intro
; ---------------------------------------------------------------------------
PartInit
        lda   subtype_w+1,u
        sta   cpl.part,u
        clr   x_sub,u
        clr   y_sub,u
        ; 5B54 : le script d'intro, un seul segment — vx = +1 px/trame
        ; arcade (0,375 px v2), vy nul, pendant 0x160 trames.
        ldd   #cpl.INTRO_VX
        std   cpl.vx,u
        ldd   #cpl.INTRO_DUR
        std   cpl.timer,u
        ; FIX #12 (29/08) : la verticale n'etait jamais posee. L'intro heritait
        ; donc du reliquat de l'objet precedent dans le slot, et derivait.
        clr   cpl.vy,u
        lda   #cpl.FIRE_PERIOD         ; A7D9 : le compteur part plein
        sta   cpl.cad,u
        ; A775 : la lettre du boss, tiree par l'orchestrateur pour les trois.
        ldb   globals.cplVariant
        stb   cpl.cfg,u
        clr   cpl.cursor,u
        ; l'image de CETTE partie : une pose chacune, la silhouette est faite
        ; de leur assemblage
        ldb   cpl.part,u
        aslb
        ldx   #cpl.images
        abx
        ldd   ,x
        std   image_set,u
        ; LA PROFONDEUR DES TROIS PIECES, ECHELONNEE COMME LA BORNE. Elle leur
        ; donne trois valeurs distinctes au spawn (A762) : DROITE 0x4020,
        ; BAS 0x4010, GAUCHE 0x4000 — en priorite signee, plus grand = plus
        ; DEVANT. Notre echelle va dans l'autre sens (1 devant, 8 derriere,
        ; cf. engine/constants.asm) et le joueur est a 3 : le boss tient donc
        ; entre 4 et 8. Les trois partageaient la valeur 4 jusqu'au 29/08 —
        ; leur ordre de recouvrement etait alors indetermine.
        ldb   cpl.part,u
        ldx   #cpl.prio
        abx
        ldb   ,x
        stb   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ; A7A4 : QUARANTE POINTS DE VIE par piece. Chez nous le champ de
        ; potentiel de la boite EST le compteur — le moteur le decremente a
        ; chaque coup, et zero vaut mort (meme idiome que le monstre du
        ; stage 1, cf. dobkeratops/monster.asm).
        _Collision_AddAABB AABB_0,AABB_list_ennemy
        lda   #cpl.PART_HP
        sta   AABB_0+AABB.p,u
        sta   cpl.hp.prev,u
        clr   cpl.hit,u
        ldb   cpl.part,u
        aslb
        ldx   #cpl.hitbox
        abx
        ldd   ,x
        std   AABB_0+AABB.rx,u
        inc   routine,u                ; -> PartLive
        lbra  PartLive.draw

; ---------------------------------------------------------------------------
; PartLive — AFE6 (motion_step) : la derive du segment courant
;
; BLOC 1 : le seul segment est celui de l'intro. Quand son compte tombe, la
; partie s'immobilise — la borne enchainerait sur les scripts de combat.
; ---------------------------------------------------------------------------
PartLive
        ; ARCADE v4 (0x40F7F1) : les trois pieces testent les bit devices SANS
        ; le force pod — immunisees au contact du pod, pas a celui des bits.
        ; Presence posee chaque trame, consommee par WeaponContactTick
        ; (src/common/lib/collisionpass.unit.asm).
        lda   #1
        sta   weaponPodImmune
        ldd   cpl.timer,u
        ; SEGMENT EPUISE : on prend le suivant. C'est motion_step (AFE6) — la
        ; piece enchaine les segments de son script, puis les scripts de sa
        ; config. Elle s'immobilisait ici jusqu'au 29/08, faute de scripts.
        ; (Le saut visait PartLive.draw un temps plus tot encore : il passait
        ; par-dessus le bloc des armes, et les pieces se taisaient apres
        ; l'intro.)
        bne   >
        lbsr  cpl.motion.next
        lbra  PartLive.armed
!
        ldb   gfxlock.frameDrop.count  ; le decompte suit l'horloge de jeu
        clra
        pshs  d
        ldd   cpl.timer,u
        subd  ,s++
        bhi   >
        ldd   #0                       ; le segment est fini
!       std   cpl.timer,u
        ; le pas du segment, compense par le frame drop
        ldd   cpl.vx,u
        lbsr  cpl.step
        jsr   moveXPos8.8
        ; ET LA VERTICALE : l'intro n'en avait pas, les scripts de combat si.
        ldb   cpl.vy,u
        sex                            ; l'octet signe redevient un 8.8
        aslb
        rola                           ; B03B : le x2 de combat (voir @segment)
        lbsr  cpl.step
        jsr   moveYPos8.8
PartLive.armed
        ; LES ARMES DE LA PIECE. La DROITE (0) et la GAUCHE (2) envoient leurs
        ; lasers horizontaux ; la gauche a en plus son laser roulant. La piece
        ; du bas n'a pas d'arme propre — ses deux tourelles vivent dans leurs
        ; propres slots.
        ; TOUS LES CHEMINS REJOIGNENT PartLive.hurt : le controle de degats
        ; doit tourner a chaque trame. Ce bloc tombait dans cpl.fire par
        ; simple voisinage jusqu'au 29/08 — la piece gauche l'executait deux
        ; fois puis continuait dans le spawner.
        ldb   cpl.part,u
        beq   @tire
        cmpb  #2
        lbne  PartLive.hurt
@tire   lbsr  cpl.fire
        ldb   cpl.part,u
        cmpb  #2
        lbne  PartLive.hurt
        lbsr  cpl.wave.tick
        lbra  PartLive.hurt
; FIX #2 : NE DESSINER QU'ENTIER A L'ECRAN. Les sprites compiles ne clippent
; pas — l'arcade spawne a x ecran -16 et laisse son MATERIEL rogner, nous
; n'avons pas ce luxe : le dessin partiel d'une piece de 66 px a -16 ecrivait
; hors du champ et CORROMPAIT la RAM residente (pscroll.res, atteste par
; l'anneau de trace : pscroll.do saute en $0050 des le spawn du boss, machine
; figee — le « gel a la camera 929 » des essais precedents, qui etait en fait
; le gel A L'HEURE DE WAVE DU BOSS). Pendant la derive d'intro, chaque piece
; apparait quand son bord gauche franchit le bord de l'ecran ; sa position
; finale (x = 116) est entiere a l'ecran.
; ---------------------------------------------------------------------------
; cpl.step — le pas d'un tick, pour une vitesse 8.8 SIGNEE
; ---------------------------------------------------------------------------
; entree : [d] la vitesse du segment, signee     sortie : [d] le pas du tour
;
; Le piege qu'elle ferme (29/08) : l'idiome maison `ldb #PAS / mul / _negd`
; suppose une MAGNITUDE dans B, et les ennemis l'emploient avec une constante
; positive. Les scripts du boss, eux, portent des vitesses signees en
; complement a deux — et l'octet bas de -72 ($FFB8) vaut 184, pas 72. Les
; segments negatifs partaient donc DEUX FOIS ET DEMIE trop vite, et les pieces
; sortaient de l'ecran en quelques secondes (releve auteur ; l'intro, dont la
; vitesse est positive, etait juste — c'est ce qui a mis sur la piste).
; On prend donc la valeur absolue, on multiplie, on remet le signe.
; ---------------------------------------------------------------------------
; Le produit est 16x8 (29/08) : il etait 8x8, l'octet bas seul passait au
; MUL. Suffisant pour les scripts (magnitudes <= 240 une fois doublees), faux
; pour le laser horizontal ($0120 = 288 -> il volait sur son octet bas, 32,
; NEUF fois trop lent) et pour le laser roulant (wav.life $0358 = 856 -> 88).
; Domaine : magnitude x trames doit tenir en 16 bits (ici <= 856 x 8).
cpl.step
        pshs  a                        ; le signe d'origine (PSHS ne touche
        bpl   >                        ;   pas les indicateurs du LDD)
        _negd                          ; D = la magnitude
!       pshs  b                        ; l'octet bas, pour le second produit
        ldb   gfxlock.frameDrop.count
        mul                            ; octet haut x trames : tient dans B
        tfr   b,a                      ;   et pese 256 fois plus
        puls  b                        ; l'octet bas de la magnitude
        pshs  a                        ; le produit haut, en attente
        lda   gfxlock.frameDrop.count
        mul                            ; D = octet bas x trames
        adda  ,s+                      ; + (haut x trames) << 8
        tst   ,s+
        bpl   >
        _negd                          ; et le signe revient
!       rts

; ---------------------------------------------------------------------------
; cpl.motion.next — AFE6 : le segment suivant du script de combat
; ---------------------------------------------------------------------------
; Un segment fait trois mots : vitesse x, vitesse y, duree. La sentinelle
; $8000 en x termine le script — on passe alors au suivant de la config, et
; apres le troisieme on reboucle sur le premier.
; V2-DEVIATION : la borne, elle, ne reboucle pas — son terminateur declenche
; l'AUTO-DESTRUCTION de la piece (~3,6 min si le joueur ne fait rien). Ce
; renoncement lui appartient ; ici la piece se bat tant qu'on ne l'abat pas,
; ce qui est aussi ce que le stage attend depuis qu'il ne gagne plus au
; compteur.
; ---------------------------------------------------------------------------
cpl.motion.next
        ; la config de la piece : trois lignes de trois mots, une par tirage
        ldb   cpl.part,u
        aslb
        ldx   #cpl.cfg.index
        ldx   b,x                      ; les trois configs de CETTE piece
        ldb   cpl.cfg,u
        aslb                           ; six octets par ligne (trois mots)
        pshs  b
        aslb
        addb  ,s+
        abx                            ; x = la config tiree
        ; le script courant, dans les bits hauts du curseur
        ldb   cpl.cursor,u
        lsrb
        lsrb
        lsrb
        lsrb
        lsrb                           ; b = index du script (0..2)
        aslb
        ldx   b,x                      ; x = le script
        ; le segment courant, dans les bits bas
        ldb   cpl.cursor,u
        andb  #cpl.CUR_SEG
        aslb                           ; six octets par segment
        pshs  b
        aslb
        addb  ,s+
        abx
        ldd   ,x                       ; la vitesse x, ou la sentinelle
        cmpd  #$8000
        bne   @segment
        ; fin du script : au suivant de la config. Le segment repart a zero,
        ; d'ou le curseur reconstruit entier.
        lda   cpl.cursor,u
        lsra
        lsra
        lsra
        lsra
        lsra
        inca
        cmpa  #3
        blo   >
        lbra  cpl.motion.suicide       ; les trois epuises : elle renonce
!       asla                            ; on le remet en bits hauts
        asla
        asla
        asla
        asla
        sta   cpl.cursor,u             ; (segment = 0, il vient d'etre efface)
        bra   cpl.motion.next          ; et on lit son premier segment
@segment
        ; B032/B044 — LE TEMPO DE COMBAT EST DOUBLE (rate, puis releve le
        ; 29/08). A chaque lecture de segment, la borne DOUBLE les deux
        ; vitesses et DIVISE la duree par deux : meme deplacement, joue deux
        ; fois plus vite. Seule l'intro (chargee par l'init, sans passer par
        ; ce chemin) reste a vitesse simple. Sans ce doublement, toute la
        ; choregraphie se jouait a la moitie du tempo — en side-by-side avec
        ; l'arcade, la sequence devenait meconnaissable (releve auteur). Les
        ; tables generees restent les valeurs ROM brutes : le doublement est
        ; un geste d'execution, comme sur la borne.
        aslb
        rola                           ; vx x2
        std   cpl.vx,u
        ldd   4,x                      ; la duree
        lsra
        rorb                           ; duree /2
        std   cpl.timer,u
        ldb   2+1,x                    ; la vitesse y : appliquee tout de
        stb   cpl.vy,u                 ;   suite (doublee a l'application —
        inc   cpl.cursor,u             ;   x2 deborde de l'octet au stockage)
        rts

; ---------------------------------------------------------------------------
; cpl.motion.suicide — AFE6, le terminateur : L'AUTO-DESTRUCTION
; ---------------------------------------------------------------------------
; Au bout de sa chaine de trois scripts, la borne ne reboucle pas : la piece
; RENONCE. Elle fige une derive vers la droite (+0x200 en 8.8, soit 2 px par
; trame arcade), et son bit de mort est diffuse au parent — le moniteur de
; combat la compte pour tombee, exactement comme si le joueur l'avait abattue.
; Un boss laisse donc partir ses pieces au bout d'environ trois minutes et
; demie si personne ne le combat.
;
; Elle ne s'eteint PAS ici : elle continue d'exister et de deriver, hors de
; l'ecran a terme. C'est ce que fait la borne, et cela laisse le joueur voir
; le boss s'en aller.
;
; Le curseur porte l'etat : son index de script passe a TROIS, valeur qu'un
; enchainement normal n'atteint jamais. Elle vaut « deja renonce » et empeche
; de compter la mort deux fois — la piece garde ses points de vie, on peut
; encore l'abattre en chemin.
; ---------------------------------------------------------------------------
cpl.motion.suicide
        lda   cpl.cursor,u
        cmpa  #3*cpl.CUR_STEP
        bhs   @deja
        lda   #3*cpl.CUR_STEP          ; l'etat « a renonce »
        sta   cpl.cursor,u
        inc   globals.compilerDead     ; sa mort est annoncee, comme un abattage
@deja   ldd   #cpl.SUICIDE_VX
        std   cpl.vx,u
        clr   cpl.vy,u
        ldd   #$FFFF                   ; une duree que rien n'epuise
        std   cpl.timer,u
        rts

; ---------------------------------------------------------------------------
; cpl.fire — AB01 (droite) / ADFB (gauche) : la salve de lasers horizontaux
; ---------------------------------------------------------------------------
; La borne decide a chaque trame, pour la partie droite comme pour la gauche :
;   - le joueur doit etre A DROITE de la piece (elle tire vers la gauche) ;
;   - il doit etre dans une fenetre verticale, comptee depuis la piece :
;     0..0x50 px arcade pour la droite, 0..0x30 pour la gauche — la piece
;     gauche vise plus serre ;
;   - un compteur de cadence doit tomber a zero ; il se recharge alors depuis
;     la valeur de difficulte (nous prenons la premiere, comme tout le cast).
; Le laser nait devant la piece (+0x50 px arcade a droite, +0x10 a gauche,
; donc DANS le corps) a une hauteur tiree d'un pool de huit offsets, et part
; vers la gauche a 3 px/trame arcade.
; ---------------------------------------------------------------------------
cpl.fire
        ; ORDRE DES CONTROLES (AB01, releve le 29/08) : la borne teste les
        ; positions AVANT de toucher au compteur. Le compteur GELE donc tant
        ; que le joueur n'est pas en vue — sortir de la fenetre et y revenir
        ; ne vaut pas une salve immediate. Ma premiere version lisait une
        ; cadence sans etat dans l'horloge de jeu, ce qui inversait cet ordre.
        ;
        ; GARDE DE VISIBILITE — ECART ASSUME. La borne n'en a pas besoin : ses
        ; pieces naissent POSEES a x=0x100, donc a droite du joueur, et le
        ; controle « joueur devant » les fait taire jusqu'au combat. Notre
        ; intro les fait ENTRER par la gauche (SPAWN_X = -16) : le meme
        ; controle devient vrai des la naissance, et le boss tirait pendant
        ; toute son approche, hors de l'ecran (releve auteur ; mesure sous
        ; toje : 3 lasers nes alors que la piece etait encore a x ecran -8).
        ldd   x_pos,u
        subd  glb_camera_x_pos         ; x ecran du centre
        bmi   @wait                    ; le centre n'est meme pas entre
        pshs  x,b,a
        ldx   #cpl.halfw
        ldb   cpl.part,u
        abx
        clra
        ldb   ,x                       ; D = la demi-largeur de CETTE piece
        cmpd  ,s                       ; face au x ecran empile
        puls  a,b,x                    ; (PULS ne touche pas aux indicateurs)
        bhi   @wait                    ; pas encore ENTIEREMENT entree
        ; --- AB01 : le joueur devant, et dans la fenetre ------------------
        ldd   player1+x_pos
        subd  x_pos,u
        bmi   @wait                    ; il est DERRIERE la piece
        ldd   player1+y_pos
        subd  y_pos,u
        addd  #cpl.FIRE_WINY0
        bmi   @wait                    ; au-dessus de la fenetre
        ldb   cpl.part,u
        cmpb  #2                       ; 2 = la piece GAUCHE, fenetre serree
        beq   @gauche
        cmpd  #cpl.FIRE_WINY_R
        bra   @teste
@gauche cmpd  #cpl.FIRE_WINY_L
@teste  bhi   @wait                    ; sous la fenetre
        ; --- AB19 : et seulement maintenant, la cadence -------------------
        lda   cpl.cad,u
        suba  gfxlock.frameDrop.count
        bhi   @garde                   ; le compte n'est pas epuise
        lda   #cpl.FIRE_PERIOD         ; AB1E : il se recharge sur la salve
        sta   cpl.cad,u
        bsr   cpl.laser.spawn
        rts
@garde  sta   cpl.cad,u
@wait   rts

; ---------------------------------------------------------------------------
; cpl.laser.spawn — AB3A : un laser, devant la piece, a hauteur tiree
; ---------------------------------------------------------------------------
cpl.laser.spawn
        jsr   LoadObject_x
        beq   @none                    ; pool plein : pas de tir, la borne
                                       ; renonce aussi
        lda   #ObjID_compilerlaser
        sta   id,x
        lda   #5                       ; -> LaserInit
        sta   routine,x
        ; X PORTE L'OST DU LASER — on le met a l'abri le temps de lire les
        ; tables. Sans cela le `ldx #cpl.prio` ci-dessous l'ecrasait et TOUT
        ; ce qui suit ecrivait dans la table de priorites au lieu du
        ; projectile : le laser naissait sans position ni profondeur, et la
        ; table qu'il ecrasait servait aux pieces (releve sous toje : la piece
        ; droite bloquee sur son premier segment, duree de segment a 27604 la
        ; ou le script en donne 256).
        pshs  x
        ; La borne place le laser JUSTE DERRIERE sa piece (0x401F contre
        ; 0x4020 a droite, 0x3FFF contre 0x4000 a gauche) : d'un cran, donc,
        ; et c'est le spawner qui le sait.
        ldb   cpl.part,u
        ldx   #cpl.prio
        abx
        ldb   ,x
        incb
        puls  x
        stb   priority,x
        ; la hauteur : un des huit offsets du pool de la piece
        jsr   RandomNumber
        andb  #7
        aslb
        ldy   #cpl.laser.poolR
        lda   cpl.part,u
        cmpa  #2
        bne   >
        ldy   #cpl.laser.poolL         ; la piece gauche a son propre pool
!       ldd   b,y
        addd  y_pos,u
        std   y_pos,x
        ; l'avance : devant la piece a droite, dans le corps a gauche
        ldd   #cpl.FIRE_AHEAD_R
        lda   cpl.part,u
        cmpa  #2
        bne   >
        ldd   #cpl.FIRE_AHEAD_L
!       addd  x_pos,u
        std   x_pos,x
        clr   x_sub,x
        clr   y_sub,x
@none   rts

; ---------------------------------------------------------------------------
; cpl.wave.tick — AD5C : la fenetre de tir du laser roulant
; ---------------------------------------------------------------------------
; La borne ouvre une fenetre de 64 trames et lache une PAIRE de segments
; toutes les 16 trames — quatre paires par fenetre, puis un long silence. Le
; declenchement d'origine tient a la hauteur de la piece et a un compteur de
; son script de combat ; celui-ci n'etant pas encore porte (bloc 1 : l'intro
; seule), on garde le RYTHME de la borne — quatre paires, puis la pause — et
; c'est le compteur de l'objet qui l'entretient.
; ---------------------------------------------------------------------------
cpl.wave.tick
        ; UN DECOMPTE, PAS UN TEST D'EGALITE. Un tick vaut ici jusqu'a huit
        ; trames de jeu : un compteur qui avance de sept ne tombe jamais
        ; PILE sur un multiple de seize, et rien ne partait (constat sous
        ; toje). Meme piege que la fenetre d'engagement du geld.
        ; Ses deux compteurs sont GLOBAUX : voir globals.cplWave dans
        ; variables.asm — sur la piece ils tombaient sur cpl.vy.
        lda   globals.cplWave
        suba  gfxlock.frameDrop.count
        bhi   @wait
        bsr   cpl.wave.pair
        ; QUATRE paires puis un silence : c'est le rythme de la borne, sa
        ; fenetre de 0x40 trames en laissant partir une toutes les seize.
        inc   globals.cplWavePair
        lda   globals.cplWavePair
        anda  #3
        bne   >
        lda   #cpl.WAVE_PAUSE          ; la fenetre se referme
        bra   @wait
!       lda   #cpl.WAVE_GAP            ; seize trames jusqu'a la suivante
@wait   sta   globals.cplWave
        rts

; ---------------------------------------------------------------------------
; cpl.wave.pair — AE5C : DEUX segments, l'un derriere l'autre
; ---------------------------------------------------------------------------
cpl.wave.pair
        ldb   #2                       ; la borne en lance deux, jamais un
@one    pshs  b
        jsr   LoadObject_x
        beq   @done                    ; pool plein : la borne renonce aussi,
                                       ; et n'essaie meme pas le second
        lda   #ObjID_compilerwave
        sta   id,x
        lda   #9                       ; -> WaveInit
        sta   routine,x
        ; le second segment nait plus a gauche que le premier
        ; On BRANCHE avant de composer D : un `ldb ,s` place apres le `ldd`
        ; en ecraserait l'octet bas — la faute deja faite sur le creusement du
        ; geld, et sur le cap de son virage.
        ldb   ,s
        cmpb  #2
        beq   @premier
        ldd   #cpl.WAVE_DX2            ; le second nait plus a gauche
        bra   @posex
@premier ldd  #cpl.WAVE_DX1
@posex  addd  x_pos,u
        std   x_pos,x
        ldd   #cpl.WAVE_DY
        addd  y_pos,u
        std   y_pos,x
        clr   x_sub,x
        clr   y_sub,x
@done   puls  b
        decb
        bne   @one
        rts

PartLive.hurt
        ; AA0F point 6 : la boite a-t-elle perdu du potentiel depuis la trame
        ; d'avant ? Alors le coup vient d'entrer — la borne joue son SFX et
        ; arme 0x1F trames de clignotement.
        lda   AABB_0+AABB.p,u
        lbeq  cpl.part.die
        cmpa  cpl.hp.prev,u
        bhs   @noHit
        ldb   #cpl.HIT_FLASH
        stb   cpl.hit,u
        ; V2-DEVIATION : la borne joue ici son SFX 0x56 (le « ping » du coup
        ; encaisse). Notre banque de bruitages n'en a pas d'equivalent — le
        ; clignotement porte seul le retour au joueur.
@noHit  sta   cpl.hp.prev,u
        ; le clignotement : une trame sur deux sautee tant qu'il court
        lda   cpl.hit,u
        beq   PartLive.draw
        suba  gfxlock.frameDrop.count
        bhi   >
        clra
!       sta   cpl.hit,u
        anda  #2                       ; deux trames visibles, deux non
        bne   PartLive.draw
        rts                            ; sautee : la piece disparait ce tour

PartLive.draw
        ldb   cpl.part,u
        ldx   #cpl.halfw
        abx
        ldb   ,x                       ; la demi-largeur de CETTE piece
        clra
        pshs  d
        ldd   x_pos,u
        subd  glb_camera_x_pos         ; x ecran du centre
        subd  ,s                       ; le bord gauche depasse ?
        bmi   @hide
        addd  ,s
        addd  ,s++                     ; le bord droit depasse ?
        cmpd  #cpl.SCREEN_W
        bhi   @hide2
        jmp   DisplaySprite
@hide   leas  2,s
@hide2  rts

; ---------------------------------------------------------------------------
; LaserInit / LaserFly — E6AB : le laser horizontal du Compiler
; ---------------------------------------------------------------------------
; Il vole vers la GAUCHE a vitesse constante, cycle sur quatre poses, et tue
; le joueur au contact (la borne pose player_one_die_flag). Il ne rebondit
; pas, ne vise pas : c'est un rideau que le joueur doit eviter.
; V2-DEVIATION : pas de selecteur de difficulte — on prend la premiere entree
; de la table de vitesses (0x1000:5848), comme tout le cast.
; ---------------------------------------------------------------------------
LaserInit
        ldd   #cpl.LASER_VX
        std   cpl.laser.vx,u
        ; (la profondeur est posee par le spawner, elle suit la piece)
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        _Collision_AddAABB AABB_0,AABB_list_ennemy
        lda   #compilerlaser_hitdamage
        sta   AABB_0+AABB.p,u
        _ldd  compilerlaser_hitbox_x,compilerlaser_hitbox_y
        std   AABB_0+AABB.rx,u
        inc   routine,u                ; -> LaserFly
LaserFly
        ; il avance, puis se montre — l'ordre de la borne
        ldd   cpl.laser.vx,u
        _negd                          ; vers la gauche
        lbsr  cpl.step
        jsr   moveXPos8.8
        ; quatre poses, deux trames chacune (frame_duration 2 au catalogue)
        lda   gfxlock.frame.count+1
        lsra
        anda  #3
        asla
        ldx   #cpl.laser.images
        ldd   a,x
        std   image_set,u
        ; sorti par la gauche ? le laser ne revient jamais
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u
        addd  #compilerlaser_hitbox_x
        bmi   @gone
        ldd   y_pos,u
        stb   AABB_0+AABB.cy,u
        jmp   DisplaySprite
@gone   lda   #4                       ; -> AlreadyDeleted
        sta   routine,u
        _Collision_RemoveAABB AABB_0,AABB_list_ennemy
        jmp   DeleteObject

; ---------------------------------------------------------------------------
; TurretInit / TurretRun — AC4C : une tourelle, portee et pivotante
; ---------------------------------------------------------------------------
; Elle ne se deplace pas d'elle-meme : sa position EST celle de sa piece plus
; son decalage, relue a chaque trame. Elle pivote vers le joueur — la borne
; appelle set_direction_to puis lit deux tables entrelacees (0x1000:5870) pour
; la pose et son attribut de miroir. Chez nous l'export a deja produit UNE
; POSE PAR DIRECTION (seize, tirees par cette meme table) : le miroir est
; cuit dans l'image, l'index suffit.
; Elle tire par le tryFoeFire commun, celui de cancer et du geld, avec son
; propre motif — et pas a la premiere trame, la borne attend d'avoir vise.
; ---------------------------------------------------------------------------
TurretInit
        ldb   subtype_w+1,u            ; le motif de tir de CETTE tourelle
        _loadFirePreset
        ldb   #cpl.PRIO_TURRET         ; la borne les met DEVANT la piece du
        stb   priority,u               ;   bas (0x4011/12 contre son 0x4010)
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        clr   cpl.tur.dir,u            ; pas de tir tant qu'on n'a pas vise
        _Collision_AddAABB AABB_0,AABB_list_ennemy
        lda   #compilerturret_hitdamage
        sta   AABB_0+AABB.p,u
        _ldd  compilerturret_hitbox_x,compilerturret_hitbox_y
        std   AABB_0+AABB.rx,u
        inc   routine,u                ; -> TurretRun
TurretRun
        ; AC4C : elle ne tire QUE si elle a deja vise une fois
        tst   cpl.tur.dir,u
        beq   >
        jsr   tryFoeFire
        ; AC56 : sa position suit celle de sa piece, decalage compris
!       ldx   cpl.tur.parent,u
        beq   @orphan
        lda   id,x
        cmpa  #ObjID_compilerpart
        bne   @orphan                  ; la piece a rendu son slot : on suit
        ldb   cpl.tur.offx,u
        sex
        addd  x_pos,x
        std   x_pos,u
        ldb   cpl.tur.offy,u
        sex
        addd  y_pos,x
        std   y_pos,u
        ; AC6B : viser le joueur, et en tirer la pose
        ldx   #player1
        jsr   setDirectionTo           ; Y = 0,4,8..$3C, l'index de la borne
        tfr   y,d
        stb   cpl.tur.dir,u
        lsrb                           ; /4 : une pose par direction
        lsrb
        ldx   #cpl.turret.images
        aslb                           ; deux octets par pointeur
        ldd   b,x
        std   image_set,u
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u
        ldd   y_pos,u
        stb   AABB_0+AABB.cy,u
        jmp   DisplaySprite
@orphan lda   #4                       ; -> AlreadyDeleted
        sta   routine,u
        _Collision_RemoveAABB AABB_0,AABB_list_ennemy
        jmp   DeleteObject

; ---------------------------------------------------------------------------
; WaveInit / WaveFly — AEFB : un segment du laser roulant
; ---------------------------------------------------------------------------
; Il part a l'horizontale d'un cote TIRE AU SORT, monte en ralentissant, et
; s'eteint quand son compte tombe. Chez la borne, le mot [+0x20] sert aux DEUX
; a la fois : c'est la vitesse verticale ET le compte a rebours, decremente
; d'un pas fixe chaque trame — le segment ralentit donc en vieillissant, et
; c'est ce qui donne la courbe. On garde ce double emploi tel quel.
; La pose ne s'anime PAS : chaque segment en prend une, fixe pour sa vie ; le
; « roulement » vient chez elle du cyclage de palette (kind 0x56), que nous
; n'avons pas — nos quatre poses different assez pour que la paire se lise.
; ---------------------------------------------------------------------------
WaveInit
        jsr   RandomNumber
        pshs  b                        ; le meme tirage sert deux fois
        andb  #$3F                     ; la magnitude horizontale
        addb  #cpl.WAVE_VX0
        clra
        tst   ,s                       ; ... et son bit 5 donne le sens
        bpl   >
        _negd
!       std   cpl.wav.vx,u
        jsr   RandomNumber
        andb  #1                       ; la duree : deux paliers, comme la
        clra                           ;   plage 0x280..0x47F de la borne
        beq   >
        ldd   #cpl.WAVE_LIFE1
        bra   @life
!       ldd   #cpl.WAVE_LIFE0
@life   std   cpl.wav.life,u
        ; la pose, fixe pour toute la vie du segment : le slot la choisit
        puls  b
        andb  #3
        aslb
        ldx   #cpl.wave.images
        ldd   b,x
        std   image_set,u
        ; AU FOND. La borne lui donne 0x C000 — en signe, tres loin derriere
        ; tout le reste. Elle valait 2 chez nous jusqu'au 29/08, soit presque
        ; au premier plan : l'ordre etait INVERSE.
        ldb   #cpl.PRIO_WAVE
        stb   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        _Collision_AddAABB AABB_0,AABB_list_ennemy
        lda   #compilerwave_hitdamage
        sta   AABB_0+AABB.p,u
        _ldd  compilerwave_hitbox_x,compilerwave_hitbox_y
        std   AABB_0+AABB.rx,u
        inc   routine,u                ; -> WaveFly
WaveFly
        ; l'horizontale : sa vitesse ne change pas, et elle est SIGNEE — le
        ; cote de depart est tire au sort.
        ldd   cpl.wav.vx,u
        lbsr  cpl.step
        jsr   moveXPos8.8
        ; la verticale : la vitesse EST le compte a rebours, il ralentit
        ldd   cpl.wav.life,u
        _negd                          ; il monte (l'axe y de la borne monte)
        lbsr  cpl.step
        jsr   moveYPos8.8
        ldd   cpl.wav.life,u
        subd  #cpl.WAVE_DECAY
        bls   @gone
        std   cpl.wav.life,u
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u
        addd  #compilerwave_hitbox_x
        bmi   @gone
        cmpd  #cpl.SCREEN_W+compilerwave_hitbox_x*2
        bhi   @gone
        ldd   y_pos,u
        bmi   @gone
        stb   AABB_0+AABB.cy,u
        jmp   DisplaySprite
@gone   lda   #4                       ; -> AlreadyDeleted
        sta   routine,u
        _Collision_RemoveAABB AABB_0,AABB_list_ennemy
        jmp   DeleteObject

; ---------------------------------------------------------------------------
; cpl.part.die / PartBoom — B062 : le chapelet d'explosions d'une piece
; ---------------------------------------------------------------------------
; La borne n'eteint pas la piece d'un coup : elle installe un MARCHEUR qui
; parcourt une liste d'offsets pendant 64 trames et seme une explosion a
; chacun, une trame sur deux. Chaque piece a sa liste — le nuage fleurit
; differemment selon celle qu'on abat (gen/enemies/compiler/explosions.asm).
; La piece cesse alors de tirer, de bouger et d'encaisser : seul le nuage
; vit. Sa mort est annoncee a l'orchestrateur, qui compte.
; ---------------------------------------------------------------------------
cpl.part.die
        _Collision_RemoveAABB AABB_0,AABB_list_ennemy
        ; l'orchestrateur tient le compte des pieces tombees
        inc   globals.compilerDead
        clr   cpl.boom.cur,u
        lda   #cpl.BOOM_FRAMES
        sta   cpl.boom.tick,u
        lda   #10                      ; -> PartBoom
        sta   routine,u
        rts

PartBoom
        ; une trame sur deux, comme la borne (elle teste la parite du compteur
        ; global) — ici le compte a rebours en fait office.
        lda   cpl.boom.tick,u
        suba  gfxlock.frameDrop.count
        bls   @fini
        sta   cpl.boom.tick,u
        bita  #1
        bne   @rts
        ; l'entree suivante du chapelet, tant qu'il en reste
        ldb   cpl.part,u
        ldx   #cpl.boom.count
        abx
        lda   cpl.boom.cur,u
        cmpa  ,x
        bhs   @rts                     ; liste epuisee : le nuage s'eteint
        inc   cpl.boom.cur,u
        ldb   cpl.part,u
        aslb
        ldx   #cpl.boom.index
        ldx   b,x                      ; la liste de CETTE piece
        lda   cpl.boom.cur,u
        deca
        asla                            ; deux octets par entree
        leax  a,x
        pshs  x
        jsr   LoadObject_x
        beq   @pop
        _ldd  ObjID_explosion,explosion.subtype.smallx3+explosion.sfx.cascade2
        std   id,x
        ldy   ,s                       ; l'entree, remise de la pile
        ldb   ,y                       ; dx, signe
        sex
        addd  x_pos,u
        std   x_pos,x
        ldb   1,y                      ; dy, signe
        sex
        addd  y_pos,u
        std   y_pos,x
@pop    puls  x
@rts    rts
@fini   lda   #4                       ; -> AlreadyDeleted
        sta   routine,u
        jmp   DeleteObject

AlreadyDeleted
        rts
