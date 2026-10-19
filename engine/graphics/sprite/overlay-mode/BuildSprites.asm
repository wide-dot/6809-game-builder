* ---------------------------------------------------------------------------
* BuildSprites
* ------------
* Draws the registered sprites over the screen, back to front : priority 8
* down to 1 (2 : front, 1 : the front pass when BuildSprites.FRONT_PASS is
* defined). A drawn sprite gets its hide flag : DisplaySprite clears it when
* the object is displayed again. Nothing is saved nor erased (overlay mode).
*
* A sprite is placed in playfield coordinates (x_pos, y_pos, against the
* camera) or in screen coordinates (x_pixel 48-207, y_pixel 28-227) ; a
* multisprite object (render_subobjects_mask) draws its children, each a
* playfield position and an image set, under the object's flags.
* BuildSprites.YWRAP : a playfield that may wrap 2048 lines high, a sprite's
* line taken round it from the camera's while BuildSprites.yWrapMask is $07
* (the default $FF : no wrap).
*
* input REG : none
* V2-DEVIATION (18/10/2026) : rewritten from v1's : one routine a step,
* shared by the single and the multisprite paths (BuildSprites.pickRoutine, BuildSprites.drawPlayfield,
* BuildSprites.drawAt) ; the dead no-range path and _mapping_frame are gone.
* ---------------------------------------------------------------------------

BuildSprites.centerParity       equ dp_engine    ; word - a byte with left zero pad byte
BuildSprites.subset             equ dp_engine+2  ; word
BuildSprites.imagePage          equ dp_engine+4  ; byte - a multisprite object's image page
BuildSprites.drawPage           equ dp_engine+6  ; byte - compilated sprite page
BuildSprites.drawRoutine        equ dp_engine+7  ; word - compilated sprite routine address
BuildSprites.x1                 equ dp_engine+9  ; word
BuildSprites.y1                 equ dp_engine+11 ; word
BuildSprites.xSize              equ dp_engine+13 ; word - a byte with left zero pad byte
BuildSprites.ySize              equ dp_engine+15 ; word - a byte with left zero pad byte
BuildSprites.x                  equ dp_engine+17 ; word
BuildSprites.y                  equ dp_engine+19 ; word
BuildSprites.children           equ dp_engine+23 ; byte
BuildSprites.flags              equ dp_engine+24 ; byte
BuildSprites.lineCorrection     equ dp_engine+25 ; byte - V2-DEVIATION : $28 (256 lines) if the screen line is negative, else 0

; V2-DEVIATION : setdp neutralized (obj target) ; every dp access is forced direct (<), DP $9F

BuildSprites
        clra                                ; the sizes' high bytes
        sta   <BuildSprites.xSize
        sta   <BuildSprites.ySize
        ldd   <glb_camera_x_pos             ; V2-DEVIATION (24/08/2026) : the pass's bounds, once
        subd  <glb_camera_x_offset
        subd  <glb_camera_x_offset
        std   BuildSprites.xLow                        ; x + x1 below : out
        ldd   <glb_camera_x_pos
        addd  #160
        std   BuildSprites.xHigh                        ; x + x1 + x_size from : out
        ldd   <glb_camera_y_pos
        subd  <glb_camera_y_offset
        std   BuildSprites.yLow                        ; y + y1 below : out ; y - BuildSprites.yLow : the screen line
        addd  #200
        std   BuildSprites.yHigh                        ; y + y1 + y_size from : out
 IFDEF BuildSprites.FRONT_PASS
        tst   BuildSprites.front            ; V2-DEVIATION (07/10/2026) : priority 1 drawn by a pass of its own
        beq   @back
        ldu   Tbl_Priority_Last_Entry+2
        lbne  @process
        rts
@back
 ENDC
        ldx   #Tbl_Priority_Last_Entry+16   ; back to front : priority 8 first
@level  ldu   ,x
        beq   @nextlevel
        pshs  x
        jsr   @process
        puls  x
@nextlevel
        leax  -2,x
 IFDEF BuildSprites.FRONT_PASS
        cmpx  #Tbl_Priority_Last_Entry+4    ; priority 2 last, 1 is the front pass's
 ELSE
        cmpx  #Tbl_Priority_Last_Entry+2    ; priority 1 last
 ENDC
        bhs   @level
        rts
