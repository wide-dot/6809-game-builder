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

mplus.ut.timer.testRW
        tst   clock.type
        beq   @ThreeMHz
@OneMHz lda   #%00000001     ; reset control register and set 1MHz clock
        bra   >
@ThreeMHz
        lda   #%00000101     ; reset control register and set 3.579545Mhz clock
!       sta   map.MPLUS.CTRL ; to no countdown
        ldd   #$0000
        std   map.MPLUS.TIMER ; clear any remaining values ...
        ldd   #$1234
        std   map.MPLUS.TIMER
        ldd   map.MPLUS.TIMER ; value is expected to be updated without the need to reset timer
        cmpd  #$1234
        bne   >
        jmp   mplus.ut.timer.returnOK
!       jmp   mplus.ut.timer.returnKO

mplus.ut.timer.testCountdown
        ldd   #$1000
        std   map.MPLUS.TIMER
        tst   clock.type
        beq   @ThreeMHz
@OneMHz lda   #%10000011 ; reset counter to period and start countdown
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
@ThreeMHz
        lda   #%10000111 ; reset counter to period and start countdown
        sta   map.MPLUS.CTRL
        nop                  ; [2] -1 for reset time
        nop                  ; [2]
        anda  #%01111101     ; [2]
        sta   map.MPLUS.CTRL ; [5]
        ldd   map.MPLUS.TIMER
        cmpd  #$0FDA
        bne   >
@ok     jmp   mplus.ut.timer.returnOK
!       cmpd  #$0FDB
        beq   @ok
        jmp   mplus.ut.timer.returnKO

mplus.ut.timer.testCycle
        ldd   #$0010
        std   map.MPLUS.TIMER
        tst   clock.type
        beq   @ThreeMHz
@OneMHz lda   #%10000011 ; reset counter to period and start countdown
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
@ThreeMHz
        lda   #%10000111 ; reload period to counter and start countdown
        sta   map.MPLUS.CTRL
        nop
        nop
        anda  #%00111101 ; stop countdown
        sta   map.MPLUS.CTRL ; 39.375 cycles @3.57, loose 1 cycle when reset or reload counter
        ldd   map.MPLUS.TIMER
        cmpd  #$000C ; 
        bne   >
@ok     jmp   mplus.ut.timer.returnOK
!       cmpd  #$000D
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
        beq   @ThreeMHz
@OneMHz lda   #%10001011 ; reset counter to period, start countdown, activate IRQ
        bra   >
@ThreeMHz
        lda   #%10001111 ; reset counter to period, start countdown, activate IRQ
!       sta   map.MPLUS.CTRL
        clra  ; dummy instruction
        bne   >
        jmp   mplus.ut.timer.returnOK
!       jmp   mplus.ut.timer.returnKO

mplus.ut.timer.doIRQ
        rts

mplus.ut.timer.testFIRQ
        ldd   #0
        std   mplus.ut.timer.intCpt
        std   mplus.ut.timer.waitCpt
        sta   mplus.ut.timer.state
        lda   #%00000001     ; reset control register
        sta   map.MPLUS.CTRL ; to no countdown
        ldd   #$1000
        std   map.MPLUS.TIMER
        ldd   #mplus.ut.timer.doFIRQ
        std   map.FIRQPT     ; map FIRQ routine
        andcc #%10111111     ; unmask firq
        tst   clock.type
        beq   @ThreeMHz
@OneMHz lda   #%10011011 ; reset counter to period, start countdown, activate FIRQ
        bra   >
@ThreeMHz
        lda   #%10011111 ; reset counter to period, start countdown, activate FIRQ
!       sta   map.MPLUS.CTRL

@loop   inc   mplus.ut.timer.waitCpt+1
        bne   >
        inc   mplus.ut.timer.waitCpt
!       ldd   mplus.ut.timer.intCpt
        beq   @loop

        lda   map.MPLUS.CTRL
        anda  #%11110111     ; disable mplus interupts
        sta   map.MPLUS.CTRL ; apply changes
        orcc  #%01000000     ; mask firq

        ; this code bloc duration is expected to be > timer period
        ; goal is to check that mplus int requests are disabled, if not disabled, an int request flag will be set
        ldd   mplus.ut.timer.waitCpt
        jsr   monitor.printHex16
        ldd   mplus.ut.timer.intCpt
        jsr   monitor.printHex16

        lda   map.MPLUS.CTRL           ; read flag: INT requested by timer (expected to be cleared)
        anda  #%10000000
        ldb   mplus.ut.timer.state     ; read a backup of flag: INT requested by timer (expected to be set)
        andb  #%10000000
        cmpd  #$0080
        bne   >
        jmp   mplus.ut.timer.returnOK
!       jmp   mplus.ut.timer.returnKO

mplus.ut.timer.intCpt  fdb 0
mplus.ut.timer.waitCpt fdb 0
mplus.ut.timer.state   fcb 0

mplus.ut.timer.doFIRQ
                                       ; [12] FIRQ (equivalent to pshs pc,cc | jmp $FFF6)
                                       ; [ 8] ROM jmp to user address
        pshs  a
        lda   map.MPLUS.CTRL           ; FIRQ acknowledge by reading ctrl register
        sta   mplus.ut.timer.state     ; save flag: INT requested by timer
        inc   mplus.ut.timer.intCpt+1
        bne   >
        inc   mplus.ut.timer.intCpt
!       puls  a,pc,cc                  ; [ 6] RTI (equivalent to puls pc,cc)

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
