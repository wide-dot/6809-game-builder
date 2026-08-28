; ---------------------------------------------------------------------------
; Geld — le mangeur de gommes du stage 4
;
; input REG : [u] pointer to Object Status Table (OST)
; ---------------------------------------------------------------------------
;
; FICHE DE PORTAGE
; ================
; arcade : create_geld 0x40:8F5E, run_geld 0x40:8F86,
;          tick_geld_engaged 0x40:90A2, geld_carve_terrain_tiles 0x40:90E0
; bestiaire : stage 4 (13 spawns dans la wave). C'est l'exact CONTRAIRE du
;             cytron : celui-ci fait pousser les gommes, le geld les mange.
;
; CE QU'IL FAIT, dans l'ordre du tick arcade (8F86) :
;   1. il derive dans la direction cardinale de sa variante, a une vitesse
;      donnee par la difficulte ; pos_x suit le decor (ancrage au scroll) ;
;   2. il teste s'il CROISE la ligne (ou la colonne) du joueur ; si oui il
;      passe 31 trames en mode « engage » puis repart PERPENDICULAIREMENT,
;      du cote ou se trouve le joueur — chaque croisement le fait donc virer
;      vers lui ;
;   3. sinon il se dessine et CREUSE : la fenetre de 2x2 tuiles en bas a
;      gauche de son centre, ou toute cellule de gomme (0x9F6) redevient du
;      vide (0xFA0). C'est sa signature ;
;   4. hors ecran -> dechargement silencieux ; touche -> explosion (un coup,
;      pas de PV : liste « one-shot v1 » du doc de combat).
;
; LES QUATRE VARIANTES (0x1000:3F76, l'indice est le quartet bas du subtype) :
;   0 = DROITE, 1 = GAUCHE, 2 = BAS, 3 = HAUT   (codes arcade)
; La table de spawn : slots 0..2 -> 3, 3..8 -> 1, 9..11 -> 2, 12..15 -> 0.
;
; LES VITESSES (0x1000:3F86, 4 variantes x 4 difficultes, en 8.8) : la
; premiere difficulte donne 1 px/trame arcade, soit nos pas d'echelle.
;
; ECARTS ASSUMES
; --------------
; V2-DEVIATION: pas de selecteur de difficulte en v2 — on prend la premiere
;   valeur de la table, comme tout le cast.
; V2-DEVIATION: l'arcade choisit son sprite d'engagement dans une table de
;   16 cases dont 4 sont VIDES sur des combinaisons pourtant atteignables
;   (elle y lirait des ordures — voir la plate de run_geld). On ne porte pas
;   le defaut : les quatre cases vides retombent sur la pose de patrouille.
; V2-DEVIATION: le clignotement de touche par echange de palette (comme le
;   cytron) n'a pas d'equivalent sur ce stage.
; ---------------------------------------------------------------------------

AABB_0        equ ext_variables      ; AABB struct (9 bytes)
geld.variant  equ ext_variables+9    ; direction courante (0..3)
geld.state    equ ext_variables+10   ; cap perpendiculaire vise (0..3)
geld.timer    equ ext_variables+11   ; trames restantes du virage (0..31)
; Le pas ENTIER franchi par le tick courant, sur l'axe de marche (le meme que
; celui de la fenetre d'engagement). Il sert a rattraper ce que le frame-drop
; fait sauter — voir le long commentaire au-dessus du test de fenetre.
geld.step     equ ext_variables+12   ; 1 octet, 0..7 px

Object
        lda   routine,u
        asla
        ldx   #Routines
        jmp   [a,x]

Routines
        fdb   Init
        fdb   Patrol
        fdb   Engaged
        fdb   AlreadyDeleted

Init
        ; --- la position : le MEME preset partage que bug et pow (8f68)
        lda   subtype_w+1,u
        anda  #$0F
        pshs  a                        ; l'indice de slot sert deux fois
        asla                           ; deux octets par entree
        ldx   #PresetXYIndex
        leax  a,x
        clra
        ldb   ,x                       ; x du preset, en px ecran
        addd  glb_camera_x_pos
        std   x_pos,u
        clr   x_sub,u
        clra
        ldb   1,x                      ; y du preset
        std   y_pos,u
        clr   y_sub,u

        ; --- la direction : 8f74, geld_variant_from_spawn_slot_table
        puls  a
        ldx   #geld.slot.variant
        lda   a,x
        sta   geld.variant,u

        lda   #1                       ; -> Patrol
        sta   routine,u
        ; 69bc/90a5 : « pos_x += scroll_amount », l'ancrage au decor — et
        ; l'arcade le fait dans SES DEUX modes. En v2 le drapeau s'en charge
        ; (cf. cytron) : sans lui le geld ne derive pas avec le niveau.
        ldb   #6                       ; priorite d'affichage
        stb   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u

        ; --- la boite : 24x24 centree (0x1000:407E, +-12 px arcade)
        _Collision_AddAABB AABB_0,AABB_list_ennemy
        lda   #geld_hitdamage
        sta   AABB_0+AABB.p,u
        _ldd  geld_hitbox_x,geld_hitbox_y
        std   AABB_0+AABB.rx,u
        lbra  Patrol.entry

; ---------------------------------------------------------------------------
; Patrol — la derive, le test de croisement, le dessin et LE CREUSEMENT
; ---------------------------------------------------------------------------
Patrol
Patrol.entry
        ; touche ? un seul coup suffit (doc/arcade-combat-reference.md)
        lda   AABB_0+AABB.p,u
        lbeq  geld.explode             ; la portee courte ne suffit pas : le
                                       ; corps du tick tient entre les deux

        ; --- 8fb4 : le pas de la variante, compense par le frame drop.
        ; L'idiome maison (cancer, pow) : B = le pas 8.8 sur UN octet, A = le
        ; nombre de trames ecoulees, mul -> D = le deplacement du tour, et
        ; _negd pour le sens negatif. L'arcade avance d'1 px par trame a la
        ; premiere difficulte : $60 en X (0,375 px v2) et $C0 en Y (0,75).
        ldb   geld.variant,u
        beq   @right
        cmpb  #1
        beq   @left
        cmpb  #2
        beq   @up
        ; 3 = DOWN (arcade vy = -1, et son axe y monte) : chez nous y CROIT.
        ; La plate de la table de variantes annonce l'inverse ; c'est la table
        ; de VITESSES qui fait foi — v2 a vy=+1 (haut), v3 vy=-1 (bas) — et le
        ; jeu le confirme : les slots 0..2 naissent en haut (preset y=3) et
        ; doivent DESCENDRE (sans quoi ils sortent de l'ecran a la naissance,
        ; constat sous toje).
        ldb   #geld.STEPY
        lda   gfxlock.frameDrop.count
        mul
        sta   geld.step,u              ; le pas entier de ce tick
        jsr   moveYPos8.8
        bra   @moved
@up     ldb   #geld.STEPY             ; 2 = UP arcade : chez nous y DECROIT
        lda   gfxlock.frameDrop.count
        mul
        sta   geld.step,u
        _negd
        jsr   moveYPos8.8
        bra   @moved
@right  ldb   #geld.STEPX
        lda   gfxlock.frameDrop.count
        mul
        sta   geld.step,u
        jsr   moveXPos8.8
        bra   @moved
@left   ldb   #geld.STEPX
        lda   gfxlock.frameDrop.count
        mul
        sta   geld.step,u
        _negd
        jsr   moveXPos8.8
@moved
        ; --- 8fda : la fenetre d'engagement, selon l'axe de la variante
        ldb   geld.variant,u
        bitb  #2                       ; bit 1 : 0 = horizontal, 1 = vertical
        lbne  geld.vertical

        ; HORIZONTAL (variantes 0 et 1) : la COLONNE du joueur, +-16 px
        ; arcade. L'ecart se mesure en x, le nouveau cap est haut ou bas.
        ldd   x_pos,u
        addd  #geld.WINX
        subd  player1+x_pos
        ; ---------------------------------------------------------------
        ; LA FENETRE COUVRE LE SEGMENT PARCOURU, PAS LE SEUL POINT D'ARRIVEE
        ; (correctif du 29/08, sur observation auteur : « en arcade ils
        ; restent sur le joueur, chez nous ils repartent »).
        ;
        ; La borne avance d'un pixel par trame et n'a pas de frame-drop : elle
        ; reste une dizaine de trames dans une fenetre de 8 px, elle ne peut
        ; pas la manquer. Nous, un tick vaut jusqu'a 8 trames de jeu — le geld
        ; franchit alors 5 a 6 px d'un coup, soit la fenetre ENTIERE, et le
        ; test tombe systematiquement de l'autre cote. Trace a l'appui : apres
        ; son virage le geld etait a dy=0, le tick suivant l'a pose a dy=+6, et
        ; il n'a plus jamais engage — il s'eloignait au lieu de tourner autour
        ; du joueur.
        ;
        ; On teste donc l'INTERSECTION du segment [depart, arrivee] avec la
        ; fenetre, ce qui revient a elargir la borne haute du pas franchi et,
        ; quand la marche va vers les coordonnees DECROISSANTES, a ramener D
        ; du meme pas (le geld venait alors de plus loin).
        ; ---------------------------------------------------------------
        ldb   geld.variant,u
        cmpb  #1                           ; 1 = GAUCHE, la marche decroit
        bne   @winX
        addb  geld.step,u                  ; (B vient d'etre compare, on le
        adca  #0                           ;  reutilise : il vaut 1, le pas
        subb  #1                           ;  s'ajoute puis on retire ce 1)
        sbca  #0
@winX   cmpd  #$8000
        lbhs  geld.draw                    ; D < 0 : le segment est a gauche
        pshs  d
        ldb   geld.step,u
        clra
        addd  #geld.WINX*2                 ; la borne, elargie du pas
        cmpd  ,s++
        lbls  geld.draw                    ; borne <= D : segment a droite
        ; 8ff1 : le cap vise le joueur. En arcade « pos_y < player_y » veut
        ; dire SOUS le joueur (son axe y monte) et donne le cap 2 = UP : il
        ; remonte vers lui. Chez nous l'axe est inverse, donc le test aussi.
        ; LE CAP SE CHOISIT APRES LA COMPARAISON (bug corrige le 29/08) : la
        ; version d'avant posait `lda #2` PUIS `ldd y_pos,u` — et LDD ecrase A.
        ; Le cap valait donc l'octet HAUT de la position, jamais 2 ni 3 : au
        ; commit du virage il devenait la variante, tombait dans la branche
        ; par defaut de Patrol (DOWN) et indexait la table d'images hors
        ; bornes. Tous les virages partaient vers le bas.
        ; A n'est pas charge entre CMPD et la branche : LDA n'affecte pas C,
        ; mais il ecrase Z — et BHI les lit tous les deux.
        ldd   y_pos,u
        cmpd  player1+y_pos
        bhi   @capUp                   ; le geld est SOUS le joueur : il monte
        lda   #3                       ; ...sinon il est au-dessus : DOWN
        bra   @capSet
@capUp  lda   #2                       ; UP : remonter vers le joueur
@capSet sta   geld.state,u
        lbra  geld.engage

geld.vertical
        ; VERTICAL (variantes 2 et 3) : la LIGNE du joueur, +-4 px arcade
        ; (3 lignes v2). Le nouveau cap est gauche ou droite.
        ldd   y_pos,u
        addd  #geld.WINY
        subd  player1+y_pos
        ; Meme rattrapage que sur l'axe horizontal — le commentaire y est.
        ldb   geld.variant,u
        cmpb  #2                           ; 2 = HAUT, la marche decroit
        bne   @winY
        addb  geld.step,u
        adca  #0
        subb  #2
        sbca  #0
@winY   cmpd  #$8000
        lbhs  geld.draw
        pshs  d
        ldb   geld.step,u
        clra
        addd  #geld.WINY*2
        cmpd  ,s++
        lbls  geld.draw
        ; Meme correction que la branche horizontale : le `clra` etait ecrase
        ; par le `ldd` qui suivait.
        ldd   x_pos,u
        cmpd  player1+x_pos
        blo   @capRight                ; le geld est A GAUCHE du joueur
        lda   #1                       ; ...donc il va a GAUCHE pour le viser
        bra   @capSet2
@capRight clra                         ; cap 0 = DROITE
@capSet2 sta  geld.state,u

geld.engage ; 9055 : 31 trames de virage, puis le cap devient le nouveau sens
        lda   #geld.TURN
        sta   geld.timer,u
        lda   #2                       ; -> Engaged
        sta   routine,u
        lbra  Engaged.draw             ; l'arcade enchaine dans la meme trame

geld.draw   ; 9028 : la pose de patrouille, quatre images par variante
        ldb   geld.variant,u
        aslb
        aslb                           ; 4 images par direction
        lda   gfxlock.frame.gameCount+1 ; l'horloge de jeu tient l'animation
        lsra
        lsra                           ; 4 trames par image
        anda  #3
        pshs  b
        adda  ,s+
        ldx   #geld.images
        asla
        ldd   a,x
        std   image_set,u
        lbsr  geld.carve               ; ET IL MANGE : la fenetre 2x2
        lbsr  geld.alive               ; hors ecran ? (les deux modes)
        jmp   DisplaySprite

; ---------------------------------------------------------------------------
; geld.alive — 904f : hors ecran, dechargement SILENCIEUX
;
; APPELE PAR LES DEUX MODES (27/08/2026). Ce test vivait au bout du chemin de
; dessin de la patrouille : un geld qui reste dans la fenetre du joueur
; re-engage a chaque retour de virage, ne dessine jamais, et VIT ETERNELLEMENT
; — il gardait son slot, et le stage 4 ne finissait plus (camera bloquee a
; 880 au lieu de 992, constat sous toje). L'arcade n'a pas ce trou : son
; tick engage rend la main au tick de patrouille qui, lui, teste toujours.
; La boite de collision suit au passage, comme chez cancer.
; ---------------------------------------------------------------------------
geld.alive
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u
        addd  #geld_hitbox_x
        bmi   geld.gone                ; sorti par la gauche
        cmpd  #geld.SCREEN_W+geld_hitbox_x*2
        bhi   geld.gone                ; ou par la droite
        ldd   y_pos,u
        addd  #geld_hitbox_y
        bmi   geld.gone                ; par le haut
        cmpd  #geld.SCREEN_H+geld_hitbox_y*2
        bhi   geld.gone                ; ou par le bas
        ldd   y_pos,u
        stb   AABB_0+AABB.cy,u
        rts

geld.gone
        lda   #3
        sta   routine,u
        _Collision_RemoveAABB AABB_0,AABB_list_ennemy
        jmp   DeleteObject

; ---------------------------------------------------------------------------
; Engaged — 31 trames de virage, puis le cap perpendiculaire est adopte
; ---------------------------------------------------------------------------
Engaged
        lda   AABB_0+AABB.p,u
        lbeq  geld.explode
Engaged.draw
        lbsr  geld.alive               ; meme garde qu'en patrouille
        ; 90a2 : il derive toujours avec le decor, il ne creuse plus.
        ldb   geld.timer,u
        bitb  #$10                     ; bit 4 : deux images de 16 trames
        beq   >
        ldb   #1
        bra   @img
!       clrb
@img    lda   geld.state,u             ; le cap vise choisit la paire
        asla
        pshs  b
        adda  ,s+
        ldx   #geld.engaged
        asla
        ldd   a,x
        std   image_set,u
        jsr   DisplaySprite

        ldb   gfxlock.frameDrop.count  ; le compte a rebours suit l'horloge
        lda   geld.timer,u
        pshs  b
        suba  ,s+
        bhi   @wait
        ; 9075 : le virage est fait — le cap devient le sens de marche
        lda   geld.state,u
        sta   geld.variant,u
        lda   #1                       ; -> Patrol
        sta   routine,u
        rts
@wait   sta   geld.timer,u
        rts

; ---------------------------------------------------------------------------
; geld.carve — LE CREUSEMENT (90e0), la signature du geld
; ---------------------------------------------------------------------------
; L'arcade sonde une fenetre de 2x2 TUILES dont le coin est a (x-4, y+4) en
; px arcade, et remet a vide (0xFA0) toute cellule qui lit une gomme (0x9F6).
; Chez nous une cellule de gomme fait 3x6 px, et l'effacement passe par le
; crochet du stage (stage.gum.hook +0 = effacer une cellule) : le code d'un
; ennemi ne peut pas connaitre un symbole du stage 4, exactement comme les
; armes (cf. src/common/state/variables.asm).
;
; Un SEUL appel, l'entree +6 du crochet (effacement en rectangle) : elle
; couvre les quatre cellules d'un coup et se charge des bornes. La borne, elle,
; sonde ses quatre coins un par un et ne remplace que ce qui vaut 0x9F6 — chez
; nous ce test est implicite, le crochet n'adresse QUE le plan des gommes et
; le decor dur (plan 1) lui est inaccessible. C'est la reponse au risque des
; deux plans : le geld ne peut pas manger le terrain.
;
; V2-DEVIATION : la borne remplace la gomme par un DEBRIS visible (0xFA0) ;
; chez nous une gomme est un bit d'un plan, pas une tuile — elle disparait.
; ---------------------------------------------------------------------------
geld.carve
        ; LE VECTEUR S'INSTALLE AVANT LES PARAMETRES (27/08/2026). L'entree +6
        ; prend A, B, X et Y a elle seule — il n'y a plus de registre pour
        ; porter le pointeur, d'ou le `jsr` auto-modifiant, exactement comme
        ; beam.gum.arm. La premiere version chargeait `ldx stage.gum.hook`
        ; JUSTE AVANT l'appel : elle ecrasait X, c'est-a-dire le x de depart
        ; du rectangle, avec l'adresse du vecteur (~$9E5x). Le rectangle
        ; s'etendait donc de cette adresse jusqu'au geld, rabote aux bords du
        ; champ — il effacait TOUT L'ECRAN a chaque trame de patrouille
        ; (releve auteur : « un rectangle d'effacement enorme », et les gommes
        ; du champ balayees a la disparition du geld).
        ldd   stage.gum.hook
        beq   @none                    ; pas de champ sur ce stage (le vecteur
                                       ; neutre est nul) — rien a manger
        addd  #6                       ; +6 : l'effacement en rectangle
        std   @call+1
        ; LE HAUT : y + 4 px arcade, MOINS UNE LIGNE QUAND IL RAMPE A
        ; L'HORIZONTALE (releve auteur, 29/08, en comparant a la borne : « on
        ; efface trop bas d'une ligne »). La borne pose son coin de sonde au
        ; meme endroit quelle que soit la direction, mais ses poses
        ; horizontales et verticales n'ont pas le meme centre : converties, nos
        ; images horizontales portent le corps une ligne plus haut. Les caps
        ; verticaux sont deja cales.
        ; On BRANCHE avant de composer D : LDD pose N et Z, il effacerait le
        ; verdict de BITB — et un `ldb` apres le calcul ecraserait l'octet bas
        ; de la ligne.
        ldb   geld.variant,u
        bitb  #2                       ; bit 1 : 0 = horizontal, 1 = vertical
        bne   @vertical
        ldd   y_pos,u
        addd  #geld.CARVE_Y-1          ; horizontal : une ligne plus haut
        bra   @ligne
@vertical
        ldd   y_pos,u
        addd  #geld.CARVE_Y            ; vertical : le calage d'origine
@ligne  pshs  b                        ; la ligne ecran tient dans un octet
        ldd   x_pos,u                  ; le coin gauche : x - 4 px arcade
        subd  #geld.CARVE_X
        tfr   d,x                      ; depart...
        tfr   d,y                      ; ...et arrivee : le geld ne balaye pas,
                                       ; il croque sur place
        lda   #$22                     ; 2 cellules de large, 2 de haut
        puls  b                        ; la ligne
@call   jsr   >0                       ; l'adresse vient d'etre installee
@none   rts


geld.explode
        ldb   #geld_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        beq   @delete
        _ldd  ObjID_explosion,explosion.subtype.smallx2
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
@delete lda   #3
        sta   routine,u
        _Collision_RemoveAABB AABB_0,AABB_list_ennemy
        jmp   DeleteObject
AlreadyDeleted
        rts
