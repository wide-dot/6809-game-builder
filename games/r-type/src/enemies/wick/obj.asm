;*******************************************************************************
; wick — SQUELETTE, avec sa FICHE DE PORTAGE complete (relevee le 26/08/2026)
;
; Le bestiaire le donne pour « voyage en groupe », « non agressif »,
; « une distraction au mauvais moment ». Les trois se lisent dans le code.
;
; LA LIGNE DE WAVE NE SPAWNE PAS UN WICK : elle spawne un EMETTEUR INVISIBLE
; qui en pond une nuee. Un seul spawn au stage 2 ($06,$54 = t 1620, camera 304).
;
; FICHE DE PORTAGE (base Ghidra `maincpu`, subsystem wick)
; -------------------------------------------------------------------------
;   40:875d create_wick_emitter ........ le spawner de l emetteur
;   40:8798 run_wick_emitter ........... son tick — INVISIBLE, sans collision
;   40:87ba wick_emitter_script_step ... la timeline de densite
;   40:8817 wick_emitter_spawn ......... pond UN wick
;   40:8861 run_wick ................... le wick visible, etat DERIVE
;   40:893e run_wick_aim_attack ........ etat PIQUE, terminal
;   1000:3afe timeline   3b12 difficultes   3b22 dispatch de pique
;   1000:3b2a vitesses de derive   3b32/3bb2 poses   3c12 l AABB
;
; L EMETTEUR. Ne se dessine pas, ne collisionne pas, ne suit PAS le decor —
; son tick ne lit pas 0x2ED0 (verifie sur les octets, pas sur les xrefs). Il
; reste donc a une abscisse ECRAN fixe pendant toute sa vie, et c est ce qui
; fait que ses wicks entrent toujours par le meme bord. Chez nous, ou les
; coordonnees sont monde, cela veut dire calculer le point de ponte a chaque
; emission — camera + 152 — plutot que de porter une position.
;   naissance (704, 288) arcade  ->  x = 152, y = 81
;   duree de vie $0600 = 1536 trames de jeu, puis retrait silencieux
;   periode d emission $40, salve 4, ancre Y des wicks $0130 -> 69
;
; LA TIMELINE DE DENSITE (1000:3afe), quatre mutations puis fin. Le seuil est
; le compteur de trames de l emetteur ; les deux bits de poids fort de
; l opcode choisissent la cible, les douze bas portent la valeur :
;   t=8    ancre Y      := $00D0 (208 arcade) -> 141
;   t=16   periode      := 36
;   t=64   salve        := 3
;   t=192  ancre Y      := $0110 (272 arcade) ->  93
; ATTENTION : le prereglage de DIFFICULTE est recharge a CHAQUE trame AVANT
; les mutations du script — le script se pose par-dessus le plancher, il ne
; le remplace pas. A la difficulte 0, celle du reste du cast : periode 36,
; salve 3. La periode posee par le ctor ($40) ne vit donc que 16 trames.
;
; LA PONTE (40:8817). L enfant nait a (x de l emetteur, y - 32 + rand[0..63]),
; le tirage evitant que la nuee s empile. L axe Y arcade monte : chez nous
;   y_enfant = y_emetteur + 24 - (rand[0..63] x 0,75)
; soit une dispersion de 48 px larges sous l ancre.
; LA REGLE DE SALVE, et c est elle qui fait le comportement : chaque ponte
; decremente le compte de salve ; au passage a zero SEULEMENT, le nouveau wick
; recoit un delai de pique tire dans [0..255]. Les autres recoivent ZERO et ne
; piqueront JAMAIS. Un wick sur trois pique, et c est le dernier de sa salve.
;
; L ETAT DERIVE (40:8861). Il suit le decor (il lit bien 0x2ED0).
;   X : defilement + vitesse propre, -1,5 px/trame arcade a la difficulte 0,
;       soit -0,5625 v2 — exactement la vitesse primaire du gouger.
;   Y : DEUX composantes qui s ajoutent —
;         . un rattrapage lent vers (ancre du parent + rand[-32..+31]) a
;           +/-0,0625 px/trame arcade (0,046875 v2)
;         . un CRENEAU de +/-0,25 px/trame arcade (0,1875 v2) commande par le
;           bit 6 d un compteur : amplitude ~32 px arcade (24 v2), periode
;           128 trames. C est l ondulation de tetard.
;   Poses : 4 images, tenues 4 trames, periode 16.
;
; L ETAT PIQUE (40:893e), TERMINAL — aucun retour a la derive. La vitesse est
; echantillonnee UNE FOIS dans wick_aim_motion_dispatch par (difficulte x 2 +
; direction) : ce n est pas un poursuivant, il part en ligne droite et ne
; corrige plus. La pose depend de la direction (selecteur par octant, 3b32).
;
; MORT : au premier coup (AABB 1000:3c12, rayon 8 arcade sur les deux axes ->
; 3 en X et 6 en Y), score $86E8 — le plus bas de la table —, son 0x54,
; explosion_special 40:e7a6.
;
; LA NUMEROTATION DES POSES, et c'est un piege silencieux. Les 32 PNG de
; images/animation sortent d'un balayage lineaire de 0x13B52 a 0x13C11, six
; octets par recette — leurs noms d'origine portent l'adresse. Or
; wick_sprite_recipes commence en 0x13BB2, soit 96 octets plus loin :
;   PNG 00..15 = les DIRECTIONS du pique (wick_aim_sprite_recipes...)
;   PNG 16..31 = wick_sprite_recipes, dont 16..19 SEULEMENT sont le cycle
;                de derive (idx*6, idx = 0..3)
; Prendre 00..03 pour le cycle donnerait l'art du pique en derive, sans que
; rien ne le signale. Verifie sur le nom : 016_013bb2.png.
;
; LA COMPENSATION DE TRAME. Toutes les horloges ci-dessus sont des horloges
; d'ARCADE, une trame = un tour. Le portage tourne par trame RENDUE, sept fois
; plus lentement : chacune doit avancer de gfxlock.frameDrop.count. Sont
; concernees la duree de vie, le compteur de timeline, le compte a rebours
; d'emission (qui peut donc devoir pondre PLUSIEURS fois dans une trame
; rendue), le delai de pique, la phase d'ondulation, le compteur d'animation,
; et bien sur les trois vitesses.
;
; A LA DIFFICULTE 0, celle du reste du cast, LA TIMELINE NE DEPLACE QUE
; L'ANCRE Y. Le plancher de difficulte est recharge a chaque trame AVANT les
; mutations : les valeurs qu'il pose (periode 36, salve 3) sont exactement
; celles que le script ecrit a t=16 et t=64, donc ces deux mutations sont
; effacees des la trame suivante et n'ont aucun effet. Meme sort pour la
; periode $40 et la salve 4 posees par le constructeur : elles vivent UNE
; trame. Ce n'est pas une simplification de notre part, c'est ce que la
; machine fait.
;
; CE QUI DEMANDERA UN ARBITRAGE
; - le pique est un second chantier : il demande la table de directions
;   (1000:3b32) et les seize poses orientees. La derive d'abord.
; - la difficulte : on prend la 0 comme le reste du cast, donc la timeline ne
;   change que l ancre Y et la salve — la periode qu elle pose EST le plancher.
; - les sons, comme partout dans ce portage : aucun.
;*******************************************************************************
; -----------------------------------------------------------------------------
; L'ETAT. Deux objets, deux usages du meme espace : l'emetteur n'a pas de
; boite (il ne se dessine pas), le wick n'a pas de timeline.
; -----------------------------------------------------------------------------
; --- l'emetteur -------------------------------------------------------------
wick.eLife      equ ext_variables      ; 0,1   duree de vie, en trames de jeu
wick.eScript    equ ext_variables+2    ; 2,3   curseur dans la timeline
wick.eTick      equ ext_variables+4    ; 4,5   trames depuis la naissance
wick.ePeriod    equ ext_variables+6    ; 6,7   periode d'emission
wick.eBurst     equ ext_variables+8    ; 8,9   taille de salve
wick.eAnchor    equ ext_variables+10   ; 10,11 ancre Y des wicks, DEJA convertie
wick.eBurstC    equ ext_variables+12   ; 12,13 compte a rebours de salve
wick.eEmitC     equ ext_variables+14   ; 14,15 compte a rebours d'emission (signe)
; --- le wick visible --------------------------------------------------------
wick.uAABB      equ ext_variables      ; 0..8  la boite
wick.uParent    equ ext_variables+9    ; 9,10  l'OST de l'emetteur, 0 s'il est mort
wick.uAnchor    equ ext_variables+11   ; 11,12 sa derniere ancre connue
wick.uAim       equ ext_variables+13   ; 13,14 delai de pique (0 = ne piquera jamais)
wick.uOsc       equ ext_variables+15   ; 15    phase de l'ondulation
wick.uAnim      equ ext_variables+16   ; 16    compteur d'animation
wick.uLate      equ ext_variables+17   ; 17,18 trames de jeu a rattraper a la
                                       ;       premiere trame — voir wick.Live

