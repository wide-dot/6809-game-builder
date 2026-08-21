* ---------------------------------------------------------------------------
* tilemap.patch — animer le decor en reecrivant des cellules de carte
* ---------------------------------------------------------------------------
*
* Une cellule de carte n'est pas un identifiant mais un POINTEUR de 3 octets
* vers la routine de la tuile compilee, cuit au build (voir tilemaps.md).
* Animer du decor revient donc a reecrire ces pointeurs, et le DrawTiles
* suivant peint le resultat. C'est le geste de l'arcade : R-Type repeint un
* rectangle de sa tilemap de fond pour avaler l'outslay dans le tube du
* gomander (0x40:A578), et compose les epaves du cuirasse de la meme facon.
* C'est aussi le SEUL moyen de faire passer un sprite DERRIERE de l'art
* anime, le decor etant peint apres les sprites.
*
* ===========================================================================
* LE MODELE : DES DEMANDES DIFFEREES
* ===========================================================================
*
* Le code objet n'ecrit JAMAIS dans la carte. Il EMPILE une demande — un
* descripteur et un numero d'image — et c'est tout. Une fois par trame, la
* boucle de jeu appelle `tilemap.flush`, qui monte la page de la carte UNE
* fois et applique ce qui s'est accumule.
*
* Ce n'est pas une commodite, c'est ce qui rend le systeme sur. Trois choses
* vivent a trois endroits : le module est resident ; l'ETAT d'une animation
* est dans l'OST de l'objet qui la pilote, donc en demi-page 0 — hors fenetre
* cartouche, qui s'arrete a $4000, et epinglee par _gfxlock.init sous overlay,
* donc TOUJOURS adressable ; le DESCRIPTEUR et les BLOCS, eux, vivent dans le
* direntry de la carte, lui pagine. Empiler un pointeur ne le deference pas :
* le code objet n'a donc aucune page a connaitre, et le seul endroit qui en
* monte une est le drain.
*
* Le sequenceur precedent lisait les deux cotes et trois defauts en sont
* sortis, tous la meme faute — une lecture prise du mauvais cote d'un montage
* ne rate pas bruyamment, elle rend les octets qui trainent la : cols/rows a
* zero et 64 Ko ecrases, l'index d'image faux et des cellules vides, le
* maintien a zero et une boucle sans fin.
*
* PAS D'ALLOCATEUR. L'etat tient dans l'OST de l'objet qui pilote
* l'animation, sur les octets que le moteur d'animation de sprites y reserve
* deja (les alias de tilemap-patch.const.asm) : instanciation, duree de vie
* et liberation sont celles de l'objet, et il n'y a rien de plus a gerer.
*
* CO-LOCALISATION, la seule contrainte. Le descripteur et ses blocs doivent
* vivre dans le direntry du plan PAIR : le drain les lit sous cette page. Les
* destinations, elles, sont montees plan par plan et peuvent differer. En
* pratique <tilepatch> se declare dans le meme <lwasm> que les deux
* <tilemap>, donc c'est acquis sans y penser.
* ---------------------------------------------------------------------------

        INCLUDE "engine/graphics/tilemap/patch/tilemap-patch.const.asm"

* --- l'anneau de demandes ---------------------------------------------------
tilemap.q             rmb   tilemap.q.LEN*tilemap.q.STEP
tilemap.q.count       fcb   0
tilemap.q.lost        fcb   0        ; TEMOIN de debordement, jamais remis a
                                     ; zero : une demande perdue est un defaut
                                     ; de dimensionnement, pas un alea, et un
                                     ; rectangle qui ne s'applique pas ne se
                                     ; voit pas autrement.

* --- parametres du poseur de rectangle --------------------------------------
tilemap.patch.col     fcb   0        ; colonne de destination (coin haut-gauche)
tilemap.patch.row     fcb   0        ; ligne de destination
tilemap.patch.cols    fcb   0        ; largeur du rectangle, en cellules
tilemap.patch.rows    fcb   0        ; hauteur du rectangle, en cellules
tilemap.patch.plane   fcb   0        ; 0 = plan pair, non nul = plan impair

