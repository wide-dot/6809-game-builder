;*******************************************************************************
; Les reflets du counter-air — etincelles secondaires de l'arme du cristal rouge
;
; Sur la borne, chaque salve du counter-air cree, en plus des deux tetes, des
; REFLETS : un a chaque coin du pod (haut-droit, bas-droit) et un sur chaque
; bit device vivant (create_counter_air_reflection_*, 0x404CD3..0x404D60 ;
; tick run_counter_air_reflection 0x404E0F). Degats 2, 8 px arcade par trame
; vers l'avant du pod, clignotement sur deux images (normale / miroir
; vertical), fondu de huit images a l'extinction. Voir
; doc/analyse-bit-device.md §1.6.
;
; PAS DE SOURCE V1. Art extrait de la borne : tools/counterair-reflection-art.txt.
;
; Unite separee — cf. l'en-tete de `forcepod.unit.asm`.
; C'est du COMMUN : l'arme suit le pod, donc les huit stages.
;
; L'entree doit etre le premier octet de l'unite.
; Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

counterairreflect.Object EXPORT

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
        INCLUDE "src/common/player/player1.equ"
        INCLUDE "src/stages/01/objid.const.asm"
        INCLUDE "src/common/state/variables.asm"   ; stage.gum.hook, globals.backgroundSolid

; V2-DEVIATION : gfxcomp genere `set_<nom>` la ou la v1 nommait `Img_<nom>`.
Img_careflect_up0    equ set_careflect_up0     ; reflet du haut (bleu), normal
Img_careflect_up1    equ set_careflect_up1     ; ... miroir vertical (clignotement)
Img_careflect_dn0    equ set_careflect_dn0     ; reflet du bas (rouge), normal
Img_careflect_dn1    equ set_careflect_dn1     ; ... miroir vertical
Img_careflect_fade0  equ set_careflect_fade0   ; le fondu : la borne joue 7 -> 0
Img_careflect_fade1  equ set_careflect_fade1
Img_careflect_fade2  equ set_careflect_fade2
Img_careflect_fade3  equ set_careflect_fade3
Img_careflect_fade4  equ set_careflect_fade4
Img_careflect_fade5  equ set_careflect_fade5
Img_careflect_fade6  equ set_careflect_fade6
Img_careflect_fade7  equ set_careflect_fade7

counterairreflect.Object
        INCLUDE "src/common/weapons/forcepods/obj_counterairreflect.asm"

 ENDSECTION
