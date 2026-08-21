* ---------------------------------------------------------------------------
* tilemap.patch — reecrire un rectangle de cellules dans une carte de scroll
* ---------------------------------------------------------------------------
*
* La carte du scroll horizontal n'est pas une table d'identifiants : chaque
* cellule est un POINTEUR de 3 octets vers la routine de la tuile compilee,
* <page><adresse>, cuit au build (voir tilemaps.md). Animer du decor revient
* donc a reecrire ces pointeurs en place, et la trame suivante les dessine.
*
* C'est le geste de l'arcade. R-Type anime le corps de ses boss en repeignant
* un rectangle de la tilemap de fond (gomander_helper_blit_recipe, 0x40:A578,
* 6x4 cellules de (tile_id, attr) ; les epaves du warship font pareil) : le
* decor n'est pas un sprite, et c'est justement ce qui permet a un sprite de
* passer DERRIERE lui — chez nous aussi, le decor etant peint apres les
* sprites depuis le 21/08/2026.
*
* GEOMETRIE. La carte est en colonne-majeur, `scroll_vp_v_tiles` cellules par
* colonne, 3 octets par cellule. Une colonne du rectangle est donc contigue
* des DEUX cotes — source comme destination — et se copie d'un seul bloc de
* rows*3 octets. C'est ce qui rend la routine courte.
*
* PAGINATION. La carte vit dans une page montee en fenetre cartouche ; le
* bloc source, LUI, doit etre directement adressable — zone residente du
* stage, ou page deja montee. Les deux ne peuvent pas etre dans la fenetre en
* meme temps, et le bloc est minuscule (3 octets par cellule : huit images sur
* 2x2 cellules pesent 96 octets, la ou les TUILES qu'elles designent pesent
* des kilo-octets), donc le loger en resident est le choix naturel. La routine
* sauve et restaure la page cartouche.
*
* LES DEUX PLANS. Le scroll lit `map.even` ou `map.odd` selon la parite de la
* camera, et les deux pointent des tuiles DIFFERENTES (variante decalee d'un
* pixel). Une animation doit donc etre appliquee aux deux plans, avec deux
* blocs sources distincts — sauf si la camera est arretee pendant la sequence,
* auquel cas sa parite est figee et un seul plan est jamais lu. La routine
* patche UN plan par appel ; l'appelant decide, et un boss qui coupe le scroll
* peut n'en declarer qu'un.
* ---------------------------------------------------------------------------

; parametres, poses avant l'appel
tilemap.patch.col       fcb   0        ; colonne de destination (coin haut-gauche)
tilemap.patch.row       fcb   0        ; ligne de destination
tilemap.patch.cols      fcb   0        ; largeur du rectangle, en cellules
tilemap.patch.rows      fcb   0        ; hauteur du rectangle, en cellules
tilemap.patch.plane     fcb   0        ; 0 = plan pair, non nul = plan impair

; variables privees
tilemap.patch.colStep   fdb   0        ; pas d'une colonne de carte, en octets
tilemap.patch.runLen    fcb   0        ; octets d'une colonne de rectangle
tilemap.patch.colCnt    fcb   0
tilemap.patch.savedPage fcb   0
tilemap.patch.savedPage2 fcb  0        ; le sequenceur, qui monte avant de lire
tilemap.patch.frameOff  fcb   0        ; l'image courante x2, relevee avant le montage
tilemap.patch.tmpA      fcb   0        ; transit : page montee -> page rendue
tilemap.patch.tmpB      fcb   0

* ---------------------------------------------------------------------------
* tilemap.patch
* -------------
* entree : X = bloc source, cols*rows triplets, COLONNE-MAJEUR
*          les parametres ci-dessus poses
* sortie : X pointe apres le dernier triplet lu
* clobbe : a, b, x, y, u
* ---------------------------------------------------------------------------
tilemap.patch
        _GetCartPageA
        sta   tilemap.patch.savedPage
*
        ; le plan : sa carte et sa page
        lda   tilemap.patch.plane
        bne   @odd
        lda   scroll_map_page_even
        ldy   scroll_map_even
        bra   @mount
@odd    lda   scroll_map_page_odd
        ldy   scroll_map_odd
