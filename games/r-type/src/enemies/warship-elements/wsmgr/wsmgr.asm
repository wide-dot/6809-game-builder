;*******************************************************************************
; wsmgr — LE MANAGER DES PIECES MOBILES DU VAISSEAU (stage 3), resident
;
; DEMANDE AUTEUR (09/09/2026) : toutes les pieces mobiles en sprite passent
; en priorite de fond et sont dessinees PAR TRANCHES de 16 x 12 au plus, par
; un manager, comme les gerbes. Plan et chiffres :
; doc/plan-warship-sprites-2026-09.md.
;
; POURQUOI DES TRANCHES. BuildSprites rejette EN BLOC un sprite qui deborde de
; la bande. Le sol du stage 3 couvre les 12 px du bas dans 94 % des colonnes,
; jamais 24 : une tranche de 12 lignes qui sort par le bas est deja sous le
; sol, une piece entiere laissait un trou de sa hauteur. Les tranches gardent
; le canevas de leur pose (gen_warship_slices.py), donc partagent son ancre :
; le dessin ne calcule aucun decalage, il teste la bande tranche par tranche.
; En largeur la fenetre est l'ecran elargi de la bordure de 8 px de chaque
; cote (voir wsmgr.DrawAll) : une tranche de 16 px y tient a cheval.
;
; POURQUOI RESIDENT, et non dans une page d'images comme le manager des
; gerbes. BuildSprites ne monte qu'UNE page par identifiant, celle du faux
; imageset ; un manager loge dans une page ne peut dessiner que celle-la. Les
; pieces vivent dans cinq pages : le dessin est donc en RAM permanente, il
; monte lui-meme la page de chaque slot (les descripteurs), puis celle de la
; routine compilee (la meme, sauf pageset), et remonte la page d'entree avant
; de rendre la main. Le faux imageset est en RAM aussi : BuildSprites le lit
; par image_set quelle que soit la page montee.
;
; LE PROTOCOLE. Une piece n'a plus de sprite a elle : a chaque tick elle
; INSCRIT un slot (wsmgr.Draw) — la page de ses descripteurs (posee dans
; wsmgr.page), la liste des tranches de sa pose, et son x, y ecran, ceux de sa
; boite. La liste est consommee et videe par le dessin : rien a armer, rien a
; vieillir, une liste refaite a chaque trame. L'ordre d'inscription est
; l'ordre de peinture (le manager peint, il ne trie pas). Le premier
; inscripteur fait naitre l'objet manager ; quand plus personne ne s'inscrit
; pendant quelques rendus, il se retire.
;
; L'OBJET est de rang 8, le fond : les pieces passent derriere tout autre
; sprite, joueur, tirs, ennemis, effets. Sa boite est garee au centre de
; l'ecran, donc jamais eliminee (le geste des managers du depot).
;
; L'ETAT EST RESIDENT, DONC IL SURVIT AU CHECKPOINT (vecu, 10/09/2026) : une
; mort renvoie au checkpoint sans disque, tous les objets tombent, mais
; wsmgr.live restait a 1 sans objet — plus aucune inscription ne faisait
; renaitre le manager, et les pieces mobiles ne s'affichaient plus. Meme
; chose pour la table des gerbes (flamemgr.live et ses slots). wsmgr.Reset
; remet tout a zero ; le pilote du vaisseau l'appelle a son premier tour
; (warship/spawner.asm), avant que la moindre piece ne naisse.
;*******************************************************************************

wsmgr.SLOTS     equ 24                 ; pieces inscrites au plus par trame
wsmgr.SLOTSZ    equ 6                  ; page des descripteurs, liste (2), x, y,
                                       ; page de la liste (celle de la piece)
wsmgr.LISTMAX   equ 8                  ; tranches par pose au plus (16x12 sur 60x24)
wsmgr.IDLE      equ 4                  ; rendus vides avant de se retirer

