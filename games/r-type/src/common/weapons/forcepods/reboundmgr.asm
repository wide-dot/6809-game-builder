;*******************************************************************************
; Le laser rebond — LE RENDERER GROUPE de ses passagers
;
; Un laser rebond est une chaine : une tete, qui vole et porte la boite de
; collision, et des passagers qui n'ont aucune logique — ils lisent leur
; position dans l'anneau d'historique de la tete et se dessinent. Chaque
; passager coutait donc un OBJET GRAPHIQUE au moteur, et le plafond
; nb_graphical_objects (64) est ce qui a fait couper la longueur du laser a
; quatre segments au lieu des huit de la borne.
;
; Ici les passagers ne se dessinent plus eux-memes : ils PUBLIENT leur position
; dans un slot, et UN SEUL objet — la routine Render du laser, la septieme —
; les dessine tous en une passe. Vingt-et-un passagers pour un objet graphique.
;
; Modele : bugmgr (src/enemies/bug/mgr.asm), y compris son piege documente —
; le slot se prend AVANT de charger l'imageset, parce que les aides ecrasent X.
;
; PAS DE NOUVEL IDENTIFIANT D'OBJET : l'espace commun est plein (29 sur 29, le
; garde-fou d'objid-common.const.asm refuse le trentieme). Le renderer est donc
; une ROUTINE de plus du laser lui-meme, ce qui a un avantage : Img_Page_Index
; designe deja sa page, il n'y a rien a rapiecer.
;*******************************************************************************

RB.MAXSEG   equ 8       ; la borne s'arrete la, et NOTRE ANNEAU AUSSI : un
                        ; passager lit a bufferIndex - (childId*4 + 6), donc le
                        ; septieme (childId 6) recule de 30 octets dans un
                        ; anneau de 32. Le huitieme lirait une position PLUS
                        ; RECENTE que la tete et se collerait devant elle.
RB.NPASS    equ RB.MAXSEG-1        ; passagers derriere la tete
RB.NSEG     equ RB.MAXSEG          ; slots par chaine : les passagers ET la tete
RB.NCHAIN   equ 3                  ; haut, centre, bas
RB.SLOTSZ   equ 5                  ; [vivant, x_pixel, y_pixel, routine(2)]
RB.NSLOT    equ RB.NCHAIN*RB.NSEG

; LA TETE PASSE PAR LE MEME CHEMIN QUE SA CHAINE (25/08/2026). Elle se
; dessinait par le moteur (DisplaySprite) pendant que ses passagers passaient
; par cette publication : deux chemins differents pour la meme grandeur, et
; l'auteur voyait la tete decalee du reste — a n'importe quelle longueur de
; chaine, donc un ecart CONSTANT, pas une erreur d'espacement (le releve
; d'anneau donne six px reguliers partout).
; Plutot que de faire coincider les deux calculs — le moteur convertit en ligne
; dans BuildSprites, nous par DRS_XYToAddress, et les deux referentiels ne se
; recouvrent pas trivialement — la tete se publie elle aussi, dans le dernier
; slot de sa chaine. Un ecart residuel s'appliquerait alors a TOUT LE MONDE et
; ne se verrait plus ; l'alignement interne est garanti par construction.

; slotMask (1, 2, 4) -> index de chaine (0, 1, 2). Une table de cinq octets
; coute moins qu'un decalage teste.
reboundmgr.chain.tbl
        fcb   0,0,1,0,2

reboundmgr.slots
        fill  0,RB.NSLOT*RB.SLOTSZ

;-------------------------------------------------------------------------------
; reboundmgr.reset — eteindre tous les slots
; Appele par l'orchestrateur au depart d'une volee : les trois chaines
; precedentes sont mortes, leurs slots n'ont plus a etre dessines.
;-------------------------------------------------------------------------------
reboundmgr.reset
        ldx   #reboundmgr.slots
        ldb   #RB.NSLOT
reboundmgr.reset.loop
        clr   ,x
        leax  RB.SLOTSZ,x
        decb
        bne   reboundmgr.reset.loop
        rts

;-------------------------------------------------------------------------------
; reboundmgr.SlotPtr — [y] = le slot du passager courant
; input REG : [u] l'OST du passager
; X PRESERVE : le site d'appel tient deja quelque chose dedans.
;-------------------------------------------------------------------------------
reboundmgr.SlotPtr
        pshs  x
        ldb   slotMask,u
        ldx   #reboundmgr.chain.tbl
        abx
        ldb   ,x                       ; 0, 1 ou 2
        lda   #RB.NSEG
        mul
        addb  childId,u
        adca  #0
        pshs  b
        lda   #RB.SLOTSZ
        ldb   ,s+
        mul
        addd  #reboundmgr.slots
        tfr   d,y
        puls  x,pc

;-------------------------------------------------------------------------------
; reboundmgr.publish — un passager se depose dans son slot au lieu de se dessiner
; input REG : [u] l'OST du passager, position et image_set deja poses
;
; C'est le remplacant de `jmp DisplaySprite` dans le tick des passagers. Le
; cadre est celui de DRS : x ecran + screen_left, y ecran + screen_top.
;-------------------------------------------------------------------------------
reboundmgr.publish
        ldd   x_pos,u
        subd  glb_camera_x_pos
        addd  #screen_left
        tsta                           ; hors du cadre en octet : on cache
        bne   reboundmgr.publish.hide
        stb   reboundmgr.sx
        ; LE SLOT D'ABORD. SlotPtr preserve X, mais l'ordre reste celui de
        ; bugmgr : charger l'imageset ensuite, jamais avant (piege du 22/08 —
        ; un set charge trop tot partait ecrase et BuildSprites sautait dans le
        ; bloc d'instance).
        bsr   reboundmgr.SlotPtr       ; Y = le slot
        ldx   image_set,u
        beq   reboundmgr.publish.hide2 ; pas d'image : rien a publier
        lda   reboundmgr.sx
        ldb   y_pos+1,u
        addb  #screen_top
        bra   reboundmgr.RecPublish
reboundmgr.publish.hide
        bsr   reboundmgr.SlotPtr
reboundmgr.publish.hide2
        clr   ,y
        rts

;-------------------------------------------------------------------------------
; reboundmgr.RecPublish — remplir un slot, avec le meme cull que le moteur
; entree : [a] x ecran, [b] y ecran (cadre DRS), [x] l'imageset, [y] le slot
; L'imageset donne sa geometrie : +4 x_size, +5 y_size, +6 centre pair/impair,
; +11 x1, +12 y1, +14 la routine compilee.
;-------------------------------------------------------------------------------
reboundmgr.RecPublish
        pshs  a,b                      ; ,s = x ecran ; 1,s = y ecran
        ldd   image_x_size,x           ; la geometrie vit sur l'IMAGESET
        sta   reboundmgr.xsize
        stb   reboundmgr.ysize
        lda   image_center_offset,x
        sta   reboundmgr.centre
        ; --- PREMIERE INDIRECTION : le miroir. Nos segments n'en ont pas, donc
        ; le code vaut zero ; on suit quand meme le moteur, qui lit la un des
        ; quatre offsets de l'en-tete d'imageset.
        lda   ,x
        beq   reboundmgr.RecPublish.off
        leax  a,x                      ; X = le SOUS-ENSEMBLE
        ; --- SECONDE INDIRECTION : LA PARITE. C'est elle qui manquait, et c'est
        ; elle qui ouvrait un joint sur deux : le moteur ne pose un sprite qu'au
        ; pas de DEUX pixels, et le laser nait sur une grille de TROIS. Sans
        ; choisir la variante PRE-DECALEE, une position impaire est dessinee a
        ; la place paire et le segment suivant ne se joint plus au precedent.
        ; bugmgr court-circuite ce parcours par des offsets fixes (11,x et 14,x,
        ; soit le miroir 0 et le code 1) : ses records ne se jointent pas, l'ecart
        ; ne s'y voit pas. Ici il se voit.
        lda   ,s
        eora  reboundmgr.centre
        anda  #1
        asla                           ; bit1 = variante decalee d'un pixel
        ora   #1                       ; bit0 = sprite overlay
        tfr   a,b
        lda   b,x
        bne   reboundmgr.RecPublish.mf
        eorb  #%00000010               ; variante absente : le moteur prend
        lda   b,x                      ;   l'autre ET corrige la position
        beq   reboundmgr.RecPublish.off
        bitb  #%00000010               ; BSP_parityFallback : +-1 sur le centre
        beq   reboundmgr.RecPublish.less
        inc   reboundmgr.centre
        bra   reboundmgr.RecPublish.mf
reboundmgr.RecPublish.less
        dec   reboundmgr.centre
reboundmgr.RecPublish.mf
        sta   reboundmgr.mfoff         ; l'offset du meta-sprite, garde
        ; --- le cull, avec x1/y1 du SOUS-ENSEMBLE
        lda   ,s
        adda  image_subset_x1_offset,x
        suba  #screen_left
        cmpa  #screen_right-screen_left
        bhi   reboundmgr.RecPublish.off
        adda  reboundmgr.xsize
        cmpa  #screen_right-screen_left+1
        bhi   reboundmgr.RecPublish.off
        lda   1,s
        adda  image_subset_y1_offset,x
        suba  #screen_top
        cmpa  #screen_bottom-screen_top
        bhi   reboundmgr.RecPublish.off
        adda  reboundmgr.ysize
        cmpa  #screen_bottom-screen_top+1
        bhi   reboundmgr.RecPublish.off
        ; --- le slot
        lda   ,s
        suba  reboundmgr.centre        ; le centre pair/impair, comme le moteur
        sta   1,y
        lda   1,s
        sta   2,y
        lda   reboundmgr.mfoff
        leax  a,x                      ; X = le meta-sprite {page, routine}
        ldd   draw_routine,x
        std   3,y
        lda   #1
        sta   ,y
        puls  a,b,pc
reboundmgr.RecPublish.off
        clr   ,y
        puls  a,b,pc

reboundmgr.xsize  fcb 0
reboundmgr.ysize  fcb 0
reboundmgr.centre fcb 0
reboundmgr.mfoff  fcb 0
reboundmgr.sx   fcb 0
reboundmgr.di   fcb 0
reboundmgr.n    fcb 0
reboundmgr.fill fcb 0
reboundmgr.k    fcb 0
reboundmgr.px   fdb 0
reboundmgr.py   fdb 0
reboundmgr.pset fdb 0

;-------------------------------------------------------------------------------
; reboundmgr.SlotPtrIdx — [y] = le slot d'indice [b] (chaine*RB.NPASS + k)
; X PRESERVE.
;-------------------------------------------------------------------------------
reboundmgr.SlotPtrIdx
        pshs  x
        lda   #RB.SLOTSZ
        mul
        addd  #reboundmgr.slots
        tfr   d,y
        puls  x,pc

;-------------------------------------------------------------------------------
; reboundmgr.pubXY — publier une position deja lue
; input VAR : .px le x de CARTE, .py le y, .pset l'imageset ; [y] le slot
;-------------------------------------------------------------------------------
reboundmgr.pubXY
        ldd   reboundmgr.px
        subd  glb_camera_x_pos
        addd  #screen_left
        tsta                           ; hors du cadre en octet : on cache
        bne   reboundmgr.pubXY.hide
        stb   reboundmgr.sx
        ldx   reboundmgr.pset
        beq   reboundmgr.pubXY.hide
        lda   reboundmgr.sx
        ldb   reboundmgr.py+1
        addb  #screen_top
        jmp   reboundmgr.RecPublish
reboundmgr.pubXY.hide
        clr   ,y
        rts

;-------------------------------------------------------------------------------
; reboundmgr.publishChain — LA TETE DEPOSE TOUTE SA CHAINE
; input REG : [u] la tete, apres son deplacement de la trame
;
; Les passagers ne sont plus des objets : ce sont des lignes de l'anneau. La
; tete en a `nbPass` derriere elle, et le passager k lit a
; (bufferIndex - (k*4 + 6)) & 31 — exactement le recul qu'il prenait quand il
; etait un OST, donc le meme echelonnement de deux ticks.
;
; C'est ce qui rend la longueur arcade gratuite : huit segments ne coutent plus
; qu'un objet et un renderer, la ou ils en coutaient huit.
;-------------------------------------------------------------------------------
reboundmgr.publishChain
        ; --- LA TETE, dans le dernier slot de sa chaine
        ldd   x_pos,u
        std   reboundmgr.px
        ldd   y_pos,u
        std   reboundmgr.py
        ldd   image_set,u
        std   reboundmgr.pset
        ldb   slotMask,u
        ldx   #reboundmgr.chain.tbl
        abx
        ldb   ,x
        lda   #RB.NSEG
        mul
        addb  #RB.NPASS                ; le rang de la tete
        jsr   reboundmgr.SlotPtrIdx
        jsr   reboundmgr.pubXY
        ; --- puis ses passagers
        lda   nbPass,u
        beq   reboundmgr.publishChain.rts
        sta   reboundmgr.n
        ; COMBIEN D'ANNEAU EST DEJA ECRIT. La tete ecrit une entree par tick ;
        ; sa duree de vie decroit du meme pas, donc LASER_LIFETIME moins ce
        ; qu'il en reste EST le nombre de ticks vecus, donc d'entrees ecrites.
        ; Un passager qui remonte plus loin que ca lirait une entree JAMAIS
        ; ECRITE — un zero, publie au bord gauche de la carte. Avec trois
        ; passagers le plus profond ne remontait que 7 ticks et ca ne se voyait
        ; guere ; avec sept il en remonte 15, et la queue de la chaine se
        ; desaligne a chaque naissance (releve du 25/08/2026 : anneau
        ; [363..330, 0,0,0,0], k=5 et k=6 a zero).
        ; La borne dit la meme chose autrement : son pre_delay fait entrer les
        ; segments UN TOUTES LES DEUX TRAMES. Ne rien publier qui n'existe pas
        ; encore, c'est exactement ce deploiement progressif.
        lda   #LASER_LIFETIME
        suba  laserLifetime,u
        cmpa  #16                      ; l'anneau tient seize entrees
        blo   >
        lda   #16
!       sta   reboundmgr.fill
        clr   reboundmgr.k
reboundmgr.publishChain.loop
        lda   reboundmgr.k             ; son recul, en ENTREES : 2k + 3
        asla
        adda  #3
        cmpa  reboundmgr.fill
        bhi   reboundmgr.publishChain.tail
        lda   reboundmgr.k             ; le recul dans l'anneau
        asla
        asla
        adda  #6
        nega
        adda  bufferIndex,u
        anda  #%00011111
        tfr   a,b
        ldx   bufferBase,u
        abx
        ldd   ,x                       ; le x de carte, commun aux deux familles
        std   reboundmgr.px
        lda   routine,u
        cmpa  #Rtn_RunHorizontalLaser
        bne   reboundmgr.publishChain.diag
        ldd   y_pos,u                  ; horizontal : la rangee et l'image ne
        std   reboundmgr.py            ;   changent pas
        ldd   #Img_reboundlaser_horizontal
        bra   reboundmgr.publishChain.pub
reboundmgr.publishChain.diag
        ldd   32,x                     ; diagonale : y et image sont dans les
        std   reboundmgr.py            ;   deux autres plans de l'anneau
        ldd   64,x
reboundmgr.publishChain.pub
        std   reboundmgr.pset
        ldb   slotMask,u               ; le slot : chaine * RB.NSEG + k
        ldx   #reboundmgr.chain.tbl
        abx
        ldb   ,x
        lda   #RB.NSEG
        mul
        addb  reboundmgr.k
        jsr   reboundmgr.SlotPtrIdx
        jsr   reboundmgr.pubXY
        inc   reboundmgr.k
        lda   reboundmgr.k
        cmpa  reboundmgr.n
        blo   reboundmgr.publishChain.loop
reboundmgr.publishChain.rts
        rts
reboundmgr.publishChain.tail
        ; ceux d'apres non plus n'existent pas : leurs slots s'eteignent, sans
        ; quoi ils garderaient l'image de la volee precedente
        ldb   reboundmgr.k
        jmp   reboundmgr.clearChainFrom

;-------------------------------------------------------------------------------
; reboundmgr.clearChainFrom — eteindre les slots d'une chaine A PARTIR d'un rang
; input REG : [u] un segment de la chaine, [b] le premier indice a eteindre
;
; Un PORTEUR touche n'emporte que ce qui est DERRIERE lui — c'est le
; comportement de la borne : les passagers derriere un porteur mort
; disparaissent, le porteur suivant continue. La tete, elle, eteint tout.
;-------------------------------------------------------------------------------
reboundmgr.clearChainFrom
        stb   reboundmgr.k
        ldb   slotMask,u
        ldx   #reboundmgr.chain.tbl
        abx
        ldb   ,x
        lda   #RB.NSEG
        mul
        addb  reboundmgr.k
        jsr   reboundmgr.SlotPtrIdx    ; Y = le premier slot a eteindre
        lda   #RB.NSEG
        suba  reboundmgr.k
        beq   reboundmgr.clearChainFrom.rts
        sta   reboundmgr.n
reboundmgr.clearChainFrom.loop
        clr   ,y
        leay  RB.SLOTSZ,y
        dec   reboundmgr.n
        bne   reboundmgr.clearChainFrom.loop
reboundmgr.clearChainFrom.rts
        rts

reboundmgr.clearChain
        clrb
        bra   reboundmgr.clearChainFrom

;*******************************************************************************
; LE FAUX IMAGESET — ce que BuildSprites croit dessiner. Son entree compilee
; pointe sur DrawAll, qui dessine les vingt-et-un slots. La page n'a pas a etre
; rapiecee : le renderer porte l'identifiant du laser, donc Img_Page_Index le
; designe deja.
;*******************************************************************************
reboundmgr.FakeImg
        fcb   reboundmgr.FakeSub-reboundmgr.FakeImg,reboundmgr.FakeSub-reboundmgr.FakeImg
        fcb   reboundmgr.FakeSub-reboundmgr.FakeImg,reboundmgr.FakeSub-reboundmgr.FakeImg
        fcb   8,8,0
reboundmgr.FakeSub
        fcb   0
        fcb   reboundmgr.FakeMf-reboundmgr.FakeSub
        fcb   0
        fcb   reboundmgr.FakeMf-reboundmgr.FakeSub
        fcb   0,0
reboundmgr.FakeMf
        fcb   0                        ; page, posee a l'init du renderer
        fdb   reboundmgr.DrawAll

;-------------------------------------------------------------------------------
; reboundmgr.DrawAll — la passe de dessin, appelee par BuildSprites SANS OST
; A rebours, comme bugmgr : le plus ancien recouvre.
;-------------------------------------------------------------------------------
reboundmgr.DrawAll
        lda   #RB.NSLOT
        sta   reboundmgr.di
reboundmgr.DrawAll.loop
        dec   reboundmgr.di
        lda   reboundmgr.di
        ldb   #RB.SLOTSZ
        mul
        addd  #reboundmgr.slots
        tfr   d,x
        lda   ,x
        beq   reboundmgr.DrawAll.next
        ldd   1,x                      ; A = x_pixel, B = y_pixel
        pshs  x
        jsr   DRS_XYToAddress
        puls  x
        ldx   3,x
        ldu   <glb_screen_location_2
        jsr   ,x                       ; la routine compilee consomme U
reboundmgr.DrawAll.next
        tst   reboundmgr.di
        bne   reboundmgr.DrawAll.loop
        rts

;-------------------------------------------------------------------------------
; Render — la septieme routine du laser : l'objet qui dessine tous les passagers
; Il ne bouge pas, ne touche rien, et vit tant qu'un slot reste allume.
;-------------------------------------------------------------------------------
Render
        lda   routine_secondary,u
        bne   reboundmgr.RenderLive
        inc   routine_secondary,u
        _GetCartPageA
        sta   reboundmgr.FakeMf        ; la page ou vit DrawAll
        ldd   #reboundmgr.FakeImg
        std   image_set,u
        clr   render_flags,u           ; coordonnees ecran : la boite est parquee
        lda   #120                     ; au centre, jamais eliminee hors-champ
        sta   x_pixel,u
        lda   #135
        sta   y_pixel,u
        ldb   #7                       ; la priorite des segments
        stb   priority,u
        jmp   DisplaySprite
reboundmgr.RenderLive
        ldx   #reboundmgr.slots
        ldb   #RB.NSLOT
reboundmgr.RenderLive.loop
        lda   ,x
        bne   reboundmgr.RenderLive.seen
        leax  RB.SLOTSZ,x
        decb
        bne   reboundmgr.RenderLive.loop
        jmp   DeleteObject             ; plus personne : le renderer s'en va
reboundmgr.RenderLive.seen
        jmp   DisplaySprite
