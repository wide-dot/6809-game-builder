; -----------------------------------------------------------------------------
; mscroll1 — set up macros (see mscroll1.asm)
; -----------------------------------------------------------------------------
; Order : setMap, setMapHeight, setMapWidth, setTileset, setBuffer,
; setViewport, setCameraPos, setCameraPosX (it biases the cursor set by
; setCameraPos), then jsr mscroll1.init to fill the code buffer.
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; _mscroll1.setMap
; -----------------------------------------------------------------------------
; input : object id of the map file (layout then chunk table, one page,
;         mounted in cartridge space : its Obj_Index_Page entry carries
;         RAM_OVER_CART)
; input : layout row stride in bytes (chunk columns, <= 255)
; input : offset of the chunk table from the start of the file
; -----------------------------------------------------------------------------
_mscroll1.setMap MACRO
        ldb   \1
        ldx   #Obj_Index_Page
        lda   b,x
        sta   mscroll1.map.page
        aslb
        ldx   #Obj_Index_Address
        ldd   b,x
        std   mscroll1.map.layout
        addd  \3
        std   mscroll1.map.chunks
        lda   \2
        sta   mscroll1.map.layout.stride
 ENDM

; -----------------------------------------------------------------------------
; _mscroll1.setMapHeight
; -----------------------------------------------------------------------------
; input : map height in pixels (a multiple of 128, <= 3968)
; -----------------------------------------------------------------------------
_mscroll1.setMapHeight MACRO
        ldd   \1
        std   mscroll1.map.height
        _lsrd
        _lsrd
        _lsrd
        _lsrd
        stb   mscroll1.map.rows
 ENDM

; -----------------------------------------------------------------------------
; _mscroll1.setMapWidth
; -----------------------------------------------------------------------------
; input : map width in pixels (the camera x cap is width - 320)
; -----------------------------------------------------------------------------
_mscroll1.setMapWidth MACRO
        ldd   \1
        subd  #320
        std   mscroll1.camera.x.max
 ENDM

; -----------------------------------------------------------------------------
; _mscroll1.setTileset
; -----------------------------------------------------------------------------
; input : object id of the tileset (one page, mounted in the data window : its
;         Obj_Index_Page entry is the plain page number)
; Blocks are stored TILE-MAJOR (the 16 lines of a block are consecutive
; words, 32 bytes per block) and the map holds ids premultiplied by 32 : the
; address of a block line is $A000 + id + line*2.
; -----------------------------------------------------------------------------
_mscroll1.setTileset MACRO
        ldb   \1
        ldx   #Obj_Index_Page
        lda   b,x
        sta   mscroll1.tile.page
        ldx   #mscroll1.tile.adresses
        ldd   #$A000
!       std   ,x++
        addd  #2
        cmpd  #$A000+32
        bne   <
 ENDM

; -----------------------------------------------------------------------------
; _mscroll1.setBuffer
; -----------------------------------------------------------------------------
; input : object id of the code buffer (mounted in cartridge space)
; -----------------------------------------------------------------------------
_mscroll1.setBuffer MACRO
        ldb   \1
        ldx   #Obj_Index_Page
        lda   b,x
        sta   mscroll1.buffer.page
        aslb
        ldx   #Obj_Index_Address
        ldu   b,x
        stu   mscroll1.buffer.address
        leau  mscroll1.BUFFER_LINES*mscroll1.LINE_SIZE,u
        stu   mscroll1.buffer.end
 ENDM

