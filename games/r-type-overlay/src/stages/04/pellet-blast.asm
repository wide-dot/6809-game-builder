;*******************************************************************************
; pellet.blast — la couche de gommes du stage 4
;
; Resident, dans la bande PAR-STAGE de la page 1. C'est ce qui rend la passe
; possible sans acrobatie : le code est en RAM FIXE, donc il lit la page
; cartouche montee (les cartes C et T, page $17) ET ecrit l'ecran ($A000/$C000)
; en meme temps — trois fenetres independantes, aucun conflit.
;
; L'ALGORITHME — prouve en Python avant d'etre ecrit ici
; ------------------------------------------------------
; tools/gen_pellet_tables.py rejoue exactement ce que fait cette routine et
; compare le resultat a l'art, au pixel : 0 divergence sur les 12 phases, champ
; intact, 20 tunnels et 50 % de grignotage aleatoire. Ce fichier transcrit.
;
; Par rangee de cellules (30), on parcourt les PLAGES de gommes consecutives.
; Pour chaque plage, chaque ligne (6) et chaque plan (2), on ecrit les octets
; qui la recouvrent :
;
;   - octet dont les DEUX pixels sont dans la plage -> valeur du motif
;     periodique, indexee par (phase, ligne, plan, j mod 3). La periode est de
;     3 octets par plan : une gomme fait 3 px, un octet en couvre 2, donc le
;     motif se repete tous les lcm(3,4) = 12 px ;
;   - octet de BORD, un seul pixel dans la plage : celui de gauche est le d=0
;     d'une gomme, celui de droite le d=2. Sa valeur ne depend donc que de la
;     ligne — 12 octets de table pour tout le champ.
;
; LES TROUS NE COUTENT RIEN. clearblast a deja pose le fond, et le creux de la
; gomme vaut ce meme fond (le plan arriere arcade du stage 4 est entierement
; noir). La passe n'ecrit que ses plages, en octets PLEINS : pas un seul
; read-modify-write, et rien a faire sur les cellules vides.
;
; LA PHASE SANS DIVISION. Le scroll tient deja scroll_tile_pos (l'index d'octet
; dans la carte, un octet = 24 px = 8 cellules) et scroll_tile_pos_offset24
; (0..23). Comme 24 est multiple de 12, la phase du motif ne depend QUE de
; offset24 : la table geo la donne, avec la premiere cellule a dessiner et leur
; nombre. Aucune division au runtime.
;
; ETAT : version SANS blast. Les octets s'ecrivent un par un. Le PSHS 9 octets
; de clearblast (exactement 3 periodes du motif) est l'optimisation suivante,
; a mesurer contre cette version-ci.
;*******************************************************************************

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "gen/layout.asm"

pellet.blast EXPORT
; Les deux cartes vivent dans l'unite de collision, un autre direntry : leurs
; bases se resolvent au chargement.
collisionMapForeground EXTERNAL
terrainCollision.hard  EXTERNAL

; Les deux plans de l'ecran. La page $E7E5 choisit le tampon ; les adresses,
; elles, sont fixes. Convention verifiee contre DrawTiles et une tuile compilee :
; px X -> plan $C000 si (X >> 1) est pair, sinon $A000 ; octet = X >> 2.
pellet.PLANE_C   equ $C000
pellet.PLANE_A   equ $A000
pellet.STRIDE    equ 40
pellet.VP_Y      equ 11               ; premiere ligne ecran du champ
pellet.ROWS      equ 30               ; rangees de cellules
pellet.MAPW      equ 48               ; octets par rangee de carte

;-------------------------------------------------------------------------------
; Etat de la trame, pose une fois par appel.
;-------------------------------------------------------------------------------
pellet.savedPage fcb 0
pellet.runBase   fdb 0                ; motif de la phase courante
pellet.kFirst    fcb 0                ; premiere cellule relative visible
pellet.kCount    fcb 0                ; combien en parcourir
pellet.x0        fcb 0                ; x ecran de la cellule relative 0 (signe)
pellet.rowsLeft  fcb 0
pellet.rowY      fcb 0                ; ligne ecran du haut de la rangee
pellet.mapPtr    fdb 0                ; C, rangee courante
pellet.mask      rmb 7                ; C AND NOT T sur la travee visible
pellet.runKa     fcb 0
pellet.runKb     fcb 0

