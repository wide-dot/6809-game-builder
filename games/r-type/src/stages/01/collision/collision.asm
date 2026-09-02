;*******************************************************************************
; La collision terrain du stage 1 — unite paginee, portee de objects/collision/01
;
; La moitie RESIDENTE (terrainCollision.main + init.do) est au moteur ; cette
; unite est la moitie MONTEE : le code de consultation, ses tables precalculees
; dimensionnees par lvlMapWidth, et les deux cartes du niveau (fond et decor,
; 66 tuiles de 24 px — la meme largeur que notre carte graphique, 132 x 12 px).
;
; L'entree est le PREMIER octet : quatre jmp en tete du moteur inclus, que
; terrainCollision.init.do adresse par l'index d'objets a +0/+3/+6/+9. Le code
; d'abord, les tables et les cartes ensuite.
;*******************************************************************************

terrainCollision.unit EXPORT
; La carte d'avant-plan et les tables de collision des nerfs : le trampoline
; resident d'eyemgr-res les atteint par le lien (page + adresse).
stage1.collisionMap     EXPORT
terrainCollision.nerves EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/system/to8/map.const.asm"

lvlMapWidth equ 66 ; stage 01 width
; La borne d'impact du moteur de collision, en px : la v1 la posait dans son
; game mode (1584 = 132 colonnes x 12 px, le niveau entier). Equate
; d'assemblage, locale a l'unite — le map_width du resident est un defaut que
; le stage ecrase deja pour scroll_max.
map_width   equ 132*12

terrainCollision.unit
        INCLUDE "engine/objects/collision/terrainCollision.asm"

terrainCollision.maps
        fdb   collisionMapBackground
        fdb   collisionMapForeground

collisionMapBackground
        INCLUDEBIN "src/stages/01/collision/level1_bc.bin"

collisionMapForeground
stage1.collisionMap                ; le meme octet, sous un nom PROPRE au stage : le
                                   ; nom generique est aussi exporte par le stage 4
        INCLUDEBIN "src/stages/01/collision/level1_fc.bin"
; Les octets de la carte d'avant-plan que chaque nerf optique occupe, avec le
; masque de ses bits (tools/gen_nerve_collision.py, d'apres les tables
; d'effacement de l'arcade). Sur la meme page que la carte : le trampoline
; monte une page et fait tout. Analyse : doc/analyse-collision-nerfs.md
        INCLUDE "src/stages/01/collision/nerve-collision.tables.asm"

 ENDSECTION
