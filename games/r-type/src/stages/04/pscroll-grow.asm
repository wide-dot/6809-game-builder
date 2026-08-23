; -----------------------------------------------------------------------------
; pscroll.grow — faire repousser UNE gomme, en coordonnees ECRAN
; -----------------------------------------------------------------------------
; input REG : [x] x ecran du point sonde, [b] ligne ecran
; sortie    : cc.Z = 1 si rien n'a pousse
;
; C'est la signature de cytron (run_cytron etape 5, 0x40:69F8) : l'arcade sonde
; la tuile sous un point et n'ecrit QUE si elle lit TILE_EMPTY — donc jamais
; dans le terrain dur. Ici la meme regle s'obtient gratuitement : setCell refuse
; une cellule deja pleine, et le terrain dur du stage 4 EST du plein dans le
; champ. Reste a passer de l'ecran a la cellule.
;
; L'ancien pellet.grow faisait ses deux divisions par soustractions successives.
; On garde le principe : au plus 53 et 30 tours, une fois par trame et par
; cytron.
; -----------------------------------------------------------------------------
pscroll.grow
        stx   pscroll.grow.x
        stb   pscroll.grow.y
        subb  #field.VP_Y              ; la rangee : (ligne - VP_Y) / 6
        blo   pscroll.grow.no          ; au-dessus du champ
        clra
pscroll.grow.rd
        cmpb  #pscroll.CELL_H
        blo   pscroll.grow.rok
        subb  #pscroll.CELL_H
        inca
        bra   pscroll.grow.rd
pscroll.grow.rok
        cmpa  #pscroll.ROWS
        bhs   pscroll.grow.no          ; sous le champ
        sta   pscroll.grow.row
        ldd   pscroll.grow.x           ; la cellule : (x ecran + camera) / 3
        addd  pscroll.camera.x
        bmi   pscroll.grow.no
        std   pscroll.grow.px
        ldx   #0
pscroll.grow.cd
        ldd   pscroll.grow.px
        cmpd  #pscroll.CELL_W
        blo   pscroll.grow.cok
        subd  #pscroll.CELL_W
        std   pscroll.grow.px
        leax  1,x
        bra   pscroll.grow.cd
pscroll.grow.cok
        ldb   pscroll.grow.row
        jmp   pscroll.setCell          ; il refuse hors ruban et deja pleine
pscroll.grow.no
        orcc  #$04                     ; Z = 1 : rien n'a pousse
        rts

pscroll.grow.x   fdb 0
pscroll.grow.y   fcb 0
pscroll.grow.row fcb 0
pscroll.grow.px  fdb 0

