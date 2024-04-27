 SECTION code
 opt c,ct

; ----- FRAMEWORK MACRO / CONSTANT  --------------------------------------------
        INCLUDE "engine/system/to8/pack/std.asm"
        INCLUDE "engine/system/thomson/pack/monitor.asm"

; ----- INITIALIZATION ---------------------------------------------------------
main.init
        _glb.init
        _monitor.setp #1,#$0000,#$0888
        _monitor.console.set80C

; ----- MAIN PROGRAM -----------------------------------------------------------

_main.test MACRO
        ldx   #\1 ; test label
        ldy   #\2 ; test routine
        jsr   main.test
 ENDM

main.loop
        _monitor.print #main.str.HEADER

        ; Timer test
        _monitor.print #main.str.TIMER
        _main.test main.str.WR,mplus.ut.timer.testRW

        _monitor.print #main.str.1MHZ
        ldb   #1 ; Clock 1MHz
!       pshs  b
        _main.test main.str.COUNTDOWN,mplus.ut.timer.testCountdown
        ;_main.test main.str.CYCLE,mplus.ut.timer.testCycle
        ;_main.test main.str.RESET,mplus.ut.timer.testReset
        ;_main.test main.str.IRQ,mplus.ut.timer.testIRQ
        ;_main.test main.str.FIRQ,mplus.ut.timer.testFIRQ
        puls  b
        decb  ; Clock 3.58MHz
        bne   >
        _monitor.print #main.str.3MHZ
        bra   <
!

        ; Play test
        _monitor.print #main.str.PLAYING

        ;_main.test main.str.SN,mplus.ut.testSN76489
        ;_main.test main.str.YM,mplus.ut.testYM2413
        ;_main.test main.str.MIDI,mplus.ut.testMIDI
        ;_main.test main.str.MEA,mplus.ut.testMEA8000
        _monitor.setp #1,#$0000,#$0080
        bra   *

main.test
        jsr   monitor.print ; print test name
        jsr   ,y            ; run test routine
        bcs   @else
        _monitor.print #main.str.OK
        bra   @endif
@else   _monitor.print #main.str.KO
        _monitor.setp #1,#$0000,#$0008
        ;bra   *
@endif  _monitor.print #main.str.CRLF
        rts

; ----- DATA -------------------------------------------------------------------
main.str.HEADER     fcc "Musique PLUS - Factory test"
                    _monitor.chr.CRLF
                    fcc "___________________________"
                    _monitor.chr.CRLF
main.str.CRLF
                    _monitor.str.CRLF
main.str.TIMER      fcc "Timer:"
                    _monitor.str.CRLF
main.str.1MHZ       fcc "1MHz"
                    _monitor.str.CRLF
main.str.3MHZ       fcc "3MHz:"
                    _monitor.str.CRLF
main.str.WR         fcs "- Write and Read ... "
main.str.COUNTDOWN  fcs "- Countdown ........ "
main.str.CYCLE      fcs "- Cycle ............ "
main.str.RESET      fcs "- Reset ............ "
main.str.IRQ        fcs "- IRQ .............. "
main.str.FIRQ       fcs "- FIRQ ............. "
main.str.PLAYING    _monitor.chr.CRLF
                    fcc "Play: "
                    _monitor.str.CRLF
main.str.SN         fcs "- SN76489 .......... "
main.str.YM         fcs "- YM2413 ........... "
main.str.MIDI       fcs "- MIDI ............. "
main.str.MEA        fcs "- MEA8000 .......... "
main.str.OK         fcs "OK"
main.str.KO         fcs "KO"

 ENDSECTION

; ----- FRAMEWORK ASM CODE  ----------------------------------------------------
        INCLUDE "engine/global/glb.init.asm"
        INCLUDE "engine/system/thomson/monitor/monitor.print.asm"
        INCLUDE "src/assets/mplus/mplus.ut.asm"
