 SECTION code
 opt c,ct

; ----- FRAMEWORK MACRO / CONSTANT  --------------------------------------------
        INCLUDE "engine/system/thomson/pack/monitor.asm"
        INCLUDE "engine/pack/ymm.asm"
        INCLUDE "engine/pack/vgc.asm"
        INCLUDE "engine/timing/time.macro.asm"

 IFDEF TO8
        INCLUDE "engine/system/to8/pack/std.asm"
        INCLUDE "engine/system/to8/pack/irq.asm"
        INCLUDE "engine/system/to8/monitor/monitor.macro.asm"
 ENDC

 IFDEF MO6       
        INCLUDE "engine/system/mo6/pack/std.asm"
        INCLUDE "engine/system/mo6/pack/irq.asm"
        INCLUDE "engine/system/mo6/monitor/monitor.macro.asm"
        INCLUDE "engine/system/mo6/sound/buzzer.macro.asm"
 ENDC

; ----- INITIALIZATION ---------------------------------------------------------
main.init
        _glb.init
 IFDEF MO6       
        _buzzer.disable
 ENDC
        _monitor.jsr.setp.invoke #1,#$0000,#$0888
        _monitor.console.set80C

; ----- MAIN PROGRAM -----------------------------------------------------------
_main.test MACRO
        ldx   #\1 ; test label
        ldy   #\2 ; test routine
        jsr   main.test
 ENDM

main.loop

        ; print some page ids
        ;_ram.data.set #loader.PAGE
        ;_loader.file.getPageID #assets.sounds.sn
        ;jsr   monitor.printHex8

        _monitor.print #main.str.HEADER
        clr   main.errorFlag        ; Initialize error flag

        ; Timer test
        _monitor.print #main.str.1MHZ
        ldb   #1 ; Clock 1MHz
        stb   clock.type
        _main.test main.str.WR,mplus.ut.timer.testRW
        _main.test main.str.COUNTDOWN,mplus.ut.timer.testCountdown
        _main.test main.str.CYCLE,mplus.ut.timer.testCycle
        _main.test main.str.RESET,mplus.ut.timer.testReset

        ; Play test
        _monitor.print #main.str.PLAYING
        _main.test main.str.DAC,dac.ut.testDAC
        _main.test main.str.SN,sn76489.ut.testSN76489
        _main.test main.str.SN.noise,sn76489.ut.testSN76489
        _main.test main.str.YM,ym2413.ut.testYM2413
        _main.test main.str.YM.rythm,ym2413.ut.testYM2413
        _main.test main.str.demo,song.ut.test
        _main.test main.str.MEA,mea8000.ut.testMEA8000
        
        ; MIDI test
        _main.test main.str.MIDI,ef6850.ut.testMIDI

        ; 440Hz test
        _monitor.print #main.str.CRLF
        jsr   sn76489.ut.testSN76489.440Hz
        jsr   ym2413.ut.testYM2413.440Hz
        jsr   mea8000.ut.testMEA8000.440Hz
        jsr   dac.ut.testDAC.440Hz ; infinite loop

        ; Final result based on error flag
        tst   main.errorFlag
        beq   @all_tests_passed
        ; At least one error occurred
        _monitor.jsr.setp.invoke #1,#$0000,#$0008 ; red
        bra   @end_tests
@all_tests_passed
        ; All tests passed
        _monitor.jsr.setp.invoke #1,#$0000,#$0080 ; green
@end_tests
        bra   *

main.test
        jsr   monitor.print ; print test name
        jsr   ,y            ; run test routine
        bcs   @test_failed
        _monitor.print #main.str.OK
        bra   @test_done
@test_failed
        _monitor.print #main.str.KO
        inc   main.errorFlag ; Mark that an error occurred
@test_done
        _monitor.print #main.str.CRLF
        rts

clock.type fcb 0
main.errorFlag fcb 0    ; Global error flag: 0=no errors, >0=at least one error

; ----- DATA -------------------------------------------------------------------
main.str.HEADER     fcc "Musique PLUS - Factory test"
                    _monitor.chr.CRLF
                    fcc "___________________________"
                    _monitor.chr.CRLF
main.str.CRLF       _monitor.str.CRLF
main.str.1MHZ       fcc "Timer 1MHz:"
                    _monitor.str.CRLF
main.str.WR         fcs "- Write and Read ... "
main.str.COUNTDOWN  fcs "- Countdown ........ "
main.str.CYCLE      fcs "- Cycle ............ "
main.str.RESET      fcs "- Reset ............ "
main.str.PLAYING    _monitor.chr.CRLF
                    fcc "Play:"
                    _monitor.str.CRLF
main.str.DAC        fcs "- DAC (FIRQ) ....... "
main.str.SN         fcs "- SN76489 .......... "
main.str.SN.noise   fcs "- SN76489 Noise .... "
main.str.YM         fcs "- YM2413 ........... "
main.str.YM.rythm   fcs "- YM2413 Rythm ..... "
main.str.demo       fcs "- Demo song ........ press enter to stop... "
main.str.MEA        fcs "- MEA8000 .......... "
main.str.MIDI       _monitor.chr.CRLF
                    fcc "MIDI:"
                    _monitor.str.CRLF
main.str.OK         fcs "OK"
main.str.KO         fcs "KO"
        
 ENDSECTION

; ----- UNIT TESTS -------------------------------------------------------------
        INCLUDE "src/assets/mplus/mplus.ut.asm"
        INCLUDE "src/assets/mplus/dac.ut.asm"
        INCLUDE "src/assets/mplus/sn76489.ut.asm"
        INCLUDE "src/assets/mplus/ym2413.ut.asm"
        INCLUDE "src/assets/mplus/ef6850.ut.asm"
        INCLUDE "src/assets/mplus/mea8000.ut.asm"
        INCLUDE "src/assets/mplus/song.ut.asm"

; ----- FRAMEWORK ASM CODE  ----------------------------------------------------
; TODO : investiguate why we need to include these files before the framework code
;        if we do not include them, we have unapplied irq.on/off at runtime link

 IFDEF TO8
        INCLUDE "engine/system/to8/irq/irq.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/controller/keyboard.fast.asm"
 ENDC

 IFDEF MO6       
        INCLUDE "engine/system/mo6/irq/irq.asm"
        INCLUDE "engine/system/mo6/map.const.asm"
 ENDC

        INCLUDE "engine/global/glb.init.asm"
        INCLUDE "engine/system/thomson/monitor/monitor.print.asm"
        INCLUDE "engine/sound/ymm.asm"
        INCLUDE "engine/sound/vgc.buffers.asm"
        INCLUDE "engine/sound/vgc.asm"
        INCLUDE "engine/system/thomson/sound/mea8000.phonemes.const.asm"
        INCLUDE "engine/system/thomson/sound/mea8000.phonemes.asm"
        INCLUDE "engine/system/thomson/sound/mea8000.phonemes.read.asm"
        INCLUDE "engine/system/thomson/controller/ascii.const.asm"
        INCLUDE "engine/timing/time.asm"