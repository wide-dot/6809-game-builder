;*******************************************************************************
; dobkeratops — le boss du stage 1, porte de la v1
;
; Le plus gros objet du jeu : le corps, ses cinq etats de nerfs, ses trois
; yeux et surtout CINQUANTE-CINQ effaceurs — le boss est trop large pour que
; le moteur restaure son fond par sprite, il se nettoie par bandes.
;
; Ses images vivent dans un pageset a elles ; l'unite garde le code et
; l'INDEX, qui doit rester dans la page que Img_Page_Index monte.
;
; L'entree doit etre le premier octet de l'unite : le code d'abord, les
; tables ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************
dobkeratops.Object   EXPORT

        INCLUDE "src/common/engine/api.asm"

; L'index d'objets du stage charge : le corps y lit ce qu'il fait naitre.
Obj_Index_Page    EXTERNAL
Obj_Index_Address EXTERNAL

; Le boss est un CORPS qui glisse d'un bloc : l'etat qui accorde ses six objets
; est resident dans le stage, qui l'EXPORTe. Ces references traversent donc le
; lien — l'objet, lui, est pagine dans l'arene du niveau.
main.followDobkeratops        EXTERNAL
main.dobkeratops.allEyesDead  EXTERNAL
main.timestamp.moveAlienStart EXTERNAL
main.dobkeratops.move.left    EXTERNAL
main.dobkeratops.halfDamage   EXTERNAL
main.dobkeratops.nervesErasing EXTERNAL

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
        ; La chronologie du boss, partagee avec le stage.
        INCLUDE "src/stages/01/timestamps.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"
        ; Les pas de deplacement en 8.8, constantes de jeu partagees.
        INCLUDE "src/common/lib/scale.asm"

; V2-DEVIATION : entrees d'imageset en set_<nom>, le nom que gfxcomp genere.
Img_dobkeratops_alien            equ set_dobkeratops_alien
Img_dobkeratops_alienN0          equ set_dobkeratops_alienN0
Img_dobkeratops_alienN1          equ set_dobkeratops_alienN1
Img_dobkeratops_alienN2          equ set_dobkeratops_alienN2
Img_dobkeratops_alienN3          equ set_dobkeratops_alienN3
Img_dobkeratops_alienN4          equ set_dobkeratops_alienN4
Img_dobkeratops_eye100           equ set_dobkeratops_eye100
Img_dobkeratops_eye101           equ set_dobkeratops_eye101
Img_dobkeratops_eye102           equ set_dobkeratops_eye102
Img_dobkeratops_eye103           equ set_dobkeratops_eye103
Img_dobkeratops_eye104           equ set_dobkeratops_eye104
Img_dobkeratops_eye300           equ set_dobkeratops_eye300
Img_dobkeratops_eye301           equ set_dobkeratops_eye301
Img_dobkeratops_eye310           equ set_dobkeratops_eye310
Img_dobkeratops_eye311           equ set_dobkeratops_eye311
Img_dobkeratops_eye312           equ set_dobkeratops_eye312
Img_dobkeratops_eye313           equ set_dobkeratops_eye313
Img_dobkeratops_eye320           equ set_dobkeratops_eye320
Img_dobkeratops_eye321           equ set_dobkeratops_eye321
Img_dobkeratops_eye322           equ set_dobkeratops_eye322

; Les effaceurs : le boss se nettoie par bandes.
Img_dobkeratops_erase0_0         equ set_dobkeratops_erase0_0
Img_dobkeratops_erase0_1         equ set_dobkeratops_erase0_1
Img_dobkeratops_erase0_2         equ set_dobkeratops_erase0_2
Img_dobkeratops_erase0_3         equ set_dobkeratops_erase0_3
Img_dobkeratops_erase0_4         equ set_dobkeratops_erase0_4
Img_dobkeratops_erase0_5         equ set_dobkeratops_erase0_5
Img_dobkeratops_erase0_6         equ set_dobkeratops_erase0_6
Img_dobkeratops_erase0_7         equ set_dobkeratops_erase0_7
Img_dobkeratops_erase0_8         equ set_dobkeratops_erase0_8
Img_dobkeratops_erase0_9         equ set_dobkeratops_erase0_9
Img_dobkeratops_erase0_10        equ set_dobkeratops_erase0_10
Img_dobkeratops_erase0_11        equ set_dobkeratops_erase0_11
Img_dobkeratops_erase0_12        equ set_dobkeratops_erase0_12
Img_dobkeratops_erase0_13        equ set_dobkeratops_erase0_13
Img_dobkeratops_erase0_14        equ set_dobkeratops_erase0_14
Img_dobkeratops_erase0_15        equ set_dobkeratops_erase0_15
Img_dobkeratops_erase1_2         equ set_dobkeratops_erase1_2
Img_dobkeratops_erase1_3         equ set_dobkeratops_erase1_3
Img_dobkeratops_erase1_4         equ set_dobkeratops_erase1_4
Img_dobkeratops_erase1_5         equ set_dobkeratops_erase1_5
Img_dobkeratops_erase1_6         equ set_dobkeratops_erase1_6
Img_dobkeratops_erase1_10        equ set_dobkeratops_erase1_10
Img_dobkeratops_erase1_11        equ set_dobkeratops_erase1_11
Img_dobkeratops_erase2_0         equ set_dobkeratops_erase2_0
Img_dobkeratops_erase2_1         equ set_dobkeratops_erase2_1
Img_dobkeratops_erase2_2         equ set_dobkeratops_erase2_2
Img_dobkeratops_erase2_3         equ set_dobkeratops_erase2_3
Img_dobkeratops_erase2_4         equ set_dobkeratops_erase2_4
Img_dobkeratops_erase2_5         equ set_dobkeratops_erase2_5
Img_dobkeratops_erase2_6         equ set_dobkeratops_erase2_6
Img_dobkeratops_erase2_7         equ set_dobkeratops_erase2_7
Img_dobkeratops_erase2_8         equ set_dobkeratops_erase2_8
Img_dobkeratops_erase2_9         equ set_dobkeratops_erase2_9
Img_dobkeratops_erase2_10        equ set_dobkeratops_erase2_10
Img_dobkeratops_erase2_11        equ set_dobkeratops_erase2_11
Img_dobkeratops_erase3_0         equ set_dobkeratops_erase3_0
Img_dobkeratops_erase3_1         equ set_dobkeratops_erase3_1
Img_dobkeratops_erase3_2         equ set_dobkeratops_erase3_2
Img_dobkeratops_erase3_3         equ set_dobkeratops_erase3_3
Img_dobkeratops_erase3_4         equ set_dobkeratops_erase3_4
Img_dobkeratops_erase3_5         equ set_dobkeratops_erase3_5
Img_dobkeratops_erase3_6         equ set_dobkeratops_erase3_6
Img_dobkeratops_erase3_7         equ set_dobkeratops_erase3_7
Img_dobkeratops_erase3_8         equ set_dobkeratops_erase3_8
Img_dobkeratops_erase3_9         equ set_dobkeratops_erase3_9

; V2-DEVIATION : l'entree v1 s'appelle `Object`, un nom trop generique pour la
; frontiere de lien.
dobkeratops.Object
        INCLUDE "src/enemies/dobkeratops/obj.asm"

 ENDSECTION
