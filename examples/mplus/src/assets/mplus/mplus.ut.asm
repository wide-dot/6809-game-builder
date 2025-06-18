samples.timpani              EXTERNAL
vgm.ym                       EXTERNAL
vgm.sn                       EXTERNAL
lotr.txt                     EXTERNAL

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
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/controller/ascii.const.asm"

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

        _firq.pcm.blockingPlay #samples.timpani,#508,1 ;  7046 hz - Low-Timpani  
        lda   mplus.ut.state
        lbne   @ko
        _firq.pcm.blockingPlay #samples.timpani,#417,1 ;  8584 hz - Mid-Timpani    
        lda   mplus.ut.state
        bne   @ko
        _firq.pcm.blockingPlay #samples.timpani,#378,1 ;  9470 hz - Hi-Timpani   
        lda   mplus.ut.state
        bne   @ko
        _firq.pcm.blockingPlay #samples.timpani,#142,0 ;  7046 hz - Low-Timpani  
        lda   mplus.ut.state
        bne   @ko
        _firq.pcm.blockingPlay #samples.timpani,#116,0 ;  8584 hz - Mid-Timpani    
        lda   mplus.ut.state
        bne   @ko
        _firq.pcm.blockingPlay #samples.timpani,#106,0 ;  9470 hz - Hi-Timpani   
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

; MIDI test data buffer
mplus.ut.midi.testData
        fcb   $90,$60,$7F,$80,$60,$40,$B0,$07,$64  ; Note On/Off + Control Change
        fcb   $C0,$01,$F0,$43,$12,$7F,$F7          ; Program Change + SysEx
mplus.ut.midi.testDataSize equ *-mplus.ut.midi.testData   ; Calculate size (15 bytes)

mplus.ut.midi.rxBuffer fill  0,mplus.ut.midi.testDataSize     ; Receive buffer (testDataSize bytes)
mplus.ut.midi.rxCount  fcb   0                               ; Number of bytes received
mplus.ut.midi.txIndex  fcb   0                               ; Current transmission index
mplus.ut.midi.firqCount fcb  0                               ; FIRQ counter for factory test

mplus.ut.testMIDI
        ; Phase 1: Synchronous loopback test
        ; -----------------------------
        orcc  #%01000000               ; mask FIRQ during setup
        ;
        ; Reset MIDI controller
        lda   #$03
        sta   map.EF6850.CTRL          ; MIDI.CTRL - reset midi controller
        lda   #map.EF6850.MIDI|map.EF6850.TX_OFF|map.EF6850.RX_OFF
        sta   map.EF6850.CTRL          ; MIDI.CTRL - no interrupts for sync test
        ;
        _monitor.print #main.str.SYNC
        ;
        ; Send Note On message byte by byte with immediate readback
        lda   #$90                     ; Note On status byte
        jsr   @sendReadByte
        cmpb  #$90                     ; Verify received byte
        bne   @ko
        ;
        lda   #$40                     ; Note 64 (E4)
        jsr   @sendReadByte
        cmpb  #$40                     ; Verify received byte
        bne   @ko
        ;
        lda   #$7F                     ; Velocity 127
        jsr   @sendReadByte
        cmpb  #$7F                     ; Verify received byte
        bne   @ko
        ;
        ; Phase 2: Asynchronous FIRQ test
        ; -----------------------------
        _monitor.print #main.str.OK
        _monitor.print #main.str.CRLF
        _monitor.print #main.str.ASYNC
        ;
        ; Clear counters for async test
        clr   mplus.ut.midi.rxCount
        clr   mplus.ut.midi.txIndex
        clr   mplus.ut.midi.firqCount
        ;
        ; Clear receive buffer
        ldx   #mplus.ut.midi.rxBuffer
        ldb   #mplus.ut.midi.testDataSize
@clear  clr   ,x+
        decb
        bne   @clear
        ;
        ; Set up FIRQ handler
        ldd   #mplus.ut.midi.firqHandler
        std   map.FIRQPT
        ;
        ; Enable FIRQ and start transmission
        andcc #%10111111               ; unmask FIRQ
        lda   #map.EF6850.MIDI|map.EF6850.TX_ON|map.EF6850.RX_ON
        sta   map.EF6850.CTRL          ; Enable both TX and RX interrupts
        ;
        ; Wait for all data with timeout
        ; Total loop time = 18 cycles per iteration
        ; 768 iterations = 13,824 cycles = ~13.8ms at 1MHz
        ldx   #$0300
@wait   lda   mplus.ut.midi.rxCount       ; [5] Load direct extended - Get received bytes count
        cmpa  #mplus.ut.midi.testDataSize ; [2] Compare immediate - Check against expected size
        beq   @rxComplete                 ; [3] Branch if equal (not taken)
        leax  -1,x                        ; [5] Decrement index register - Update timeout counter
        bne   @wait                       ; [3] Branch if not equal (taken = 3, not taken = 1)
                                          ; Total: 5+2+3+5+3 = 18 cycles per iteration
