********************************************************************************
* AABB.spanX — la boite balayee d'un projectile, construite par ses BORDS
*
* Fichier v2 (pas d'equivalent v1). Cf. docs/lang/en/migration/aabb-screen-projection.md
* et games/r-type/doc/analyse-wrap-boites.md.
*
* Collision_Do compare les centres SUR UN OCTET, modulo 256 : une boite dont un
* bord sort de [0,255] reapparait de l'autre cote de l'ecran. Caler le centre ne
* suffit pas — a bas regime le rayon d'un tir balaye atteint 27 px, et un
* centre cale a 0 laisse la boite courir jusqu'a -27, que le noyau lit 229.
* La seule propriete qui compte : LA BOITE ENTIERE reste dans l'octet. Elle
* s'obtient en raisonnant en bords, pas en centre + rayon :
*
*   arriere = la frontiere avant de la trame precedente (x_prev + demi-largeur)
*   avant   = la frontiere avant courante              (x      + demi-largeur)
*
* Les deux bords sont cales dans [0,255] — un arriere negatif devient 0, la
* boite est coupee au bord de l'ecran et garde son avant — puis seulement
* convertis en centre et rayon. D'une trame a l'autre la couverture est
* contigue, sans recouvrement : a 50 img/s le segment fait la largeur du tir.
*
* Les deux sens sont servis : l'avant peut etre a gauche de l'arriere (tir vers
* la gauche). Le role des registres est fixe, pas leur ordre : la routine sait
* ainsi quel bord est l'avant, qu'elle garde EXACT ; l'arrondi d'une longueur
* impaire mange un pixel a l'arriere, jamais au bout portant.
*
* Entree : D = l'avant (decalage ecran signe, 16 bits : x - camera)
*          X = l'arriere (idem)
*          Y = la boite (AABB)
* Sortie : AABB.cx,y et AABB.rx,y ; D, X detruits ; Y, U intacts.
* Cout : ~60 cycles sans les bords hors champ, +6 par bord cale. Les octets
* intermediaires vivent dans des immediats auto-modifies : le resident est en
* RAM, et la routine n'est appelee que hors interruption.
*
* Le cas ou les deux bords sont du meme cote hors champ donne une boite
* ponctuelle sur le bord de l'ecran : l'objet est alors deja hors de sa zone
* de vie, sa regle de sortie le supprime dans le meme tick.
********************************************************************************

AABB.spanX
        ; l'avant, cale dans [0,255] : le signe de A passe dans la retenue
        tsta
        beq   >
        asla                           ; C = le signe de A
        ldb   #255                     ; au-dela de 255 : 255...
        adcb  #0                       ; ...negatif : 255 + 1 = 0
!       stb   AABB.spanX.front
        ; l'arriere, meme calage
        tfr   x,d
        tsta
        beq   >
        asla
        ldb   #255
        adcb  #0
!       subb  #0                       ; B = arriere - avant
AABB.spanX.front equ *-1               ;   C = 1 : arriere < avant, le tir va a droite
        lda   AABB.spanX.front         ; A = l'avant (lda ne touche pas C)
        bcs   AABB.spanX.right
        ; vers la gauche (ou longueur nulle) : la boite s'etire a droite de l'avant
        lsrb                           ; B = la demi-longueur
        stb   AABB.rx,y
        stb   AABB.spanX.half
        adda  #0                       ; cx = avant + demi-longueur
AABB.spanX.half equ *-1
        sta   AABB.cx,y
        rts
AABB.spanX.right
        ; vers la droite : la boite s'etire a gauche de l'avant
        negb                           ; B = avant - arriere, la longueur
        lsrb                           ; B = la demi-longueur
        stb   AABB.rx,y
        stb   AABB.spanX.halfR
        suba  #0                       ; cx = avant - demi-longueur
AABB.spanX.halfR equ *-1
        sta   AABB.cx,y
        rts
