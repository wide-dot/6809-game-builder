* ---------------------------------------------------------------------------
* CheckSpritesRefresh (1bpp)
* -------------------
* Subroutine to determine if sprites are gonna be erased and/or drawn
* Read Display Priority Structure (back to front)
* priority: 0 - unregistred
* priority: 1 - register non moving overlay sprite
* priority; 2-8 - register moving sprite (2:front, ..., 8:back)
*
* 1bpp port of background-erase-mode/CheckSpritesRefresh.asm for the $26
* two-plane mode (320x200, 1 bit per pixel). Same frame order contract, same
* imageset layout, same rsv metadata. What changes, and why :
* - mapping frame : a single byte-aligned variant exists (no SHIFT_1), so the
*   x parity / center offset selection collapses to bit1 = overlay or not.
*   A missing variant hides the sprite, there is no shifted fallback.
* - horizontal box : x_pixel is a byte column (onebpp.screen.left.byte=108 ..
*   right.byte=147), checked pixel-exact in 16 bits against the byte-aligned
*   bounds. Compiled code draws whole bytes and cannot clip, so without xloop
*   the box must sit fully inside, like the BM16 source requires.
* - movement compare : byte columns are already atomic, the x/2 precision
*   shift is gone on both sides (here and in DrawSprites1Bpp).
* - cross-plane overlaps still force a refresh : harmless (same pixels), just
*   not skipped. Filtering by display_plane is future work, not correctness.
* - dirty cell bitmap, one walk plus a deferred list : the v1 sub-searches
*   only see list entries appended BEFORE the current object in walk order
*   (back to front), so a back object misses a front object's erase and keeps
*   a bitten copy until it moves again — visible flicker in a crowd, and the
*   CLR erase of clear1 makes every overlap a bite. The walk decides the
*   direct erase and draw flags and MARKS the cells they will touch (previous
*   box of an erase, current box of a draw that changes pixels, both in one
*   union mark for a moved sprite) in a 40x13 bitmap of 8x16 px cells. An
*   object unchanged on screen is DEFERRED : once every mark is in, its
*   current box is tested against the bitmap and a hit upgrades it to
*   erase+draw, marking its box in turn so the deferred objects after it
*   follow (chains of 3+ stay order dependent, like v1). Cost is linear in
*   the object count instead of the v1 O(n^2) list scans ; the cell
*   granularity only adds false refreshes. The erase/draw lists of the BM16
*   version are gone : nothing else read them.
* - horizontal box : x1_offset is read from the image SUBSET (the BM16 source
*   reloads y there ; the set holds x_size at the same offset).
* input REG : none
* ---------------------------------------------------------------------------
* ---------------------------------------------------------------------------
* Dirty cell bitmap
* ---------------------------------------------------------------------------
* 40 columns (one screen byte each) x 13 rows of 16 px, column-major : one
* word per column, bit 15 = row 0 ... bit 3 = row 12. A box (x1,y1,x2,y2) in
* rsv byte columns / pixel rows becomes a run of columns sharing one row mask,
* From[r1] AND To[r2]. Columns are clamped to the screen (xloop sprites).
cur_priority                  equ dp_engine   ; byte
CSR_box                       equ dp_engine+1 ; x1,y1,x2,y2 handed to the dirty routines
CSR_mask                      equ dp_engine+5 ; row mask word
CSR_c1                        equ dp_engine+7 ; first column
CSR_cnt                       equ dp_engine+8 ; column count
CSR_defer.ptr                 equ dp_engine+9 ; word : next free cell of the deferred list
onebpp.dirty.COLS             equ 40
onebpp.dirty.ROWS             equ 13
CSR_defer                     fill  0,nb_graphical_objects*2 ; objects unchanged on screen, walk order, phase 1 input
CSR_dirty                     fill  0,onebpp.dirty.COLS*2
CSR_dirty_end
CSR_rowFrom                   fdb   $ffff,$7fff,$3fff,$1fff,$0fff,$07ff,$03ff ; rows >= r
                              fdb   $01ff,$00ff,$007f,$003f,$001f,$000f
