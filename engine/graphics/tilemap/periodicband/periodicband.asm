; -----------------------------------------------------------------------------
; Periodic band (a picture whose pattern repeats along x, at any phase)
; -----------------------------------------------------------------------------
; wide-dot - 10/2026
; ---------------------------------------
; - the picture is made ready by <periodicband> (6809-game-builder), whose
;   generated source is assembled BEFORE this file, in the same unit, with the
;   <gfxcomp grid> that compiles its strips :
;     . its FULL lines (no transparent pixel) are drawn here from tables : the
;       period of each plane (12 bytes) is read once per line by pulu and
;       stored three times across the 144 px window, std/stx at fixed offsets
;       (the way lotus-adnz draws its mountain band). Each table is doubled,
;       so any rotation reads in one go ; the 2 px step swaps the planes, the
;       1 px step picks the other parity's tables. No S register, no irq mask.
;     . its other lines, the stems, are compiled strips of 16 px (gfxcomp
;       draw, ND0), 9 or 10 of them per call. The first one starts up to 14 px
;       left of the window and the last one ends up to 14 px right of it :
;       what spills lands in the side margins of the screen (and wraps to the
;       neighbouring line), which a playfield mask must cover - the window is
;       144 px in a 160 px line, 8 px of margin on each side.
; - draws on whatever is there : the stems keep their transparency, the full
;   lines cover everything. Call it AFTER the sprites for a foreground.
; - self-modifying (the class's pointer steps) : the unit must live in RAM.
; - the writer is written for a period of 48 px in a 144 px window, the case
;   it was measured on (r-type stage 5) : other geometries stop the assembly.
; - cost : 305 cycles per full line, ~640 cycles per strip of 24 lines.
; -----------------------------------------------------------------------------

 IFNE periodicband.PERIOD-48
        ERROR "periodicband : the writer is written for a period of 48 px"
 ENDC
 IFNE periodicband.WIDTH-144
        ERROR "periodicband : the writer is written for a 144 px window"
 ENDC

periodicband.ZONE    equ $A000                     ; the plane of the odd pixel pairs
periodicband.BYTES   equ periodicband.PERIOD/4     ; a plane's bytes in a period
periodicband.TABLE   equ 2*periodicband.BYTES      ; a doubled table
periodicband.PARITY  equ 2*periodicband.TABLE      ; a parity's two tables
periodicband.LINE    equ 2*periodicband.PARITY     ; a full line's tables
periodicband.COL     equ periodicband.X/4          ; the window's first byte

; one plane of a full line : the period's 12 bytes, 4 by 4, each stored at its
; three places of the window (U = the table, Y = the line)
_periodicband.plane MACRO
        pulu  d,x
        std   periodicband.COL+0,y
        stx   periodicband.COL+2,y
        std   periodicband.COL+12,y
        stx   periodicband.COL+14,y
        std   periodicband.COL+24,y
        stx   periodicband.COL+26,y
        pulu  d,x
        std   periodicband.COL+4,y
        stx   periodicband.COL+6,y
        std   periodicband.COL+16,y
        stx   periodicband.COL+18,y
        std   periodicband.COL+28,y
        stx   periodicband.COL+30,y
        pulu  d,x
        std   periodicband.COL+8,y
        stx   periodicband.COL+10,y
        std   periodicband.COL+20,y
        stx   periodicband.COL+22,y
        std   periodicband.COL+32,y
        stx   periodicband.COL+34,y
 ENDM

; -----------------------------------------------------------------------------
; periodicband.draw
; -----------------------------------------------------------------------------
; input  REG : [y] phase, 0..periodicband.PERIOD-1 : the window's pixel x shows
;              the picture's pixel (x + phase) mod periodicband.PERIOD
; -----------------------------------------------------------------------------
; draws the band in the data window ($A000-$DFFF : the back buffer between
; _gfxlock.on and _gfxlock.off). Every register is destroyed.
; -----------------------------------------------------------------------------
periodicband.draw
        tfr   y,d
        pshs  b                        ; the phase, again for the strips

        ; THE CLASS : s = phase/2 the byte phase, its parity e picks the
        ; parity's tables ; t = s/2 the rotation, s odd swaps the planes. The
        ; first plane written ($A000 zone, odd pixel pairs) reads the odd
        ; table at t, or the even one at t+1 when the planes are swapped ; the
        ; second ($C000 zone) the even table at t, or the odd one.
        lsrb                           ; B = s, C = e
        lda   #0                       ; keeps C
        bcc   >
        lda   #periodicband.PARITY
!       lsrb                           ; B = t, C = s & 1
        bcs   @swap
        adda  #periodicband.TABLE      ; the odd table first
        pshs  a
        lda   #-(periodicband.TABLE+periodicband.BYTES)
        sta   periodicband.d1+2        ; to the even table, same t
        lda   #periodicband.LINE+periodicband.TABLE-periodicband.BYTES
        bra   @class
@swap   inca                           ; the even table at t+1
        pshs  a
        lda   #periodicband.TABLE-1-periodicband.BYTES
        sta   periodicband.d1+2        ; to the odd table at t
        lda   #periodicband.LINE-periodicband.TABLE-periodicband.BYTES+1
@class  sta   periodicband.d2+2        ; to the next line's first table
        addb  ,s+
        clra
        std   periodicband.offset+2    ; the class's first read, in a line

 IFNE periodicband.RUNS
        ; THE FULL LINES, run after run
        ldx   #periodicband.runs
        lda   #periodicband.RUNS
        pshs  a
@run    ldd   ,x                       ; the run's video offset
        addd  #periodicband.ZONE
        tfr   d,y                      ; Y = the line, first plane
        ldb   2,x
        pshs  b,x                      ; line count, run pointer
        ldu   3,x
periodicband.offset
        leau  >0,u                     ; (self-modified) the class's first read
@line   _periodicband.plane
periodicband.d1
        leau  -36,u                    ; (self-modified) the second table
        leay  $2000,y                  ; the other plane
        _periodicband.plane
periodicband.d2
        leau  108,u                    ; (self-modified) the next line's table
        leay  -$2000+40,y              ; the next line, first plane
        dec   ,s
        bne   @line
        puls  b,x
        leax  5,x
        dec   ,s
        lbne  @run                     ; the unrolled planes : out of a byte's reach
        leas  1,s
 ENDC

 IFNE periodicband.STEMS
        ; THE STRIPS. The parity e picks its strips, q = phase - e (even) :
        ; strip q/16 of the period starts at window x = -(q mod 16), and so on
        ; every 16 px, 10 strips (9 when the first one is aligned).
        puls  b                        ; B = phase
        lda   #2*periodicband.STRIP.ENTRIES
        lsrb                           ; B = q/2, C = e
        bcs   >
        clra
!       ldx   #periodicband.strips
        leax  a,x                      ; the parity's strip table
        tfr   b,a
        lsra
        lsra
        lsra                           ; A = q/16, the first strip
        lsla
        leax  a,x
        ldy   #periodicband.WIDTH/16
        andb  #7                       ; B = (q mod 16)/2
        beq   >
        leay  1,y                      ; one more strip, the window's right edge
!       lslb
        negb                           ; B = -(q mod 16), the first strip's x
        addb  #periodicband.X          ; on the screen, -6..8 for X = 8
        sex
        ; the BM16 location of the strip, gfxcomp's convention : U = the
        ; plane of its first pixel pair (glb_screen_location_2), the other
        ; one in glb_screen_location_1 - one byte further when the strip
        ; starts on an odd pair
        bitb  #2
        bne   @odd
        asra
        rorb
        asra
        rorb
        addd  #periodicband.ZONE+$2000+periodicband.STEMS.Y*40
        std   <glb_screen_location_2
        subd  #$2000
        std   <glb_screen_location_1
        bra   @strip
@odd    asra
        rorb
        asra
        rorb
        addd  #periodicband.ZONE+periodicband.STEMS.Y*40
        std   <glb_screen_location_2
        addd  #$2001
        std   <glb_screen_location_1
@strip  ldu   <glb_screen_location_2
        pshs  x,y                      ; compiled code may push X and Y too
        jsr   [,x]
        puls  x,y
        leax  2,x
        ldd   <glb_screen_location_2
        addd  #4                       ; 16 px further
        std   <glb_screen_location_2
        ldd   <glb_screen_location_1
        addd  #4
        std   <glb_screen_location_1
        leay  -1,y
        bne   @strip
        rts
 ELSE
        puls  b,pc
 ENDC
