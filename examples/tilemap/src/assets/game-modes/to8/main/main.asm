;*******************************************************************************
; TilemapBuffer — bench
;
; Feeds the tile buffer from a generated map (src/assets/map, tools/gen_map.py)
; and checks every cell of the view against a reference read straight from
; the map : the layout cell, its chunk, the tile entry, the tile's record.
; The reference shares nothing with FeedTileBuffer's splitting into chunks
; and rings, which is what it checks. Then draws the view, the screen read
; back as a checksum, the empty and high priority cells counted against the
; reference.
;
; Two targets run the same tests : fd the defaults, fd-opt with OPAQUE,
; PLANES_CURSOR and SKIP_ROWS ; the tile routines draw the same picture
; either way, so the two disks' checksums agree.
;
; Witnesses at $9C00 (docs/lang/en/benches.md) : $CA, TESTS, $0D once done,
; a byte per test ($01 pass), a word per test.
;   t01 the whole view fed at 0,0 (a byte a layout cell)
;   t02 the whole view fed at 203,77 : unaligned, three chunks across
;   t03 small moves, the four ways and diagonal : each view checked
;   t04 the rings : 40 columns right, 24 rows down, then back diagonally
;   t05 a jump right past a view
;   t06 a jump down past a view
;   t07 jumps left, up, then down and right past a view
;   t08 a word a layout cell (SetCells, three banks) : fed whole, walked
;   t09 back to a byte a cell : SetCells puts the reads back
;   t10 DrawBufferedTile : the low priority cells (word : the screen), the
;       empty ones in glb_alphaTiles (none with OPAQUE), the high priority
;       ones queued
;   t11 DrawHighPriorityBufferedTile : the queue drawn (word : the screen),
;       S back
;   t12 the camera did not move : nothing drawn, an empty queue
;   t13 the rows drawn, on a tile boundary (a row less) ; with SKIP_ROWS,
;       three left to the game, DBT_row on the first of them (word : the
;       screen)
;*******************************************************************************

map.bytes       EXTERNAL
map.words       EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/thomson/graphics/mode/gfxmode.macro.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.macro.asm"
        INCLUDE "engine/graphics/tilemap/data-types/map-16bits.equ"

 opt c,ct

TMB_TILE_BUFFER equ $9000              ; 16*128, 2048 aligned
TMB_HPRIO_TILES equ $8C00              ; tmb_hprio_size (1009) below it

TESTS     equ 13
res.magic equ $9C00
res.count equ $9C01
res.done  equ $9C02
res.base  equ $9C03
res.sums  equ res.base+TESTS

R.t01 equ res.base+0
R.t02 equ res.base+1
R.t03 equ res.base+2
R.t04 equ res.base+3
R.t05 equ res.base+4
R.t06 equ res.base+5
R.t07 equ res.base+6
R.t08 equ res.base+7
R.t09 equ res.base+8
R.t10 equ res.base+9
R.t11 equ res.base+10
R.t12 equ res.base+11
R.t13 equ res.base+12
W.t10 equ res.sums+2*9
W.t11 equ res.sums+2*10
W.t13 equ res.sums+2*12

bench.camx  equ $9B00                  ; word : the camera asked for
bench.camy  equ $9B02
bench.tx    equ $9B04                  ; word : a tile, for the reference
bench.ty    equ $9B06
bench.want  equ $9B08                  ; 4 bytes : the cell the reference expects
bench.cx    equ $9B0C                  ; word : the view's first tile
bench.cy    equ $9B0E
bench.i     equ $9B10
bench.j     equ $9B11
bench.tmp   equ $9B12                  ; word
bench.desc  equ $9B14                  ; word : the map's descriptor
bench.walkp equ $9B16                  ; word
bench.n     equ $9B18
bench.dx    equ $9B19                  ; word
bench.dy    equ $9B1B                  ; word
bench.rows  equ $9B1D
bench.cols  equ $9B1E
bench.empty equ $9B1F
bench.high  equ $9B20
bench.sys   equ $9B21                  ; word

 IFDEF TilemapBuffer.OPAQUE
