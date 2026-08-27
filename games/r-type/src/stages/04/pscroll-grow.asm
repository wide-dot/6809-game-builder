; -----------------------------------------------------------------------------
; pscroll.grow — faire repousser UNE gomme
; -----------------------------------------------------------------------------
; input REG : [x] x du point sonde, en px de CARTE ; [b] ligne ecran
; sortie    : cc.Z = 1 si rien n'a pousse
;
; C'est la signature de cytron (run_cytron etape 5, 0x40:69F8) : l'arcade sonde
; la tuile sous un point et n'ecrit QUE si elle lit TILE_EMPTY — donc jamais
; dans le terrain dur. Ici la meme regle s'obtient gratuitement : setCell refuse
; une cellule deja pleine, et le terrain dur du stage 4 EST du plein dans le
; champ. Reste a passer du pixel a la cellule.
;
; PLUS AUCUNE DIVISION (24/08/2026). Ce qu'il y avait avant, et ce que ca
; coutait : deux divisions par soustractions successives, dont celle par 3 qui
; portait sur la coordonnee de CARTE — donc un nombre de tours qui CROISSAIT
; avec la progression dans le niveau. Releve au profileur : 296 tours par
; appel a la camera 665, 32 cycles le tour, 673 appels en 750 trames, soit
; 42,7 % du temps machine ; 22,6 % a la camera 200. C'etait le premier poste
; du stage, et le seul dont le cout depend d'ou l'on se trouve.
;
; Comment on s'en passe, en trois idees :
;   1. LE RUBAN D'ABORD. mutate refuse tout ce qui sort des dix bandes ; on le
;      teste ICI, avant tout calcul, par une soustraction et une comparaison
;      non signee (qui attrape aussi le negatif). Un cytron qui vient de naitre
;      est a camera+152 et au-dela — hors ecran a droite : son point etait
;      calcule au prix fort puis jete.
;   2. L'ORIGINE DU RUBAN EST DEJA DIVISEE. pscroll.ribbon.cell et .rem
;      portent x0/3 et x0 mod 3, propages d'une bande a l'autre par
;      ribbon.up/.down (16 px = 5 cellules et 1 de reste). Ils ne se
;      recalculent qu'a l'ouverture du stage.
;   3. CE QUI RESTE A DIVISER EST BORNE. L'offset dans le ruban vaut 0..161,
;      plus le reste 0..2 : une table de 176 octets et un `ldb b,x`.
; La rangee suit la meme regle : la ligne dans le champ vaut 0..188, table de
; 192 octets. Cout total ~75 cycles, et CONSTANT.
;
; Reference maison si une plage n'etait pas bornee : DIV3u/DIV6u dans
; src/common/weapons/forcepods/obj_reboundlaser.asm — une reciproque par `mul`
; (85/256, avec sa queue d'arrondi pour une vraie division), ~60 cycles.
; -----------------------------------------------------------------------------
; L'INDEXATION EST `abx`, PAS `b,x`. Le mode indexe par accumulateur du 6809
; SIGNE son offset : une entree au-dela de 127 se lirait avant la table. `abx`
; ajoute B non signe — meme cout (3 cycles), et les deux tables font plus de
; 127 octets.
; ---------------------------------------------------------------------------
; pscroll.erase — MANGER une gomme, meme conversion, autre verbe
; ---------------------------------------------------------------------------
; input REG : [x] x du point sonde, en px de CARTE ; [b] ligne ecran
; sortie    : cc.Z = 1 si rien n'a ete mange
;
; L'inverse de grow, et il n'a besoin d'AUCUN test de durete : depuis que la
; carte des gommes est une carte a elle (gumres.unit.asm), un bit pose y EST
; une gomme. Le decor dur vit dans l'autre plan de collision et n'apparait pas
; ici. C'est la meme simplification que l'arcade obtient par son identifiant de
; tuile — elle n'efface que ce qui lit exactement TILE_GREEN_BALL.
; ---------------------------------------------------------------------------
pscroll.erase
        ldy   #pscroll.clearCell
        bra   pscroll.point

pscroll.grow
        ldy   #pscroll.setCell
pscroll.point
        stx   pscroll.grow.x           ; le x de carte, le temps de la rangee
        subb  #field.VP_Y              ; la rangee : (ligne - VP_Y) / 6
        blo   pscroll.grow.no          ; au-dessus du champ
        ldx   #pscroll.div6.tbl
        abx
        ldb   ,x
        cmpb  #pscroll.ROWS
        bhs   pscroll.grow.no          ; sous le champ
        stb   pscroll.grow.row
        ldd   pscroll.grow.x           ; la colonne : ou dans le ruban ?
        subd  pscroll.ribbon.x0
        ; 180 ET NON 162 (27/08/2026) : l'anneau arcade depasse l'ecran a
        ; droite — un cytron qui vient de naitre y seme, et sa gomme entre a
        ; l'ecran avec le defilement. La fenetre acceptee va donc au-dela du
        ; ruban : mutate pose le bit de carte et ne saute que la VRAM (voir
        ; @maponly). Borne prouvee : le semis le plus a droite possible vaut
        ; preset max (155) + camera - x0 (<=15) + offset de pose max (4,9),
        ; soit un index de table (offset-8+reste) <= 169 — dans les 176
        ; entrees de div3. A gauche du ruban le NON SIGNE refuse toujours.
        cmpd  #pscroll.CELL_W*60       ; 180 : la fenetre elargie
        bhs   pscroll.grow.no

        ; LE BORD DU VIEWPORT (25/08/2026). La carte des gommes n'appartient
        ; pas a pscroll : c'est le PLAN 0 de terrainCollision, la meme grille
        ; que level4_hard.bin — pellet.reset y deplie level4_ball.rle octet
        ; pour octet, et l'extraction verifie `hard OR ball == level4_fc`. Or
        ; cette grille commence au bord GAUCHE DU CHAMP, pas au bord de
        ; l'ecran : terrainCollision.xOffset est declare `equ *-8`, il retire
        ; les 8 px de marge avant de diviser, et son chemin de retour les
        ; rajoute (`addd #8 ; screen border offset`).
        ; Ici la division portait sur le x brut : huit px de decalage, soit
        ; DEUX CELLULES ET DEMIE trop a droite. Effets : les gommes semees par
        ; cytron ne tombaient pas sur la cellule que la collision lit, et
        ; l'effacement demande par un tir — qui vient justement de la sonde de
        ; terrain, donc en coordonnee de terrain — visait une cellule vide et
        ; ne faisait rien (`clearCell` sort sur `bitb ,x / lbeq @already`).
        ; C'est ce que l'auteur voyait : l'impact se pose sur la gomme et la
        ; gomme reste.
        subd  #8
        blo   pscroll.grow.no          ; les 8 px de marge eux-memes

        addb  pscroll.ribbon.rem       ; 0..161 + 0..2, pas de retenue dans A
        ldx   #pscroll.div3.tbl
        abx
        ldb   ,x                       ; (offset + reste) / 3
        ldx   pscroll.ribbon.cell      ; la colonne du bord du ruban
        abx                            ; ... plus la notre
        ldb   pscroll.grow.row
        jmp   ,y                       ; setCell ou clearCell : tous deux
                                       ; refusent hors ruban et sans effet
pscroll.grow.no
        orcc  #$04                     ; Z = 1 : rien n'a pousse
        rts

pscroll.grow.x   fdb 0
pscroll.grow.row fcb 0

        INCLUDE "src/stages/04/pscroll-divtables.asm"

; -----------------------------------------------------------------------------
; pscroll.sweep — EFFACER LE RECTANGLE BALAYE ENTRE DEUX POINTS
; -----------------------------------------------------------------------------
; input REG : [x] le x de carte du coin haut-gauche du bloc au DEPART,
;             [y] le meme x a l'ARRIVEE, [b] la ligne ecran du HAUT,
;             [a] la taille du bloc : quartet HAUT = largeur, BAS = hauteur,
;                 en cellules ($12 = 1x2 pour le beam, $44 = 4x4 pour le pod)
;
; La porte d'entree EN PIXELS de pscroll.clearRect, dont le contrat est en
; cellules — le code objet, lui, ne connait que des pixels et vit dans une
; autre page. La surface couverte est le rectangle balaye par le bloc entre
; les deux points, soit [gauche .. droite+largeur-1] x [haut .. haut+hauteur-1].
;
; POURQUOI CETTE FORME. Le Wave Cannon de la borne (0x40:323B) efface CX
; grappes en avancant d'une cellule par grappe, soit une bande de deux rangees
; sur CX+1 colonnes, REFAITE A CHAQUE TICK. Deux bandes consecutives ne
; different que d'une colonne au bout : leur reunion EST une bande. On demande
; donc la reunion d'un coup, du depart au bout de la portee — un appel par
; trame, quel que soit le nombre de trames sautees, sans boucle de rattrapage.
; C'est la raison d'etre de clearRect (« les armes passent un depart et une
; arrivee, elles ne portent pas de grille », arbitrage auteur du 23/08).
;
; LES BORDS SONT RABOTES, PAS REFUSES. pscroll.point rend la main des qu'un
; point sort du ruban : c'est bon pour UN point, ce serait absurde ici — un
; beam a cheval sur le bord perdrait tout son effacement. Les deux x sont donc
; ramenes dans le ruban.
;
; La conversion est REECRITE ici plutot que partagee avec pscroll.point : ce
; dernier est le chemin chaud du stage (la trainee de cytron, 42,7 % du temps
; machine avant optimisation), et lui imposer deux jsr de plus par appel
; couterait plus que ne coute cette vingtaine d'octets.
; -----------------------------------------------------------------------------
pscroll.sweep
        stb   pscroll.sweep.line
        tfr   a,b                      ; le quartet bas : la hauteur
        andb  #$0F
        stb   pscroll.rect.h
        lsra                           ; le quartet haut : la largeur
        lsra
        lsra
        lsra
        sta   pscroll.rect.w
        tfr   x,d
        bsr   pscroll.sweep.col
        stx   pscroll.rect.c0
        tfr   y,d
        bsr   pscroll.sweep.col
        stx   pscroll.rect.c1
        ldb   pscroll.sweep.line
        bsr   pscroll.sweep.row
        stb   pscroll.rect.r0
        stb   pscroll.rect.r1
        jmp   pscroll.clearRect

; [d] un x de carte -> [x] la colonne, RABOTEE au ruban
pscroll.sweep.col
        subd  pscroll.ribbon.x0
        bhs   pscroll.sweep.col.in
        clra                           ; a gauche du ruban : on colle au bord
        clrb
pscroll.sweep.col.in
        cmpd  #pscroll.CELL_W*54
        blo   pscroll.sweep.col.ok
        ldd   #pscroll.CELL_W*54-1     ; a droite : on colle a l'autre bord
pscroll.sweep.col.ok
        subd  #8                       ; le bord du viewport, cf. pscroll.point
        bhs   pscroll.sweep.col.div
        clra
        clrb
pscroll.sweep.col.div
        addb  pscroll.ribbon.rem       ; 0..153 + 0..2, pas de retenue dans A
        ldx   #pscroll.div3.tbl
        abx
        ldb   ,x
        ldx   pscroll.ribbon.cell      ; la colonne du bord du ruban
        abx                            ; ... plus la notre
        rts

; [b] une ligne ecran -> [b] la rangee, RABOTEE au champ
pscroll.sweep.row
        subb  #field.VP_Y
        bhs   pscroll.sweep.row.in
        clrb                           ; au-dessus du champ : premiere rangee
pscroll.sweep.row.in
        cmpb  #pscroll.div6.SIZE-1     ; la table a une fin, et deux armes
        blo   pscroll.sweep.row.tbl    ; l'adressent maintenant
        ldb   #pscroll.div6.SIZE-1
pscroll.sweep.row.tbl
        ldx   #pscroll.div6.tbl
        abx
        ldb   ,x
        cmpb  #pscroll.ROWS
        blo   pscroll.sweep.row.ok
        ldb   #pscroll.ROWS-1          ; sous le champ : derniere rangee
pscroll.sweep.row.ok
        rts

pscroll.sweep.line fcb 0
