;*******************************************************************************
; LA TABLE DES GERBES — resident, parce qu'elle a deux lecteurs dans deux pages
;
; Les reacteurs de ventre vivent dans la page du cast, le manager dans la page
; des flammes ; l'un arme, l'autre dessine. Une table dans l'une des deux pages
; obligerait l'autre a la monter — donc elle vit dans l'arene RESIDENTE, que
; les deux atteignent sans rien monter, et qui arrive ZEROEE (chargee comme un
; fichier de zeros, cf. outslay/res.unit.asm).
;
; Un slot : vie, zone, puis l'ancrage a la COUCHE — abscisse en repere de
; couche et le couple (ordonnee ecran, camera.y) de la naissance, le meme
; ancrage que toutes les pieces du vaisseau (warship-elements/layer.asm).
; La gerbe suit donc le vaisseau pendant sa seconde de vie.
;*******************************************************************************

        INCLUDE "src/enemies/warship-elements/reactor/flame.equ"

flamemgr.Slots EXPORT
flamemgr.live  EXPORT

 SECTION code

flamemgr.Slots  fill  0,flamemgr.SLOTS*flamemgr.SLOTSZ
flamemgr.live   fcb   0                ; 1 quand l'objet manager existe

 ENDSECTION
