* ---------------------------------------------------------------------------
* raycast : the raycaster's unit
* ---------------------------------------------------------------------------
* Casts a ray a screen column in a grid map and writes a column descriptor
* (wallscaler.asm) for each. Called by raycast.asm, which mounts its page.
*
* Assembled after the builder's <raycast> (constants, _raycast.tables), in a
* file of its own at an address $xx00 of the cart window : the variables and
* the four loops sit in its first 256 bytes, its direct page. The variables
* are constant offsets : an object file's 8 bit internal references are not
* relocated.
*
* A ray : 1/|rd| from a table, the first side distances, a DDA loop for the
* ray's quadrant (its deltas patched in its own operands), the
* perpendicular distance, the texture column, the height from a table. The
* builder's RayModel makes the same descriptors.
*
* In : raycast.x, raycast.y (8.8 cells), raycast.in (the angle's rays).
* Entries (A, B, X, Y, U and CC lost, DP kept) :
*   raycast.unit.cast   U = the descriptors buffer
*   raycast.unit.move   B = the step, signed, 1/256 cell
* ---------------------------------------------------------------------------

raycast.unit.cast EXPORT
raycast.unit.move EXPORT
raycast.x         EXTERNAL
raycast.y         EXTERNAL
raycast.in        EXTERNAL

 SECTION code

; the variables : offsets in the direct page (the unit's first bytes)
raycast.cell0  equ 0
raycast.rx     equ 2
raycast.ry     equ 4
raycast.arx    equ 6
raycast.ary    equ 8
raycast.dx     equ 10
raycast.dy     equ 12
raycast.sx     equ 14
raycast.sy     equ 16
raycast.perp   equ 18
raycast.m      equ 20
raycast.tx     equ 22
raycast.mx     equ 24
raycast.my     equ 26
raycast.nx     equ 28
raycast.ny     equ 30
raycast.q      equ 32
raycast.mv     equ 33
raycast.rx8    equ 34
raycast.ry8    equ 35
raycast.fxn    equ 36
raycast.fxp    equ 37
raycast.fyn    equ 38
raycast.fyp    equ 39
raycast.f      equ 40
raycast.t      equ 41
raycast.tb     equ 42
raycast.count  equ 43
raycast.slot   equ 44
raycast.rx0    equ 46
raycast.ry0    equ 48
raycast.s2x    equ 50
raycast.s2y    equ 52
raycast.hc     equ 54
raycast.lhc    equ 56
raycast.ltx    equ 58
raycast.n      equ 60
raycast.ln     equ 61
raycast.side   equ 62
raycast.lside  equ 63
raycast.VARS   equ 64

raycast.vars
        fill  0,raycast.VARS

;-------------------------------------------------------------------------------
; the DDA loop, one copy a quadrant (\4 : which, 0-3). X the cell, Y side x,
; the y side in the cmpy operand. Exits to the quadrant's own tails with B =
; the cell (its texture number). The copies follow the variables : a copy
; reaches its own operands through the direct page.
;-------------------------------------------------------------------------------
raycast.CMP equ raycast.l0.c+2-raycast.l0             ; offsets of the patched operands,
raycast.LEA equ raycast.l0.l+2-raycast.l0             ; from the labels (the same in the
raycast.ADD equ raycast.l0.a+1-raycast.l0             ; four copies)
raycast.LOOP equ raycast.l2-raycast.l0            ; a copy's bytes

RAYLOOP MACRO
\1
\1.c    cmpy  #$0000                       ; (dynamic) side y
        bhs   \1.y
\1.l    leay  >$0000,y                     ; (dynamic) side x += delta x
        leax  \2,x
        ldb   ,x
        beq   \1
        jmp   \1.hx
\1.y    ldd   <raycast.VARS+\4*raycast.LOOP+raycast.CMP                   ; side y += delta y
\1.a    addd  #$0000                       ; (dynamic)
        std   <raycast.VARS+\4*raycast.LOOP+raycast.CMP
        leax  \3,x
        ldb   ,x
        beq   \1
        jmp   \1.hy
 ENDM

;-------------------------------------------------------------------------------
; a tail : the hit's perp, its texture column, its descriptor. \1 label,
; \2 0 x face (side x in Y) / 1 y face (side y in the loop's cmpy operand,
; U the loop), \3 |rd'| along the face, \4 the position's fraction along
; it, \5 rd' < 0, \6 mirrored
;-------------------------------------------------------------------------------
RAYTAIL MACRO
\1      stx   <raycast.hc                      ; the hit cell, the face : the
        lda   #\2                          ; interpolation's test
        sta   <raycast.side
        ldx   #raycast.textures
        lslb                               ; a word a texture, its high byte
        lda   b,x
        sta   <raycast.tb
 IFEQ \2
        tfr   y,d
        subd  <raycast.dx
 ELSE
        ldd   raycast.CMP,u
        subd  <raycast.dy
 ENDC
        cmpd  #raycast.PERP_MIN
        bhs   \1.p
        ldd   #raycast.PERP_MIN
\1.p    std   <raycast.perp
        ; ((perp x r) >> 7) & 255, r = |rd'| >> 7 : (ph x r) << 1 + (pl x r) >> 7
        lda   <raycast.perp+1
        ldb   <\3
        mul                                ; pl x r
        lslb                               ; bit 7 to C
        rola                               ; A = (pl x r) >> 7, low byte
        sta   <raycast.t
        lda   <raycast.perp
        ldb   <\3
        mul                                ; ph x r
        lslb
        addb  <raycast.t
 IFNE \5
        negb
 ENDC
        addb  \4
        lsrb
        lsrb                               ; u
 IFNE \6
        eorb  #63
 ENDC
        lda   #64
        mul
        adda  <raycast.tb
        std   <raycast.tx                      ; the texture column
        ldd   <raycast.perp
        lsra
        rorb
        lsra
        rorb                               ; perp >> 2
        cmpd  #raycast.NLEN
        blo   \1.n
        ldd   #raycast.NLEN-1
\1.n    ldx   #raycast.nsamp
        ldb   d,x
        stb   <raycast.n                       ; the samples
        rts
 ENDM

        RAYLOOP raycast.l0,1,raycast.MAP_W,0       ; q = 0 : x+, y+
        RAYLOOP raycast.l2,-1,raycast.MAP_W,1      ; q = 2 : x-, y+
        RAYLOOP raycast.l4,1,-raycast.MAP_W,2      ; q = 4 : x+, y-
        RAYLOOP raycast.l6,-1,-raycast.MAP_W,3     ; q = 6 : x-, y-

 IFGT *-raycast.vars-256
        ERROR "raycast : the variables and the loops leave the direct page"
 ENDC
 IFNE raycast.l6-raycast.vars-raycast.VARS-3*raycast.LOOP
        ERROR "raycast : a loop is not where its own operands say"
 ENDC

        RAYTAIL raycast.l0.hx,0,raycast.ry8,raycast.y+1,0,0
        RAYTAIL raycast.l0.hy,1,raycast.rx8,raycast.x+1,0,1
        RAYTAIL raycast.l2.hx,0,raycast.ry8,raycast.y+1,0,1
        RAYTAIL raycast.l2.hy,1,raycast.rx8,raycast.x+1,1,1
        RAYTAIL raycast.l4.hx,0,raycast.ry8,raycast.y+1,1,0
        RAYTAIL raycast.l4.hy,1,raycast.rx8,raycast.x+1,0,0
        RAYTAIL raycast.l6.hx,0,raycast.ry8,raycast.y+1,1,1
        RAYTAIL raycast.l6.hy,1,raycast.rx8,raycast.x+1,1,0

raycast.loops
        fdb   raycast.l0,raycast.l2,raycast.l4,raycast.l6

;-------------------------------------------------------------------------------
; raycast.unit.cast : U = the descriptors buffer (column 0). A ray for column
; 0, the even columns and the last one ; an odd column whose neighbours hit
; the same cell on the same face is their mean (height, texture column),
; otherwise it casts its own ray (raycast.PAIR 0 : always).
;-------------------------------------------------------------------------------
raycast.unit.cast
        pshs  dp                           ; the interrupt sets its own DP and
        leax  raycast.vars,pcr             ; the CPU saves ours
        tfr   x,d
        tfr   a,dp
        stu   <raycast.slot
        lda   >raycast.y                       ; the camera's cell
        ldb   #raycast.MAP_W
        mul
        addb  >raycast.x
        adca  #0
        addd  #raycast.map
        std   <raycast.cell0
        ldb   >raycast.x+1                     ; the fractions : towards - and +
        stb   <raycast.fxn
        negb
        stb   <raycast.fxp                     ; 256 - fx, 0 is 256
        ldb   >raycast.y+1
        stb   <raycast.fyn
        negb
        stb   <raycast.fyp
        ldd   >raycast.in+4                    ; 2 x step
        aslb
        rola
        std   <raycast.s2x
        ldd   >raycast.in+6
        aslb
        rola
        std   <raycast.s2y
        ldd   >raycast.in                      ; column 0
        std   <raycast.rx0
        std   <raycast.rx
        ldd   >raycast.in+2
        std   <raycast.ry0
        std   <raycast.ry
        jsr   raycast.one
        ldx   <raycast.slot
        ldb   <raycast.n
        ldy   <raycast.tx
        jsr   raycast.emit
        jsr   raycast.keepL
        lda   #(raycast.COLS-2)/2
        sta   <raycast.count
raycast.pair
        ldd   <raycast.rx0                     ; the next even column
        addd  <raycast.s2x
        std   <raycast.rx0
        std   <raycast.rx
        ldd   <raycast.ry0
        addd  <raycast.s2y
        std   <raycast.ry0
        std   <raycast.ry
        jsr   raycast.one
        ldx   <raycast.slot
        leax  12,x
        stx   <raycast.slot
        ldb   <raycast.n
        ldy   <raycast.tx
        jsr   raycast.emit
        ; the odd column before it
 IFNE raycast.PAIR
        ldd   <raycast.hc
        cmpd  <raycast.lhc
        bne   @cast
        lda   <raycast.side
        cmpa  <raycast.lside
        bne   @cast
        ldd   <raycast.tx                      ; the texture columns' mean
        addd  <raycast.ltx
        rora
        rorb
        andb  #$C0
        tfr   d,y
        ldb   <raycast.n                       ; the samples' mean
        addb  <raycast.ln
        rorb
        jsr   raycast.keepL                    ; (keeps B, Y)
        ldx   <raycast.slot
        leax  -6,x
        jsr   raycast.emit
        bra   @next
 ENDC
@cast   jsr   raycast.keepL
        ldd   <raycast.rx0                     ; its own ray
        subd  >raycast.in+4
        std   <raycast.rx
        ldd   <raycast.ry0
        subd  >raycast.in+6
        std   <raycast.ry
        jsr   raycast.one
        ldx   <raycast.slot
        leax  -6,x
        ldb   <raycast.n
        ldy   <raycast.tx
        jsr   raycast.emit
@next   dec   <raycast.count
        bne   raycast.pair
        ldd   <raycast.rx0                     ; the last column
        addd  >raycast.in+4
        std   <raycast.rx
        ldd   <raycast.ry0
        addd  >raycast.in+6
        std   <raycast.ry
        jsr   raycast.one
        ldx   <raycast.slot
        leax  6,x
        ldb   <raycast.n
        ldy   <raycast.tx
        jsr   raycast.emit
        puls  dp,pc

; raycast.keepL : the last even column becomes the left one (keeps B, Y)
raycast.keepL
        lda   <raycast.n
        sta   <raycast.ln
        ldx   <raycast.tx
        stx   <raycast.ltx
        ldx   <raycast.hc
        stx   <raycast.lhc
        lda   <raycast.side
        sta   <raycast.lside
        rts

; raycast.emit : X the slot, B the samples, Y the texture column
raycast.emit
        sty   2,x
        clra
        lslb
        rola
        lslb
        rola                               ; samples x 4
        ldu   #raycast.scalers
        leau  d,u
        ldd   ,u                           ; page, top row
        std   ,x
        ldd   2,u                          ; the scaler
        std   4,x
        rts

;-------------------------------------------------------------------------------
; raycast.one : one ray (raycast.rx, raycast.ry) -> raycast.n, raycast.tx, raycast.hc, raycast.side
;-------------------------------------------------------------------------------
raycast.one
raycast.col
        ; ---- x : |rdx|, its delta, the first side
        ldx   #raycast.recip
        ldd   <raycast.rx
        bmi   raycast.xn
        clr   <raycast.q
        std   <raycast.arx
        lslb
        rola
        sta   <raycast.rx8                     ; |rd| >> 7
        ldd   <raycast.arx
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        andb  #$FE                         ; (|rdx| >> 4) x 2
        ldd   d,x
        std   <raycast.dx
        lda   <raycast.fxp                     ; 0 is 256 : side = delta
        bne   raycast.xm
        ldd   <raycast.dx
        bra   raycast.xs
raycast.xn  nega                               ; negd
        negb
        sbca  #0
        std   <raycast.arx
        lslb
        rola
        sta   <raycast.rx8                     ; |rd| >> 7
        ldd   <raycast.arx
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        andb  #$FE
        ldd   d,x
        std   <raycast.dx
        lda   #2
        sta   <raycast.q
        lda   <raycast.fxn                     ; 0 is 0
        bne   raycast.xm
        clrb
        bra   raycast.xs
raycast.xm  sta   <raycast.f
        ldb   <raycast.dx+1
        mul
        sta   <raycast.t
        lda   <raycast.f
        ldb   <raycast.dx
        mul
        addb  <raycast.t
        adca  #0
raycast.xs  std   <raycast.sx
        ; ---- y
        ldd   <raycast.ry
        bmi   raycast.yn
        std   <raycast.ary
        lslb
        rola
        sta   <raycast.ry8                     ; |rd| >> 7
        ldd   <raycast.ary
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        andb  #$FE
        ldd   d,x
        std   <raycast.dy
        lda   <raycast.fyp
        bne   raycast.ym
        ldd   <raycast.dy
        bra   raycast.ys
raycast.yn  nega
        negb
        sbca  #0
        std   <raycast.ary
        lslb
        rola
        sta   <raycast.ry8                     ; |rd| >> 7
        ldd   <raycast.ary
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        andb  #$FE
        ldd   d,x
        std   <raycast.dy
        ldb   <raycast.q
        addb  #4
        stb   <raycast.q
        lda   <raycast.fyn
        bne   raycast.ym
        clrb
        bra   raycast.ys
raycast.ym  sta   <raycast.f
        ldb   <raycast.dy+1
        mul
        sta   <raycast.t
        lda   <raycast.f
        ldb   <raycast.dy
        mul
        addb  <raycast.t
        adca  #0
raycast.ys  std   <raycast.sy
        ; ---- the quadrant's loop, its operands, go
        ldx   #raycast.loops
        ldb   <raycast.q
        ldu   b,x
        ldd   <raycast.sy
        std   raycast.CMP,u
        ldd   <raycast.dx
        std   raycast.LEA,u
        ldd   <raycast.dy
        std   raycast.ADD,u
        ldy   <raycast.sx
        ldx   <raycast.cell0
        jmp   ,u

;-------------------------------------------------------------------------------
; raycast.unit.move : B = the step along the camera's direction, signed, in
; 1/256 cell (forward when positive). The camera moves where the map lets
; it, raycast.RADIUS from any wall, x then y : it slides along a wall.
;-------------------------------------------------------------------------------
raycast.unit.move
        pshs  dp,b
        leax  raycast.vars,pcr
        tfr   x,d
        tfr   a,dp
        puls  b
        bsr   raycast.move1
        puls  dp,pc
raycast.move1
        tstb
        bmi   @back
        bne   @fwd
        rts
@fwd    stb   <raycast.mv
        ldd   >raycast.in+8
        bsr   raycast.scale
        std   <raycast.mx
        ldd   >raycast.in+10
        bsr   raycast.scale
        std   <raycast.my
        bra   @go
@back   negb
        stb   <raycast.mv
        ldd   >raycast.in+8
        bsr   raycast.scale
        nega
        negb
        sbca  #0
        std   <raycast.mx
        ldd   >raycast.in+10
        bsr   raycast.scale
        nega
        negb
        sbca  #0
        std   <raycast.my
@go     ; x first : the cell ahead of the new x, at the radius
        ldd   >raycast.x
        addd  <raycast.mx
        std   <raycast.nx
        tst   <raycast.mx
        bmi   @xl
        addd  #raycast.RADIUS
        bra   @xc
@xl     subd  #raycast.RADIUS
@xc     tfr   a,b                          ; the column
        lda   >raycast.y                       ; the row
        bsr   raycast.cell
        bne   @ydo
        ldd   <raycast.nx
        std   >raycast.x
@ydo    ldd   >raycast.y
        addd  <raycast.my
        std   <raycast.ny
        tst   <raycast.my
        bmi   @yl
        addd  #raycast.RADIUS
        bra   @yc
@yl     subd  #raycast.RADIUS
@yc     ldb   >raycast.x                       ; the column
        bsr   raycast.cell
        bne   @rts
        ldd   <raycast.ny
        std   >raycast.y
@rts    rts

raycast.cell                                   ; A row, B column -> B the cell, Z
        pshs  b
        ldb   #raycast.MAP_W
        mul
        addb  ,s+
        adca  #0
        addd  #raycast.map
        tfr   d,x
        ldb   ,x
        rts

raycast.scale                                  ; D s1.14 -> D x MOVE >> 14, 8.8
        pshs  cc
        tsta
        bpl   @a
        nega
        negb
        sbca  #0
@a      ldb   <raycast.mv                      ; |dir| high byte x the step >> 6
        mul
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        puls  cc
        bpl   @r
        nega
        negb
        sbca  #0
@r      rts

        _raycast.tables

 ENDSECTION
