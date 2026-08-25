;*******************************************************************************
; Le laser anti-aérien — l'arme du cristal jaune
;
; C'est l'objet v1 `objects/player1/forcepods/obj_counterairlaser.asm`. Deux
; traits partent du force pod, l'un vers le haut, l'autre vers le bas, et se
; propagent le long du décor.
;
; Unité séparée — cf. l'en-tête de `forcepod.unit.asm`.
; C'est du COMMUN : les sept game modes de la v1 le déclarent.
;
; L'entrée doit être le premier octet de l'unité.
; Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

counterairlaser.Object EXPORT

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
        INCLUDE "src/stages/01/objid.const.asm"
        INCLUDE "src/common/state/variables.asm"   ; stage.gum.hook

; V2-DEVIATION : la v1 nomme ses entrées d'imageset `Img_<nom>`, gfxcomp les
; génère en `set_<nom>`. Une table de liaison laisse le fichier v1 au 1:1.
Img_counterairlaser_0            equ set_counterairlaser_0
Img_counterairlaser_1            equ set_counterairlaser_1
Img_counterairlaser_2            equ set_counterairlaser_2
Img_counterairlaser_3            equ set_counterairlaser_3
Img_counterairlaser_4            equ set_counterairlaser_4
Img_counterairlaser_5            equ set_counterairlaser_5
Img_counterairlaser_6            equ set_counterairlaser_6
Img_counterairlaser_7            equ set_counterairlaser_7

; V2-DEVIATION : l'entrée v1 s'appelle `Object`, un nom trop générique pour la
; frontière de lien — même écart que l'éclair d'émission et loadFirePreset.
counterairlaser.Object
        INCLUDE "src/common/weapons/forcepods/obj_counterairlaser.asm"

 ENDSECTION
