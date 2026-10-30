;*******************************************************************************
; Sprite streams (bm4s) - bench
;
; The spritestream manager (docs/lang/en/spritestream.md) : the builder's
; <spritestream> streams and walkers, clip mode on, with the engine's runtime,
; one copy in each half of the video half page. Four test pictures
; (tools/gen_spritestream.py : flag, its mirror flagm stored as a second
; facing, slab, tall), each drawn on the back buffer (page 2) in many ways ;
; every result is checked here against a second path, screens compared by
; checksums (both planes, 8 000 bytes each) :
;
;   t01-t16  flag, flagm, slab, tall ; facing 0 and 1 (the mirrored walk) ;
;            the 2 pixel steps 0 and 1 (x 120 : an even first byte, x 126 :
;            an odd one). draw, then its restore gives the background back ;
;            drawAt and drawClip (the rectangle the screen) draw the same
;            screen ; drawClip through five cuts of the box (its first
;            byte, its last, its lower half, its upper half, a window one
;            byte and one line in from each side) draws what draw draws with
;            the bytes outside the cut put back, and restores. The word : the
;            draw's checksum.
;   t17-t18  flag mirrored (the mirrored walk) draws what flagm, its second
;            facing, draws stored, at both steps. The word : the checksum.
;   t19-t42  flag, slab, tall, both facings, crossing the screen's left,
;            right, top and bottom edges (drawClip, the rectangle the
;            screen ; a uniform background) : the visible part of the box
;            equals the same box drawn inside the screen through a cut on the
;            same bytes (box relative checksums), nothing else on the screen
;            changed (the visible part put back to the background, the
;            screen is the background), the restore gives the background
;            back. The word : the visible part's checksum.
;   t43-t44  the guard (<spritestream guard="true">) : flag stored at x 120
;            (the first case of t01-t16), the save stack's top set to leave
;            the draw its bound (the record's bytes 8-9) less one byte : not
;            drawn, spritestream.skips one more, the screen the background
;            (t43, the word : skips' step, 1) ; then exactly its bound : drawn,
;            the screen t01's, the restore gives the background back (t44, the
;            word : the draw's checksum, t01's). A bottom record (REND) at the
;            top set : the restore walker's end there.
;
; Every test also checks the bytes past the screen in each plane
; ($BF40-$BFFF, $DF40-$DFFF) unchanged.
;
; Results at $9C00 (docs/lang/en/benches.md) : +0 $CA, +1 N, +2 $0D once
; the sequence completed, +3.. a byte a test ($01 pass, else the code of the
; check that failed : $E1.. in the order above), then a word a test. The
; words are the bench's reference (bench.ref) : a changed word is a changed
; picture.
;*******************************************************************************

spritestream.init       EXTERNAL
spritestream.restore    EXTERNAL
spritestream.draw       EXTERNAL
spritestream.drawAt     EXTERNAL
spritestream.drawClip   EXTERNAL
adr_flag                EXTERNAL
adr_flagm               EXTERNAL
adr_slab                EXTERNAL
adr_tall                EXTERNAL
spritestream.skips      EXTERNAL
spritestream.stack      EXTERNAL
spritestream.stack.end  EXTERNAL

 SECTION code

        INCLUDE "engine/constants.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/thomson/graphics/mode/gfxmode.macro.asm"
        INCLUDE "src/bench.equ"
        INCLUDE "engine/graphics/sprite/stream/spritestream.const.asm"

bench.w         equ   $9C00
bench.N         equ   44
bench.res       equ   bench.w+3
bench.words     equ   bench.res+bench.N
bench.PAGE      equ   map.RAM_OVER_CART+assets.sprites.page
bench.UNI       equ   $6C                   ; the uniform background (t19-t42)
bench.CASE      equ   15                    ; bytes a case

* a case : record, facing, x, y (signed), then for t19-t42 the move inside
* the screen (dx, dy) and the cut that stands for the screen's edge there
c.rec           equ   0
c.f             equ   2
c.x             equ   3
c.y             equ   5
c.dx            equ   7
c.dy            equ   9
c.r             equ   11

main
        orcc  #$50                          ; no interrupt : the tests own S
        lda   #$CA
        sta   bench.w
        lda   #bench.N
        sta   bench.w+1
        clr   bench.w+2
        _gfxmode.setBM4S
        _ram.data.set #2                    ; the back buffer : page 2
        ldb   map.MC6846.PRC
        orb   #1                            ; the first half of the video half page : manager 0
        stb   map.MC6846.PRC
        lda   #bench.PAGE
        sta   map.CF74021.CART              ; the records, read here too
        jsr   spritestream.init
        ldx   #bench.res                    ; every test failed until it ran
        lda   #$FF
@c      sta   ,x+
        cmpx  #bench.words
        bne   @c
        ldd   #0
@z      std   ,x++
        cmpx  #bench.words+2*bench.N
        bne   @z
        lbsr  bench.tails
        std   bench.tsum
        ; t01-t16 : on the screen, the patterned background
        clr   bench.uni
        lbsr  bench.fill
        lbsr  bench.sum
        std   bench.bg
        ldy   #bench.casesA
@a      lbsr  bench.load
        lbsr  bench.caseA
        lbsr  bench.put
        ldy   bench.cp
        leay  bench.CASE,y
        cmpy  #bench.casesB
        bne   @a
        ; t17-t18 : the mirrored walk against the second facing
        ldy   #bench.casesB
@b      sty   bench.cb
        lbsr  bench.caseB
        lbsr  bench.put
        ldy   bench.cb
        leay  2*bench.CASE,y
        cmpy  #bench.casesC
        bne   @b
        ; t19-t42 : across the screen's edges, a uniform background
        inc   bench.uni
        lbsr  bench.fill
        lbsr  bench.sum
        std   bench.bg
        ldy   #bench.casesC
@e      lbsr  bench.load
        lbsr  bench.caseC
        lbsr  bench.put
        ldy   bench.cp
        leay  bench.CASE,y
        cmpy  #bench.casesEnd
        bne   @e
        ; t43-t44 : the guard, on the patterned background
        clr   bench.uni
        lbsr  bench.fill
        lbsr  bench.sum
        std   bench.bg
        lda   #-1                           ; t43 : one byte short of the bound
        sta   bench.gd
        ldy   #bench.casesA
        lbsr  bench.load
        lbsr  bench.caseG
        lbsr  bench.put
        clr   bench.gd                      ; t44 : the bound exactly
        ldy   #bench.casesA
        lbsr  bench.load
        lbsr  bench.caseG
        lbsr  bench.put
        jsr   spritestream.init
        lda   #$0D
        sta   bench.w+2
@end    bra   @end

* A the verdict of test bench.t, bench.word its word ; after a failed test,
* the save stacks emptied and the background drawn again : the next starts
* clean
bench.put
        cmpa  #$01
        beq   @p
        pshs  a
        jsr   spritestream.init
        lbsr  bench.fill
        puls  a
@p      ldb   bench.t
        ldx   #bench.res
        sta   b,x
        ldx   #bench.words
        aslb
        abx
        ldd   bench.word
        std   ,x
        inc   bench.t
        rts

* Y a case : bench.cp, the record's rows and widest box (bench.h, bench.n),
* bench.k0 (x / 4, signed)
bench.load
        sty   bench.cp
        ldu   c.rec,y
        lda   6,u
        sta   bench.h
        lda   4,u
        cmpa  5,u
        bhs   @n
        lda   5,u
@n      sta   bench.n
        ldd   c.x,y
        std   bench.x
        asra
        rorb
        asra
        rorb
        std   bench.k0
        ldd   c.y,y
        std   bench.y
        rts

* --------------------------------------------------------------------------
* the tests ; a failed check returns from the test, A its code

bench.caseA
        sts   bench.s
        lbsr  bench.draw
        lbsr  bench.sum
        std   bench.word
        lda   #$E1
        lbsr  bench.back
        lbsr  bench.drawAt
        lda   #$E2
        lbsr  bench.same
        lda   #$E3
        lbsr  bench.back
        lbsr  bench.full
        lbsr  bench.drawClip
        lda   #$E4
        lbsr  bench.same
        lda   #$E5
        lbsr  bench.back
        clr   bench.k
@k      lda   bench.k                       ; the five cuts
        lbsr  bench.cut
        lbsr  bench.drawClip
        lbsr  bench.sum
        std   bench.sum1
        lda   bench.k
        asla
        adda  #$E7
        lbsr  bench.back
        lbsr  bench.draw                    ; the second path : whole, the bytes outside the cut put back
        lda   #4
        sta   bench.mode
        lbsr  bench.box
        lbsr  bench.sum
        cmpd  bench.sum1
        beq   @ok
        lda   bench.k
        asla
        adda  #$E6
        lbra  bench.fail
@ok     lda   bench.k
        asla
        adda  #$E7
        lbsr  bench.back
        inc   bench.k
        lda   bench.k
        cmpa  #5
        bne   @k
        lda   #$01
        rts

bench.caseB                                 ; bench.cb two cases : flag mirrored, flagm stored
        sts   bench.s
        ldy   bench.cb
        lbsr  bench.load
        lbsr  bench.draw
        lbsr  bench.sum
        std   bench.sum1
        lda   #$E2
        lbsr  bench.back
        ldy   bench.cb
        leay  bench.CASE,y
        lbsr  bench.load
        lbsr  bench.draw
        lbsr  bench.sum
        std   bench.word
        lda   #$E3
        lbsr  bench.back
        ldd   bench.word
        cmpd  bench.sum1
        beq   @ok
        lda   #$E1
        lbra  bench.fail
@ok     lda   #$01
        rts

bench.caseC
        sts   bench.s
        lbsr  bench.full
        lbsr  bench.drawClip                ; across the edge
        lda   #3                            ; the visible part : its checksum, then put back
        sta   bench.mode
        lbsr  bench.box
        std   bench.word
        lbsr  bench.sum
        cmpd  bench.bg
        beq   @a
        lda   #$E2                          ; a byte written outside the visible part
        lbra  bench.fail
@a      lda   #$E3
        lbsr  bench.back
        ldy   bench.cp                      ; the second path : moved inside, the edge a cut
        ldd   bench.x
        addd  c.dx,y
        std   bench.x
        asra
        rorb
        asra
        rorb
        std   bench.k0
        ldd   bench.y
        addd  c.dy,y
        std   bench.y
        ldd   c.r,y
        std   <spritestream.clipLeft
        ldd   c.r+2,y
        std   <spritestream.clipTop
        lbsr  bench.drawClip
        lda   #1
        sta   bench.mode
        lbsr  bench.box
        cmpd  bench.word
        beq   @b
        lda   #$E1
        lbra  bench.fail
@b      lda   #$E4
        lbsr  bench.back
        lda   #$01
        rts

* A a code : the buffer restored, the screen the background and the bytes
* past it unchanged, else the test fails with A
bench.back
        sta   bench.code
        jsr   spritestream.restore
        lbsr  bench.sum
        cmpd  bench.bg
        bne   @f
        lbsr  bench.tails
        cmpd  bench.tsum
        bne   @f
        rts
@f      lda   bench.code
bench.fail
        lds   bench.s
        rts

* A a code : the screen's checksum the word, else the test fails with A
bench.same
        sta   bench.code
        lbsr  bench.sum
        cmpd  bench.word
        bne   @f
        rts
@f      lda   bench.code
        bra   bench.fail

* t43-t44 : the stack's top at its bottom + IRQ + the record's bound +
* bench.gd (-1 or 0), a bottom record there, the case drawn
bench.caseG
        sts   bench.s
        ldu   [bench.cp]                    ; the record
        ldb   bench.gd
        sex
        addd  8,u                           ; its bound
        addd  #spritestream.stack
        addd  #spritestream.IRQ
        std   spritestream.top0             ; half 0 : the bench draws with manager 0
        tfr   d,x
        ldy   #spritestream.stack.end        ; its bottom record, copied there : the
        ldd   ,y                            ; restore walker's end
        std   ,x
        lda   2,y
        sta   2,x
        lda   spritestream.skips
        sta   bench.sk
        lbsr  bench.draw
        lda   spritestream.skips
        suba  bench.sk
        tst   bench.gd
        beq   @fit
        sta   bench.word+1                  ; t43 : skipped once
        clr   bench.word
        cmpa  #1
        beq   @once
        lda   #$E1
        lbra  bench.fail
@once   lda   #$E2                          ; nothing drawn
        lbsr  bench.back
        lda   #$01
        rts
@fit    tsta                                ; t44 : drawn
        beq   @drawn
        lda   #$E3
        lbra  bench.fail
@drawn  lbsr  bench.sum
        std   bench.word
        cmpd  bench.words                   ; t01's draw
        beq   @same
        lda   #$E4
        lbra  bench.fail
@same   lda   #$E5                          ; restored
        lbsr  bench.back
        lda   #$01
        rts

* --------------------------------------------------------------------------
* the case drawn by each entry

bench.draw
        lda   #bench.PAGE
        ldy   bench.cp
        ldb   c.f,y
        ldu   c.rec,y
        ldx   bench.x
        ldy   bench.y
        jmp   spritestream.draw

bench.drawAt
        lda   bench.y+1                     ; Y the box's first byte on its top line
        ldb   bench.k0+1
        lbsr  bench.addr
        tfr   x,y
        ldx   bench.cp
        ldb   bench.x+1
        andb  #2                            ; the step, bit 1
        orb   c.f,x
        ldu   c.rec,x
        lda   #bench.PAGE
        jmp   spritestream.drawAt

bench.drawClip
        lda   #bench.PAGE
        ldy   bench.cp
        ldb   c.f,y
        ldu   c.rec,y
        ldx   bench.x
        ldy   bench.y
        jmp   spritestream.drawClip

* the clip rectangle : the screen
bench.full
        ldd   #$0050                        ; screen bytes 0 to 80
        std   <spritestream.clipLeft
        ldd   #$00C8                        ; lines 0 to 200
        std   <spritestream.clipTop
        rts

* A = k : the cut k of the case's box (on the screen) : its first byte off,
* its last, its upper half, its lower half, a window
bench.cut
        pshs  a
        bsr   bench.full
        puls  a
        ldb   bench.k0+1
        tsta
        beq   @left
        deca
        beq   @right
        deca
        beq   @top
        deca
        beq   @bot
        incb                                ; the window
        stb   <spritestream.clipLeft
        addb  bench.n
        subb  #2
        stb   <spritestream.clipRight
        ldb   bench.y+1
        incb
        stb   <spritestream.clipTop
        addb  bench.h
        subb  #2
        stb   <spritestream.clipBottom
        rts
@left   incb
        stb   <spritestream.clipLeft
        rts
@right  addb  bench.n
        decb
        stb   <spritestream.clipRight
        rts
@top    ldb   bench.h
        lsrb
        addb  bench.y+1
        stb   <spritestream.clipTop
        rts
@bot    ldb   bench.h
        lsrb
        addb  bench.y+1
        stb   <spritestream.clipBottom
        rts

* --------------------------------------------------------------------------
* the screen

* A a line (0-199), B a screen byte (0-79) : X its address (even bytes RAMA)
bench.addr
        pshs  b
        ldb   #40
        mul
        tfr   d,x
        puls  b
        lsrb
        abx
        bcs   @b
        leax  $C000,x
        rts
@b      leax  $A000,x
        rts

* X an address : B its background byte
bench.bgbyte
        tst   bench.uni
        bne   @u
        tfr   x,d
        pshs  a
        eorb  ,s+
        rts
@u      ldb   #bench.UNI
        rts

* the screen's bytes : the background
bench.fill
        ldx   #$A000
@a      bsr   bench.bgbyte
        stb   ,x+
        cmpx  #$BF40
        bne   @a
        ldx   #$C000
@b      bsr   bench.bgbyte
        stb   ,x+
        cmpx  #$DF40
        bne   @b
        rts

* D : the checksum of the screen's bytes (both planes, a sum of words : the
* background differs at every address, so a byte drawn elsewhere changes it)
bench.sum
        ldx   #$A000
        ldd   #0
