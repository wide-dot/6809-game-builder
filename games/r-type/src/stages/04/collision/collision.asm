;*******************************************************************************
; La collision terrain du stage 4 — unite paginee, gabarit du stage 1
;
; La moitie RESIDENTE (terrainCollision.main + init.do) est au moteur ; cette
; unite est la moitie MONTEE : le code de consultation, ses tables
; dimensionnees par lvlMapWidth, et les cartes du niveau — un seul plan servi deux fois, comme la v1
; (vérité : le terrain.asm v1 du stage, dans src/stages/04/terrain/).
;
; L'entree est le PREMIER octet : quatre jmp en tete du moteur inclus, que
; terrainCollision.init.do adresse par l'index d'objets a +0/+3/+6/+9.
;*******************************************************************************

terrainCollision.unit EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/system/to8/map.const.asm"

lvlMapWidth equ 48 ; stage 04 width (terrain.asm v1)
; La borne d'impact, en px : la largeur de la carte de CE stage.
map_width   equ 96*12

terrainCollision.unit
        INCLUDE "engine/objects/collision/terrainCollision.asm"

terrainCollision.maps
        fdb   collisionMapBackground
        fdb   collisionMapForeground

; La v1 pointe le MEME bin pour les deux plans de ce stage — le
; level4_bc.bin du dossier terrain est un orphelin qu'elle ne
; consomme jamais (son pas de ligne ne correspond d'ailleurs pas).
collisionMapBackground
collisionMapForeground
        INCLUDEBIN "src/stages/04/terrain/level4_fc.bin"

 ENDSECTION
