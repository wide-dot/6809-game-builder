; -----------------------------------------------------------------------------
; Multidirectional Scroll (mscroll)
; -----------------------------------------------------------------------------
; wide-dot - Benoit Rousseau - 08/2026
; ---------------------------------------
; V2 fork of the v1 vertical scroll (thomson-to8-game-engine
; engine/graphics/tilemap/vscroll/vscroll.asm @ 00ae193f) — the pristine 1:1
; import lives in engine/graphics/tilemap/vscroll/, this fork diverges.
; Plan and rationale : docs/lang/fr/etude-mscroll-2026-08.md
;   M1 : behaviour-identical clone, vertical axis only (validated 20/08)
;   M2 (this state) : horizontal ribbon displacement on top of the vertical
;        machinery — hscroll-style decomposition x = 16*h + 4*b + 2*w, entry
;        and patched exit offset by h chunks, RAMA/RAMB zone swap for the 2px
;        phase. Body chunks shrink from 8 to 4 data bytes (ldd#/ldx#/pshs d,x)
;        so any line offers a 16px-granular entry ; blast cost +~11%.
;        The ribbon SEAM is assumed : content left of the wrap column comes
;        from the adjacent buffer line (a 1px vertical shear, moving with the
;        scroll) — same trade as hscroll v1.
;   M3 (this state) : horizontal tile feed. The map becomes 2D : rows of
;        16-bit pre-doubled tile ids (row-major), the row stride a POWER OF
;        TWO so a row address is a shift, not a multiply — the generator pads
;        the map width. camera.x becomes a 16-bit pixel position with its own
;        8.8 fraction accumulator (the exact mirror of the vertical axis),
;        clamped against the map edges. When the 16px window crosses a chunk
;        boundary, the entering map column (= one chunk = two 8x16 tiles) is
;        written into its slot (column mod 10) across every buffer line, both
;        planes — one tile line is exactly one chunk operand. Limits : map
;        width <= 2048 px, height <= 4080 px, map data in one 16KB page.
;   M3-opt (this state) : the feed is per 8px TILE column, scheduled on the
;        masked edges (a tile is fed when it comes under the right mask
;        moving right, under the left mask moving left — always complete one
;        8px step before any of its pixels shows). Tiles are stored
;        TILE-MAJOR (the 16 lines of a tile are consecutive words, 32 bytes
;        per tile and per plane, max 512 tiles) and the map holds ids
;        premultiplied by 32 : the feed's inner loop is ldd ,y++ / std ,u —
;        no table, no page traffic per line. Measured : the inner line cost
;        fell from 117 to ~37 cycles.
; -----------------------------------------------------------------------------
; - use a cycling code buffer to render the scroll
; - buffer use stack blasting (pshs d,x)
; - buffer is only updated few lines per frame (only the new lines)
; - scroll is bi-directionnal on both axes
; - speeds are fixed point values and adjusted in regard of frame drop
; - handle up to 512 lines of tiles in a map
; - as S register is used to write in video buffer, an irq will write 12
;   bytes just before the current write position ; keep $9FF4-$9FFF /
;   $BFF4-$BFFF free when the band starts at the top of the screen
; -----------------------------------------------------------------------------

        opt c

; constants
; -----------------------------------------------------------------------------
mscroll.OPCODE_JMP_E        equ   $7E

mscroll.CHUNK_SIZE          equ   8     ; code bytes by 16px chunk (ldd#/ldx#/pshs d,x)
mscroll.CHUNKS_PER_LINE     equ   10
mscroll.LINE_SIZE           equ   mscroll.CHUNKS_PER_LINE*mscroll.CHUNK_SIZE
 IFNDEF  mscroll.BUFFER_LINES
mscroll.BUFFER_LINES        equ   208  ; project should define it : content lines + margin
 ENDC

; parameters
; -----------------------------------------------------------------------------
; scroll data is split in 5 pages
mscroll.obj.map.page        fcb   0
mscroll.obj.map.address     fdb   0
mscroll.obj.tile.pages      fill  0,32 ; pages for every line tileset A and B
mscroll.obj.tile.adresses   fill  0,32 ; tile line bases : $A000 + line*2 (tile-major layout)
mscroll.obj.bufferA.page    fcb   0
mscroll.obj.bufferA.address fdb   0
mscroll.obj.bufferA.end     fdb   0
mscroll.obj.bufferB.page    fcb   0
mscroll.obj.bufferB.address fdb   0
mscroll.obj.bufferB.end     fdb   0
mscroll.camera.speed        fdb   0    ; (signed 8.8 fixed point) vertical, nb of pixels/50hz
mscroll.camera.speedx       fdb   0    ; (signed 8.8 fixed point) horizontal, nb of pixels/50hz

; private variables
; -----------------------------------------------------------------------------
mscroll.cursor.w            fcb   0                                ; padding for 16 bit operations
mscroll.cursor              fcb   0
mscroll.speed               fdb   0                                ; (signed 8.8 fixed point) nb of line to scroll
mscroll.speedx              fdb   0                                ; (signed 8.8 fixed point) nb of px to scroll (horizontal)
mscroll.map.height          fdb   0                                ; map height in pixels
mscroll.map.rowshift        fcb   0                                ; log2 of the map row stride in bytes
mscroll.map.stride          fdb   0                                ; 1 << rowshift (set with it)
mscroll.camera.x            fdb   0                                ; camera position in map (in pixels, integer)
mscroll.camera.x.max        fdb   0                                ; camera x cap : map width − 160
mscroll.window              fcb   0                                ; 16px window base : (camera.x+8)>>4
mscroll.edge8               fcb   0                                ; 8px feed edge : (camera.x+8)>>3
mscroll.stretch             fcb   0                                ; camera.x/160 : index of the map seam the camera sits in
mscroll.seam.slots          fcb   0                                ; nb of window columns beyond the next seam (0-19, contiguous from slot 0)
mscroll.col.cache           fill  0,32                             ; tile feed : one id per tile row (16 rows max)
mscroll.map.cache.LINE_SIZE equ   20*2
mscroll.map.cache.NB_LINES  equ   13
mscroll.map.cache.SIZE      equ   mscroll.map.cache.LINE_SIZE*mscroll.map.cache.NB_LINES
mscroll.map.cache.y         fdb   -1                               ; camera range for the current cached tile line
mscroll.map.cache.cursor    fdb   0                                ; position in cache buffer (adress)
mscroll.map.cache.line      fcb   0                                ; position in cache buffer (in lines)
mscroll.map.cache           fill  0,mscroll.map.cache.SIZE         ; tile ids reflecting scroll buffer
mscroll.map.cache.END       equ   *
mscroll.map.cache.above     fill  0,mscroll.map.cache.LINE_SIZE    ; ids of the row ABOVE the cached one, raw :
                                                                   ; consumed by the seam fixup when the sheared
                                                                   ; write crosses a tile boundary (copyBitmap)
; operand byte offset of each buffer slot within a line (slot p lives in
; chunk 9-(p/2), D operand when even, X operand when odd — feedTile computes
; the same value arithmetically)
mscroll.slot.off            fcb   73,76,65,68,57,60,49,52,41,44
                            fcb   33,36,25,28,17,20,9,12,1,4
mscroll.viewport.height.w   fcb   0                                ; padding for 16 bit operations
mscroll.viewport.height     fcb   0
mscroll.viewport.y          fcb   0                                ; y position of viewport on screen
mscroll.viewport.ram        fdb   0                                ; band end address in the $A000-$BFFF zone
                                                                   ; (was a self-modified lds operand in v1 vscroll.do)
mscroll.camera.y            fdb   0                                ; camera position in map (in pixels)
mscroll.camera.lastY        fdb   0                                ; last camera position in map (in pixels)

; -----------------------------------------------------------------------------
; mscroll.move
; -----------------------------------------------------------------------------
; input  REG : none
; -----------------------------------------------------------------------------
; apply frame compensated speeds to both axes, then feed the code buffer with
; the lines that entered the viewport (vertical axis). The horizontal part
; only moves the window position : the rotation is applied at blast time.
; -----------------------------------------------------------------------------

; temporary variables in dp
mscroll.loop.counter        equ dp_extreg    ; BYTE
mscroll.loop.counter2       equ dp_extreg+1  ; BYTE
mscroll.backBuffer          equ dp_extreg+2  ; BYTE
mscroll.buffer.wAddressA    equ dp_extreg+3  ; WORD
mscroll.buffer.wAddressB    equ dp_extreg+5  ; WORD
mscroll.camera.currentY     equ dp_extreg+7  ; WORD
mscroll.skippedLines        equ dp_extreg+9  ; WORD
mscroll.tileset.line        equ dp_extreg+11 ; BYTE
mscroll.buffer.line         equ dp_extreg+12 ; BYTE
; blast-time variables (mscroll.do only, never live across a frame)
mscroll.h                   equ dp_extreg+13 ; BYTE entry chunk index (0-9)
mscroll.w                   equ dp_extreg+14 ; BYTE 2px phase (0-1)
mscroll.bo                  equ dp_extreg+15 ; WORD S byte offset (-2..1, sign extended)
mscroll.destForA            equ dp_extreg+17 ; WORD S start for buffer A code
mscroll.destForB            equ dp_extreg+19 ; WORD S start for buffer B code
mscroll.dest.current        equ dp_extreg+21 ; WORD S start for current buffer
; tile-feed variables (mscroll.move only — the do block above is dead by
; then, so they share its dp slots plus the tail of the extreg space)
mscroll.fc.newedge          equ dp_extreg+13 ; BYTE 8px edge after the move
mscroll.fc.off              equ dp_extreg+14 ; BYTE operand code offset of the slot
mscroll.fc.row              equ dp_extreg+15 ; WORD top map row (pixels)
mscroll.fc.tl               equ dp_extreg+17 ; BYTE tile line at the top row
mscroll.fc.cache            equ dp_extreg+18 ; WORD row walk of the id gather
mscroll.fc.end              equ dp_extreg+20 ; WORD buffer wrap bound (low)
mscroll.fc.count            equ dp_extreg+22 ; BYTE lines left to feed
mscroll.tmp1                equ dp_extreg+23 ; BYTE scratch (mapRowAddr shift)
mscroll.tmp2                equ dp_extreg+24 ; BYTE scratch (tile, then plane index)
mscroll.fc.srcoff           equ dp_extreg+25 ; WORD map byte offset, then id list cursor
mscroll.fc.rtl              equ dp_extreg+27 ; BYTE tile line of the current run
; y-feed variables (updategfx/updateTileCache — the x-part walk above is
; over by then, so they share the same dp slots)
mscroll.currentYs           equ dp_extreg+13 ; WORD currentY minus the camera stretch (sheared row space)
mscroll.uc.base             equ dp_extreg+25 ; WORD updateTileCache slice destination

mscroll.move

; update horizontal position : accumulate the 8.8 speed, move by whole
; pixels, clamp against the map edges, then feed the 16px columns that
; enter when the window crosses a chunk boundary
; --------------------------------------------------------------------------

        ; check for elapsed frames
        lda   gfxlock.frameDrop.count
        bne   >
@exit0  rts
;
        ; compute frame compensated speed (the accumulator keeps the fraction
        ; between frames, the exact mirror of the vertical axis)
!       sta   <mscroll.loop.counter
        ldd   mscroll.speedx
!       addd  mscroll.camera.speedx
        dec   <mscroll.loop.counter
        bne   <
        std   mscroll.speedx
        ; displacement = int part (by truncating, negative is floor and
        ; positive is ceil, so make it ceil also for negative)
        ldb   mscroll.speedx
        bpl   >
        incb
!       sex
        addd  mscroll.camera.x
        ; clamp in [0, map width − 160]
        bpl   >
        ldd   #0
!       cmpd  mscroll.camera.x.max
        ble   >
        ldd   mscroll.camera.x.max
!       std   mscroll.camera.x
        ; consume the int part, keep the fraction
        ldb   mscroll.speedx
        bpl   >
        ldb   #$ff
        bra   @xtail
!       clrb
@xtail  stb   mscroll.speedx
        ; map-fixed seam : the ribbon split always falls on map columns that
        ; are multiples of 160 px. Content is written pre-sheared (one line
        ; up per seam left of the column — feedTile and the row cache), and
        ; the cycling cursor carries the camera's own seam index as a bias :
        ; it moves by one here when the camera crosses a seam, which happens
        ; while the boundary is hidden under the edge mask — nothing is ever
        ; re-fed for the seam, the image does not move
        ldx   #0
        ldd   mscroll.camera.x
@stret  subd  #160
        blo   >
        leax  1,x
        bra   @stret
!       tfr   x,d
        cmpb  mscroll.stretch
        beq   @snone
        subb  mscroll.stretch
        sex
        addd  mscroll.cursor.w
        bmi   @sup
@smod   cmpd  #mscroll.BUFFER_LINES
        blo   @sok
        subd  #mscroll.BUFFER_LINES
        bra   @smod
@sup    addd  #mscroll.BUFFER_LINES
        bmi   @sup
@sok    std   mscroll.cursor.w
        tfr   x,d
        stb   mscroll.stretch
@snone  equ   *
        ; refresh the 16px window (blast decomposition) and the 8px feed edge
        ldd   mscroll.camera.x
        addd  #8
        _lsrd
        _lsrd
        _lsrd
        stb   <mscroll.fc.newedge
        _lsrd
        stb   mscroll.window
        ; feed the tiles that enter, one 8px column per edge step : moving
        ; right a tile is fed when it comes under the RIGHT mask (edge+18),
        ; moving left when it comes under the LEFT mask (edge-1) — both are
        ; ready one 8px step before any of their pixels leaves the masks
@floop  ldb   <mscroll.fc.newedge
        cmpb  mscroll.edge8
        beq   @xdone
        bhi   @fright
        dec   mscroll.edge8
        ldb   mscroll.edge8
        decb
        jsr   mscroll.feedTile
        bra   @floop
@fright inc   mscroll.edge8
        ldb   mscroll.edge8
        addb  #18
        jsr   mscroll.feedTile
        bra   @floop
@xdone  equ   *
        ; how many window columns sit beyond the next seam : those are the
        ; sheared ones, and they occupy slots 0..n-1 (a seam is a multiple
        ; of 20 columns, so they wrap to the start of the slot space).
        ; updateTileCache bakes their cache entries one tile line up.
        ldb   mscroll.stretch
        incb
        lda   #20
        mul                            ; d = first column past the seam
        std   <mscroll.fc.row          ; (x-part scratch, dead after)
        ldb   mscroll.edge8
        clra
        addd  #19                      ; last column of the window
        subd  <mscroll.fc.row
        bpl   >
        ldd   #0
!       stb   mscroll.seam.slots

; update vertical position in map and buffer (v1 vscroll.move, unchanged)
; ------------------------------------------------------------------------

        ; compute frame compensated speed
        lda   gfxlock.frameDrop.count
        sta   <mscroll.loop.counter
        ldd   mscroll.speed                  ; load speed value of previous frame
!       addd  mscroll.camera.speed           ; mult speed by frame drop
        dec   <mscroll.loop.counter
        bne   <
;
        ; exit if speed is too small (subpixel)
        stb   mscroll.speed+1
        sta   mscroll.speed
        adda  #128 ; this cryptic code negate integer part of a 8.8 value
        eora  #127 ; and round by floor
        sbca  #255 ; cursor goes the opposite direction of y in buffer
        lbeq  mscroll.move.exit        ; global label : a blank line ends an
                                       ; @-local scope in lwasm, and blocks
                                       ; are separated by blanks below
;
        ; compute cursor in cycling buffer code (modulo)
        tfr   a,b
        sex
        bpl   @goUp
@goDown
        addd  mscroll.cursor.w
        bpl   @end
!       addd  #mscroll.BUFFER_LINES
        bmi   <
        bra   @end
@goUp
        addd  mscroll.cursor.w
        cmpd  #mscroll.BUFFER_LINES
        blo   @end
!       subd  #mscroll.BUFFER_LINES
        cmpd  #mscroll.BUFFER_LINES
        bhs   <
@end    stb   mscroll.cursor

        ; compute position in map
        ldx   mscroll.camera.y
        stx   mscroll.camera.lastY
        ldb   mscroll.speed                  ; get int part of 8.8
        bpl   >
        incb                                 ; by truncating, negative is floor and positive is ceil, so make it ceil also for negative
!       leax  b,x                            ; do not use abx, b is signed, speed is implicitly caped to a choppy 127px by frame

        ; wrap camera position in map (infinite level loop)
        tfr   x,d
        cmpx  mscroll.map.height
        bge   >
        tsta
        bpl   @end2
        addd  mscroll.map.height
        bra   @end2
!       subd  mscroll.map.height
@end2   std   mscroll.camera.y
        bra   mscroll.updategfx
mscroll.move.exit
        rts

; mscroll.camera.impulse
; ----------------------
; accumulate an exact displacement : X = dx (signed 8.8 px), D = dy (signed
; 8.8 lines). For script pilots that unwind elapsed video frames themselves,
; one frame at a time : camera.speed/speedx stay at ZERO in this mode and the
; caller pushes the per-frame sum here — the residual accumulators carry a
; sign-extended fraction between game loops, so the addition is exact and
; move applies the whole of it (clamp, seams, feeds) on the next loop. This
; removes the segment-boundary error of the speed mode, where a whole
; frame-drop span is integrated at a single speed.
mscroll.camera.impulse
        addd  mscroll.speed
        std   mscroll.speed
        tfr   x,d
        addd  mscroll.speedx
        std   mscroll.speedx
        rts

; update gfx in buffer code
; -------------------------
mscroll.updategfx
        jsr   mscroll.computeBufferWAddress
        tst   <mscroll.loop.counter          ; nb of lines to render
        lbeq  @exit                          ; when viewport shrink nothing to render
        ; setup mscroll buffers
        ldx   mscroll.obj.bufferA.address
        leax  d,x
        stx   <mscroll.buffer.wAddressA
        ldx   mscroll.obj.bufferB.address
        leax  d,x
        stx   <mscroll.buffer.wAddressB
        ; compute current line in tile
        ldb   map.CF74021.DATA
        stb   <mscroll.backBuffer            ; backup back video buffer
        lda   mscroll.camera.lastY+1         ; LSB only
        adda  <mscroll.skippedLines          ; nb skip lines (outside viewport)
        ldb   mscroll.speed
        bpl   >
        deca                                 ; next line in tile
        ldb   #$4A ; deca
        ldu   #0
        ldx   #mscroll.LINE_SIZE
        ldy   #-1
        bra   @mod
!       adda  mscroll.viewport.height
        inca                                 ; previous line in tile
        ldb   #$4C ; inca
        ldu   mscroll.viewport.height.w
        ldx   #-mscroll.LINE_SIZE
        ldy   #1
@mod
        suba  mscroll.stretch                ; map-fixed shear : the camera's own
                                             ; columns are written one line up per
                                             ; seam left of the camera — exact mod
                                             ; 16 because the map height is a
                                             ; multiple of 16
        anda  #$0f                           ; modulo to keep 0-15
        sta   <mscroll.tileset.line
        ; setup dynamic code in main scroll loop
        sty   @direction
        stb   @direction2
        stu   @direction3
        stx   @direction4
        stx   @direction5
        eorb  #%00000110                     ; inverse deca/inca instruction
        stb   @direction6
        ldd   mscroll.camera.lastY
        addd  #0                             ; add viewport when going down
@direction3 equ *-2
@loop
        addd  #0
@direction equ *-2
        cmpd  mscroll.map.height
        bge   >
        tsta
        bpl   @end1
        addd  mscroll.map.height
        bra   @end1
!       subd  mscroll.map.height
@end1   std   <mscroll.camera.currentY
        subb  mscroll.stretch                ; sheared row space (see @mod above)
        sbca  #0
        bpl   @shok
        addd  mscroll.map.height
@shok   std   <mscroll.currentYs
;
; PROCESS BUFFER A
; ----------------
        andb  #$f0                           ; tile height is 16px, faster check here than _asrd*4
        cmpd  mscroll.map.cache.y
        beq  >
        std   mscroll.map.cache.y            ; load cache at a new position
;
        ldy   #mscroll.map.cache
        lda   <mscroll.buffer.line
        lsra
        lsra
        lsra
        lsra
        sta   mscroll.map.cache.line
        ldb   #mscroll.map.cache.LINE_SIZE
        mul
        leay  d,y
        sty   mscroll.map.cache.cursor
;
        ldd   <mscroll.currentYs
        jsr   mscroll.updateTileCache        ; check cache for this line number (in d)
!       lda   mscroll.obj.bufferA.page
        _SetCartPageA                        ; mount in cartridge space
        lda   <mscroll.tileset.line
        lsla
        ldx   #mscroll.obj.tile.adresses     ; load A tileset addr
        ldy   a,x
        ldx   #mscroll.obj.tile.pages        ; load A tileset page
        lda   a,x
        sta   map.CF74021.DATA               ; mount in data space
        ldu   <mscroll.buffer.wAddressA
        ldx   mscroll.map.cache.cursor
        jsr   mscroll.copyBitmap             ; copy bitmap for buffer A
        leau  1234,u
@direction4 equ *-2
        cmpu  mscroll.obj.bufferA.address
        bge   @tendA
        leau  mscroll.BUFFER_LINES*mscroll.LINE_SIZE,u
        bra   >
@tendA  cmpu  mscroll.obj.bufferA.end
        blt   >
        leau  -mscroll.BUFFER_LINES*mscroll.LINE_SIZE,u
!       stu   <mscroll.buffer.wAddressA
;
; PROCESS BUFFER B
; ----------------
        lda   mscroll.obj.bufferB.page
        _SetCartPageA                        ; mount in cartridge space
        lda   <mscroll.tileset.line
        lsla
        ldx   #mscroll.obj.tile.adresses     ; load B tileset addr
        ldy   a,x
        ldx   #mscroll.obj.tile.pages+1      ; load B tileset page
        lda   a,x
        sta   map.CF74021.DATA               ; mount in data space
        ldu   <mscroll.buffer.wAddressB
        ldx   mscroll.map.cache.cursor
        jsr   mscroll.copyBitmap             ; copy bitmap for buffer B
        lda   <mscroll.buffer.line
        inca
@direction6 equ *-1
        leau  1234,u
@direction5 equ *-2
        cmpu  mscroll.obj.bufferB.address
        bge   @tendB
        lda   #mscroll.BUFFER_LINES-1
        leau  mscroll.BUFFER_LINES*mscroll.LINE_SIZE,u
        bra   >
@tendB  cmpu  mscroll.obj.bufferB.end
        blt   >
        lda   #0
        leau  -mscroll.BUFFER_LINES*mscroll.LINE_SIZE,u
!       stu   <mscroll.buffer.wAddressB
;
        sta   <mscroll.buffer.line
        lda   <mscroll.tileset.line
        inca
@direction2 equ *-1
        anda  #$0f
        sta   <mscroll.tileset.line
;
        ldd   <mscroll.camera.currentY
        dec   <mscroll.loop.counter
        lbne  @loop                          ; loop until all lines are rendered
@exit
        ldb   mscroll.speed
        bpl   >
        ldb   #$ff
        bra   @end2
!       clrb
@end2   stb   mscroll.speed
        ldb   <mscroll.backBuffer            ; restore back video buffer
        stb   map.CF74021.DATA
        rts

; update the horizontal line of tile id in map cache
; --------------------------------------------------
; input REG : [d] SHEARED map row (in pixels — currentYs), [y] cache row base
; input VAR : [currentYs] the same value, reused for the above row
; loads the 20 tile ids of the current 16px window at that row, ROTATED so
; that a cache index is the buffer slot it feeds (column mod 20) —
; copyBitmap then reads the cache linearly, whatever the window position.
; The entries of the columns beyond the next map seam (slots 0..seam.slots-1)
; are then BAKED one tile line up (id*32 - 2) : that is the map-fixed shear,
; paid here once per reload instead of per written line. The row ABOVE is
; loaded raw next to the cache for the lines where the sheared write crosses
; a tile boundary (copyBitmap's fixup).
; The map is rows of 16-bit ids premultiplied by 32, row stride = 1 << rowshift.
mscroll.updateTileCache
        sty   <mscroll.uc.base
        bsr   @slice                   ; the row itself
        ldb   mscroll.seam.slots
        beq   @above
        stb   <mscroll.tmp1
        ldy   <mscroll.uc.base
@bake   ldd   ,y
        subd  #2
        std   ,y++
        dec   <mscroll.tmp1
        bne   @bake
@above  ldd   <mscroll.currentYs       ; the row above, raw, for the fixup
        subd  #16
        bpl   >
        addd  mscroll.map.height       ; the map wraps vertically
!       ldy   #mscroll.map.cache.above
        sty   <mscroll.uc.base
        ; falls through : the second load returns to the caller
@slice  _lsrd
        _lsrd
        _lsrd
        _lsrd                          ; b = tile row (map height <= 4080)
        jsr   mscroll.mapRowAddr       ; x = row base in cartridge window
        lda   mscroll.obj.map.page
        _SetCartPageA                  ; mount page that contain map data
        ; the slice starts one tile left of the 8px feed edge — the exact
        ; set of tiles the tile feed keeps in the buffer slots
        ldb   mscroll.edge8
        decb
        stb   <mscroll.tmp2            ; T0, first tile of the slice
        clra
        aslb
        rola                           ; d = T0 * 2 bytes
        leax  d,x
        ; rotation : dest index = T0 mod 20 (a cache index IS the buffer slot)
        ldb   <mscroll.tmp2
@mod    cmpb  #20
        blo   @modok
        subb  #20
        bra   @mod
@modok  stb   <mscroll.tmp2            ; r
        lda   #20
        suba  <mscroll.tmp2
        sta   <mscroll.loop.counter2   ; 20 − r ids to the right part
        aslb
        ldy   <mscroll.uc.base
        leay  b,y                      ; dest = slice base + 2r
@copy1  ldd   ,x++
        std   ,y++
        dec   <mscroll.loop.counter2
        bne   @copy1
        ldb   <mscroll.tmp2            ; r ids wrap to the slice base
        beq   @done
        stb   <mscroll.loop.counter2
        ldy   <mscroll.uc.base
@copy2  ldd   ,x++
        std   ,y++
        dec   <mscroll.loop.counter2
        bne   @copy2
@done   rts

; map row address
; ---------------
; input REG : [b] tile row — output REG : [x] row base in cartridge window
; (the caller mounts the map page ; the row stride is a power of two so the
; product is a shift)
mscroll.mapRowAddr
        lda   mscroll.map.rowshift
        sta   <mscroll.tmp1
        clra
@shift  aslb
        rola
        dec   <mscroll.tmp1
        bne   @shift
        addd  mscroll.obj.map.address
        tfr   d,x
        rts

; -----------------------------------------------------------------------------
; mscroll.feedTile
; -----------------------------------------------------------------------------
; input  REG : [b] 8px map tile column index
; -----------------------------------------------------------------------------
; write that tile column into its slot (column mod 20) of every buffer line,
; both planes — the horizontal counterpart of the row feed, called by
; mscroll.move at every 8px edge step, inside the gfxlock like the rest of
; the feed. The tile-major layout makes the inner loop trivial : the source
; of a whole run of buffer lines is the tile's consecutive words (,y++), no
; table and no page traffic per line. The ids of the spanned tile rows are
; gathered once (map page mounted once, addresses walked by the row stride),
; then each plane pass runs with its code buffer in the cartridge window and
; its tileset in the data window, both mounted once per pass.
; -----------------------------------------------------------------------------
mscroll.feedTile
        ldu   #-1                      ; the edge moved : the row cache
        stu   mscroll.map.cache.y      ; content belongs to the old slice
        lda   map.CF74021.DATA
        sta   <mscroll.backBuffer      ; backup back video buffer
        stb   <mscroll.tmp2
        clra
        aslb
        rola
        std   <mscroll.fc.srcoff       ; tile*2 : byte offset in a map row
        ; the column's shear : one line up per map seam left of it (seams sit
        ; every 20 columns — see the note in mscroll.move). Stashed in fc.tl
        ; until the row anchor below consumes it and stores the real tile line.
        lda   #0
        ldb   <mscroll.tmp2
@shear  cmpb  #20
        blo   >
        subb  #20
        inca
        bra   @shear
!       sta   <mscroll.fc.tl
        ; operand code offset of the slot : chunk 9-(p/2), D if even, X if odd
        ldb   <mscroll.tmp2
@mod    cmpb  #20
        blo   @modok
        subb  #20
        bra   @mod
@modok  tfr   b,a
        anda  #1
        lsrb
        aslb
        aslb
        aslb
        stb   <mscroll.tmp1
        ldb   #73
        subb  <mscroll.tmp1
        tsta
        beq   >
        addb  #3                       ; odd tile : the X operand
!       stb   <mscroll.fc.off
        ; top map row spanned by the buffer, minus the column's shear
        ldd   mscroll.camera.y
        subb  <mscroll.fc.tl           ; the stashed shear
        sbca  #0
        bpl   >
        addd  mscroll.map.height       ; the map wraps vertically
!       std   <mscroll.fc.row
        ldb   <mscroll.fc.row+1
        andb  #$0F
        stb   <mscroll.fc.tl
        ; gather the column ids, one per tile row, walking down with wrap
        lda   mscroll.obj.map.page
        _SetCartPageA
        ldd   <mscroll.fc.row
        std   <mscroll.fc.cache        ; row walk (pixels)
        _lsrd
        _lsrd
        _lsrd
        _lsrd
        jsr   mscroll.mapRowAddr
        ldd   <mscroll.fc.srcoff
        leax  d,x                      ; x = the column's id in the top row
        ldu   #mscroll.col.cache
        lda   #14                      ; covers BUFFER_LINES + a tile of slack
        sta   <mscroll.fc.count
@gather ldd   ,x
        std   ,u++
        ldd   mscroll.map.stride
        leax  d,x
        ldd   <mscroll.fc.cache        ; next tile row, wrap at map height
        addd  #16
        andb  #$F0
        cmpd  mscroll.map.height
        blo   @nw
        ldx   mscroll.obj.map.address  ; wrapped : rows restart at the top
        ldd   <mscroll.fc.srcoff
        leax  d,x
        ldd   #0
@nw     std   <mscroll.fc.cache
        dec   <mscroll.fc.count
        bne   @gather
        ; write both planes
        clr   <mscroll.tmp2            ; plane index
        lda   mscroll.obj.bufferA.page
        ldx   mscroll.obj.bufferA.address
        bsr   mscroll.feedTile.plane
        lda   #1
        sta   <mscroll.tmp2
        lda   mscroll.obj.bufferB.page
        ldx   mscroll.obj.bufferB.address
        bsr   mscroll.feedTile.plane
        ldb   <mscroll.backBuffer      ; restore back video buffer
        stb   map.CF74021.DATA
        rts

; one plane of the tile feed
; --------------------------
; input REG : [a] code buffer page, [x] code buffer address
; input VAR : [tmp2] plane index, [fc.off/tl] see above, col.cache = the ids
mscroll.feedTile.plane
        _SetCartPageA                  ; the code buffer, for the whole pass
        ldb   <mscroll.tmp2
        ldy   #mscroll.obj.tile.pages
        lda   b,y
        sta   map.CF74021.DATA         ; the tileset, for the whole pass
        ; wrap bound and start position, both carrying the slot offset
        tfr   x,d
        addb  <mscroll.fc.off
        adca  #0
        std   <mscroll.fc.end          ; low bound : line 0\'s operand
        pshs  x
        lda   mscroll.cursor           ; top line = (cursor-1) mod BUFFER_LINES
        bne   >                        ; only 0 wraps — a deca/bpl guard here
        lda   #mscroll.BUFFER_LINES    ; would also fire for cursor 129..200
!       deca                           ; (bit 7 set after the dec) and anchor
                                       ; every feed at line 200, shifting the
                                       ; whole column by 201-cursor pixels
        ldb   #mscroll.LINE_SIZE
        mul
        addd  ,s++
        addb  <mscroll.fc.off
        adca  #0
        tfr   d,u                      ; u = operand of the top line
        ; per-pass run state
        ldb   <mscroll.fc.tl
        stb   <mscroll.fc.rtl
        ldd   #mscroll.col.cache
        std   <mscroll.fc.srcoff       ; id list cursor
        ldb   #mscroll.BUFFER_LINES
        stb   <mscroll.fc.count
@outer  ldx   <mscroll.fc.srcoff
        ldd   ,x++
        stx   <mscroll.fc.srcoff
        addd  #$A000                   ; id is premultiplied by 32
        tfr   d,y
        ldb   <mscroll.fc.rtl
        aslb
        leay  b,y                      ; y = tile data at the run\'s first line
        ; run length = min(16 - rtl, lines left)
        lda   #16
        suba  <mscroll.fc.rtl
        cmpa  <mscroll.fc.count
        bls   >
        lda   <mscroll.fc.count
!       sta   <mscroll.loop.counter2
        ldb   <mscroll.fc.count
        pshs  a
        subb  ,s+
        stb   <mscroll.fc.count
@inner  ldd   ,y++
        std   ,u
        leau  -mscroll.LINE_SIZE,u
        cmpu  <mscroll.fc.end
        bge   >                        ; SIGNED : the buffer loads at $0000,
                                       ; u underflows below zero at the wrap
                                       ; and an unsigned compare would see
                                       ; $FFxx as huge, skip the wrap and
                                       ; spray the walk over the I/O page
                                       ; (v1 guards its walks the same way)
        leau  mscroll.BUFFER_LINES*mscroll.LINE_SIZE,u
!       dec   <mscroll.loop.counter2
        bne   @inner
        tst   <mscroll.fc.count
        beq   @done
        clr   <mscroll.fc.rtl
        bra   @outer
@done   rts

; copy the tile bitmap to the code buffer
; read tiles in reverse order (from right to left)
; ------------------------------------------------
; M2 chunk geometry : 10 chunks of 8 code bytes per line, each holding two
; 8px tiles — D operand (offset 1) is the left tile of the chunk, X operand
; (offset 4) the right one. Chunk 0 is executed first and writes the
; rightmost 16px of the line (S pushes downward).
mscroll.copyBitmap
        ldd   38,x                     ; [6] load tile id
        ldd   d,y                      ; [9] load 4 pixels of this tile line
        std   4,u                      ; [6] fill the LDX of chunk 0
        ldd   36,x
        ldd   d,y
        std   1,u                      ; fill the LDD of chunk 0
        ldd   34,x
        ldd   d,y
        std   12,u                     ; chunk 1
        ldd   32,x
        ldd   d,y
        std   9,u

        ldd   30,x
        ldd   d,y
        std   20,u                     ; chunk 2
        ldd   28,x
        ldd   d,y
        std   17,u
        ldd   26,x
        ldd   d,y
        std   28,u                     ; chunk 3
        ldd   24,x
        ldd   d,y
        std   25,u

        ldd   22,x
        ldd   d,y
        std   36,u                     ; chunk 4
        ldd   20,x
        ldd   d,y
        std   33,u
        ldd   18,x
        ldd   d,y
        std   44,u                     ; chunk 5
        ldd   16,x
        ldd   d,y
        std   41,u

        ldd   14,x
        ldd   d,y
        std   52,u                     ; chunk 6
        ldd   12,x
        ldd   d,y
        std   49,u
        ldd   10,x
        ldd   d,y
        std   60,u                     ; chunk 7
        ldd   8,x
        ldd   d,y
        std   57,u

        ldd   6,x
        ldd   d,y
        std   68,u                     ; chunk 8
        ldd   4,x
        ldd   d,y
        std   65,u
        ldd   2,x
        ldd   d,y
        std   76,u                     ; chunk 9 (leftmost 16px)
        ldd   ,x                       ; [5] load tile id
        ldd   d,y
        std   73,u
        ; seam fixup : the sheared columns (their cache ids are baked one
        ; tile line up, see updateTileCache) crossed a tile boundary on the
        ; lines where the pass above used tile line 0 — rewrite those slots
        ; from the ABOVE-row cache at tile line 15. One line in sixteen.
        tst   <mscroll.tileset.line
        bne   @nofix
        ldb   mscroll.seam.slots
        beq   @nofix
        stb   <mscroll.loop.counter2
        ldx   #mscroll.map.cache.above
        ldy   #mscroll.slot.off
        pshs  u
@fix    lda   ,y+                      ; operand offset of this slot
        ldu   ,s                       ; line base
        leau  a,u                      ; operand address
        ldd   ,x++                     ; id of the tile in the row above
        addd  #$A000+30                ; its line 15 (tile-major : +2 per line)
        pshs  u
        tfr   d,u
        ldd   ,u                       ; the bitmap word
        puls  u
        std   ,u
        dec   <mscroll.loop.counter2
        bne   @fix
        puls  u
@nofix  rts

; compute write location in buffer
; --------------------------------
mscroll.computeBufferWAddress

        ; compute number of lines to render
        ldd   #0
        std   <mscroll.skippedLines        ; init tmp value
        ldb   mscroll.speed
        bpl   >
        comb                               ; by truncating, negative is floor and positive is ceil, so make it ceil also for negative
!       cmpb  mscroll.viewport.height      ; compare to viewport height
        bls   >
        subb  mscroll.viewport.height
        stb   <mscroll.skippedLines+1      ; number of skipped lines (outside of viewport)
        ldb   mscroll.viewport.height      ; keep lowest value
!       stb   <mscroll.loop.counter        ; setup nb of line to render

        ; compute relative write location in code buffer
        tst   mscroll.speed
        bmi   @goUp
@goDown
        addd  mscroll.cursor.w
        subd  #1
        subd  <mscroll.skippedLines        ; skip lines if needed
        bmi   @loop
        cmpd  #mscroll.BUFFER_LINES
        bhs   @loop2
        bra   >
@loop
        addd  #mscroll.BUFFER_LINES    ; cycling in buffer
        bmi   @loop
        bra   >
@goUp
        negb                           ; substract it to cursor + viewport height
        sex                            ; omg !
        addd  mscroll.cursor.w
        addd  mscroll.viewport.height.w
        addd  <mscroll.skippedLines
        addd  #1                       ; V2-DEVIATION vs v1 vscroll : without it
                                       ; the upward feed lands one buffer line
                                       ; below the pairing the downward feed and
                                       ; the blast maintain, shifting every
                                       ; up-fed row by one pixel (measured on
                                       ; the mscroll test pattern ; v1 probably
                                       ; carries the same latent bias, never
                                       ; checked byte-exact)
        cmpd  #mscroll.BUFFER_LINES
        blo   >
@loop2
        subd  #mscroll.BUFFER_LINES    ; cycling in buffer
        cmpd  #mscroll.BUFFER_LINES
        bhs   @loop2
!       stb   <mscroll.buffer.line
        lda   #mscroll.LINE_SIZE
        mul
        rts

; -----------------------------------------------------------------------------
; mscroll.do
; -----------------------------------------------------------------------------
; input  REG : none
; -----------------------------------------------------------------------------
; render the whole band at the current position (to be called between
; _gfxlock.on and _gfxlock.off, writes to the back buffer).
;
; The vertical position selects the entry LINE (the vscroll cursor) ; the
; horizontal position is decomposed like hscroll :
;   x = 16*h + 4*bo + 2*w    h  : entry chunk in every line (0-9)
;                            bo : S byte offset (-2..1)
;                            w  : 2px phase, swap RAMA/RAMB destinations
; Entry point and patched exit are both offset by h chunks, so the run
; still covers exactly viewport.height lines of data : no hole, no guard
; line — the exit patch of vscroll already lands wherever we need it.
; When the first screen line is part of the scroll, as S register is used
; to write in video buffer, expect irq to write 12 bytes just before the
; current write position (see header note).
; -----------------------------------------------------------------------------
mscroll.do
        ; decompose the window position : x = 16*window + 4*bo + 2*w
        ; The slot layout is REVERSED (chunk c of a line holds map column
        ; 9-c — inherited from the v1 buffer order, where chunk 0 writes the
        ; rightmost 16px), so the entry chunk is MINUS the window modulo 10.
        ; The fine part only needs the low byte (16*window carries the rest).
        ldb   mscroll.window
@mod    cmpb  #10
        blo   @modok
        subb  #10
        bra   @mod
@modok  beq   >
        subb  #10
        negb                           ; h = (10 − window mod 10) mod 10
!       stb   <mscroll.h
        ldb   mscroll.camera.x+1       ; low byte of the pixel position
        addb  #8
        andb  #$0F
        subb  #8                       ; b = fine part (-8..7)
        tfr   b,a
        asra                           ; a = fine part / 2 (-4..3)
        tfr   a,b
        andb  #1
        stb   <mscroll.w
        asra                           ; a = S byte offset (-2..1)
        tfr   a,b
        sex
        _negd                          ; camera convention : +x shows content
                                       ; further right, the OPPOSITE of the
                                       ; hscroll band rotation — both fine
                                       ; terms flip sign (bo here, w below)
        std   <mscroll.bo

        ; compute S start address for each code buffer.
        ; viewport.ram is the band end in the $A000-$BFFF zone (RAMB) ;
        ; +$2000 is the same spot in the $C000-$DFFF zone (RAMA)
        tst   <mscroll.w
        bne   @w1
        ; phase 0 : plane 0 -> $C000 zone, plane 1 -> $A000 zone
        addd  mscroll.viewport.ram
        std   <mscroll.destForB
        addd  #$2000
        std   <mscroll.destForA
        bra   @run
        ; phase 1 (2px) : plane 0 -> $A000 zone (−1), plane 1 -> $C000 zone —
        ; the mirror of the hscroll variant : the zone swap shifts plane 0 by
        ; −2px and plane 1 by +2px ; pulling plane 0's destination back one
        ; byte adds +4px to it, so both planes land at +2px
@w1     addd  mscroll.viewport.ram
        subd  #1
        std   <mscroll.destForA
        addd  #$2000+1
        std   <mscroll.destForB
@run
        ; run buffer B then buffer A
        ldd   <mscroll.destForB
        std   <mscroll.dest.current
        lda   mscroll.obj.bufferB.page
        ldx   mscroll.obj.bufferB.address
        bsr   mscroll.runBuffer
        ldd   <mscroll.destForA
        std   <mscroll.dest.current
        lda   mscroll.obj.bufferA.page
        ldx   mscroll.obj.bufferA.address
        ; fallthrough to mscroll.runBuffer (last call, returns to caller)

; -----------------------------------------------------------------------------
; mscroll.runBuffer
; -----------------------------------------------------------------------------
; input  REG : [a] code buffer page
; input  REG : [x] code buffer address (in cartridge space)
; input  VAR : [mscroll.dest.current] S start address
; input  VAR : [mscroll.cursor] entry line, [mscroll.h] entry chunk
; -----------------------------------------------------------------------------
mscroll.runBuffer
        _SetCartPageA                  ; mount page that contain buffer code
        ; exit position : ((cursor + height) mod BUFFER_LINES) lines + h chunks
        ldb   mscroll.cursor
        addb  mscroll.viewport.height
        bcs   @cycle
        cmpb  #mscroll.BUFFER_LINES
        blo   >                        ; strict : with h > 0 an exit placed at
                                       ; BUFFER_LINES*LINE_SIZE+h*8 would land
                                       ; past the wrap jmp — wrap to line 0
                                       ; instead (the wrap jmp then runs once
                                       ; before the patched exit, 4 cycles)
@cycle  subb  #mscroll.BUFFER_LINES    ; cycling in buffer
!       lda   #mscroll.LINE_SIZE
        mul
        leau  d,x
        ldb   <mscroll.h
        aslb
        aslb
        aslb                           ; b = h * CHUNK_SIZE
        leau  b,u                      ; u = where the exit jmp is placed
        pulu  a,y                      ; save 3 bytes that will be erased by the jmp
        stu   @save_u
        pshs  a,y
        lda   #mscroll.OPCODE_JMP_E    ; build exit jmp instruction
        ldy   #@ret
        sta   -3,u
        sty   -2,u
        sts   @save_s
        lds   <mscroll.dest.current
        ; entry position : cursor lines + h chunks
        lda   mscroll.cursor
        ldb   #mscroll.LINE_SIZE
        mul
        leax  d,x
        ldb   <mscroll.h
        aslb
        aslb
        aslb
        leax  b,x                      ; x = entry point in code buffer
        jmp   ,x
@ret    lds   #0
@save_s equ   *-2
        ldu   #0
@save_u equ   *-2
        puls  a,x
        pshu  a,x                      ; restore 3 bytes in buffer
        rts
