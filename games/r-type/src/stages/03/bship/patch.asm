;*******************************************************************************
; bship.patch — LES PATCHES DE LA CARTE mscroll : l'epave des sous-parties
;
; L'ARCADE detruit la coque ZONE PAR ZONE : une sous-partie qui tombe blitte
; sa grille d'epave dans la tilemap de fond (40:c8e8), a la cellule de son
; ancre, et la coque reste ainsi jusqu'au rechargement de la tilemap. Ici le
; meme geste sur la carte mscroll : le builder (<mscroll patches=...>) a
; ajoute les tuiles d'epave au jeu et ecrit, par piece, les cellules a
; reecrire — offset dans la carte, id d'origine, id d'epave
; (gen/stages/03/bship/battleship.patches.asm, dans la page du CAST).
;
; POURQUOI PAS UN SPRITE. La premiere version (10/09/2026) dessinait l'epave
; en sprite de fond chez wsmgr : 1 700 cycles par epave et par rendu, mesures
; sous toje sur un stage qui n'a AUCUNE attente — neuf epaves faisaient
; passer la periode de rendu de 8,3 a 9,1 trames. Refuse par l'auteur. Le
; patch de carte coute une fois, a la mort : zero cycle par trame.
;
; LE PROTOCOLE, celui de tilemap.patch : la piece DEMANDE (bship.patch.request,
; depuis sa page, rien n'est monte) et c'est la boucle de stage qui applique
; (bship.patch.drain), juste apres mscroll.move — la ou le feed tourne, sous
; les memes conditions. Une demande a la fois : une piece dont la demande
; n'est pas prise redemande au tick suivant. Appliquer = monter le cast pour
; copier la table dans un tampon resident, monter la carte pour ecrire les
; ids, puis re-nourrir par mscroll.feedTile chaque colonne du patch qui est
; dans la fenetre du buffer (edge8-1 .. edge8+18, celles que le feed ecrit).
;
; LE CHECKPOINT ne recharge pas la carte (pas de disque) : bship.patch.reset,
; appele par stage.checkpointReset (checkpoint.load, APRES le rejeu du
; defilement — stage.setup ne tourne pas a la reprise), rejoue les ids
; d'ORIGINE de chaque patch applique (le bitmap bship.patch.done, resident,
; survit a la mort) et re-nourrit les colonnes que la fenetre montre, au cas
; ou la reprise tombe sur la coque. A l'ouverture du stage l'unite arrive du
; disque, bitmap a zero : rien a defaire.
;*******************************************************************************
bship.patch.MAXCELLS equ 12            ; Mscroll.PATCH_MAX_CELLS : le builder refuse au-dela

bship.patch.pending  fcb   0           ; rang+1 du patch demande, 0 = rien
bship.patch.done     fcb   0,0,0,0     ; un bit par patch applique (32 au plus)
bship.patch.page0    fcb   0           ; la page cartouche a l'entree
bship.patch.flag     fcb   0           ; 0 = ids d'origine, 1 = l'epave + feed
bship.patch.n        fcb   0
bship.patch.col      fcb   0
bship.patch.buf      fill  0,3+6*bship.patch.MAXCELLS ; n, col0, ncols, puis les cellules

; bship.patch.request — A = le rang du patch (le sous-type de la piece).
; Z = 1 si la demande est prise. Appelable depuis une page.
bship.patch.request
        tst   bship.patch.pending
        bne   @non
        inca
        sta   bship.patch.pending
        clra
@non    rts

; bship.patch.drain — apres mscroll.move : la demande en attente
bship.patch.drain
        lda   bship.patch.pending
        beq   @rts
        clr   bship.patch.pending
        deca
        pshs  a
        tfr   a,b                      ; done[rang/8] |= 1 << (rang & 7)
        lsrb
        lsrb
        lsrb
        ldx   #bship.patch.done
        abx
        anda  #7
        ldb   #1
@bit    tsta
        beq   >
        aslb
        deca
        bra   @bit
!       orb   ,x
        stb   ,x
        puls  a
        ldb   #1                       ; l'epave, et les colonnes re-nourries
        bra   bship.patch.apply
@rts    rts

; bship.patch.reset — a la reprise du checkpoint : chaque patch applique
; reprend ses ids d'origine, les colonnes visibles re-nourries
bship.patch.reset
        clr   bship.patch.pending
        clra
@loop   pshs  a
        tfr   a,b
        lsrb
        lsrb
        lsrb
        ldx   #bship.patch.done
        ldb   b,x
        anda  #7
@sh     tsta
        beq   >
        lsrb
        deca
        bra   @sh
!       lsrb                           ; C = le bit de ce patch
        bcc   @next
        lda   ,s
        clrb                           ; l'origine...
        bsr   bship.patch.apply
        lda   ,s
        ldb   #2                       ; ... et le feed des colonnes visibles
        bsr   bship.patch.apply
@next   puls  a
        inca
        cmpa  #battleship.PATCHES
        blo   @loop
        clr   bship.patch.done
        clr   bship.patch.done+1
        clr   bship.patch.done+2
        clr   bship.patch.done+3
        rts

; bship.patch.apply — A = rang, B = 0 : ecrire les ids d'origine ; 1 : ecrire
; l'epave et re-nourrir ses colonnes visibles ; 2 : re-nourrir seulement.
; Monte la page du cast pour copier la table, celle de la carte pour ecrire,
; et rend la page d'entree — feedTile laisse la sienne.
bship.patch.apply
        stb   bship.patch.flag
        pshs  a
        _GetCartPageA
        sta   bship.patch.page0
        lda   Obj_Index_Page+ObjID_warship_part
        _SetCartPageA                  ; le cast : les tables
        puls  a
        asla
        ldx   #battleship.patches
        ldx   a,x                      ; la table de ce patch
        ldb   ,x                       ; n cellules
        lda   #6
        mul
        addb  #3                       ; n, col0, ncols, puis 6 octets par cellule
        stb   bship.patch.n
        ldy   #bship.patch.buf
@copy   lda   ,x+
        sta   ,y+
        dec   bship.patch.n
        bne   @copy
        lda   mscroll.obj.map.page
        _SetCartPageA                  ; la carte
        lda   bship.patch.flag
        cmpa  #2
        beq   @feed                    ; re-nourrir seulement
        ldy   #bship.patch.buf
        lda   ,y
        sta   bship.patch.n
        beq   @feed                    ; un patch sans cellule changee
        leay  3,y
@cell   ldd   ,y                       ; l'offset dans la carte
        ldx   mscroll.obj.map.address
        leax  d,x
        ldd   2,y                      ; l'id d'origine...
        tst   bship.patch.flag
        beq   >
        ldd   4,y                      ; ... ou celui de l'epave
!       std   ,x
        leay  6,y
        dec   bship.patch.n
        bne   @cell
@feed   tst   bship.patch.flag
        beq   @done
        ldb   bship.patch.buf+2        ; les colonnes du patch
        beq   @done
        stb   bship.patch.n
        lda   bship.patch.buf+1
        sta   bship.patch.col
@col    lda   bship.patch.col
        suba  mscroll.edge8
        inca                           ; colonne - (edge8-1) : dans [0,20) = visible
        cmpa  #20
        bhs   >
        ldb   bship.patch.col
        jsr   mscroll.feedTile         ; monte ses pages, rend celle des donnees
!       inc   bship.patch.col
        dec   bship.patch.n
        bne   @col
@done   lda   bship.patch.page0
        _SetCartPageA
        rts
