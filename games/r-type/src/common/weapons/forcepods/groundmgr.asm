;*******************************************************************************
; Le laser de sol — LE RENDERER GROUPE de ses cellules
;
; Calque de `reboundmgr.asm` (le laser rebond), taille pour DEUX chaines de six
; cellules : la tete marche (obj_groundlaser), les suiveurs n'ont aucune
; logique — ils lisent leur position dans l'anneau de la tete, echelonnes de
; DEUX TICKS par cellule comme la file de deux de la borne, et UN SEUL objet
; graphique (la routine Render du laser) les dessine tous.
;
; La tete passe par le meme chemin que ses suiveurs (lecon du rebond,
; 25/08/2026) : deux calculs de position differents finissent decales d'une
; constante ; un seul chemin rend l'alignement structurel.
;
; ECART assume avec reboundmgr.publishChain : sa queue de deploiement eteint
; les slots depuis le premier suiveur manquant JUSQU'AU BOUT DE LA CHAINE —
; y compris le slot de la tete, publiee juste avant. Ici la queue s'arrete
; AVANT le slot de tete : la tete reste visible pendant le deploiement.
;*******************************************************************************

GL.NSEG    equ 6                     ; cellules par chaine, tete comprise (palier 3)
GL.NCHAIN  equ 2                     ; faisceau A (plafond) et B (sol)
GL.SLOTSZ  equ 5                     ; [vivant, x_pixel, y_pixel, routine(2)]
GL.NSLOT   equ GL.NCHAIN*GL.NSEG

groundmgr.slots
        fill  0,GL.NSLOT*GL.SLOTSZ

; L'ANNEAU de chaque tete : seize entrees de quatre octets (x, y de CARTE).
; Ecrit par TICK (obj_groundlaser, boucle de frame-drop), le suiveur k lit a
; (index - (2k+3)) & 15 — le meme recul en entrees que le rebond, donc le
; meme echelonnement de deux ticks par cellule. Le plus profond (k=4) recule
; de 11 entrees dans un anneau de 16.
groundmgr.ringA
        fill  0,16*4
groundmgr.ringB
        fill  0,16*4

