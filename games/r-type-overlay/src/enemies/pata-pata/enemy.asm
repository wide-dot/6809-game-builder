;*******************************************************************************
; Pata-pata — le premier ennemi porté
;
; Le code v1 est repris tel quel ; deux écarts seulement, marqués ci-dessous.
; L'unité est paginée : RunObjects lit sa page dans l'index d'objets du stage,
; la monte, puis saute à `Object`. Ses images vivent dans le même direntry,
; donc l'index d'imageset les atteint par la page de celui-ci.
;
; L'entrée doit être le premier octet de l'unité : le code d'abord, les tables
; ensuite — d'où l'ordre des includes.
;*******************************************************************************

patapata.Object   EXPORT

; ce que l'ennemi appelle chez le moteur résident
        INCLUDE "src/common/engine/api.asm"

; L'index d'objets du stage chargé : le macro `_loadFirePreset` y lit la page
; et l'adresse de la sous-routine avant de la faire monter. C'est la voie 3 de
; la frontière, dans le sens moteur→stage, empruntée ici par un ennemi — le
; re-link de `scene.load` la repointe à chaque échange, comme pour le moteur.
Obj_Index_Page    EXTERNAL
Obj_Index_Address EXTERNAL


 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/map.const.asm"
        ; Les identifiants d'objets sont des CONSTANTES, pas des externes :
        ; le code les combine par décalage (_ldd id,subtype), ce qu'aucune
        ; relocation ne sait faire. La v1 les générait de même, par game mode.
        ; Coût : cette unité est liée à la numérotation du stage 1.
        INCLUDE "src/stages/01/objid.const.asm"

        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/animation/index.equ"
        INCLUDE "src/common/lib/projectile.macro.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"

patapata.Object
        INCLUDE "src/enemies/pata-pata/obj.asm"

 ENDSECTION
