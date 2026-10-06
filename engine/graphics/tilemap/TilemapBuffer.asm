* ---------------------------------------------------------------------------
*
* ---------------------------------------------------------------------------

        INCLUDE "./engine/graphics/tilemap/data-types/map-16bits.equ"
        ;SETDP   dp/256 ; V2-DEVIATION: setdp neutralized (not permitted in lwasm
                         ; obj target ; migration/setdp-obj-target.md)

; data structure for current loaded map
; -------------------------------------
glb_map_pge             fcb   0
glb_map_adr             fdb   0
glb_map_chunk_pge       fcb   0 ; map data to chunk tiles (8x8 tiles group)
glb_map_chunk_adr       fdb   0 ; map data to chunk tiles (8x8 tiles group)
glb_map_defchunk0_pge   fcb   0 ; chunk data to tiles (8x16 px)
glb_map_defchunk0_adr   fdb   0 ; chunk data to tiles (8x16 px)
glb_map_defchunk1_pge   fcb   0 ; chunk data to tiles (8x16 px)
glb_map_defchunk1_adr   fdb   0 ; chunk data to tiles (8x16 px)
glb_map_tiles_pge       fcb   0 ; tile index
glb_map_tiles_adr       fdb   0 ; tile index
glb_map_width           fcb   0

; tmp variables
h_tl                  equ   dp_engine    ; nb of full sized (middle) horizontal chunks
h_tl_bck              equ   dp_engine+1
v_tl                  equ   dp_engine+2  ; nb of full sized (middle) vertical chunks
c_h_tl                equ   dp_engine+3  ; variable that stores current left, middle or right width of chunks
l_h_tl                equ   dp_engine+4
r_h_tl                equ   dp_engine+5
r_h_tl_bck            equ   dp_engine+6
c_v_tl                equ   dp_engine+7  ; variable that stores current up, middle or bottom height of chunks
u_v_tl                equ   dp_engine+8
b_v_tl                equ   dp_engine+9
c_h_tl_bck            equ   dp_engine+10 ; backup value of horizontal width of chunks
c_v_tl_bck            equ   dp_engine+11 ; backup value of vertical height of chunks
cur_c                 equ   dp_engine+12 ; current chunk id
x_off                 equ   dp_engine+13 ; x start position in top left chunk
y_off                 equ   dp_engine+15 ; y start position in top left chunk
b_loc                 equ   dp_engine+17 ; location in buffer
tmb_x                 equ   dp_engine+19
tmb_y                 equ   dp_engine+21
DBT_lcpt              equ   dp_engine+23
DBT_ccpt              equ   dp_engine+24
DBT_left              equ   dp_engine+25 ; cells of a row after the ring's end
DBT_ncol              equ   dp_engine+26 ; cells of a row

; persistant variables
tmb_old_camera_x      fdb   0 ; last camera position (x axis)
tmb_old_camera_y      fdb   0 ; last camera position (y axis)

tmb_vp_h_tiles        equ   18 ; viewport tiles on x axis
tmb_vp_v_tiles        equ   11 ; viewport tiles on y axis
tmb_vp_h_px           equ   tmb_vp_h_tiles*8
tmb_vp_v_px           equ   tmb_vp_v_tiles*16

InitTileBuffer
        ldd   <glb_camera_x_pos
        addd  #tmb_vp_h_px
        std   tmb_old_camera_x
        ldd   <glb_camera_y_pos
        addd  #tmb_vp_v_px
        std   tmb_old_camera_y
        rts

ComputeTileBuffer

        ; check if a map was registred
        ; ---------------------------------------------------------------------

        lda   glb_map_pge
        bne   @a
        rts
@a

        ; compute tiles that needs to be added to buffer
        ; ---------------------------------------------------------------------

        ; compute y location
        ldu   <glb_camera_y_pos
        ldd   tmb_old_camera_y
        subd  <glb_camera_y_pos
        beq   @next
        bpl   @a
        leau  tmb_vp_v_px,u
        leau  d,u
@a      stu   tmb_y
        ; compute height in tiles
        ldd   <glb_camera_y_pos
        _asrd
        _asrd
        _asrd
        _asrd
        std   @dyn
        ldd   tmb_old_camera_y
        _asrd
        _asrd
        _asrd
        _asrd
        subd   #0