@a      addd  ,x++
        addd  ,x++
        addd  ,x++
        addd  ,x++
        addd  ,x++
        addd  ,x++
        addd  ,x++
        addd  ,x++
        cmpx  #$BF40
        bne   @a
        ldx   #$C000
@b      addd  ,x++
        addd  ,x++
        addd  ,x++
        addd  ,x++
        addd  ,x++
        addd  ,x++
        addd  ,x++
        addd  ,x++
        cmpx  #$DF40
        bne   @b
        rts

* D : the checksum of the bytes past the screen in each plane
bench.tails
        ldx   #$BF40
        ldd   #0
@a      addd  ,x++
        aslb
        rola
        adcb  #0
        cmpx  #$C000
        bne   @a
        ldx   #$DF40
@b      addd  ,x++
        aslb
        rola
        adcb  #0
        cmpx  #$E000
        bne   @b
        rts

* the case's box (bench.n bytes from bench.k0, bench.h lines from bench.y),
* its bytes on the screen, in order ; bench.mode : bit 0 the checksum of the
* ones inside the clip rectangle (D, box relative : the same for the same box
* anywhere), bit 1 those put back to the background, bit 2 the ones outside
* it put back
bench.box
        ldd   #0
        std   bench.bsum
        ldd   bench.y
        std   bench.line
        lda   bench.h
        sta   bench.rows
