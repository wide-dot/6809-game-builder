;*******************************************************************************
; tailmgr — la queue du boss, portee de la v1
;
; Un seul objet pour toute la queue : il porte les blits compiles de chaque
; segment (tailmgr_blits.asm, 1169 lignes) et ses tables d'animation. La v1
; avait d'abord un objet par segment (tail.asm) ; cette version-la est
; abandonnee et n'est pas nommee par le game mode disquette — elle n'est donc
; pas portee.
;
; Il ECRIT sa propre page dans Img_Page_Index du stage : ses blits vivent
; chez lui, et c'est cette table que le moteur consulte avant de dessiner.
;
; L'entree doit etre le premier octet de l'unite : le code d'abord, les
; tables ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************
tailmgr.Object   EXPORT

        INCLUDE "src/common/engine/api.asm"

; L'index d'objets du stage charge, et la table des pages d'images : le
; gestionnaire y inscrit la sienne pour que le moteur trouve ses blits.
Obj_Index_Page    EXTERNAL
Obj_Index_Address EXTERNAL

; Le boss est un CORPS qui glisse d'un bloc : l'etat qui accorde ses six objets
; est resident dans le stage, qui l'EXPORTe. Ces references traversent donc le
; lien — l'objet, lui, est pagine dans l'arene du niveau.
main.dobkeratops.computeStep  EXTERNAL
main.timestamp.moveAlienStart EXTERNAL
main.dobkeratops.move.left    EXTERNAL
main.dobkeratops.move.step    EXTERNAL
main.dobkeratops.explode      EXTERNAL
Img_Page_Index    EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/map.const.asm"
        ; Les identifiants d'objets sont des CONSTANTES, pas des externes : le
        ; code les combine par decalage, ce qu'aucune relocation ne sait faire.
        INCLUDE "src/stages/01/objid.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"
        ; Les pas de deplacement en 8.8, constantes de jeu partagees.
        INCLUDE "src/common/lib/scale.asm"

; V2-DEVIATION : l'entree v1 s'appelle `Object`, un nom trop generique pour la
; frontiere de lien.
tailmgr.Object
        INCLUDE "src/enemies/dobkeratops/tailmgr.asm"

 ENDSECTION
