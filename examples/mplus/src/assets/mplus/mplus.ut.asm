mplus.ut.timer.testRW        EXPORT
mplus.ut.timer.testCountdown EXPORT
mplus.ut.timer.testCycle     EXPORT
mplus.ut.timer.testReset     EXPORT

 SECTION code

 ; TIMER need a single clock cycle to load, reload or reset the period to counter.
 ; This single cycle is 1MHz or 3.579545Mhz, based on clock select.
 ; You must provide period-1 to period register when setting timer frequency.

 ; Bit 7: R- Timer - INT requested by timer (0=NO, 1=YES)
 ;        -W Timer - reset timer by reloading period to counter
 ; Bit 6: -------  - Unused
 ; Bit 5: -------  - Unused
 ; Bit 4: RW Timer - INT select (0=IRQ, 1=FIRQ)
 ; Bit 3: RW Timer - (F)IRQ (0=disabled, 1=enabled)
 ; Bit 2: RW Timer - clock select (0=1Mhz, 1=3.579545Mhz)
 ; Bit 1: RW Timer - countdown of timer (0=disabled, 1=enabled)
 ; Bit 0: RW TI    - TI clock disable (0=enabled, 1=disabled)
 ; Notes : - Timer F/IRQ ack by CPU is done by reading this control register
 ;         - TI clock enable will be effective only after the first write to TI data register
 ;         - User must set the value: period-1 to period register

 ; ----------------------------------------------------------------------------
 ; testRW
 ; ----------------------------------------------------------------------------

mplus.ut.timer.testRW
        lda   #%00000000     ; reset control register and set 1MHz clock
        sta   map.MPLUS.CTRL ; to no countdown
        ldd   #$0000
        std   map.MPLUS.TIMER ; clear any remaining values ...
        ldd   #$1234
        std   map.MPLUS.TIMER
        ldd   map.MPLUS.TIMER ; value is expected to be updated without the need to reset timer
        cmpd  #$1234
        bne   >
        jmp   mplus.ut.timer.returnOK
!       jmp   mplus.ut.timer.returnKO

 ; ----------------------------------------------------------------------------
 ; testCountdown
 ; ----------------------------------------------------------------------------

mplus.ut.timer.testCountdown
        ldd   #$1000
        std   map.MPLUS.TIMER
        lda   #%10000010 ; reset counter to period and start countdown
        sta   map.MPLUS.CTRL
        nop                  ; [2] -1 for reset time
        nop                  ; [2]
        anda  #%01111101     ; [2]
        sta   map.MPLUS.CTRL ; [5]
        ldd   map.MPLUS.TIMER
        cmpd  #$0FF6
        bne   >
        jmp   mplus.ut.timer.returnOK
!       jmp   mplus.ut.timer.returnKO

 ; ----------------------------------------------------------------------------
 ; testCycle
 ; ----------------------------------------------------------------------------

mplus.ut.timer.testCycle
        ldd   #$0010
        std   map.MPLUS.TIMER
        lda   #%10000010 ; reset counter to period and start countdown
        sta   map.MPLUS.CTRL
        nop   ; -1 for reset time
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        anda  #%00111101 ; stop countdown [2] -1 for reload time
        sta   map.MPLUS.CTRL ; [5]
        ldd   map.MPLUS.TIMER
        cmpd  #$000B
        bne   >
        jmp   mplus.ut.timer.returnOK
!       jmp   mplus.ut.timer.returnKO

 ; ----------------------------------------------------------------------------
 ; testReset
 ; ----------------------------------------------------------------------------

mplus.ut.timer.testReset
        ldd   #$DCBA
        std   map.MPLUS.TIMER
        lda   #%10000010 ; reset counter to period and start countdown
        sta   map.MPLUS.CTRL
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        anda  #%00111100 ; stop countdown
        ora   #%10000000 ; ask for a counter reset
        sta   map.MPLUS.CTRL
        ldd   map.MPLUS.TIMER
        cmpd  #$DCBA
        bne   >
        jmp   mplus.ut.timer.returnOK
!       jmp   mplus.ut.timer.returnKO

 ; ----------------------------------------------------------------------------
 ; Common subroutines
 ; ----------------------------------------------------------------------------

mplus.ut.timer.returnOK
        jsr   monitor.printHex16
mplus.ut.returnOK
        _monitor.jsr.putc.invoke #ascii.SPACE
        andcc #%11111110 ; OK
        rts

mplus.ut.timer.returnKO
        jsr   monitor.printHex16
mplus.ut.returnKO
        _monitor.jsr.putc.invoke #ascii.SPACE
        orcc  #%00000001 ; KO
        rts

 ENDSECTION 