@dyn    equ   *-2
        beq   @next
        bpl   @b
        _negd
@b      cmpd  #tmb_vp_v_tiles
        ble   @c
        ldb   #tmb_vp_v_tiles
@c      stb   glb_tmb_height
        ldd   <glb_camera_x_pos
        std   tmb_x
        lda   #tmb_vp_h_tiles
        sta   glb_tmb_width
        jsr   FeedTileBuffer
@next

        ; compute x location
        ldu   <glb_camera_x_pos
        ldd   tmb_old_camera_x
        subd  <glb_camera_x_pos
        beq   @exit
        bpl   @a
        leau  tmb_vp_h_px,u
        leau  d,u
@a      stu   tmb_x
        ; compute width in tiles
        ldd   <glb_camera_x_pos
        _asrd
        _asrd
        _asrd
        std   @dyn
        ldd   tmb_old_camera_x
        _asrd
        _asrd
        _asrd
        subd   #0
@dyn    equ   *-2
        beq   @exit
        bpl   @b
        _negd
@b      cmpd  #tmb_vp_h_tiles
        ble   @c
        ldb   #tmb_vp_h_tiles
@c      stb   glb_tmb_width
        ldd   <glb_camera_y_pos
        std   tmb_y
        lda   #tmb_vp_v_tiles
        sta   glb_tmb_height
        jsr   FeedTileBuffer
@exit
        ldd   <glb_camera_x_pos
        std   tmb_old_camera_x
        ldd   <glb_camera_y_pos
        std   tmb_old_camera_y
        rts

; ****************************************************************************************************************************
; * FeedTileBuffer
; * Feed the tile buffer, based on camera x and y and a number of tiles in width and height
; *
; * tmb_x      (0-32767)
; * tmb_y      (0-32767)
; * glb_tmb_width  (1-20)
; * glb_tmb_height (1-13)
; *
; ****************************************************************************************************************************

FeedTileBuffer

        ; mount the map
        ; ---------------------------------------------------------------------

        lda   glb_map_pge
        _SetCartPageA
        ldu   glb_map_adr

        anda  #0
        sta   x_off                         ; init MSB to 0
        sta   y_off                         ; init MSB to 0

        ; compute position in cycling buffer
        ; ---------------------------------------------------------------------

; OPTIM SAM
        ldb   tmb_y+1                                 ; each 16px steps in y add $80
        lda   #%00010000
        mul
        ldb   tmb_x+1                                 ; each 8px steps in x add $04
        andb  #%11111000
        _lsrd

        adda  #tile_buffer/256
        std   b_loc

        ; transform a camera position into an index to map (64x128px chunks)
        ; ---------------------------------------------------------------------
        ldd   tmb_x
        _lsrd
        _lsrd
        _lsrd
        _lsrd
        _lsrd
        _lsrd
        std   @dyn1
        ldd   tmb_y
        _lsrd
        _lsrd
        _lsrd
        _lsrd
        _lsrd
        _lsrd
        andb  #%11111110                              ; faster than _lsrd (last shift for 128px map) and lsld (2 bytes index in mul ref)
        leax  layer_mul_ref,u
        ldd   d,x                                     ; use precalculated values to get y in map (16 bits mul)
        addd  #0                                      ; (dynamic) add x position to index
@dyn1   equ   *-2
        addd  glb_map_chunk_adr                       ; (dynamic) add map data address to index
        tfr   d,x

        ; compute tile offset in chunks
        ; ---------------------------------------------------------------------

        lda   tmb_x+1
        anda  #%00111000
        asra
        asra
        sta   x_off+1                                 ; horizontal offset to first tile in top left chunk
        asra
        suba  #8                                      ; chunk hold 8 tiles in a row
        nega
        cmpa  #0
glb_tmb_width equ *-1                                 ; (dynamic) nb of tile in screen width
        blt   @a                                      ; branch if requested tiles in width are covered by more chunks than the first one
        lda   glb_tmb_width                           ; if not cap to the requested width
