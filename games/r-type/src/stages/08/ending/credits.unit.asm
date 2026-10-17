;*******************************************************************************
; credits — the ending's text lines, its own direntry (stage8.credits)
;
; Each line of the credits is ONE compiled transparent sprite (images/lines,
; tools/gen_ending.py from the HUD's glyphs): over everything, as on the
; arcade, one call per line — measured on the 580 renders of the sequence, 53 to 56 %
; fewer cycles than drawing it glyph by glyph (worst render 15 706 cycles
; against 34 868). credits.Draw is called by the stage's overlay
; (stage-main.asm, paged.call), after the sprites, before the side bands.
;
; A line is at y = (8 (row - 16) - Y) mod 512 arcade pixels (TO8: 10 + 3y/4).
; It is drawn as soon as it overlaps the playfield — top on line 3 to 191, in
; the screen's memory — and the black bands it covered (lines 3-10 at the top,
; 191-198 at the bottom) are painted black again after: a line comes in and
; goes out progressively, as the side columns let the ships in. A band costs
; 100 cycles a line and a plane, 1 600 at most, only when a line is on it. The entry is the
; FIRST byte of the unit (docs/lang/en/migration/unit-entry-point.md).
;*******************************************************************************

credits.Draw EXPORT

; resident, in the stage 8 main: the rows the director wrote, the scroll
ending.rowText    EXTERNAL
ending.textY      EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"

credits.Draw
        lda   #11
        sta   credits.top                ; no line on the top band (11 = none)
        clr   credits.bot                ; none on the bottom band
        ldx   #ending.rowText+16
        lda   #16
        sta   credits.row
@loop   ldb   ,x
        lbeq  @next
        stx   credits.rx
        lda   credits.row
        suba  #16
        ldb   #8
        mul
        subd  ending.textY
        anda  #1                         ; mod 512
        cmpd  #242                       ; down to its top on line 191
        bls   @pos
        cmpd  #512-9                     ; up to its top on line 3: a line
        lblo  @skip                      ; leaving at the top is negative
        subd  #512
@pos    std   credits.a                  ; 3y/4, signed
        aslb
        rola
        addd  credits.a
        asra
        rorb
        asra
        rorb
        addd  #10                        ; B = its top line, 3 to 191
        cmpb  #11                        ; ON THE BANDS: a line straddling
        bhs   >                          ; one is drawn whole, the band's
        stb   credits.top                ; lines it covered go black again
!       cmpb  #183                       ; after (credits.Band) — it comes
        bls   >                          ; in and goes out progressively
        stb   credits.bot
!       lda   #40
        mul
        addd  #$C000
        std   credits.a
        ldb   [credits.rx]               ; the string's rank + 1
        decb
        ldx   #ending.Cols
        lda   b,x                        ; its byte column
        aslb
        ldx   #ending.Lines
        ldx   b,x                        ; its compiled line
        tfr   a,b
        clra
        addd  credits.a
        std   <glb_screen_location_2     ; the $C000 plane, the other one
        suba  #$20                       ; 8 KB below
        std   <glb_screen_location_1
        tfr   d,u
        leau  $2000,u
        jsr   ,x
@skip   ldx   credits.rx
@next   leax  1,x
        inc   credits.row
        lda   credits.row
        cmpa  #64
        lblo  @loop
        ldb   credits.top                ; the top band: its lines from the
        cmpb  #11                        ; line's top down to 10
        bhs   >
        lda   #11                        ; B = first line, A = 11 - B lines
        suba  credits.top
        bsr   credits.Band
!       ldb   credits.bot                ; the bottom band: its lines from
        beq   @rts                       ; 191 down to the line's bottom
        subb  #183                       ; count = top + 8 - 191
        tfr   b,a
        ldb   #191
        bsr   credits.Band
@rts    rts

; black again: A lines from line B, on both planes — 10 pushes of 4 bytes a
; line, from the end up
credits.Band
        sta   credits.n
        addb  credits.n                  ; the line after the last
        lda   #40
        mul
        addd  #$C000
        std   credits.a
        tfr   d,u
        bsr   @plane
        ldu   credits.a
        leau  -$2000,u
@plane  lda   credits.n
        sta   credits.c
        ldd   #0
        ldy   #0
@line   pshu  d,y
        pshu  d,y
        pshu  d,y
        pshu  d,y
        pshu  d,y
        pshu  d,y
        pshu  d,y
        pshu  d,y
        pshu  d,y
        pshu  d,y
        dec   credits.c
        bne   @line
        rts

credits.row   fcb   0                    ; the row drawn,
credits.rx    fdb   0                    ; its cell,
credits.a     fdb   0                    ; the line's address
credits.top   fcb   0                    ; the top line of a line on the top band
credits.bot   fcb   0                    ; the top line of a line on the bottom one
credits.n     fcb   0                    ; a band: its line count,
credits.c     fcb   0                    ; the lines left

        INCLUDE "src/stages/08/ending/text.asm"

 ENDSECTION
