;*******************************************************************************
; Stack copy — example and bench
;
; engine/graphics/draw/stackcopy.asm copies blocks in RAM page 5 (the data
; window, $A000-$DFFF), the 50 Hz interrupt on : lengths around its 7-byte
; chunks and 252-byte blocks, a destination above an overlapping source, a
; screen half copied 16 times, then a copy with the interrupts masked by the
; caller. Each copy is checked byte by byte, with 16 bytes on either side :
; the destination holds the source's bytes, the source what it held where the
; destination does not cover it, the rest untouched.
;
; The bench stops at every interrupt during the copies (IrqManager) : the
; interrupted S must not point into the data window.
;
; Witnesses at $9C00 : +0 $CA once running, +1 $0D all passed or $E0+n test n
; failed, +2 the tests passed, +3 (word) the interrupts taken during a copy,
; +5 1 during a copy. Then copies timed by the bench, at time.call and
; time.done, the interrupts masked.
;*******************************************************************************

bench.magic  equ $9C00
bench.status equ $9C01
bench.passed equ $9C02
bench.irqs   equ $9C03
bench.inCopy equ $9C05

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.macro.asm"
        INCLUDE "engine/system/thomson/graphics/mode/gfxmode.macro.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.macro.asm"

 opt c,ct

        ; the scene loads this at the game mode region and jumps to its first
        ; byte, so main has to be the first thing emitted

main
        jsr   InitGlobals
        clr   bench.status
        clr   bench.passed
        ldd   #0
        std   bench.irqs
        clr   bench.inCopy
        lda   #$CA
        sta   bench.magic
        _ram.data.set #5

        ldx   #seq.t                       ; the pattern's table : a = 5a + 1, every byte once
        lda   #$3B
        clrb
!       sta   ,x+
        pshs  a
        lsla
        lsla
        adda  ,s+
        inca
        decb
        bne   <

        ldd   #userIRQ
        std   Irq_user_routine
        jsr   IrqInit
        lda   #255                         ; sync out of display
        ldx   #Irq_one_frame
        jsr   IrqSync
        jsr   IrqOn

        lda   #1
        sta   bench.n
        ldy   #tests
@test   ldd   ,y
        beq   @masked
        std   t.src
        ldd   2,y
        std   t.dst
        ldd   4,y
        std   t.len
        lda   6,y
        sta   t.rep
        pshs  y
@rep    jsr   t.run
        bcs   @fail
        dec   t.rep
        bne   @rep
        puls  y
        inc   bench.passed
        inc   bench.n
        leay  7,y
        bra   @test
@masked ldd   #$A100                       ; the caller's interrupts masked : kept masked, none taken
        std   t.src
        ldd   #$B000
        std   t.dst
        ldd   #2000
        std   t.len
        ldd   bench.irqs
        std   t.irqs
        orcc  #$50
        jsr   t.run
        bcs   @fail
        tfr   cc,a
        andcc #$AF
        bita  #$10
        beq   @fail
        ldd   bench.irqs
        cmpd  t.irqs
        bne   @fail
        inc   bench.passed
        lda   #$0D
        sta   bench.status
        bra   time
@fail   lda   bench.n
        adda  #$E0
        sta   bench.status
        bra   *

;-------------------------------------------------------------------------------
; the timed copies : each length of time.lens in turn, the interrupts masked
;-------------------------------------------------------------------------------
time    orcc  #$50
@all    ldx   #time.lens
@next   ldd   ,x++
        cmpd  #$FFFF
        beq   @all
        std   t.len
        pshs  x
        ldu   #$A020
        ldy   #$BF80
time.call
        jsr   stackcopy.run
time.done
        puls  x
        bra   @next

time.lens
        fdb   0,7,252,8000,$FFFF

;-------------------------------------------------------------------------------
; the tests : source, destination, bytes, times
;-------------------------------------------------------------------------------
tests
        fdb   $A100,$B000,0
        fcb   1
        fdb   $A100,$B000,1
        fcb   1
        fdb   $A100,$B000,6
        fcb   1
        fdb   $A100,$B000,7
        fcb   1
        fdb   $A100,$B000,8
        fcb   1
        fdb   $A100,$B000,13
        fcb   1
        fdb   $A100,$B000,251
        fcb   1
        fdb   $A100,$B000,252
        fcb   1
        fdb   $A100,$B000,253
        fcb   1
        fdb   $A100,$B000,504
        fcb   1
        fdb   $A100,$B000,505
        fcb   1
        fdb   $A020,$BF80,8000             ; a screen half, 16 times : interrupts taken
        fcb   16
        fdb   $A100,$A101,1000             ; a destination above an overlapping source
        fcb   1
        fdb   $A100,$A107,1000
        fcb   1
        fdb   $A020,$A228,7480             ; a screen half moved down 13 rows
        fcb   1
        fdb   $A100,$A100,300              ; onto itself
        fcb   1
        fdb   0

;-------------------------------------------------------------------------------
; t.run : the window (16 bytes on either side) filled with $55, the source
; with the pattern, the copy, then the window checked. C = 1 a byte wrong
;-------------------------------------------------------------------------------
t.run
        ldd   t.src
        cmpd  t.dst
        bls   >
        ldd   t.dst
!       subd  #16
        std   t.lo
        ldd   t.src
        cmpd  t.dst
        bhs   >
        ldd   t.dst
!       addd  t.len
        addd  #16
        std   t.hi
        ldx   t.lo
        lda   #$55
!       sta   ,x+
        cmpx  t.hi
        bne   <
        ldx   t.src
        ldy   #0
        bra   @fcond
@fill   bsr   t.f
        sta   ,x+
        leay  1,y
@fcond  cmpy  t.len
        bne   @fill
        ldu   t.src
        ldy   t.dst
        ldd   t.len
        inc   bench.inCopy
        jsr   stackcopy.run
        clr   bench.inCopy
        ldx   t.lo
@chk    tfr   x,d                          ; in the destination : the pattern from it
        subd  t.dst
        cmpd  t.len
        blo   @f
        tfr   x,d                          ; in the source : the pattern from it
        subd  t.src
        cmpd  t.len
        blo   @f
        lda   #$55
        bra   @cmp
@f      tfr   d,y
        bsr   t.f
@cmp    cmpa  ,x+
        bne   @bad
        cmpx  t.hi
        bne   @chk
        andcc #$FE
        rts
@bad    orcc  #1
        rts

t.f                                        ; A = the pattern's byte Y : seq.t[Y low] + Y high
        pshs  b,x
        tfr   y,d
        ldx   #seq.t
        abx
        adda  ,x
        puls  b,x,pc

;-------------------------------------------------------------------------------
; the interrupt : those during a copy counted
;-------------------------------------------------------------------------------
userIRQ
        tst   bench.inCopy
        beq   @rts
        ldd   bench.irqs
        addd  #1
        std   bench.irqs
@rts    rts

bench.n      fcb   0                       ; the test running
t.src        fdb   0
t.dst        fdb   0
t.len        fdb   0
t.rep        fcb   0
t.lo         fdb   0                       ; the window checked
t.hi         fdb   0
t.irqs       fdb   0                       ; the interrupts before the masked copy
seq.t        fill  0,256

;*******************************************************************************
; engine
;*******************************************************************************
        INCLUDE "engine/InitGlobals.asm"
        INCLUDE "engine/irq/Irq.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.asm"
        INCLUDE "engine/graphics/draw/stackcopy.asm"

 ENDSECTION