@rxComplete
        ;
        ; Disable FIRQ and restore
        orcc  #%01000000               ; mask FIRQ
        lda   #map.EF6850.MIDI|map.EF6850.TX_OFF|map.EF6850.RX_OFF
        sta   map.EF6850.CTRL
        ;
        ; FACTORY TEST: Validate FIRQ was used
        lda   mplus.ut.midi.firqCount
        cmpa  #mplus.ut.midi.testDataSize*2  ; Should have both RX and TX interrupts
        blo   @ko                      ; FIRQ test failed
        ;
        ; Verify data integrity
        ldx   #mplus.ut.midi.testData  ; Source data
        ldy   #mplus.ut.midi.rxBuffer  ; Received data
        lda   #mplus.ut.midi.testDataSize
@verify ldb   ,x+
        cmpb  ,y+
        bne   @ko
        deca
        bne   @verify
        ;
        jmp   mplus.ut.returnOK
@ko     jmp   mplus.ut.returnKO
        ;
        ; Subroutine: Send byte in A, read back in B with timeout
@sendReadByte
        sta   map.EF6850.TX            ; Send byte
        ldx   #$1000                   ; Timeout counter
@waitRx lda   map.EF6850.CTRL
        bita  #map.EF6850.STAT_RDRF    ; Check RDRF
        bne   @readOK
        leax  -1,x
        bne   @waitRx
        ldb   #$FF                     ; Error marker
        rts
@readOK ldb   map.EF6850.RX
        pshs  b
        jsr   monitor.printHex8
        _monitor.putc #ascii.SPACE
        puls  b
        rts

main.str.SYNC  fcs "- SYNC ............ "
main.str.ASYNC fcs "- FIRQ ............ "

; FIRQ Handler for MIDI transmission with TX/RX synchronization
; Factory test implementation - FIRQ MANDATORY for validation
; suboptimal implementation, for production implementation see engine's midi asm
mplus.ut.midi.firqHandler
        ; Save ALL registers used
        pshs  d,x,y
        
        ; Read status register and check interrupt source
        lda   map.EF6850.CTRL          ; Read status register
        bita  #map.EF6850.STAT_RDRF    ; Check if RX data available
        bne   @handleRx                ; Yes -> handle reception
        bita  #map.EF6850.STAT_TDRE    ; Check if TX buffer empty
        bne   @handleTx                ; Yes -> handle transmission
        bra   @exit                    ; No request -> exit
        ;
@handleRx
        ; Handle reception (RDRF=1)
        inc   mplus.ut.midi.firqCount  ; Count RX interrupt
        ldb   map.EF6850.RX            ; Read received byte (clears RDRF)
        ; Store in receive buffer
        ldx   #mplus.ut.midi.rxBuffer
        lda   mplus.ut.midi.rxCount
        stb   a,x                      ; Store received byte
        inc   mplus.ut.midi.rxCount
        pshs  b
        jsr   monitor.printHex8
        _monitor.putc #ascii.SPACE
        puls  b
        bra   @exit
        ;
@handleTx
        ; Handle transmission (TDRE=1)
        inc   mplus.ut.midi.firqCount  ; Count TX interrupt
        ; Get current byte to transmit
        ldx   #mplus.ut.midi.testData
        lda   mplus.ut.midi.txIndex
        cmpa  #mplus.ut.midi.testDataSize  ; Check if all data transmitted
        beq   @endTransmission         ; End of data reached
        ldb   a,x                      ; Get byte at index
        stb   map.EF6850.TX            ; Send byte (clears TDRE)
        inc   mplus.ut.midi.txIndex
        bra   @exit
        ;
@endTransmission
        ; Disable TX interrupts when done
        lda   #map.EF6850.MIDI|map.EF6850.TX_OFF|map.EF6850.RX_ON
        sta   map.EF6850.CTRL
        ;
@exit   puls  d,x,y
        rti

 ; ----------------------------------------------------------------------------
 ; testMEA8000
 ; ----------------------------------------------------------------------------

page.mea equ map.RAM_OVER_CART+7

; phonemes
mplus.ut.testMEA8000
        _cart.setRam #page.mea
        lda   #$38
        ldx   #mea8000.phonemes
        ldy   #lotr.txt
        jsr   mea8000.phonemes.read
        rts

 ; ----------------------------------------------------------------------------
 ; Common subroutines
 ; ----------------------------------------------------------------------------

mplus.ut.timer.returnOK
        jsr   monitor.printHex16
mplus.ut.returnOK
        _monitor.putc #ascii.SPACE
        andcc #%11111110 ; OK
        rts

mplus.ut.timer.returnKO
        jsr   monitor.printHex16
mplus.ut.returnKO
        _monitor.putc #ascii.SPACE
        orcc  #%00000001 ; KO
        rts

 ENDSECTION