CSR_rowTo                     fdb   $8000,$c000,$e000,$f000,$f800,$fc00,$fe00 ; rows <= r
                              fdb   $ff00,$ff80,$ffc0,$ffe0,$fff0,$fff8
; V2-DEVIATION: setdp neutralized, the obj target rejects it. Extended
; addressing stays correct, and operands explicitly forced with < are unaffected.
;       setdp dp/256
CheckSpritesRefresh
CSR_Start
        ldu   #CSR_dirty_end                ; clear the bitmap : 13 x 6 + 2 = 80 bytes
        ldd   #0                            ; through u, interrupts push on s
        ldx   #0
        ldy   #0
        pshu  d,x,y
        pshu  d,x,y
        pshu  d,x,y
        pshu  d,x,y
        pshu  d,x,y
        pshu  d,x,y
        pshu  d,x,y
        pshu  d,x,y
        pshu  d,x,y
        pshu  d,x,y
        pshu  d,x,y
        pshu  d,x,y
        pshu  d,x,y
        pshu  d
        ldd   #CSR_defer
        std   CSR_defer.ptr
        jsr   CSR_WalkAll                   ; phase 0 : every object, direct flags and marks
        ; phase 1 : the objects deferred as unchanged, in walk order (back to
        ; front), asked to the bitmap. Their previous box is their current box
        ; and they are on screen, in range, at their registered priority.
        ldx   #CSR_defer
CSR_Phase1
        cmpx  CSR_defer.ptr
        beq   CSR_Phase1.end
        ldu   ,x++
        jsr   CSR_dirty.testCur             ; z clear when a mark touches its box
        beq   CSR_Phase1.unchanged
        jsr   CSR_dirty.markCur             ; upgrade : erase and draw, and the
        lda   rsv_render_flags,u            ; objects after it follow (chain)
        ora   #rsv_render_erasesprite_mask|rsv_render_displaysprite_mask
        sta   rsv_render_flags,u
        bra   CSR_Phase1.hide
CSR_Phase1.unchanged
        lda   rsv_render_flags,u
        anda  #^rsv_render_erasesprite_mask
        ora   #rsv_render_displaysprite_mask ; still displayed, DrawSprites skips it (on screen)
        sta   rsv_render_flags,u
CSR_Phase1.hide
        lda   render_flags,u
        ora   #render_hide_mask             ; set hide flag, like every drawn object
        sta   render_flags,u
        bra   CSR_Phase1
CSR_Phase1.end
        rts
CSR_WalkAll
        lda   gfxlock.backBuffer.id         ; read current screen buffer for write operations
        bne   CSR_SetBuffer1
CSR_SetBuffer0
        lda   #rsv_buffer_0                 ; set offset to object variables that belongs to screen buffer 0
        sta   CSR_ProcessEachPriorityLevel+2
CSR_P8B0
        ldu   DPS_buffer_0+buf_Tbl_Priority_First_Entry+16 ; read DPS from priority 8 to priority 1
        beq   CSR_P7B0
        lda   #$08
        sta   cur_priority
        jsr   CSR_ProcessEachPriorityLevel
CSR_P7B0
        ldu   DPS_buffer_0+buf_Tbl_Priority_First_Entry+14
        beq   CSR_P6B0
        lda   #$07
        sta   cur_priority
        jsr   CSR_ProcessEachPriorityLevel
CSR_P6B0
        ldu   DPS_buffer_0+buf_Tbl_Priority_First_Entry+12
        beq   CSR_P5B0
        lda   #$06
        sta   cur_priority
        jsr   CSR_ProcessEachPriorityLevel
CSR_P5B0
        ldu   DPS_buffer_0+buf_Tbl_Priority_First_Entry+10
        beq   CSR_P4B0
        lda   #$05
        sta   cur_priority
        jsr   CSR_ProcessEachPriorityLevel
CSR_P4B0
        ldu   DPS_buffer_0+buf_Tbl_Priority_First_Entry+8
        beq   CSR_P3B0
        lda   #$04
        sta   cur_priority
        jsr   CSR_ProcessEachPriorityLevel