;
; the objects of a priority level, U its last one, walked to its first
@process
        lda   render_flags,u
        bita  #render_hide_mask             ; hidden : skipped
        bne   @nextobject
        bita  #render_subobjects_mask
        lbne  @multisprite
        ldx   image_set,u                   ; no image : nothing to draw
        beq   @nextobject
        sta   <BuildSprites.flags
        ldx   #Img_Page_Index               ; the image's page, then its set
        ldb   id,u
        abx
        lda   ,x
        _SetCartPageA
        ldx   image_set,u
        ldd   image_x_size,x
        sta   <BuildSprites.xSize+1
        stb   <BuildSprites.ySize+1
        ldb   image_center_offset,x
        sex
        std   <BuildSprites.centerParity
        lda   <BuildSprites.flags                ; the subset of its mirrors
        anda  #render_xmirror_mask|render_ymirror_mask
        ldb   a,x
        beq   @nextobject
        leax  b,x
        stx   <BuildSprites.subset
        lda   <BuildSprites.flags
        bita  #render_playfieldcoord_mask
        beq   @screen
        ldd   y_pos,u
        std   <BuildSprites.y
        ldd   x_pos,u
 IFDEF BuildSprites.EVEN_X
        andb  #$FE                          ; V2-DEVIATION (11/10/2026) : an even x, as the camera's
 ENDC
        std   <BuildSprites.x
        subd  <glb_camera_x_pos             ; its parity picks the shifted variant
        jsr   BuildSprites.pickRoutine
        beq   @nextobject
        jsr   BuildSprites.drawPlayfield
        bcs   @nextobject                   ; out of the screen
@drawn  lda   <BuildSprites.flags
        ora   #render_hide_mask             ; drawn : hidden until displayed again
        sta   render_flags,u
@nextobject
        ldu   rsv_priority_prev_obj,u
        lbne  @process
        rts
;
; screen coordinates : the bounds in a shifted referential, one unsigned
; compare a pair (V2-DEVIATION 19/08/2026)
@screen
        ldb   x_pixel,u
        jsr   BuildSprites.pickRoutine
        beq   @nextobject
        ldx   <BuildSprites.subset
        ldb   y_pixel,u
        addb  image_subset_y1_offset,x
        subb  #screen_top
        cmpb  #screen_bottom-screen_top
        bhi   @nextobject
        stb   <BuildSprites.y1+1
        addb  <BuildSprites.ySize+1
        cmpb  #screen_bottom-screen_top
        bhi   @nextobject
        cmpb  <BuildSprites.y1+1                  ; wrapped
        blo   @nextobject
        lda   <BuildSprites.flags
        bita  #render_xloop_mask            ; xloop : no horizontal bound
        bne   @setposition
        ldb   x_pixel,u
        addb  image_subset_x1_offset,x
        subb  #screen_left
        cmpb  #screen_right-screen_left
        bhi   @nextobject
        stb   <BuildSprites.x1+1
        addb  <BuildSprites.xSize+1
        cmpb  #screen_right-screen_left
        bhi   @nextobject
        cmpb  <BuildSprites.x1+1                  ; wrapped
        blo   @nextobject
@setposition
        clr   <BuildSprites.lineCorrection
        ldd   xy_pixel,u
 IFDEF BuildSprites.HALFLINE
        andb  #$FE                          ; V2-DEVIATION (06/10/2026) : an even line
 ENDC
        suba  <BuildSprites.centerParity+1
        suba  #48                           ; x from 0
        bcc   >
        suba  #$60                          ; left of the screen : the end of the line above
        decb
!       subb  #28                           ; the line from 0
        bcc   >
        pshs  a
        lda   #$28                          ; V2-DEVIATION : a negative line, 256 lines back
        sta   <BuildSprites.lineCorrection
        puls  a
!       jsr   BuildSprites.drawAt
        bra   @drawn