* --- variables privees ------------------------------------------------------
tilemap.patch.colStep fdb   0
tilemap.patch.runLen  fcb   0
tilemap.patch.colCnt  fcb   0
tilemap.patch.saved   fcb   0
tilemap.anim.nbFrames fcb   0        ; les deux parametres d'horloge, deposes
tilemap.anim.holdVal  fcb   0        ; par l'appelant de tilemap.animate
tilemap.anim.desc     fdb   0
tilemap.q.rd          fdb   0

* ---------------------------------------------------------------------------
* tilemap.request — empiler une demande
* -------------------------------------
* entree : X = descripteur, B = numero d'image
* Ne deference RIEN : c'est ce qui permet de l'appeler depuis n'importe quel
* code objet sans se soucier de la page ou vit le descripteur.
* clobbe : a, b, y
* ---------------------------------------------------------------------------
tilemap.request
        lda   tilemap.q.count
        cmpa  #tilemap.q.LEN
        bhs   @full
        pshs  b
        ldb   #tilemap.q.STEP
        mul                            ; A = count, B = STEP
        ldy   #tilemap.q
        leay  d,y
        puls  b
        stx   ,y
        stb   2,y
        inc   tilemap.q.count
        rts
@full   inc   tilemap.q.lost
        rts

* ---------------------------------------------------------------------------
* tilemap.stamp — poser une image, une fois pour toutes
* -----------------------------------------------------
* entree : X = descripteur
* Les epaves du cuirasse sont exactement ca : 31 rectangles d'UNE image,
* poses quand une piece casse et qui ne bougent plus jamais. Pas d'horloge,
* pas de sens, pas de cycle de vie — donc pas d'etat, et rien a allouer.
* ---------------------------------------------------------------------------
tilemap.stamp
        clrb
        bra   tilemap.request

* ---------------------------------------------------------------------------
* tilemap.restore — remettre les cellules patchables dans l'etat du niveau
* ------------------------------------------------------------------------
* A appeler au RETOUR DE CHECKPOINT, avant que checkpoint.load ne repeigne.
*
* Pourquoi c'est necessaire : la carte en RAM est la SEULE copie, et un
* checkpoint ne recharge rien depuis la disquette — il repeint depuis ces
* memes tables. Sans ca le decor reste fige dans la derniere image ecrite.
*
* Le stage publie sa table via tilemap.resetTable, generee par <tilereset> a
* partir d'une simple liste de rectangles de carte. Elle est faite d'entrees
* d'anneau DEJA FORMATEES : la restauration est donc une recopie de bloc, et
* le drain les applique sans savoir que ce sont des restaurations. Aucun
* chemin dedie dans le runtime.
*
* On ECRASE l'anneau au lieu d'y ajouter : au retour de checkpoint, ce qui y
* trainait decrit un etat de jeu qui n'existe plus.
* clobbe : tout
* ---------------------------------------------------------------------------
tilemap.resetTable    fdb   0        ; pose par le setup du stage ; 0 = ce stage
                                     ; n'a rien de patchable, et restore ne
                                     ; fait rien
tilemap.restore
        ldx   tilemap.resetTable
        beq   @rts
* LA TABLE EST PAGINEE, elle aussi. Elle vit avec les descripteurs qu'elle
* nomme, donc dans le direntry de la carte : la lire sans monter cette page
* rend les octets qui trainent la, et le compte comme les entrees sont alors
* du hasard. Quatrieme fois que ce piege mord — d'ou le montage explicite ici
* aussi, et non parce que « ca ne coute rien ».
        _GetCartPageA
        sta   tilemap.patch.saved
        lda   scroll_map_page_even
        _SetCartPageA
        lda   ,x+                      ; le nombre de rectangles
        beq   @none
        cmpa  #tilemap.q.LEN
        bls   @take
        lda   #tilemap.q.LEN           ; l'anneau borne la restauration ; le
        inc   tilemap.q.lost           ; surplus est un defaut de dimensionnement
@take   sta   tilemap.q.count
        ldb   #tilemap.q.STEP
        mul                            ; D = N x 3 octets
        tfr   d,y
        ldu   #tilemap.q
