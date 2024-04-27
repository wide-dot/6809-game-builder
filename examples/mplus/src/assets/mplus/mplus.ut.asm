mplus.ut.timer.testRW        EXPORT
mplus.ut.timer.testCountdown EXPORT
mplus.ut.timer.testCycle     EXPORT
mplus.ut.timer.testReset     EXPORT
mplus.ut.timer.testIRQ       EXPORT
mplus.ut.timer.testFIRQ      EXPORT
mplus.ut.testSN76489         EXPORT
mplus.ut.testYM2413          EXPORT
mplus.ut.testMIDI            EXPORT
mplus.ut.testMEA8000         EXPORT

 SECTION code

        ; Control/status register
        ;   Bit 7: R- Timer - INT requested by timer (0=NO, 1=YES)
        ;          -W Timer - reset timer (0=do nothing, 1=reload period to counter)
        ;   Bit 6: -------  - Unused
        ;   Bit 5: -------  - Unused
        ;   Bit 4: RW Timer - INT select (0=IRQ, 1=FIRQ)
        ;   Bit 3: RW Timer - (F)IRQ enable (0=NO, 1=YES)
        ;   Bit 2: RW Timer - clock select (0=1Mhz, 1=3.579545Mhz)
        ;   Bit 1: RW Timer - enable countdown of timer (0=OFF, 1=ON)
        ;   Bit 0: RW TI    - TI clock disable (0=enabled, 1=disabled)
        ;   Note: Timer F/IRQ ack by CPU is done by reading this control register

mplus.ut.timer.testRW
        ldd   #$ABCD
        std   map.MPLUS.TIMER
        ldd   #%10000001 ; reload period to counter
        std   map.MPLUS.CTRL
        ldd   map.MPLUS.TIMER
        cmpd  #$ABCD
        bne   >
        andcc #%11111110 ; OK
        rts
!       jsr   monitor.printHex16
        _monitor.putc #ascii.SPACE
        orcc  #%00000001 ; KO
        rts

mplus.ut.timer.testCountdown
        ldd   #$7FFF
        std   map.MPLUS.TIMER
        tst   2,s
        beq   @ThreeMHz
@OneMHz lda   #%10000011 ; reload period to counter and start countdown
        sta   map.MPLUS.CTRL
        nop
        nop
        anda  #%01111101 ; stop countdown
        sta   map.MPLUS.CTRL
        ldd   map.MPLUS.TIMER
        cmpd  #$7F00
        bne   >
        andcc #%11111110 ; OK
        rts
!       jsr   monitor.printHex16
        _monitor.putc #ascii.SPACE
        orcc  #%00000001 ; KO
        rts
@ThreeMHz
        lda   #%10000111 ; reload period to counter and start countdown
        sta   map.MPLUS.CTRL
        nop
        nop
        anda  #%01111101 ; stop countdown
        sta   map.MPLUS.CTRL
        ldd   map.MPLUS.TIMER
        cmpd  #$7F00
        bne   >
        andcc #%11111110 ; OK
        rts
!       jsr   monitor.printHex16
        _monitor.putc #ascii.SPACE
        orcc  #%00000001 ; KO
        rts

mplus.ut.timer.testCycle
        ldd   #$0010
        std   map.MPLUS.TIMER
        tst   2,s
        beq   @ThreeMHz
@OneMHz lda   #%10000011 ; reload period to counter and start countdown
        sta   map.MPLUS.CTRL
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        anda  #%01111101 ; stop countdown
        sta   map.MPLUS.CTRL
        ldd   map.MPLUS.TIMER
        cmpd  #$7F00
        bne   >
        andcc #%11111110 ; OK
        rts
!       jsr   monitor.printHex16
        _monitor.putc #ascii.SPACE
        orcc  #%00000001 ; KO
        rts
@ThreeMHz
        lda   #%10000111 ; reload period to counter and start countdown
        sta   map.MPLUS.CTRL
        nop
        nop
        anda  #%01111101 ; stop countdown
        sta   map.MPLUS.CTRL
        ldd   map.MPLUS.TIMER
        cmpd  #$7F00
        bne   >
        andcc #%11111110 ; OK
        rts
!       jsr   monitor.printHex16
        _monitor.putc #ascii.SPACE
        orcc  #%00000001 ; KO
        rts

mplus.ut.timer.testReset
        ldd   #$1234
        std   map.MPLUS.TIMER
        tst   2,s
        beq   @ThreeMHz
@OneMHz ldd   #%10000001 ; reload period to counter
        bra   >
@ThreeMHz
        ldd   #%10000101 ; reload period to counter
!       std   map.MPLUS.CTRL
        ldd   map.MPLUS.TIMER
        cmpd  #$1234
        bne   >
        andcc #%11111110 ; OK
        rts
!       jsr   monitor.printHex16
        _monitor.putc #ascii.SPACE
        orcc  #%00000001 ; KO
        rts

mplus.ut.timer.testIRQ
        tst   2,s
        andcc #%11111110
        rts

mplus.ut.timer.testFIRQ
        tst   2,s
        andcc #%11111110
        rts

mplus.ut.testSN76489
        tst   2,s
        andcc #%11111110
        rts

mplus.ut.testYM2413
        tst   2,s
        andcc #%11111110
        rts

mplus.ut.testMIDI
        tst   2,s
        andcc #%11111110
        rts

mplus.ut.testMEA8000
        tst   2,s
        andcc #%11111110
        rts

 ENDSECTION
