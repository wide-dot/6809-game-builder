;*******************************************************************************
; Periodic band — example and bench
;
; A band whose pattern repeats every 48 px (src/band.png, a measuring pattern :
; tools/gen_band.py), drawn by engine/graphics/tilemap/periodicband at each of
; its 48 phases in turn. The screen is filled with colour 15 first, a colour
; the band never uses : a transparent pixel drawn by mistake, or a strip
; spilling where it should not, shows.
;
; Each phase is drawn in both screen buffers, then held. Alone, the example
; holds each phase 25 frames. Under ci/toje-bench/periodicband_ut.py, which
; writes $A5 at +5 in the first 100 frames, it holds each phase until the
; script, having captured and checked the screen, writes the counter (+2)
; back at +4 : no capture can fall between two phases.
;
; Witnesses at $9C00 : +0 $CA once running, +1 the phase on screen, +2 a
; counter moved once both buffers hold it, +3 $0D after the 48 phases, +4
; the script's acknowledgement, +5 $A5 when a script drives the bench.
;
; The setup (mode, palette, irq, gfxlock) is examples/hscroll's.
;*******************************************************************************

bench.magic equ $9C00
bench.phase equ $9C01
bench.count equ $9C02
bench.done  equ $9C03
bench.ack   equ $9C04
bench.armed equ $9C05
HOLD        equ 25                         ; frames a phase stays on screen
WAIT        equ 100                        ; frames the script has to arm

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.macro.asm"
        INCLUDE "engine/system/thomson/graphics/mode/gfxmode.macro.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.macro.asm"

 opt c,ct

        ; the scene loads this at the game mode region and jumps to its first
        ; byte, so main has to be the first thing emitted

main
        jsr   InitGlobals
        _gfxmode.setBM16

        ldd   #Pal_band
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow

        ldd   #userIRQ
        std   Irq_user_routine
        jsr   IrqInit
        lda   #255                         ; sync out of display
        ldx   #Irq_one_frame
        jsr   IrqSync
        _gfxlock.init
        jsr   IrqOn

        clr   bench.phase
        clr   bench.count
        clr   bench.done
        clr   bench.ack
        clr   bench.armed
        lda   #$CA
        sta   bench.magic
        lda   #WAIT                        ; a script may arm the bench
        sta   buffers
@arm    jsr   frame
        lda   bench.armed
        cmpa  #$A5
        beq   phase
        dec   buffers
        bne   @arm

phase
        lda   #2                           ; both buffers
        sta   buffers
draw    _gfxlock.on
        orcc  #$50                         ; the fill pushes through S
        ldx   #$FFFF                       ; colour 15, the background
        jsr   ClearInterlacedEvenDataMemory
        ldx   #$FFFF
        jsr   ClearInterlacedOddDataMemory
        andcc #$AF
        ldb   bench.phase
        clra
        tfr   d,y
        jsr   periodicband.draw
        _gfxlock.off
        _gfxlock.loop
        dec   buffers
        bne   draw
        inc   bench.count                  ; the phase is on screen, both buffers
        lda   bench.armed
        cmpa  #$A5
        bne   @timed
@acked  jsr   frame                        ; until the script has checked it
        lda   bench.ack
        cmpa  bench.count
        bne   @acked
        bra   @next
@timed  lda   #HOLD
        sta   buffers
@hold   jsr   frame
        dec   buffers
        bne   @hold
@next
        lda   bench.phase
        inca
        sta   bench.phase
        cmpa  #periodicband.PERIOD
        lbne  phase
        clr   bench.phase                  ; the sequence again, after the witness
        lda   #$0D
        sta   bench.done
        lbra  phase

buffers fcb   0

frame                                      ; one frame, nothing drawn
        _gfxlock.on
        _gfxlock.off
        _gfxlock.loop
        rts

userIRQ
        jsr   gfxlock.bufferSwap.check
        jmp   PalUpdateNow

;*******************************************************************************
; engine
;*******************************************************************************
        INCLUDE "engine/InitGlobals.asm"
        INCLUDE "engine/irq/Irq.asm"
        INCLUDE "engine/palette/PalUpdateNow.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.asm"
        INCLUDE "engine/graphics/clear/ClearInterlacedDataMemory.asm"
        INCLUDE "engine/graphics/tilemap/periodicband/periodicband.asm"

 ENDSECTION
