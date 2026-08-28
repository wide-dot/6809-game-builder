;*******************************************************************************
; Suivre la couche battleship — le service partage des pieces du vaisseau
;
; LES DEUX AXES DE LA COUCHE NE SE COMPORTENT PAS PAREIL, et c'est le piege.
;   camera.x est ECRETEE dans [0, largeur-160] (mscroll.asm : « clamp »),
;   camera.y est REPLIEE dans [0, hauteur[   (mscroll.asm : « wrap camera
;   position in map, infinite level loop »).
;
; Une piece rangee en ordonnee ABSOLUE de couche (`y_naissance + camera.y`)
; se calcule donc juste... jusqu'a la premiere couture. Le script de
; choregraphie fait osciller la camera autour de zero : elle passe de 0 a 383
; sans arret, et la difference saute de 384 px a chaque fois. La piece se
; teleporte hors du cadre et se fait retirer — c'est exactement ce qu'on a vu
; le 28/08/2026, des tourelles qui naissent a droite puis disparaissent au
; premier deplacement.
;
; LA PARADE : ne jamais soustraire deux ordonnees absolues, mais mesurer la
; DERIVE DE LA CAMERA depuis la naissance, repliee dans [-192, +192[. Cette
; derive-la est sans ambiguite : l'excursion verticale de tout le script fait
; 103 px, tres en deca de la demi-periode de 192. On garde donc, par piece,
; son ordonnee d'ECRAN a la naissance et la camera de ce moment-la.
;
; L'axe x n'a pas besoin de repli — il ne boucle pas (camera.x est ecretee).
; MAIS IL A SA PROPRE CHAUSSE-TRAPE : le pas horizontal le plus fin du mscroll
; est DEUX PIXELS (decomposition x = 16h + 4b + 2w, la phase 2px par echange
; de zone RAMA/RAMB — pas de phase 1px, il faudrait les tilesets doubles du
; pscroll). La coque s'affiche donc a `M - 2*floor(camera/2)` : elle arrondit
; LA CAMERA a la paire. Une piece qui calcule `M - camera` exact puis laisse
; le moteur de sprites arrondir CE resultat prend l'autre arrondi : 2 px
; d'ecart chaque fois que la camera est impaire, et la parite bascule a
; chaque pixel de course — l'oscillation vue le 28/08/2026.
; La regle : toute derivation d'ecran horizontale attachee a la couche masque
; le bit 0 de camera.x (layer.evenX), le meme arrondi qu'elle.
;*******************************************************************************

; LE RANG RESERVE DE L'OST : le spawner depose l'age du MAITRE dans les deux
; derniers octets de chaque piece a sa naissance (voir spawner.asm). Aucune
; piece n'y range autre chose — c'est la porte par laquelle une piece nee
; en cours de route se cale sur une choregraphie ABSOLUE, celle du script
; d'orientation des reacteurs de ventre.
warship.age0   equ ext_variables+18

; layer.evenX — camera.x quantifiee comme la couche l'affiche (bit 0 masque).
; Rend D. Ne touche que D.
layer.evenX
        ldd   mscroll.camera.x
        andb  #$FE
        rts

; layer.followY
; -------------
; D = l'ordonnee ECRAN a la naissance, X = la camera.y de ce moment.
; Rend D = l'ordonnee ecran courante. Ne touche ni U ni les autres registres
; utiles a l'appelant.
layer.followY
        std   layer.y0
        tfr   x,d
        std   layer.cam0
        ldd   mscroll.camera.y
        subd  layer.cam0               ; la derive brute, qui peut valoir +-384
        cmpd  #192
        blt   @bas
        subd  #384                     ; la couche a passe la couture vers le bas
        bra   @fait
@bas    cmpd  #-192
        bge   @fait
        addd  #384                     ; ... ou vers le haut
@fait   std   layer.cam0               ; la derive, repliee
        ldd   layer.y0
        subd  layer.cam0               ; l'ecran suit la couche
        rts

layer.y0        fdb 0
layer.cam0      fdb 0

; layer.AddPos — deplacer de la vitesse 8.8 en D, compensee de layer.drop
; (pose par l'appelant), sur le champ 24 bits pointe par X. Meme calcul que
; le gouger, le wick et le brood : deux mul non signes, produit tronque juste
; en complement a deux.
layer.AddPos
        pshs  a
        lda   layer.drop+1
        mul
        std   layer.tmp
        puls  a
        ldb   layer.drop+1
        mul
        tfr   b,a
        clrb
        addd  layer.tmp
        pshs  d
        ldb   ,s
        sex
        sta   @a+1
        puls  d
        addd  1,x
        std   1,x
        lda   ,x
@a      adca  #$00
        sta   ,x
        rts

layer.drop      fdb 0
layer.tmp       fdb 0
