;*******************************************************************************
; Le tir simple du force pod — l'arme sans cristal
;
; C'est l'objet v1 `objects/player1/forcepods/obj_simplefire.asm`. Le trait que
; le force pod lâche tant qu'aucun cristal n'a été ramassé : une direction
; parmi cinq, et l'éclat d'impact du tir du joueur en fin de course.
;
; Unité séparée — cf. l'en-tête de `forcepod.unit.asm`.
;
; L'entrée doit être le premier octet de l'unité.
; Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

simplefire.Object EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "src/common/lib/object.const.asm"
        ; Les variables inter-main : le tir lit backgroundSolid.
        INCLUDE "src/common/state/variables.asm"


; V2-DEVIATION : la v1 nomme ses entrées d'imageset `Img_<nom>`, gfxcomp les
; génère en `set_<nom>`. Une table de liaison laisse le fichier v1 au 1:1.
;
; Les deux éclats d'impact sont les MÊMES PNG que ceux de l'unité `weapon`, et
; ils sont recompilés ici plutôt que partagés : les images d'un objet doivent
; tenir dans SA page, celle que `CheckSpritesRefresh` monte d'après
; `Img_Page_Index[id]`. Un symbole unique par copie — la v1, qui n'a pas de
; table de symboles inter-fichiers, les déclare deux fois sous le même nom.
Img_shootup                      equ set_shootup
Img_shootupright                 equ set_shootupright
Img_shootright                   equ set_shootright
Img_shootdownright               equ set_shootdownright
Img_shootdown                    equ set_shootdown
Img_weapon_impact0               equ set_simplefire_impact0
Img_weapon_impact3               equ set_simplefire_impact3

; V2-DEVIATION : l'entrée v1 s'appelle `Object`, un nom trop générique pour la
; frontière de lien — même écart que l'éclair d'émission et loadFirePreset.
simplefire.Object
        INCLUDE "src/common/weapons/forcepods/obj_simplefire.asm"

 ENDSECTION