wick.SPAWNX     equ 152                ; arcade 704 : (704-320) x 0,375 + 8
wick.SPAWNY     equ 105                ; arcade 288-32 : 297 - 0,75 x 256
wick.LIFE       equ $0600              ; 1536 trames de jeu
wick.VX         equ -144               ; -1,5 px/trame arcade a la difficulte 0
wick.VTRACK     equ 12                 ; +/-0,0625 arcade : le rattrapage lent
wick.VOSC       equ 48                 ; +/-0,25 arcade : le creneau
wick.PERIOD     equ 36                 ; plancher de difficulte 0
wick.BURST      equ 3                  ; idem

;*******************************************************************************
; L'EMETTEUR — invisible, sans boite, et surtout SANS ANCRAGE AU DECOR : son
; tick arcade ne lit pas 0x2ED0 (verifie sur les octets). Il tient donc une
; abscisse ECRAN fixe. Chez nous, ou les coordonnees sont monde, on ne lui
; donne pas de position du tout : le point de ponte se calcule a l'emission,
; camera + 152. Rien a compenser, rien a corriger.
;*******************************************************************************
wick.Object
        lda   routine,u
        asla
        ldx   #wick.Routines
        jmp   [a,x]
wick.Routines
        fdb   wick.Init
        fdb   wick.Live
        fdb   wick.Deleted