@r      ldd   bench.k0
        std   bench.col
        lda   bench.n
        sta   bench.cols
@c      lda   bench.line                    ; on the screen ?
        bne   @next
        lda   bench.line+1
        cmpa  #200
        bhs   @next
        lda   bench.col
        bne   @next
        ldb   bench.col+1
        cmpb  #80
        bhs   @next
        lda   bench.line+1
        lbsr  bench.addr
        ldb   bench.col+1                   ; inside the clip rectangle ?
        cmpb  <spritestream.clipLeft
        blo   @out
        cmpb  <spritestream.clipRight
        bhs   @out
        lda   bench.line+1
        cmpa  <spritestream.clipTop
        blo   @out
        cmpa  <spritestream.clipBottom
        bhs   @out
        lda   bench.mode
        bita  #1
        beq   @p
        ldb   ,x
        clra
        addd  bench.bsum
        aslb
        rola
        adcb  #0
        std   bench.bsum
        lda   bench.mode
@p      bita  #2
        beq   @next
        bra   @w
@out    lda   bench.mode
        bita  #4
        beq   @next
@w      lbsr  bench.bgbyte
        stb   ,x
@next   ldd   bench.col
        addd  #1
        std   bench.col
        dec   bench.cols
        lbne  @c
        ldd   bench.line
        addd  #1
        std   bench.line
        dec   bench.rows
        lbne  @r
        ldd   bench.bsum
        rts

