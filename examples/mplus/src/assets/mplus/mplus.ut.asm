samples.timpani              EXTERNAL
vgm.ym                       EXTERNAL
vgm.sn                       EXTERNAL
;lotr.txt                     EXTERNAL
harder.mea                   EXTERNAL

mplus.ut.timer.testRW        EXPORT
mplus.ut.timer.testCountdown EXPORT
mplus.ut.timer.testCycle     EXPORT
mplus.ut.timer.testReset     EXPORT
mplus.ut.testDAC             EXPORT
mplus.ut.testSN76489         EXPORT
mplus.ut.testYM2413          EXPORT
mplus.ut.testMIDI            EXPORT
mplus.ut.testMEA8000         EXPORT

        INCLUDE "engine/system/thomson/sound/dac.enable.asm"
        INCLUDE "engine/system/to8/sound/dac.mute.asm"

 SECTION code

        INCLUDE "engine/sound/firq.pcm.macro.asm"
        INCLUDE "engine/sound/firq.pcm.const.asm"

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
        tst   clock.type
        beq   @ThreeMHz
@OneMHz lda   #%00000000     ; reset control register and set 1MHz clock
        bra   >
@ThreeMHz
        lda   #%00000100     ; reset control register and set 3.579545Mhz clock
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

 ; ----------------------------------------------------------------------------
 ; testCountdown
 ; ----------------------------------------------------------------------------

mplus.ut.timer.testCountdown
        ldd   #$1000
        std   map.MPLUS.TIMER
        tst   clock.type
        beq   @ThreeMHz
@OneMHz lda   #%10000010 ; reset counter to period and start countdown
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
        lda   #%10000110 ; reset counter to period and start countdown
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

 ; ----------------------------------------------------------------------------
 ; testCycle
 ; ----------------------------------------------------------------------------

mplus.ut.timer.testCycle
        ldd   #$0010
        std   map.MPLUS.TIMER
        tst   clock.type
        beq   @ThreeMHz
@OneMHz lda   #%10000010 ; reset counter to period and start countdown
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
        lda   #%10000110 ; reload period to counter and start countdown
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

 ; ----------------------------------------------------------------------------
 ; testReset
 ; ----------------------------------------------------------------------------

mplus.ut.timer.testReset
        ldd   #$DCBA
        std   map.MPLUS.TIMER
        tst   clock.type
        beq   @ThreeMHz
@OneMHz lda   #%10000010 ; reset counter to period and start countdown
        bra   >
@ThreeMHz
        lda   #%10000110 ; reset counter to period and start countdown
!       sta   map.MPLUS.CTRL
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
        cmpd  #$DCBA ; TODO egalement DCBE ?
        bne   >
        jmp   mplus.ut.timer.returnOK
!       jmp   mplus.ut.timer.returnKO

 ; ----------------------------------------------------------------------------
 ; testDAC
 ; ----------------------------------------------------------------------------

mplus.ut.state fcb 0

mplus.ut.testDAC
        _cart.setRam #map.RAM_OVER_CART+5 ; set ram over cartridge space (sample data)
        _firq.pcm.init                    ; bind pcm firq routine
        _irq.off
        jsr   dac.unmute
        jsr   dac.enable
        clr   mplus.ut.state

        _firq.pcm.freezePlay #samples.timpani,#508 ;  7046 hz - Low-Timpani  
        lda   mplus.ut.state
        bne   @ko
        _firq.pcm.freezePlay #samples.timpani,#417 ;  8584 hz - Mid-Timpani    
        lda   mplus.ut.state
        bne   @ko
        _firq.pcm.freezePlay #samples.timpani,#378 ;  9470 hz - Hi-Timpani   
        lda   mplus.ut.state
        bne   @ko
        andcc #%11111110 ; OK
        rts
@ko     orcc  #%00000001 ; KO
        rts

firq.pcm.sample.play
                                       ; [12] FIRQ (equivalent to pshs pc,cc | jmp $FFF6)
                                       ; [8]  ROM jmp to user address
        sta   @a                       ; [5]  backup register value
        lda   map.MPLUS.CTRL           ; [5]  FIRQ acknowledge by reading ctrl register
        ;bpl   @traperror1              ; [3]
@trap   ;lda   map.MPLUS.CTRL           ; [5]  OK, 1 for int_timer_ack at first read
        ;bmi   @traperror2              ; [3]  new test
                                       ;      OK, 0 for int_timer_ack
        lda   >$0000                   ; [5]  read sample byte
firq.pcm.sample equ *-2
        sta   map.DAC                  ; [5]  send byte to DAC
        bpl   @move                    ; [3]  skip if no end marker
