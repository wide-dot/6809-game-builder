;*******************************************************************************
; pscroll.vid — la part RAM FIXE du champ de gommes du stage 4
;
; Tout ce qui monte un buffer, et rien d'autre : feedBand, engraveColumn,
; buildSkeleton, les routines deroulees generees (rangees, cellules, runs,
; zrow) et les tables lues buffer monte. Destination $4000-$5FFF — la
; demi-page video 0, 8 Ko de RAM FIXE : ces routines restent appelables quelle
; que soit la page en fenetre cartouche, et leurs tables lisibles de partout
; sans une donnee de lien.
;
; LA DISCIPLINE : chaque routine d'ici qui commute la fenetre cartouche pour
; atteindre un buffer REMONTE pscroll.cart.page avant son rts — c'est la que
; vit le code qui l'a appelee. Seule exception, nommee : engraveColumn,
; appelee par feedBand AVEC le buffer monte.
;*******************************************************************************

collisionMapForeground EXTERNAL

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "gen/layout.asm"
        INCLUDE "gen/stages/04/map/map.const.asm"
field.MAP_W        equ map.COLS*12
field.VP_Y         equ 11
pscroll.CELL_W     equ 3
pscroll.BAND_LINES equ 180
pscroll.MAP_WIDTH  equ field.MAP_W
pscroll.MAX_SEAMS  equ 8
PSCROLL_PART       equ 2                ; la part RAM fixe ($4000)

 SECTION code

        INCLUDE "engine/graphics/tilemap/pscroll/pscroll.asm"
        INCLUDE "src/stages/04/pscroll-rows.asm"

 ENDSECTION
