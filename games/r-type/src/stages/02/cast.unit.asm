;*******************************************************************************
; Le cast du stage 2 en UN direntry (group multi-membres)
;
; Le repertoire du disque est la denree rare : il reside dans le pool du
; loader (4060 octets), et son passage de 10 a 11 secteurs a creve le pool
; au premier echange de scene — cinq entrees de repertoire pour cinq
; squelettes etaient un luxe. Un group = un direntry multi-asm (exports
; fusionnes, un seul id de fichier) ; chaque ennemi garde SON fichier
; source dans src/enemies/, pret a grandir.
;
; L'entree de chaque objet est son export ; le bouchon commun compte le
; spawn dans les temoins du banc puis rend le slot — une implementation
; vide ne bloque jamais le pool d'objets.
;
; TOUS les obj.asm sont assembles ICI, dans la meme unite : une etiquette
; sans prefixe (`Init`, `Routines`, `Live`...) serait prise par le premier
; ennemi implemente et interdite au suivant. Chaque implementation prefixe
; ses etiquettes de son nom — voir outslay/obj.asm.
;*******************************************************************************

; Les sprites du GOUGER franchissent la frontiere de direntry : chaque
; direction a sa page — et chaque MOITIE la sienne, les poses etant coupees
; en deux (46 demi-sprites, plus de deux pages, et Img_Page_Index ne donne
; qu'une page par identifiant). Ces symboles sont resolus au chargement.
set_gouger_tl_top_0  EXTERNAL
set_gouger_tl_top_1  EXTERNAL
set_gouger_tl_top_2  EXTERNAL
set_gouger_tl_top_3  EXTERNAL
set_gouger_tl_top_idle_0  EXTERNAL
set_gouger_tr_top_0  EXTERNAL
set_gouger_tr_top_1  EXTERNAL
set_gouger_tr_top_2  EXTERNAL
set_gouger_tr_top_3  EXTERNAL
set_gouger_tr_top_idle_0  EXTERNAL
set_gouger_bl_top_0  EXTERNAL
set_gouger_bl_top_1  EXTERNAL
set_gouger_bl_top_2  EXTERNAL
set_gouger_bl_top_3  EXTERNAL
set_gouger_bl_top_idle_0  EXTERNAL
set_gouger_br_top_0  EXTERNAL
set_gouger_br_top_1  EXTERNAL
set_gouger_br_top_2  EXTERNAL
set_gouger_br_top_idle_0  EXTERNAL
set_gouger_hit_tl_top_0  EXTERNAL
set_gouger_hit_tr_top_0  EXTERNAL
set_gouger_hit_bl_top_0  EXTERNAL
set_gouger_hit_br_top_0  EXTERNAL
set_gouger_tl_bottom_0  EXTERNAL
set_gouger_tl_bottom_1  EXTERNAL
set_gouger_tl_bottom_2  EXTERNAL
set_gouger_tl_bottom_3  EXTERNAL
set_gouger_tl_bottom_idle_0  EXTERNAL
set_gouger_tr_bottom_0  EXTERNAL
set_gouger_tr_bottom_1  EXTERNAL
set_gouger_tr_bottom_2  EXTERNAL
set_gouger_tr_bottom_3  EXTERNAL
set_gouger_tr_bottom_idle_0  EXTERNAL
set_gouger_bl_bottom_0  EXTERNAL
set_gouger_bl_bottom_1  EXTERNAL
set_gouger_bl_bottom_2  EXTERNAL
set_gouger_bl_bottom_3  EXTERNAL
set_gouger_bl_bottom_idle_0  EXTERNAL
set_gouger_br_bottom_0  EXTERNAL
set_gouger_br_bottom_1  EXTERNAL
set_gouger_br_bottom_2  EXTERNAL
set_gouger_br_bottom_idle_0  EXTERNAL
set_gouger_hit_tl_bottom_0  EXTERNAL
set_gouger_hit_tr_bottom_0  EXTERNAL
set_gouger_hit_bl_bottom_0  EXTERNAL
set_gouger_hit_br_bottom_0  EXTERNAL
set_wick_0  EXTERNAL
set_wick_1  EXTERNAL
set_wick_2  EXTERNAL
set_wick_3  EXTERNAL
set_wick_4  EXTERNAL
set_wick_5  EXTERNAL
set_wick_6  EXTERNAL
set_wick_7  EXTERNAL
set_wick_8  EXTERNAL
set_wick_9  EXTERNAL
set_wick_10  EXTERNAL
set_wick_11  EXTERNAL
set_wick_12  EXTERNAL
set_wick_13  EXTERNAL
set_wick_14  EXTERNAL
set_wick_15  EXTERNAL
set_wick_16  EXTERNAL
set_wick_17  EXTERNAL
set_wick_18  EXTERNAL
set_wick_19  EXTERNAL
set_wick_20  EXTERNAL
set_wick_21  EXTERNAL
set_wick_22  EXTERNAL
set_wick_23  EXTERNAL
set_wick_24  EXTERNAL
set_wick_25  EXTERNAL
set_wick_26  EXTERNAL
set_wick_27  EXTERNAL
set_wick_28  EXTERNAL
set_wick_29  EXTERNAL
set_wick_30  EXTERNAL
set_wick_31  EXTERNAL
gouger.Object    EXPORT
gouger.Half      EXPORT
wick.Object      EXPORT
wick.Unit        EXPORT
brood.Object     EXPORT
outslay.Object   EXPORT
outslay.Segment  EXPORT
outslay.Render   EXPORT
outslay.Shot     EXPORT
tilemapanim.Object EXPORT
gomander.Object  EXPORT

        INCLUDE "src/common/engine/api.asm"

; L'index d'objets du stage charge : LoadObject y lit page et adresse de ce
; que le cast fait naitre (segments d'outslay, tirs, explosions).
Obj_Index_Page    EXTERNAL
Obj_Index_Address EXTERNAL
; Le renderer groupe de l'outslay y inscrit SA page, pour que BuildSprites la
; monte avant d'appeler sa routine de dessin (schema du tailmgr).
Img_Page_Index    EXTERNAL

; Les poses de tete/finalizer de l'outslay vivent dans leur propre direntry
; (stage2.cast.imgHead) : 37 sprites 12x24 ne tiennent pas dans les 16 Ko
; d'une seule entree. Seize references de lien, resolues au chargement.
set_outslay_head_0  EXTERNAL
set_outslay_head_1  EXTERNAL
set_outslay_head_2  EXTERNAL
set_outslay_head_3  EXTERNAL
set_outslay_head_4  EXTERNAL
set_outslay_head_5  EXTERNAL
set_outslay_head_6  EXTERNAL
set_outslay_head_7  EXTERNAL
set_outslay_head_8  EXTERNAL
set_outslay_head_9  EXTERNAL
set_outslay_head_10 EXTERNAL
set_outslay_head_11 EXTERNAL
set_outslay_head_12 EXTERNAL
set_outslay_head_13 EXTERNAL
set_outslay_head_14 EXTERNAL
set_outslay_head_15 EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/graphics/tilemap/patch/tilemap-patch.const.asm"
        INCLUDE "gen/stages/02/engulf/engulf.const.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        ; Les identifiants d'objets sont des CONSTANTES, pas des externes : le
        ; code les combine par decalage, ce qu'aucune relocation ne sait faire.
        INCLUDE "src/stages/02/objid.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/fx/soundfx/soundFX.const.asm"
        INCLUDE "engine/sound/soundFX.macro.asm"
        INCLUDE "src/common/state/variables.asm"
        ; Les pas de deplacement en 8.8, constantes de jeu partagees.
        INCLUDE "src/common/lib/scale.asm"
        ; Les index des scripts d'animation communs (offsets dans la LUT que
        ; moveByScript.register a epinglee pour le stage).
        INCLUDE "src/common/fx/animation/index.equ"

        INCLUDE "src/common/bench.const.asm"

stage2.cast.stub
        ldd   bench.spawns              ; temoin du banc : ce spawn a eu lieu,
        addd  #1                        ; atteint par l'index du stage charge
        std   bench.spawns
        lda   bench.stage
        sta   bench.spawnStage
        jsr   UnloadObject_u            ; implementation vide : rendre le slot
        rts

        INCLUDE "src/enemies/gouger/obj.asm"
        INCLUDE "src/enemies/wick/obj.asm"
        INCLUDE "src/enemies/brood/obj.asm"
        INCLUDE "src/enemies/outslay/obj.asm"
        INCLUDE "src/enemies/outslay/shot.asm"
        INCLUDE "src/common/fx/tilemapanim/obj.asm"
        INCLUDE "src/enemies/gomander/obj.asm"

 ENDSECTION