@copy   lda   ,x+
        sta   ,u+
        leay  -1,y
        bne   @copy
        lda   tilemap.patch.saved      ; rendre la page avant le drain, qui
        _SetCartPageA                  ; remontera la sienne
        jmp   tilemap.flush            ; applique TOUT DE SUITE : deux trames
                                       ; plus tard, le joueur aurait vu le
                                       ; decor patche sous le READY
@none   lda   tilemap.patch.saved
        _SetCartPageA
@rts    rts

* ---------------------------------------------------------------------------
* tilemap.anim.arm — (re)armer une animation portee par un OST
* ------------------------------------------------------------
* entree : U = OST, X = descripteur, A = nombre d'images, B = maintien
*          tanim.flags,u : bit de sens deja pose par l'appelant
* Pose l'image de depart et l'empile : une animation qui demarre doit se voir
* a la trame ou elle demarre, pas a la suivante.
* clobbe : a, b, x, y
* ---------------------------------------------------------------------------
tilemap.anim.arm
        stb   tanim.timer,u
        sta   tilemap.anim.nbFrames
        lda   tanim.flags,u
        anda  #tanim.BACKWARD          ; garder le sens, effacer DONE
        sta   tanim.flags,u
        clrb
        bita  #tanim.BACKWARD
        beq   @set
        ldb   tilemap.anim.nbFrames    ; a l'envers : on part de la derniere
        decb
@set    stb   tanim.frame,u
        jmp   tilemap.request          ; B = image de depart, X = descripteur

* ---------------------------------------------------------------------------
* tilemap.animate — faire avancer l'horloge d'une animation portee par un OST
* ---------------------------------------------------------------------------
* entree : U = OST, X = descripteur
*          A = nombre d'images, B = maintien en trames video — deux equates
*              emises par <tilepatch gensymbols>, donc connues a l'assemblage :
*              rien a lire dans une page
*          tanim.flags,u bit 0 = sens (0 avant, 1 arriere)
* sortie : Z = 1 si la sequence est terminee
* clobbe : a, b, x, y
*
* N'empile une demande QUE lorsque l'image change : une image tenue deux
* trames ne repose pas son rectangle deux fois.
* ---------------------------------------------------------------------------
tilemap.animate
        sta   tilemap.anim.nbFrames
        stb   tilemap.anim.holdVal
        stx   tilemap.anim.desc
        lda   tanim.flags,u
        bita  #tanim.DONE
        bne   @done
        lda   tanim.timer,u
        suba  gfxlock.frameDrop.count
        bgt   @keep                    ; le maintien court encore
        sta   tilemap.patch.saved      ; le retard, en transit
* RATTRAPAGE. Une boucle de jeu couvre plusieurs trames video : un maintien
* court peut etre franchi plusieurs fois dans le meme tour. On avance
* d'autant d'images que le retard en contient et on n'empile qu'UNE demande,
* sur l'image d'arrivee — les intermediaires ne seraient jamais vues. Le
* reste du retard est reporte, comme pour les segments d'outslay.
* (<tilepatch> refuse un maintien nul, sans quoi ceci bouclerait.)
@catchup
        ldb   tanim.frame,u
        lda   tanim.flags,u
        bita  #tanim.BACKWARD
        bne   @backward
        incb
        cmpb  tilemap.anim.nbFrames
        bhs   @finish
        bra   @advance
@backward
        tstb
        beq   @finish
        decb
@advance
        stb   tanim.frame,u
        lda   tilemap.patch.saved
        adda  tilemap.anim.holdVal
        sta   tilemap.patch.saved
        ble   @catchup                 ; toujours en retard : encore une image
        sta   tanim.timer,u
        ldb   tanim.frame,u
        ldx   tilemap.anim.desc
        jsr   tilemap.request
        andcc #$FB                     ; Z = 0 : elle tourne encore
        rts
@keep   sta   tanim.timer,u
        andcc #$FB
        rts
@finish
        lda   tanim.flags,u
        ora   #tanim.DONE
        sta   tanim.flags,u
@done   orcc  #$04                     ; Z = 1 : terminee
        rts