bench.FLAGS equ %11111100              ; what LoadChunk keeps of an entry's high byte
bench.INDEX equ %00000011
 ELSE
bench.FLAGS equ %11111000
bench.INDEX equ %00000111
 ENDC

main
        jsr   InitGlobals              ; the direct page cleared : camera at 0,0
        orcc  #$50                     ; one thread : no IRQ, no gfxlock
        _gfxmode.setBM16
        _ram.data.set #2               ; a screen buffer at the data window
        ldx   #res.magic
        ldb   #3+3*TESTS
!       clr   ,x+
        decb
        bne   <
        lda   #$CA
        sta   res.magic
        lda   #TESTS
        sta   res.count
        ldx   #TMB_HPRIO_TILES         ; the game clears the queue
!       clr   ,x+
        cmpx  #TMB_HPRIO_TILES+tmb_hprio_size
        blo   <
        ldx   #map.bytes
        jsr   bench.mapSet

; t01 : the whole view at 0,0
        ldd   #0
        std   bench.camx
        std   bench.camy
        jsr   bench.full
        bne   >
        lda   #1
        sta   R.t01
!
; t02 : the whole view at 203,77
        ldd   #203
        std   bench.camx
        ldd   #77
        std   bench.camy
        jsr   bench.full
        bne   >
        lda   #1
        sta   R.t02
!
; t03 : small moves from 203,77
        ldx   #t03.walk
        jsr   bench.walk
        bne   >
        lda   #1
        sta   R.t03
!
; t04 : the rings, from the view at 0,0
        ldd   #0
        std   bench.camx
        std   bench.camy
        jsr   bench.full
        bne   t04ko
        ldd   #8
        std   bench.dx
        ldd   #0
        std   bench.dy
        lda   #40
        jsr   bench.stride             ; 320 px right : past the 32 cell ring
        bne   t04ko
        ldd   #0
        std   bench.dx
        ldd   #16
        std   bench.dy
        lda   #24
        jsr   bench.stride             ; 384 px down : past the 16 row ring
        bne   t04ko
        ldd   #-8
        std   bench.dx
        ldd   #-16
        std   bench.dy
        lda   #20
        jsr   bench.stride             ; back up and left, diagonally
        bne   t04ko
        lda   #1
        sta   R.t04
t04ko
; t05 : a jump right past a view
        ldd   #100
        std   bench.camx
        std   bench.camy
        jsr   bench.full
        bne   >
        ldx   #t05.walk
        jsr   bench.walk
        bne   >
        lda   #1
        sta   R.t05
!
; t06 : a jump down past a view
        ldd   #100
        std   bench.camx
        std   bench.camy
        jsr   bench.full
        bne   >
        ldx   #t06.walk
        jsr   bench.walk
        bne   >
        lda   #1
        sta   R.t06
!
; t07 : jumps left, up, then down and right past a view
        ldd   #500
        std   bench.camx
        ldd   #400
        std   bench.camy
        jsr   bench.full
        bne   >
        ldx   #t07.walk
        jsr   bench.walk
        bne   >
        lda   #1
        sta   R.t07
!
; t08 : a word a layout cell
        ldx   #map.words
        jsr   bench.mapSet
        ldd   #37
        std   bench.camx
        ldd   #59
        std   bench.camy
        jsr   bench.full
        bne   >
        ldx   #t08.walk
        jsr   bench.walk
        bne   >
        lda   #1
        sta   R.t08
!
; t09 : back to a byte a cell
        ldx   #map.bytes
        jsr   bench.mapSet
        ldd   #203
        std   bench.camx
        ldd   #77
        std   bench.camy
        jsr   bench.full
        bne   >
        lda   #1
        sta   R.t09
