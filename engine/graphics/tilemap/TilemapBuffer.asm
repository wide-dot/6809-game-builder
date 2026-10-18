* ---------------------------------------------------------------------------
* TilemapBuffer
* -------------
* A tile map drawn through a buffer of the tiles in view : 16 rows of 32
* cells, rings both ways, a cell [flags][page][routine address] (page 0 :
* empty). The map is a layout of chunks (64 x 128 px, 8 x 8 tiles of 8 x 16
* px), a chunk a table of 16 bit tile entries (flags, tile index), a tile
* index of [page][routine address] records (map-16bits.equ).
*
* InitTileBuffer              the next ComputeTileBuffer feeds the whole view
* ComputeTileBuffer           feeds the rows and columns the camera uncovered
* FeedTileBuffer              feeds TilemapBuffer.width x .height tiles from
*                             TilemapBuffer.x, .y
* TilemapBuffer.SetCells      a layout of byte or word cells (see below)
* DrawBufferedTile            draws the view's low priority cells, queues the
*                             high priority ones
* DrawHighPriorityBufferedTile draws the queue
*
* The game declares the buffer, TMB_TILE_BUFFER (16*128 bytes, 2048 aligned),
* and the high priority queue, TMB_HPRIO_TILES (tmb_hprio_size bytes), both
* cleared before InitTileBuffer.
* Options : TilemapBuffer.OPAQUE (bit 10 of an entry, a tile hiding the
* background, kept in the flags), TilemapBuffer.PLANES_CURSOR (the tile
* routines take plane 1 in Y and leave it on the next cell),
* TilemapBuffer.SKIP_ROWS (DBT_skiprows : the view's last rows left to the
* game, which goes on from DBT_row, DBT_rowy and DBT_hiptr).
* V2-DEVIATION : the buffer and the queue at the game's fixed addresses
* (#tile_buffer/256 does not relocate) ; a camera move past a view feeds the
* new view (v1 fed from the old one) ; DrawBufferedTile's loop rewritten (X on
* the buffer, the queue pushed on S, the ring cut once a row) ; the options.
* ---------------------------------------------------------------------------

        INCLUDE "./engine/graphics/tilemap/data-types/map-16bits.equ"

 IFNDEF TMB_TILE_BUFFER
        ERROR "TilemapBuffer : the game declares TMB_TILE_BUFFER (16*128 bytes, 2048 aligned)"
 ENDC
 IFNDEF TMB_HPRIO_TILES
        ERROR "TilemapBuffer : the game declares TMB_HPRIO_TILES (tmb_hprio_size bytes)"
 ENDC
tile_buffer     equ TMB_TILE_BUFFER
tmb_hprio_tiles equ TMB_HPRIO_TILES

TilemapBuffer.VIEW_COLS equ 18         ; the tiles a view spans
TilemapBuffer.VIEW_ROWS equ 11
TilemapBuffer.VIEW_W    equ TilemapBuffer.VIEW_COLS*8
TilemapBuffer.VIEW_H    equ TilemapBuffer.VIEW_ROWS*16

* the queue : 5 bytes a view cell (PSHS b,x,y) and the end's entry, then
* the room an IRQ (12 bytes) and a call (2) push under S ; it grows down
tmb_hprio_size  equ (TilemapBuffer.VIEW_COLS*TilemapBuffer.VIEW_ROWS+1)*5+12+2
tmb_hprio_top   equ tmb_hprio_tiles+tmb_hprio_size

; the map
glb_map_pge             fcb   0        ; the map descriptor (map-16bits.equ)
glb_map_adr             fdb   0
glb_map_chunk_pge       fcb   0        ; the layout
glb_map_chunk_adr       fdb   0
glb_map_defchunk0_pge   fcb   0        ; chunks 0-127
glb_map_defchunk0_adr   fdb   0
glb_map_defchunk1_pge   fcb   0        ; chunks 128-255
glb_map_defchunk1_adr   fdb   0
glb_map_tiles_pge       fcb   0        ; the tile index
glb_map_tiles_adr       fdb   0
glb_map_stride          fdb   0        ; a layout row's bytes : the width, twice with word cells
glb_map_bank_tbl        fill  0,4*3    ; word cells : each bank's [page][address], 4 at most

