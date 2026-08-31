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
main.timestamp.moveAlienStart EXTERNAL
main.dobkeratops.move.left    EXTERNAL
; le compte des nerfs vivants, tenu par eyemgr (chantier nerfs-overlay)
main.eyemgr.eyesAlive         EXTERNAL
main.dobkeratops.explode      EXTERNAL

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
Img_dobkeratops_band0            equ set_dobkeratops_band0
Img_dobkeratops_band1            equ set_dobkeratops_band1
Img_dobkeratops_band2            equ set_dobkeratops_band2
Img_dobkeratops_band3            equ set_dobkeratops_band3

; V2-DEVIATION : l'entree v1 s'appelle `Object`, un nom trop generique pour la
; frontiere de lien.
dobkeratops.Object
        INCLUDE "src/enemies/dobkeratops/obj.asm"

 ENDSECTION