* --------------------------------------------------------------------------
* the cases

bench.casesA
        fdb   adr_flag
        fcb   0
        fdb   120,60,0,0,0,0
        fdb   adr_flag
        fcb   0
        fdb   126,60,0,0,0,0
        fdb   adr_flag
        fcb   1
        fdb   120,60,0,0,0,0
        fdb   adr_flag
        fcb   1
        fdb   126,60,0,0,0,0
        fdb   adr_flagm
        fcb   0
        fdb   120,60,0,0,0,0
        fdb   adr_flagm
        fcb   0
        fdb   126,60,0,0,0,0
        fdb   adr_flagm
        fcb   1
        fdb   120,60,0,0,0,0
        fdb   adr_flagm
        fcb   1
        fdb   126,60,0,0,0,0
        fdb   adr_slab
        fcb   0
        fdb   120,60,0,0,0,0
        fdb   adr_slab
        fcb   0
        fdb   126,60,0,0,0,0
        fdb   adr_slab
        fcb   1
        fdb   120,60,0,0,0,0
        fdb   adr_slab
        fcb   1
        fdb   126,60,0,0,0,0
        fdb   adr_tall
        fcb   0
        fdb   120,60,0,0,0,0
        fdb   adr_tall
        fcb   0
        fdb   126,60,0,0,0,0
        fdb   adr_tall
        fcb   1
        fdb   120,60,0,0,0,0
        fdb   adr_tall
        fcb   1
        fdb   126,60,0,0,0,0
