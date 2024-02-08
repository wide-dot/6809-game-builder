
ymm.obj.play EXPORT

 SECTION code

ymm.obj.play
        jsr   irq.off
        stb   ymm.loop
        sty   ymm.callback
        sta   ymm.data.page

        jsr   ymm.play.subroutine

        jsr   ym2413.init
        jmp   irq.on

 ENDSECTION

        INCLUDE "new-engine/sound/ymm.asm"