;
; a multisprite object : its children, under its flags, each with its own
; unmirrored image ; the object is walked whatever its children do
@multisprite
        ora   #render_hide_mask             ; walked : hidden until displayed again
        sta   render_flags,u
        sta   <BuildSprites.flags
        lda   mainspr_childsprites,u
        beq   @nextobject
        sta   <BuildSprites.children
        ldx   #Img_Page_Index
        ldb   id,u
        abx
        lda   ,x
        sta   <BuildSprites.imagePage
        leay  sub2_x_pos,u
@child  lda   <BuildSprites.imagePage                  ; again : the last draw changed the page
        _SetCartPageA
        ldx   4,y                           ; the child's image set (0 : none)
        beq   @nextchild
        ldd   image_x_size,x
        sta   <BuildSprites.xSize+1
        stb   <BuildSprites.ySize+1
        ldb   image_center_offset,x
        sex
        std   <BuildSprites.centerParity
        ldb   ,x                            ; the unmirrored subset
        leax  b,x
        stx   <BuildSprites.subset
        ldd   2,y
        std   <BuildSprites.y
        ldd   ,y
 IFDEF BuildSprites.EVEN_X
        andb  #$FE                          ; V2-DEVIATION (11/10/2026) : an even x, as the camera's
 ENDC
        std   <BuildSprites.x
        subd  <glb_camera_x_pos
        jsr   BuildSprites.pickRoutine
        beq   @nextchild
        jsr   BuildSprites.drawPlayfield              ; Y and U kept
@nextchild
        leay  next_subspr,y
        dec   <BuildSprites.children
        bne   @child
        lbra  @nextobject

* ---------------------------------------------------------------------------
* BuildSprites.pickRoutine - the draw routine of a variant
* input  : X the image subset, B the position's low byte (x - camera, x_pixel)
* output : BuildSprites.drawPage, BuildSprites.drawRoutine ; Z set when the subset has none
* The parity picks the shifted variant ; missing, the other one, the centre a
* pixel the other way (V2-DEVIATION 20/08/2026 : on the shift bit, as a word)
* ---------------------------------------------------------------------------
BuildSprites.pickRoutine
        eorb  <BuildSprites.centerParity+1       ; an odd centre swaps the shifts
        andb  #1
        aslb                                ; bit 1 : shifted
        orb   #1                            ; bit 0 : draw (overlay)
        lda   b,x
        bne   @found
        eorb  #%00000010                    ; the other shift
        pshs  b
        bitb  #%00000010
        beq   @less
        ldd   <BuildSprites.centerParity         ; shifted : a pixel further
        addd  #1
        bra   @adjust
@less   ldd   <BuildSprites.centerParity         ; unshifted : a pixel nearer
        subd  #1
@adjust std   <BuildSprites.centerParity
        puls  b
        lda   b,x
        beq   @none
@found  leax  a,x
        lda   page_draw_routine,x
        sta   <BuildSprites.drawPage
        ldd   draw_routine,x
        std   <BuildSprites.drawRoutine
        andcc #%11111011                    ; Z clear : found (a routine may be at $0000)
@none   rts

* ---------------------------------------------------------------------------
* BuildSprites.drawPlayfield - draws a sprite placed in playfield coordinates
* input  : BuildSprites.x, BuildSprites.y, BuildSprites.subset, BuildSprites.xSize, BuildSprites.ySize,
*          BuildSprites.centerParity, BuildSprites.flags, the routine (BuildSprites.pickRoutine)
* output : C set when the sprite is out of the screen ; Y and U kept
* ---------------------------------------------------------------------------
BuildSprites.drawPlayfield
        ldx   <BuildSprites.subset
        ldb   image_subset_x1_offset,x
        sex
        std   <BuildSprites.x1
        ldb   image_subset_y1_offset,x
        sex
        std   <BuildSprites.y1
        lda   <BuildSprites.flags
        bita  #render_xloop_mask
        beq   @xStrict
        ldd   <BuildSprites.x                       ; V2-DEVIATION (31/08/2026) : xloop, overlapping the window is enough
        addd  <BuildSprites.x1
        cmpd  BuildSprites.xHigh
        bge   @out
        addd  <BuildSprites.xSize
        cmpd  BuildSprites.xLow
        blt   @out
        bra   @yTests
