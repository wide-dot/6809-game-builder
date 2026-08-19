;*******************************************************************************
; scantfire — le tir du scant, porté de la v1 (stage 1)
;
; La v1 le range dans la famille foefire (objects/foefire/obj_scantfire.asm) :
; un projectile à part entière, avec son identifiant, que scant fait naître
; par LoadObject. Ses deux scripts d'animation étaient GÉNÉRÉS par le pipeline
; v1 dans l'objet lui-même (scantfire_Animation.asm) — ils vivent donc ici,
; pas dans l'objet d'animation commun.
;
; L'entrée doit être le premier octet de l'unité : le code d'abord, les
; scripts ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

scantfire.Object   EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/graphics/animation/constants-animation.equ"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"

; V2-DEVIATION : entrées d'imageset en set_<nom>, le nom que gfxcomp génère.
; Les properties v1 : 0/1 = scantfire_*.png tel quel, 2/3 = les mêmes en
; miroir X (le tir part vers la gauche ou vers la droite).
Img_scantfire_0              equ set_scantfire_0
Img_scantfire_1              equ set_scantfire_1
Img_scantfire_2              equ set_scantfire_2
Img_scantfire_3              equ set_scantfire_3

; V2-DEVIATION : l'entrée v1 s'appelle `Object`, un nom trop générique pour la
; frontière de lien.
scantfire.Object
        INCLUDE "src/enemies/scant/fire.asm"

; Les deux scripts, portés du généré v1 (scantfire_Animation.asm) :
;   Ani_scantfire_left  = 3;Img_scantfire_0;Img_scantfire_1;_resetAnim
;   Ani_scantfire_right = 3;Img_scantfire_2;Img_scantfire_3;_resetAnim
; L'octet qui PRÉCÈDE l'étiquette est la durée d'une image.
        fcb   3
Ani_scantfire_left
        fdb   Img_scantfire_0
        fdb   Img_scantfire_1
        fcb   _resetAnim
        fcb   3
Ani_scantfire_right
        fdb   Img_scantfire_2
        fdb   Img_scantfire_3
        fcb   _resetAnim

 ENDSECTION