wick.Init
        ldd   #wick.LIFE
        std   wick.eLife,u
        ldd   #wick.Timeline
        std   wick.eScript,u
        ldd   #0
        std   wick.eTick,u
        ; le constructeur arcade pose periode $40 et salve 4 — elles ne vivent
        ; qu'une trame, le plancher de difficulte les ecrase des le premier
        ; tour. On pose donc directement le plancher, c'est le meme resultat.
        ldd   #wick.PERIOD
        std   wick.ePeriod,u
        ; LE RETARD DE WAVE de l'emetteur lui-meme. Il n'a pas de vitesse
        ; propre, mais il porte une HORLOGE : sans cette avance, toute sa nuee
        ; naitrait decalee du meme retard. wave_frame_drop ALIASE
        ; anim_frame_duration — rien ne l'a encore ecrase ici.
        ldb   wave_frame_drop,u
        clra
        pshs  d
        ldd   #wick.PERIOD
        subd  ,s++
        std   wick.eEmitC,u
        ldd   #wick.BURST
        std   wick.eBurst,u
        std   wick.eBurstC,u
        ldd   #297-(304*3)/4           ; ancre $0130 convertie
        std   wick.eAnchor,u
        clr   priority,u               ; il ne se dessine pas
        clr   render_flags,u
        inc   routine,u
        rts

wick.Live
        jsr   wick.Frame               ; D = trames de jeu de ce tour
        ldd   wick.eLife,u
        subd  wick.drop
        std   wick.eLife,u
        lble  wick.Gone                ; duree de vie epuisee
        jsr   wick.Script
        ; --- l'emission. Le compte a rebours peut passer sous zero de PLUSIEURS
        ;     periodes quand la trame rendue vaut sept trames de jeu, d'ou la
        ;     boucle. Mais pondre n wicks ne suffit pas : ils ne naissent pas au
        ;     meme INSTANT, et le premier a donc deja vecu quand le dernier
        ;     nait. Chacun emporte son RETARD propre et le rattrapera a sa
        ;     premiere trame (wick.uLate).
        ;     Le compte est direct : quand le compte a rebours vaut D <= 0,
        ;     c'est qu'il a franchi zero il y a -D trames de jeu. Recharger une
        ;     periode fait decroitre ce retard d'autant pour la ponte suivante —
        ;     l'ordre de naissance va donc bien du plus ancien au plus recent.
        ldd   wick.eEmitC,u
        subd  wick.drop
