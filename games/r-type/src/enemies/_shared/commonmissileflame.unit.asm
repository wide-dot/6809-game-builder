;*******************************************************************************
; commonmissileflame — la flamme du missile, portée de la v1
;
; Le missile la fait naître par LoadObject et garde son OST : elle le suit,
; puis se supprime quand il disparaît. Comme lui, elle sert les trois clients
; (tabrok, p-staff, joueur) — c'est le même objet pour tous.
;
; L'entrée doit être le premier octet de l'unité : le code d'abord, les tables
; ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

commonmissileflame.Object   EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "src/stages/01/objid.const.asm"
        INCLUDE "src/common/state/variables.asm"

; V2-DEVIATION : entrées d'imageset en set_<nom>, le nom que gfxcomp génère.
; Les properties v1 : quatre poses, les quatre PNG de boost.
Img_missileflame_0           equ set_missileflame_0
Img_missileflame_1           equ set_missileflame_1
Img_missileflame_2           equ set_missileflame_2
Img_missileflame_3           equ set_missileflame_3

; V2-DEVIATION : l'entrée v1 s'appelle `Object`, un nom trop générique pour la
; frontière de lien.
commonmissileflame.Object
        INCLUDE "src/enemies/_shared/commonmissileflame.asm"

 ENDSECTION
