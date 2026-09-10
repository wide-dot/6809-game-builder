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
; Protocol (TP101 fig. 19-20 and 28): STOP, pitch, every frame, then STOP once
; the dummy frame has started. REQ is polled once per frame only: the chip
; recovers within 3 us between the bytes of a frame, less than two stores.
; Blocking: returns when the file has been played.
;
; input: [X] address of the speech file
; ----------------------------------------------------------------------------
mea8000.file.read
        pshs  d,x,u
        ldd   ,x
        leau  d,x             ; U = end of file
        ldb   #$1A
        stb   map.MEA8000.A   ; STOP, slow-stop procedure, REQ pin disabled
        ldb   3,x             ; starting pitch (the free byte at 2,x is skipped)
        leax  4,x
        stb   map.MEA8000.D
@frame
        stu   @end
        cmpx  #0
@end    equ   *-2
        bhs   @last
        bsr   @wait           ; ready for the next frame (up to 8 ms after the
                              ; pitch, up to 64 ms after a frame)
        ldd   ,x++
        sta   map.MEA8000.D
        stb   map.MEA8000.D
        ldd   ,x++
        sta   map.MEA8000.D
        stb   map.MEA8000.D
        bra   @frame
@last
        bsr   @wait           ; the dummy frame has started: stop now
        ldb   #$1A
        stb   map.MEA8000.A
        puls  d,x,u,pc
@wait
        tst   map.MEA8000.A   ; bit 7 = REQ, 1 when the chip accepts a byte
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