pellet.blast
        ; --- la page des cartes, le temps de l'appel
        _GetCartPageA
        sta   pellet.savedPage
        lda   #map.RAM_OVER_CART+collision.page
        _SetCartPageA

        ; --- la geometrie de CETTE trame
        ldb   scroll_tile_pos_offset24   ; 0..23, tenu par le scroll
        aslb                             ; entrees de 4 octets
        aslb
        ldx   #pellet.tbl.geo
        abx
        ldd   ,x                         ; phase x 36 : l'offset du motif
        addd  #pellet.tbl.run
        std   pellet.runBase
        lda   2,x
        sta   pellet.kFirst
        lda   3,x
        sta   pellet.kCount
        ; l'ancre : x ecran de la cellule relative 0, soit 8 - offset24
        ldb   scroll_tile_pos_offset24
        negb
        addb  #8
        stb   pellet.x0

        ; --- la premiere rangee de carte
        ldb   scroll_tile_pos            ; index d'octet dans la rangee
        clra
        addd  #collisionMapForeground
        std   pellet.mapPtr
        lda   #pellet.VP_Y
        sta   pellet.rowY
        lda   #pellet.ROWS
        sta   pellet.rowsLeft

pellet.rowLoop
        ; --- le masque des gommes vivantes de la rangee : C AND NOT T, 7 octets
        ; (7 et pas 6 : la travee visible fait 48 cellules mais commence a un
        ; decalage quelconque dans l'octet de carte).
        ldx   pellet.mapPtr
        ldu   #pellet.mask
        lda   #7
        sta   pellet.mlLeft
pellet.mlLoop
        ldb   pellet.HARDOFF,x           ; T, la meme colonne dans le terrain dur
        comb                             ; NOT T
        andb  ,x                         ; AND C -> les gommes vivantes
        stb   ,u+
        leax  1,x
        dec   pellet.mlLeft
        bne   pellet.mlLoop
        ; --- decouper en plages et dessiner
        jsr   pellet.rowRuns
        ; --- rangee suivante : 6 lignes ecran plus bas, une rangee de carte plus loin
        lda   pellet.rowY
        adda  #6
        sta   pellet.rowY
        ldd   pellet.mapPtr
        addd  #pellet.MAPW
        std   pellet.mapPtr
        dec   pellet.rowsLeft
        bne   pellet.rowLoop
        lda   pellet.savedPage
        _SetCartPageA
        rts

pellet.mlLeft    fcb 0
; L'ecart entre les deux cartes. Il ne peut PAS s'ecrire
; terrainCollision.hard-collisionMapForeground : ce sont deux symboles resolus
; separement au chargement, leur difference n'existe pas a l'assemblage. La
; valeur est donc figee ici — et l'unite de collision porte un garde-fou qui
; refuse d'assembler si les deux cartes cessent d'etre contigues.
pellet.HARDOFF   equ 1440

;-------------------------------------------------------------------------------
; pellet.rowRuns — decouper la rangee en plages de gommes et les dessiner.
; Parcourt kFirst..kFirst+kCount-1 ; bit 7 du premier octet = cellule la plus
; a gauche.
;-------------------------------------------------------------------------------
pellet.rowRuns
        lda   pellet.kFirst
        sta   pellet.rrK
        lda   pellet.kCount
        sta   pellet.rrLeft
        clr   pellet.rrIn
pellet.rrLoop
        lda   pellet.rrK
        jsr   pellet.cellSet             ; Z=1 : cellule vide
        beq   pellet.rrGap
        tst   pellet.rrIn
        bne   pellet.rrNext              ; plage deja ouverte
        lda   pellet.rrK
        sta   pellet.runKa               ; on l'ouvre ici
        inc   pellet.rrIn
        bra   pellet.rrNext
pellet.rrGap
        tst   pellet.rrIn
        beq   pellet.rrNext
        lda   pellet.rrK
        deca
        sta   pellet.runKb               ; la plage finit a la cellule precedente
        clr   pellet.rrIn
        jsr   pellet.drawRun
pellet.rrNext
        inc   pellet.rrK
        dec   pellet.rrLeft
        bne   pellet.rrLoop
        tst   pellet.rrIn                ; une plage ouverte au bord droit
        beq   pellet.rrDone
        lda   pellet.rrK
        deca
        sta   pellet.runKb
        clr   pellet.rrIn
        jsr   pellet.drawRun
pellet.rrDone
        rts

pellet.rrK       fcb 0
pellet.rrLeft    fcb 0
pellet.rrIn      fcb 0

;-------------------------------------------------------------------------------
; pellet.cellSet — la cellule relative A porte-t-elle une gomme vivante ?
; sortie : Z=1 si vide. A preserve.
;-------------------------------------------------------------------------------
pellet.cellSet
        pshs  a,b,x,u
        tfr   a,b
        lsrb
        lsrb
        lsrb                             ; l'octet du masque
        ldx   #pellet.mask
        abx
        anda  #7                         ; le rang du bit dans l'octet
        tfr   a,b
        ldu   #pellet.tbl.bit
        ldb   b,u                        ; le masque du bit
        andb  ,x                         ; pose Z
        puls  a,b,x,u,pc                 ; PULS ne touche pas CC

pellet.tbl.bit   fcb $80,$40,$20,$10,$08,$04,$02,$01

;-------------------------------------------------------------------------------
; pellet.drawRun — dessiner la plage [runKa..runKb] de la rangee courante.
;
; xa = x0 + 3*ka, xb = x0 + 3*kb + 2, les pixels ecran extremes de la plage. La
; geo garantit xa >= 6 et xb <= 153 : la plage deborde d'au plus deux pixels sur
; la bordure, que le masque du champ recouvre en fin de trame — c'est ce que
; fait deja DrawTiles avec sa marge gauche.
;-------------------------------------------------------------------------------
pellet.drawRun
        lda   pellet.runKa
        ldb   #3
        mul                              ; D = 3*ka, tient dans B
        addb  pellet.x0
        stb   pellet.drXa
        lda   pellet.runKb
        ldb   #3
        mul
        addb  pellet.x0
        addb  #2
        stb   pellet.drXb
        ldx   pellet.runBase             ; motif : ligne 0, plan C
        lda   pellet.rowY
        sta   pellet.drY
        clr   pellet.drEdgeIdx
        lda   #6
        sta   pellet.drLine
pellet.drLineLoop
        lda   pellet.drY                 ; l'adresse de la ligne dans les 2 plans
        ldb   #pellet.STRIDE
        mul
        addd  #pellet.PLANE_C
        std   pellet.drBaseC
        subd  #pellet.PLANE_C-pellet.PLANE_A
        std   pellet.drBaseA
        clr   pellet.drPlane
        jsr   pellet.drawPlane
        inc   pellet.drPlane
        jsr   pellet.drawPlane
        leax  6,x                        ; ligne suivante du motif (2 plans x 3)
        inc   pellet.drY
        lda   pellet.drEdgeIdx
        adda  #2
        sta   pellet.drEdgeIdx
        dec   pellet.drLine
        bne   pellet.drLineLoop
        rts

;-------------------------------------------------------------------------------
; pellet.drawPlane — les octets d'un plan pour la ligne courante.
; X pointe le motif de la ligne (plan C) ; le plan A est 3 octets plus loin.
;   ja = (xa - 2p + 2) >> 2   le premier octet dont un pixel touche la plage
;   jb = (xb - 2p) >> 2       le dernier
;-------------------------------------------------------------------------------
pellet.drawPlane
        pshs  x
        lda   pellet.drPlane
        asla
        sta   pellet.dpTwoP
        tst   pellet.drPlane
        beq   pellet.dpPlanC
        leax  9,x
        ldd   pellet.drBaseA
        bra   pellet.dpGo
pellet.dpPlanC
        ldd   pellet.drBaseC
pellet.dpGo
        std   pellet.dpBase
        lda   pellet.drXa
        suba  pellet.dpTwoP
        adda  #2
        lsra
        lsra
        sta   pellet.dpJ
        lda   pellet.drXb
        suba  pellet.dpTwoP
        lsra
        lsra
        sta   pellet.dpJb
        ldb   pellet.dpJ                 ; l'index du motif : ja mod 3
        ldu   #pellet.tbl.mod3
        lda   b,u
        sta   pellet.dpIdx
pellet.dpLoop
        lda   pellet.dpJ
        cmpa  pellet.dpJb
        bhi   pellet.dpDone
        asla                             ; g = 4j + 2p
        asla
        adda  pellet.dpTwoP
        cmpa  pellet.drXa
        blo   pellet.dpLeft              ; g < xa : seul le pixel droit est dedans
        inca                             ; d = g + 1
        cmpa  pellet.drXb
        bhi   pellet.dpRight             ; d > xb : seul le pixel gauche est dedans
        ldb   pellet.dpIdx               ; les deux : le motif periodique
        lda   b,x
        bra   pellet.dpStore
pellet.dpLeft
        ldb   pellet.drEdgeIdx
        ldu   #pellet.tbl.edge
        lda   b,u
        bra   pellet.dpStore
pellet.dpRight
        ldb   pellet.drEdgeIdx
        ldu   #pellet.tbl.edge+1
        lda   b,u
pellet.dpStore
        ldu   pellet.dpBase
        ldb   pellet.dpJ
        leau  b,u
        sta   ,u                         ; l'octet part a l'ecran
        inc   pellet.dpJ                 ; octet suivant, le motif tourne 0,1,2
        lda   pellet.dpIdx
        inca
        cmpa  #3
        blo   pellet.dpKeep
        clra
pellet.dpKeep
        sta   pellet.dpIdx
        bra   pellet.dpLoop
pellet.dpDone
        puls  x,pc

pellet.drXa      fcb 0
pellet.drXb      fcb 0
pellet.drY       fcb 0
pellet.drLine    fcb 0
pellet.drPlane   fcb 0
pellet.drEdgeIdx fcb 0
pellet.drBaseC   fdb 0
pellet.drBaseA   fdb 0
pellet.dpBase    fdb 0
pellet.dpTwoP    fcb 0
pellet.dpJ       fcb 0
pellet.dpJb      fcb 0
pellet.dpIdx     fcb 0

        INCLUDE "src/stages/04/pellet-tables.asm"

 ENDSECTION