CSR_P3B0
        ldu   DPS_buffer_0+buf_Tbl_Priority_First_Entry+6
        beq   CSR_P2B0
        lda   #$03
        sta   cur_priority
        jsr   CSR_ProcessEachPriorityLevel
CSR_P2B0
        ldu   DPS_buffer_0+buf_Tbl_Priority_First_Entry+4
        beq   CSR_P1B0
        lda   #$02
        sta   cur_priority
        jsr   CSR_ProcessEachPriorityLevel
CSR_P1B0
        ldu   DPS_buffer_0+buf_Tbl_Priority_First_Entry+2
        beq   CSR_rtsB0
        lda   #$01
        sta   cur_priority
        jsr   CSR_ProcessEachPriorityLevel
CSR_rtsB0
        rts
CSR_SetBuffer1
        lda   #rsv_buffer_1                 ; set offset to object variables that belongs to screen buffer 1
        sta   CSR_ProcessEachPriorityLevel+2
CSR_P8B1
        ldu   DPS_buffer_1+buf_Tbl_Priority_First_Entry+16 ; read DPS from priority 8 to priority 1
        beq   CSR_P7B1
        lda   #$08
        sta   cur_priority
        jsr   CSR_ProcessEachPriorityLevel
CSR_P7B1
        ldu   DPS_buffer_1+buf_Tbl_Priority_First_Entry+14
        beq   CSR_P6B1
        lda   #$07
        sta   cur_priority
        jsr   CSR_ProcessEachPriorityLevel
CSR_P6B1
        ldu   DPS_buffer_1+buf_Tbl_Priority_First_Entry+12
        beq   CSR_P5B1
        lda   #$06
        sta   cur_priority
        jsr   CSR_ProcessEachPriorityLevel
CSR_P5B1
        ldu   DPS_buffer_1+buf_Tbl_Priority_First_Entry+10
        beq   CSR_P4B1
        lda   #$05
        sta   cur_priority
        jsr   CSR_ProcessEachPriorityLevel
CSR_P4B1
        ldu   DPS_buffer_1+buf_Tbl_Priority_First_Entry+8
        beq   CSR_P3B1
        lda   #$04
        sta   cur_priority
        jsr   CSR_ProcessEachPriorityLevel
CSR_P3B1
        ldu   DPS_buffer_1+buf_Tbl_Priority_First_Entry+6
        beq   CSR_P2B1
        lda   #$03
        sta   cur_priority
        jsr   CSR_ProcessEachPriorityLevel
CSR_P2B1
        ldu   DPS_buffer_1+buf_Tbl_Priority_First_Entry+4
        beq   CSR_P1B1
        lda   #$02
        sta   cur_priority
        jsr   CSR_ProcessEachPriorityLevel
CSR_P1B1
        ldu   DPS_buffer_1+buf_Tbl_Priority_First_Entry+2
        beq   CSR_rtsB1
        lda   #$01
        sta   cur_priority
        jsr   CSR_ProcessEachPriorityLevel
CSR_rtsB1
        rts
CSR_ProcessEachPriorityLevel
        leax  16,u                          ; dynamic offset, x point to object variables relative to current writable buffer (beware that rsv_buffer_0 and rsv_buffer_1 should be equ >=16)
CSR_CheckDelHide
        lda   render_flags,u
        anda  #render_hide_mask|render_todelete_mask
        lbne  CSR_DoNotDisplaySprite
CSR_CheckRefresh
        lda   rsv_render_flags,u
        anda  #rsv_render_checkrefresh_mask ; branch if checkrefresh is true
        lbne  CSR_CheckErase
