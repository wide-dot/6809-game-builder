;*******************************************************************************
; LE MANAGER DES GERBES — un seul objet pour toutes les flammes de ventre
;
; POURQUOI UN MANAGER. Quatre reacteurs tirent ENSEMBLE, chacun une gerbe de
; 48 lignes qui vit une seconde : des objets par gerbe feraient seize objets
; d'un coup. Les reacteurs ne pondent donc rien : ils ARMENT UN SLOT
; (flamemgr.Arm, children.asm) dans la table residente (flameslots.asm), et
; le premier armement fait naitre cet objet. Il fait descendre les vies,
; choisit la pose par la chaine arcade, et se retire quand tout est eteint.
;
; IL NE DESSINE PLUS RIEN LUI-MEME (09/09/2026, decision auteur : les gros
; sprites mobiles du vaisseau passent par le manager de tranches wsmgr, en
; priorite de fond). A chaque tick, pour chaque gerbe vivante, il INSCRIT chez
; wsmgr la liste des tranches 16x12 de sa pose (flames.asm) avec son ancre
; ecran. C'est wsmgr qui teste la bande tranche par tranche et monte la page
; des flammes. Consequences :
;  - ce code vit dans le CAST, comme les reacteurs qui l'arment : plus de
;    copies locales des services de couche, plus de faux imageset, et la page
;    des flammes ne contient plus que de l'art ;
;  - l'ancre est calculee AU TICK, avec la camera du tick, le meme instant
;    que les pieces (l'ancien dessin relisait la camera au rendu et flottait
;    d'une trame — vecu le 29/08/2026) ;
;  - la page des DESCRIPTEURS que wsmgr monte se lit dans Img_Page_Index :
;    celle de cet identifiant pour les gerbes basse et droite (imgFlame),
;    celle des tourelles pour la gauche — les trois ne tiennent plus dans
;    une page tranchees en 16x12 (flame.PageIds, flames.asm).
;*******************************************************************************

        INCLUDE "src/enemies/warship-elements/reactor/flame.equ"

flamemgr.Object
        lda   routine,u
        bne   flamemgr.Live
        inc   routine,u
flamemgr.Live
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   flamemgr.drop
        jsr   layer.evenX
        std   flamemgr.exs             ; l'arrondi de couche du tick
        ldx   #flamemgr.Slots
        ldb   #flamemgr.SLOTS
        clr   flamemgr.any
@vies   stx   flamemgr.sp
        stb   flamemgr.di
        lda   ,x
        beq   @suiv
        ; LA POSE DE CE RENDU SE LIT SUR LA VIE D'AVANT LE VIEILLISSEMENT :
        ; un rendu compense sept trames en moyenne, vieillir d'abord sautait
        ; toujours la pose 0 — la bouffee initiale, celle qui fait
        ; l'apparition (vecu le 09/09/2026). L'arcade la tient cinq trames.
        pshs  a
        suba  flamemgr.drop+1
        bhi   >
        clra                           ; la gerbe est finie apres ce rendu
!       sta   ,x
        beq   >
        inc   flamemgr.any
!       puls  a
        ; le pas de la chaine : (LIFE - vie) / STEP, plafonne au dernier
        nega
        adda  #flamemgr.LIFE
        ldb   #flamemgr.STEP
        bsr   flamemgr.Div
        cmpa  #9
        bls   >
        lda   #9
!       ldb   1,x                      ; la zone
        ldy   #flame.PageIds           ; la page des tranches de cette gerbe :
        ldb   b,y                      ; Img_Page_Index de l'identifiant qui
        ldy   #Img_Page_Index          ; porte son fichier d'images (deux pages
        ldb   b,y                      ; pour les trois gerbes)
        stb   wsmgr.page
        ldb   1,x
        aslb
        pshs  a
        ldy   #flame.Chains
        ldy   b,y
        puls  a
        lda   a,y                      ; le rang de la pose unique
        asla
        ldy   #flame.Sets
        ldy   b,y
        ldy   a,y                      ; Y = la liste des tranches de la pose
        ; l'ancre : abscisse de couche ramenee a l'ecran par la camera du
        ; tick, ordonnee suivie depuis la naissance (layer.followY)
        ldd   2,x
        subd  flamemgr.exs
        pshs  b                        ; x ecran, 0-base
        ldd   4,x
        ldx   6,x
        jsr   layer.followY            ; D = y ecran courant (Y intact)
        puls  a                        ; A = x, B = y
        tfr   y,x
        jsr   wsmgr.Draw
@suiv   ldx   flamemgr.sp
        leax  flamemgr.SLOTSZ,x
        ldb   flamemgr.di
        decb
        bne   @vies
        tst   flamemgr.any
        bne   >
        clr   flamemgr.live            ; plus rien : le prochain armement nous
        jmp   DeleteObject             ; fera renaitre
!       rts

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
flamemgr.any    fcb 0
flamemgr.sp     fdb 0
flamemgr.drop   fdb 0
flamemgr.exs    fdb 0

        INCLUDE "src/enemies/warship-elements/reactor/flames.asm"