@loop   std   wick.eEmitC,u
        cmpd  #0
        bgt   @done
        ldd   #0
        subd  wick.eEmitC,u            ; retard de CETTE ponte = -D
        std   wick.late
        jsr   wick.Spawn
        ldd   wick.eEmitC,u
        addd  wick.ePeriod,u
        bra   @loop
@done   rts

wick.Deleted
        rts
wick.Gone
        lda   #2
        sta   routine,u
        jmp   DeleteObject

; -----------------------------------------------------------------------------
; LA TIMELINE. Le plancher de difficulte est recharge AVANT les mutations,
; exactement comme l'arcade — c'est ce qui rend sans effet, a la difficulte 0,
; les entrees qui touchent la periode et la salve : elles y ecrivent la valeur
; du plancher. Seule l'ancre Y survit d'une trame a l'autre.
; Le seuil se teste en >=, donc la compensation de trame ne peut pas le
; manquer ; on consomme autant d'entrees que le compteur en a depassees.
; -----------------------------------------------------------------------------
wick.Script
        ldd   wick.eTick,u
        addd  wick.drop
        std   wick.eTick,u
        ldd   #wick.PERIOD             ; le plancher, a chaque trame
        std   wick.ePeriod,u
        ldd   #wick.BURST
        std   wick.eBurst,u
@next   ldx   wick.eScript,u
        ldd   wick.eTick,u
        cmpd  ,x                       ; compteur >= seuil ?
        blo   @rts
        ldd   2,x                      ; l'opcode
        leax  4,x
        stx   wick.eScript,u
        tsta
        bmi   @period                  ; bit 15 : la periode
        bita  #$40                     ; bit 14 : la salve
        bne   @burst
        anda  #$0F                     ; sinon l'ancre Y, a convertir
        jsr   wick.ToY
        std   wick.eAnchor,u
        bra   @next
@period anda  #$0F
        std   wick.ePeriod,u
        std   wick.eEmitC,u
        bra   @next
@burst  anda  #$0F
        std   wick.eBurst,u
        std   wick.eBurstC,u
        bra   @next
@rts    rts

; D = ordonnee arcade -> D = ordonnee v2 (297 - 0,75 y). y arcade < 400 ici,
; donc y*3 tient sur seize bits sans precaution.
wick.ToY
        pshs  d
        lsra
        rorb                           ; D = y/2
        addd  ,s                       ; D = y + y/2 = 1,5 y
        lsra
        rorb                           ; D = 0,75 y
        leas  2,s
        pshs  d
        ldd   #297
        subd  ,s++
        rts

; -----------------------------------------------------------------------------
; LA PONTE. L'enfant nait a l'abscisse ecran de l'emetteur — qui n'existe pas
; chez nous, on la reconstruit — et a une ordonnee tiree sous l'ancre de
; naissance. LA REGLE DE SALVE : seul le DERNIER de chaque salve recoit un
; delai de pique ; les autres recoivent zero et ne piqueront jamais.
; -----------------------------------------------------------------------------
wick.Spawn
        jsr   LoadObject_x
        beq   @rts
        lda   #ObjID_wick_unit
        sta   id,x
        clr   routine,x
        ldd   glb_camera_x_pos
        addd  #wick.SPAWNX
        std   x_pos,x
        clr   x_pos+2,x
        ; y = 105 - 0,75 x rand[0..63] : la dispersion anti-empilage
        jsr   wick.Rand63
        lda   #3
        mul
        lsrb
        lsrb
        clra
        pshs  d
        ldd   #wick.SPAWNY
        subd  ,s++
        std   y_pos,x
        clr   y_pos+2,x
        stu   wick.uParent,x
        ldd   wick.eAnchor,u
        std   wick.uAnchor,x
        ldd   #0
        std   wick.uAim,x              ; par defaut : pas de pique
        clr   wick.uOsc,x
        clr   wick.uAnim,x
        ldd   wick.late
        std   wick.uLate,x
        ; la regle de salve
        ldd   wick.eBurstC,u
        subd  #1
        std   wick.eBurstC,u
        bne   @rts
        ldd   wick.eBurst,u
        std   wick.eBurstC,u           ; la salve suivante repart
        jsr   RandomNumber             ; celui-ci piquera : delai arcade 0..255
        tstb
        bne   >
        incb                           ; ZERO veut dire « ne piquera jamais » :