@a      sta   l_h_tl                                  ; save nb of tiles in left chunks
        lda   glb_tmb_width
        suba  l_h_tl
        tfr   a,b
        asrb
        asrb
        asrb
        stb   h_tl_bck                                ; nb of full sized (middle) horizontal chunks
        anda  #%00000111                              ; skip middle chunks that are 8 tiles wide
        sta   r_h_tl                                  ; save nb of horizontal tiles in right chunks
        sta   r_h_tl_bck

        lda   tmb_y+1
        anda  #%01110000                              ; get tile position in chunk
        sta   y_off+1                                 ; vertical offset to first tile in top left chunk
        asra
        asra
        asra
        asra
        suba  #8                                      ; chunk hold 8 tiles in a col
        nega
        cmpa  #0
glb_tmb_height equ *-1                                ; (dynamic) nb of tile in screen width
        blt   @a                                      ; branch if requested tiles in width are covered by the first chunk
        lda   glb_tmb_height
@a      sta   u_v_tl                                  ; save nb of vertical tiles in top chunks
        lda   glb_tmb_height                          ; (dynamic) nb of tile in screen height
        suba  u_v_tl
        tfr   a,b
        asrb
        asrb
        asrb
        stb   v_tl                                    ; nb of full sized (middle) vertical chunks
        anda  #%00000111                              ; skip middle chunks that are 8 tiles high
        sta   b_v_tl                                  ; save nb of vertical tiles in bottom chunks

        ; load chunks
        ; --------------------
        lda   glb_map_chunk_pge
        _SetCartPageA

        ldb   u_v_tl                   ; first line begin with upper vertical chunk height
        stb   c_v_tl_bck

        ldd   y_off                    ; offset in top left chunk is horizontal and vertical
        std   c_y_off
        addd  x_off
        std   chunk_offset
@vloop
        stx   @start_pos_bck           ; position in chunk map
        stx   start_pos
        ldb   h_tl_bck                 ; restore nb of middle chunks (8 tiles width) on x axis for one row
        stb   h_tl
        ldd   b_loc                    ; load location in cycling buffer
        andb  #%10000000               ; compute line start
        std   cl_pos_bck
        ldb   l_h_tl                   ; nb of tiles on left chunk
        stb   c_h_tl                   ; store in current nb of tiles
        lda   c_v_tl_bck               ; compute location for next row
        ldb   #128                     ; ...
        mul                            ; ...
        addd  b_loc                    ; ...
        anda  #%00000111
        adda  #tile_buffer/256 ; add base address
        std   @l1_bck                  ; save location for next row
@hloop
        jsr   LoadChunk
        ldd   #0
c_y_off equ   *-2
        std   chunk_offset
        ldd   b_loc                    ; compute location for next col
        addd  #4
        anda  #%00000000
        andb  #%01111100 ; cycle thru this line (0-127) by 4 bytes
        addd  #0
cl_pos_bck equ *-2
        std   b_loc                    ; set location for next col
        lda   h_tl                     ; check number of middle chunks
        beq   @rc
        ldb   #8                       ; middle chunks are 8 tiles width
        stb   c_h_tl
        deca
        sta   h_tl
        bra   @hloop
@rc     ldb   r_h_tl                   ; check right chunk
        beq   @hexit
        stb   c_h_tl
        stb   r_h_tl_bck
        clr   r_h_tl
        bra   @hloop
@hexit  lda   r_h_tl_bck
        sta   r_h_tl
        ldd   #0
@l1_bck equ   *-2
        std   b_loc                    ; set location for next row
        ldb   glb_map_width
        ldx   #0
@start_pos_bck equ *-2
        abx
        ldb   v_tl                     ; are we in middle or bottom chunk ?
        beq   @a
        bmi   @end
        lda   #8                       ; middle
        sta   c_v_tl_bck
        bra   @b
@a      lda   b_v_tl                   ; bottom
        beq   @end
        sta   c_v_tl_bck
@b      decb
        stb   v_tl
        ldd   #0
        std   c_y_off
        ldd   x_off
        std   chunk_offset             ; offset in next row of chunk is only horizontal
        jmp   @vloop
@end    rts

LoadChunk
        ldd   b_loc
        andb  #%10000000
        std   cl_pos                                  ; save line start for cycling buffer
        ldb   c_h_tl                                  ; preprocess line return
        lslb                                          ; buffer : 4 bytes per tile in width
        lslb
        lda   #%11111111
        negb
        addd  #128+4                                  ; one line in buffer and one tile width
        std   r_stp_1

        ldx   #0
