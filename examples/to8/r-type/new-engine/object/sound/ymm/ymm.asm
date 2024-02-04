
        INCLUDE "new-engine/system/to8/map.const.asm"

 SECTION code

ymm.init
        stb   ymm.loop
        stx   ymm.data
        sty   ymm.callback
        lda   #1
        sta   ymm.status
        sta   ymm.frame.waits
        ldu   #ymm.buffer
        stu   ymm.data.pos
        jmp   ymm.decompress

 ENDSECTION

        INCLUDE "./new-engine/sound/ymm.asm"