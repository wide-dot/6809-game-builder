; -----------------------------------------------------------------------------
; _mscroll.setMap
; -----------------------------------------------------------------------------
; input : object id of map
; -----------------------------------------------------------------------------
_mscroll.setMap MACRO
        ldb   \1
        ldx   #Obj_Index_Page
        lda   b,x   
        sta   mscroll.obj.map.page
        aslb
        ldx   #Obj_Index_Address
        ldx   b,x
        stx   mscroll.obj.map.address
 ENDM

; -----------------------------------------------------------------------------
; _mscroll.setMapHeight
; -----------------------------------------------------------------------------
; input : map height in pixels
; -----------------------------------------------------------------------------
_mscroll.setMapHeight MACRO
        ldd   \1
        std   mscroll.map.height
 ENDM

; -----------------------------------------------------------------------------
; _mscroll.setTileset
; -----------------------------------------------------------------------------
; input : object id of tileset A
; input : object id of tileset B
; -----------------------------------------------------------------------------

_mscroll.setTileset_ MACRO
        lda   #4
        sta   <dp_extreg
        ldu   #@list
        ldx   #Obj_Index_Page
        ldy   #mscroll.obj.tile.pages
@loop   equ   *
        ldd   ,u++
        lda   a,x   
        ldb   b,x   
        sta   ,y+
        stb   ,y+
        sta   ,y+
        stb   ,y+
        sta   ,y+
        stb   ,y+
        sta   ,y+
        stb   ,y+
        dec   <dp_extreg
        bne   @loop
        bra   @list+8
@list   equ   *
 ENDM

_mscroll.setUpdateRoutine_ MACRO
        sta   mscroll.tiles.nbLinesByPage
        asra
        ldx   #mscroll.tiles.dyncall
        ldx   a,x
        stx   mscroll.tiles.updateTilesForNLines.address
        lda   mscroll.tiles.nbLinesByPage
        asla
        sta   mscroll.tiles.nbLinesByPage.x2.0001
        sta   mscroll.tiles.nbLinesByPage.x2.0010
        sta   mscroll.tiles.nbLinesByPage.x2.0011
        sta   mscroll.tiles.nbLinesByPage.x2.0100
        sta   mscroll.tiles.nbLinesByPage.x2.0101
        sta   mscroll.tiles.nbLinesByPage.x2.0110
        sta   mscroll.tiles.nbLinesByPage.x2.0111
        sta   mscroll.tiles.nbLinesByPage.x2.1000
        sta   mscroll.tiles.nbLinesByPage.x2.1001
        sta   mscroll.tiles.nbLinesByPage.x2.1010
        sta   mscroll.tiles.nbLinesByPage.x2.1011
        sta   mscroll.tiles.nbLinesByPage.x2.1100
        sta   mscroll.tiles.nbLinesByPage.x2.1101
        sta   mscroll.tiles.nbLinesByPage.x2.1110
        sta   mscroll.tiles.nbLinesByPage.x2.1111
 ENDM

_mscroll.setTileset256 MACRO
 IFDEF mscroll.tiles.DEFINED
        lda   #16
        _mscroll.setUpdateRoutine_
 ENDC
        _mscroll.setTileset_
        fcb   \1
        fcb   \2
        fcb   \1
        fcb   \2
        fcb   \1
        fcb   \2
        fcb   \1
        fcb   \2
 ENDM

_mscroll.setTileset512 MACRO
 IFDEF mscroll.tiles.DEFINED
        lda   #16
        _mscroll.setUpdateRoutine_
 ENDC
        _mscroll.setTileset256 \1,\2
 ENDM

_mscroll.setTileset1024 MACRO
 IFDEF mscroll.tiles.DEFINED
        lda   #8        
        _mscroll.setUpdateRoutine_
 ENDC
        _mscroll.setTileset_
        fcb   \1
        fcb   \2
        fcb   \1
        fcb   \2
        fcb   \3
        fcb   \4
        fcb   \3
        fcb   \4
 ENDM

