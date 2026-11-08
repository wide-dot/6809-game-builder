map.MEA8000.D EXTERNAL ; DONN - data register
map.MEA8000.A EXTERNAL ; RCOM - command / status register

 SECTION code

; ============================================================================
; MEA8000 speech file player (polling)
; ============================================================================
; Plays one speech file in the Philips / Cedic-Nathan format (TP101 p. 14):
;   length   : 2 bytes, the whole file including this header
;   free     : 1 byte, application data (Cedic phoneme sets repeat the pitch)
;   pitch    : 1 byte, starting pitch (Hz / 2)
;   frames   : 4 bytes each; frames with AMPL=0 are silence; the last frame is
;              the AMPL=0 dummy frame that lets the previous one play to its end
; Protocol, the period player's: STOP, pitch, every byte after a REQ poll, and
; no STOP at the end - the chip fades on the dummy frame and stops by itself
; 16 ms after it started; the routine waits for that before returning. A STOP
; sent as the dummy frame starts would race the chip's own clock, and the
; chip's state would differ from one machine to the next.
; Blocking: returns when the file has been played and the chip is at rest.
;
; input: [X] address of the speech file
; ----------------------------------------------------------------------------
mea8000.file.read
        pshs  d,x,y,u
        ldd   ,x
        leau  d,x             ; U = end of file
        pshs  u               ; kept on the stack for the end test
        ldb   #$1A
        stb   map.MEA8000.A   ; STOP, slow-stop procedure, REQ pin disabled
        ldb   3,x             ; starting pitch (the free byte at 2,x is skipped)
        leax  4,x
        stb   map.MEA8000.D   ; accepted at once: the chip is stopped
@byte   cmpx  ,s              ; end of the file?
        bhs   @done
        bsr   @wait
        lda   ,x+
        sta   map.MEA8000.D
        bra   @byte
@done   bsr   @wait           ; the dummy frame has started
        ldy   #3000           ; 24 ms (8 cycles per turn at 1 MHz): it plays
@settle leay  -1,y            ; 8 ms, the chip fades 8 ms more and stops
        bne   @settle
        leas  2,s
        puls  d,x,y,u,pc
@wait   tst   map.MEA8000.A   ; REQ: bit 7 set when the chip accepts a byte
        bpl   @wait
        rts

; ============================================================================
; MEA8000 vocabulary player (polling)
; ============================================================================
; Plays one file of a vocabulary image (TP101 fig. 27, the Cedic-Nathan demo
; cartridge and phoneme sets): a table of 16-bit offsets from the start of the
; image, ended by $FFFF, then the speech files.
; Blocking.
;
; input: [X] address of the vocabulary image
; input: [B] file number
; ----------------------------------------------------------------------------
mea8000.rom.read
        pshs  d,x
        clra
        lslb
        rola
        ldd   d,x
        leax  d,x
        bsr   mea8000.file.read
        puls  d,x,pc

 ENDSECTION
