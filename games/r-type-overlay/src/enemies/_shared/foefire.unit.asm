;*******************************************************************************
; Le tir ennemi — l'unité paginée du projectile
;
; L'objet que `createFoeFire` fait naître : une balle qui suit la direction
; calculée à sa création, meurt sur le décor ou hors du viewport, et tue le
; joueur au contact sans être détruite par lui.
;
; Le fichier v1 s'appelle déjà `foefire.asm` dans cette arborescence (c'était
; `objects/foefire/obj.asm`), d'où le `.unit` : ce fichier-ci est l'enveloppe,
; pas l'objet.
;
; L'entrée doit être le premier octet : le code d'abord, les tables ensuite.
;*******************************************************************************

foefire.Object EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/map.const.asm"
        ; Le délai d'affichage de la balle est un champ de tir de l'OST.
        INCLUDE "src/common/lib/object.const.asm"
        ; `globals.backgroundSolid` : le décor de fond arrête-t-il les
        ; projectiles ? Équate absolue de la zone réservée `globals`.
        INCLUDE "src/common/state/variables.asm"

; V2-DEVIATION: la v1 nommait ses entrées d'imageset Img_<nom>, gfxcomp les
; génère en set_<nom>. Une table de liaison plutôt qu'un renommage dans
; l'objet, comme pour l'explosion.
Img_foefire_0 equ set_foefire_0
Img_foefire_1 equ set_foefire_1
Img_foefire_2 equ set_foefire_2
Img_foefire_3 equ set_foefire_3

foefire.Object
        INCLUDE "src/enemies/_shared/foefire.asm"

 ENDSECTION