!
; t10 : DrawBufferedTile at 203,77
        jsr   bench.vramClear
        clr   glb_alphaTiles
        lda   #1
        sta   glb_camera_move
        jsr   DrawBufferedTile
        jsr   bench.vramsum
        std   W.t10
        jsr   bench.viewRows
        jsr   bench.count
 IFDEF TilemapBuffer.OPAQUE
        lda   glb_alphaTiles           ; the background routine reads the flags
 ELSE
        lda   glb_alphaTiles
        suba  bench.empty
 ENDC
        bne   >
        jsr   bench.queued
        bne   >
        lda   #1
        sta   R.t10
!
; t11 : the queue drawn
        sts   bench.sys
        jsr   DrawHighPriorityBufferedTile
        cmps  bench.sys
        bne   >
        jsr   bench.vramsum
        std   W.t11
        cmpd  W.t10                    ; the high priority tiles drew
        beq   >
        lda   #1
        sta   R.t11
!
; t12 : the camera did not move
        jsr   bench.vramClear
        clr   glb_camera_move
        jsr   DrawBufferedTile
        jsr   DrawHighPriorityBufferedTile
        jsr   bench.vramsum
        bne   >                        ; something drew
        ldd   DBT_hiptr
        cmpd  #tmb_hprio_top-5
        bne   >
        lda   #1
        sta   R.t12
!
; t13 : the rows, at 203,64 : on a tile boundary, a row less
        ldd   #64
        std   bench.camy
        jsr   bench.camera
        jsr   ComputeTileBuffer
        jsr   bench.checkView
        bne   t13ko
        jsr   bench.vramClear
        lda   #1
        sta   glb_camera_move
 IFDEF TilemapBuffer.SKIP_ROWS
        lda   #3
        sta   DBT_skiprows             ; the last three left to the game
 ENDC
        jsr   DrawBufferedTile
        jsr   DrawHighPriorityBufferedTile
        jsr   bench.vramsum
        std   W.t13
        jsr   bench.viewRows
 IFDEF TilemapBuffer.SKIP_ROWS
        suba  #3
        clr   DBT_skiprows
 ENDC
        cmpa  #10-3                    ; on a boundary : 10 rows, 7 without the three
        beq   >
        cmpa  #10
        bne   t13ko
!       sta   bench.rows
        ldd   bench.cy                 ; the loop left DBT_row on the first row not drawn
        addb  bench.rows
        std   bench.ty
        ldd   bench.cx
        std   bench.tx
        jsr   bench.cellAddr
        cmpx  DBT_row
        bne   t13ko
        lda   #1
        sta   R.t13
t13ko
        lda   #$0D
        sta   res.done
done    bra   done

t03.walk fdb  211,77,224,77,224,93,224,100,216,100,216,84
         fdb  240,124,200,100,201,101,200,100,$FFFF
t05.walk fdb  500,100,$FFFF
t06.walk fdb  100,400,$FFFF
t07.walk fdb  100,400,100,50,500,500,$FFFF
t08.walk fdb  45,59,45,75,300,75,300,400,292,384,$FFFF

;*******************************************************************************
; bench helpers
;*******************************************************************************

; X the map's descriptor -> registered, as a game's map load does
bench.mapSet
        stx   bench.desc
        _ram.cart.set #assets.map.page
        stx   glb_map_adr
        lda   $E7E6
        sta   glb_map_pge
        sta   glb_map_tiles_pge
        ldd   layer_tiles,x
        std   glb_map_tiles_adr
        ldu   layer_map,x
        lda   ,u
        sta   glb_map_chunk_pge
        ldd   1,u
        std   glb_map_chunk_adr
        ldu   layer_chunk0,x
        lda   ,u
        sta   glb_map_defchunk0_pge
        ldd   1,u
        std   glb_map_defchunk0_adr
        ldu   layer_chunk1,x
        lda   ,u
        sta   glb_map_defchunk1_pge
        ldd   1,u
        std   glb_map_defchunk1_adr
        lda   layer_map_banks,x
        ldb   layer_map_width,x
        ldx   layer_chunk0,x
        jmp   TilemapBuffer.SetCells