* ---------------------------------------------------------------------------
* tilemap.flush — appliquer tout ce qui s'est accumule
* ----------------------------------------------------
* A appeler UNE fois par trame depuis la boucle de jeu, hors du verrou : on
* n'ecrit que la table de carte, c'est DrawTiles qui peindra.
*
* Le seul endroit du module qui monte une page. Le descripteur et les blocs
* sont lus sous la page du plan PAIR (cf. la co-localisation en tete) ; les
* destinations sont montees plan par plan par tilemap.patch.
* clobbe : tout
* ---------------------------------------------------------------------------
tilemap.flush
        lda   tilemap.q.count
        bne   @go
        rts
@go     ldx   #tilemap.q
        stx   tilemap.q.rd
@entry  _GetCartPageA
        sta   tilemap.patch.saved
        lda   scroll_map_page_even     ; la page du DESCRIPTEUR et des blocs
        _SetCartPageA
        ldx   tilemap.q.rd
        ldy   ,x                       ; le descripteur
        ldb   2,x                      ; l'image
        lda   tilemap.desc.cols,y
        sta   tilemap.patch.cols
        lda   tilemap.desc.rows,y
        sta   tilemap.patch.rows
        lda   tilemap.desc.col,y
        sta   tilemap.patch.col
        lda   tilemap.desc.row,y
        sta   tilemap.patch.row
        aslb
        pshs  b
        clr   tilemap.patch.plane      ; --- le plan pair
        ldx   tilemap.desc.tableEven,y
        abx
        ldx   ,x
        pshs  y
        jsr   tilemap.patch
        puls  y
        ldx   tilemap.desc.tableOdd,y  ; --- le plan impair, s'il est declare
        beq   @noOdd                   ; table nulle : la camera est figee, le
        lda   #1                       ; scroll ne lira jamais ce plan
        sta   tilemap.patch.plane
        ldb   ,s
        abx
        ldx   ,x
        jsr   tilemap.patch
@noOdd  leas  1,s
        lda   tilemap.patch.saved
        _SetCartPageA
        ldx   tilemap.q.rd
        leax  tilemap.q.STEP,x
        stx   tilemap.q.rd
        dec   tilemap.q.count
        bne   @entry
        rts

* ---------------------------------------------------------------------------
* tilemap.patch — poser UN rectangle dans UN plan
* -----------------------------------------------
* entree : X = bloc source, cols/rows/col/row/plane poses
* La carte est en colonne-majeur, scroll_vp_v_tiles cellules par colonne, 3
* octets par cellule : une colonne du rectangle est donc contigue des DEUX
* cotes et se copie d'un seul bloc. C'est ce qui rend la routine courte.
* clobbe : a, b, x, y, u
* ---------------------------------------------------------------------------
tilemap.patch
        lda   tilemap.patch.plane
        bne   @odd
        lda   scroll_map_page_even
        ldy   scroll_map_even
        bra   @mount
@odd    lda   scroll_map_page_odd
        ldy   scroll_map_odd
@mount  _SetCartPageA
* GARDE. Une geometrie nulle n'est pas benigne ici : `dec`/`bne` sur zero
* parcourt 256 tours, donc 256 colonnes de 256 octets — toute la memoire
* ecrasee. Un symbole non resolu vaut zero en silence dans ce projet ; on
* refuse le zero plutot que de lui faire confiance.
        lda   tilemap.patch.cols
        beq   @rts
        lda   tilemap.patch.rows
        beq   @rts
        ldb   #3
        mul
        stb   tilemap.patch.runLen
* Le pas d'une colonne de carte. L'octet bas suffit au `mul` ci-dessous, et
* c'est structurel : scroll_vp_v_tiles est la hauteur du VIEWPORT en tuiles,
* donc au plus 200/12 = 16, soit un pas de 48.
        lda   scroll_vp_v_tiles
        ldb   #3
        mul
        std   tilemap.patch.colStep
        lda   tilemap.patch.col
        ldb   tilemap.patch.colStep+1
        mul
        leay  d,y
        lda   tilemap.patch.row
        ldb   #3
        mul
        leay  d,y
        lda   tilemap.patch.cols
        sta   tilemap.patch.colCnt
@column tfr   y,u
        ldb   tilemap.patch.runLen
@cell   lda   ,x+
        sta   ,u+
        decb
        bne   @cell
        ldd   tilemap.patch.colStep
        leay  d,y
        dec   tilemap.patch.colCnt
        bne   @column
@rts    rts
