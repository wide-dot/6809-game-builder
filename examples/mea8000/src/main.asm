; ============================================================================
; MEA8000 playback, nothing else
; ============================================================================
; Plays one speech file (Philips / Cedic-Nathan format) over and over on the
; speech synthesizer at $E7FE/$E7FF, with a pause between plays. No screen, no
; interrupt, no other sound chip: the smallest program that should talk on a
; TO8 with the Cedic-Nathan synthesizer (real or emulated).
;
; The player is written out here in full rather than included from the engine
; so that the whole program fits on one page.
; ----------------------------------------------------------------------------

        org   $6100

        INCLUDE "engine/system/to8/map.const.asm"

main
        orcc  #$50            ; polling only: no interrupt may steal cycles

@play   ldx   #speech         ; the stream is a sequence of speech files
@next   bsr   play            ; (one per utterance): play them in turn
        cmpx  #speech.end
        blo   @next
        ldx   #3              ; about one and a half seconds of silence (no blank
                              ; line here: lwasm ends the local-label scope on one)
@pause  ldy   #$FFFF
@inner  leay  -1,y            ; 8 cycles per turn
        bne   @inner
        leax  -1,x
        bne   @pause
        bra   @play

; ----------------------------------------------------------------------------
; play - play one speech file (TP101 fig. 19-20 and 28)
; ----------------------------------------------------------------------------
; File: length (2 bytes, header included), free byte, starting pitch (Hz/2),
; then frames of 4 bytes; the last frame is the AMPL=0 dummy frame.
; Protocol: STOP, pitch, every frame, then STOP once the dummy frame has
; started. REQ (bit 7 of the status) is polled once per frame.
;
; input:  [X] address of the speech file
; output: [X] address of the byte after the file (the next file of a stream)
; ----------------------------------------------------------------------------
play
        pshs  d,u
        ldd   ,x
        leau  d,x             ; U = end of file
        ldb   #map.MEA8000.STOP_SLOW
        stb   map.MEA8000.A   ; $1A: STOP, slow-stop procedure, REQ pin disabled
        ldb   3,x             ; starting pitch (the free byte at 2,x is skipped)
        leax  4,x
        stb   map.MEA8000.D
@frame  stu   @end
        cmpx  #0
@end    equ   *-2
        bhs   @last
        bsr   @wait
        ldd   ,x++
        sta   map.MEA8000.D
        stb   map.MEA8000.D
        ldd   ,x++
        sta   map.MEA8000.D
        stb   map.MEA8000.D
        bra   @frame
@last   bsr   @wait           ; the dummy frame has started: stop now
        ldb   #map.MEA8000.STOP_SLOW
        stb   map.MEA8000.A
        tfr   u,x             ; X = end of the file
        puls  d,u,pc
@wait   tst   map.MEA8000.A   ; REQ: bit 7 set when the chip accepts a byte
        bpl   @wait
        rts

; ----------------------------------------------------------------------------
; the speech stream: Philips speech files, one per utterance, back to back
; (produced by the mea8000 encoder from the Goldorak line, no frame merging)
; ----------------------------------------------------------------------------
speech
        includebin "src/goldorak-01.mea"
speech.end