; the feed's variables
TilemapBuffer.hMid      equ dp_engine     ; middle chunks left in the row
TilemapBuffer.hMids     equ dp_engine+1   ; middle chunks a row
TilemapBuffer.vMid      equ dp_engine+2   ; middle chunk rows left
TilemapBuffer.cols      equ dp_engine+3   ; this chunk's tile columns
TilemapBuffer.leftCols  equ dp_engine+4   ; the left chunk's
TilemapBuffer.rightCols equ dp_engine+5   ; the right chunk's
TilemapBuffer.rightSave equ dp_engine+6
TilemapBuffer.rows      equ dp_engine+7   ; this chunk's tile rows left
TilemapBuffer.topRows   equ dp_engine+8   ; the top chunk's
TilemapBuffer.bottomRows equ dp_engine+9  ; the bottom chunk's
TilemapBuffer.colsSave  equ dp_engine+10
TilemapBuffer.chunkRows equ dp_engine+11  ; this chunk row's tile rows
TilemapBuffer.xOff      equ dp_engine+13  ; word : the first tile's column in its chunk, * 2
TilemapBuffer.yOff      equ dp_engine+15  ; word : its row, * 16
TilemapBuffer.cell      equ dp_engine+17  ; word : the buffer cell fed
TilemapBuffer.x         equ dp_engine+19  ; word : FeedTileBuffer's position
TilemapBuffer.y         equ dp_engine+21  ; word
; the draw's
DBT_lcpt                equ dp_engine+23  ; rows left
DBT_ccpt                equ dp_engine+24  ; cells left before the ring's end
DBT_left                equ dp_engine+25  ; cells of a row after the ring's end
DBT_ncol                equ dp_engine+26  ; cells a row

TilemapBuffer.oldX      fdb   0        ; the camera the buffer was fed for
TilemapBuffer.oldY      fdb   0

InitTileBuffer
        ldd   <glb_camera_x_pos
        addd  #TilemapBuffer.VIEW_W
        std   TilemapBuffer.oldX
        ldd   <glb_camera_y_pos
        addd  #TilemapBuffer.VIEW_H
        std   TilemapBuffer.oldY
        rts

ComputeTileBuffer
        lda   glb_map_pge
        bne   >
        rts                            ; no map
!       ldu   <glb_camera_y_pos        ; the rows
        ldd   TilemapBuffer.oldY
        subd  <glb_camera_y_pos
        beq   @x
        bpl   @y                       ; up : from the camera down
        cmpd  #-TilemapBuffer.VIEW_H
        bge   >
        ldd   #-TilemapBuffer.VIEW_H   ; past a view : the whole view
!       leau  TilemapBuffer.VIEW_H,u
        leau  d,u                      ; down : from the old view's end
@y      stu   <TilemapBuffer.y
        ldd   <glb_camera_y_pos
        _asrd
        _asrd
        _asrd
        _asrd
        std   @ty
        ldd   TilemapBuffer.oldY
        _asrd
        _asrd
        _asrd
        _asrd
        subd  #0
@ty     equ   *-2                      ; the tile rows moved
        beq   @x
        bpl   >
        _negd
!       cmpd  #TilemapBuffer.VIEW_ROWS
        ble   >
        ldb   #TilemapBuffer.VIEW_ROWS
!       stb   TilemapBuffer.height
        ldd   <glb_camera_x_pos
        std   <TilemapBuffer.x
        lda   #TilemapBuffer.VIEW_COLS
        sta   TilemapBuffer.width
        jsr   FeedTileBuffer
