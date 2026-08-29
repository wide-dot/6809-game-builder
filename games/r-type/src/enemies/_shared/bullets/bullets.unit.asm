;*******************************************************************************
; L'UNITE DU MANAGER DE TIRS — la page qui porte tout
;
; Elle contient le manager, sa table, `createFoeFire` et les images des balles.
; C'est voulu : BuildSprites monte la page d'images de l'objet avant d'appeler
; sa routine de dessin, et `tryFoeFire` monte la meme page pour appeler
; `createFoeFire`. Une seule page, donc plus un seul montage par balle.
;
; L'entree doit etre le premier octet : le code d'abord, les tables ensuite.
;*******************************************************************************

foefire.Object EXPORT
createFoeFire  EXPORT
bullet.ArmV    EXPORT
; Le resident du stage : le manager y patche sa page a sa naissance.
Img_Page_Index EXTERNAL

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "src/common/lib/object.const.asm"
        ; `globals.backgroundSolid` : le decor de fond arrete-t-il les tirs ?
        INCLUDE "src/common/state/variables.asm"
        ; SONDE : le bloc de temoins, pour observer le manager sans monter sa page.
        INCLUDE "src/common/bench.const.asm"
        ; Les identifiants d'objets sont des CONSTANTES : le manager pose le
        ; sien dans l'OST qu'il alloue pour lui-meme.
        INCLUDE "src/stages/01/objid.const.asm"

        INCLUDE "src/enemies/_shared/bullets/mgr.asm"
        INCLUDE "src/enemies/_shared/bullets/create.asm"

 ENDSECTION