; the camera at bench.camx, bench.camy
bench.camera
        ldd   bench.camx
        std   glb_camera_x_pos
        ldd   bench.camy
        std   glb_camera_y_pos
        rts

; the buffer scrambled, the view fed whole at the camera asked for, checked
; -> Z set if it matches
bench.full
        ldx   #TMB_TILE_BUFFER
        ldd   #$5A5A
!       std   ,x++
        cmpx  #TMB_TILE_BUFFER+16*128
        blo   <
        jsr   bench.camera
        jsr   InitTileBuffer
        jsr   ComputeTileBuffer
        jmp   bench.checkView

; X a list of positions (x, y words, $FFFF the end) -> the camera moved to
; each, the buffer fed, the view checked ; Z set if every view matches
bench.walk
        stx   bench.walkp
@loop   ldx   bench.walkp
        ldd   ,x
        cmpd  #$FFFF
        beq   @rts
        std   bench.camx
        ldd   2,x
        std   bench.camy
        leax  4,x
        stx   bench.walkp
        jsr   bench.camera
        jsr   ComputeTileBuffer
        jsr   bench.checkView
        beq   @loop
@rts    rts

; A steps of bench.dx, bench.dy -> each fed and checked ; Z set if all match
bench.stride
        sta   bench.n
@loop   ldd   bench.camx
        addd  bench.dx
        std   bench.camx
        ldd   bench.camy
        addd  bench.dy
        std   bench.camy
        jsr   bench.camera
        jsr   ComputeTileBuffer
        jsr   bench.checkView
        bne   @rts
        dec   bench.n
        bne   @loop
@rts    rts

; the view's first tile -> bench.cx, bench.cy
bench.origin
        ldd   bench.camx
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        std   bench.cx
        ldd   bench.camy
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        std   bench.cy
        rts

; every cell of the view (18 x 11 from its first tile) as the reference has
; it -> Z set if they all are
bench.checkView
        jsr   bench.origin
        clr   bench.i
@row    clr   bench.j
@col    jsr   bench.at
        jsr   bench.refCell
        jsr   bench.cellAddr
        ldd   ,x
        cmpd  bench.want               ; the flags and the page
        bne   @ko
        tstb
        beq   @next                    ; empty : the address is not written
        ldd   2,x
        cmpd  bench.want+2             ; the routine
        bne   @ko
@next   inc   bench.j
        lda   bench.j
        cmpa  #TilemapBuffer.VIEW_COLS
        blo   @col
        inc   bench.i
        lda   bench.i
        cmpa  #TilemapBuffer.VIEW_ROWS
        blo   @row
        clra                           ; Z set
        rts
@ko     lda   #1                       ; Z clear
        rts

; bench.tx, bench.ty <- the view's tile bench.j, bench.i
bench.at
        ldd   bench.cx
        addb  bench.j
        adca  #0
        std   bench.tx
        ldd   bench.cy
        addb  bench.i
        adca  #0
        std   bench.ty
        rts

; bench.tx, bench.ty -> X the buffer cell : 128 bytes a row, 4 a cell, rings
; of 16 rows and 32 cells
bench.cellAddr
        lda   bench.ty+1
        anda  #15
        ldb   #128
        mul
        addd  #TMB_TILE_BUFFER
        tfr   d,x
        ldb   bench.tx+1
        andb  #31
        aslb
        aslb
        abx
        rts

; bench.tx, bench.ty -> bench.want : the cell the reference expects, read
; from the map : flags, page (0 : empty), routine
bench.refCell
        _ram.cart.set #assets.map.page
        ldx   bench.desc
        ldb   bench.ty+1
        lsrb
        lsrb
        lsrb                           ; the chunk row
        lda   layer_map_width,x
        mul
        std   bench.tmp
        ldb   bench.tx+1
        lsrb
        lsrb
        lsrb                           ; the chunk column
        clra
        addd  bench.tmp                ; the layout cell, below 256
        ldu   layer_map,x
        ldu   1,u
        lda   layer_map_banks,x
        cmpa  #2
        bhi   @word
        clra
        leau  d,u
        ldb   ,u                       ; a byte : the id
        bra   @id
