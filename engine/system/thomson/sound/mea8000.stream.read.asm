map.CF74021.CART EXTERNAL ; cartridge window page register

 SECTION code

; ============================================================================
; MEA8000 stream player (polling), a stream spread over RAM pages
; ============================================================================
; Plays a stream of speech files longer than one page: the stream is cut into
; blocks at speech-file boundaries, one block per RAM page, each loaded by the
; builder into the cartridge window ($0000-$3FFF on TO8). A table describes
; the blocks, 5 bytes each:
;   register : 1 byte, the value that maps the block's page into the window
;              (page | map.RAM_OVER_CART, as the builder's tables write it)
;   address  : 2 bytes, the block's address in the window
;   length   : 2 bytes, the block's length
; A register byte of 0 ends the table. The caller's page is restored.
; Needs mea8000.file.read (mea8000.file.read.asm). Blocking.
;
; input: [X] address of the block table
; ----------------------------------------------------------------------------
mea8000.stream.read
        pshs  d,x,y,u
        lda   map.CF74021.CART
        pshs  a               ; the caller's page
        tfr   x,u
@block  lda   ,u+
        beq   @done
        sta   map.CF74021.CART ; the block's page into the window
        ldx   ,u++            ; the block's address
        ldd   ,u++            ; its length
        leay  d,x             ; Y = end of the block
@file   jsr   mea8000.file.read
        ldd   ,x
        leax  d,x             ; X = the next file
        pshs  y
        cmpx  ,s++
        blo   @file
        bra   @block
@done   puls  a
        sta   map.CF74021.CART
        puls  d,x,y,u,pc

 ENDSECTION