@x      ldu   <glb_camera_x_pos        ; the columns
        ldd   TilemapBuffer.oldX
        subd  <glb_camera_x_pos
        beq   @exit
        bpl   @xx                      ; left : from the camera right
        cmpd  #-TilemapBuffer.VIEW_W
        bge   >
        ldd   #-TilemapBuffer.VIEW_W   ; past a view : the whole view
!       leau  TilemapBuffer.VIEW_W,u
        leau  d,u                      ; right : from the old view's end
@xx     stu   <TilemapBuffer.x
        ldd   <glb_camera_x_pos
        _asrd
        _asrd
        _asrd
        std   @tx
        ldd   TilemapBuffer.oldX
        _asrd
        _asrd
        _asrd
        subd  #0
@tx     equ   *-2                      ; the tile columns moved
        beq   @exit
        bpl   >
        _negd
!       cmpd  #TilemapBuffer.VIEW_COLS
        ble   >
        ldb   #TilemapBuffer.VIEW_COLS
!       stb   TilemapBuffer.width
        ldd   <glb_camera_y_pos
        std   <TilemapBuffer.y
        lda   #TilemapBuffer.VIEW_ROWS
        sta   TilemapBuffer.height
        jsr   FeedTileBuffer
@exit   ldd   <glb_camera_x_pos
        std   TilemapBuffer.oldX
        ldd   <glb_camera_y_pos
        std   TilemapBuffer.oldY
        rts

FeedTileBuffer
        lda   glb_map_pge
        _SetCartPageA                  ; the map descriptor
        ldu   glb_map_adr
        clra
        sta   <TilemapBuffer.xOff
        sta   <TilemapBuffer.yOff
        ldb   <TilemapBuffer.y+1       ; the buffer cell : 16 px down a row ($80)
        lda   #%00010000
        mul
        ldb   <TilemapBuffer.x+1       ; 8 px right a cell (4)
        andb  #%11111000
        _lsrd
        adda  #tile_buffer/256
        std   <TilemapBuffer.cell
        ldd   <TilemapBuffer.x         ; the layout cell
        _lsrd
        _lsrd
        _lsrd
        _lsrd
        _lsrd
TilemapBuffer.xCell                    ; (dynamic, TilemapBuffer.SetCells) lsra/rorb : a byte a cell,
        _lsrd                          ; andb #$FE : a word (the column * 2)
        std   @col
        ldd   <TilemapBuffer.y
        _lsrd
        _lsrd
        _lsrd
        _lsrd
        _lsrd
        _lsrd
        andb  #%11111110               ; the chunk row * 2
        leax  layer_mul_ref,u
        ldd   d,x                      ; its offset in the layout
        addd  #0
@col    equ   *-2
        addd  glb_map_chunk_adr
        tfr   d,x
        lda   <TilemapBuffer.x+1       ; the first chunk's columns
        anda  #%00111000
        asra
        asra
        sta   <TilemapBuffer.xOff+1
        asra
        suba  #8
        nega
        cmpa  #0
TilemapBuffer.width equ *-1            ; (dynamic) the tiles to feed across
        blt   >
        lda   TilemapBuffer.width      ; capped to the width
!       sta   <TilemapBuffer.leftCols
        lda   TilemapBuffer.width
        suba  <TilemapBuffer.leftCols
        tfr   a,b
        asrb
        asrb
        asrb
        stb   <TilemapBuffer.hMids     ; the middle chunks, 8 columns each
        anda  #%00000111
        sta   <TilemapBuffer.rightCols ; the right chunk's
        sta   <TilemapBuffer.rightSave
        lda   <TilemapBuffer.y+1       ; the first chunk's rows
        anda  #%01110000
        sta   <TilemapBuffer.yOff+1
        asra
        asra
        asra
        asra
        suba  #8
        nega
        cmpa  #0
TilemapBuffer.height equ *-1           ; (dynamic) the tiles to feed down
        blt   >
        lda   TilemapBuffer.height
