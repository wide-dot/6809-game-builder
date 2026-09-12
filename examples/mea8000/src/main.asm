; ============================================================================
; MEA8000 playback, nothing else
; ============================================================================
; Says one sentence over and over on the speech synthesizer at $E7FE/$E7FF,
; with a pause between plays. No screen, no interrupt, no other sound chip:
; the smallest program that should talk on a TO8 with the Cedic-Nathan
; synthesizer (real or emulated).
;
; The data and the player are those of the period: the sentence is a sequence
; of Philips speech files (one per word group, the format of every Cedic-Nathan
; product), and the player has the shape of the one published with the
; Cedic-Nathan demonstrations. The player is written out here in full rather
; than included from the engine so that the whole program fits on one page.
; ----------------------------------------------------------------------------

        org   $6100

        INCLUDE "engine/system/to8/map.const.asm"

main
        orcc  #$50            ; polling only: no interrupt may steal cycles

@play   ldx   #speech         ; the sentence: speech files one after the other
@next   bsr   play            ; play one, X moves to the next
        cmpx  #speech.end
        blo   @next
        ldx   #3              ; about two seconds of silence between plays (no
                              ; blank line here: lwasm ends the local-label
                              ; scope on one)
@pause  ldy   #$FFFF
@inner  leay  -1,y            ; 11 cycles per turn
        bne   @inner
        leax  -1,x
        bne   @pause
        bra   @play

; ----------------------------------------------------------------------------
; play - play one speech file, the way the period player does
; ----------------------------------------------------------------------------
; STOP once, the starting pitch, then every byte of the frames after a REQ
; poll. No STOP at the end: the last frame of a file has amplitude 0 (the
; "dummy frame" of Philips TP101 fig. 19), the chip fades on it and stops by
; itself 16 ms after it started; the routine waits for that before returning,
; so that the next file finds a chip at rest. A STOP sent at the dummy's
; start instead would race the chip's own clock: whether it lands before or
; after the chip's first sample of the frame depends on the CPU's timing, and
; the sound would differ from one machine to the next by a sample's state.
; Checked against MAME's synthesizer, sample for sample (2026-09-12).
; File: length (2 bytes, header included), free byte, starting pitch (Hz/2),
; then frames of 4 bytes.
;
; input:  [X] address of the speech file
; output: [X] address of the byte after the file (the next file of a stream)
; ----------------------------------------------------------------------------
play
        pshs  d,y,u
        ldd   ,x
        leau  d,x             ; U = end of file
        pshs  u               ; kept on the stack for the end test
        ldb   #map.MEA8000.STOP_SLOW
        stb   map.MEA8000.A   ; $1A: STOP, slow-stop procedure, REQ pin disabled
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
        tfr   u,x             ; X = the next file
        puls  d,y,u,pc
@wait   tst   map.MEA8000.A   ; REQ: bit 7 set when the chip accepts a byte
        bpl   @wait
        rts

; ----------------------------------------------------------------------------
; the sentence: "C'est peut-être le moment le plus important de notre débat
; parlementaire" (Mozilla Common Voice, clip common_voice_fr_17963678, CC0),
; encoded by the mea8000 encoder with its default thomson profile: eight
; speech files, 1888 bytes — samples/fr-female.mea of
; https://github.com/wide-dot/mea8000-encoder
; ----------------------------------------------------------------------------
speech
        includebin "src/fr-female.mea"
speech.end
