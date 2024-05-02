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

; Bit 7: R- Timer - INT requested by timer (0=NO, 1=YES)
;        -W Timer - reset timer by reloading period to counter (stateless, 1=do)
; Bit 6: -W Timer - fire INT and enable countdown of timer (stateless, 1=do)
; Bit 5: -------  - Unused
; Bit 4: RW Timer - INT select (0=IRQ, 1=FIRQ)
; Bit 3: RW Timer - (F)IRQ (0=disabled, 1=enabled)
; Bit 2: RW Timer - clock select (0=1Mhz, 1=3.579545Mhz)
; Bit 1: RW Timer - countdown of timer (0=disabled, 1=enabled)
; Bit 0: RW TI    - TI clock disable (0=enabled, 1=disabled)
; Notes : - Timer F/IRQ ack by CPU is done by reading this control register
;         - TI clock enable will be effective only after the first write to TI data register

mplus.ut.timer.testRW
        ldd   #$1234
        std   map.MPLUS.TIMER
        lda   #%10000001 ; load period to counter
        sta   map.MPLUS.CTRL
        ldd   map.MPLUS.TIMER
        cmpd  #$1234
        bne   >
        jmp   mplus.ut.timer.returnOK
!       jmp   mplus.ut.timer.returnKO

mplus.ut.timer.testCountdown
        ldd   #$1000
        std   map.MPLUS.TIMER
        tst   clock.type
        beq   @ThreeMHz
@OneMHz lda   #%10000011 ; reload period to counter and start countdown
        sta   map.MPLUS.CTRL
        nop                  ; [2]
        nop                  ; [2]
        anda  #%01111101     ; [2] stop countdown
        sta   map.MPLUS.CTRL ; [5] Total 11 cycles
        ldd   map.MPLUS.TIMER
        cmpd  #$1000-11
        bne   >
        jmp   mplus.ut.timer.returnOK
!       jmp   mplus.ut.timer.returnKO
@ThreeMHz
        lda   #%10000111 ; reload period to counter and start countdown
        sta   map.MPLUS.CTRL
        nop                  ; [2]
        nop                  ; [2]
        anda  #%01111101     ; [2] stop countdown
        sta   map.MPLUS.CTRL ; [5] Total 11*3.58=39 or 40 cycles
        ldd   map.MPLUS.TIMER
        cmpd  #$1000-39
        bne   >
@ok     jmp   mplus.ut.timer.returnOK
!       cmpd  #$1000-40
        beq   @ok
        jmp   mplus.ut.timer.returnKO

mplus.ut.timer.testCycle
        ldd   #$0010
        std   map.MPLUS.TIMER
        tst   clock.type
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
        anda  #%00111101 ; stop countdown
        sta   map.MPLUS.CTRL ; 23 cycles
        ldd   map.MPLUS.TIMER
        cmpd  #$0010+(16+1)-23
        bne   >
        jmp   mplus.ut.timer.returnOK
!       jmp   mplus.ut.timer.returnKO
@ThreeMHz
        lda   #%10000111 ; reload period to counter and start countdown
        sta   map.MPLUS.CTRL
        nop
        nop
        anda  #%00111101 ; stop countdown
        sta   map.MPLUS.CTRL ; 39 or 40 cycles
        ldd   map.MPLUS.TIMER
        cmpd  #$0010+(16+1)*2-39
        bne   >
@ok     jmp   mplus.ut.timer.returnOK
!       cmpd  #$0010+(16+1)*2-40
        beq   @ok
        jmp   mplus.ut.timer.returnKO

mplus.ut.timer.testReset
        ldd   #$DCBA
        std   map.MPLUS.TIMER
        tst   clock.type
        beq   @ThreeMHz
@OneMHz lda   #%10000011 ; reset counter to period and start countdown
        bra   >
@ThreeMHz
        lda   #%10000111 ; reset counter to period and start countdown
!       sta   map.MPLUS.CTRL
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        anda  #%00111101 ; stop countdown
        ora   #%10000000 ; ask for a counter reset
        sta   map.MPLUS.CTRL
        ldd   map.MPLUS.TIMER
        cmpd  #$DCBA
        bne   >
        jmp   mplus.ut.timer.returnOK
!       jmp   mplus.ut.timer.returnKO

mplus.ut.timer.testIRQ
        tst   clock.type
        andcc #%11111110
        rts

mplus.ut.timer.testFIRQ
        tst   clock.type
        andcc #%11111110
        rts

mplus.ut.timer.testImIRQ
        tst   clock.type
        andcc #%11111110
        rts

mplus.ut.timer.testImFIRQ
        tst   clock.type
        andcc #%11111110
        rts

mplus.ut.timer.returnOK
        jsr   monitor.printHex16
        _monitor.putc #ascii.SPACE
        andcc #%11111110 ; OK
        rts

mplus.ut.timer.returnKO
        jsr   monitor.printHex16
        _monitor.putc #ascii.SPACE
        orcc  #%00000001 ; KO
        rts

mplus.ut.testSN76489
        tst   clock.type
        andcc #%11111110
        rts

mplus.ut.testYM2413
        tst   clock.type
        andcc #%11111110
        rts

mplus.ut.testMIDI
        tst   clock.type
        andcc #%11111110
        rts

mplus.ut.testMEA8000
        tst   clock.type
        andcc #%11111110
        rts

 ENDSECTION
