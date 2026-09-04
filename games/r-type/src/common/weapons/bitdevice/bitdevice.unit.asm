;*******************************************************************************
; Les bit devices — les deux satellites blindés du vaisseau
;
; C'est l'objet v1 `objects/player1/bitdevice/obj.asm`. Une boîte à option de
; type 5 en fait naître un ; il vient se coller au-dessus ou au-dessous du
; vaisseau, encaisse les tirs et en rend.
;
; UN objet, DEUX instances, et elles ne vivent pas dans le pool : ce sont les
; OST statiques `bitdevTopOST` et `bitdevBotOST` de la zone réservée. La v1 les
; amorce en routine Dormant à l'ouverture du stage et au rechargement de
; checkpoint — deux gestes que notre main n'a pas encore, faute de cet objet
; (cf. docs/lang/fr/portage-main-2026-08.md §6bis). Ils arrivent avec lui.
;
; C'est du COMMUN : les sept game modes de la v1 le déclarent.
;
; L'entrée doit être le premier octet de l'unité.
; Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

bitdevice.Object EXPORT

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
        INCLUDE "engine/system/to8/controller/joypad.const.asm" ; masques dpad (BitTrack)
        ; le compte de bits vit dans `globals` depuis le 25/08/2026 : il doit
        ; survivre a l'echange de stage, que la page directe ne fait pas.
        INCLUDE "src/common/state/variables.asm"
        INCLUDE "src/common/weapons/bitdevice/bitdevice.equ"
        INCLUDE "src/stages/01/objid.const.asm"
        ; Le bruitage du ramassage : le meme que les boites a option
        ; (decision auteur, 04/09/2026). Le macro ecrit la boite aux lettres
        ; residente, exposee par api.asm.
        INCLUDE "src/common/fx/soundfx/soundFX.const.asm"
        INCLUDE "engine/sound/soundFX.macro.asm"

; V2-DEVIATION : gfxcomp génère `set_<nom>` là où la v1 nommait `Img_<nom>`.
Img_bitdevice_0 equ set_bitdevice_0
Img_bitdevice_1 equ set_bitdevice_1
Img_bitdevice_2 equ set_bitdevice_2
Img_bitdevice_3 equ set_bitdevice_3
Img_bitdevice_4 equ set_bitdevice_4
Img_bitdevice_5 equ set_bitdevice_5

; V2-DEVIATION : l'entrée v1 s'appelle `Object`.
bitdevice.Object
        INCLUDE "src/common/weapons/bitdevice/obj.asm"

 ENDSECTION
