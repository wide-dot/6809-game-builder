;*******************************************************************************
; LE MANAGER DES GERBES — un seul objet pour toutes les flammes de ventre
;
; POURQUOI UN MANAGER. Une gerbe fait 48 lignes et BuildSprites REJETTE EN BLOC
; ce qui deborde de la bande : elle disparait des que son bas sort, alors que sa
; buse est encore a l'ecran — 44 px de bande morte, pres d'une seconde de jet
; manquant quand le vaisseau descend. La parade est de trancher (quatre fois
; douze lignes ramenent la bande morte a 8 px), mais quatre objets par gerbe et
; quatre reacteurs qui tirent ENSEMBLE feraient seize objets d'un coup.
;
; Le depot a deja ce patron — c'est outslay.Render : un objet qui GARE SA BOITE
; AU CENTRE DE L'ECRAN, donc jamais elimine, et qui peint lui-meme ce qu'il
; veut. Le culling ne le concerne plus : c'est LUI qui decide, tranche par
; tranche, laquelle tient dans la bande.
;
; COMMENT LES REACTEURS LE PILOTENT. Ils ne pondent rien : ils ARMENT UN SLOT
; (flamemgr.Arm, cote cast) dans la table residente, et le premier armement
; fait naitre le manager. Le manager fait descendre les vies, choisit la pose
; par la chaine arcade, dessine, et se retire quand tout est eteint.
;
; DEUX CONTRAINTES DE PAGE ONT DESSINE CE FICHIER :
;  - BuildSprites ne monte QU'UNE page d'images par identifiant, et c'est CETTE
;    page qui est montee quand il appelle notre routine. Les 48 tranches et ce
;    code sont donc dans le MEME direntry, et rien d'ici n'appelle le cast.
;    D'ou les copies locales de layer.evenX / layer.followY / layer.Div : une
;    soixantaine d'octets dupliques valent mieux qu'un montage de page au
;    milieu du dessin.
;  - Les trois gerbes ne tenaient dans une page qu'apres deduplication : la
;    chaine arcade ne designe que QUATRE poses uniques sur ses dix pas
;    (gen_warship_flames.py), soit 15,5 Ko au lieu de 36.
;
; IL PEINT, IL NE TRIE PAS (comme outslay) : le dernier dessine passe dessus.
; Les tranches d'une meme gerbe partent donc du BAS pour que la plus haute,
; cote buse, recouvre les autres.
;
; LES QUATRE TRANCHES SE DESSINENT A LA MEME ANCRE. Elles gardent le canevas de
; 48 lignes de la gerbe et n'en peignent que douze ; l'encodeur rogne les bords
; transparents mais rapporte les bornes au centre du CANEVAS, si bien que
; chaque tranche porte la boite de ses douze lignes tout en partageant l'ancre
; des autres. Le test de bande est donc par tranche, et le dessin sans calcul.
;*******************************************************************************

        INCLUDE "src/enemies/warship-elements/reactor/flame.equ"

;*******************************************************************************
; L'OBJET — il ne fait que vieillir les slots ; tout le dessin se passe dans la
; routine que BuildSprites appelle.
;*******************************************************************************
flamemgr.Object
        lda   routine,u
        bne   flamemgr.Live
        ; La premiere trame : se rendre indelogeable, comme outslay.Render.
        _GetCartPageA
        ldb   id,u
        ldx   #Img_Page_Index
        sta   b,x                      ; le moteur montera NOTRE page
        sta   flamemgr.FakeMf
        ldd   #flamemgr.FakeImg
        std   image_set,u
        clr   render_flags,u           ; coordonnees ecran, boite garee au
        lda   #120                     ; centre : jamais eliminee hors-champ
        sta   x_pixel,u
        lda   #135
        sta   y_pixel,u
        ldb   #4                       ; devant la coque, derriere les pieces
        stb   priority,u
        inc   routine,u
        bsr   flamemgr.Sample
        jmp   DisplaySprite