CSR_UpdSpriteImageBasedOnMirror
        ; an image set is made of 1 to 4 image subsets
        ; each subset represent a mirrored version of the image (N: normal, X: x mirror, Y: y mirror, XY: xy mirror)
        ; this code set the active image subset based on mirror flags
        lda   rsv_render_flags,u
        ora   #rsv_render_checkrefresh_mask
        sta   rsv_render_flags,u            ; set checkrefresh flag to true
        ldy   #Img_Page_Index               ; call page that store imageset for this object
        lda   #$00
        ldb   id,u
        lda   d,y
        _SetCartPageA
        lda   render_flags,u                ; set image to display based on x and y mirror flags
        anda  #render_xmirror_mask|render_ymirror_mask
        ldy   image_set,u
        ldb   image_center_offset,y
        stb   rsv_image_center_offset,u
        ldb   a,y
        leay  b,y                           ; read image set index
        sty   rsv_image_subset,u
CSR_CheckPlayFieldCoord
        lda   render_flags,u
        anda  #render_playfieldcoord_mask
        beq   CSR_ComputeMappingFrame       ; branch if position is already expressed in screen coordinate
        ; purpose here is to check if image coordinate in the playfield
        ; can be converted to screen position, if not it is flagged out of range
        ldd   x_pos,u
        subd  <glb_camera_x_pos
        lblo  CSR_SetOutOfRange             ; out of range if x_pos < glb_camera_x_pos
        tsta
        lbne  CSR_SetOutOfRange             ; out of range if x_pos + 256 > glb_camera_x_pos
        addb  glb_camera_x_offset+1
        stb   x_pixel,u
        ldd   y_pos,u
        subd  <glb_camera_y_pos
        lblo  CSR_SetOutOfRange             ; out of range if y_pos < glb_camera_y_pos
        tsta
        lbne  CSR_SetOutOfRange             ; out of range if y_pos + 256 > glb_camera_y_pos
        addb  glb_camera_y_offset+1
        stb   y_pixel,u
        bra   CSR_ComputeMappingFrame
CSR_DoNotDisplaySprite
        lda   priority,u
        cmpa  cur_priority
        bne   CSR_NextObject                ; next object if this one is a new priority record (no need to erase)
        lda   rsv_render_flags,u
        anda  #^rsv_render_erasesprite_mask&^rsv_render_displaysprite_mask ; set erase and display flag to false
        sta   rsv_render_flags,u
        ldb   buf_prev_render_flags,x
        bpl   CSR_NextObject                ; branch if not on screen
        ora   #rsv_render_erasesprite_mask  ; set erase flag to true if on screen
        sta   rsv_render_flags,u
        jsr   CSR_dirty.markPrev            ; its old pixels go
CSR_NextObject
        ldu   buf_priority_next_obj,x
        lbne  CSR_ProcessEachPriorityLevel
        rts
CSR_ComputeMappingFrame
        ; 1bpp has a single byte-aligned variant per mirror/overlay combination :
        ; bit1 selects overlay (draw, no background save), bit0 would select the
        ; 1px shifted image and is always zero here. A missing entry hides the
        ; sprite outright, there is no shifted fallback to try.
        ldb   #0
        lda   render_flags,u
        anda  #render_overlay_mask          ; set bit1 for normal (background save) or overlay sprite (no background save)
        beq   @c
        incb
@c      lda   b,y
        beq   CSR_NoDefinedFrame
        leay  a,y                           ; read image subset index
        sty   rsv_mapping_frame,u
        bra   CSR_UpdateMetadata
CSR_NoDefinedFrame
        ldy   #0                            ; no defined frame, nothing will be displayed
        sty   rsv_mapping_frame,u
        lda   render_flags,u
        ora   #render_hide_mask             ; set hide flag
        sta   render_flags,u
        jmp   CSR_CheckErase
CSR_UpdateMetadata
        lda   erase_nb_cell,y               ; copy current image metadata into object data
        sta   rsv_erase_nb_cell,u           ; this is needed to avoid a lot of page switch
        lda   page_draw_routine,y           ; during following routines
        sta   rsv_page_draw_routine,u
        ldd   draw_routine,y
        std   rsv_draw_routine,u
        lda   page_erase_routine,y
        sta   rsv_page_erase_routine,u
        ldd   erase_routine,y
        std   rsv_erase_routine,u
