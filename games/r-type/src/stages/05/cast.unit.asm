;*******************************************************************************
; Le cast du stage 5 en UN direntry (group multi-membres)
;
; Meme raison qu'au stage 2 : le repertoire du disque reside dans le pool du
; loader et une entree par ennemi est un luxe. Un group = un direntry
; multi-asm, exports fusionnes, un seul id de fichier ; chaque ennemi garde
; SON fichier source dans src/enemies/.
;
; TOUS les obj.asm sont assembles ICI : une etiquette sans prefixe (`Init`,
; `Routines`, `Live`…) serait prise par le premier ennemi implemente et
; interdite au suivant. Chaque implementation prefixe ses etiquettes de son
; nom — voir slither/obj.asm.
;
; Le cast du stage : slither, pursuer, cheetah lui sont EXCLUSIFS ; mid et
; cancer sont partages avec d'autres stages (ils vivent dans leur propre lot
; et se convertissent sur les douze communs) ; bellmite est le boss.
; Seul le slither est implemente — le reste tombe sur le bouchon commun.
;*******************************************************************************

slither.Object   EXPORT
slither.Segment  EXPORT
slither.Render   EXPORT
slither.Corpse   EXPORT

        INCLUDE "src/common/engine/api.asm"

; L'index d'objets du stage charge : LoadObject y lit page et adresse de ce
; que le cast fait naitre (la tete du serpent, le renderer, les explosions).
Obj_Index_Page    EXTERNAL
Obj_Index_Address EXTERNAL
; Le renderer groupe y inscrit SA page, pour que BuildSprites la monte avant
; d'appeler sa routine de dessin.
Img_Page_Index    EXTERNAL

; Les seize poses de la TETE et celles de la QUEUE vivent dans leurs propres
; direntries (stage5.cast.imgHead, stage5.cast.imgTail) : la tete parce
; qu'elle fait 36x54 en TO8, la queue parce que corps et queue ne tenaient
; pas ensemble sur la page du cast. Trente-deux references de lien, resolues
; au chargement (cf. symbols.md).
set_slither_bodyhit_0  EXTERNAL
set_slither_bodyhit_1  EXTERNAL
set_slither_bodyhit_2  EXTERNAL
set_slither_bodyhit_3  EXTERNAL
set_slither_bodyhit_4  EXTERNAL
set_slither_bodyhit_5  EXTERNAL
set_slither_bodyhit_6  EXTERNAL
set_slither_bodyhit_7  EXTERNAL
set_slither_bodyhit_8  EXTERNAL
set_slither_bodyhit_9  EXTERNAL
set_slither_bodyhit_10 EXTERNAL
set_slither_bodyhit_11 EXTERNAL
set_slither_bodyhit_12 EXTERNAL
set_slither_bodyhit_13 EXTERNAL
set_slither_bodyhit_14 EXTERNAL
set_slither_bodyhit_15 EXTERNAL
set_slither_tailhit_0  EXTERNAL
set_slither_tailhit_1  EXTERNAL
set_slither_tailhit_2  EXTERNAL
set_slither_tailhit_3  EXTERNAL
set_slither_tailhit_4  EXTERNAL
set_slither_tailhit_5  EXTERNAL
set_slither_tailhit_6  EXTERNAL
set_slither_tailhit_7  EXTERNAL
set_slither_tailhit_8  EXTERNAL
set_slither_tailhit_9  EXTERNAL
set_slither_tailhit_10 EXTERNAL
set_slither_tailhit_11 EXTERNAL
set_slither_tailhit_12 EXTERNAL
set_slither_tailhit_13 EXTERNAL
set_slither_tailhit_14 EXTERNAL
set_slither_tailhit_15 EXTERNAL
set_slither_headhit_0  EXTERNAL
set_slither_headhit_1  EXTERNAL
set_slither_headhit_2  EXTERNAL
set_slither_headhit_3  EXTERNAL
set_slither_headhit_4  EXTERNAL
set_slither_headhit_5  EXTERNAL
set_slither_headhit_6  EXTERNAL
set_slither_headhit_7  EXTERNAL
set_slither_headhit_8  EXTERNAL
set_slither_headhit_9  EXTERNAL
set_slither_headhit_10 EXTERNAL
set_slither_headhit_11 EXTERNAL
set_slither_headhit_12 EXTERNAL
set_slither_headhit_13 EXTERNAL
set_slither_headhit_14 EXTERNAL
set_slither_headhit_15 EXTERNAL
set_slither_head_0  EXTERNAL
set_slither_head_1  EXTERNAL
set_slither_head_2  EXTERNAL
set_slither_head_3  EXTERNAL
set_slither_head_4  EXTERNAL
set_slither_head_5  EXTERNAL
set_slither_head_6  EXTERNAL
set_slither_head_7  EXTERNAL
set_slither_head_8  EXTERNAL
set_slither_head_9  EXTERNAL
set_slither_head_10 EXTERNAL
set_slither_head_11 EXTERNAL
set_slither_head_12 EXTERNAL
set_slither_head_13 EXTERNAL
set_slither_head_14 EXTERNAL
set_slither_head_15 EXTERNAL
set_slither_tail_0  EXTERNAL
set_slither_tail_1  EXTERNAL
set_slither_tail_2  EXTERNAL
set_slither_tail_3  EXTERNAL
set_slither_tail_4  EXTERNAL
set_slither_tail_5  EXTERNAL
set_slither_tail_6  EXTERNAL
set_slither_tail_7  EXTERNAL
set_slither_tail_8  EXTERNAL
set_slither_tail_9  EXTERNAL
set_slither_tail_10 EXTERNAL
set_slither_tail_11 EXTERNAL
set_slither_tail_12 EXTERNAL
set_slither_tail_13 EXTERNAL
set_slither_tail_14 EXTERNAL
set_slither_tail_15 EXTERNAL

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
        INCLUDE "src/stages/05/objid.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"
        INCLUDE "src/common/lib/scale.asm"
        INCLUDE "src/common/fx/animation/index.equ"
        INCLUDE "src/common/bench.const.asm"

stage5.cast.stub
        ldd   bench.spawns              ; temoin du banc : ce spawn a eu lieu,
        addd  #1                        ; atteint par l'index du stage charge
        std   bench.spawns
        lda   bench.stage
        sta   bench.spawnStage
        jsr   UnloadObject_u            ; implementation vide : rendre le slot
        rts

        INCLUDE "src/enemies/slither/obj.asm"

; Pas de scripts de mouvement ici : ils vivent dans le pool commun
; (src/common/fx/animation/), que moveByScript epingle pour tout le stage.

; Le preset XY commun, partage avec le bug et les autres : l'entree vient du
; quartet bas du descripteur.
PresetXYIndex
        INCLUDE "src/common/lib/presets/18dd0_preset-xy.asm"

 ENDSECTION