; LA CAMERA S'ECHANTILLONNE ICI, PAS AU DESSIN. Les pieces calculent leur
; position dans RunObjects, AVANT mscroll.move ; le dessin du manager, lui,
; passe par BuildSprites, APRES. Relire la camera au dessin prenait donc une
; trame d'avance sur les tourelles : 2 px de divergence au gre des trames —
; la gerbe flottait sur sa buse (vecu le 29/08/2026). On fige donc l'arrondi
; de couche et camera.y au TICK, le meme instant que turret.Live, et DrawAll
; consomme ces valeurs. La formule ET l'instant sont ceux des pieces.
flamemgr.Sample
        ldd   mscroll.camera.x
        andb  #$FE                     ; l'arrondi de la couche (layer.evenX)
        std   flamemgr.exs
        ldd   mscroll.camera.y
        std   flamemgr.cys
        rts

flamemgr.Live
        bsr   flamemgr.Sample
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   flamemgr.drop
        ldx   #flamemgr.Slots
        ldb   #flamemgr.SLOTS
        clr   flamemgr.any
@vies   lda   ,x
        beq   @suiv
        suba  flamemgr.drop+1
        bhi   >
        clra                           ; la gerbe est finie
!       sta   ,x
        beq   @suiv
        inc   flamemgr.any
@suiv   leax  flamemgr.SLOTSZ,x
        decb
        bne   @vies
        tst   flamemgr.any
        bne   >
        clr   flamemgr.live            ; plus rien : le prochain armement nous
        jmp   DeleteObject             ; fera renaitre
!       jmp   DisplaySprite

;*******************************************************************************
; LE FAUX IMAGESET — c'est lui qui fait appeler notre routine par BuildSprites.
; Meme forme que celui de l'outslay : quatre renvois vers un sous-bloc, une
; geometrie minuscule (la boite garee), puis la page et l'adresse a appeler.
;*******************************************************************************
flamemgr.FakeImg
        fcb   flamemgr.FakeSub-flamemgr.FakeImg,flamemgr.FakeSub-flamemgr.FakeImg
        fcb   flamemgr.FakeSub-flamemgr.FakeImg,flamemgr.FakeSub-flamemgr.FakeImg
        fcb   8,8,0
flamemgr.FakeSub
        fcb   0
        fcb   flamemgr.FakeMf-flamemgr.FakeSub
        fcb   0
        fcb   flamemgr.FakeMf-flamemgr.FakeSub
        fcb   0,0
flamemgr.FakeMf
        fcb   0                        ; page, patchee a l'Init
        fdb   flamemgr.DrawAll