CSR_CheckPosition
        ldb   y_pixel,u                     ; check if sprite is fully in screen vertical range
        ldy   rsv_image_subset,u            ; (long branches : the 1bpp X box below
        addb  image_subset_y1_offset,y      ; is longer than the BM16 one it replaces)
        cmpb  #screen_bottom
        lbhi  CSR_SetOutOfRange
        cmpb  #screen_top
        lblo  CSR_SetOutOfRange
        stb   rsv_y1_pixel,u
        ldy   image_set,u
        addb  image_y_size,y
        cmpb  #screen_bottom
        lbhi  CSR_SetOutOfRange
        cmpb  #screen_top
        lblo  CSR_SetOutOfRange
        stb   rsv_y2_pixel,u
        cmpb  rsv_y1_pixel,u                ; check wrapping
        lblo  CSR_SetOutOfRange
        ; horizontal box in byte columns : gfxcomp anchors the 1bpp code on the
        ; canvas reference byte, so x_pixel + floor(x1_offset/8) is the exact
        ; first ink byte and x_pixel + floor((x1_offset+x_size)/8) the last one,
        ; inclusive. Whole bytes are drawn : byte bounds are exact, not
        ; conservative, and a sprite must sit fully inside them without xloop.
        ldy   rsv_image_subset,u            ; x1_offset lives in the subset (the set
        ldb   image_subset_x1_offset,y      ; holds x_size at the same offset !)
        sex                                 ; D = signed x1_offset
        asra                                ; D >> 3, floor
        rorb
        asra
        rorb
        asra
        rorb
        addb  x_pixel,u                     ; first ink byte
        stb   rsv_x1_pixel,u
        ldb   image_subset_x1_offset,y
        sex
        ldy   image_set,u
        addb  image_x_size,y                ; D = x1_offset + x_size (last ink pixel)
        adca  #0
        asra
        rorb
        asra
        rorb
        asra
        rorb
        addb  x_pixel,u                     ; last ink byte
        stb   rsv_x2_pixel,u
        lda   render_flags,u
        bita  #render_xloop_mask
        bne   CSR_DontCheckXFrontier_end    ; xloop : no range check
        lda   rsv_x1_pixel,u
        cmpa  #onebpp.screen.left.byte
        blo   CSR_SetOutOfRange
        cmpb  #onebpp.screen.right.byte
        bhi   CSR_SetOutOfRange
        cmpb  rsv_x1_pixel,u                ; wrapping
        blo   CSR_SetOutOfRange
CSR_DontCheckXFrontier_end
        lda   rsv_render_flags,u
        anda  #^rsv_render_outofrange_mask  ; unset out of range flag
        sta   rsv_render_flags,u
        bra   CSR_CheckErase
CSR_SetOutOfRange
        lda   rsv_render_flags,u
        ora   #rsv_render_outofrange_mask   ; set out of range flag
        sta   rsv_render_flags,u
CSR_CheckErase
        lda   buf_priority,x
        cmpa  cur_priority
        lbne  CSR_CheckDraw
        lda   rsv_render_flags,u
        anda  #rsv_render_outofrange_mask
        beq   CSR_CheckErase_InRange
        lda   buf_prev_render_flags,x
        lbpl  CSR_SetEraseDrawFalse         ; branch if object is not on screen
        bra   CSR_SetEraseTrue
CSR_CheckErase_InRange
        lda   buf_prev_render_flags,x
        lbpl  CSR_SetEraseFalse             ; branch if object is not on screen
        lda   <glb_force_sprite_refresh
        bne   CSR_SetEraseTrue
        ldd   xy_pixel,u                    ; byte columns are atomic : exact compare
        cmpd  buf_prev_xy_pixel,x           ; (the BM16 x/2 precision shift is gone)
        bne   CSR_SetEraseTrue              ; branch if object moved since last frame
        ldd   rsv_mapping_frame,u
        cmpd  buf_prev_mapping_frame,x
        bne   CSR_SetEraseTrue              ; branch if object image changed since last frame
        lda   priority,u
        cmpa  buf_priority,x
        bne   CSR_SetEraseTrue              ; branch if object priority changed since last frame
        ldy   CSR_defer.ptr                 ; unchanged on screen : deferred, phase 1
        stu   ,y++                          ; asks the bitmap once every mark is in
        sty   CSR_defer.ptr
        lbra  CSR_NextObject
