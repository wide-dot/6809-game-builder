;*******************************************************************************
; dobkeratops_monster — la creature du boss, portee de la v1
;
; Elle crache les scies et meurt en explosions. Son tirage aleatoire passe par
; RandomNumber, de l'interface moteur — voir la V2-DEVIATION dans le source.
;
; L'entree doit etre le premier octet de l'unite : le code d'abord, les
; tables ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************
dobkeratopsMonster.Object   EXPORT

        INCLUDE "src/common/engine/api.asm"

; L'index d'objets du stage charge : le monstre y lit les scies et les explosions qu'il fait naitre.
Obj_Index_Page    EXTERNAL
Obj_Index_Address EXTERNAL

; Le boss est un CORPS qui glisse d'un bloc : l'etat qui accorde ses six objets
; est resident dans le stage, qui l'EXPORTe. Ces references traversent donc le
; lien — l'objet, lui, est pagine dans l'arene du niveau.
main.followDobkeratops        EXTERNAL
main.timestamp.moveAlienStart EXTERNAL
main.dobkeratops.move.left    EXTERNAL
main.dobkeratops.halfDamage   EXTERNAL
main.dobkeratops.nervesErasing EXTERNAL
main.dobkeratops.explode      EXTERNAL

; V2-DEVIATION : la palette du jeu s'appelle Pal_stage en v2 (png2pal du
; stage) ; la v1 la nomme Pal_game. Elle est residente, le monstre la lit
; par le lien.
Pal_stage                      EXTERNAL
Pal_game equ Pal_stage

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

; V2-DEVIATION : entrees d'imageset en set_<nom>.
Img_dobkeratops_monster_1        equ set_dobkeratops_monster_1
Img_dobkeratops_monster_2        equ set_dobkeratops_monster_2
Img_dobkeratops_monster_3        equ set_dobkeratops_monster_3
Img_dobkeratops_monster_4        equ set_dobkeratops_monster_4
Img_dobkeratops_monster_5        equ set_dobkeratops_monster_5
Img_dobkeratops_monster_6        equ set_dobkeratops_monster_6

; V2-DEVIATION : l'entree v1 s'appelle `Object`, un nom trop generique pour la
; frontiere de lien.
dobkeratopsMonster.Object
        INCLUDE "src/enemies/dobkeratops/monster.asm"

 ENDSECTION