;*******************************************************************************
; LE DESSIN — appele par BuildSprites, notre page montee, SANS OST sous la main
; (c'est pourquoi la table est statique et residente).
;*******************************************************************************
flamemgr.DrawAll
        lda   #flamemgr.SLOTS
        sta   flamemgr.di
        ldx   #flamemgr.Slots
        stx   flamemgr.sp
@slot   ldx   flamemgr.sp
        lda   ,x
        lbeq  @suiv
        ; le pas de la chaine : (LIFE - vie) / STEP, plafonne au dernier
        nega
        adda  #flamemgr.LIFE
        ldb   #flamemgr.STEP
        lbsr  flamemgr.Div
        cmpa  #9
        bls   >
        lda   #9
!       ldb   1,x                      ; la zone
        aslb
        pshs  a
        ldy   #flame.Chains
        ldy   b,y
        puls  a
        lda   a,y                      ; le rang de la pose unique
        ldb   #2*flamemgr.TRANCHES
        mul
        ldy   #flame.Sets
        pshs  d
        ldb   1,x
        aslb
        ldy   b,y
        puls  d
        leay  d,y                      ; Y = les quatre tranches de la pose
        sty   flamemgr.setp
        ; l'ancre, ramenee de la couche a l'ecran puis au repere du moteur —
        ; avec la camera DU TICK (flamemgr.Sample), jamais celle du moment
        ldd   flamemgr.exs
        pshs  d
        ldd   2,x
        subd  ,s++
        addb  #screen_left
        stb   flamemgr.dx
        ldx   flamemgr.sp
        ldd   4,x
        ldx   6,x
        lbsr  flamemgr.FollowY
        addb  #screen_top
        stb   flamemgr.dy
        ; les quatre tranches, du BAS vers le HAUT : le manager peint sans
        ; trier, la derniere dessinee passe dessus — et c'est la tranche du
        ; haut, cote buse, qui doit rester devant.
        lda   #flamemgr.TRANCHES-1
        sta   flamemgr.t
@tr     lda   flamemgr.t
        asla
        ldx   flamemgr.setp
        ldx   a,x                      ; X = l'imageset de la tranche
        ; LE TEST DE BANDE, par tranche : la geometrie vient de l'imageset
        ; (+11 x1, +4 x_size, +12 y1, +5 y_size), jamais de constantes — le
        ; meme calcul que outslay.RecPublish.
        lda   flamemgr.dx
        adda  11,x
        suba  #screen_left
        cmpa  #screen_right-screen_left
        bhi   @hors
        adda  4,x
        cmpa  #screen_right-screen_left+1
        bhi   @hors
        lda   flamemgr.dy
        adda  12,x
        suba  #screen_top
        cmpa  #screen_bottom-screen_top
        bhi   @hors
        adda  5,x
        cmpa  #screen_bottom-screen_top+1
        bhi   @hors
        ldy   14,x                     ; la routine compilee
        lda   flamemgr.dx
        suba  6,x                      ; le centre pair/impair, comme le moteur
        ldb   flamemgr.dy
        jsr   DRS_XYToAddress
        ldu   <glb_screen_location_2
        jsr   ,y                       ; la routine consomme U
@hors   dec   flamemgr.t
        bpl   @tr
@suiv   ldd   flamemgr.sp
        addd  #flamemgr.SLOTSZ
        std   flamemgr.sp
        dec   flamemgr.di
        lbne  @slot
        rts

;*******************************************************************************
; LES COPIES LOCALES DES SERVICES DE COUCHE — voir l'en-tete : le dessin ne
; peut pas appeler le cast. Meme code que warship-elements/layer.asm.
;*******************************************************************************

; D = ordonnee ecran de naissance, X = camera.y de ce moment -> D = ordonnee
; courante. La derive est REPLIEE : camera.y boucle, une soustraction
; d'absolus sauterait de 384 px a chaque couture.
flamemgr.FollowY
        std   flamemgr.y0
        tfr   x,d
        std   flamemgr.cam0
        ldd   flamemgr.cys             ; la camera du tick, cf. flamemgr.Sample
        subd  flamemgr.cam0
        cmpd  #192
        blt   @bas
        subd  #384
        bra   @fait
@bas    cmpd  #-192
        bge   @fait
        addd  #384
@fait   std   flamemgr.cam0
        ldd   flamemgr.y0
        subd  flamemgr.cam0
        rts

; A / B, quotient dans A.
flamemgr.Div
        pshs  b
        clrb
!       suba  ,s
        bcs   >
        incb
        bra   <
!       tfr   b,a
        puls  b
        rts

flamemgr.di     fcb 0
flamemgr.t      fcb 0
flamemgr.any    fcb 0
flamemgr.dx     fcb 0
flamemgr.dy     fcb 0
flamemgr.sp     fdb 0
flamemgr.setp   fdb 0
flamemgr.drop   fdb 0
flamemgr.exs    fdb 0
flamemgr.cys    fdb 0
flamemgr.y0     fdb 0
flamemgr.cam0   fdb 0

        INCLUDE "src/enemies/warship-elements/reactor/flames.asm"
