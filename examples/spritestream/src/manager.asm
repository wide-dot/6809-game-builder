;*******************************************************************************
; The bench's manager unit, head : one copy per half of the video half page
; ($4000-$5FFF, slices 0 and 1 ; to8.config.xml gives spritestream.HALF),
; then the generated walkers (<spritestream genwalker clip="true">), the
; engine's runtime (engine/graphics/sprite/stream/spritestream.asm) and
; ENDSECTION. Half 0 exports the entries : the halves are the same code at
; the same addresses (only the direct page byte of the save stack's top
; differs).
;*******************************************************************************

        INCLUDE "engine/constants.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "src/bench.equ"

 IFEQ spritestream.HALF
spritestream.skips       EXPORT       ; the guard (t43-t44) : its count, the stack, its bottom record
spritestream.stack       EXPORT
spritestream.stack.end   EXPORT
spritestream.init        EXPORT
spritestream.restore     EXPORT
spritestream.draw        EXPORT
spritestream.drawAt      EXPORT
spritestream.drawClip    EXPORT
 ENDC

 SECTION code