@mount  _SetCartPageA
*
        ; Le pas d'une colonne de carte : scroll_vp_v_tiles cellules x 3.
        ; L'octet bas suffit au `mul` de la colonne plus bas, et c'est
        ; STRUCTUREL : scroll_vp_v_tiles est la hauteur du VIEWPORT en tuiles,
        ; donc au plus 200/12 = 16 sur cette machine, soit un pas de 48. Il
        ; faudrait une carte de 86 lignes pour deborder, ce que l'ecran
        ; n'autorise pas — rien a verifier ici.
        lda   scroll_vp_v_tiles
        ldb   #3
        mul
        std   tilemap.patch.colStep
*
        ; GARDE. Une geometrie nulle n'est pas benigne ici : `dec`/`bne` sur
        ; zero parcourt 256 tours, donc 256 colonnes de 256 octets, soit toute
        ; la memoire ecrasee. C'est exactement ce qui est arrive le 21/08/2026
        ; quand le descripteur etait lu a travers la mauvaise page. Un symbole
        ; non resolu vaut zero en silence dans ce projet : on refuse le zero
        ; plutot que de lui faire confiance.
        lda   tilemap.patch.cols
        beq   @leave
        lda   tilemap.patch.rows
        beq   @leave
*
        ; les octets d'une colonne de rectangle : rows x 3
        ldb   #3
        mul
        stb   tilemap.patch.runLen
*
        ; Y = premiere cellule visee : base + col * colStep + row * 3
        lda   tilemap.patch.col
        ldb   tilemap.patch.colStep+1
        mul
        leay  d,y
        lda   tilemap.patch.row
        ldb   #3
        mul
        leay  d,y
*
        ; une colonne par tour, chacune d'un seul bloc contigu
        lda   tilemap.patch.cols
        sta   tilemap.patch.colCnt
@column tfr   y,u                      ; U suit la destination dans la colonne
        ldb   tilemap.patch.runLen
@cell   lda   ,x+
        sta   ,u+
        decb
        bne   @cell
        ldd   tilemap.patch.colStep    ; colonne suivante, cote carte
        leay  d,y
        dec   tilemap.patch.colCnt
        bne   @column
*
@leave  lda   tilemap.patch.savedPage
        _SetCartPageA
        rts

