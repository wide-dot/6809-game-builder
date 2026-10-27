* ---------------------------------------------------------------------------
* spritestream : sprites drawn from streams (bm4s), the runtime
* ---------------------------------------------------------------------------
* The builder's <spritestream> writes each sprite as a record and streams of
* masked row segments (in pages, under the cart window), and the walkers that
* draw them (genwalker). This file is the rest of the manager : the draw
* entries, the restore and the save stack. It is assembled
* with the generated walkers, in a unit of its own placed in the video half
* page $4000-$5FFF, one copy in each half : gfxlock mounts the half of the
* buffer it draws (PRC bit 0), so each buffer finds its own save stack there.
* The data window holds the back buffer (RAMB $A000, RAMA $C000), the cart
* window the record's page : neither may hold this code.
*
* The game declares :
*   spritestream.HALF   0 or 1 : the half this copy is assembled for
*   spritestream.dp     4 bytes of the direct page (DP $9F) : the tops of the
*                       two save stacks
*   spritestream.STACK  bytes of each save stack (default 768) : the most a
*                       buffer saves between two restores, plus what an
*                       interrupt pushes on S while a walker runs
*
* Record (8 bytes, in the sprite's page) : stream of the picture, stream of
* the picture 2 pixels right, box bytes of each, height, mirror flag (the
* mirror of each stream lands on the other's 2 pixel step).
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
*   spritestream.drawAt    A = record page, B = facing (bit 0) + 2 x step
*                          (bit 1 : x mod 4 = 2), Y = screen address of the
*                          box's first byte on its top line, U = record
* The caller's cart page is given back.
* ---------------------------------------------------------------------------

 IFNDEF spritestream.HALF
        ERROR "spritestream : the game declares spritestream.HALF (0 or 1), the half page of this copy"
 ENDC
 IFNDEF spritestream.STACK
spritestream.STACK equ 768
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

* ---------------------------------------------------------------------------
* spritestream.drawAt
* ---------------------------------------------------------------------------

spritestream.drawAt
        pshs  a
        lda   map.CF74021.CART
        sta   <spritestream.page
        puls  a
        sta   map.CF74021.CART
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

* ---------------------------------------------------------------------------
* the save stack of this half : it grows down from its bottom record
* ---------------------------------------------------------------------------

 IFNE spritestream.SAVE
spritestream.stack      rmb   spritestream.STACK
spritestream.stack.end  fcb   spritestream.REND,0,0 ; the restore walker's end
 ENDC
