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
        cmpd  #pscroll.CELL_W*54       ; 162 : la fenetre, arrondie au cran de
        bhs   pscroll.grow.no          ; cellule. NON SIGNE : a gauche du ruban
                                       ; la soustraction deborde et tombe ici
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
