;*******************************************************************************
; The bench's map, in a page of its own over the cartridge window (page 6,
; $0000), as a game's : the descriptors, the layouts, the chunks, the tile
; index (map-data.asm, tools/gen_map.py) and the tile routines.
;
; A tile routine draws its tile's byte, $0F + 15 * its index, at the cell's
; centre and the byte before it, on both planes : the bench reads the screen
; back as a checksum. With TilemapBuffer.PLANES_CURSOR plane 1 comes in Y and
; the routine leaves Y on the next cell ; else it reads glb_screen_location_1.
; Either way the same bytes land at the same places.
;*******************************************************************************

 SECTION code

map.bytes       EXPORT
map.words       EXPORT

        INCLUDE "engine/constants.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/graphics/tilemap/data-types/map-16bits.equ"

_tile MACRO
tile.\1
        lda   #$0F+15*\1
        sta   -1,u                     ; plane 2
        sta   ,u
 IFDEF TilemapBuffer.PLANES_CURSOR
        sta   -1,y                     ; plane 1, the loop's cursor
        sta   ,y
        leay  2,y                      ; left on the next cell
 ELSE
        ldu   <glb_screen_location_1   ; plane 1
        sta   -1,u
        sta   ,u
 ENDC
        rts
 ENDM

        _tile 0
        _tile 1
        _tile 2
        _tile 3
        _tile 4
        _tile 5
        _tile 6
        _tile 7
        _tile 8
        _tile 9
        _tile 10
        _tile 11
        _tile 12
        _tile 13
        _tile 14
        _tile 15

        INCLUDE "src/assets/map/map-data.asm"

 ENDSECTION