wsmgr.Slots     fill  0,wsmgr.SLOTS*wsmgr.SLOTSZ
wsmgr.count     fcb   0                ; inscrits cette trame
wsmgr.live      fcb   0                ; 1 quand l'objet manager existe
wsmgr.idle      fcb   0                ; rendus consecutifs sans inscription
wsmgr.page      fcb   0                ; ENTREE de wsmgr.Draw : la page des descripteurs
wsmgr.page0     fcb   0
wsmgr.n         fcb   0
wsmgr.xy        fdb   0
wsmgr.sp        fdb   0
wsmgr.lp        fdb   0
; LA LISTE EST RECOPIEE ICI avant de monter la page des descripteurs : elle vit
; dans la page de la PIECE (ses tables), qui n'est pas celle de ses images —
; la lire apres le montage lisait n'importe quoi (vecu : stage 3 fige).
wsmgr.list      fill  0,1+2*wsmgr.LISTMAX

;*******************************************************************************
; INSCRIRE une piece. A = x ecran, B = y ecran (0-base, ceux de la boite),
; X = la liste des tranches de la pose (fcb n, fdb sets), wsmgr.page = la
; page de ses descripteurs (Img_Page_Index de la piece). Tout est preserve.
;*******************************************************************************
wsmgr.Reset
        clr   wsmgr.count
        clr   wsmgr.live
        clr   wsmgr.idle
        clr   flamemgr.live
        ldx   #flamemgr.Slots
        ldb   #flamemgr.SLOTS*flamemgr.SLOTSZ
!       clr   ,x+
        decb
        bne   <
        rts

wsmgr.Draw
        pshs  a,b,x
        lda   wsmgr.live
        bne   >
        jsr   LoadObject_x             ; le premier inscripteur fait naitre le manager
        beq   @plein
        lda   #ObjID_warship_wsmgr
        sta   id,x
        inc   wsmgr.live
!       ldb   wsmgr.count
        cmpb  #wsmgr.SLOTS
        bhs   @plein                   ; plus de slot : la piece n'est pas dessinee ce tour
        lda   #wsmgr.SLOTSZ
        mul
        ldx   #wsmgr.Slots
        abx
        lda   wsmgr.page
        sta   ,x
        ldd   2,s                      ; la liste
        std   1,x
        lda   ,s                       ; x, y : au repere du moteur
        adda  #screen_left
        ldb   1,s
        addb  #screen_top
        std   3,x
        _GetCartPageA                  ; la page de la piece : celle de sa liste
        sta   5,x
        inc   wsmgr.count
@plein  puls  a,b,x,pc

;*******************************************************************************
; L'OBJET — il ne fait que tenir le faux imageset et se retirer a l'oisivete ;
; tout le dessin se passe dans la routine que BuildSprites appelle.
;*******************************************************************************
wsmgr.Object
        lda   routine,u
        bne   wsmgr.Live
        _GetCartPageA
        sta   wsmgr.FakeMf             ; n'importe quelle page : la routine est residente
        ldd   #wsmgr.FakeImg
        std   image_set,u
        clr   render_flags,u           ; coordonnees ecran, boite garee au
        lda   #120                     ; centre : jamais eliminee hors-champ
        sta   x_pixel,u
        lda   #135
        sta   y_pixel,u
        ldb   #8                       ; LE FOND : derriere tout autre sprite
        stb   priority,u
        clr   wsmgr.idle
        inc   routine,u
wsmgr.Live
        lda   wsmgr.idle
        cmpa  #wsmgr.IDLE
        blo   >
        clr   wsmgr.live               ; plus de piece : la prochaine
        jmp   DeleteObject             ; inscription nous fera renaitre
!       jmp   DisplaySprite

; LE FAUX IMAGESET (meme forme que celui des gerbes) : quatre renvois vers un
; sous-bloc, une geometrie minuscule (la boite garee), puis la page et
; l'adresse a appeler — la notre, residente.
wsmgr.FakeImg
        fcb   wsmgr.FakeSub-wsmgr.FakeImg,wsmgr.FakeSub-wsmgr.FakeImg
        fcb   wsmgr.FakeSub-wsmgr.FakeImg,wsmgr.FakeSub-wsmgr.FakeImg
        fcb   8,8,0
wsmgr.FakeSub
        fcb   0
        fcb   wsmgr.FakeMf-wsmgr.FakeSub
        fcb   0
        fcb   wsmgr.FakeMf-wsmgr.FakeSub
        fcb   0,0
wsmgr.FakeMf
        fcb   0                        ; page, posee a l'Init
        fdb   wsmgr.DrawAll

