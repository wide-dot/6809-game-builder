;*******************************************************************************
; Le laser de sol — l'arme du cristal JAUNE (« counter-ground »)
;
; Deux faisceaux partent du Force Pod, l'un vers le haut l'autre vers le bas,
; et RAMPENT le long du decor : c'est un suiveur de mur, l'un tenant la paroi
; de la main droite, l'autre de la gauche. Voir doc/ground-laser-arcade.md.
;
; PAS DE SOURCE V1 : le stage 1 ne donne jamais ce cristal, la v1 ne l'a donc
; jamais porte. Tout vient du releve Ghidra de la borne.
;
; Unite separee — cf. l'en-tete de `forcepod.unit.asm`.
; C'est du COMMUN : l'arme suit le pod, donc les huit stages.
;
; L'entree doit etre le premier octet de l'unite.
; Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

groundlaser.Object EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "src/common/lib/object.const.asm"
        INCLUDE "src/common/player/player1.equ"   ; forcepod_mount_side
        INCLUDE "src/stages/01/objid.const.asm"
        INCLUDE "src/common/state/variables.asm"   ; globals.backgroundSolid

; V2-DEVIATION : gfxcomp genere `set_<nom>` la ou la v1 nommait `Img_<nom>`.
; Meme table de liaison que les autres armes du pod.
Img_groundlaser_0  equ set_groundlaser_0
Img_groundlaser_1  equ set_groundlaser_1
Img_groundlaser_2  equ set_groundlaser_2
Img_groundlaser_3  equ set_groundlaser_3
Img_groundlaser_f0 equ set_groundlaser_f0
Img_groundlaser_f1 equ set_groundlaser_f1
Img_groundlaser_f2 equ set_groundlaser_f2
Img_groundlaser_f3 equ set_groundlaser_f3
Img_groundlaser_x0 equ set_groundlaser_x0
Img_groundlaser_x1 equ set_groundlaser_x1
Img_groundlaser_x2 equ set_groundlaser_x2
Img_groundlaser_x3 equ set_groundlaser_x3

groundlaser.Object
        INCLUDE "src/common/weapons/forcepods/obj_groundlaser.asm"
        INCLUDE "src/common/weapons/forcepods/groundmgr.asm"

 ENDSECTION
