;*******************************************************************************
; tabrokcanon — le canon que le tabrok fait naître, porté de la v1 (stage 1)
;
; La v1 le range dans la famille foefire (objects/foefire/obj_tabrokcanon.asm) :
; un objet à part entière, avec son identifiant, que le tabrok crée par
; LoadObject. Il a son unité parce que ses étiquettes internes (Object, Init,
; Routines) sont celles de tous les objets v1 — infusionnables.
;
; L'entrée doit être le premier octet de l'unité : le code d'abord, les tables
; ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

tabrokcanon.Object   EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/map.const.asm"
        ; Les identifiants d'objets sont des CONSTANTES, pas des externes : le
        ; code les combine par décalage, ce qu'aucune relocation ne sait faire.
        INCLUDE "src/stages/01/objid.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"

; V2-DEVIATION : entrées d'imageset en set_<nom>, le nom que gfxcomp génère.
; Les properties v1 : une seule image, déclarée deux fois — telle quelle et en
; miroir X, le canon tirant vers la gauche ou vers la droite.
Img_tabrokcanon_left         equ set_tabrokcanon_left
Img_tabrokcanon_right        equ set_tabrokcanon_right

; V2-DEVIATION : l'entrée v1 s'appelle `Object`, un nom trop générique pour la
; frontière de lien.
tabrokcanon.Object
        INCLUDE "src/enemies/tabrok/canon.asm"

 ENDSECTION
