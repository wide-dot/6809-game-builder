; ============================================================================
; MEA8000 playback, nothing else
; ============================================================================
; Says one sentence over and over on the speech synthesizer at $E7FE/$E7FF,
; with a pause between plays: the smallest program that should talk on a TO8
; with the Cedic-Nathan synthesizer (real or emulated). No screen, no
; interrupt, no other sound chip.
;
; The sentence is a stream of Philips speech files (one per word group, the
; format of every Cedic-Nathan product), loaded as a block into its own RAM
; page and played by the engine's mea8000.stream.read through the cartridge
; window - the way a stream longer than a page is played, with one block here.
; Witnesses for the bench: $9C00 = $CA once running, $9C01 = plays completed.
; ----------------------------------------------------------------------------

 SECTION code

        INCLUDE "engine/system/to8/map.const.asm"

witness.magic equ $9C00
witness.plays equ $9C01

main
        orcc  #$50            ; polling only: no interrupt may steal cycles
        clr   witness.plays
        lda   #$CA
        sta   witness.magic
@play   ldx   #blocks
        jsr   mea8000.stream.read
        inc   witness.plays
        ldx   #3              ; about two seconds of silence between plays
@pause  ldy   #$FFFF
@inner  leay  -1,y
        bne   @inner
        leax  -1,x
        bne   @pause
        bra   @play

; the block table of mea8000.stream.read: the sentence is one block, page 5
blocks
        fcb   map.RAM_OVER_CART|$05
        fdb   $0000
        fdb   speech.SIZE
        fcb   0

 ENDSECTION

        INCLUDE "engine/system/thomson/sound/mea8000.file.read.asm"
        INCLUDE "engine/system/thomson/sound/mea8000.stream.read.asm"
