map.MEA8000.D EXTERNAL ; DATA register
map.MEA8000.A EXTERNAL ; COMMAND register
map.IRQPT EXTERNAL ; Timer IRQ vector address
map.STATUS EXTERNAL ; System status register
map.MC6846.CSR EXTERNAL ; Timer control/status register

 SECTION code

; ============================================================================
; MEA8000 Phonemes IRQ-based asynchronous reader
; ============================================================================
; Asynchronous variant of mea8000.phonemes.read using interrupts
; to free the CPU during voice synthesis
; ============================================================================

; Global variables for interrupt mode
mea8000.phonemes.read.irq.phonemePointer   FDB 0     ; Current pointer in phoneme table
mea8000.phonemes.read.irq.textPointer      FDB 0     ; Current pointer in text to read
mea8000.phonemes.read.irq.phoneticPointer  FDB 0     ; Current pointer in phoneme data
mea8000.phonemes.read.irq.byteCounter      FCB 0     ; Remaining byte counter for current phoneme
mea8000.phonemes.read.irq.activeFlag       FCB 0     ; Flag: synthesis in progress
mea8000.phonemes.read.irq.tonality         FCB 0     ; Initial tonality value

; ============================================================================
; mea8000.phonemes.read.irq.startReading
; Start asynchronous reading of phoneme list with IRQ
; input: [A] tonality
; input: [X] addr of phonemes 3.3 lookup
; input: [Y] addr of txt to read
; output: Returns immediately, synthesis continues in background
; ============================================================================
mea8000.phonemes.read.irq.startReading
        pshs  d,x,y
        
        ; Check if synthesis is already in progress
        tst   mea8000.phonemes.read.irq.activeFlag
        beq   >
        jsr   mea8000.phonemes.read.irq.stopReading
!       sta   mea8000.phonemes.read.irq.tonality
        stx   mea8000.phonemes.read.irq.phonemePointer
        sty   mea8000.phonemes.read.irq.textPointer
        ; Initialize byteCounter to 0 (will load first phoneme)
        clr   mea8000.phonemes.read.irq.byteCounter
        inc   mea8000.phonemes.read.irq.activeFlag
        ; Disable IRQ first
        lda   #0         ; disable timer
        sta   map.MC6846.TCR
        lda   map.STATUS
        anda  #%11011111 ; disable status register
        sta   map.STATUS
        orcc  #%00010000 ; disable interrupts
        ldx   #mea8000.phonemes.read.irq.irqHandler
        stx   map.IRQPT ; install new IRQ vector

        ; Initialize MEA8000 with tonality BEFORE enabling IRQ
        lda   #map.MEA8000.STOP_SLOW
        sta   map.MEA8000.A
        lda   mea8000.phonemes.read.irq.tonality
        sta   map.MEA8000.D

        ; Enable IRQ first
        andcc #%11101111

        ; Configure MEA8000 in interrupt mode (will immediately trigger IRQ)
        lda   #map.MEA8000.INTERRUPT_MODE
        sta   map.MEA8000.A
        puls  d,x,y,pc

; ============================================================================
; mea8000.phonemes.read.irq.stopReading
; Stop current voice synthesis and restore previous state
; ============================================================================
mea8000.phonemes.read.irq.stopReading
        ; Check if already stopped
        tst   mea8000.phonemes.read.irq.activeFlag
        beq   @already_stopped
        ; Mark as inactive
        clr   mea8000.phonemes.read.irq.activeFlag
        ; Mask IRQ
        orcc  #%00010000
        ; Stop MEA8000 and restore polling mode
        lda   #map.MEA8000.STOP_SLOW
        sta   map.MEA8000.A
@already_stopped
        rts

; ============================================================================
; mea8000.phonemes.read.irq.irqHandler
; IRQ interrupt handler for MEA8000
; Called automatically when MEA8000 is ready to receive data
; ============================================================================
mea8000.phonemes.read.irq.irqHandler
        lda   map.MEA8000.A          ; Read STATUS (acquits MEA8000 IRQ)
        bmi   >
        rti                          ; Not our IRQ, exit immediately
!       tst   mea8000.phonemes.read.irq.activeFlag
        bne   >
        rti                          ; MEA8000 IRQ but synthesis not active
!       ; Save registers for MEA8000 IRQ processing
        pshs  d,x,y,u
        ; Direct phoneme handling (no state machine needed)
@handle_phoneme
        tst   mea8000.phonemes.read.irq.byteCounter
        beq   @load_next_phoneme
        ; Send current phoneme byte
        ldx   mea8000.phonemes.read.irq.phoneticPointer
        lda   ,x+
        sta   map.MEA8000.D
        stx   mea8000.phonemes.read.irq.phoneticPointer
        dec   mea8000.phonemes.read.irq.byteCounter
        puls  d,x,y,u
        rti
@load_next_phoneme
        ldy   mea8000.phonemes.read.irq.textPointer
        lda   ,y+
        bpl   >
        ; End of text reached - disable interrupt mode and stop synthesis
        lda   #map.MEA8000.STOP_SLOW     ; Disable ROE (back to polling mode)
        sta   map.MEA8000.A
        jsr   mea8000.phonemes.read.irq.stopReading
        puls  d,x,y,u
        rti
!       sty   mea8000.phonemes.read.irq.textPointer
        lsla
        ldx   mea8000.phonemes.read.irq.phonemePointer
        ldu   a,x
        lda   ,u+
        stu   mea8000.phonemes.read.irq.phoneticPointer
        sta   mea8000.phonemes.read.irq.byteCounter
        beq   @load_next_phoneme
        lda   ,u+
        sta   map.MEA8000.D
        stu   mea8000.phonemes.read.irq.phoneticPointer
        dec   mea8000.phonemes.read.irq.byteCounter
        puls  d,x,y,u
        rti

; ============================================================================
; mea8000.phonemes.read.irq.waitComplete
; Wait for end of voice synthesis (blocking version)
; Useful for synchronizing with end of synthesis
; ============================================================================
mea8000.phonemes.read.irq.waitComplete
@wait_loop
        tst   mea8000.phonemes.read.irq.activeFlag
        bne   @wait_loop
        rts

 ENDSECTION 