_mscroll.setTileset2048 MACRO
 IFDEF mscroll.tiles.DEFINED
        lda   #4
        _mscroll.setUpdateRoutine_
 ENDC
        _mscroll.setTileset_
        fcb   \1
        fcb   \2
        fcb   \3
        fcb   \4
        fcb   \5
        fcb   \6
        fcb   \7
        fcb   \8
 ENDM

; -----------------------------------------------------------------------------
; _mscroll.setTileLut
; -----------------------------------------------------------------------------
; Tiles are stored TILE-MAJOR (the 16 lines of a tile are consecutive words,
; 32 bytes per tile and per plane) and the map holds ids premultiplied by 32 :
; the address of a tile line is base + id + line*2. The per-line LUT of the
; row feed therefore steps by 2, whatever the tile count (max 512 per plane
; page).
; -----------------------------------------------------------------------------
_mscroll.setTileLut MACRO
        ldx   #mscroll.obj.tile.adresses
        ldd   #$A000
!       std   ,x++
        addd  #2
        cmpd  #$A000+32
        bne   <
 ENDM

; -----------------------------------------------------------------------------
; _mscroll.setBuffer
; -----------------------------------------------------------------------------
; input : object id of mscroll code buffer A
; input : object id of mscroll code buffer B
; -----------------------------------------------------------------------------
_mscroll.setBuffer MACRO
        ldx   #Obj_Index_Page
        ldy   #Obj_Index_Address
        ldb   \1
        lda   b,x   
        sta   mscroll.obj.bufferA.page
        aslb
        ldu   b,y
        stu   mscroll.obj.bufferA.address
        leau  mscroll.BUFFER_LINES*mscroll.LINE_SIZE,u
        stu   mscroll.obj.bufferA.end
        ldb   \2
        lda   b,x   
        sta   mscroll.obj.bufferB.page
        aslb
        ldu   b,y
        stu   mscroll.obj.bufferB.address
        leau  mscroll.BUFFER_LINES*mscroll.LINE_SIZE,u
        stu   mscroll.obj.bufferB.end
 ENDM

; -----------------------------------------------------------------------------
; _mscroll.setCameraPos
; -----------------------------------------------------------------------------
; input : camera position in map 0-8191 (map height of 512 tiles max)
; -----------------------------------------------------------------------------
_mscroll.setCameraPos MACRO
        ldd   \1
        std   mscroll.camera.y
        std   mscroll.camera.lastY
        ; anchor the cycling cursor on the generated start buffer : the
        ; builder's <mscroll output="start"> emits BUFFER_LINES lines in a
        ; reverse chunk stream (buffer line holds map line BUFFER_LINES-1-L),
        ; and the runtime pairing buffer(cursor-1) <-> camera.y then needs
        ; cursor = (-y0) mod BUFFER_LINES. without this the whole start view
        ; sits one pixel off until every line has been re-fed.
        ldd   #mscroll.BUFFER_LINES
        subd  \1
        cmpd  #mscroll.BUFFER_LINES
        blo   @curok
        subd  #mscroll.BUFFER_LINES
@curok  std   mscroll.cursor.w
 ENDM

; -----------------------------------------------------------------------------
; _mscroll.setCameraSpeed
; -----------------------------------------------------------------------------
; input : camera speed (signed 8.8 fixed point) nb of pixels/50hz
; -----------------------------------------------------------------------------
_mscroll.setCameraSpeed MACRO
        ldd   \1
        std   mscroll.camera.speed
        eora  mscroll.speed            ; check direction change
        anda  #%10000000               ; by comparing sign bit
        beq   @end                     ; eor return 0 if both bit are identical
        ldd   #0                       ; if direction change, get rid of remainer
        std   mscroll.speed            ; otherwise it may gives an unwanted
@end    equ   *                        ; boost on first frame
 ENDM

