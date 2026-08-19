;*******************************************************************************
; Le POW — le bonus que l'escadrille rouge laisse tomber
;
; C'est l'objet v1 `objects/player1/pow/pow.asm`. Il tombe, se pose, marche sur
; le décor, redécolle, et quand un tir le détruit il lâche une explosion ET une
; boîte à option — ou un bit device quand le quartet haut de son subtype vaut 5.
;
; C'est du COMMUN : les sept game modes de la v1 le déclarent, comme le joueur
; et ses armes. Rien ici ne connaît le niveau.
;
; Unité séparée de la boîte à option, alors que les deux tiennent sur une page
; et se font naître l'un l'autre : les deux fichiers v1 nomment leur entrée
; `Object`, leurs tables `Routines`, et posent tous deux `AABB_0 equ
; ext_variables`. Les réunir demanderait de renommer, donc de perdre le 1:1 sur
; l'un des deux. La v1 en fait deux objets ; nous en faisons deux unités.
;
; Les scripts de MOUVEMENT (`anim_19A96`, `anim_19AA2`) sont des INDEX dans le
; banc commun d'animation, pas des adresses : `moveByScript.initialize` les
; ajoute à la base que `moveByScript.register` a posée depuis l'index d'objets.
; Le banc est chargé (région `anim`), il n'y a rien à faire de plus ici.
;
; L'entrée doit être le premier octet de l'unité : le code d'abord, les tables
; ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

pow.Object EXPORT

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
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/fx/animation/index.equ"
        ; Les pas de deplacement en 8.8, communs : la v1 les tient dans son
        ; main (scale.equ), le POW les cite pour sa marche sur le decor.
        INCLUDE "src/common/lib/scale.asm"
        INCLUDE "src/stages/01/objid.const.asm"

; V2-DEVIATION : la v1 nomme ses entrées d'imageset `Img_<nom>`, gfxcomp les
; génère en `set_<nom>`. Une table de liaison laisse le fichier v1 au 1:1 —
; c'est le rôle que jouait son fichier d'imageset généré.
Img_pow_fly equ set_pow_fly
Img_pow_1   equ set_pow_1
Img_pow_2   equ set_pow_2
Img_pow_3   equ set_pow_3
Img_pow_4   equ set_pow_4
Img_pow_5   equ set_pow_5

; V2-DEVIATION : l'entrée v1 s'appelle `Object`, un nom trop générique pour la
; frontière de lien — même écart que l'éclair d'émission et loadFirePreset.
pow.Object
        INCLUDE "src/common/pickups/pow/pow.asm"

 ENDSECTION