@stop   lda   map.MPLUS.CTRL           ; --- [5] load ctrl register
        anda  #%11110111               ; --- [2] Bit 3: RW Timer - (F)IRQ enable (0=NO, 1=YES)
        sta   map.MPLUS.CTRL           ; --- [5] disable timer FIRQ
        bra   @exit                    ; --- [3] do not make any move in buffer
@move
        inc   firq.pcm.sample+1        ; [7]  move to next sample (LSB)
        bne   @exit                    ; [3]  skip if no LSB rollover
        inc   firq.pcm.sample          ; --- [7]  move to next sample (MSB)
@exit   lda   #0                       ; [2]  restore register value
@a      equ   *-1
        rti                            ; [6]  RTI (equivalent to puls pc,cc)
@traperror1
        pshs  d,x,y,u,dp
        _monitor.print  #mplus.ut.KO1
        puls  d,x,y,u,dp
        lda   #firq.pcm.END_MARKER
        sta   [firq.pcm.sample]
        sta   mplus.ut.state
        bra   @stop                    ; KO, 0 for int_timer_ack at first read
@traperror2
        pshs  d,x,y,u,dp
        _monitor.print  #mplus.ut.KO2
        puls  d,x,y,u,dp
        lda   #firq.pcm.END_MARKER
        sta   [firq.pcm.sample]
        sta   mplus.ut.state
        bra   @stop                    ; KO, 1 for int_timer_ack at second read

mplus.ut.KO1         fcs "int ack (0)"
mplus.ut.KO2         fcs "int ack (1)"

 ; ----------------------------------------------------------------------------
 ; testSN76489
 ; ----------------------------------------------------------------------------

page.vgc equ map.RAM_OVER_CART+5
mplus.ut.testSN76489.lock fcb 0

mplus.ut.testSN76489
        _irq.init
        _irq.setRoutine #mplus.ut.testSN76489.irq
        _irq.set50Hz
        lda   map.MPLUS.CTRL
        anda  #%11111110 ; TI clock enable
        sta   map.MPLUS.CTRL

        _cart.setRam #page.vgc
        _vgc.obj.play #page.vgc,#vgm.sn,#vgc.NO_LOOP,#mplus.ut.testSN76489.callback
        _irq.on
!       lda   mplus.ut.testSN76489.lock
        beq   <
        _sn76489.init
        lda   map.MPLUS.CTRL
        ora   #%00000001 ; TI clock disable
        sta   map.MPLUS.CTRL
        andcc #%11111110
        rts

mplus.ut.testSN76489.callback
        _irq.off
        lda   #1
        sta   mplus.ut.testSN76489.lock
        rts

mplus.ut.testSN76489.irq
        _cart.setRam #page.vgc
        _vgc.frame.play
        rts

 ; ----------------------------------------------------------------------------
 ; testYM2413
 ; ----------------------------------------------------------------------------

page.ymm equ map.RAM_OVER_CART+5
mplus.ut.testYM2413.lock fcb 0

mplus.ut.testYM2413
        _irq.init
        _irq.setRoutine #mplus.ut.testYM2413.irq
        _irq.set50Hz

        _cart.setRam #page.ymm
        _ymm.obj.play #page.ymm,#vgm.ym,#ymm.NO_LOOP,#mplus.ut.testYM2413.callback
        _irq.on
!       lda   mplus.ut.testYM2413.lock
        beq   <
        _ym2413.init
        andcc #%11111110
        rts

mplus.ut.testYM2413.callback
        _irq.off
        lda   #1
        sta   mplus.ut.testYM2413.lock
        rts

mplus.ut.testYM2413.irq
        _cart.setRam #page.ymm
        _ymm.frame.play
        rts

 ; ----------------------------------------------------------------------------
 ; testMIDI
 ; ----------------------------------------------------------------------------

mplus.ut.testMIDI
        tst   clock.type
        andcc #%11111110
        rts

 ; ----------------------------------------------------------------------------
 ; testMEA8000
 ; ----------------------------------------------------------------------------

; phonemes
;mplus.ut.testMEA8000
;        lda   #$38
;        ldx   #mea8000.phonemes
;        ldy   #lotr.txt
;        jsr   mea8000.phonemes.read
;        rts

mplus.ut.testMEA8000
        ldx   #harder.mea
        jsr   mea8000.digitalized.read
        rts

 ; ----------------------------------------------------------------------------
 ; Common subroutines
 ; ----------------------------------------------------------------------------

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

 ENDSECTION