!       sta   <TilemapBuffer.topRows
        lda   TilemapBuffer.height
        suba  <TilemapBuffer.topRows
        tfr   a,b
        asrb
        asrb
        asrb
        stb   <TilemapBuffer.vMid      ; the middle chunk rows
        anda  #%00000111
        sta   <TilemapBuffer.bottomRows ; the bottom chunk's
        lda   glb_map_chunk_pge
        _SetCartPageA                  ; the layout
        ldb   <TilemapBuffer.topRows
        stb   <TilemapBuffer.chunkRows
        ldd   <TilemapBuffer.yOff      ; the first chunk : from its first tile
        std   @chunkY
        addd  <TilemapBuffer.xOff
        std   TilemapBuffer.chunkOffset
@vloop  stx   @layout
        stx   TilemapBuffer.layoutCell
        ldb   <TilemapBuffer.hMids
        stb   <TilemapBuffer.hMid
        ldd   <TilemapBuffer.cell
        andb  #%10000000
        std   @rowStart                ; the buffer row
        ldb   <TilemapBuffer.leftCols
        stb   <TilemapBuffer.cols
        lda   <TilemapBuffer.chunkRows ; the next chunk row's buffer cell
        ldb   #128
        mul
        addd  <TilemapBuffer.cell
        anda  #%00000111
        adda  #tile_buffer/256
        std   @nextRow
@hloop  jsr   LoadChunk
        ldd   #0
@chunkY equ   *-2                      ; the next chunks : from their first column
        std   TilemapBuffer.chunkOffset
        ldd   <TilemapBuffer.cell      ; the next chunk's buffer cell
        addd  #4
        clra
        andb  #%01111100               ; the row's ring
        addd  #0
@rowStart equ *-2
        std   <TilemapBuffer.cell
        lda   <TilemapBuffer.hMid
        beq   @right
        ldb   #8                       ; a middle chunk
        stb   <TilemapBuffer.cols
        deca
        sta   <TilemapBuffer.hMid
        bra   @hloop
@right  ldb   <TilemapBuffer.rightCols
        beq   @hexit
        stb   <TilemapBuffer.cols
        stb   <TilemapBuffer.rightSave
        clr   <TilemapBuffer.rightCols
        bra   @hloop
@hexit  lda   <TilemapBuffer.rightSave
        sta   <TilemapBuffer.rightCols
        ldd   #0
@nextRow equ  *-2
        std   <TilemapBuffer.cell
        ldx   #0
@layout equ   *-2
        ldd   glb_map_stride           ; the layout's next row
        leax  d,x
        ldb   <TilemapBuffer.vMid
        beq   @bottom
        bmi   @end
        lda   #8                       ; a middle chunk row
        sta   <TilemapBuffer.chunkRows
        bra   >
@bottom lda   <TilemapBuffer.bottomRows
        beq   @end
        sta   <TilemapBuffer.chunkRows
!       decb
        stb   <TilemapBuffer.vMid
        ldd   #0
        std   @chunkY
        ldd   <TilemapBuffer.xOff
        std   TilemapBuffer.chunkOffset ; the next chunk row : from its first row
        jmp   @vloop
@end    rts