CSR_SetEraseTrue                            ; marks happen in CheckDraw, once it
        lda   rsv_render_flags,u            ; knows whether a draw follows
        ora   #rsv_render_erasesprite_mask
        sta   rsv_render_flags,u
        bra   CSR_CheckDraw
CSR_SetEraseFalse
        lda   rsv_render_flags,u
        anda  #^rsv_render_erasesprite_mask
        sta   rsv_render_flags,u
CSR_CheckDraw
        lda   priority,u
        cmpa  cur_priority
        lbne  CSR_DrawSkip
        lda   rsv_render_flags,u
        anda  #rsv_render_outofrange_mask
        bne   CSR_SetDrawFalse              ; branch if object image is out of range
        ldd   rsv_mapping_frame,u
        beq   CSR_SetDrawFalse              ; branch if object have no image
        lda   render_flags,u
        anda  #render_hide_mask
        bne   CSR_SetDrawFalse              ; branch if object is hidden
CSR_SetDrawTrue
        lda   rsv_render_flags,u
        ora   #rsv_render_displaysprite_mask ; set displaysprite flag
        sta   rsv_render_flags,u
        ; mark the cells this object will touch. Erased (so on screen) and
        ; drawn again : old and new box in one union mark. Not erased and not
        ; on screen : it appears, new box. Not erased and on screen : cannot
        ; happen here, such an object was deferred.
        bita  #rsv_render_erasesprite_mask
        beq   CSR_MarkAppear
        jsr   CSR_dirty.markUnion
        bra   CSR_SetHide
CSR_MarkAppear
        ldb   buf_prev_render_flags,x
        bmi   CSR_SetHide
        jsr   CSR_dirty.markCur
        bra   CSR_SetHide
CSR_DrawSkip                                ; registered at another priority this
        lda   rsv_render_flags,u            ; frame : the erase decided at the old
        ; level is all there is to mark here
        bita  #rsv_render_erasesprite_mask
        lbeq  CSR_NextObject
        jsr   CSR_dirty.markPrev
        jmp   CSR_NextObject
CSR_SetHide
        lda   render_flags,u
        ora   #render_hide_mask             ; set hide flag
        sta   render_flags,u
        ldu   buf_priority_next_obj,x
        lbne  CSR_ProcessEachPriorityLevel
        rts
CSR_SetEraseDrawFalse
        lda   rsv_render_flags,u
        anda  #^rsv_render_erasesprite_mask
        sta   rsv_render_flags,u
CSR_SetDrawFalse
        lda   rsv_render_flags,u
        anda  #^rsv_render_displaysprite_mask
        sta   rsv_render_flags,u
        bita  #rsv_render_erasesprite_mask  ; erased and not drawn again (out of
        beq   CSR_SetDrawFalse.next         ; range, hidden, no frame) : its old
        jsr   CSR_dirty.markPrev            ; pixels go
CSR_SetDrawFalse.next
        ldu   buf_priority_next_obj,x
        lbne  CSR_ProcessEachPriorityLevel
        rts
* ---------------------------------------------------------------------------
* Dirty cell bitmap routines. x and u are preserved, y and d are not.
* ---------------------------------------------------------------------------
CSR_dirty.markCur                           ; u = object : its current box
        ldd   rsv_xy1_pixel,u
        std   CSR_box
        ldd   rsv_xy2_pixel,u
        std   CSR_box+2
        bra   CSR_dirty.mark
CSR_dirty.markUnion                         ; u = object, x = its buffer variables : previous box + current box
        lda   rsv_x1_pixel,u                ; (an xloop sprite wrapping the byte
        cmpa  buf_prev_xy1_pixel,x          ; space makes a wide union : false
        bls   CSR_dirty.markUnion.x1        ; refreshes, never a miss)
        lda   buf_prev_xy1_pixel,x