;*******************************************************************************
; LE DESSIN — appele par BuildSprites, une page quelconque montee, sans OST.
; Slot par slot : monter la page des descripteurs, puis tranche par tranche
; le containment (_sprite.cull, geometrie lue dans l'imageset), l'adresse
; ecran (DRS_XYToAddress, resident), la page de la routine compilee, l'appel.
;*******************************************************************************
wsmgr.DrawAll
        _GetCartPageA
        sta   wsmgr.page0
        lda   wsmgr.count
        bne   >
        inc   wsmgr.idle
        rts
!       clr   wsmgr.idle
        ldx   #wsmgr.Slots
        stx   wsmgr.sp
@slot   ldx   wsmgr.sp
        ldd   3,x
        std   wsmgr.xy
        lda   5,x
        _SetCartPageA                  ; la page de la piece : sa liste
        ldy   1,x                      ; fcb n, fdb sets — recopiee en RAM
        ldu   #wsmgr.list
        ldb   ,y
        cmpb  #wsmgr.LISTMAX
        bls   >
        ldb   #wsmgr.LISTMAX           ; une liste plus longue est tronquee
!       stb   ,u+
        stb   wsmgr.n
        leay  1,y
        pshs  b                        ; le compteur sur la pile : ldd ecrase B
@copy   ldd   ,y++                     ; (vecu : la copie continuait jusqu'a un
        std   ,u++                     ;  octet nul et recouvrait wsmgr.Draw)
        dec   ,s
        bne   @copy
        leas  1,s
        lda   ,x
        _SetCartPageA                  ; les descripteurs de la piece
        ldy   #wsmgr.list+1
        sty   wsmgr.lp
@tr     ldy   wsmgr.lp
        ldx   ,y++                     ; X = l'imageset de la tranche
        sty   wsmgr.lp
        ldd   wsmgr.xy
        pshs  a,b
        ; LE TEST D'APPARITION, tranche par tranche. En X la fenetre est
        ; l'ecran ELARGI DE LA BORDURE : huit pixels de chaque cote, [-8, 168)
        ; (decision auteur, 09/09/2026). Une tranche fait 16 px au plus et la
        ; ligne qui deborde a droite revient a gauche de la suivante : ce qui
        ; sort de l'ecran par un bord tombe dans la bordure de ce bord ou,
        ; par le retour de ligne, dans celle de l'autre — jamais dans le
        ; champ. La tranche apparait donc des que huit de ses pixels sont
        ; entres, et non quand elle est entiere (elle poppait a 16 px du
        ; bord). Les bornes sont celles du CONTENU (imageset), toujours dans
        ; la tranche theorique. En Y le test reste strict : une tranche de 12
        ; lignes qui sort par le bas est sous le sol (voir l'en-tete).
        lda   ,s
        adda  imgset.x1,x
        suba  #screen_left-8           ; le bord gauche, depuis la bordure gauche
        cmpa  #160+16
        bhi   wsmgr.hors               ; avant la bordure gauche (ou loin a droite)
        adda  imgset.xsize,x           ; le bord droit, meme repere
        cmpa  #160+16
        bhi   wsmgr.hors               ; au-dela de la bordure droite
!       lda   1,s
        adda  imgset.y1,x
        suba  #screen_top
        cmpa  #screen_bottom-screen_top
        bhi   wsmgr.hors
        adda  imgset.ysize,x
        cmpa  #screen_bottom-screen_top+1
        bhi   wsmgr.hors
        lda   ,s
        suba  imgset.center,x          ; la parite du centre, comme le moteur
        ldb   1,s
        jsr   DRS_XYToAddress          ; -> glb_screen_location_2 (resident)
        ldy   14,x                     ; la routine compilee...
        lda   13,x                     ; ... et sa page (celle des descripteurs,
        _SetCartPageA                  ;     sauf pageset)
        ldu   <glb_screen_location_2
        jsr   ,y                       ; la routine consomme U
        ldx   wsmgr.sp
        lda   ,x
        _SetCartPageA                  ; les descripteurs, pour la tranche suivante
wsmgr.hors
        leas  2,s                      ; la pile rendue, sur les deux chemins
        dec   wsmgr.n
        bne   @tr
        ldd   wsmgr.sp
        addd  #wsmgr.SLOTSZ
        std   wsmgr.sp
        dec   wsmgr.count              ; la liste se vide en se dessinant
        lbne  @slot                    ; la boucle depasse les 128 octets
        lda   wsmgr.page0
        _SetCartPageA
        rts
