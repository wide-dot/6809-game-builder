map.MEA8000.D EXTERNAL ; DONN - data register
map.MEA8000.A EXTERNAL ; RCOM - command / status register
map.IRQPT EXTERNAL     ; IRQ vector
map.STATUS EXTERNAL    ; system status register
map.MC6846.TCR EXTERNAL ; timer control register

 SECTION code

; ============================================================================
; MEA8000 speech file player (interrupt driven)
; ============================================================================
; Same file format and protocol as mea8000.file.read, but the bytes are sent
; from the IRQ raised by the REQ pin (command $1B: ROE=1), so the CPU is free
; while the chip speaks. One byte per interrupt: after each byte REQ drops for
; up to 3 us and the level-triggered IRQ line follows it. The interrupt after
; the last byte of the dummy frame (the frame has started) sends STOP, which
; also disables the REQ pin, and clears the active flag.
;
; Takes over the IRQ vector and the 6846 timer interrupt for the duration of
; the file, like mea8000.phonemes.read.irq. Not reentrant.
; ----------------------------------------------------------------------------

mea8000.file.read.irq.pointer FDB 0 ; next byte to send
mea8000.file.read.irq.end     FDB 0 ; end of the file
mea8000.file.read.irq.active  FCB 0 ; 1 while a file is being sent

; ----------------------------------------------------------------------------
; mea8000.file.read.irq.start
; Start playing a speech file, returns at once.
; input: [X] address of the speech file
; ----------------------------------------------------------------------------
mea8000.file.read.irq.start
        pshs  d,x,u
        tst   mea8000.file.read.irq.active
        beq   >
        bsr   mea8000.file.read.irq.stop
!       ldd   ,x
        leau  d,x
        stu   mea8000.file.read.irq.end
        leau  4,x
        stu   mea8000.file.read.irq.pointer
        ldb   3,x                    ; starting pitch
        ; mask interrupts and take the vector
        lda   #0
        sta   map.MC6846.TCR         ; no timer interrupt
        lda   map.STATUS
        anda  #%11011111
        sta   map.STATUS
        orcc  #%00010000
        ldx   #mea8000.file.read.irq.handler
        stx   map.IRQPT
        ; STOP, pitch, then let REQ drive the interrupt line
        lda   #$1A
        sta   map.MEA8000.A
        stb   map.MEA8000.D
        inc   mea8000.file.read.irq.active
        andcc #%11101111
        lda   #$1B                   ; ROE=1: REQ on the pin, first interrupt follows
        sta   map.MEA8000.A
        puls  d,x,u,pc

; ----------------------------------------------------------------------------
; mea8000.file.read.irq.stop
; Stop at once (mutes the chip) and release the interrupt.
; ----------------------------------------------------------------------------
mea8000.file.read.irq.stop
        tst   mea8000.file.read.irq.active
        beq   @done
        clr   mea8000.file.read.irq.active
        orcc  #%00010000
        lda   #$1A                   ; STOP, REQ pin disabled
        sta   map.MEA8000.A
@done   rts

; ----------------------------------------------------------------------------
; mea8000.file.read.irq.wait
; Block until the file has been played.
; ----------------------------------------------------------------------------
mea8000.file.read.irq.wait
!       tst   mea8000.file.read.irq.active
        bne   <
        rts

; ----------------------------------------------------------------------------
; mea8000.file.read.irq.handler
; ----------------------------------------------------------------------------
mea8000.file.read.irq.handler
        lda   map.MEA8000.A          ; bit 7: the chip accepts a byte
        bmi   >
        rti                          ; not ours
!       tst   mea8000.file.read.irq.active
        bne   >
        rti
!       pshs  x
        ldx   mea8000.file.read.irq.pointer
        cmpx  mea8000.file.read.irq.end
        bhs   @done
        lda   ,x+
        sta   map.MEA8000.D
        stx   mea8000.file.read.irq.pointer
        puls  x
        rti
@done                                ; the dummy frame has started
        clr   mea8000.file.read.irq.active
        lda   #$1A                   ; STOP, REQ pin disabled: no more interrupts
        sta   map.MEA8000.A
        puls  x
        rti

 ENDSECTION
