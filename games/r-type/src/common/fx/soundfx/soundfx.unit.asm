;*******************************************************************************
; Les bruitages — unité paginée
;
; Le pilote lit une boîte aux lettres résidente (`soundFX.newSound`, écrite par
; le macro `_soundFX.play` depuis la page de l'objet qui demande un bruitage) et
; pousse les commandes au YM2413, une par trame.
;
; Ce n'est pas un objet : ni OST, ni état par entité, rien dans la vague ne le
; nomme. Le stage le vise par `paged.call` depuis son IRQ utilisateur, comme le
; masque et le HUD — la v1 devait en faire un objet (`_Obj_Jmp ObjID_soundFX`)
; faute d'autre moyen d'atteindre du code paginé.
;
; L'unité porte le pilote (importé de la v1) ET les données de bruitage du jeu :
; six sons, décrits en commandes registre/valeur/délai.
;*******************************************************************************

soundfx.frame EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/sound/ym2413.macro.asm"

soundfx.frame
        INCLUDE "src/common/fx/soundfx/soundFX.asm"

 ENDSECTION
