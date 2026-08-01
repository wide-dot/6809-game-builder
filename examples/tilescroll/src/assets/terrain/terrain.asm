;*******************************************************************************
; Terrain collision — the mounted unit
;
; This is how r-type ships its per-level collision : lvlMapWidth, the engine
; implementation — whose jump table has to be the unit's first bytes, which is
; why nothing else may come before the include — then the maps table and the
; bitmap. One bit per 3 pixel tile, lvlMapWidth bytes per map row.
;
; The resident side (terrainCollision.main.asm, in the game mode) reaches this
; unit through the object index, page mounted per call.
;
; The bench map is a single wall column at map byte 3, bit 7 : solid pixels
; 80..82 on every row, everything else open. That makes every expected value
; derivable by hand : sensor x maps to column (x-8)/24 and tile ((x-8)%24)/3,
; and an impact reports col*24 + tile*3 + 8.
;*******************************************************************************

; the scroll state lives in the game mode ; the map lookup follows it
scroll_tile_pos          EXTERNAL
scroll_tile_pos_offset24 EXTERNAL

; so do the sensors, the impact and the boss-follow state : they belong to the
; resident half (terrainCollision.main.asm), the mounted code only reads and
; writes them. v1 hid this coupling behind undefextern ; here it is spelled.
terrainCollision.sensor.x   EXTERNAL
terrainCollision.sensor.y   EXTERNAL
terrainCollision.impact.x   EXTERNAL
terrainCollision.disabled   EXTERNAL
terrainCollision.bgFlag     EXTERNAL
terrainCollision.bgByteOff  EXTERNAL
terrainCollision.bgBitShift EXTERNAL
terrainCollision.bgColTmp   EXTERNAL

 SECTION code

; constants.asm asks the game for this before it defines the object layout
ext_variables_size equ 20
        INCLUDE "engine/constants.asm"

map_width   equ 288                    ; the impact cap, same as the game mode's
lvlMapWidth equ 8                      ; 8 bytes = 64 tiles = 192 px per row

        INCLUDE "engine/objects/collision/terrainCollision.asm"

terrainCollision.maps
        fdb   map.wall                 ; id 0 : background
        fdb   map.wall                 ; id 1 : foreground, same map here

; 30 rows — the engine's yOffset table covers 30 of them — of 8 bytes
map.wall
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$00,$80,$00,$00,$00,$00

 ENDSECTION
