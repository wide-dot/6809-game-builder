;*******************************************************************************
; Le laser à rebond — l'arme du cristal rouge
;
; C'est l'objet v1 `objects/player1/forcepods/obj_reboundlaser.asm`. Tiré par le
; force pod, le trait rebondit sur le décor et se propage en chaîne : chaque
; segment porte son parent, son identifiant d'enfant et son masque de slot.
;
; Unité séparée — cf. l'en-tête de `forcepod.unit.asm`.
; C'est du COMMUN : les sept game modes de la v1 le déclarent.
;
; L'entrée doit être le premier octet de l'unité.
; Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

reboundlaser.Object EXPORT

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
        ; Les variables inter-main : le laser lit backgroundSolid pour savoir
        ; si le decor de fond arrete les rebonds.
        INCLUDE "src/common/state/variables.asm"
        INCLUDE "src/common/player/player1.equ"
        INCLUDE "src/stages/01/objid.const.asm"

; V2-DEVIATION : la v1 nomme ses entrées d'imageset `Img_<nom>`, gfxcomp les
; génère en `set_<nom>`. Une table de liaison laisse le fichier v1 au 1:1.
Img_reboundlaser_angle_0         equ set_reboundlaser_angle_0
Img_reboundlaser_angle_1         equ set_reboundlaser_angle_1
Img_reboundlaser_angle_2         equ set_reboundlaser_angle_2
Img_reboundlaser_angle_3         equ set_reboundlaser_angle_3
Img_reboundlaser_angle_4         equ set_reboundlaser_angle_4
Img_reboundlaser_angle_5         equ set_reboundlaser_angle_5
Img_reboundlaser_angle_6         equ set_reboundlaser_angle_6
Img_reboundlaser_angle_7         equ set_reboundlaser_angle_7
Img_reboundlaser_diagonal_0      equ set_reboundlaser_diagonal_0
Img_reboundlaser_diagonal_1      equ set_reboundlaser_diagonal_1
Img_reboundlaser_diagonal_2      equ set_reboundlaser_diagonal_2
Img_reboundlaser_diagonal_3      equ set_reboundlaser_diagonal_3
Img_reboundlaser_horizontal      equ set_reboundlaser_horizontal
Img_reboundlaser_explosion_0     equ set_reboundlaser_explosion_0
Img_reboundlaser_explosion_1     equ set_reboundlaser_explosion_1
Img_reboundlaser_explosion_2     equ set_reboundlaser_explosion_2
Img_reboundlaser_explosion_3     equ set_reboundlaser_explosion_3

; V2-DEVIATION : l'entrée v1 s'appelle `Object`, un nom trop générique pour la
; frontière de lien — même écart que l'éclair d'émission et loadFirePreset.
reboundlaser.Object
        INCLUDE "src/common/weapons/forcepods/obj_reboundlaser.asm"

 ENDSECTION