* ---------------------------------------------------------------------------
* TilemapBuffer.SetCells - the layout's cells, at a map's load : A the chunk
* banks of 128, B the layout's width (chunks a row), X the first bank's
* [page][address] record, the others following it. Two banks : a byte a cell
* (glb_map_defchunk0/1, the caller's). More, up to 4 : a big endian word a
* cell, its bank id >> 7, the records copied to glb_map_bank_tbl. The cell's
* read and the column's last shift are patched : the loops pay nothing.
* ---------------------------------------------------------------------------
TilemapBuffer.SetCells
        pshs  a
        clra
        std   glb_map_stride           ; a byte a cell : the width
        puls  a
        cmpa  #2
        bhi   @word
        ldd   #$A680                   ; lda ,x+
        std   LoadChunk.cell
        ldd   #$4456                   ; lsra / rorb
        std   TilemapBuffer.xCell
        rts
@word   asl   glb_map_stride+1         ; a word a cell : twice the width
        rol   glb_map_stride
        ldu   #glb_map_bank_tbl
        ldb   #3
        mul                            ; the records' bytes
!       lda   ,x+
        sta   ,u+
        decb
        bne   <
        ldd   #$2000+((LoadChunk.word-LoadChunk.cell-2)&$FF) ; bra LoadChunk.word
        std   LoadChunk.cell
        ldd   #$C4FE                   ; andb #$FE
        std   TilemapBuffer.xCell
        rts

LoadChunk.word                         ; a word cell : the chunk's bank its id >> 7
        ldd   ,x++
        lslb                           ; B : (id & 127) * 2
        rola                           ; A : its bank
        pshs  b
        ldb   #3
        mul
        ldu   #glb_map_bank_tbl
        leau  d,u
        ldb   ,u                       ; the bank's page
        ldu   1,u                      ; and address
        puls  a
        lsra                           ; A : id & 127
        bra   LoadChunk.bank

* ---------------------------------------------------------------------------
* LoadChunk - feeds TilemapBuffer.cols x .chunkRows tiles of the chunk at the
* layout cell TilemapBuffer.layoutCell, from TilemapBuffer.chunkOffset in it,
* to the buffer from TilemapBuffer.cell
* ---------------------------------------------------------------------------
LoadChunk
        ldd   <TilemapBuffer.cell
        andb  #%10000000
        std   LoadChunk.lineStart      ; the buffer row
        ldb   <TilemapBuffer.cols      ; from a row's last cell to the next row's first
        lslb
        lslb
        lda   #%11111111
        negb
        addd  #128+4
        std   LoadChunk.rowStep
        ldx   #0
TilemapBuffer.layoutCell equ *-2
LoadChunk.cell
        lda   ,x+                      ; (dynamic) bra LoadChunk.word : a word cell
        bpl   >
        ldu   glb_map_defchunk1_adr
        anda  #%01111111
        ldb   glb_map_defchunk1_pge
        bra   LoadChunk.bank
!       ldu   glb_map_defchunk0_adr
        ldb   glb_map_defchunk0_pge
 IFGT LoadChunk.cell+2-LoadChunk.word-128
        ERROR "LoadChunk.word out of the patched bra's reach"
 ENDC
LoadChunk.bank
        stb   chk_idx_pge
        _SetCartPageB                  ; the chunk's page
        ldb   #0
        _asrd                          ; the chunk : id * 128
        addd  #0
TilemapBuffer.chunkOffset equ *-2      ; (dynamic) its first tile
        leau  d,u
        stx   TilemapBuffer.layoutCell
        stu   LoadChunk.row
        lda   <TilemapBuffer.cols
 IFDEF T2
        lbeq  LoadChunk.end
 ELSE
        beq   LoadChunk.end
 ENDC
        sta   <TilemapBuffer.colsSave
        lda   <TilemapBuffer.chunkRows
 IFDEF T2
        lbeq  LoadChunk.end
 ELSE
        beq   LoadChunk.end
 ENDC
        sta   <TilemapBuffer.rows
LoadChunk.tile
        ldy   <TilemapBuffer.cell
        ldd   ,u++                     ; the tile entry
        bne   >
        std   ,y                       ; 0 : an empty cell
        bra   LoadChunk.next
!       stu   @entry
        sta   @high
 IFDEF TilemapBuffer.OPAQUE
        anda  #%11111100               ; the flags : priority, solidity, opacity
 ELSE
        anda  #%11111000               ; the flags : priority, solidity
 ENDC
        sta   ,y
        lda   #0
@high   equ   *-1
 IFDEF TilemapBuffer.OPAQUE
        anda  #%00000011               ; the tile index
 ELSE
        anda  #%00000111
 ENDC
        std   @index
        _lsld
        addd  #0
@index  equ   *-2                      ; * 3 : its record
        ldu   glb_map_tiles_adr
        leau  d,u
        lda   glb_map_tiles_pge
        _SetCartPageA
        pulu  a,x                      ; the routine's page and address
        sta   1,y
        stx   2,y
        lda   #0
chk_idx_pge equ *-1                    ; (dynamic) the chunk's page
        _SetCartPageA
        ldu   #0
@entry  equ   *-2
LoadChunk.next
        dec   <TilemapBuffer.cols
        beq   LoadChunk.rowEnd
        ldd   #4                       ; the next cell, in the row's ring
        addd  <TilemapBuffer.cell
        clra
        andb  #%01111100
        addd  #0
LoadChunk.lineStart equ *-2
        std   <TilemapBuffer.cell
 IFDEF T2
        jmp   LoadChunk.tile
 ELSE
        bra   LoadChunk.tile
 ENDC
LoadChunk.rowEnd
        dec   <TilemapBuffer.rows
        bne   LoadChunk.nextRow
LoadChunk.end
        lda   glb_map_chunk_pge
        _SetCartPageA                  ; the layout back
        rts
LoadChunk.nextRow
        lda   <TilemapBuffer.colsSave
        sta   <TilemapBuffer.cols
        ldu   #0
LoadChunk.row equ *-2                  ; (dynamic) the chunk row's first tile
        leau  16,u                     ; 8 entries a chunk row
        stu   LoadChunk.row
        ldd   #0
LoadChunk.rowStep equ *-2              ; (dynamic)
        addd  <TilemapBuffer.cell
        anda  #%00000111
        adda  #tile_buffer/256
        std   <TilemapBuffer.cell
        andb  #%10000000
        std   LoadChunk.lineStart
        jmp   LoadChunk.tile

* ---------------------------------------------------------------------------
* DrawBufferedTile - the view's cells : the low priority ones drawn, the high
* priority ones pushed on a queue on S (PSHS page, cell, screen address ;
* the end an entry of page 0, pushed first), popped by
* DrawHighPriorityBufferedTile. An IRQ or a call pushes below S, free there.
* Nothing drawn when the camera did not move for this buffer.
* ---------------------------------------------------------------------------
DrawBufferedTile
        lda   <glb_camera_move
        bne   >
        clr   tmb_hprio_top-5          ; an empty queue
        ldd   #tmb_hprio_top-5
        std   DBT_hiptr
        rts
!       clr   <glb_Page                ; no page backup by the page macros
        ldb   #TilemapBuffer.VIEW_COLS ; a column less on a tile boundary
        lda   <glb_camera_x_pos+1
        anda  #%00000111
        bne   >
        decb
!       stb   <DBT_ncol
        ldb   #TilemapBuffer.VIEW_ROWS ; a row less on a tile boundary
        lda   <glb_camera_y_pos+1
        anda  #%00001111
        bne   >
        decb
!
 IFDEF TilemapBuffer.SKIP_ROWS
        subb  DBT_skiprows             ; the last rows left to the game
 ENDC
        stb   <DBT_lcpt
        lda   <glb_camera_x_pos+1      ; the first cell's screen address : 2 px
        anda  #%00000110               ; a byte, two lines a step (interlacing)
        nega
        adda  #12
        ldb   <glb_camera_y_pos+1
        andb  #%00001110
        negb
        addb  #20
        lsra                           ; 2 px a byte
        lsra                           ; RAMA, RAMB
        bcs   @ram2
        sta   @ram1x
        lda   #40
        mul
        addd  #$C000
@ram1x  equ   *-1
        addd  #441                     ; the tiles' centre (TILE8x16)
        std   <glb_screen_location_2
        suba  #$20
        std   <glb_screen_location_1
        bra   >
@ram2   sta   @ram2x
        lda   #40
        mul
        addd  #$A000
@ram2x  equ   *-1
        addd  #441
        std   <glb_screen_location_2
        addd  #$2001
        std   <glb_screen_location_1
!       std   DBT_rowy
        ldd   <glb_screen_location_2
        subd  <glb_screen_location_1
        std   DBT_delta
        std   DBT_delta2
        ldb   <glb_camera_y_pos+1      ; the first cell in the buffer
        lda   #%00010000
        mul
        ldb   <glb_camera_x_pos+1
        andb  #%11111000
        _lsrd
        addd  #tile_buffer
        std   DBT_row
        andb  #%01111111               ; a row reaches its ring's end at most once,
        lsrb                           ; at the same column for all
        lsrb
        negb
        addb  #32
        cmpb  <DBT_ncol
        blo   >
        ldb   <DBT_ncol
!       stb   DBT_run1                 ; the cells up to it
        negb
        addb  <DBT_ncol
        stb   DBT_run2                 ; and after it
        sts   DBT_sys
        lds   #tmb_hprio_top
        clrb                           ; the queue's end : page 0
        pshs  b,x,y
DBT_lloop
        ldx   #0
DBT_row equ   *-2                      ; the row's first cell
        ldy   #0
DBT_rowy equ  *-2                      ; and screen address
        lda   #0
DBT_run1 equ  *-1
        sta   <DBT_ccpt
        lda   #0
DBT_run2 equ  *-1
        sta   <DBT_left
DBT_cloop
        ldd   ,x                       ; A the flags, B the page (0 : empty)
 IFDEF TilemapBuffer.OPAQUE
        beq   DBT_next                 ; the background routine reads the opacity bit
 ELSE
        beq   DBT_empty
 ENDC
        bmi   DBT_high                 ; bit 7 : high priority
        stb   $E7E6
 IFDEF TilemapBuffer.PLANES_CURSOR
        leau  $1234,y                  ; plane 2 ; plane 1 in Y, moved on by the routine
DBT_delta equ *-2
        jsr   [2,x]
        leax  4,x
        dec   <DBT_ccpt
        bne   DBT_cloop
        bra   DBT_rowend
 ELSE
        sty   <glb_screen_location_1   ; plane 1
        leau  $1234,y                  ; plane 2
DBT_delta equ *-2
        jsr   [2,x]
 ENDC
DBT_next
        leax  4,x
        leay  2,y
        dec   <DBT_ccpt
        bne   DBT_cloop
DBT_rowend
        lda   <DBT_left                ; the row goes on from its ring's start
        beq   >
        sta   <DBT_ccpt
        clr   <DBT_left
        leax  -128,x
        bra   DBT_cloop
!       ldd   DBT_rowy                 ; the next row : 16 lines down
        addd  #40*16
        std   DBT_rowy
        ldd   DBT_row
        addd  #128
        anda  #%00000111
        adda  #tile_buffer/256
        std   DBT_row
        dec   <DBT_lcpt
        bne   DBT_lloop
        sts   DBT_hiptr
        lds   #0
DBT_sys equ   *-2
        rts

DBT_high
        pshs  b,x,y                    ; page, cell, screen address
        bra   DBT_next

 IFDEF TilemapBuffer.SKIP_ROWS
DBT_skiprows fcb 0                     ; the game's, each frame
 ENDC

 IFNDEF TilemapBuffer.OPAQUE
DBT_empty
        inc   <glb_alphaTiles          ; the background shows
        bra   DBT_next
 ENDC

DrawHighPriorityBufferedTile
        clr   <glb_Page                ; no page backup by the page macros
        sts   @sys
        lds   #tmb_hprio_tiles         ; (dynamic) the queue's last entry
DBT_hiptr equ *-2
        bra   @entry
@loop
 IFNDEF TilemapBuffer.PLANES_CURSOR
        sty   <glb_screen_location_1
 ENDC
        leau  $1234,y
DBT_delta2 equ *-2
        jsr   [2,x]
@entry  puls  b,x,y
        stb   $E7E6
        bne   @loop
        lds   #0
@sys    equ   *-2
        rts
