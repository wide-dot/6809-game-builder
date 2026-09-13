* ---------------------------------------------------------------------------
* DrawSprites (1bpp)
* ------------
* Subroutine to draw sprites on screen
* Read Display Priority Structure (back to front)
* priority: 0 - unregistred
* priority: 1 - register non moving overlay sprite
* priority; 2-8 - register moving sprite (2:front, ..., 8:back)
*
* 1bpp port of background-erase-mode/DrawSpritesExtEnc.asm for the $26
* two-plane mode (320x200, 1 bit per pixel). Same walk order, same backup
* contract (U = screen address, Y = background cell end from BgBufferAlloc),
* same metadata snapshots. What changes, and why :
* - address : x_pixel is a byte column, so x/4 + RAMA/RAMB interlace becomes
*   y*40 + xrel with the plane base ($C000 RAMA / $A000 RAMB) selected by the
*   per-object display_plane byte the game declares (see onebpp.const.asm).
*   (x_pixel, y_pixel) is the canvas reference of the image position (centre
*   byte and centre row for position=center) : gfxcomp anchors the compiled
*   code there, whatever the trim, so x_pixel*8 + x1_offset is the exact ink
*   left edge and CSR boxes are exact.
* - movement precision : byte columns are atomic, the x/2 shift is gone on
*   both sides (store here, compare in CheckSpritesRefresh1Bpp).
* - no extended encoders : 1bpp has no alpha maps and no zx0, the draw call
*   is direct and the ifndef stubs are gone.
* - CLEAR1BPP : when the game defines it (clear1 encoder, sprite-only plane),
*   the background cells are skipped — there is nothing to save — and the
*   shared snapshot tail still records prev position and routine for the
*   clear-erase. Unset for the bdraw1 backup path, byte-identical then.
* input REG : none
* ---------------------------------------------------------------------------
InitDrawSprites
        ldd   #onebpp.screen.left.byte
        std   glb_camera_x_offset
        ldd   #screen_top
        std   glb_camera_y_offset
        rts
DrawSprites
DRS_Start
        lda   gfxlock.backBuffer.id         ; read current screen buffer for write operations
        bne   DRS_P8B1
DRS_P8B0
        ldx   DPS_buffer_0+buf_Tbl_Priority_First_Entry+16 ; read DPS from priority 8 to priority 1
        beq   DRS_P7B0
        jsr   DRS_ProcessEachPriorityLevelB0
DRS_P7B0
        ldx   DPS_buffer_0+buf_Tbl_Priority_First_Entry+14
        beq   DRS_P6B0
        jsr   DRS_ProcessEachPriorityLevelB0
DRS_P6B0
        ldx   DPS_buffer_0+buf_Tbl_Priority_First_Entry+12
        beq   DRS_P5B0
        jsr   DRS_ProcessEachPriorityLevelB0
DRS_P5B0
        ldx   DPS_buffer_0+buf_Tbl_Priority_First_Entry+10
        beq   DRS_P4B0
        jsr   DRS_ProcessEachPriorityLevelB0
DRS_P4B0
        ldx   DPS_buffer_0+buf_Tbl_Priority_First_Entry+8
        beq   DRS_P3B0
        jsr   DRS_ProcessEachPriorityLevelB0
DRS_P3B0
        ldx   DPS_buffer_0+buf_Tbl_Priority_First_Entry+6
        beq   DRS_P2B0
        jsr   DRS_ProcessEachPriorityLevelB0
DRS_P2B0
        ldx   DPS_buffer_0+buf_Tbl_Priority_First_Entry+4
        beq   DRS_P1B0
        jsr   DRS_ProcessEachPriorityLevelB0
DRS_P1B0
        ldx   DPS_buffer_0+buf_Tbl_Priority_First_Entry+2
        beq   DRS_rtsB0
        jsr   DRS_ProcessEachPriorityLevelB0
DRS_rtsB0
        rts
DRS_P8B1
        ldx   DPS_buffer_1+buf_Tbl_Priority_First_Entry+16 ; read DPS from priority 8 to priority 1
        beq   DRS_P7B1
        jsr   DRS_ProcessEachPriorityLevelB1
DRS_P7B1
        ldx   DPS_buffer_1+buf_Tbl_Priority_First_Entry+14
        beq   DRS_P6B1
        jsr   DRS_ProcessEachPriorityLevelB1
