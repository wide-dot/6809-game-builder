samples.timpani              EXTERNAL

dac.ut.testDAC               EXPORT
dac.ut.testDAC.440Hz         EXPORT

        INCLUDE "engine/system/thomson/sound/dac.enable.asm"
        INCLUDE "engine/system/to8/sound/dac.mute.asm"

 SECTION code

        INCLUDE "engine/sound/firq.pcm.macro.asm"
        INCLUDE "engine/sound/firq.pcm.const.asm"

 ; ----------------------------------------------------------------------------
 ; testDAC
 ; ----------------------------------------------------------------------------

dac.ut.state fcb 0

dac.ut.testDAC
        _cart.setRam #map.RAM_OVER_CART+5 ; set ram over cartridge space (sample data)
        _firq.pcm.init                    ; bind pcm firq routine
        _irq.off
        jsr   dac.unmute
        jsr   dac.enable
        clr   dac.ut.state

        ldd   #samples.timpani
        std   dac.ut.dac.samplePtr
        ldd   #508
        std   dac.ut.dac.period
        lda   #1
        sta   dac.ut.dac.clockType
        jsr   dac.ut.dac.playWithTimeout
        lbcs  dac.ut.dac.testFailed     ; timeout occurred
        lda   dac.ut.state
        lbne  dac.ut.dac.testFailed
        ; Continue with next sample test
        ldd   #samples.timpani
        std   dac.ut.dac.samplePtr
        ldd   #417
        std   dac.ut.dac.period
        lda   #1
        sta   dac.ut.dac.clockType
        jsr   dac.ut.dac.playWithTimeout
        bcs   dac.ut.dac.testFailed     ; timeout occurred
        lda   dac.ut.state
        bne   dac.ut.dac.testFailed
        ; Continue with next sample test
        ldd   #samples.timpani
        std   dac.ut.dac.samplePtr
        ldd   #378
        std   dac.ut.dac.period
        lda   #1
        sta   dac.ut.dac.clockType
        jsr   dac.ut.dac.playWithTimeout
        bcs   dac.ut.dac.testFailed     ; timeout occurred
        lda   dac.ut.state
        bne   dac.ut.dac.testFailed
        ; Continue with next sample test
        ldd   #samples.timpani
        std   dac.ut.dac.samplePtr
        ldd   #142
        std   dac.ut.dac.period
        lda   #0
        sta   dac.ut.dac.clockType
        jsr   dac.ut.dac.playWithTimeout
        bcs   dac.ut.dac.testFailed     ; timeout occurred
        lda   dac.ut.state
        bne   dac.ut.dac.testFailed
        ; Continue with next sample test
        ldd   #samples.timpani
        std   dac.ut.dac.samplePtr
        ldd   #116
        std   dac.ut.dac.period
        lda   #0
        sta   dac.ut.dac.clockType
        jsr   dac.ut.dac.playWithTimeout
        bcs   dac.ut.dac.testFailed     ; timeout occurred
        lda   dac.ut.state
        bne   dac.ut.dac.testFailed
        ; Continue with final sample test
        ldd   #samples.timpani
        std   dac.ut.dac.samplePtr
        ldd   #106
        std   dac.ut.dac.period
        lda   #0
        sta   dac.ut.dac.clockType
        jsr   dac.ut.dac.playWithTimeout
        bcs   dac.ut.dac.testFailed     ; timeout occurred
        lda   dac.ut.state
        bne   dac.ut.dac.testFailed
        ; All tests passed
        andcc #%11111110 ; OK
        rts

dac.ut.dac.testFailed
        orcc  #%00000001 ; KO
        rts

 ; ----------------------------------------------------------------------------
 ; testDAC.440Hz - Generate 440Hz square wave using Thomson TO8 internal DAC
 ; ----------------------------------------------------------------------------

dac.ut.testDAC.440Hz
        ; Flush keyboard buffer to prevent immediate termination
@flushKeyboard
        jsr   map.KTST                 ; Test if a key is in buffer
        bcc   @keyboardFlushed         ; No key, buffer is empty
        jsr   map.GETC                 ; Read and discard the key
        bra   @flushKeyboard           ; Check for more keys
@keyboardFlushed

        ; Enable the Thomson TO8 DAC
        jsr   dac.unmute
        jsr   dac.enable
        
        ; Calculate timing for 440Hz square wave
        ; Target: 440Hz square wave with 1MHz CPU clock
        ; Period = 1,000,000 ÷ 440 = 2272.7 cycles per complete cycle
        ; Half-cycle = 2272.7 ÷ 2 = 1136.4 cycles per half-cycle
        ; 
        ; Instruction overhead per half-cycle:
        ; lda #$XX (2) + sta map.DAC (4) + ldx #140 (3) + loop overhead (~10) = ~19 cycles
        ; Available for delay: 1136 - 19 = 1117 cycles
        ; Loop: leax -1,x (5) + bne (3) = 8 cycles per iteration
        ; Required iterations: 1117 ÷ 8 = 139.6 ≈ 140 iterations
        
        ; Display message to user
        _monitor.print #dac.ut.dac440Hz.pressKey
        
        ; Square wave generation loop
@squareWaveLoop
        ; Generate one complete 440Hz cycle (high + low)
        ; High phase: Set DAC to maximum value ($3F)
        lda   #$3F                      ; [2] Maximum DAC value (6-bit DAC)
        sta   map.DAC                   ; [4] Set DAC high
        ; Timing delay for half cycle at 440Hz (1136 cycles total)
        ldx   #140                      ; [3] 140 iterations × 8 cycles = 1120 cycles + overhead = ~1136 cycles
