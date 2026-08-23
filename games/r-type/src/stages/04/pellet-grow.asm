;*******************************************************************************
; pellet.grow — faire repousser UNE gomme du champ du stage 4
;
; C'est l'exact inverse de ce que la Wave Cannon du joueur fait au champ, et
; c'est la signature de cytron (run_cytron etape 5, 0x40:69F8..6A1D). L'arcade
; sonde la tuile de premier plan sous un point et n'ecrit QUE si elle lit
; exactement TILE_EMPTY (0xFA0) : donc jamais dans le terrain dur, qui ne lit
; jamais cette valeur. Ici la meme regle s'ecrit « le bit du champ est a 0 ET
; le bit du terrain dur est a 0 ».
;
; input REG : [x] x ecran du point sonde, [b] ligne ecran
; sortie    : cc.Z = 1 si rien n'a pousse (hors champ, terrain dur, ou deja
;             pleine) — la meme convention que pscroll.setCell
;
; Les deux divisions se font par soustractions : la cellule fait 3 px de large
; et la rangee 6 lignes, donc au plus 53 et 30 tours, une fois par trame et par
; cytron. Si le stage en fait vivre plusieurs a la fois, c'est le premier
; endroit ou mettre une table.
;*******************************************************************************

pellet.grow EXPORT
pellet.grow
        stx   pellet.gx
        stb   pellet.gy

        ; --- la rangee : (ligne - VP_Y) / 6
        subb  #pellet.VP_Y
        blo   @rien                      ; au-dessus du champ
        clra
@rowdiv cmpb  #pellet.CELL_H
        blo   @rowok
        subb  #pellet.CELL_H
        inca
        bra   @rowdiv
@rowok  cmpa  #pellet.ROWS
        bhs   @rien                      ; sous le champ
        sta   pellet.grow.row

        ; --- la cellule relative : (x ecran - x0) / 3
        ldd   pellet.gx
        subb  pellet.x0
        sbca  #0
        blo   @rien                      ; a gauche de la travee
        tsta
        bne   @rien                      ; hors ecran a droite
        clra
@coldiv cmpb  #pellet.CELL_W
        blo   @colok
        subb  #pellet.CELL_W
        inca
        bra   @coldiv
@colok  sta   pellet.grow.k

        ; --- l'octet et le bit, dans la page des cartes
        _GetCartPageA
        sta   pellet.grow.page
        lda   #map.RAM_OVER_CART+collision.page
        _SetCartPageA

        lda   pellet.grow.row            ; rangee * 48
        ldb   #pellet.MAPW
        mul
        addd  #collisionMapForeground
        pshs  d
        lda   pellet.grow.k              ; + l'octet de la cellule
        lsra
        lsra
        lsra
        tfr   a,b
        clra
        addd  ,s++
        tfr   d,x                        ; x = l'octet du champ
        ldb   pellet.grow.k
        andb  #7
        ldu   #pellet.tbl.bit
        ldb   b,u                        ; le masque du bit

        bitb  pellet.HARDOFF,x           ; terrain dur : cytron n'y peut rien
        bne   @fini
        bitb  ,x                         ; deja pleine ?
        bne   @fini
        orb   ,x                         ; elle pousse
        stb   ,x
        lda   pellet.grow.page
        _SetCartPageA
        andcc #$FB                       ; Z = 0 : le champ a change
        rts
@fini   lda   pellet.grow.page
        _SetCartPageA
@rien   orcc  #$04                       ; Z = 1 : rien n'a pousse
        rts

pellet.CELL_W    equ 3                   ; largeur d'une cellule, en px larges
pellet.CELL_H    equ 6                   ; hauteur d'une cellule, en lignes
pellet.gx        fdb 0
pellet.gy        fcb 0
pellet.grow.row  fcb 0
pellet.grow.k    fcb 0
pellet.grow.page fcb 0
