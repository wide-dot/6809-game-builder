;*******************************************************************************
; sawmgr — la scie du Dobkeratops, en manager (02/09/2026)
;
; Un seul objet pour toute la chaine : il integre la tete, range sa
; trajectoire dans un anneau et en deduit chaque maillon ; il dessine seul
; via le faux imageset et balaie lui-meme les listes de collision. Remplace
; l'objet v1 dobkeratops_saw (un OST par scie), dont il garde l'identifiant
; ObjID_dobkeratops_saw, les images et l'arithmetique. Conception :
; doc/analyse-saw-manager.md.
;
; Il ECRIT sa propre page dans Img_Page_Index du stage : ses images vivent
; chez lui, et c'est cette table que le moteur consulte avant de dessiner.
;
; L'entree doit etre le premier octet de l'unite : le code d'abord, les
; tables ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************
sawmgr.Object   EXPORT
        INCLUDE "src/common/engine/api.asm"
Img_Page_Index    EXTERNAL
; La boite aux lettres du monstre : residente (stage1.sawmgr.res), parce que
; le monstre et le manager n'ont pas la meme page.
main.sawmgr.spawn EXTERNAL
main.sawmgr.x     EXTERNAL
main.sawmgr.y     EXTERNAL
 SECTION code
        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "src/stages/01/objid.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/state/variables.asm"
sawmgr.Object
        INCLUDE "src/enemies/dobkeratops/sawmgr.asm"
 ENDSECTION