start_pos equ *-2
        lda   ,x+
        bpl   @a
        ldu   glb_map_defchunk1_adr
        anda  #%01111111
        ldb   glb_map_defchunk1_pge
        bra   @b
@a      ldu   glb_map_defchunk0_adr
        ldb   glb_map_defchunk0_pge
@b      stb   chk_idx_pge
        _SetCartPageB                                 ; set chunk definition page
        ldb   #0
        _asrd
        addd  #0                                      ; (dynamic) ajust position of first tile in chunk
chunk_offset  equ   *-2
        leau  d,u

        stx   start_pos
        stu   start_x                                 ; start position in chunk

DrawChunk
        lda   c_h_tl
 IFDEF T2
        lbeq  EndOfChunk
 ELSE
        beq   EndOfChunk
 ENDC
        sta   c_h_tl_bck
        lda   c_v_tl_bck
 IFDEF T2
        lbeq  EndOfChunk
 ELSE
        beq   EndOfChunk
 ENDC
        sta   c_v_tl

DrawTile
        ldy   b_loc
        ldd   ,u++                                    ; load tile index in d (16 bits)
        bne   @a
        ldd   #0
        std   ,y
        jmp   NextCol
@a      stu   @dyn2
        sta   @dyn0
 IFDEF TilemapBuffer.OPAQUE
        ; V2-DEVIATION (06/10/2026) : bit 10 of a chunk entry marks a tile
        ; that covers its whole cell (sonic-2's tools/ehz_opaque.py) ; it is
        ; kept in the flags byte (bit 2) for a background routine that skips
        ; the rows such tiles cover. The tile index is then bits 0-9.
        anda  #%11111100                              ; save priority, solidity and opacity on first byte
 ELSE
        anda  #%11111000                              ; save priority and solidity on first byte
 ENDC
        sta   ,y
        lda   #0
@dyn0   equ   *-1
 IFDEF TilemapBuffer.OPAQUE
        anda  #%00000011                              ; remove priority, solidity and opacity to get tile index
 ELSE
        anda  #%00000111                              ; remove priority and solidity to get tile index
 ENDC
        std   @dyn1                                   ; multiply tile index by 3 to load tile page and addr
        _lsld
        addd  #0                                      ; (dynamic)
@dyn1   equ   *-2
        ldu   glb_map_tiles_adr
        leau  d,u
        lda   glb_map_tiles_pge
        _SetCartPageA                                 ; set tile index page
        pulu  a,x                                     ; a: tile routine page, x: tile routine address
        sta   1,y
        stx   2,y
        lda   #0
chk_idx_pge equ *-1
        _SetCartPageA                                 ; restore chunk definition page
        ldu   #0
@dyn2   equ *-2

NextCol
        dec   c_h_tl                                  ; check remaining tiles in this row
        beq   EndOfRow

        ; Move tile position on screen to next column
        ; -------------------------------------------
        ldd   #4                                    ; nb of linear memory bytes between two tiles in a column
        addd  b_loc
        anda  #%00000000
        andb  #%01111100 ; cycle thru this line (0-127) by 4 bytes
        addd  #0
cl_pos  equ   *-2
        std   b_loc
 IFDEF T2
        jmp   DrawTile
 ELSE
        bra   DrawTile
 ENDC

        ; Check end of line of current Chunk
        ; ----------------------------------
EndOfRow                                              ; end of line on right chunk, do we need to go to bottom chunk or exit ?
        dec   c_v_tl
        bne   DrawNextRow

        ; End of DrawChunk, restore map of chunks page
        ; ------------------------------------------------------------------
EndOfChunk
        lda   glb_map_chunk_pge
        _SetCartPageA
        rts

DrawNextRow
        lda   c_h_tl_bck
        sta   c_h_tl

        ldu   #0                                      ; (dynamic)
start_x equ   *-2
        leau  16,u                                    ; a chunk is made of 8 tiles in width
        stu   start_x
        ; Move tile position on screen to next row
        ; -----------------------------------------
        ldd   #0                                      ; (dynamic) nb of linear memory bytes to go from the last tile of a row to the first tile of the next row
r_stp_1 equ   *-2
        addd  b_loc
        anda  #%00000111
        adda  #tile_buffer/256 ; add base address
        std   b_loc
        andb  #%10000000
        std   cl_pos                                  ; save start of line for cycling buffer
        jmp   DrawTile

cpt_x fcb 0

; ****************************************************************************************************************************
; *
; *
; *
; *
; *
; *
; *
; *
; *
; *
; *
; ****************************************************************************************************************************

; 29ms on avg
DrawBufferedTile
; V2-DEVIATION (06/10/2026) : the loop rewritten for speed (sonic-2 measures
; it with tools/ehz_perf.py). X walks the tile buffer, so U no longer goes
; through a save and a restore around each call (the tile routines use D and
; U only) ; LDD sets Z for an empty cell (a zero word) and N for the high
; priority bit, the page is written only for a cell drawn now ; each row is
; cut where the 32 cell ring comes back to its start, once per frame, instead
; of a compare per cell ; the last cell of a row is no longer a case apart
; (it did not queue a high priority tile). The high priority queue lives on
; S : PSHS of the page, the cell and the screen address (13 cycles a tile
; against 51), popped with PULS by DrawHighPriorityBufferedTile. An IRQ or a
; call pushes below S, where the queue is free (filling) or consumed
; (popping) ; the queue's end is an entry of page 0, pushed first.

        lda   glb_camera_move
        bne   @a
        ; nothing drawn : an empty queue for the high priority pass
        clr   tmb_hprio_top-5
        ldd   #tmb_hprio_top-5
        std   DBT_hiptr
        rts
@a

        ; disable page backup (page swap macros)
        ; mandatory if using T2 and direct access to E7E6
        anda  #0
        sta   glb_Page

        ; compute number of tiles to render
        ; saves one tile row or col when camera pos is a multiple of tile size
        ; ---------------------------------------------------------------------
        ldb   #tmb_vp_h_tiles               ; nb of tile in screen width
        lda   <glb_camera_x_pos+1
        anda  #%00000111
        bne   @skip
        decb
@skip   stb   <DBT_ncol

        ldb   #tmb_vp_v_tiles               ; nb of tile in screen height
        lda   <glb_camera_y_pos+1
        anda  #%00001111
        bne   @skip
        decb
@skip   stb   <DBT_lcpt

        ; compute top left tile position on screen
        ; position is rounder to 2 px horizontally beacuse of 2px per byte
        ; and vertically beacuse of interlacing
        ; ---------------------------------------------------------------------
        lda   <glb_camera_x_pos+1
        anda  #%00000110                    ; mask for 8px tile in width
        nega
        adda  #12                           ; on screen position of camera

        ldb   <glb_camera_y_pos+1
        andb  #%00001110                    ; mask for 16px tile in height
        negb
        addb  #20                           ; on screen position of camera

        lsra                                ; x=x/2, sprites moves by 2 pixels on x axis
        lsra                                ; x=x/2, RAMA RAMB interlace
        bcs   @RAM2First                    ; Branch if write must begin in RAM2 first
@RAM1First
        sta   @dyn1
        lda   #40                           ; 40 bytes per line in RAMA or RAMB
        mul
        addd  #$C000                        ; (dynamic)
@dyn1   equ   *-1
        addd  #441 ; tileset should be declared with TILE8x16 center parameter in properties
        std   <glb_screen_location_2
        suba  #$20
        std   <glb_screen_location_1
        bra   @end
@RAM2First
        sta   @dyn2
        lda   #40                           ; 40 bytes per line in RAMA or RAMB
        mul
        addd  #$A000                        ; (dynamic)
@dyn2   equ   *-1
        addd  #441 ; tileset should be declared with TILE8x16 center parameter in properties
        std   <glb_screen_location_2
        addd  #$2001
        std   <glb_screen_location_1
@end    std   DBT_rowy

        ldd   <glb_screen_location_2
        subd  <glb_screen_location_1
        std   DBT_delta
        std   DBT_delta2

        ; compute position in cycling buffer
        ; ---------------------------------------------------------------------
        ldb   <glb_camera_y_pos+1                     ; each 16px steps in y add $80
        lda   #%00010000
        mul
        ldb   <glb_camera_x_pos+1                     ; each 8px steps in x add $04
        andb  #%11111000
        _lsrd
        addd  #tile_buffer
        std   DBT_row

        ; a buffer row is a ring of 32 cells : from the first column, the row
        ; reaches the ring's end at most once, at the same column for all
        andb  #%01111111
        lsrb
        lsrb                                          ; first column
        negb
        addb  #32                                     ; cells up to the ring's end
        cmpb  <DBT_ncol
        blo   @a
        ldb   <DBT_ncol
@a      stb   DBT_run1
        negb
        addb  <DBT_ncol
        stb   DBT_run2                                ; cells after it (0 : none)

        sts   DBT_sys
        lds   #tmb_hprio_top
        clrb                                          ; the queue's end : page 0
        pshs  b,x,y

DBT_lloop
        ldx   #0                                      ; the row's first cell
DBT_row equ   *-2
        ldy   #0                                      ; and screen address
DBT_rowy equ  *-2
        lda   #0
DBT_run1 equ  *-1
        sta   <DBT_ccpt
        lda   #0
DBT_run2 equ  *-1
        sta   <DBT_left

DBT_cloop
        ldd   ,x                                      ; a : flags, b : page (0 : empty)
        beq   DBT_empty
        bmi   DBT_high                                ; a's bit 7 : high priority
        stb   $E7E6
        sty   <glb_screen_location_1                  ; plane 1, read by the routine
        leau  $1234,y                                 ; plane 2
DBT_delta equ *-2
        jsr   [2,x]
DBT_next
        leax  4,x
        leay  2,y
        dec   <DBT_ccpt
        bne   DBT_cloop
        lda   <DBT_left                               ; the row goes on from the ring's start
        beq   @row
        sta   <DBT_ccpt
        clr   <DBT_left
        leax  -128,x
        bra   DBT_cloop
@row    ldd   DBT_rowy                                ; next row : 16 lines down
        addd  #40*16
        std   DBT_rowy
        ldd   DBT_row                                 ; and the buffer's next row
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
        pshs  b,x,y                                   ; page, cell, screen address
        bra   DBT_next

DBT_empty
        inc   <glb_alphaTiles                         ; the background shows : redraw it
        bra   DBT_next

; ****************************************************************************************************************************
; *
; * DrawHighPriorityBufferedTile : the queue DrawBufferedTile pushed on S, popped
; *
; ****************************************************************************************************************************

DrawHighPriorityBufferedTile
        ; disable page backup (page swap macros)
        ; mandatory if using T2 and direct access to E7E6
        anda  #0
        sta   glb_Page
        sts   @sys
        lds   #tmb_hprio_tiles                        ; zeroed by the game : an empty queue
DBT_hiptr equ *-2
        bra   @entry
@loop   sty   <glb_screen_location_1
        leau  $1234,y
DBT_delta2 equ *-2
        jsr   [2,x]
@entry  puls  b,x,y
        stb   $E7E6
        bne   @loop
        lds   #0
@sys    equ   *-2
        rts

 IFDEF TMB_TILE_BUFFER
; V2-DEVIATION: the code takes the buffer's address by its high byte
; (#tile_buffer/256), which a relocatable unit cannot give : a division of a
; relocated label is not a relocation (migration/relocatable-alignment.md). A
; v2 game declares the buffer at a fixed 2048 aligned address, reserved in its
; layout, and clears it before InitTileBuffer : v1's fill was loaded zeros.
tile_buffer equ TMB_TILE_BUFFER
 ELSE
        align 2048
tile_buffer
        fill  0,16*128
 ENDC

 IFDEF TMB_HPRIO_TILES
; V2-DEVIATION: the game may keep the queue out of its unit too, at a fixed
; address it reserves and clears (the zeros v1's fill loaded)
tmb_hprio_tiles equ TMB_HPRIO_TILES
 ELSE
tmb_hprio_tiles
        fill  0,tmb_vp_h_tiles*tmb_vp_v_tiles*7 ; in case all tiles are in high priority ... that's crazy ... you can lower that if you know what you are doing
        fcb   0 ; end marker
 ENDC
; the queue grows down from its top, 5 bytes a tile : 990 at most, the
; room below for an IRQ (12 bytes) and a call (2) is ample
tmb_hprio_top equ tmb_hprio_tiles+tmb_vp_h_tiles*tmb_vp_v_tiles*7