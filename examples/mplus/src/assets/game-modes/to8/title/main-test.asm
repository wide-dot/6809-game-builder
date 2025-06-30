 SECTION code
 opt c,ct

; ----- FRAMEWORK MACRO / CONSTANT  --------------------------------------------
        INCLUDE "engine/system/to8/pack/std.asm"
        INCLUDE "engine/system/to8/pack/irq.asm"
        INCLUDE "engine/system/thomson/pack/monitor.asm"
        INCLUDE "engine/system/to8/monitor/monitor.macro.asm"
        INCLUDE "engine/pack/ymm.asm"
        INCLUDE "engine/pack/vgc.asm"

; ----- MAIN PROGRAM -----------------------------------------------------------
        INCLUDE "src/assets/game-modes/title/main-test.asm"
        
 ENDSECTION

; ----- UNIT TESTS -------------------------------------------------------------
        INCLUDE "src/assets/mplus/mplus.ut.asm"
        INCLUDE "src/assets/mplus/dac.ut.asm"
        INCLUDE "src/assets/mplus/sn76489.ut.asm"
        INCLUDE "src/assets/mplus/ym2413.ut.asm"
        INCLUDE "src/assets/mplus/ef6850.ut.asm"
        INCLUDE "src/assets/mplus/mea8000.ut.asm"

; ----- FRAMEWORK HARDWARE SPECIFIC ASM CODE
; if irq is declared after framework code, we will have unapplied irq.on/off at runtime link
; looks like a bug ? TODO: investiguate
        INCLUDE "engine/system/to8/irq/irq.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/thomson/controller/ascii.const.asm"

; ----- FRAMEWORK ASM CODE  ----------------------------------------------------
        INCLUDE "engine/global/glb.init.asm"
        INCLUDE "engine/system/thomson/monitor/monitor.print.asm"
        INCLUDE "engine/sound/ymm.asm"
        INCLUDE "engine/sound/vgc.buffers.asm"
        INCLUDE "engine/sound/vgc.asm"
        INCLUDE "engine/system/thomson/sound/mea8000.phonemes.const.asm"
        INCLUDE "engine/system/thomson/sound/mea8000.phonemes.asm"
        INCLUDE "engine/system/thomson/sound/mea8000.phonemes.read.asm"