@word   clra
        aslb
        rola
        leau  d,u
        ldd   ,u                       ; a word : the id
@id     pshs  b
        aslb
        rola                           ; A : the bank, id >> 7
        ldb   #3
        mul
        ldu   layer_chunk0,x           ; the banks' records
        leau  d,u
        ldu   1,u                      ; the bank's chunks
        puls  b
        andb  #%01111111
        lda   #128
        mul
        leau  d,u                      ; the chunk
        lda   bench.ty+1
        anda  #7
        ldb   #16
        mul
        leau  d,u                      ; its row
        ldb   bench.tx+1
        andb  #7
        aslb
        clra
        leau  d,u                      ; the entry
        ldd   ,u
        bne   >
        std   bench.want               ; empty
        std   bench.want+2
        rts
!       pshs  a
        anda  #bench.FLAGS
        sta   bench.want
        puls  a
        anda  #bench.INDEX
        std   bench.tmp
        aslb
        rola
        addd  bench.tmp                ; the index * 3
        ldu   layer_tiles,x
        leau  d,u
        lda   ,u
        sta   bench.want+1
        ldd   1,u
        std   bench.want+2
        rts

; -> A the rows DrawBufferedTile draws at the camera : 11, a row less on a
; tile boundary
bench.viewRows
        lda   #TilemapBuffer.VIEW_ROWS
        ldb   bench.camy+1
        andb  #%00001111
        bne   >
        deca
!       rts

; A the rows -> bench.empty, bench.high : the reference's empty and high
; priority cells among DrawBufferedTile's (its columns : 18, a column less on
; a tile boundary)
bench.count
        sta   bench.rows
        ldb   #TilemapBuffer.VIEW_COLS
        lda   bench.camx+1
        anda  #%00000111
        bne   >
        decb
!       stb   bench.cols
        jsr   bench.origin
        clr   bench.empty
        clr   bench.high
        clr   bench.i
@row    lda   bench.i
        cmpa  bench.rows
        bhs   @rts
        clr   bench.j
@col    lda   bench.j
        cmpa  bench.cols
        bhs   @nextrow
        jsr   bench.at
        jsr   bench.refCell
        lda   bench.want+1
        bne   >
        inc   bench.empty
        bra   @next
!       lda   bench.want
        bpl   @next
        inc   bench.high
@next   inc   bench.j
        bra   @col
@nextrow inc  bench.i
        bra   @row
@rts    rts

; -> Z set if the queue holds bench.high entries (5 bytes each, from its end
; at tmb_hprio_top-5 down to DBT_hiptr)
bench.queued
        lda   bench.high
        ldb   #5
        mul
        std   bench.tmp
        ldd   #tmb_hprio_top-5
        subd  DBT_hiptr
        cmpd  bench.tmp
        rts

; both plane windows cleared
bench.vramClear
        ldd   #0
        ldx   #$A000
!       std   ,x++
        cmpx  #$A000+200*40
        blo   <
        ldx   #$C000
!       std   ,x++
        cmpx  #$C000+200*40
        blo   <
        rts

; a 16 bit rotate-and-add checksum of both plane windows -> D, Z set if 0
bench.vramsum
        ldd   #0
        std   bench.tmp
        ldx   #$A000
!       ldd   bench.tmp
        aslb
        rola
        adcb  #0
        addb  ,x+
        adca  #0
        std   bench.tmp
        cmpx  #$A000+200*40
        blo   <
        ldx   #$C000
!       ldd   bench.tmp
        aslb
        rola
        adcb  #0
        addb  ,x+
        adca  #0
        std   bench.tmp
        cmpx  #$C000+200*40
        blo   <
        ldd   bench.tmp
        rts

;*******************************************************************************
; engine
;*******************************************************************************
        INCLUDE "engine/InitGlobals.asm"
        INCLUDE "engine/graphics/tilemap/TilemapBuffer.asm"

 ENDSECTION