; -----------------------------------------------------------------------------
; _mscroll.setCameraPosX
; -----------------------------------------------------------------------------
; input : horizontal camera position in map (in pixels, integer)
; NOTE : the start buffers must hold the map columns of that position in
; their slots (column mod 20) — a start position of 0 matches buffers baked
; from the map's left edge
; -----------------------------------------------------------------------------
_mscroll.setCameraPosX MACRO
        ; must be 0 : the generated start buffer holds the camera (0, y0)
        ; view (with the map-fixed seam shear baked for every column), and
        ; the seam state below is initialized for the first stretch
        ldd   \1
        std   mscroll.camera.x
        addd  #8
        _lsrd
        _lsrd
        _lsrd
        stb   mscroll.edge8
        _lsrd
        stb   mscroll.window
        clr   mscroll.stretch
        ldb   mscroll.edge8
        subb  #1                       ; window columns beyond the first seam
        bpl   @sm                      ; (edge8+19-20, clamped at zero)
        clrb
@sm     stb   mscroll.seam.slots
 ENDM

; -----------------------------------------------------------------------------
; _mscroll.setMapWidth
; -----------------------------------------------------------------------------
; input : map width in pixels (the camera x cap is width − 160)
; -----------------------------------------------------------------------------
_mscroll.setMapWidth MACRO
        ldd   \1
        subd  #160
        std   mscroll.camera.x.max
 ENDM

; -----------------------------------------------------------------------------
; _mscroll.setMapRowShift
; -----------------------------------------------------------------------------
; input : log2 of the map row stride in bytes — the map rows are 16-bit tile
; ids premultiplied by 32, padded to a power-of-two stride (e.g. a 512px wide
; map is 64 tiles = 128 bytes per row = shift 7)
; -----------------------------------------------------------------------------
_mscroll.setMapRowShift MACRO
        lda   \1
        sta   mscroll.map.rowshift
        sta   <dp_extreg
        ldd   #1
!       aslb
        rola
        dec   <dp_extreg
        bne   <
        std   mscroll.map.stride
 ENDM

; -----------------------------------------------------------------------------
; _mscroll.setCameraSpeedX
; -----------------------------------------------------------------------------
; input : horizontal camera speed (signed 8.8 fixed point) nb of pixels/50hz
; -----------------------------------------------------------------------------
_mscroll.setCameraSpeedX MACRO
        ldd   \1
        std   mscroll.camera.speedx
 ENDM

; -----------------------------------------------------------------------------
; _mscroll.setViewport
; -----------------------------------------------------------------------------
; input : viewport line start from top of screen (in pixel)
; input : viewport height (in pixel)
; -----------------------------------------------------------------------------
_mscroll.setViewport MACRO
        lda   \2
        sta   mscroll.viewport.height
        lda   \1
        sta   mscroll.viewport.y
        adda  mscroll.viewport.height
        ldb   #40                            ; nb of bytes in a line
        mul
        addd  #$A000                         ; video ram start location
        std   mscroll.viewport.ram
 ENDM

; -----------------------------------------------------------------------------
; _mscroll.buffer
; -----------------------------------------------------------------------------
; data structure for buffer code
; -----------------------------------------------------------------------------

; M2 chunk : 16 pixels, so that every line offers an entry point at the
; horizontal rotation granularity (the h of x = 16h + 4bo + 2w)
_mscroll.buffer.chunk MACRO
        ldd   #0
        ldx   #0
        pshs  d,x
 ENDM

_mscroll.buffer.line MACRO
        _mscroll.buffer.chunk
        _mscroll.buffer.chunk
        _mscroll.buffer.chunk
        _mscroll.buffer.chunk
        _mscroll.buffer.chunk
        _mscroll.buffer.chunk
        _mscroll.buffer.chunk
        _mscroll.buffer.chunk
        _mscroll.buffer.chunk
        _mscroll.buffer.chunk
 ENDM

_mscroll.buffer.linex8 MACRO
        _mscroll.buffer.line
        _mscroll.buffer.line
        _mscroll.buffer.line
        _mscroll.buffer.line
        _mscroll.buffer.line
        _mscroll.buffer.line
        _mscroll.buffer.line
        _mscroll.buffer.line
 ENDM
