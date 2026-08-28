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
; L'axe x n'a pas besoin de ca — il ne boucle pas.
;*******************************************************************************

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
