; -----------------------------------------------------------------------------
; Multidirectional Scroll, one bit per pixel (mscroll1)
; -----------------------------------------------------------------------------
; wide-dot - Benoit Rousseau - 10/2026
; ---------------------------------------
; Fork of engine/graphics/tilemap/mscroll/mscroll.asm (the BM16 version, R-Type
; stage 3) for the 1 bpp screen modes ($24 : RAMA alone, 320x200x2). Plan and
; rationale : docs/lang/fr/etude-mscroll1-2026-10.md.
;
; What carries over unchanged : the cyclic code buffer of stack pushes, the
; vertical machinery (cursor, row feed, row cache), the ribbon entry/exit,
; the per-column feed scheduled on the masked edges. The map-fixed seam
; shear carries over CORRECTED (study §4) : the cursor bias is -S with
; S = ceil(window/10), the shear is relative to the camera, and the row the
; bias move uncovers is fed (mscroll1.feedLine).
; A 1 bpp line of 320 px is 40 bytes : exactly one line of the BM16 code
; buffer (10 chunks ldd#/ldx#/pshs d,x). A 16x16 block is 2 bytes x 16 lines :
; exactly one BM16 tile of one plane, one operand per buffer line. So a slot
; (one operand) is a 16 px BLOCK column here, where it was an 8 px tile column
; of one plane in BM16 — every slot, seam and shear rule reads the same.
;
; What differs :
; - ONE plane : one code buffer, one tileset page, one blast pass, into the
;   RAMA zone ($C000-$DFFF of the data window).
; - horizontal decomposition x = 32*h + 8*bo (h : entry chunk, bo : S byte
;   offset -2..1). There is no RAMA/RAMB swap at 1 bpp : the step is 8 px,
;   the blast shows the window at camera.x rounded DOWN to a multiple of 8.
;   The game draws its sprites against that rounded position.
; - block columns are 16-bit (the map may be up to 32 K px wide) : column
;   mod 20 (slot) and column / 20 (seam index) come from mscroll1.divmod20.
; - TWO-LEVEL map, the Mega Drive way : a layout of chunk indices (one byte
;   each, row-major, any stride up to 255) and a chunk table (128 bytes per
;   chunk : 8 rows of 8 block ids, each premultiplied by 32), both in one page
;   mounted in cartridge space. Chunks are 128x128 px.
; - no generated start buffer : the code buffer is a skeleton and
;   mscroll1.init fills it by feeding the 20 window columns.
;
; Limits : map height <= 4080 px (a multiple of 128), width <= 32 K px, the
; tileset <= 512 blocks (one page, read through the data window), layout +
; chunk table in one 16 KB page.
; -----------------------------------------------------------------------------
; - as S register is used to write in video buffer, an irq will write 12
;   bytes just before the current write position : with the band at the top
;   of the screen, they land in $BFF4-$BFFF (the unused RAMB zone in $24)
; -----------------------------------------------------------------------------

        opt c

; constants
; -----------------------------------------------------------------------------
mscroll1.OPCODE_JMP_E        equ   $7E

mscroll1.CHUNK_SIZE          equ   8     ; code bytes by 32px chunk (ldd#/ldx#/pshs d,x)
mscroll1.CHUNKS_PER_LINE     equ   10
mscroll1.LINE_SIZE           equ   mscroll1.CHUNKS_PER_LINE*mscroll1.CHUNK_SIZE
 IFNDEF  mscroll1.BUFFER_LINES
mscroll1.BUFFER_LINES        equ   201  ; project should define it : content lines + 1
 ENDC

; parameters
; -----------------------------------------------------------------------------
mscroll1.map.page            fcb   0    ; layout + chunks, mounted in cartridge space
mscroll1.map.layout          fdb   0    ; layout base : one chunk index per byte, row-major
mscroll1.map.layout.stride   fcb   0    ; bytes per layout row
mscroll1.map.chunks          fdb   0    ; chunk table : 128 bytes per chunk
mscroll1.tile.page           fcb   0    ; tileset page, mounted in the data window
mscroll1.tile.adresses       fill  0,32 ; tile line bases : $A000 + line*2 (tile-major layout)
mscroll1.buffer.page         fcb   0
mscroll1.buffer.address      fdb   0
mscroll1.buffer.end          fdb   0
mscroll1.camera.speed        fdb   0    ; (signed 8.8 fixed point) vertical, nb of pixels/50hz
mscroll1.camera.speedx       fdb   0    ; (signed 8.8 fixed point) horizontal, nb of pixels/50hz

; private variables
; -----------------------------------------------------------------------------
mscroll1.cursor.w            fcb   0                                ; padding for 16 bit operations
mscroll1.cursor              fcb   0
mscroll1.speed               fdb   0                                ; (signed 8.8 fixed point) nb of line to scroll
mscroll1.speedx              fdb   0                                ; (signed 8.8 fixed point) nb of px to scroll (horizontal)
mscroll1.map.height          fdb   0                                ; map height in pixels
mscroll1.map.rows            fcb   0                                ; map height in 16px block rows
mscroll1.camera.x            fdb   0                                ; camera position in map (in pixels, integer)
mscroll1.camera.x.max        fdb   0                                ; camera x cap : map width - 320
mscroll1.window              fdb   0                                ; 32px window base : (camera.x+16)>>5
mscroll1.edge                fdb   0                                ; 16px feed edge : (camera.x+16)>>4
mscroll1.newedge             fdb   0                                ; the edge after the move
mscroll1.stretch             fcb   0                                ; (camera.x>>4)/20 : index of the map seam the camera sits in
mscroll1.seam.slots          fcb   0                                ; nb of window columns beyond the next seam (0-19, contiguous from slot 0)
mscroll1.q                   fcb   0                                ; divmod20 quotient bits
mscroll1.seam.moved          fcb   0                                ; S moved this frame : +n / -n (move only)
mscroll1.fl.line             fcb   0                                ; feedLine : the buffer line
mscroll1.col.cache           fill  0,28                             ; tile feed : one id per block row (14 rows)
; map walk state (row slice and column gather)
mscroll1.r.row               fcb   0                                ; block row
mscroll1.r.rowoff            fcb   0                                ; (row & 7) * 16 : the row inside a chunk
mscroll1.r.lrow              fdb   0                                ; layout row base
mscroll1.r.col               fdb   0                                ; block column
mscroll1.r.end               fdb   0                                ; end of the slice destination (base + 40)
mscroll1.f.col               fdb   0                                ; fed column
mscroll1.f.cc                fdb   0                                ; its chunk column
mscroll1.f.kx                fcb   0                                ; its byte offset in a chunk row ((col & 7) * 2)
mscroll1.map.cache.LINE_SIZE equ   20*2
mscroll1.map.cache.NB_LINES  equ   13
mscroll1.map.cache.SIZE      equ   mscroll1.map.cache.LINE_SIZE*mscroll1.map.cache.NB_LINES
mscroll1.map.cache.y         fdb   -1                               ; camera range for the current cached tile line
mscroll1.map.cache.cursor    fdb   0                                ; position in cache buffer (adress)
mscroll1.map.cache.line      fcb   0                                ; position in cache buffer (in lines)
mscroll1.map.cache           fill  0,mscroll1.map.cache.SIZE        ; tile ids reflecting scroll buffer
mscroll1.map.cache.END       equ   *
mscroll1.map.cache.above     fill  0,mscroll1.map.cache.LINE_SIZE   ; ids of the row ABOVE the cached one, raw :
                                                                    ; consumed by the seam fixup when the sheared
                                                                    ; write crosses a tile boundary (copyBitmap)
; operand byte offset of each buffer slot within a line (slot p lives in
; chunk 9-(p/2), D operand when even, X operand when odd)
mscroll1.slot.off            fcb   73,76,65,68,57,60,49,52,41,44
                             fcb   33,36,25,28,17,20,9,12,1,4
mscroll1.viewport.height.w   fcb   0                                ; padding for 16 bit operations
mscroll1.viewport.height     fcb   0
mscroll1.viewport.y          fcb   0                                ; y position of viewport on screen
mscroll1.viewport.ram        fdb   0                                ; band end address in the $A000-$BFFF zone
mscroll1.camera.y            fdb   0                                ; camera position in map (in pixels)
mscroll1.camera.lastY        fdb   0                                ; last camera position in map (in pixels)

; temporary variables in dp
mscroll1.loop.counter        equ dp_extreg    ; BYTE
mscroll1.loop.counter2       equ dp_extreg+1  ; BYTE
mscroll1.backBuffer          equ dp_extreg+2  ; BYTE
mscroll1.buffer.wAddress     equ dp_extreg+3  ; WORD
mscroll1.camera.currentY     equ dp_extreg+7  ; WORD
mscroll1.skippedLines        equ dp_extreg+9  ; WORD
mscroll1.tileset.line        equ dp_extreg+11 ; BYTE
mscroll1.buffer.line         equ dp_extreg+12 ; BYTE
; blast-time variables (mscroll1.do only, never live across a frame)
mscroll1.h                   equ dp_extreg+13 ; BYTE entry chunk index (0-9)
mscroll1.dest                equ dp_extreg+15 ; WORD S start
; tile-feed variables (mscroll1.feedTile only)
mscroll1.fc.off              equ dp_extreg+14 ; BYTE operand code offset of the slot
mscroll1.fc.row              equ dp_extreg+15 ; WORD top map row (pixels)
mscroll1.fc.tl               equ dp_extreg+17 ; BYTE tile line at the top row
mscroll1.fc.end              equ dp_extreg+20 ; WORD buffer wrap bound (low)
mscroll1.fc.count            equ dp_extreg+22 ; BYTE lines left to feed
mscroll1.tmp1                equ dp_extreg+23 ; BYTE scratch
mscroll1.fc.srcoff           equ dp_extreg+25 ; WORD id list cursor
mscroll1.fc.rtl              equ dp_extreg+27 ; BYTE tile line of the current run
; y-feed variables (updategfx/updateTileCache)
mscroll1.currentYs           equ dp_extreg+13 ; WORD currentY minus the camera stretch (sheared row space)
mscroll1.uc.base             equ dp_extreg+25 ; WORD updateTileCache slice destination

; -----------------------------------------------------------------------------
; mscroll1.init
; -----------------------------------------------------------------------------
; input  REG : none
; -----------------------------------------------------------------------------
; fill the code buffer for the current camera position : the 20 window
; columns (edge-1 .. edge+18) are fed over every buffer line. Call once the
; map, tileset, buffer, viewport and both camera positions are set (the
; buffer itself only has to hold the chunk skeleton). ~20 column feeds.
; -----------------------------------------------------------------------------
mscroll1.init
        ldd   mscroll1.edge
        subd  #1
        std   mscroll1.newedge         ; (scratch : the column walk)
@loop   ldd   mscroll1.newedge
        jsr   mscroll1.feedTile
        ldd   mscroll1.newedge
        addd  #1
        std   mscroll1.newedge
        subd  mscroll1.edge
        cmpd  #18                      ; up to edge+18 included
        ble   @loop
        rts

; -----------------------------------------------------------------------------
; mscroll1.divmod20
; -----------------------------------------------------------------------------
; input  REG : [d] value, 0-2559
; output REG : [a] value / 20, [b] value mod 20
; -----------------------------------------------------------------------------
; binary long division by 20 : seven conditional subtractions of 20*2^k,
; the quotient bits shifted in complemented (C is set when a step does NOT
; subtract) and fixed at the end. ~140 cycles.
; -----------------------------------------------------------------------------
mscroll1.divmod20
        cmpd  #1280
        bcs   >
        subd  #1280
!       rol   mscroll1.q
        cmpd  #640
        bcs   >
        subd  #640
!       rol   mscroll1.q
        cmpd  #320
        bcs   >
        subd  #320
!       rol   mscroll1.q
        cmpd  #160
        bcs   >
        subd  #160
!       rol   mscroll1.q
        cmpd  #80
        bcs   >
        subd  #80
!       rol   mscroll1.q
        cmpd  #40
        bcs   >
        subd  #40
!       rol   mscroll1.q
        cmpd  #20
        bcs   >
        subd  #20
!       rol   mscroll1.q
        lda   mscroll1.q
        coma
        anda  #$7F
        rts

; -----------------------------------------------------------------------------
; mscroll1.move
; -----------------------------------------------------------------------------
; input  REG : none
; -----------------------------------------------------------------------------
; apply frame compensated speeds to both axes, then feed the code buffer with
; the columns and the lines that entered the window. The horizontal part only
; moves the window position : the rotation is applied at blast time.
; -----------------------------------------------------------------------------
mscroll1.move

; update horizontal position : accumulate the 8.8 speed, move by whole
; pixels, clamp against the map edges, then feed the 16px block columns that
; enter
; --------------------------------------------------------------------------

        ; check for elapsed frames
        lda   gfxlock.frameDrop.count
        bne   >
@exit0  rts
;
        ; compute frame compensated speed (the accumulator keeps the fraction
        ; between frames, the exact mirror of the vertical axis)
!       sta   <mscroll1.loop.counter
        ldd   mscroll1.speedx
!       addd  mscroll1.camera.speedx
        dec   <mscroll1.loop.counter
        bne   <
        std   mscroll1.speedx
        ; displacement = int part (by truncating, negative is floor and
        ; positive is ceil, so make it ceil also for negative)
        ldb   mscroll1.speedx
        bpl   >
        incb
!       sex
        addd  mscroll1.camera.x
        ; clamp in [0, map width - 320]
        bpl   >
        ldd   #0
!       cmpd  mscroll1.camera.x.max
        ble   >
        ldd   mscroll1.camera.x.max
!       std   mscroll1.camera.x
        ; consume the int part, keep the fraction
        ldb   mscroll1.speedx
        bpl   >
        ldb   #$ff
        bra   @xtail
!       clrb
@xtail  stb   mscroll1.speedx
        ; map-fixed seam : the ribbon split always falls on map columns that
        ; are multiples of 320 px (20 block columns). A buffer slot lands on
        ; its screen line, or on the line below when the line it belongs to
        ; wraps : the carry is ceil(window/10) - shear(column) (shear = the
        ; column's seam index, column/20). So a column is written pre-sheared
        ; RELATIVE to the camera (shear(c) - S + 1 lines up, 0 or 1 for the
        ; window, see feedTile and the row cache) and the cycling cursor
        ; carries -S as a bias, S = ceil(window/10) : it moves by one here
        ; when the window crosses 10k -> 10k+1 — nothing is ever re-fed for
        ; the seam, the image does not move
        ldd   mscroll1.camera.x
        addd  #16
        _lsrd
        _lsrd
        _lsrd
        _lsrd
        _lsrd                          ; window
        addd  #9
        aslb
        rola                           ; 2*(window+9) : /20 = ceil(window/10)
        jsr   mscroll1.divmod20        ; a = S
        cmpa  mscroll1.stretch
        beq   @snone
        tfr   a,b
        subb  mscroll1.stretch
        sta   mscroll1.stretch
        stb   mscroll1.seam.moved      ; the row it uncovers is fed below
        negb                           ; the bias is -S
        sex
        addd  mscroll1.cursor.w
        bmi   @sup
@smod   cmpd  #mscroll1.BUFFER_LINES
        blo   @sok
        subd  #mscroll1.BUFFER_LINES
        bra   @smod
@sup    addd  #mscroll1.BUFFER_LINES
        bmi   @sup
@sok    std   mscroll1.cursor.w
@snone  equ   *
        ; refresh the 32px window (blast decomposition) and the 16px feed edge
        ldd   mscroll1.camera.x
        addd  #16
        _lsrd
        _lsrd
        _lsrd
        _lsrd
        std   mscroll1.newedge
        _lsrd
        std   mscroll1.window
        ; feed the blocks that enter, one 16px column per edge step : moving
        ; right a column is fed when it comes under the RIGHT mask (edge+18),
        ; moving left when it comes under the LEFT mask (edge-1)
@floop  ldd   mscroll1.newedge
        cmpd  mscroll1.edge
        beq   @xdone
        bhi   @fright
        ldd   mscroll1.edge
        subd  #1
        std   mscroll1.edge
        subd  #1
        jsr   mscroll1.feedTile
        bra   @floop
@fright ldd   mscroll1.edge
        addd  #1
        std   mscroll1.edge
        addd  #18
        jsr   mscroll1.feedTile
        bra   @floop
@xdone  equ   *
        ; how many window columns sit beyond the next seam (column 20*S) :
        ; those are the sheared ones, and they occupy slots 0..n-1 (a seam
        ; is a multiple of 20 columns, so they wrap to the start of the slot
        ; space). updateTileCache bakes their cache entries one tile line up.
        ldb   mscroll1.stretch
        lda   #20
        mul                            ; d = first column past the seam
        std   <mscroll1.fc.row         ; (x-part scratch, dead after)
        ldd   mscroll1.edge
        addd  #19                      ; one past the last column of the slice
        subd  <mscroll1.fc.row
        bpl   >
        ldd   #0
!       stb   mscroll1.seam.slots
        ; the cursor bias moved : the BUFFER_LINES rows the buffer holds
        ; slid by one for every column, and one buffer line now pairs with
        ; a row nobody fed. S up (cursor -1) : line cursor, the row
        ; y + BUFFER_LINES-1 (the hidden one below). S down (cursor +1) :
        ; line cursor-1, the row y (the visible top line). One row feed.
        ldb   mscroll1.seam.moved
        beq   @nomove
        clr   mscroll1.seam.moved
        tstb
        bmi   @sdown
        ldb   mscroll1.cursor
        clra
        tfr   d,x
        ldd   mscroll1.camera.y
        addd  #mscroll1.BUFFER_LINES-1
        cmpd  mscroll1.map.height
        blo   @feedl
        subd  mscroll1.map.height
        bra   @feedl
@sdown  ldb   mscroll1.cursor
        bne   >
        ldb   #mscroll1.BUFFER_LINES
!       decb
        clra
        tfr   d,x
        ldd   mscroll1.camera.y
@feedl  jsr   mscroll1.feedLine
@nomove equ   *

; update vertical position in map and buffer (v1 vscroll.move, unchanged)
; ------------------------------------------------------------------------

        ; compute frame compensated speed
        lda   gfxlock.frameDrop.count
        sta   <mscroll1.loop.counter
        ldd   mscroll1.speed                 ; load speed value of previous frame
!       addd  mscroll1.camera.speed          ; mult speed by frame drop
        dec   <mscroll1.loop.counter
        bne   <
;
        ; exit if speed is too small (subpixel)
        stb   mscroll1.speed+1
        sta   mscroll1.speed
        adda  #128 ; this cryptic code negate integer part of a 8.8 value
        eora  #127 ; and round by floor
        sbca  #255 ; cursor goes the opposite direction of y in buffer
        lbeq  mscroll1.move.exit       ; global label : a blank line ends an
                                       ; @-local scope in lwasm, and blocks
                                       ; are separated by blanks below
;
        ; compute cursor in cycling buffer code (modulo)
        tfr   a,b
        sex
        bpl   @goUp
@goDown
        addd  mscroll1.cursor.w
        bpl   @end
!       addd  #mscroll1.BUFFER_LINES
        bmi   <
        bra   @end
@goUp
        addd  mscroll1.cursor.w
        cmpd  #mscroll1.BUFFER_LINES
        blo   @end
!       subd  #mscroll1.BUFFER_LINES
        cmpd  #mscroll1.BUFFER_LINES
        bhs   <
@end    stb   mscroll1.cursor

        ; compute position in map
        ldx   mscroll1.camera.y
        stx   mscroll1.camera.lastY
        ldb   mscroll1.speed                 ; get int part of 8.8
        bpl   >
        incb                                 ; by truncating, negative is floor and positive is ceil, so make it ceil also for negative
!       leax  b,x                            ; do not use abx, b is signed, speed is implicitly caped to a choppy 127px by frame

        ; wrap camera position in map (infinite level loop)
        tfr   x,d
        cmpx  mscroll1.map.height
        bge   >
        tsta
        bpl   @end2
        addd  mscroll1.map.height
        bra   @end2
!       subd  mscroll1.map.height
@end2   std   mscroll1.camera.y
        bra   mscroll1.updategfx
mscroll1.move.exit
        rts

; mscroll1.camera.impulse
; -----------------------
; accumulate an exact displacement : X = dx (signed 8.8 px), D = dy (signed
; 8.8 lines). For script pilots that unwind elapsed video frames themselves,
; one frame at a time : camera.speed/speedx stay at ZERO in this mode and the
; caller pushes the per-frame sum here — move applies the whole of it (clamp,
; seams, feeds) on the next loop.
mscroll1.camera.impulse
        addd  mscroll1.speed
        std   mscroll1.speed
        tfr   x,d
        addd  mscroll1.speedx
        std   mscroll1.speedx
        rts

; update gfx in buffer code
; -------------------------
mscroll1.updategfx
        jsr   mscroll1.computeBufferWAddress
        tst   <mscroll1.loop.counter         ; nb of lines to render
        lbeq  @exit                          ; when viewport shrink nothing to render
        ; setup mscroll1 buffer
        ldx   mscroll1.buffer.address
        leax  d,x
        stx   <mscroll1.buffer.wAddress
        ; compute current line in tile
        ldb   map.CF74021.DATA
        stb   <mscroll1.backBuffer           ; backup back video buffer
        lda   mscroll1.camera.lastY+1        ; LSB only
        adda  <mscroll1.skippedLines         ; nb skip lines (outside viewport)
        ldb   mscroll1.speed
        bpl   >
        deca                                 ; next line in tile
        ldb   #$4A ; deca
        ldu   #0
        ldx   #mscroll1.LINE_SIZE
        ldy   #-1
        bra   @mod
!       adda  mscroll1.viewport.height
        inca                                 ; previous line in tile
        ldb   #$4C ; inca
        ldu   mscroll1.viewport.height.w
        ldx   #-mscroll1.LINE_SIZE
        ldy   #1
@mod
        anda  #$0f                           ; modulo to keep 0-15 (the shear is
                                             ; relative : the camera's own columns
                                             ; are not sheared, see move)
        sta   <mscroll1.tileset.line
        ; setup dynamic code in main scroll loop
        sty   @direction
        stb   @direction2
        stu   @direction3
        stx   @direction4
        eorb  #%00000110                     ; inverse deca/inca instruction
        stb   @direction6
        ldd   mscroll1.camera.lastY
        addd  #0                             ; add viewport when going down
@direction3 equ *-2
@loop
        addd  #0
@direction equ *-2
        cmpd  mscroll1.map.height
        bge   >
        tsta
        bpl   @end1
        addd  mscroll1.map.height
        bra   @end1
!       subd  mscroll1.map.height
@end1   std   <mscroll1.camera.currentY
        std   <mscroll1.currentYs            ; (the row space is not sheared for
                                             ; the camera's own columns)
;
        andb  #$f0                           ; tile height is 16px, faster check here than _asrd*4
        cmpd  mscroll1.map.cache.y
        beq  >
        std   mscroll1.map.cache.y           ; load cache at a new position
;
        ldy   #mscroll1.map.cache
        lda   <mscroll1.buffer.line
        lsra
        lsra
        lsra
        lsra
        sta   mscroll1.map.cache.line
        ldb   #mscroll1.map.cache.LINE_SIZE
        mul
        leay  d,y
        sty   mscroll1.map.cache.cursor
;
        ldd   <mscroll1.currentYs
        jsr   mscroll1.updateTileCache       ; check cache for this line number (in d)
!       lda   mscroll1.buffer.page
        _SetCartPageA                        ; mount in cartridge space
        lda   <mscroll1.tileset.line
        lsla
        ldx   #mscroll1.tile.adresses        ; tileset line base
        ldy   a,x
        lda   mscroll1.tile.page
        sta   map.CF74021.DATA               ; mount in data space
        ldu   <mscroll1.buffer.wAddress
        ldx   mscroll1.map.cache.cursor
        jsr   mscroll1.copyBitmap            ; copy bitmap for the buffer line
        lda   <mscroll1.buffer.line
        inca
@direction6 equ *-1
        leau  1234,u
@direction4 equ *-2
        cmpu  mscroll1.buffer.address
        bge   @tend
        lda   #mscroll1.BUFFER_LINES-1
        leau  mscroll1.BUFFER_LINES*mscroll1.LINE_SIZE,u
        bra   >
@tend   cmpu  mscroll1.buffer.end
        blt   >
        lda   #0
        leau  -mscroll1.BUFFER_LINES*mscroll1.LINE_SIZE,u
!       stu   <mscroll1.buffer.wAddress
        sta   <mscroll1.buffer.line
        lda   <mscroll1.tileset.line
        inca
@direction2 equ *-1
        anda  #$0f
        sta   <mscroll1.tileset.line
;
        ldd   <mscroll1.camera.currentY
        dec   <mscroll1.loop.counter
        lbne  @loop                          ; loop until all lines are rendered
@exit
        ldb   mscroll1.speed
        bpl   >
        ldb   #$ff
        bra   @end2
!       clrb
@end2   stb   mscroll1.speed
        ldb   <mscroll1.backBuffer           ; restore back video buffer
        stb   map.CF74021.DATA
        rts

; feed one whole buffer line
; --------------------------
; input REG : [d] map row (pixels), [x] buffer line (0..BUFFER_LINES-1)
; the row feed for a single line chosen by the caller, through the same
; cache, bake and fixup as updategfx (the cache row is borrowed and the
; cache invalidated after)
mscroll1.feedLine
        std   <mscroll1.currentYs
        tfr   x,d
        stb   mscroll1.fl.line
        lda   map.CF74021.DATA
        sta   <mscroll1.backBuffer           ; backup back video buffer
        ldy   #mscroll1.map.cache
        ldd   <mscroll1.currentYs
        jsr   mscroll1.updateTileCache       ; row ids, baked, and the row above
        ldb   <mscroll1.currentYs+1
        andb  #$0f
        stb   <mscroll1.tileset.line
        lda   mscroll1.buffer.page
        _SetCartPageA
        lda   <mscroll1.tileset.line
        lsla
        ldx   #mscroll1.tile.adresses
        ldy   a,x
        lda   mscroll1.tile.page
        sta   map.CF74021.DATA
        lda   mscroll1.fl.line
        ldb   #mscroll1.LINE_SIZE
        mul
        addd  mscroll1.buffer.address
        tfr   d,u
        ldx   #mscroll1.map.cache
        jsr   mscroll1.copyBitmap
        ldd   #-1
        std   mscroll1.map.cache.y           ; the borrowed cache row is stale
        ldb   <mscroll1.backBuffer           ; restore back video buffer
        stb   map.CF74021.DATA
        rts

; update the horizontal line of tile id in map cache
; --------------------------------------------------
; input REG : [d] SHEARED map row (in pixels — currentYs), [y] cache row base
; input VAR : [currentYs] the same value, reused for the above row
; loads the 20 block ids of the current window slice at that row, ROTATED so
; that a cache index is the buffer slot it feeds (column mod 20) —
; copyBitmap then reads the cache linearly, whatever the window position.
; The entries of the columns beyond the next map seam (slots 0..seam.slots-1)
; are then BAKED one tile line up (id*32 - 2) : that is the map-fixed shear,
; paid here once per reload instead of per written line. The row ABOVE is
; loaded raw next to the cache for the lines where the sheared write crosses
; a tile boundary (copyBitmap's fixup).
mscroll1.updateTileCache
        sty   <mscroll1.uc.base
        bsr   @slice                   ; the row itself
        ldb   mscroll1.seam.slots
        beq   @above
        stb   <mscroll1.tmp1
        ldy   <mscroll1.uc.base
@bake   ldd   ,y
        subd  #2
        std   ,y++
        dec   <mscroll1.tmp1
        bne   @bake
@above  ldd   <mscroll1.currentYs      ; the row above, raw, for the fixup
        subd  #16
        bpl   >
        addd  mscroll1.map.height      ; the map wraps vertically
!       ldy   #mscroll1.map.cache.above
        sty   <mscroll1.uc.base
        ; falls through : the second load returns to the caller
@slice  _lsrd
        _lsrd
        _lsrd
        _lsrd                          ; b = block row (map height <= 4080)
        stb   mscroll1.r.row
        lda   mscroll1.map.page
        _SetCartPageA                  ; mount page that contain map data
        ; the slice starts one block left of the 16px feed edge — the exact
        ; set of columns the tile feed keeps in the buffer slots
        ldd   mscroll1.edge
        subd  #1
        std   mscroll1.r.col           ; T0, first column of the slice
        jsr   mscroll1.divmod20        ; b = T0 mod 20 : a cache index IS the slot
        aslb
        ldy   <mscroll1.uc.base
        leax  40,y
        stx   mscroll1.r.end
        leay  b,y                      ; dest = slice base + 2*slot
        lda   #20
        sta   <mscroll1.loop.counter2
        ; the row inside a chunk, and the layout row
        ldb   mscroll1.r.row
        andb  #7
        aslb
        aslb
        aslb
        aslb
        stb   mscroll1.r.rowoff
        ldb   mscroll1.r.row
        lsrb
        lsrb
        lsrb
        lda   mscroll1.map.layout.stride
        mul
        addd  mscroll1.map.layout
        std   mscroll1.r.lrow
        ; one run per chunk crossed : chunks + chunk*128 + rowoff + (col&7)*2
@run    ldd   mscroll1.r.col
        _lsrd
        _lsrd
        _lsrd
        addd  mscroll1.r.lrow
        tfr   d,x
        ldb   ,x                       ; chunk index
        tfr   b,a
        clrb
        lsra
        rorb                           ; d = chunk*128
        addd  mscroll1.map.chunks
        addb  mscroll1.r.rowoff
        adca  #0
        tfr   d,x
        ldb   mscroll1.r.col+1
        andb  #7
        aslb
        abx                            ; x = the column's id
        lsrb
        negb
        addb  #8                       ; b = columns left in this chunk
        stb   <mscroll1.tmp1
@copy   ldd   ,x++
        std   ,y++
        cmpy  mscroll1.r.end           ; rotation : wrap to the slice base
        bne   >
        ldy   <mscroll1.uc.base
!       dec   <mscroll1.loop.counter2
        beq   @done
        ldd   mscroll1.r.col
        addd  #1
        std   mscroll1.r.col
        dec   <mscroll1.tmp1
        bne   @copy
        bra   @run
@done   rts

; -----------------------------------------------------------------------------
; mscroll1.feedTile
; -----------------------------------------------------------------------------
; input  REG : [d] 16px map block column index
; -----------------------------------------------------------------------------
; write that block column into its slot (column mod 20) of every buffer
; line — the horizontal counterpart of the row feed, called by mscroll1.move
; at every 16px edge step, inside the gfxlock like the rest of the feed. The
; tile-major layout makes the inner loop trivial : the source of a whole run
; of buffer lines is the block's consecutive words (,y++), no table and no
; page traffic per line. The ids of the spanned block rows are gathered once
; (map page mounted once, a layout lookup per chunk crossed), then the pass
; runs with the code buffer in the cartridge window and the tileset in the
; data window, both mounted once.
; -----------------------------------------------------------------------------
mscroll1.feedTile
        std   mscroll1.f.col
        ldu   #-1                      ; the edge moved : the row cache
        stu   mscroll1.map.cache.y     ; content belongs to the old slice
        lda   map.CF74021.DATA
        sta   <mscroll1.backBuffer     ; backup back video buffer
        ; the column's shear relative to the camera (its seam index
        ; column/20, minus S-1 : 0 or 1 for a window column, see move) and
        ; its slot (column mod 20)
        ldd   mscroll1.f.col
        jsr   mscroll1.divmod20
        inca
        suba  mscroll1.stretch
        sta   <mscroll1.fc.tl          ; stashed until the row anchor below
        ldx   #mscroll1.slot.off
        ldb   b,x
        stb   <mscroll1.fc.off         ; operand code offset of the slot
        ; top map row spanned by the buffer, minus the column's shear
        ldb   <mscroll1.fc.tl          ; signed : -1 is possible far off the
        sex                            ; window, keep it exact
        _negd
        addd  mscroll1.camera.y
        bpl   >
        addd  mscroll1.map.height      ; the map wraps vertically
        bra   @rowok
!       cmpd  mscroll1.map.height
        blo   @rowok
        subd  mscroll1.map.height
@rowok  std   <mscroll1.fc.row
        ldb   <mscroll1.fc.row+1
        andb  #$0F
        stb   <mscroll1.fc.tl
        ; gather the column ids, one per block row, walking down with wrap
        lda   mscroll1.map.page
        _SetCartPageA
        ldd   mscroll1.f.col
        _lsrd
        _lsrd
        _lsrd
        std   mscroll1.f.cc            ; chunk column
        ldb   mscroll1.f.col+1
        andb  #7
        aslb
        stb   mscroll1.f.kx            ; byte offset in a chunk row
        ldd   <mscroll1.fc.row
        _lsrd
        _lsrd
        _lsrd
        _lsrd
        stb   mscroll1.r.row           ; block row walk
        ldu   #mscroll1.col.cache
        lda   #14                      ; covers BUFFER_LINES + a block of slack
        sta   <mscroll1.fc.count
@chunk  ldb   mscroll1.r.row           ; look the chunk up
        lsrb
        lsrb
        lsrb
        lda   mscroll1.map.layout.stride
        mul
        addd  mscroll1.map.layout
        addd  mscroll1.f.cc
        tfr   d,x
        ldb   ,x                       ; chunk index
        tfr   b,a
        clrb
        lsra
        rorb                           ; d = chunk*128
        addd  mscroll1.map.chunks
        addb  mscroll1.f.kx
        adca  #0
        tfr   d,x
        ldb   mscroll1.r.row
        andb  #7
        lda   #16
        mul
        abx                            ; x = the id at (row, column)
@gather ldd   ,x
        std   ,u++
        dec   <mscroll1.fc.count
        beq   @gdone
        leax  16,x                     ; the next block row of the chunk
        ldb   mscroll1.r.row
        incb
        cmpb  mscroll1.map.rows        ; wrap at the map height
        blo   >
        clrb
!       stb   mscroll1.r.row
        andb  #7
        bne   @gather                  ; same chunk : keep walking down
        bra   @chunk                   ; a chunk boundary (or the wrap)
@gdone
        lda   mscroll1.buffer.page
        ldx   mscroll1.buffer.address
        bsr   mscroll1.feedTile.plane
        ldb   <mscroll1.backBuffer     ; restore back video buffer
        stb   map.CF74021.DATA
        rts

; the buffer pass of the tile feed
; --------------------------------
; input REG : [a] code buffer page, [x] code buffer address
; input VAR : [fc.off/tl] see above, col.cache = the ids
mscroll1.feedTile.plane
        _SetCartPageA                  ; the code buffer, for the whole pass
        ldb   mscroll1.tile.page
        stb   map.CF74021.DATA         ; the tileset, for the whole pass
        ; wrap bound and start position, both carrying the slot offset
        tfr   x,d
        addb  <mscroll1.fc.off
        adca  #0
        std   <mscroll1.fc.end         ; low bound : line 0's operand
        pshs  x
        lda   mscroll1.cursor          ; top line = (cursor-1) mod BUFFER_LINES
        bne   >                        ; only 0 wraps (a deca/bpl guard would
        lda   #mscroll1.BUFFER_LINES   ; also fire for cursor 129..200)
!       deca
        ldb   #mscroll1.LINE_SIZE
        mul
        addd  ,s++
        addb  <mscroll1.fc.off
        adca  #0
        tfr   d,u                      ; u = operand of the top line
        ; per-pass run state
        ldb   <mscroll1.fc.tl
        stb   <mscroll1.fc.rtl
        ldd   #mscroll1.col.cache
        std   <mscroll1.fc.srcoff      ; id list cursor
        ldb   #mscroll1.BUFFER_LINES
        stb   <mscroll1.fc.count
@outer  ldx   <mscroll1.fc.srcoff
        ldd   ,x++
        stx   <mscroll1.fc.srcoff
        addd  #$A000                   ; id is premultiplied by 32
        tfr   d,y
        ldb   <mscroll1.fc.rtl
        aslb
        leay  b,y                      ; y = tile data at the run's first line
        ; run length = min(16 - rtl, lines left)
        lda   #16
        suba  <mscroll1.fc.rtl
        cmpa  <mscroll1.fc.count
        bls   >
        lda   <mscroll1.fc.count
!       sta   <mscroll1.loop.counter2
        ldb   <mscroll1.fc.count
        pshs  a
        subb  ,s+
        stb   <mscroll1.fc.count
@inner  ldd   ,y++
        std   ,u
        leau  -mscroll1.LINE_SIZE,u
        cmpu  <mscroll1.fc.end
        bge   >                        ; SIGNED : the buffer loads at $0000,
                                       ; u underflows below zero at the wrap
                                       ; and an unsigned compare would see
                                       ; $FFxx as huge, skip the wrap and
                                       ; spray the walk over the I/O page
        leau  mscroll1.BUFFER_LINES*mscroll1.LINE_SIZE,u
!       dec   <mscroll1.loop.counter2
        bne   @inner
        tst   <mscroll1.fc.count
        beq   @done
        clr   <mscroll1.fc.rtl
        bra   @outer
@done   rts

; copy the tile bitmap to the code buffer
; read tiles in reverse order (from right to left)
; ------------------------------------------------
; 10 chunks of 8 code bytes per line, each holding two 16px blocks — D
; operand (offset 1) is the left block of the chunk, X operand (offset 4) the
; right one. Chunk 0 is executed first and writes the rightmost 32px of the
; line (S pushes downward).
mscroll1.copyBitmap
        ldd   38,x                     ; [6] load tile id
        ldd   d,y                      ; [9] load 16 pixels of this tile line
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
        std   76,u                     ; chunk 9 (leftmost 32px)
        ldd   ,x                       ; [5] load tile id
        ldd   d,y
        std   73,u
        ; seam fixup : the sheared columns (their cache ids are baked one
        ; tile line up, see updateTileCache) crossed a tile boundary on the
        ; lines where the pass above used tile line 0 — rewrite those slots
        ; from the ABOVE-row cache at tile line 15. One line in sixteen.
        tst   <mscroll1.tileset.line
        bne   @nofix
        ldb   mscroll1.seam.slots
        beq   @nofix
        stb   <mscroll1.loop.counter2
        ldx   #mscroll1.map.cache.above
        ldy   #mscroll1.slot.off
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
        dec   <mscroll1.loop.counter2
        bne   @fix
        puls  u
@nofix  rts

; compute write location in buffer
; --------------------------------
mscroll1.computeBufferWAddress

        ; compute number of lines to render
        ldd   #0
        std   <mscroll1.skippedLines       ; init tmp value
        ldb   mscroll1.speed
        bpl   >
        comb                               ; by truncating, negative is floor and positive is ceil, so make it ceil also for negative
!       cmpb  mscroll1.viewport.height     ; compare to viewport height
        bls   >
        subb  mscroll1.viewport.height
        stb   <mscroll1.skippedLines+1     ; number of skipped lines (outside of viewport)
        ldb   mscroll1.viewport.height     ; keep lowest value
!       stb   <mscroll1.loop.counter       ; setup nb of line to render

        ; compute relative write location in code buffer
        tst   mscroll1.speed
        bmi   @goUp
@goDown
        addd  mscroll1.cursor.w
        subd  #1
        subd  <mscroll1.skippedLines       ; skip lines if needed
        bmi   @loop
        cmpd  #mscroll1.BUFFER_LINES
        bhs   @loop2
        bra   >
@loop
        addd  #mscroll1.BUFFER_LINES   ; cycling in buffer
        bmi   @loop
        bra   >
@goUp
        negb                           ; substract it to cursor + viewport height
        sex                            ; omg !
        addd  mscroll1.cursor.w
        addd  mscroll1.viewport.height.w
        addd  <mscroll1.skippedLines
        addd  #1                       ; the upward feed lands one line below
                                       ; the pairing otherwise (mscroll V2-DEVIATION)
        cmpd  #mscroll1.BUFFER_LINES
        blo   >
@loop2
        subd  #mscroll1.BUFFER_LINES   ; cycling in buffer
        cmpd  #mscroll1.BUFFER_LINES
        bhs   @loop2
!       stb   <mscroll1.buffer.line
        lda   #mscroll1.LINE_SIZE
        mul
        rts

; -----------------------------------------------------------------------------
; mscroll1.do
; -----------------------------------------------------------------------------
; input  REG : none
; -----------------------------------------------------------------------------
; render the whole band at the current position (to be called between
; _gfxlock.on and _gfxlock.off, writes to the back buffer, RAMA zone).
;
; The vertical position selects the entry LINE (the vscroll cursor) ; the
; horizontal position is decomposed :
;   x = 32*window + 8*bo + r     h  : entry chunk in every line (0-9)
;                                bo : S byte offset (-2..1)
;                                r  : 0-7, not rendered (8px step)
; Entry point and patched exit are both offset by h chunks, so the run
; covers exactly viewport.height lines of data.
; -----------------------------------------------------------------------------
mscroll1.do
        ; the slot layout is REVERSED (chunk c of a line holds the window's
        ; chunk 9-c), so the entry chunk is MINUS the window modulo 10
        ldd   mscroll1.window
        jsr   mscroll1.divmod20        ; b = window mod 20
        cmpb  #10
        blo   >
        subb  #10                      ; b = window mod 10
!       tstb
        beq   >
        subb  #10
        negb                           ; h = (10 - window mod 10) mod 10
!       stb   <mscroll1.h
        ldb   mscroll1.camera.x+1      ; low byte of the pixel position
        addb  #16
        andb  #$1F
        subb  #16                      ; b = fine part (-16..15)
        asrb
        asrb
        asrb                           ; b = S byte offset (-2..1), floor
        sex
        _negd                          ; camera convention : +x shows content
                                       ; further right
        addd  mscroll1.viewport.ram
        addd  #$2000                   ; the RAMA zone ($C000-$DFFF)
        std   <mscroll1.dest
        lda   mscroll1.buffer.page
        ldx   mscroll1.buffer.address
        ; fallthrough to mscroll1.runBuffer

; -----------------------------------------------------------------------------
; mscroll1.runBuffer
; -----------------------------------------------------------------------------
; input  REG : [a] code buffer page
; input  REG : [x] code buffer address (in cartridge space)
; input  VAR : [mscroll1.dest] S start address
; input  VAR : [mscroll1.cursor] entry line, [mscroll1.h] entry chunk
; -----------------------------------------------------------------------------
mscroll1.runBuffer
        _SetCartPageA                  ; mount page that contain buffer code
        ; exit position : ((cursor + height) mod BUFFER_LINES) lines + h chunks
        ldb   mscroll1.cursor
        addb  mscroll1.viewport.height
        bcs   @cycle
        cmpb  #mscroll1.BUFFER_LINES
        blo   >                        ; strict : with h > 0 an exit placed at
                                       ; BUFFER_LINES*LINE_SIZE+h*8 would land
                                       ; past the wrap jmp — wrap to line 0
                                       ; instead (the wrap jmp then runs once
                                       ; before the patched exit, 4 cycles)
@cycle  subb  #mscroll1.BUFFER_LINES   ; cycling in buffer
!       lda   #mscroll1.LINE_SIZE
        mul
        leau  d,x
        ldb   <mscroll1.h
        aslb
        aslb
        aslb                           ; b = h * CHUNK_SIZE
        leau  b,u                      ; u = where the exit jmp is placed
        pulu  a,y                      ; save 3 bytes that will be erased by the jmp
        stu   @save_u
        pshs  a,y
        lda   #mscroll1.OPCODE_JMP_E   ; build exit jmp instruction
        ldy   #@ret
        sta   -3,u
        sty   -2,u
        sts   @save_s
        lds   <mscroll1.dest
        ; entry position : cursor lines + h chunks
        lda   mscroll1.cursor
        ldb   #mscroll1.LINE_SIZE
        mul
        leax  d,x
        ldb   <mscroll1.h
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

; -----------------------------------------------------------------------------
; mscroll1.mask
; -----------------------------------------------------------------------------
; input  REG : none
; -----------------------------------------------------------------------------
; black the two zones of the band the blast cannot get right, in the back
; buffer (call after mscroll1.do and after whatever the game draws in the
; band, between _gfxlock.on and _gfxlock.off). The picture left is
; 312 x (height-1) px. ~1.7 k cycles for 200 lines.
;
; - the OVERLAP band : byte 39 of every band line (8 px on the right). When
;   x mod 16 >= 8 the window spans 21 block columns for 20 slots, so one
;   slot is shown at both edges, straddling the line wrap : its right byte
;   opens line n+1 (right), its left byte closes line n, where it is wrong
;   (the slot holds the left column, edge-1, not the one 320 px further).
; - the TOP LINE of the band, the buffer zone of the ribbon : the S byte
;   offset leaves up to 2 bytes at its start unwritten (D = 1, 2 :
;   x mod 32 in 16..31), stale from the previous blast in this buffer.
;
; The blast also spills OUTSIDE the band by up to 2 bytes : byte 39 of the
; line above (D = -1) and bytes 0-1 of the line below (D = 2). Out of sight
; with a band starting at line 0 ($BFFF, the unused RAMB zone) or ending at
; line 199 (past the 8000 displayed bytes) ; anywhere else the game covers
; them (R-Type stage 3 : its HUD).
; -----------------------------------------------------------------------------
mscroll1.mask
        ldx   mscroll1.viewport.ram
        leax  $2000-1,x                ; byte 39 of the last band line (RAMA zone)
        clra
        ldb   mscroll1.viewport.height
@one    bitb  #3                       ; height mod 4 lines one by one,
        beq   @four                    ; then four lines per pass
        sta   ,x
        leax  -40,x
        decb
        bra   @one
@four   lsrb
        lsrb
        beq   @top
@loop   sta   ,x
        sta   -40,x
        sta   -80,x
        sta   -120,x
        leax  -160,x
        decb
        bne   @loop
@top    leau  41,x                     ; x is byte 39 of the line above the
        clrb                           ; band : u is one past the top line
        ldx   #0
        ldy   #0
        pshu  d,x,y                    ; 40 bytes, 6 at a time
        pshu  d,x,y
        pshu  d,x,y
        pshu  d,x,y
        pshu  d,x,y
        pshu  d,x,y
        pshu  d,x
        rts