@xStrict
        ldd   <BuildSprites.x
        addd  <BuildSprites.x1
        cmpd  BuildSprites.xLow
        blt   @out
        addd  <BuildSprites.xSize
        cmpd  BuildSprites.xHigh
        bge   @out
@yTests
 IFDEF BuildSprites.YWRAP
        ldd   <BuildSprites.y                       ; the screen line, signed round the
        subd  BuildSprites.yLow                     ; playfield's height
        addd  #$400
        anda  BuildSprites.yWrapMask
        subd  #$400
        std   <BuildSprites.y
        addd  <BuildSprites.y1
        blt   @out
        addd  <BuildSprites.ySize
        cmpd  #200
        bge   @out
        ldd   <BuildSprites.y
 ELSE
        ldd   <BuildSprites.y
        addd  <BuildSprites.y1
        cmpd  BuildSprites.yLow
        blt   @out
        addd  <BuildSprites.ySize
        cmpd  BuildSprites.yHigh
        bge   @out
        ldd   <BuildSprites.y                       ; the screen line
        subd  BuildSprites.yLow
 ENDC
        anda  #$28                          ; V2-DEVIATION : a negative line, 256 lines back
        sta   <BuildSprites.lineCorrection
 IFDEF BuildSprites.HALFLINE
        andb  #$FE                          ; V2-DEVIATION (06/10/2026) : an even line
 ENDC
        stb   @ypx
        ldd   <BuildSprites.x                       ; the screen x
        addd  <glb_camera_x_offset
        subd  <BuildSprites.centerParity
        subd  <glb_camera_x_pos
        bcc   >
        subb  #$60                          ; left of the screen : the end of the line above
        lda   @ypx
        bne   @up
        lda   #$28                          ; V2-DEVIATION : line 0, one line up : line -1
        sta   <BuildSprites.lineCorrection
@up     dec   @ypx
!       tfr   b,a
        ldb   #0
@ypx    equ   *-1
        jsr   BuildSprites.drawAt
        andcc #$FE                          ; drawn
        rts
@out    orcc  #1                            ; out of the screen
        rts

* ---------------------------------------------------------------------------
* BuildSprites.drawAt - draws the routine at a screen place
* input  : A the screen x (0-159), B the screen line, BuildSprites.lineCorrection,
*          BuildSprites.drawPage, BuildSprites.drawRoutine
* output : Y and U kept
* ---------------------------------------------------------------------------
BuildSprites.drawAt
        lsra
        lsra                                ; x / 4 : RAMA and RAMB interleaved
        bcs   @ram2                         ; the write begins in RAM2
        sta   @lbyte1
        lda   #40                           ; 40 bytes a line
        mul
        addd  #$C000                        ; (dynamic)
@lbyte1 equ   *-1
        suba  <BuildSprites.lineCorrection                       ; V2-DEVIATION : a negative line, 256 lines back
        std   <glb_screen_location_2
        suba  #$20
        std   <glb_screen_location_1
        bra   @draw
@ram2   sta   @lbyte2
        lda   #40
        mul
        addd  #$A000                        ; (dynamic)
@lbyte2 equ   *-1
        suba  <BuildSprites.lineCorrection                       ; V2-DEVIATION : a negative line, 256 lines back
        std   <glb_screen_location_2
        addd  #$2001
        std   <glb_screen_location_1
@draw   lda   <BuildSprites.drawPage
        _SetCartPageA
        pshs  y,u
        ldu   <glb_screen_location_2
        jsr   [BuildSprites.drawRoutine]
        puls  y,u,pc

; the pass's bounds, extended : dp_engine has no room left for them
BuildSprites.xLow  fdb   0
BuildSprites.xHigh  fdb   0
BuildSprites.yLow  fdb   0
BuildSprites.yHigh  fdb   0
 IFDEF BuildSprites.YWRAP
BuildSprites.yWrapMask fcb $FF         ; the playfield's height : $07 2048 lines, wrapping
 ENDC
 IFDEF BuildSprites.FRONT_PASS
BuildSprites.front fcb 0                   ; set : the pass draws priority 1 alone
 ENDC
