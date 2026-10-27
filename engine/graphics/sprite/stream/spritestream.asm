* ---------------------------------------------------------------------------
* spritestream : sprites drawn from streams (bm4s), the runtime
* ---------------------------------------------------------------------------
* The builder's <spritestream> writes each sprite as a record and streams of
* masked row segments (in pages, under the cart window), and the walkers that
* draw them (genwalker). This file is the rest of the manager : the draw
* entries, the clip mode, the restore and the save stack. It is assembled
* with the generated walkers, in a unit of its own placed in the video half
* page $4000-$5FFF, one copy in each half : gfxlock mounts the half of the
* buffer it draws (PRC bit 0), so each buffer finds its own save stack there.
* The data window holds the back buffer (RAMB $A000, RAMA $C000), the cart
* window the record's page : neither may hold this code.
*
* The game declares :
*   spritestream.HALF   0 or 1 : the half this copy is assembled for
*   spritestream.dp     8 bytes of the direct page (DP $9F) : the tops of the
*                       two save stacks, the clip rectangle
*   spritestream.STACK  bytes of each save stack (default 768) : the most a
*                       buffer saves between two restores, plus what an
*                       interrupt pushes on S while a walker runs
*
* Record (8 bytes, in the sprite's page) : stream of the picture, stream of
* the picture 2 pixels right, box bytes of each, height, mirror flag (the
* mirror of each stream lands on the other's 2 pixel step) ; with the
* walkers' guard (spritestream.GUARD), 2 words more : what its draw saves,
* whole (exactly) and cut by drawClip (at most).
*
* Guard : a draw whose saves the stack could not hold below its top (less
* spritestream.IRQ bytes, default 12, for an interrupt's pushes) is not
* drawn : spritestream.skips counts it, the screen is left as it was.
*
* A frame, inside the loop's gfxlock section : spritestream.restore first
* (the bytes the draws of this buffer's last frame saved, put back), then the
* draws. After a cut (both buffers redrawn) : spritestream.init.
*
* Entries (DP $9F ; A, B, X, Y, U and CC lost, DP kept) :
*   spritestream.init      the save stacks of both buffers emptied
*   spritestream.restore   the buffer's saved bytes put back, last draw first
*   spritestream.draw      A = record page ($E7E6 value), B = facing (0 the
*                          stored one, else mirrored), X = x of the left edge
*                          (0-318, even), Y = top line (0-255), U = record
*   spritestream.drawAt    (unless spritestream.DRAWAT is 0)
*                          A = record page, B = facing (bit 0) + 2 x step
*                          (bit 1 : x mod 4 = 2), Y = screen address of the
*                          box's first byte on its top line, U = record
*   spritestream.drawClip  as draw, X and Y signed : only the part inside
*                          the clip rectangle (spritestream.clipLeft, Right :
*                          screen bytes 0-80, clipTop, Bottom : lines 0-200,
*                          right and bottom excluded) ; a box wholly inside
*                          takes the draw path
* The caller's cart page is given back.
* ---------------------------------------------------------------------------

 IFNDEF spritestream.HALF
        ERROR "spritestream : the game declares spritestream.HALF (0 or 1), the half page of this copy"
 ENDC
 IFNDEF spritestream.STACK
spritestream.STACK equ 768
 ENDC
 IFNDEF spritestream.GUARD
spritestream.GUARD equ 0
 ENDC
 IFNDEF spritestream.IRQ
spritestream.IRQ equ 12
 ENDC
 IFNDEF spritestream.DRAWAT
spritestream.DRAWAT equ 1                    ; 0 : drawAt left out (its bytes to the save stack)
 ENDC

        INCLUDE "engine/graphics/sprite/stream/spritestream.const.asm"
 IFEQ spritestream.HALF
spritestream.top        equ spritestream.top0
 ELSE
spritestream.top        equ spritestream.top1
 ENDC

spritestream.saveS      equ dp_engine           ; word - the caller's S while a walker runs
spritestream.jtk        equ dp_engine+2         ; byte - mirrored walk : its jump table
spritestream.page       equ dp_engine+3         ; byte - the caller's cart page
spritestream.facing     equ dp_engine+4         ; byte
spritestream.flag       equ dp_engine+5         ; byte - the record's mirror flag
spritestream.line       equ dp_engine+6         ; word - 40 x (top line - 1)
spritestream.stream     equ dp_engine+8         ; word
spritestream.n          equ dp_engine+10        ; byte - box bytes of the stream drawn
spritestream.kp         equ dp_engine+11        ; byte - 0 : the box starts on RAMA, 2 : on RAMB

* ---------------------------------------------------------------------------
* spritestream.init : both save stacks emptied (their bottom record left)
* ---------------------------------------------------------------------------

spritestream.init
 IFNE spritestream.SAVE
        ldd   #spritestream.stack.end
        std   <spritestream.top0
        std   <spritestream.top1
 ENDC
        rts

* ---------------------------------------------------------------------------
* spritestream.draw
* ---------------------------------------------------------------------------

spritestream.draw
        pshs  a
        lda   map.CF74021.CART
        sta   <spritestream.page    ; the caller's page
        puls  a
        sta   map.CF74021.CART      ; the record's
        stb   <spritestream.facing
spritestream.draw.mounted
 IFNE spritestream.GUARD
        ldd   <spritestream.top
        subd  8,u                   ; what this draw saves
        cmpd  #spritestream.stack+spritestream.IRQ
        lblo  spritestream.skip     ; the stack cannot hold it
 ENDC
        lda   7,u
        sta   <spritestream.flag
        tfr   y,d
        lda   #40
        mul
        subd  #40
        std   <spritestream.line    ; the walker steps one row down first
        tfr   x,d
        lsra
        rorb
        lsrb                        ; B = screen byte, C = 2 pixel step
        rola
 IFNE spritestream.MIRRORABLE
        tst   <spritestream.facing
        beq   @p
        eora  <spritestream.flag    ; mirrored : the stream whose mirror has that step
 ENDC
@p      asla
        ldx   a,u
        stx   <spritestream.stream
        lsra
        adda  #4
        lda   a,u
        sta   <spritestream.n
        clra
        lsrb                        ; D = column, C = plane of the first byte
        bcs   @odd
        addd  #$C000
        addd  <spritestream.line
        tfr   d,y                   ; plane 0 in RAMA
        clr   <spritestream.kp
        bra   @set
@odd    addd  #$A000
        addd  <spritestream.line
        tfr   d,y                   ; plane 0 in RAMB
        lda   #2
        sta   <spritestream.kp
@set    ldu   <spritestream.stream
 IFNE spritestream.MIRRORABLE
        tst   <spritestream.facing
        bne   @mirror
 ENDC
        ldx   #spritestream.jtn
        ldb   <spritestream.kp
        ldx   b,x
        jsr   spritestream.wn.draw
 IFNE spritestream.MIRRORABLE
        bra   @end
@mirror lda   <spritestream.n
        deca
        lsra                        ; (N-1)/2, C = (N-1) & 1
        leay  a,y                   ; the mirrored first column
        lda   <spritestream.kp
        adca  #1                    ; table 1 + 2 plane parity + width parity
        sta   <spritestream.jtk
        ldx   #spritestream.rev
        jsr   spritestream.wm.draw
 ENDC
@end    lda   <spritestream.page
        sta   map.CF74021.CART
        rts

 IFNE spritestream.GUARD
spritestream.skip                   ; a draw the save stack cannot hold
        inc   spritestream.skips
        lda   <spritestream.page
        sta   map.CF74021.CART
        rts
 ENDC

 IFNE spritestream.DRAWAT
* ---------------------------------------------------------------------------
* spritestream.drawAt
* ---------------------------------------------------------------------------

spritestream.drawAt
        pshs  a
        lda   map.CF74021.CART
        sta   <spritestream.page
        puls  a
        sta   map.CF74021.CART
 IFNE spritestream.GUARD
        pshs  b
        ldd   <spritestream.top
        subd  8,u
        cmpd  #spritestream.stack+spritestream.IRQ
        puls  b                     ; (PULS keeps the flags)
        lblo  spritestream.skip
 ENDC
        tfr   b,a
        anda  #1
        sta   <spritestream.facing
        lsrb                        ; B = step
 IFNE spritestream.MIRRORABLE
        tsta
        beq   @p
        eorb  7,u
 ENDC
@p      aslb
        ldx   b,u
        stx   <spritestream.stream
        lsrb
        addb  #4
        ldb   b,u
        stb   <spritestream.n
        leay  -40,y                 ; one row up
        clrb
        cmpy  #$C000-40
        bhs   @k                    ; RAMA : the box starts on an even byte
        ldb   #2
@k      stb   <spritestream.kp
        ldu   <spritestream.stream
 IFNE spritestream.MIRRORABLE
        tsta
        bne   @mirror
 ENDC
        ldx   #spritestream.jtn
        ldx   b,x
        jsr   spritestream.wn.draw
 IFNE spritestream.MIRRORABLE
        bra   @end
@mirror lda   <spritestream.n
        deca
        lsra
        leay  a,y
        lda   <spritestream.kp
        adca  #1
        sta   <spritestream.jtk
        ldx   #spritestream.rev
        jsr   spritestream.wm.draw
 ENDC
@end    lda   <spritestream.page
        sta   map.CF74021.CART
        rts

 ENDC

 IFNE spritestream.CLIP
* ---------------------------------------------------------------------------
* spritestream.drawClip
* ---------------------------------------------------------------------------
* A box inside the clip rectangle (with the wider of its two streams) takes
* the draw path : 78 cycles more than spritestream.draw. A crossing box is
* walked with the clip tables : each record goes to a clip handler, which
* draws a whole visible record by its routine, skips a hidden one, draws the
* visible bytes of a cut one by a tight loop (saved as it draws them, one
* restore record a row), and ends the walk on the first record below the
* clip. cl.nrow is the address of the next row's column 0 on plane 0 (Y's
* column : Y - cl.nrow + 40), box bytes count from the box's left (0 to N-1) ;
* the visible rows are an address range, [cl.atop, cl.abot). The walk
* keeps its state in the direct page : the draw's own bytes from
* spritestream.facing to spritestream.kp are free during it.

spritestream.cl.nr      equ dp_engine+4         ; byte - a cut record : its visible rows (left)
spritestream.cl.sk      equ dp_engine+5         ; byte - its rows above the clip, else 0
spritestream.cl.y       equ dp_engine+6         ; word - its Y
spritestream.cl.sh      equ dp_engine+8         ; word - its shape
spritestream.cl.ja      equ dp_engine+10        ; byte - its first visible box byte
spritestream.cl.nb      equ dp_engine+11        ; byte - its visible bytes a row
spritestream.cl.nrow    equ dp_engine+12        ; word - the next row's column 0, plane 0 (setup : row 0's)
spritestream.cl.real    equ dp_engine+14        ; word - stored : the drawing jump table
spritestream.cl.q       equ dp_engine+14        ; byte - mirrored : (N-1) & 1
spritestream.cl.k       equ dp_engine+15        ; byte - mirrored : the drawing jump table
spritestream.cl.atop    equ dp_engine+16        ; word - the first visible row's column 0, plane 0
spritestream.cl.abot    equ dp_engine+18        ; word - the first row below the clip's
spritestream.cl.jl      equ dp_engine+20        ; byte - visible box bytes [jl, jr)
spritestream.cl.jr      equ dp_engine+21        ; byte
spritestream.cl.code    equ dp_engine+22        ; byte - the record's code
spritestream.cl.lo      equ dp_engine+23        ; byte - its leftmost box byte
spritestream.cl.nc      equ dp_engine+24        ; byte - a cut row : bytes left
spritestream.cl.t       equ dp_engine+25        ; byte - a mirrored byte's data
spritestream.cl.scr     equ dp_engine+26        ; word - its screen address
spritestream.cl.safe    equ dp_engine+28        ; word - cl.abot less MAXROWS - 1 rows : above, a record's rows are visible

spritestream.cl.x       rmb   2                 ; x, signed
spritestream.cl.y0      rmb   2                 ; top line, signed
spritestream.cl.k0      rmb   2                 ; first screen byte, signed
spritestream.cl.h       rmb   1                 ; rows of the box
spritestream.cl.m       rmb   1                 ; clamp bound
spritestream.cl.rt      rmb   1                 ; visible rows [rt, rb)
spritestream.cl.rb      rmb   1
spritestream.cl.ofs     rmb   2                 ; plane 1 - plane 0
spritestream.cl.t16     rmb   2
spritestream.cl.dir     rmb   1                 ; the walk : 0 stored, 1 mirrored
spritestream.cl.ent0    rmb   2                 ; its cut loop's entry for an even box byte
spritestream.cl.ent1    rmb   2                 ; for an odd one
spritestream.cl.u       rmb   2                 ; a cut record : its payload
spritestream.cl.rl      rmb   1                 ; its rows left to count
spritestream.cl.xa      rmb   2                 ; its row's first visible byte
spritestream.cl.ya      rmb   2                 ; its first visible byte's pair of offsets
spritestream.cl.ent     rmb   2                 ; its cut loop's entry

spritestream.drawClip
        pshs  a
        lda   map.CF74021.CART
        sta   <spritestream.page
        puls  a
        sta   map.CF74021.CART
        stb   <spritestream.facing
        tfr   x,d                   ; inside, with the wider stream (N1) : the draw path
        asra
        rorb
        asra
        rorb                        ; D = x / 4
        tsta
        bne   @cut                  ; left of the screen, or past it
        cmpb  <spritestream.clipLeft
        blo   @cut
        addb  5,u
        bcs   @cut
        cmpb  <spritestream.clipRight
        bhi   @cut
        tfr   y,d
        tsta
        bne   @cut
        cmpb  <spritestream.clipTop
        blo   @cut
        addb  6,u
        bcs   @cut
        cmpb  <spritestream.clipBottom
        bhi   @cut
        jmp   spritestream.draw.mounted
@cut
 IFNE spritestream.GUARD
        ldd   <spritestream.top
        subd  10,u                  ; the most a cut draw saves
        cmpd  #spritestream.stack+spritestream.IRQ
        lblo  spritestream.skip
 ENDC
        stx   spritestream.cl.x
        sty   spritestream.cl.y0
        tfr   x,d
        andb  #2
        lsrb                        ; the 2 pixel step
 IFNE spritestream.MIRRORABLE
        tst   <spritestream.facing
        beq   @p
        eorb  7,u
 ENDC
@p      aslb
        ldx   b,u
        stx   <spritestream.stream
        lsrb
        addb  #4
        ldb   b,u
        stb   <spritestream.n
        lda   6,u
        sta   spritestream.cl.h
        ldd   spritestream.cl.x
        asra
        rorb
        asra
        rorb
        std   spritestream.cl.k0    ; x / 4, signed
        lda   <spritestream.n       ; the visible box bytes and rows, clamped to the box
        sta   spritestream.cl.m
        clra
        ldb   <spritestream.clipLeft
        subd  spritestream.cl.k0
        bsr   @clamp
        stb   <spritestream.cl.jl
        clra
        ldb   <spritestream.clipRight
        subd  spritestream.cl.k0
        bsr   @clamp
        stb   <spritestream.cl.jr
        lda   spritestream.cl.h
        sta   spritestream.cl.m
        clra
        ldb   <spritestream.clipTop
        subd  spritestream.cl.y0
        bsr   @clamp
        stb   spritestream.cl.rt
        clra
        ldb   <spritestream.clipBottom
        subd  spritestream.cl.y0
        bsr   @clamp
        stb   spritestream.cl.rb
        lda   <spritestream.cl.jl
        cmpa  <spritestream.cl.jr
        bhs   @none                 ; nothing visible
        lda   spritestream.cl.rt
        cmpa  spritestream.cl.rb
        bhs   @none
        ora   <spritestream.cl.jl
        bne   @clip
        lda   <spritestream.cl.jr
        cmpa  <spritestream.n
        bne   @clip
        lda   spritestream.cl.rb
        cmpa  spritestream.cl.h
        bne   @clip
        ldx   spritestream.cl.x     ; wholly visible : the draw path
        ldy   spritestream.cl.y0
        jmp   spritestream.draw.mounted
@none   lda   <spritestream.page
        sta   map.CF74021.CART
        rts
@clamp  tsta                        ; D signed -> B in [0, cl.m]
        bmi   @zero
        bne   @max
        cmpb  spritestream.cl.m
        bls   @ok
@max    ldb   spritestream.cl.m
@ok     rts
@zero   clrb
        rts
@clip   ldd   spritestream.cl.k0
        ldx   #-$2000               ; plane 1 - plane 0 : the box starts on RAMA
        asra
        rorb                        ; D = column of the first byte, C = its plane
        bcc   @even
        ldx   #$2001                ; on RAMB
        addd  #$A000-$C000
@even   addd  #$C000
        std   <spritestream.cl.nrow
        stx   spritestream.cl.ofs
        tfr   x,d
        aslb                        ; 0 or 2
        stb   <spritestream.kp
        ldd   spritestream.cl.y0    ; + 40 x top line, signed
        aslb
        rola
        aslb
        rola
        aslb
        rola
        std   spritestream.cl.t16
        aslb
        rola
        aslb
        rola
        addd  spritestream.cl.t16
        addd  <spritestream.cl.nrow
        std   <spritestream.cl.nrow  ; row 0, column 0, plane 0
        lda   #40                   ; the visible rows' addresses
        ldb   spritestream.cl.rt
        mul
        addd  <spritestream.cl.nrow
        std   <spritestream.cl.atop
        lda   #40
        ldb   spritestream.cl.rb
        mul
        addd  <spritestream.cl.nrow
        std   <spritestream.cl.abot
        subd  #40*(spritestream.MAXROWS-1)
        std   <spritestream.cl.safe
        ldd   <spritestream.cl.nrow
        addd  #40
        std   <spritestream.cl.nrow ; the walk : the current row is row 0
        clr   <spritestream.cl.sk
        ldd   #spritestream.clip.sa ; the cut loop's entries : facing, plane of box byte 0
        ldx   #spritestream.clip.sb
 IFNE spritestream.MIRRORABLE
        clr   spritestream.cl.dir
        tst   <spritestream.facing
        beq   @k
        inc   spritestream.cl.dir
        ldd   #spritestream.clip.ma
        ldx   #spritestream.clip.mb
@k
 ENDC
        tst   <spritestream.kp
        beq   @e
        exg   d,x                   ; box byte 0 on RAMB
@e      std   spritestream.cl.ent0
        stx   spritestream.cl.ent1
        ldu   <spritestream.stream
 IFNE spritestream.MIRRORABLE
        tst   <spritestream.facing
        bne   @mirror
 ENDC
        ldx   #spritestream.jtn
        ldb   <spritestream.kp
        ldx   b,x
        stx   <spritestream.cl.real
        ldd   <spritestream.cl.nrow
        subd  #80
        tfr   d,y                   ; the walker steps one row down first
        ldx   #spritestream.jtc
        jsr   spritestream.wn.draw
 IFNE spritestream.MIRRORABLE
        bra   @end
@mirror lda   <spritestream.n
        deca
        lsra
        pshs  a                     ; (N-1)/2
        ldb   #0
        rolb
        stb   <spritestream.cl.q    ; (N-1) & 1
        addb  <spritestream.kp
        incb
        stb   <spritestream.cl.k    ; the drawing table
        lda   #spritestream.CLIPK
        sta   <spritestream.jtk
        ldd   <spritestream.cl.nrow
        subd  #80
        addb  ,s+
        adca  #0
        tfr   d,y
        ldx   #spritestream.rev
        jsr   spritestream.wm.draw
 ENDC
@end    lda   <spritestream.page
        sta   map.CF74021.CART
        rts

* the clip handlers : the record's code in A (stored) or B (mirrored), Y moved
* to it, U on its payload, S the save stack. A record is whole when its rows
* are visible and its box bytes [lo, lo + n) are : its routine draws it with
* Y and U kept ; the others go to clip.part (rows visible) or clip.partv,
* with B = lo.

spritestream.clipStored
        sta   <spritestream.cl.code
        tfr   y,d
        subd  <spritestream.cl.nrow ; negative on the current row
        bge   @rows
@c      addb  #40                   ; Y's column
        ldx   #spritestream.shapes
        lda   <spritestream.cl.code
        leax  a,x                   ; 2 bytes a code
        aslb                        ; 2 x column + p : the record's first box byte
        addb  ,x
        cmpy  <spritestream.cl.atop
        blo   @v                    ; its first row above the clip
        cmpy  <spritestream.cl.safe
        bhs   @low
@h      cmpb  <spritestream.cl.jl
        blo   @part
        addb  1,x
        cmpb  <spritestream.cl.jr
        bhi   @cut
        ldx   <spritestream.cl.real ; whole : its routine, the clip table kept in X
        lda   <spritestream.cl.code
        ldx   a,x
        pshs  x
        ldx   #spritestream.jtc
        rts
@cut    subb  1,x
@part   jmp   spritestream.clip.part
@low    jsr   spritestream.clip.low
        bcs   @h
@v      jmp   spritestream.clip.partv
@rows   ldx   <spritestream.cl.nrow ; the current row moves down to Y's
@r      leax  40,x
        subd  #40
        bge   @r
        stx   <spritestream.cl.nrow
        bra   @c

 IFNE spritestream.MIRRORABLE
spritestream.clipMirrored
        stb   <spritestream.cl.code
        tfr   y,d
        subd  <spritestream.cl.nrow
        bge   @rows
@c      addb  #40
        ldx   #spritestream.shapes
        lda   <spritestream.cl.code
        leax  a,x
        aslb                        ; 2 x column + the plane of the mirrored first byte
        addb  ,x
        eorb  <spritestream.cl.q
        subb  1,x
        incb                        ; its leftmost box byte (drawn leftwards)
        cmpy  <spritestream.cl.atop
        blo   @v
        cmpy  <spritestream.cl.safe
        bhs   @low
@h      cmpb  <spritestream.cl.jl
        blo   @part
        addb  1,x
        cmpb  <spritestream.cl.jr
        bhi   @cut
        ldx   #spritestream.rev     ; whole : its routine
        lda   <spritestream.cl.k
        ldb   <spritestream.cl.code
        ldx   d,x
        pshs  x
        ldx   #spritestream.rev
        rts
@cut    subb  1,x
@part   jmp   spritestream.clip.part
@low    jsr   spritestream.clip.low
        bcs   @h
@v      jmp   spritestream.clip.partv
@rows   ldx   <spritestream.cl.nrow
@r      leax  40,x
        subd  #40
        bge   @r
        stx   <spritestream.cl.nrow
        bra   @c
 ENDC

* a record near the clip's bottom (Y at cl.safe or past it), X its shape :
* the walk ends at the first record below the clip ; C set when all its rows
* are visible (A lost, B kept)
spritestream.clip.low
        cmpy  <spritestream.cl.abot
        bhs   @end
        pshs  b
        lda   spritestream.ROWS,x
        ldb   #40
        mul
        addd  <spritestream.cl.nrow
        subd  #80                   ; its last row
        subd  <spritestream.cl.abot
        puls  b,pc
@end    leas  2,s                   ; the handler's return
        jmp   spritestream.wn.end

* a cut or hidden record whose rows are visible : B its leftmost box byte, X
* its shape, Y and U as at the handler. Its visible bytes are drawn row by
* row, left to right, by a tight loop (clip.sa, sb ; mirrored ma, mb) : X the
* screen byte (the plane steps alternate : RAMA to RAMB -$2000, RAMB to the
* next column's RAMA +$2001), Y the byte's pair in the offsets table (its
* mask and data in the row's payload ; mirrored, read backwards), U the row's
* payload. The bytes of a row are saved as it draws them, then one restore
* record for them : RCLIP, its last byte's address, their count (one byte :
* RBYTE and its address).
spritestream.clip.part
        lda   spritestream.ROWS,x
        sta   <spritestream.cl.nr   ; all its rows
spritestream.clip.cols              ; B = lo, cl.nr its visible rows, cl.sk the rows above them
        stb   <spritestream.cl.lo
        cmpb  <spritestream.cl.jl   ; visible box bytes [ja, jb) : [max(lo, jl), min(lo + n, jr))
        bhs   @a
        ldb   <spritestream.cl.jl
@a      stb   <spritestream.cl.ja
        lda   <spritestream.cl.lo
        adda  1,x
        cmpa  <spritestream.cl.jr
        bls   @b
        lda   <spritestream.cl.jr
@b      suba  <spritestream.cl.ja
        bls   @hid                  ; none
        sta   <spritestream.cl.nb
        sty   <spritestream.cl.y
        stu   spritestream.cl.u
        stx   <spritestream.cl.sh
        ldy   <spritestream.cl.nrow
        leay  -40,y                 ; the current row
        lda   <spritestream.cl.sk
        beq   @e
        ldb   spritestream.ROWS+1,x ; past the rows above the clip : their payload and lines
        mul
        leau  d,u
        lda   #40
        ldb   <spritestream.cl.sk
        clr   <spritestream.cl.sk
        mul
        leay  d,y
        ldb   <spritestream.cl.ja
@e      lsrb                        ; ja : its column, C its plane
        leay  b,y
        bcs   @odd
        ldd   spritestream.cl.ent0
        bra   @f
@odd    ldd   spritestream.cl.ofs
        leay  d,y
        ldd   spritestream.cl.ent1
@f      std   spritestream.cl.ent
        sty   spritestream.cl.xa
        ldb   <spritestream.cl.ja
        subb  <spritestream.cl.lo   ; stored : ja - lo, its pair
 IFNE spritestream.MIRRORABLE
        tst   spritestream.cl.dir
        beq   @g
        negb
        addb  1,x                   ; mirrored : n - (ja - lo), the pair after its
 ENDC
@g      lda   <spritestream.cl.code
        ldx   #spritestream.offsets
        ldx   a,x
        abx
        abx
        stx   spritestream.cl.ya
        bra   spritestream.clip.row
@hid    clr   <spritestream.cl.sk
        jmp   spritestream.clip.skip
spritestream.clip.row
        lda   <spritestream.cl.nb
        sta   <spritestream.cl.nc
        ldx   spritestream.cl.xa
        ldy   spritestream.cl.ya
        jmp   [spritestream.cl.ent]

spritestream.clip.sa                ; stored, a RAMA byte
 IFNE spritestream.SAVE
        ldb   ,x
        pshs  b
 ENDC
        ldd   ,y++
        lda   a,u
        anda  ,x
        ora   b,u
        sta   ,x
        dec   <spritestream.cl.nc
        beq   spritestream.clip.eol
        leax  -$2000,x
spritestream.clip.sb                ; a RAMB byte
 IFNE spritestream.SAVE
        ldb   ,x
        pshs  b
 ENDC
        ldd   ,y++
        lda   a,u
        anda  ,x
        ora   b,u
        sta   ,x
        dec   <spritestream.cl.nc
        beq   spritestream.clip.eol
        leax  $2001,x
        bra   spritestream.clip.sa
spritestream.clip.eol
 IFNE spritestream.SAVE
        lda   <spritestream.cl.nb   ; the row's restore record, X its last byte :
        deca
        bne   @n
        ldb   #spritestream.RBYTE   ; one byte
        bra   @r
@n      inca
        pshs  a                     ; or the count of its bytes
        ldb   #spritestream.RCLIP
@r      pshs  x,b
 ENDC
        dec   <spritestream.cl.nr   ; the next row
        beq   spritestream.clip.done
        ldx   <spritestream.cl.sh
        ldb   spritestream.ROWS+1,x
        leau  b,u
        ldd   spritestream.cl.xa
        addd  #40
        std   spritestream.cl.xa
        bra   spritestream.clip.row
 IFNE spritestream.MIRRORABLE
spritestream.clip.ma                ; mirrored, a RAMA byte
        stx   <spritestream.cl.scr
        ldd   ,--y
        ldx   #spritestream.rev
        ldb   b,u
        lda   a,u
        ldb   b,x
        lda   a,x                   ; its pixels reversed
        ldx   <spritestream.cl.scr
        stb   <spritestream.cl.t
  IFNE spritestream.SAVE
        ldb   ,x
        pshs  b
  ENDC
        anda  ,x
        ora   <spritestream.cl.t
        sta   ,x
        dec   <spritestream.cl.nc
        beq   spritestream.clip.eol
        leax  -$2000,x
spritestream.clip.mb                ; a RAMB byte
        stx   <spritestream.cl.scr
        ldd   ,--y
        ldx   #spritestream.rev
        ldb   b,u
        lda   a,u
        ldb   b,x
        lda   a,x
        ldx   <spritestream.cl.scr
        stb   <spritestream.cl.t
  IFNE spritestream.SAVE
        ldb   ,x
        pshs  b
  ENDC
        anda  ,x
        ora   <spritestream.cl.t
        sta   ,x
        dec   <spritestream.cl.nc
        beq   spritestream.clip.eol
        leax  $2001,x
        bra   spritestream.clip.ma
 ENDC
spritestream.clip.done
        ldu   spritestream.cl.u
        ldx   <spritestream.cl.sh
        ldy   <spritestream.cl.y
spritestream.clip.skip              ; past the record : X its shape, Y and U as at the handler
        ldb   spritestream.ROWS+1,x
        lda   spritestream.ROWS,x
        deca
        bne   @rows
        leau  b,u                   ; one row
        bra   @next
@rows   deca
        bne   @more
        aslb                        ; two
        leau  b,u
        bra   @next
@more   adda  #2
        mul
        leau  d,u
        lda   spritestream.ROWS,x   ; 3 rows or more : the walk ends on the last
        deca
        ldb   #40
        mul
        leay  d,y
@next
 IFNE spritestream.MIRRORABLE
        tst   spritestream.cl.dir
        bne   @nm
        leau  1,u                   ; the next record's mirrored delta
 ENDC
        ldx   #spritestream.jtc
        pulu  d
        leay  b,y
        jmp   [a,x]
 IFNE spritestream.MIRRORABLE
@nm     ldx   #spritestream.rev
        ldd   ,u
        leay  a,y
        lda   <spritestream.jtk
        leau  3,u
        jmp   [d,x]
 ENDC

* a record with rows outside the clip : B its leftmost box byte, X its shape,
* Y and U as at the handler : its rows above the clip (cl.sk) skipped, the
* ones below it cut, then as clip.part
spritestream.clip.partv
        pshs  b
        lda   spritestream.ROWS,x
        sta   spritestream.cl.rl    ; rows left
        clr   <spritestream.cl.nr
        ldd   <spritestream.cl.nrow
        subd  #40                   ; its first row
@a      cmpd  <spritestream.cl.atop
        bhs   @b
        inc   <spritestream.cl.sk   ; above the clip
        addd  #40
        dec   spritestream.cl.rl
        bne   @a
        bra   @hid
@b      cmpd  <spritestream.cl.abot
        bhs   @c
        inc   <spritestream.cl.nr   ; inside
        addd  #40
        dec   spritestream.cl.rl
        bne   @b
@c      tst   <spritestream.cl.nr
        beq   @hid
        puls  b
        jmp   spritestream.clip.cols
@hid    clr   <spritestream.cl.sk
        puls  b
        jmp   spritestream.clip.skip
 ENDC

* ---------------------------------------------------------------------------
* the save stack of this half : it grows down from its bottom record
* ---------------------------------------------------------------------------

 IFNE spritestream.GUARD
spritestream.skips      fcb   0                 ; the draws skipped (wraps)
 ENDC
 IFNE spritestream.SAVE
spritestream.stack      rmb   spritestream.STACK
spritestream.stack.end  fcb   spritestream.REND,0,0 ; the restore walker's end
 ENDC
