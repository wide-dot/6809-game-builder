;*******************************************************************************
; eyepieces — les morceaux d'effacement des nerfs du dobkeratops
;
; Une unite d'images + une routine : trop volumineux pour tenir avec eyemgr
; dans un meme direntry (16 Ko), les morceaux vivent ici et la routine de
; dessin avec eux (une table adr_* locale ne traverse aucun lien). Atteinte
; par le trampoline resident main.eyemgr.drawPieces — jamais appelee
; directement depuis une autre page.
;
; L'entree doit etre le premier octet de l'unite : le code d'abord, les
; tables et les images ensuite. Cf. docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************
eyepieces.DrawAll   EXPORT

        INCLUDE "src/common/engine/api.asm"

main.eyemgr.status  EXTERNAL
main.eyemgr.removed EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"

        INCLUDE "src/enemies/dobkeratops/eyepieces.asm"

 ENDSECTION
