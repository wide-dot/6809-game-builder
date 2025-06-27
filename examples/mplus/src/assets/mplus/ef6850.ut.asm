ef6850.ut.testMIDI           EXPORT
ef6850.ut.detectEF6850       EXPORT

 SECTION code

 ; ----------------------------------------------------------------------------
 ; testMIDI
 ; ----------------------------------------------------------------------------

; MIDI test data buffer
ef6850.ut.midi.testData
        fcb   $90,$60,$7F,$80,$60,$40,$B0,$07,$64  ; Note On/Off + Control Change
        fcb   $C0,$01,$F0,$43,$12,$7F,$F7          ; Program Change + SysEx
ef6850.ut.midi.testDataSize equ *-ef6850.ut.midi.testData   ; Calculate size (15 bytes)

ef6850.ut.midi.rxBuffer fill  0,ef6850.ut.midi.testDataSize     ; Receive buffer (testDataSize bytes)
ef6850.ut.midi.rxCount  fcb   0                               ; Number of bytes received
ef6850.ut.midi.txIndex  fcb   0                               ; Current transmission index
ef6850.ut.midi.firqCount fcb  0                               ; FIRQ counter for factory test

ef6850.ut.testMIDI
        ; Test EF6850 ACIA presence before running MIDI test
        jsr   ef6850.ut.detectEF6850
        bcc   @ef6850Present            ; Carry clear = EF6850 detected
        ; EF6850 not present - display message and skip test
        _monitor.print #ef6850.ut.notDetected
        andcc #%11111110 ; OK
        rts
@ef6850Present
        _monitor.print #ef6850.ut.detected
        _monitor.print #main.str.CRLF
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
        clr   ef6850.ut.midi.rxCount
        clr   ef6850.ut.midi.txIndex
        clr   ef6850.ut.midi.firqCount
        ;
        ; Clear receive buffer
        ldx   #ef6850.ut.midi.rxBuffer
        ldb   #ef6850.ut.midi.testDataSize
@clear  clr   ,x+
        decb
        bne   @clear
        ;
        ; Set up FIRQ handler
        ldd   #ef6850.ut.midi.firqHandler
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
@wait   lda   ef6850.ut.midi.rxCount       ; [5] Load direct extended - Get received bytes count
        cmpa  #ef6850.ut.midi.testDataSize ; [2] Compare immediate - Check against expected size
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
        lda   ef6850.ut.midi.firqCount
        cmpa  #ef6850.ut.midi.testDataSize*2  ; Should have both RX and TX interrupts
        blo   @ko                      ; FIRQ test failed
        ;
        ; Verify data integrity
        ldx   #ef6850.ut.midi.testData  ; Source data
        ldy   #ef6850.ut.midi.rxBuffer  ; Received data
        lda   #ef6850.ut.midi.testDataSize
@verify ldb   ,x+
        cmpb  ,y+
        bne   @ko
        deca
        bne   @verify
        ;
        jmp   ef6850.ut.returnOK
@ko     jmp   ef6850.ut.returnKO
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
ef6850.ut.midi.firqHandler
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
        inc   ef6850.ut.midi.firqCount  ; Count RX interrupt
        ldb   map.EF6850.RX            ; Read received byte (clears RDRF)
        ; Store in receive buffer
        ldx   #ef6850.ut.midi.rxBuffer
        lda   ef6850.ut.midi.rxCount
        stb   a,x                      ; Store received byte
        inc   ef6850.ut.midi.rxCount
        pshs  b
        jsr   monitor.printHex8
        _monitor.putc #ascii.SPACE
        puls  b
        bra   @exit
        ;
@handleTx
        ; Handle transmission (TDRE=1)
        inc   ef6850.ut.midi.firqCount  ; Count TX interrupt
        ; Get current byte to transmit
        ldx   #ef6850.ut.midi.testData
        lda   ef6850.ut.midi.txIndex
        cmpa  #ef6850.ut.midi.testDataSize  ; Check if all data transmitted
        beq   @endTransmission         ; End of data reached
        ldb   a,x                      ; Get byte at index
        stb   map.EF6850.TX            ; Send byte (clears TDRE)
        inc   ef6850.ut.midi.txIndex
        bra   @exit
        ;
@endTransmission
        ; Disable TX interrupts when done
        lda   #map.EF6850.MIDI|map.EF6850.TX_OFF|map.EF6850.RX_ON
        sta   map.EF6850.CTRL
        ;
@exit   puls  d,x,y
        rti

; EF6850 Detection Routine
; Test if EF6850 ACIA is present by checking if registers respond to writes
; output: Carry flag: 0=present, 1=not present
ef6850.ut.detectEF6850
        pshs  d,x
        lda   #%00000011                ; Master reset command (CR1-0=11)
        sta   map.EF6850.CTRL           ; Send master reset
        lda   map.EF6850.CTRL           ; Read status after reset
        bne   @notPresent
        lda   #map.EF6850.MIDI          ; Normal MIDI configuration ($15)
        sta   map.EF6850.CTRL           ; Configure ACIA
        lda   map.EF6850.CTRL           ; Read status
        cmpa  #2
        bne   @notPresent
        lda   #%00000011                ; Master reset command (CR1-0=11)
        sta   map.EF6850.CTRL           ; Send master reset
        lda   map.EF6850.CTRL           ; Read status after reset
@aciaPresent
        andcc #$FE                      ; Clear carry = present
        puls  d,x,pc
@notPresent
        orcc  #$01                      ; Set carry = not present
        puls  d,x,pc

 ; ----------------------------------------------------------------------------
 ; Common subroutines
 ; ----------------------------------------------------------------------------

ef6850.ut.returnOK
        _monitor.putc #ascii.SPACE
        andcc #%11111110 ; OK
        rts

ef6850.ut.returnKO
        _monitor.putc #ascii.SPACE
        orcc  #%00000001 ; KO
        rts

ef6850.ut.notDetected fcs "UNDETECTED "
ef6850.ut.detected fcs "DETECTED "

 ENDSECTION 