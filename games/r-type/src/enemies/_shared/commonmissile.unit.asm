;*******************************************************************************
; commonmissile — le missile, porté de la v1
;
; MUTUALISÉ : c'est le même objet pour les missiles du tabrok et du p-staff
; (subtypes 0 et 1) et pour l'arme du joueur (subtype 2, dont le code vit dans
; player_missile.asm et que ce fichier inclut). Un seul identifiant, un seul
; jeu de sprites, trois clients — la v1 le range dans la famille foefire et le
; déclare une fois par game mode.
;
; Elle est paginée : RunObjects lit sa page dans l'index d'objets du stage, la
; monte, puis saute à l'entrée.
;
; L'entrée doit être le premier octet de l'unité : le code d'abord, les tables
; ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

commonmissile.Object   EXPORT

        INCLUDE "src/common/engine/api.asm"

; L'index d'objets du stage chargé : le missile y lit la page et l'adresse de
; la flamme qu'il fait naître.
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
        ; Les identifiants d'objets sont des CONSTANTES, pas des externes : le
        ; code les combine par décalage, ce qu'aucune relocation ne sait faire.
        INCLUDE "src/stages/01/objid.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/fx/soundfx/soundFX.const.asm"
        INCLUDE "engine/sound/soundFX.macro.asm"
        INCLUDE "src/common/state/variables.asm"
        ; Les pas de deplacement en 8.8, constantes de jeu partagees.
        INCLUDE "src/common/lib/scale.asm"

; V2-DEVIATION : la v1 nomme ses entrées d'imageset `Img_<nom>`, gfxcomp les
; génère en `set_<nom>`. Une table de liaison laisse le fichier v1 au 1:1.
; Les properties v1 déclarent SEIZE poses tirées de cinq PNG : le missile
; pointe dans les quatre directions, chaque quadrant étant un miroir de
; l'image de base (Y, XY, X). L'index MissileImagesIndex les enchaîne.
Img_missile_0                equ set_missile_0
Img_missile_1                equ set_missile_1
Img_missile_2                equ set_missile_2
Img_missile_3                equ set_missile_3
Img_missile_4                equ set_missile_4
Img_missile_5                equ set_missile_5
Img_missile_6                equ set_missile_6
Img_missile_7                equ set_missile_7
Img_missile_8                equ set_missile_8
Img_missile_9                equ set_missile_9
Img_missile_10               equ set_missile_10
Img_missile_11               equ set_missile_11
Img_missile_12               equ set_missile_12
Img_missile_13               equ set_missile_13
Img_missile_14               equ set_missile_14
Img_missile_15               equ set_missile_15

; V2-DEVIATION : l'entrée v1 s'appelle `Object`, un nom trop générique pour la
; frontière de lien.
commonmissile.Object
        INCLUDE "src/enemies/_shared/commonmissile.asm"

 ENDSECTION