DRS_P6B1
        ldx   DPS_buffer_1+buf_Tbl_Priority_First_Entry+12
        beq   DRS_P5B1
        jsr   DRS_ProcessEachPriorityLevelB1
DRS_P5B1
        ldx   DPS_buffer_1+buf_Tbl_Priority_First_Entry+10
        beq   DRS_P4B1
        jsr   DRS_ProcessEachPriorityLevelB1
DRS_P4B1
        ldx   DPS_buffer_1+buf_Tbl_Priority_First_Entry+8
        beq   DRS_P3B1
        jsr   DRS_ProcessEachPriorityLevelB1
DRS_P3B1
        ldx   DPS_buffer_1+buf_Tbl_Priority_First_Entry+6
        beq   DRS_P2B1
        jsr   DRS_ProcessEachPriorityLevelB1
DRS_P2B1
        ldx   DPS_buffer_1+buf_Tbl_Priority_First_Entry+4
        beq   DRS_P1B1
        jsr   DRS_ProcessEachPriorityLevelB1
DRS_P1B1
        ldx   DPS_buffer_1+buf_Tbl_Priority_First_Entry+2
        beq   DRS_rtsB1
        jsr   DRS_ProcessEachPriorityLevelB1
DRS_rtsB1
        rts
DRS_ProcessEachPriorityLevelB0
        lda   rsv_render_flags,x
        anda  #rsv_render_displaysprite_mask
        lbeq  DRS_NextObjectB0
        lda   rsv_prev_render_flags_0,x
        lbmi  DRS_NextObjectB0
        lda   render_flags,x
        anda  #render_overlay_mask
        bne   DRS_DrawWithoutBackupB0
 IFNDEF CLEAR1BPP
        lda   rsv_erase_nb_cell,x
        jsr   BgBufferAlloc                 ; allocate free space to store sprite background data
        cmpy  #$0000                        ; y contains cell_end of allocated space
        lbeq   DRS_NextObjectB0             ; branch if no more free space
 ENDC
DRS_DrawWithoutBackupB0
        ldd   xy_pixel,x                    ; load x byte column (108-147) and y position (28-227) in one operation
        suba  rsv_image_center_offset,x     ; always zero for 1bpp, kept for shape
        jsr   DRS_XYToAddress
        ldd   rsv_mapping_frame,x
        std   rsv_prev_mapping_frame_0,x    ; save previous mapping_frame
        lda   rsv_page_draw_routine,x
        _SetCartPageA
        stx   DRS_dyn3B0+1                  ; save x reg
        ldu   <glb_screen_location_2
        jsr   [rsv_draw_routine,x]          ; backup background and draw sprite on working screen buffer
DRS_dyn3B0
        ldx   #$0000                        ; (dynamic) restore x reg
        stu   rsv_bgdata_0,x                ; store pointer to saved background data
        ldd   xy_pixel,x                    ; byte columns are atomic : exact store
        std   rsv_prev_xy_pixel_0,x         ; save previous x_pixel and y_pixel in one operation
        ldd   rsv_xy1_pixel,x               ; load x' and y' in one operation
        std   rsv_prev_xy1_pixel_0,x        ; save as previous x' and y'
        ldd   rsv_xy2_pixel,x               ; load x'' and y'' in one operation
        std   rsv_prev_xy2_pixel_0,x        ; save as previous x'' and y''
        lda   rsv_erase_nb_cell,x
        sta   rsv_prev_erase_nb_cell_0,x
        lda   rsv_page_erase_routine,x
        sta   rsv_prev_page_erase_routine_0,x
        ldd   rsv_erase_routine,x
        std   rsv_prev_erase_routine_0,x
        lda   rsv_prev_render_flags_0,x
        ora   #rsv_prev_render_onscreen_mask
        ldb   render_flags,x
        bitb  #render_overlay_mask
        beq   DRS_NoOverlayB0
        ora   #rsv_prev_render_overlay_mask
        bra   DRS_UpdateRenderFlagB0
DRS_NoOverlayB0
        anda   #^rsv_prev_render_overlay_mask
DRS_UpdateRenderFlagB0
        sta   rsv_prev_render_flags_0,x     ; set the onscreen flag and save overlay flag
        lda   rsv_render_flags,x
        ora   #rsv_render_onscreen_mask     ; sprite is on screen
        sta   rsv_render_flags,x
DRS_NextObjectB0
        ldx   rsv_priority_next_obj_0,x
        lbne  DRS_ProcessEachPriorityLevelB0
        rts