CSR_dirty.markUnion.x1
        sta   CSR_box
        lda   rsv_y1_pixel,u
        cmpa  buf_prev_xy1_pixel+1,x
        bls   CSR_dirty.markUnion.y1
        lda   buf_prev_xy1_pixel+1,x
CSR_dirty.markUnion.y1
        sta   CSR_box+1
        lda   rsv_x2_pixel,u
        cmpa  buf_prev_xy2_pixel,x
        bhs   CSR_dirty.markUnion.x2
        lda   buf_prev_xy2_pixel,x
CSR_dirty.markUnion.x2
        sta   CSR_box+2
        lda   rsv_y2_pixel,u
        cmpa  buf_prev_xy2_pixel+1,x
        bhs   CSR_dirty.markUnion.y2
        lda   buf_prev_xy2_pixel+1,x
CSR_dirty.markUnion.y2
        sta   CSR_box+3
        bra   CSR_dirty.mark
CSR_dirty.markPrev                          ; x = object buffer variables : its previous box
        ldd   buf_prev_xy1_pixel,x
        std   CSR_box
        ldd   buf_prev_xy2_pixel,x
        std   CSR_box+2
CSR_dirty.mark
        jsr   CSR_dirty.locate
        beq   CSR_dirty.mark.rts
CSR_dirty.mark.col
        ldd   ,y
        ora   CSR_mask
        orb   CSR_mask+1
        std   ,y++
        dec   CSR_cnt
        bne   CSR_dirty.mark.col
CSR_dirty.mark.rts
        rts
CSR_dirty.testCur                           ; u = object ; out : z clear when a mark touches its box
        ldd   rsv_xy1_pixel,u
        std   CSR_box
        ldd   rsv_xy2_pixel,u
        std   CSR_box+2
        jsr   CSR_dirty.locate
        beq   CSR_dirty.test.rts            ; nothing on screen : clean
CSR_dirty.test.col
        ldd   ,y++
        anda  CSR_mask
        bne   CSR_dirty.test.rts
        andb  CSR_mask+1
        bne   CSR_dirty.test.rts
        dec   CSR_cnt
        bne   CSR_dirty.test.col
CSR_dirty.test.rts
        rts                                 ; z set by the last dec : clean
CSR_dirty.locate                            ; CSR_box -> y = first column word, CSR_cnt, CSR_mask ; z set when off screen
        lda   CSR_box+1                     ; y1 -> row word index : (y/16)*2
        suba  #screen_top
        lsra
        lsra
        lsra
        anda  #$FE
        ldy   #CSR_rowFrom
        ldd   a,y
        std   CSR_mask
        lda   CSR_box+3                     ; y2
        suba  #screen_top
        lsra
        lsra
        lsra
        anda  #$FE
        ldy   #CSR_rowTo
        leay  a,y
        lda   CSR_mask
        anda  ,y
        sta   CSR_mask
        lda   CSR_mask+1
        anda  1,y
        sta   CSR_mask+1
        lda   CSR_box                       ; x1 -> first column, clamped left
        suba  #onebpp.screen.left.byte
        bcc   CSR_dirty.locate.left
        clra
CSR_dirty.locate.left
        cmpa  #onebpp.dirty.COLS
        bhs   CSR_dirty.locate.none         ; starts past the right edge
        sta   CSR_c1
        ldb   CSR_box+2                     ; x2 -> last column, clamped right
        subb  #onebpp.screen.left.byte
        bcs   CSR_dirty.locate.none         ; ends before the left edge
        cmpb  #onebpp.dirty.COLS
        blo   CSR_dirty.locate.right
        ldb   #onebpp.dirty.COLS-1
CSR_dirty.locate.right
        subb  CSR_c1
        bcs   CSR_dirty.locate.none         ; wrapped box, x2 < x1
        incb
        stb   CSR_cnt
        lsla                                ; a = c1 still
        ldy   #CSR_dirty
        leay  a,y                           ; z clear, y is never zero
        rts
CSR_dirty.locate.none
        clrb                                ; z set
        rts