; -----------------------------------------------------------------------------
; _mscroll1.setCameraPos
; -----------------------------------------------------------------------------
; input : vertical camera position in map (pixels)
; -----------------------------------------------------------------------------
_mscroll1.setCameraPos MACRO
        ldd   \1
        std   mscroll1.camera.y
        std   mscroll1.camera.lastY
        ; buffer line L holds map line (y0 + BUFFER_LINES-1-L) once fed : the
        ; pairing the blast and both feeds maintain needs cursor = (-y0) mod
        ; BUFFER_LINES (the anchor of mscroll's generated start buffer)
        ldd   #mscroll1.BUFFER_LINES
        subd  \1
@cmod   cmpd  #0
        bge   @cpos
        addd  #mscroll1.BUFFER_LINES
        bra   @cmod
@cpos   cmpd  #mscroll1.BUFFER_LINES
        blo   @curok
        subd  #mscroll1.BUFFER_LINES
        bra   @cpos
@curok  std   mscroll1.cursor.w
 ENDM

; -----------------------------------------------------------------------------
; _mscroll1.setCameraPosX
; -----------------------------------------------------------------------------
; input : horizontal camera position in map (pixels, integer)
; after _mscroll1.setCameraPos : the cursor takes the bias of the camera's
; seam index, the one mscroll1.move accumulates while crossing seams
; -----------------------------------------------------------------------------
_mscroll1.setCameraPosX MACRO
        ldd   \1
        std   mscroll1.camera.x
        addd  #16
        _lsrd
        _lsrd
        _lsrd
        _lsrd
        std   mscroll1.edge
        _lsrd
        std   mscroll1.window
        ; the ribbon's seam index S = ceil(window/10), the cursor biased by -S
        ldd   mscroll1.window
        addd  #9
        aslb
        rola
        jsr   mscroll1.divmod20
        sta   mscroll1.stretch
        nega
        tfr   a,b
        sex
        addd  mscroll1.cursor.w
@smod   cmpd  #0
        bge   @sok
        addd  #mscroll1.BUFFER_LINES
        bra   @smod
@sok    std   mscroll1.cursor.w
        ; window columns beyond the next seam (column 20*S)
        ldb   mscroll1.stretch
        lda   #20
        mul
        std   <dp_extreg
        ldd   mscroll1.edge
        addd  #19
        subd  <dp_extreg
        bpl   @sl
        ldd   #0
@sl     stb   mscroll1.seam.slots
 ENDM

; -----------------------------------------------------------------------------
; _mscroll1.setCameraSpeed
; -----------------------------------------------------------------------------
; input : camera speed (signed 8.8 fixed point) nb of pixels/50hz
; -----------------------------------------------------------------------------
_mscroll1.setCameraSpeed MACRO
        ldd   \1
        std   mscroll1.camera.speed
        eora  mscroll1.speed           ; check direction change
        anda  #%10000000               ; by comparing sign bit
        beq   @end                     ; eor return 0 if both bit are identical
        ldd   #0                       ; if direction change, get rid of remainer
        std   mscroll1.speed           ; otherwise it may gives an unwanted
@end    equ   *                        ; boost on first frame
 ENDM

; -----------------------------------------------------------------------------
; _mscroll1.setCameraSpeedX
; -----------------------------------------------------------------------------
; input : horizontal camera speed (signed 8.8 fixed point) nb of pixels/50hz
; -----------------------------------------------------------------------------
_mscroll1.setCameraSpeedX MACRO
        ldd   \1
        std   mscroll1.camera.speedx
 ENDM

; -----------------------------------------------------------------------------
; _mscroll1.setViewport
; -----------------------------------------------------------------------------
; input : viewport line start from top of screen (in pixel)
; input : viewport height (in pixel)
; -----------------------------------------------------------------------------
_mscroll1.setViewport MACRO
        lda   \2
        sta   mscroll1.viewport.height
        lda   \1
        sta   mscroll1.viewport.y
        adda  mscroll1.viewport.height
        ldb   #40                            ; nb of bytes in a line
        mul
        addd  #$A000                         ; video ram start location
        std   mscroll1.viewport.ram
 ENDM

; -----------------------------------------------------------------------------
; _mscroll1.buffer
; -----------------------------------------------------------------------------
; the code buffer skeleton : mscroll1.init writes every operand
; -----------------------------------------------------------------------------

; one chunk : 32 pixels (two 16px blocks)
_mscroll1.buffer.chunk MACRO
        ldd   #0
        ldx   #0
        pshs  d,x
 ENDM

_mscroll1.buffer.line MACRO
        _mscroll1.buffer.chunk
        _mscroll1.buffer.chunk
        _mscroll1.buffer.chunk
        _mscroll1.buffer.chunk
        _mscroll1.buffer.chunk
        _mscroll1.buffer.chunk
        _mscroll1.buffer.chunk
        _mscroll1.buffer.chunk
        _mscroll1.buffer.chunk
        _mscroll1.buffer.chunk
 ENDM

_mscroll1.buffer.linex8 MACRO
        _mscroll1.buffer.line
        _mscroll1.buffer.line
        _mscroll1.buffer.line
        _mscroll1.buffer.line
        _mscroll1.buffer.line
        _mscroll1.buffer.line
        _mscroll1.buffer.line
        _mscroll1.buffer.line
 ENDM