!       clra                           ; on le decale d'une trame plutot que de
        std   wick.uAim,x              ; perdre un piqueur sur 256
@rts    rts

wick.Rand63
        jsr   RandomNumber
        andb  #$3F
        rts

wick.drop       fdb 0
wick.late       fdb 0                  ; le retard de la ponte en cours

; -----------------------------------------------------------------------------
; L'ouverture de trame, commune : le compte de trames de JEU de ce tour.
; -----------------------------------------------------------------------------
wick.Frame
        ldb   gfxlock.frameDrop.count
        bne   >
        incb                           ; miroir du garde de runByFrameDrop
!       clra
        std   wick.drop
        rts

*******************************************************************************
; LE WICK VISIBLE — etat DERIVE. Lui SUIT le decor (son tick arcade lit bien
; 0x2ED0), donc coordonnees playfield et aucun code de defilement.
;
; Le Y compose DEUX mouvements, et c'est ce qui fait le tetard :
;   . un rattrapage LENT vers une cible tiree a chaque trame autour de l'ancre
;     du parent — +/-0,0625 px/trame arcade. La cible bouge, le pas est
;     minuscule : le tirage se moyenne et le wick converge vers l'ancre en
;     tremblant.
;   . un CRENEAU de +/-0,25 px/trame commande par le bit 6 d'une phase : il
;     bascule toutes les 64 trames, soit 16 px arcade crete a crete (12 chez
;     nous) et une periode de 128. La plate Ghidra annonce ~32 px, c'est le
;     double du calcul et de la mesure — 64 trames x 0,25 font 16.
;
; Les deux vitesses, la phase, l'animation et le delai de pique avancent tous
; du meme compte de trames de JEU.
;*******************************************************************************
wick.Unit
        lda   routine,u
        asla
        ldx   #wick.UnitRoutines
        jmp   [a,x]
wick.UnitRoutines
        fdb   wick.UnitInit
        fdb   wick.Drift
        fdb   wick.UnitDeleted

wick.UnitInit
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldb   #6
        stb   priority,u
        _Collision_AddAABB wick.uAABB,AABB_list_ennemy
        lda   #wick_hitdamage
        sta   wick.uAABB+AABB.p,u
        _ldd  wick_hitbox_x,wick_hitbox_y
        std   wick.uAABB+AABB.rx,u
        inc   routine,u
        ; PAS DE RTS : il derive des sa premiere trame, comme l'arcade — mais
        ; de son RETARD PROPRE, pas du frame-drop du tour. Quand une trame
        ; rendue vaut sept trames de jeu, les wicks d'une meme rafale ne sont
        ; pas nes au meme instant : le premier a deja vecu six trames quand le
        ; dernier nait. Chacun rejoue donc ici les siennes, et zero est une
        ; valeur legitime — celui qui vient de naitre ne bouge pas encore.
        ldd   wick.uLate,u
        std   wick.drop
        bra   wick.DriftBody

wick.Drift
        jsr   wick.Frame
wick.DriftBody
        ; --- mort au premier coup -----------------------------------------
        lda   wick.uAABB+AABB.p,u
        lbeq  wick.Boom
        ; --- X : la vitesse propre, le defilement etant implicite ----------
        ldd   #wick.VX
        leax  x_pos,u
        jsr   wick.AddPos
        ; --- Y, premiere composante : le rattrapage lent ------------------
        ldx   wick.uParent,u
        beq   @ancre                   ; parent mort : on garde la derniere
        lda   id,x
        cmpa  #ObjID_wick
        beq   >
        clr   wick.uParent,u           ; le slot a change de main
        clr   wick.uParent+1,u
        bra   @ancre
!       ldd   wick.eAnchor,x
        std   wick.uAnchor,u