@highDelay
        leax  -1,x                      ; [5] Decrement counter
        bne   @highDelay                ; [3] Loop (3 cycles when taken, 2 when not taken)
        ; Low phase: Set DAC to minimum value ($00)
        lda   #$00                      ; [2] Minimum DAC value
        sta   map.DAC                   ; [4] Set DAC low
        ; Timing delay for second half cycle (identical timing for symmetrical square wave)
        ldx   #140                      ; [3] Same delay for symmetrical square wave
@lowDelay
        leax  -1,x                      ; [5] Decrement counter
        bne   @lowDelay                 ; [3] Loop (3 cycles when taken, 2 when not taken)
        bra   @squareWaveLoop           ; Continue until key pressed
        ; this test never ends ;-)

; Play sample with 10 second timeout
; Parameters: dac.ut.dac.samplePtr, dac.ut.dac.period, dac.ut.dac.clockType (set before calling)
; Returns: Carry set = timeout, Carry clear = completed normally
dac.ut.dac.playWithTimeout
        ldd   dac.ut.dac.samplePtr
        std   firq.pcm.sample
        ldd   dac.ut.dac.period
        std   map.MPLUS.TIMER
        lda   dac.ut.dac.clockType
        beq   dac.ut.dac.use1MHz
        lda   #%10011110     ; 3.579545MHz clock (bit 2 = 1)
        bra   dac.ut.dac.startTimer
dac.ut.dac.use1MHz
        lda   #%10011010     ; 1MHz clock (bit 2 = 0)
dac.ut.dac.startTimer
        sta   map.MPLUS.CTRL
        andcc #%10111111     ; unmask firq
        ; Using nested loops: outer * inner * cycles_per_inner_loop
        ; 200 * 1000 * 17 = 3,400,000 cycles ≈ 3.4 seconds
        ldy   #200           ; Outer loop counter (3.4 second timeout)
dac.ut.dac.waitOuter
        ldx   #1000          ; Inner loop counter
dac.ut.dac.waitInner
        ; Simple check like original blocking macro - just test bit 7
        lda   [firq.pcm.sample]  ; [6] Check current sample byte
        bmi   dac.ut.dac.completed  ; [3] Sample finished (bit 7 = 1)
        leax  -1,x               ; [5] Decrement inner counter  
        bne   dac.ut.dac.waitInner  ; [3] Continue inner loop
                                 ; Total inner loop: 6+3+5+3 = 17 cycles per iteration
        leay  -1,y               ; Decrement outer counter
        bne   dac.ut.dac.waitOuter  ; Continue outer loop
        ; Timeout reached - stop FIRQ and return error
        lda   map.MPLUS.CTRL
        anda  #%11110111         ; Disable timer FIRQ
        sta   map.MPLUS.CTRL
        orcc  #%00000001 ; KO
        rts
        
dac.ut.dac.completed
        andcc #%11111110 ; OK
        rts

; DAC test global variables
dac.ut.dac.samplePtr  fdb   0
dac.ut.dac.period     fdb   0  
dac.ut.dac.clockType  fcb   0

firq.pcm.sample.play
                                       ; [12] FIRQ (equivalent to pshs pc,cc | jmp $FFF6)
                                       ; [8]  ROM jmp to user address
        sta   firq.pcm.regBackup       ; [5]  backup register value
        lda   map.MPLUS.CTRL           ; [5]  FIRQ acknowledge by reading ctrl register
        ;bpl   firq.pcm.trapError1     ; [3]
firq.pcm.trap   
        ;lda   map.MPLUS.CTRL          ; [5]  OK, 1 for int_timer_ack at first read
        ;bmi   firq.pcm.trapError2     ; [3]  new test
                                       ;      OK, 0 for int_timer_ack
        lda   >$0000                   ; [5]  read sample byte
firq.pcm.sample equ *-2
        sta   map.DAC                  ; [5]  send byte to DAC
        bpl   firq.pcm.move            ; [3]  skip if no end marker
firq.pcm.stop   
        lda   map.MPLUS.CTRL           ; --- [5] load ctrl register
        anda  #%11110111               ; --- [2] Bit 3: RW Timer - (F)IRQ enable (0=NO, 1=YES)
        sta   map.MPLUS.CTRL           ; --- [5] disable timer FIRQ
        bra   firq.pcm.exit            ; --- [3] do not make any move in buffer
firq.pcm.move
        inc   firq.pcm.sample+1        ; [7]  move to next sample (LSB)
        bne   firq.pcm.exit            ; [3]  skip if no LSB rollover
        inc   firq.pcm.sample          ; --- [7]  move to next sample (MSB)
firq.pcm.exit   
        lda   #0                       ; [2]  restore register value
firq.pcm.regBackup equ *-1
        rti                            ; [6]  RTI (equivalent to puls pc,cc)
firq.pcm.trapError1
        pshs  d,x,y,u,dp
        _monitor.print  #dac.ut.KO1
        puls  d,x,y,u,dp
        lda   #firq.pcm.END_MARKER
        sta   [firq.pcm.sample]
        sta   dac.ut.state
        bra   firq.pcm.stop            ; KO, 0 for int_timer_ack at first read
firq.pcm.trapError2
        pshs  d,x,y,u,dp
        _monitor.print  #dac.ut.KO2
        puls  d,x,y,u,dp
        lda   #firq.pcm.END_MARKER
        sta   [firq.pcm.sample]
        sta   dac.ut.state
        bra   firq.pcm.stop            ; KO, 1 for int_timer_ack at second read

dac.ut.KO1         fcs "int ack (0)"
dac.ut.KO2         fcs "int ack (1)"

; DAC test messages
dac.ut.dac440Hz.pressKey fcc "Playing DAC 440Hz square wave - Reboot to stop..."
                         _monitor.str.CRLF

 ENDSECTION 