* ---------------------------------------------------------------------------
* LE SEQUENCEUR
* -------------
* Une animation de decor est un catalogue de rectangles et une table de
* pointeurs — exactement l'arcade, qui garde huit charges utiles et DEUX
* tables (gomander_engulf_recipe_table_fwd et _rev : les memes payloads, l'une
* a l'endroit, l'autre a l'envers). On garde le catalogue et on jette la
* seconde table : le sens de lecture est une propriete de la LECTURE, pas des
* donnees. Un drapeau coute un octet la ou l'arcade payait seize.
*
* UNE animation, DEUX plans, UNE horloge. Le scroll lit map.even ou map.odd
* selon la parite de la camera, et les deux pointent des tuiles differentes ;
* une animation doit donc etre appliquee aux deux. L'etat porte les deux
* descripteurs et n'avance qu'un compteur — les stepper separement ferait
* courir l'horloge deux fois. Un boss qui coupe le scroll fige la parite de la
* camera : il passe alors 0 comme descripteur impair et n'en declare qu'un.
*
* Le descripteur, emis par <tilepatch> — un par plan, comme <tilemap> :
*
*     fcb   cols            geometrie du rectangle, en cellules
*     fcb   rows
*     fcb   frames          nombre d'images
*     fcb   col             destination dans la carte
*     fcb   row
*     fcb   hold            trames video par image (arcade : 2)
*     fdb   table           `frames` pointeurs de blocs
*
* La geometrie, la destination et le maintien sont lus dans le descripteur
* PAIR : les deux plans decrivent la meme animation au meme endroit, seules
* les tuiles designees changent.
*
* L'etat, porte par l'appelant — huit octets, typiquement dans ses variables
* etendues d'OST, pour que deux animations puissent tourner ensemble.
* ---------------------------------------------------------------------------

        INCLUDE "engine/graphics/tilemap/patch/tilemap-patch.const.asm"

* ---------------------------------------------------------------------------
* tilemap.anim.mount / tilemap.anim.unmount
* -----------------------------------------
* LES DEUX SEULS ENDROITS DU MODULE QUI TOUCHENT A LA PAGINATION.
*
* Trois choses vivent a TROIS endroits differents. L'etat appartient a
* l'appelant (son direntry, ou du resident) ; le descripteur et les blocs
* vivent dans le direntry de la CARTE, choisi ainsi pour qu'UNE page rende
* lisibles a la fois la source et la destination ; le module, lui, est
* resident et toujours la. Une lecture faite du mauvais cote de ces deux
* appels ne rate pas bruyamment : elle rend les octets qui trainent la.
*
* Trois defauts successifs sont sortis de la avant que la regle ne soit posee
* — cols/rows a zero et 64 Ko ecrases, l'index d'image faux et des cellules
* vides, hold a zero et la boucle de rattrapage sans fin. D'ou le
* confinement : hors de ces deux routines et d'applyOne, personne ne monte
* rien, et rien de pagine n'est lu.
* ---------------------------------------------------------------------------
tilemap.anim.mount
        _GetCartPageA
        sta   tilemap.patch.savedPage2
        lda   tilemap.patch.plane
        bne   @o
        lda   scroll_map_page_even
        bra   @s
@o      lda   scroll_map_page_odd
@s      _SetCartPageA
        rts
tilemap.anim.unmount
        lda   tilemap.patch.savedPage2
        _SetCartPageA
        rts

* ---------------------------------------------------------------------------
* tilemap.anim.cache
* ------------------
* entree : X = etat, Y = descripteur pair
* Recopie dans l'etat les deux octets que l'horloge relit a chaque tour.
* ---------------------------------------------------------------------------
tilemap.anim.cache
        jsr   tilemap.anim.mount
        lda   tilemap.desc.frames,y
        sta   tilemap.patch.tmpA
        lda   tilemap.desc.hold,y
        sta   tilemap.patch.tmpB
        jsr   tilemap.anim.unmount
        lda   tilemap.patch.tmpA       ; l'etat n'est adressable qu'ici, page rendue
        sta   tilemap.anim.frames,x
        lda   tilemap.patch.tmpB
        sta   tilemap.anim.hold,x
        rts

* ---------------------------------------------------------------------------
* tilemap.anim.start
* ------------------
* entree : X = etat, Y = descripteur pair, U = descripteur impair (0 = aucun)
*          B = sens (0 avant, non nul arriere)
* Pose l'image de depart et l'APPLIQUE : une animation qui demarre doit se
* voir a la trame ou elle demarre, pas a la suivante.
* clobbe : a, b, y, u  (X est preserve)
* ---------------------------------------------------------------------------
tilemap.anim.start
        sty   tilemap.anim.descEven,x
        stu   tilemap.anim.descOdd,x
        stb   tilemap.anim.dir,x
        clr   tilemap.anim.flags,x
        clr   tilemap.anim.frame,x
        jsr   tilemap.anim.cache       ; frames et hold, une fois pour toutes
        tstb
        beq   >
        lda   tilemap.anim.frames,x    ; a l'envers : on part de la derniere
        deca
        sta   tilemap.anim.frame,x
!       lda   tilemap.anim.hold,x
        sta   tilemap.anim.timer,x
        bra   tilemap.anim.apply

* ---------------------------------------------------------------------------
* tilemap.anim.step
* -----------------
* entree : X = etat
* sortie : Z = 1 si l'animation est terminee
*
* Fait avancer l'horloge de `gfxlock.frameDrop.count` trames video — la meme
* compensation que partout ailleurs — et n'applique le rectangle que lorsque
* l'image CHANGE. Une image tenue deux trames ne recopie donc pas ses cellules
* deux fois.
* clobbe : a, b, y, u  (X est preserve)
* ---------------------------------------------------------------------------
tilemap.anim.step
        lda   tilemap.anim.flags,x
        bita  #tilemap.anim.DONE
        bne   @done
*
        lda   tilemap.anim.timer,x
        suba  gfxlock.frameDrop.count
        bgt   @keep                    ; le maintien court encore
*
        ; RATTRAPAGE. Une boucle de jeu couvre plusieurs trames video ; un
        ; maintien de 2 trames peut donc etre franchi DEUX fois dans le meme
        ; tour. On avance d'autant d'images que le retard en contient, et on
        ; n'applique le rectangle qu'UNE fois, sur l'image d'arrivee — les
        ; intermediaires ne seraient jamais vues. Le reste du retard est
        ; reporte sur le maintien suivant, comme pour les segments d'outslay.
        ; (Le descripteur garantit hold >= 1, sans quoi ceci bouclerait ;
        ; <tilepatch> le refuse au build.)
@catchup
        ldb   tilemap.anim.frame,x
        tst   tilemap.anim.dir,x
        bne   @backward
        incb
        cmpb  tilemap.anim.frames,x
        bhs   @finish
        bra   @advance
@backward
        tstb
        beq   @finish
        decb
@advance
        stb   tilemap.anim.frame,x
        adda  tilemap.anim.hold,x
        ble   @catchup                 ; toujours en retard : encore une image
        sta   tilemap.anim.timer,x
        jsr   tilemap.anim.apply       ; une seule fois, sur l'image d'arrivee
        andcc #$FB                     ; Z = 0 : elle tourne encore
        rts
@keep   sta   tilemap.anim.timer,x
        andcc #$FB
        rts
@finish
        lda   tilemap.anim.flags,x
        ora   #tilemap.anim.DONE
        sta   tilemap.anim.flags,x
@done   orcc  #$04                     ; Z = 1 : terminee
        rts

* ---------------------------------------------------------------------------
* tilemap.anim.apply
* ------------------
* entree : X = etat
* Applique l'image courante AUX DEUX PLANS. Point d'entree utilisable seul,
* pour poser une image precise sans faire tourner l'horloge.
* clobbe : a, b, y, u  (X est preserve)
* ---------------------------------------------------------------------------
tilemap.anim.apply
        pshs  x
        ldy   tilemap.anim.descEven,x
        clr   tilemap.patch.plane
        jsr   tilemap.anim.applyOne
        ldx   ,s                       ; l'etat, sans le depiler
        ldy   tilemap.anim.descOdd,x
        beq   >                        ; pas de plan impair declare
        lda   #1
        sta   tilemap.patch.plane
        jsr   tilemap.anim.applyOne
!       puls  x,pc

* Un plan : Y = son descripteur, X = l'etat (pour l'image courante).
*
* LE DESCRIPTEUR ET LES BLOCS VIVENT DANS LE DIRENTRY DE LA CARTE. C'est ce
* qui rend le schema tenable : une seule page a monter les rend lisibles EN
* MEME TEMPS que la carte ou l'on ecrit, alors que source et destination
* seraient sinon deux pages a la fois dans une seule fenetre.
*
* D'ou ce montage AVANT la premiere lecture. Sans lui on lit le descripteur a
* travers la page de l'appelant : cols et rows sortent des octets qui trainent
* la — a zero le 21/08/2026 — et la copie part sur toute la memoire.
tilemap.anim.applyOne
        ldb   tilemap.anim.frame,x     ; l'etat : lu dans la page de l'APPELANT
        aslb
        stb   tilemap.patch.frameOff
*
* L'ETAT EST LU AVANT LE MONTAGE, le descripteur APRES. Les deux ne vivent pas
* dans la meme page : l'etat appartient a l'appelant (son direntry, ou du
* resident) et le descripteur au direntry de la carte. Monter puis lire l'etat
* le lisait a travers la page de la carte — l'index d'image sortait faux,
* `abx` sortait de la table, et le bloc copie etait une zone de zeros. C'est
* le meme piege que celui du descripteur, un cran plus loin : ici DEUX pages
* sont en jeu et chaque lecture doit savoir laquelle est montee.
        jsr   tilemap.anim.mount
        lda   tilemap.desc.cols,y
        sta   tilemap.patch.cols
        lda   tilemap.desc.rows,y
        sta   tilemap.patch.rows
        lda   tilemap.desc.col,y
        sta   tilemap.patch.col
        lda   tilemap.desc.row,y
        sta   tilemap.patch.row
        ldb   tilemap.patch.frameOff   ; releve plus haut, avant le montage
        ldx   tilemap.desc.table,y
        abx
        ldx   ,x
        jsr   tilemap.patch            ; il remonte la meme page : sans effet
        jmp   tilemap.anim.unmount