@ancre  jsr   wick.Rand63              ; cible = ancre + 24 - 0,75 x rand[0..63]
        lda   #3
        mul
        lsrb
        lsrb
        clra
        pshs  d
        ldd   wick.uAnchor,u
        addd  #24
        subd  ,s++
        cmpd  y_pos,u
        bhi   >
        ldd   #-wick.VTRACK            ; on est sous la cible : remonter
        bra   @track
!       ldd   #wick.VTRACK
@track  leax  y_pos,u
        jsr   wick.AddPos
        ; --- Y, seconde composante : le creneau ---------------------------
        lda   wick.uOsc,u
        adda  wick.drop+1
        sta   wick.uOsc,u
        bita  #$40
        beq   >
        ldd   #wick.VOSC               ; bit 6 arme : l'arcade descend
        bra   @osc
!       ldd   #-wick.VOSC
@osc    leax  y_pos,u
        jsr   wick.AddPos
        ; --- l'animation : quatre poses tenues quatre trames --------------
        lda   wick.uAnim,u
        adda  wick.drop+1
        sta   wick.uAnim,u
        lsra
        lsra
        anda  #3
        asla
        ldx   #wick.Poses
        jsr   wick.SetPose
        ; --- le delai de pique : zero = ne piquera jamais ------------------
        ldd   wick.uAim,u
        beq   @cadre                   ; zero : celui-la ne piquera jamais
        subd  wick.drop
        bgt   >
        ldd   #0                       ; le PIQUE n'est pas encore porte : le
!       std   wick.uAim,u              ; delai s'eteint, il reste en derive.
@cadre  jsr   wick.Visible
        lbne  wick.Vanish
        jmp   DisplaySprite

; A = l'index de pose x2, X = la table
wick.SetPose
        leax  a,x
        ldx   ,x
        stx   image_set,u
        rts

; La fenetre de visibilite, comme le gouger : Conv.java, X 0..159, Y -6..204.
; Z = 0 s'il faut partir.
wick.Visible
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   wick.uAABB+AABB.cx,u
        cmpd  #159
        bhi   @part
        ldd   y_pos,u
        stb   wick.uAABB+AABB.cy,u
        addd  #6
        cmpd  #204+6
        bhi   @part
        orcc  #$04
        rts
@part   andcc #$FB
        rts

wick.Boom
        ldb   #wick_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        lbeq  wick.Vanish
        _ldd  ObjID_explosion,explosion.subtype.smallx2
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
wick.Vanish
        lda   #2
        sta   routine,u
        _Collision_RemoveAABB wick.uAABB,AABB_list_ennemy
        jmp   DeleteObject
wick.UnitDeleted
        rts

; -----------------------------------------------------------------------------
; Deplacer de la vitesse 8.8 en D, compensee du frame-drop, sur le champ
; pointe par X (haut, bas, fraction). Meme calcul que le gouger : deux `mul`
; non signes, le produit tronque a seize bits etant juste en complement a deux.
; -----------------------------------------------------------------------------
wick.AddPos
        pshs  a
        lda   wick.drop+1
        mul
        std   wick.tmp
        puls  a
        ldb   wick.drop+1
        mul
        tfr   b,a
        clrb
        addd  wick.tmp
        pshs  d
        ldb   ,s
        sex
        sta   @a+1
        puls  d
        addd  1,x
        std   1,x
        lda   ,x
@a      adca  #$00
        sta   ,x
        rts

wick.tmp        fdb 0

wick.Poses
        fdb   set_wick_16,set_wick_17,set_wick_18,set_wick_19

; -----------------------------------------------------------------------------
; LA TIMELINE, telle que 1000:3afe la donne. Seuil, puis opcode : bit 15 la
; periode, bit 14 la salve, sinon l'ancre Y en coordonnees ARCADE (converties
; au vol par wick.ToY — les garder brutes rend la table relisable face a la ROM).
; -----------------------------------------------------------------------------
wick.Timeline
        fdb   8,$00D0                  ; ancre Y := 208 arcade -> 141
        fdb   16,$8024                 ; periode := 36  (sans effet, cf. fiche)
        fdb   64,$4003                 ; salve   := 3   (idem)
        fdb   192,$0110                ; ancre Y := 272 arcade ->  93
        fdb   $FFFF,$0130              ; jamais atteint : la fin

