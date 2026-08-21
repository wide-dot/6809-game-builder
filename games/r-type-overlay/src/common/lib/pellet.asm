;*******************************************************************************
; Les primitives du champ de gommes — terrain solide DESTRUCTIBLE
;
; Inclus par l'unite de collision d'un stage, APRES ses cartes : ce code vit
; dans la meme page qu'elles et les adresse en direct. Voir
; games/r-type-overlay/analyse-gommes-stage4.md et plan-gommes-stage4.md.
;
; LE MODELE
; ---------
; Le stage 4 est une tilemap mutable : le joueur creuse le champ de cellules
; Bydo, Cytron le fait repousser. En arcade les deux ecritures sont exactement
; inverses (tuile 0x9F6 <-> 0xFA0), et la solidite n'est qu'un seuil
; d'identifiant — une gomme EST la collision, il n'y a pas de terrain dessous.
;
; Cote v2, deux masques a la maille de la cellule 3x6 (un bit chacun) :
;
;   C  la carte de collision VIVANTE, celle que terrainCollision lit deja.
;      Terrain dur ET gommes. C'est la seule carte mutable.
;   T  le terrain dur SEUL, statique, jamais ecrit.
;
; Les gommes vivantes ne sont jamais stockees : elles valent C AND NOT T. D'ou
; les trois regles que ce fichier implemente :
;
;   une gomme vivante   C pose ET T libre
;   du terrain dur      C pose ET T pose      -> indestructible
;   une cellule libre   C libre               -> Cytron peut y faire pousser
;
; Consequence voulue : terrainCollision n'est pas modifie d'une ligne. Il lit C
; exactement comme avant, donc aucun ecart au 1:1 v1 a consigner.
;
; LE CONTRAT D'INCLUSION
; ----------------------
; L'unite hote doit avoir defini, avant d'inclure ce fichier :
;   collisionMapForeground   le debut de C
;   terrainCollision.hard    le debut de T, meme geometrie, meme taille
; et avoir inclus terrainCollision.asm (pour loadMap).
;
; L'APPEL
; -------
; Les trois primitives prennent leur cellule dans terrainCollision.sensor.x/y,
; la meme convention que terrainCollision.do — et elles la resolvent par
; loadMap, donc par LE MEME calcul d'adresse que la collision. Une gomme
; effacee est forcement celle que la collision avait trouvee ; les deux ne
; peuvent pas designer des cellules differentes.
;
; Depuis une autre page :
;       ldd   #<x>
;       std   terrainCollision.sensor.x
;       ldd   #<y>
;       std   terrainCollision.sensor.y
;       lda   #map.RAM_OVER_CART+collision.page
;       ldx   #pellet.clear
;       jsr   paged.call
;
; Toutes rendent B : != 0 quand l'action a eu lieu, 0 sinon (et Z pose en
; consequence, donc un simple BEQ suffit).
;
; Le plan arriere n'a pas de gomme : loadMap est appele avec l'index du plan
; AVANT (1), ce qui a l'effet secondaire utile de sauter le decalage
; boss-follow, qui ne concerne que le plan arriere.
;*******************************************************************************

; L'interface franchit une frontiere de direntry (les appelants vivent dans
; d'autres pages) — c'est ce qui justifie l'export, cf. docs/lang/en/symbols.md.
; Les unites de collision des stages sont des ALTERNATIVES a une meme
; destination : ces noms peuvent donc se repeter d'un stage a l'autre.
pellet.test  EXPORT
pellet.clear EXPORT
pellet.set   EXPORT

; L'ecart entre les deux cartes, constant a l'assemblage : la meme colonne dans
; T se lit a cet offset de la rangee de C que loadMap a calculee.
pellet.hard.delta equ terrainCollision.hard-collisionMapForeground

; ---------------------------------------------------------------------------
; pellet.test — y a-t-il une gomme VIVANTE sous le senseur ?
; sortie : B = masque du bit (!= 0) si oui, 0 sinon
;          A = colonne, Y = rangee de C, U = rangee de T (les appelants
;          internes s'en servent, ne pas les clobber)
; ---------------------------------------------------------------------------
pellet.test
        ldb   #1                        ; plan AVANT
        jsr   terrainCollision.loadMap  ; A = colonne, B = masque, Y = rangee C
        leau  pellet.hard.delta,y       ; la meme rangee dans T
        pshs  b                         ; le masque, relu deux fois
        andb  a,y                       ; le bit de C
        beq   @sortie                   ; cellule libre -> B = 0
        ldb   ,s
        andb  a,u                       ; le bit de T
        beq   @gomme                    ; solide et pas dur -> c'est une gomme
        clrb                            ; terrain dur : indestructible
        bra   @sortie
@gomme  ldb   ,s
@sortie leas  1,s
        rts

; ---------------------------------------------------------------------------
; pellet.clear — manger la gomme sous le senseur
; sortie : B != 0 si une gomme a ete mangee (le tir marque, le son se declenche)
; ---------------------------------------------------------------------------
pellet.clear
        bsr   pellet.test
        beq   @rts                      ; rien a manger ici
        comb                            ; ~masque
        andb  a,y                       ; le bit tombe dans C ...
        stb   a,y                       ; ... la cellule devient franchissable
        ldb   #1                        ; mange
@rts    rts

; ---------------------------------------------------------------------------
; pellet.set — faire pousser une gomme sous le senseur (Cytron)
; Refuse le terrain dur et les cellules deja occupees : en arcade Cytron ne
; convertit QUE la tuile vide, jamais du decor.
; sortie : B != 0 si une gomme a pousse
; ---------------------------------------------------------------------------
pellet.set
        ldb   #1                        ; plan AVANT
        jsr   terrainCollision.loadMap
        leau  pellet.hard.delta,y
        pshs  b
        andb  a,u                       ; du terrain dur ici ?
        bne   @non                      ; oui -> refus
        ldb   ,s
        andb  a,y                       ; deja quelque chose ?
        bne   @non                      ; oui -> rien a faire
        ldb   ,s
        orb   a,y                       ; la gomme apparait ...
        stb   a,y                       ; ... et devient solide dans la trame
        ldb   #1
        bra   @sortie
@non    clrb
@sortie leas  1,s
        rts
