* ---------------------------------------------------------------------------
* wallscaler : the columns unit
* ---------------------------------------------------------------------------
* Draws the frame's column descriptors by compiled scalers, a routine a
* wall height (the builder's <wallscaler form="scalers">).
*
* Assembled after the builder's <wallscaler form="columns"> (constants,
* _wallscaler.blocks, _wallscaler.fill), one copy in each half of the video
* half page $4000-$5FFF : gfxlock mounts the half of the buffer it draws,
* and each copy keeps, in its code, the top rows last drawn in its buffer.
*
* Entered by wallscaler.draw with S on the descriptors. A block a column
* pulls its descriptor, restores the fringe when the wall got shorter,
* mounts the scaler's page and calls it. A push lands on descriptors
* already pulled ; the word after the last one is the caller's stack.
*
* 41 cycles a column plus its scaler ; a restored fringe, about 125 cycles
* plus 16 a row.
* ---------------------------------------------------------------------------

        INCLUDE "engine/system/to8/map.const.asm"

wallscaler.columns EXPORT

 SECTION code

wallscaler.columns
        _wallscaler.blocks
        lds   ,s                           ; the caller's stack
        rts

;-------------------------------------------------------------------------------
; wallscaler.fringeAt : called by a block whose wall got shorter. A page, B
; new top row, X texture, Y scaler : kept. The return address R is the
; block's draw : the old top row is the cmpb operand at R-6, the column's
; row 0 the ldu operand at R+7. The wall is centred : d = new top - old top
; rows come back on each side, rewritten by one pass of wallscaler.fill.
;-------------------------------------------------------------------------------
wallscaler.fringeAt
        pshs  d,x,y                        ; R at 6,s
        ldx   6,s
        ldu   7,x                          ; the column's row 0
        subb  -6,x                         ; d
        clra
        lslb
        ldy   #wallscaler.fillEntry
        ldy   d,y                          ; enter at end - 8 x d
        ldb   1,s                          ; the new top row
        lslb
        ldx   #wallscaler.rowOff
        abx
        ldd   ,x                           ; new top x 40
        leax  d,u                          ; X : the new top row
        nega                               ; negd
        negb
        sbca  #0
        addd  #wallscaler.ROWS*40
        leau  d,u                          ; U : the row past the new bottom
        ldd   #wallscaler.FLOOR*256+wallscaler.CEIL
        jsr   ,y
        puls  d,x,y,pc

        _wallscaler.fill

 ENDSECTION