********************************************************************************
* x_pixel and y_pixel coordinate system (1bpp)
* x coordinates (byte columns):
*    - off-screen left 00-6B (0-107)
*    - on screen 6C-93 (108-147)
*    - off-screen right 94-FF (148-255)
*
* y coordinates:
*    - off-screen top 00-1B (0-27)
*    - on screen 1C-E3 (28-227)
*    - off-screen bottom E4-FF (228-255)
********************************************************************************
DRS_XYToAddress
        suba  #onebpp.screen.left.byte
        bcc   DRS_XYToAddressPositive
        suba  #(256-40)                     ; negative case mirrors the BM16 wrap
        decb
DRS_XYToAddressPositive
        subb  #screen_top
        pshs  a                             ; xrel survives the multiply
        lda   #40                           ; 40 bytes per plane line
        mul                                 ; D = 40*yrel
        addb  ,s+                           ; D += xrel, S balanced
        adca  #0
        tst   display_plane,x               ; per-object plane, x is preserved
        bne   DRS_XYToAddressRAMB
        addd  #$C000                        ; RAMA in the data window
        bra   DRS_XYToAddressStore
DRS_XYToAddressRAMB
        addd  #$A000                        ; RAMB in the data window
DRS_XYToAddressStore
        std   <glb_screen_location_2
        rts
DRS_ProcessEachPriorityLevelB1
        lda   rsv_render_flags,x
        anda  #rsv_render_displaysprite_mask
        lbeq  DRS_NextObjectB1
        lda   rsv_prev_render_flags_1,x
        lbmi  DRS_NextObjectB1
        lda   render_flags,x
        anda  #render_overlay_mask
        bne   DRS_DrawWithoutBackupB1
 IFNDEF CLEAR1BPP
        lda   rsv_erase_nb_cell,x
        jsr   BgBufferAlloc                 ; allocate free space to store sprite background data
        cmpy  #$0000                        ; y contains cell_end of allocated space
        lbeq   DRS_NextObjectB1             ; branch if no more free space
 ENDC
DRS_DrawWithoutBackupB1
        ldd   xy_pixel,x                    ; load x byte column (108-147) and y position (28-227) in one operation
        suba  rsv_image_center_offset,x     ; always zero for 1bpp, kept for shape
        jsr   DRS_XYToAddress
        ldd   rsv_mapping_frame,x
        std   rsv_prev_mapping_frame_1,x    ; save previous mapping_frame
        lda   rsv_page_draw_routine,x
        _SetCartPageA
        stx   DRS_dyn3B1+1                  ; save x reg
        ldu   <glb_screen_location_2
        jsr   [rsv_draw_routine,x]
DRS_dyn3B1
        ldx   #$0000                        ; (dynamic) restore x reg
        stu   rsv_bgdata_1,x                ; store pointer to saved background data
        ldd   xy_pixel,x                    ; byte columns are atomic : exact store
        std   rsv_prev_xy_pixel_1,x         ; save previous x_pixel and y_pixel in one operation
        ldd   rsv_xy1_pixel,x               ; load x' and y' in one operation
        std   rsv_prev_xy1_pixel_1,x        ; save as previous x' and y'
        ldd   rsv_xy2_pixel,x               ; load x'' and y'' in one operation
        std   rsv_prev_xy2_pixel_1,x        ; save as previous x'' and y''
        lda   rsv_erase_nb_cell,x
        sta   rsv_prev_erase_nb_cell_1,x
        lda   rsv_page_erase_routine,x
        sta   rsv_prev_page_erase_routine_1,x
        ldd   rsv_erase_routine,x
        std   rsv_prev_erase_routine_1,x
        lda   rsv_prev_render_flags_1,x
        ora   #rsv_prev_render_onscreen_mask
        ldb   render_flags,x
        bitb  #render_overlay_mask
        beq   DRS_NoOverlayB1
        ora   #rsv_prev_render_overlay_mask
        bra   DRS_UpdateRenderFlagB1
DRS_NoOverlayB1
        anda   #^rsv_prev_render_overlay_mask
DRS_UpdateRenderFlagB1
        sta   rsv_prev_render_flags_1,x     ; set the onscreen flag and save overlay flag
        lda   rsv_render_flags,x
        ora   #rsv_render_onscreen_mask     ; sprite is on screen
        sta   rsv_render_flags,x
DRS_NextObjectB1
        ldx   rsv_priority_next_obj_1,x
        lbne  DRS_ProcessEachPriorityLevelB1
        rts
