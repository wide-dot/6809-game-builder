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

pscroll.stage4.fillMap EXPORT           ; la recopie collision -> carte
collisionMapForeground EXTERNAL
pscroll.field.map      EXTERNAL         ; cote cartouche, avec qui la lit

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

; -----------------------------------------------------------------------------
; pscroll.stage4.fillMap — la carte de collision devient le bitfield
; -----------------------------------------------------------------------------
; Deux pages se disputent la fenetre cartouche : la source (collision) et la
; destination (field.map, dans la page pscroll). D'ici — RAM fixe — on alterne
; les montages et on fait transiter chaque tranche par le staging de feedBand
; (120 octets, libre a cet instant). 1440 octets = 12 tranches de 120.
;
; Appelee par stage4.init, qui a deja pose pscroll.cart.page : c'est elle
; qu'on remonte en sortant, comme toute routine de cette part.
; -----------------------------------------------------------------------------
fill.CHUNK equ 120

pscroll.stage4.fillMap
        ldx   #collisionMapForeground  ; x ne sert qu'a lire la source,
        ldu   #pscroll.field.map       ; u qu'a ecrire la carte : chacun
                                       ; traverse les montages sans etre touche
@chunk  ; la source, par tranche, vers le staging
        lda   #map.RAM_OVER_CART+collision.page
        _SetCartPageA
        ldy   #pscroll.feed.stage
@in     ldd   ,x++
        std   ,y++
        cmpy  #pscroll.feed.stage+fill.CHUNK
        blo   @in
        ; le staging vers la carte, page pscroll remontee
        lda   pscroll.cart.page
        _SetCartPageA
        ldy   #pscroll.feed.stage
@out    ldd   ,y++
        std   ,u++
        cmpy  #pscroll.feed.stage+fill.CHUNK
        blo   @out
        cmpu  #pscroll.field.map+pscroll.MAP_STRIDE*pscroll.ROWS
        blo   @chunk
        rts                            ; cart.page est deja remontee
