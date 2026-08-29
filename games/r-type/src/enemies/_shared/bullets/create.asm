;*******************************************************************************
; createFoeFire — LE POINT DE BASCULE DE TOUT LE JEU
;
; Les neuf familles d'ennemis qui tirent passent par `tryFoeFire` (resident),
; qui monte la page de cet identifiant et saute ici. Cette routine allouait un
; OST ; elle arme desormais un slot du manager. AUCUN code d'ennemi ne change,
; et les tirs cessent d'un coup de peser sur le pool d'objets.
;
; Le calcul lui-meme est celui de la v1, inchange : direction vers le joueur
; par les seize presets de `setDirectionTo`, vitesse lue dans la table de
; presets d'arcade, et le delai d'apparition recopie du tireur.
;
; U pointe l'OST DU TIREUR pendant tout le corps — c'est l'appelant qui le
; fournit, et on ne le modifie pas.
;*******************************************************************************
createFoeFire
        ; La direction : `setDirectionTo` veut le tireur en U et la cible en X,
        ; et rend dans Y le rang du preset (0-63, seize directions).
        ldx   FoeFireTarget
        jsr   setDirectionTo
        lda   #64
        ldb   fireVelocityPreset,u
        decb                           ; 0 = pas de preset, donc 1-7 -> 0-6
        mul
        addd  #createFoeFire.data
        leay  d,y                      ; Y = les deux vitesses du preset
        ldd   ,y
        std   bullet.newvx
        ldd   2,y
        std   bullet.newvy
        lda   fireDisplayDelay,u
        sta   bullet.newdelay
        ; La position de naissance : celle du tireur.
        ldy   y_pos,u
        ldd   x_pos,u
        jsr   bullet.Arm               ; C=0 si la table est pleine
        bcc   @rts
        ; Le slot arme est en X : on y verse ce que le preset a calcule.
        ldd   bullet.newvx
        std   bullet.vx,x
        ldd   bullet.newvy
        std   bullet.vy,x
        lda   bullet.newdelay
        sta   bullet.delay,x
@rts    rts

bullet.newvx    fdb 0
bullet.newvy    fdb 0
bullet.newdelay fcb 0

createFoeFire.data
; V2-DEVIATION: chemin du preset — les tables v1 de global/preset/ vivent
; sous src/common/lib/presets/.
        INCLUDE "src/common/lib/presets/18f90_preset-fireVelocity.asm"
