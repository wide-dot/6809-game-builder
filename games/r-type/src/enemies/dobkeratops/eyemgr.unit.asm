;*******************************************************************************
; eyemgr — le manager des nerfs optiques du dobkeratops (chantier overlay)
;
; Un seul objet pour les quatre systemes d'oeil : bandes de l'etat intact,
; sequences d'effacement, boites de collision (table residente du stage).
; Ses images de bandes vivent CHEZ LUI (gfxcomp du config, table adr_*
; locale, pas d'index) ; il ecrit sa propre page dans Img_Page_Index, comme
; tailmgr. Les morceaux d'effacement vivent dans l'unite eyepieces, atteinte
; par le trampoline resident main.eyemgr.drawPieces.
;
; L'entree doit etre le premier octet de l'unite : le code d'abord, les
; tables et les images ensuite. Cf. docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************
eyemgr.Object   EXPORT

        INCLUDE "src/common/engine/api.asm"

Obj_Index_Page    EXTERNAL
Obj_Index_Address EXTERNAL
Img_Page_Index    EXTERNAL

; L'etat qui accorde le boss est resident dans le stage, qui l'EXPORTe.
main.dobkeratops.allEyesDead   EXTERNAL
main.dobkeratops.halfDamage    EXTERNAL
main.dobkeratops.nervesErasing EXTERNAL
main.eyemgr.status             EXTERNAL
main.eyemgr.removed            EXTERNAL
main.eyemgr.aabb               EXTERNAL
main.eyemgr.eyesAlive          EXTERNAL
main.eyemgr.drawPieces         EXTERNAL
; le hook de la parite impaire, dans sa propre unite
eyemgrD1.Draw                  EXTERNAL
eyemgrD1.Draw$PAGE             EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/map.const.asm"
        ; Les identifiants d'objets sont des CONSTANTES, pas des externes.
        INCLUDE "src/stages/01/objid.const.asm"
        ; La chronologie du boss, partagee avec le stage.
        INCLUDE "src/stages/01/timestamps.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"

eyemgr.Object
        INCLUDE "src/enemies/dobkeratops/eyemgr.asm"

 ENDSECTION