;-------------------------------------------------------------------------------
; groundmgr.reset — eteindre tous les slots (depart d'une volee)
;-------------------------------------------------------------------------------
groundmgr.reset
        ldx   #groundmgr.slots
        ldb   #GL.NSLOT
groundmgr.reset.loop
        clr   ,x
        leax  GL.SLOTSZ,x
        decb
        bne   groundmgr.reset.loop
        rts

;-------------------------------------------------------------------------------
; groundmgr.SlotPtrIdx — [y] = le slot d'indice [b] (chaine*GL.NSEG + k)
; X PRESERVE.
;-------------------------------------------------------------------------------
groundmgr.SlotPtrIdx
        pshs  x
        lda   #GL.SLOTSZ
        mul
        addd  #groundmgr.slots
        tfr   d,y
        puls  x,pc

;-------------------------------------------------------------------------------
; groundmgr.RecPublish — remplir un slot, avec le meme cull que le moteur
; entree : [a] x ecran, [b] y ecran (cadre DRS), [x] l'imageset, [y] le slot
;
; Copie de reboundmgr.RecPublish, parcours d'imageset a deux niveaux compris :
; le miroir (toujours 0 ici) puis LA PARITE — le moteur pose un sprite au pas
; de DEUX pixels et la marche est sur une grille de TROIS : sans la variante
; pre-decalee une position impaire se dessine a la place paire et la cellule
; suivante ne se joint plus (vecu sur le rebond).
;-------------------------------------------------------------------------------
groundmgr.RecPublish
        pshs  a,b                      ; ,s = x ecran ; 1,s = y ecran
        ldd   image_x_size,x           ; la geometrie vit sur l'IMAGESET
        sta   groundmgr.xsize
        stb   groundmgr.ysize
        lda   image_center_offset,x
        sta   groundmgr.centre
        lda   ,x                       ; premiere indirection : le miroir (0)
        beq   groundmgr.RecPublish.off
        leax  a,x                      ; X = le SOUS-ENSEMBLE
        lda   ,s                       ; seconde indirection : la parite
        eora  groundmgr.centre
        anda  #1
        asla                           ; bit1 = variante decalee d'un pixel
        ora   #1                       ; bit0 = sprite overlay
        tfr   a,b
        lda   b,x
        bne   groundmgr.RecPublish.mf
        eorb  #%00000010               ; variante absente : le moteur prend
        lda   b,x                      ;   l'autre ET corrige la position
        beq   groundmgr.RecPublish.off
        bitb  #%00000010               ; BSP_parityFallback : +-1 sur le centre
        beq   groundmgr.RecPublish.less
        inc   groundmgr.centre
        jmp   groundmgr.RecPublish.mf
groundmgr.RecPublish.less
        dec   groundmgr.centre
groundmgr.RecPublish.mf
        sta   groundmgr.mfoff          ; l'offset du meta-sprite, garde
        lda   ,s                       ; le cull, avec x1/y1 du SOUS-ENSEMBLE
        adda  image_subset_x1_offset,x
        suba  #screen_left
        cmpa  #screen_right-screen_left
        bhi   groundmgr.RecPublish.off
        adda  groundmgr.xsize
        cmpa  #screen_right-screen_left+1
        bhi   groundmgr.RecPublish.off
        lda   1,s
        adda  image_subset_y1_offset,x
        suba  #screen_top
        cmpa  #screen_bottom-screen_top
        bhi   groundmgr.RecPublish.off
        adda  groundmgr.ysize
        cmpa  #screen_bottom-screen_top+1
        bhi   groundmgr.RecPublish.off
        lda   ,s                       ; le slot
        suba  groundmgr.centre         ; le centre pair/impair, comme le moteur
        sta   1,y
        lda   1,s
        sta   2,y
        lda   groundmgr.mfoff
        leax  a,x                      ; X = le meta-sprite {page, routine}
        ldd   draw_routine,x
        std   3,y
        lda   #1
        sta   ,y
        puls  a,b,pc
groundmgr.RecPublish.off
        clr   ,y
        puls  a,b,pc

groundmgr.xsize  fcb 0
groundmgr.ysize  fcb 0
groundmgr.centre fcb 0
groundmgr.mfoff  fcb 0
groundmgr.sx     fcb 0
groundmgr.di     fcb 0
groundmgr.k      fcb 0
groundmgr.base   fcb 0               ; chaine * GL.NSEG, l'indice du slot 0
groundmgr.px     fdb 0
groundmgr.py     fdb 0
groundmgr.pset   fdb 0
groundmgr.ring   fdb 0               ; l'anneau de la tete en cours
groundmgr.boom   fcb 0               ; 0 = faisceau, 1 = vague d'explosion
groundmgr.e      fcb 0               ; l'age de la vague (trames depuis gl.boom)

; e' -> offset dans gl.imagesX : l'explosion se joue A REBOURS (le compte
; 0x18 arcade retranche 6 avant d'indexer, donc rangees 3,2,1,0), six trames
; par image.
groundmgr.xidx
        fcb   6,6,6,6,6,6
        fcb   4,4,4,4,4,4
        fcb   2,2,2,2,2,2
        fcb   0,0,0,0,0,0

;-------------------------------------------------------------------------------
; groundmgr.boomSet — l'imageset d'une cellule pendant la vague d'explosion
; input  : [a] e', l'age de la vague SUR CETTE CELLULE (signe)
; output : [d] l'imageset — le faisceau tant que la vague n'est pas la (<0),
;          l'explosion a rebours (0..23), 0 = noir ensuite.
;-------------------------------------------------------------------------------
groundmgr.boomSet
        tsta
        bmi   groundmgr.boomSet.beam
        cmpa  #24
        bhs   groundmgr.boomSet.dark
        ldx   #groundmgr.xidx
        lda   a,x
        ldx   #gl.imagesX
        ldd   a,x
        rts
groundmgr.boomSet.beam
        ldd   groundmgr.fset
        rts
groundmgr.boomSet.dark
        ldd   #0
        rts

;-------------------------------------------------------------------------------
; groundmgr.pubXY — publier une position deja lue
; input VAR : .px le x de CARTE, .py le y, .pset l'imageset ; [y] le slot
;-------------------------------------------------------------------------------
groundmgr.pubXY
        ldd   groundmgr.px
        subd  glb_camera_x_pos
        addd  #screen_left
        tsta                           ; hors du cadre en octet : on cache
        bne   groundmgr.pubXY.hide
        stb   groundmgr.sx
        ldx   groundmgr.pset
        beq   groundmgr.pubXY.hide
        lda   groundmgr.sx
        ldb   groundmgr.py+1
        addb  #screen_top
        jmp   groundmgr.RecPublish
groundmgr.pubXY.hide
        clr   ,y
        rts

;-------------------------------------------------------------------------------
; groundmgr.publishChain — LA TETE DEPOSE TOUTE SA CHAINE
; input REG : [u] la tete, apres sa marche de la trame ;
;             image_set,u = l'imageset de TETE de la trame ;
;             groundmgr.fset = l'imageset de SUIVEUR de la trame (meme phase
;             de scintillement, pose par obj_groundlaser avant l'appel).
;
; Le suiveur k lit l'anneau a (gl_ridx - (2k+3)) & 15 : deux ticks de recul
; par cellule, la file de deux de la borne. Un suiveur dont l'entree n'a
; jamais ete ecrite (gl_fill < 2k+3) n'est pas publie — c'est le deploiement
; progressif, une cellule entre toutes les deux ticks comme le pre_delay
; arcade.
;-------------------------------------------------------------------------------
groundmgr.fset   fdb 0

groundmgr.publishChain
        lda   subtype,u                ; la chaine : faisceau A ou B
        anda  #1
        ldb   #GL.NSEG
        mul
        stb   groundmgr.base
        ; --- LA TETE, dans le dernier slot de sa chaine. La vague d'explosion
        ; l'atteint en premier (e' = e).
        ldd   x_pos,u
        std   groundmgr.px
        ldd   y_pos,u
        std   groundmgr.py
        tst   groundmgr.boom
        beq   groundmgr.pc.headBeam
        lda   groundmgr.e
        jsr   groundmgr.boomSet
        bra   groundmgr.pc.headGo
groundmgr.pc.headBeam
        ldd   image_set,u
groundmgr.pc.headGo
        std   groundmgr.pset
        ldb   groundmgr.base
        addb  #GL.NSEG-1
        jsr   groundmgr.SlotPtrIdx
        jsr   groundmgr.pubXY
        ; --- l'anneau de cette tete — X charge AVANT le test : un LDX entre
        ; le anda et le beq poserait Z selon l'adresse (jamais nulle) et les
        ; deux tetes partageraient ringB (cf. le commentaire d'obj_groundlaser)
        ldx   #groundmgr.ringA
        lda   subtype,u
        anda  #1
        beq   >
        ldx   #groundmgr.ringB
!       stx   groundmgr.ring
        ; --- puis les suiveurs : 2 au palier 2, 5 au palier 3
        ldb   #GL.NSEG-1
        lda   globals.forcepodlevel
        cmpa  #3
        beq   >
        ldb   #2
!       stb   groundmgr.n
        clr   groundmgr.k
groundmgr.publishChain.loop
        lda   groundmgr.k              ; son recul, en ENTREES : 2k + 3
        asla
        adda  #3
        cmpa  gl_fill,u
        bhi   groundmgr.publishChain.tail
        nega                           ; l'entree : (gl_ridx - (2k+3)) & 15
        adda  gl_ridx,u
        anda  #%00001111
        asla                           ; * 4 octets par entree
        asla
        tfr   a,b
        ldx   groundmgr.ring
        abx
        ldd   ,x
        std   groundmgr.px
        ldd   2,x
        std   groundmgr.py
        tst   groundmgr.boom
        beq   groundmgr.pc.folBeam
        lda   groundmgr.e              ; e' = e - (k+1) : la vague remonte la
        suba  groundmgr.k              ;   chaine d'une cellule par trame,
        suba  #1                       ;   comme la propagation arriere arcade
        jsr   groundmgr.boomSet
        bra   groundmgr.pc.folGo
groundmgr.pc.folBeam
        ldd   groundmgr.fset
groundmgr.pc.folGo
        std   groundmgr.pset
        ldb   groundmgr.base
        addb  groundmgr.k
        jsr   groundmgr.SlotPtrIdx
        jsr   groundmgr.pubXY
        inc   groundmgr.k
        lda   groundmgr.k
        cmpa  groundmgr.n
        blo   groundmgr.publishChain.loop
        rts
groundmgr.publishChain.tail
        ; ceux d'apres n'existent pas encore : leurs slots s'eteignent — MAIS
        ; PAS le slot de tete, publie plus haut (ecart assume, cf. en-tete).
        ldb   groundmgr.k
        bra   groundmgr.clearFollowersFrom

groundmgr.n      fcb 0

;-------------------------------------------------------------------------------
; groundmgr.clearFollowersFrom — eteindre les slots SUIVEURS d'une chaine
; input : groundmgr.base pose, [b] le premier indice a eteindre (0..GL.NSEG-2)
;-------------------------------------------------------------------------------
groundmgr.clearFollowersFrom
        stb   groundmgr.k
        addb  groundmgr.base
        jsr   groundmgr.SlotPtrIdx     ; Y = le premier slot a eteindre
        lda   #GL.NSEG-1
        suba  groundmgr.k
        bls   groundmgr.clearFollowersFrom.rts
        sta   groundmgr.di
groundmgr.clearFollowersFrom.loop
        clr   ,y
        leay  GL.SLOTSZ,y
        dec   groundmgr.di
        bne   groundmgr.clearFollowersFrom.loop
groundmgr.clearFollowersFrom.rts
        rts

;-------------------------------------------------------------------------------
; groundmgr.clearChain — eteindre TOUTE la chaine d'une tete (sa mort)
; input REG : [u] la tete
;-------------------------------------------------------------------------------
groundmgr.clearChain
        lda   subtype,u
        anda  #1
        ldb   #GL.NSEG
        mul
        jsr   groundmgr.SlotPtrIdx
        lda   #GL.NSEG
        sta   groundmgr.di
groundmgr.clearChain.loop
        clr   ,y
        leay  GL.SLOTSZ,y
        dec   groundmgr.di
        bne   groundmgr.clearChain.loop
        rts

;*******************************************************************************
; LE FAUX IMAGESET — ce que BuildSprites croit dessiner. Son entree compilee
; pointe sur DrawAll, qui dessine les douze slots. La page n'a pas a etre
; rapiecee : le renderer porte l'identifiant du laser, donc Img_Page_Index la
; designe deja.
;*******************************************************************************
groundmgr.FakeImg
        fcb   groundmgr.FakeSub-groundmgr.FakeImg,groundmgr.FakeSub-groundmgr.FakeImg
        fcb   groundmgr.FakeSub-groundmgr.FakeImg,groundmgr.FakeSub-groundmgr.FakeImg
        fcb   8,8,0
groundmgr.FakeSub
        fcb   0
        fcb   groundmgr.FakeMf-groundmgr.FakeSub
        fcb   0
        fcb   groundmgr.FakeMf-groundmgr.FakeSub
        fcb   0,0
groundmgr.FakeMf
        fcb   0                        ; page, posee a l'init du renderer
        fdb   groundmgr.DrawAll

;-------------------------------------------------------------------------------
; groundmgr.DrawAll — la passe de dessin, appelee par BuildSprites SANS OST
; A rebours, comme le rebond : le plus ancien recouvre.
;-------------------------------------------------------------------------------
groundmgr.DrawAll
        lda   #GL.NSLOT
        sta   groundmgr.di
groundmgr.DrawAll.loop
        dec   groundmgr.di
        lda   groundmgr.di
        ldb   #GL.SLOTSZ
        mul
        addd  #groundmgr.slots
        tfr   d,x
        lda   ,x
        beq   groundmgr.DrawAll.next
        ldd   1,x                      ; A = x_pixel, B = y_pixel
        pshs  x
        jsr   DRS_XYToAddress
        puls  x
        ldx   3,x
        ldu   <glb_screen_location_2
        jsr   ,x                       ; la routine compilee consomme U
groundmgr.DrawAll.next
        tst   groundmgr.di
        bne   groundmgr.DrawAll.loop
        rts

;-------------------------------------------------------------------------------
; Render — la cinquieme routine du laser : l'objet qui dessine les deux chaines
; Il ne bouge pas, ne touche rien, et vit tant qu'un slot reste allume.
;-------------------------------------------------------------------------------
Render
        lda   routine_secondary,u
        bne   groundmgr.RenderLive
        inc   routine_secondary,u
        _GetCartPageA
        sta   groundmgr.FakeMf         ; la page ou vit DrawAll
        ldd   #groundmgr.FakeImg
        std   image_set,u
        clr   render_flags,u           ; coordonnees ecran : la boite est parquee
        lda   #120                     ; au centre, jamais eliminee hors-champ
        sta   x_pixel,u
        lda   #135
        sta   y_pixel,u
        ldb   #7                       ; la priorite des cellules
        stb   priority,u
        jmp   DisplaySprite
groundmgr.RenderLive
        ldx   #groundmgr.slots
        ldb   #GL.NSLOT
groundmgr.RenderLive.loop
        lda   ,x
        bne   groundmgr.RenderLive.seen
        leax  GL.SLOTSZ,x
        decb
        bne   groundmgr.RenderLive.loop
        jmp   DeleteObject             ; plus personne : le renderer s'en va
groundmgr.RenderLive.seen
        jmp   DisplaySprite