bench.casesB
        fdb   adr_flag
        fcb   1
        fdb   120,60,0,0,0,0
        fdb   adr_flagm
        fcb   0
        fdb   120,60,0,0,0,0
        fdb   adr_flag
        fcb   1
        fdb   126,60,0,0,0,0
        fdb   adr_flagm
        fcb   0
        fdb   126,60,0,0,0,0
bench.casesC                                ; x, y, then dx, dy and the cut : left, right, top, bottom
        fdb   adr_flag
        fcb   0
        fdb   -6,60,40,0,$0A50,$00C8        ; the left edge : box byte 2 at screen byte 0, then 10
        fdb   adr_flag
        fcb   0
        fdb   302,60,-40,0,$0046,$00C8      ; the right edge : screen byte 80, then 70
        fdb   adr_flag
        fcb   0
        fdb   120,-12,0,80,$0050,$50C8      ; the top edge : line 0, then 80
        fdb   adr_flag
        fcb   0
        fdb   120,186,0,-80,$0050,$0078     ; the bottom edge : line 200, then 120
        fdb   adr_flag
        fcb   1
        fdb   -6,60,40,0,$0A50,$00C8
        fdb   adr_flag
        fcb   1
        fdb   302,60,-40,0,$0046,$00C8
        fdb   adr_flag
        fcb   1
        fdb   120,-12,0,80,$0050,$50C8
        fdb   adr_flag
        fcb   1
        fdb   120,186,0,-80,$0050,$0078
        fdb   adr_slab
        fcb   0
        fdb   -6,60,40,0,$0A50,$00C8
        fdb   adr_slab
        fcb   0
        fdb   302,60,-40,0,$0046,$00C8
        fdb   adr_slab
        fcb   0
        fdb   120,-12,0,80,$0050,$50C8
        fdb   adr_slab
        fcb   0
        fdb   120,186,0,-80,$0050,$0078
        fdb   adr_slab
        fcb   1
        fdb   -6,60,40,0,$0A50,$00C8
        fdb   adr_slab
        fcb   1
        fdb   302,60,-40,0,$0046,$00C8
        fdb   adr_slab
        fcb   1
        fdb   120,-12,0,80,$0050,$50C8
        fdb   adr_slab
        fcb   1
        fdb   120,186,0,-80,$0050,$0078
        fdb   adr_tall
        fcb   0
        fdb   -6,60,40,0,$0A50,$00C8
        fdb   adr_tall
        fcb   0
        fdb   302,60,-40,0,$0046,$00C8
        fdb   adr_tall
        fcb   0
        fdb   120,-12,0,80,$0050,$50C8
        fdb   adr_tall
        fcb   0
        fdb   120,186,0,-80,$0050,$0078
        fdb   adr_tall
        fcb   1
        fdb   -6,60,40,0,$0A50,$00C8
        fdb   adr_tall
        fcb   1
        fdb   302,60,-40,0,$0046,$00C8
        fdb   adr_tall
        fcb   1
        fdb   120,-12,0,80,$0050,$50C8
        fdb   adr_tall
        fcb   1
        fdb   120,186,0,-80,$0050,$0078
bench.casesEnd

* --------------------------------------------------------------------------
* variables

bench.t         fcb   0                     ; the test
bench.cp        fdb   0                     ; its case
bench.cb        fdb   0                     ; t17-t18 : the pair of cases
bench.s         fdb   0                     ; S at its start
bench.code      fcb   0
bench.word      fdb   0
bench.sum1      fdb   0
bench.bg        fdb   0                     ; the background's checksum
bench.tsum      fdb   0                     ; the bytes past the screen's
bench.uni       fcb   0                     ; 0 the patterned background, else the uniform one
bench.gd        fcb   0                     ; t43-t44 : the top's offset from the bound
bench.sk        fcb   0                     ; t43-t44 : skips before the draw
bench.k         fcb   0                     ; the cut
bench.mode      fcb   0
bench.x         fdb   0                     ; the case : x, y, x / 4
bench.y         fdb   0
bench.k0        fdb   0
bench.h         fcb   0                     ; its record's rows, widest box
bench.n         fcb   0
bench.line      fdb   0                     ; bench.box
bench.col       fdb   0
bench.rows      fcb   0
bench.cols      fcb   0
bench.bsum      fdb   0

 ENDSECTION
