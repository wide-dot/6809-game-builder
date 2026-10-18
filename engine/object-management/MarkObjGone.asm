* ---------------------------------------------------------------------------
* MarkObjGone
* -----------
* Keeps an object while it is near the camera ; past that window, frees its
* respawn entry (so it can be spawned again) and deletes it.
*
* MarkObjGone      U the object : displayed in the window
* MarkObjGone2     U the object, D its x position : displayed in the window
* MarkObjGone3     U the object : nothing done in the window
* V2-DEVIATION : $80 respawn entries, read unsigned (abx).
* ---------------------------------------------------------------------------

Object_Respawn_Table
Obj_respawn_index    fdb    0          ; the respawn entries next to the camera, left and right
Obj_respawn_data     fill   0,$80      ; one byte per entry, bit 7 : the object is live
Obj_respawn_data_End

MarkObjGone
        ldd   x_pos,u
MarkObjGone2
        andb  #$C0                     ; the coarse x
        subd  glb_camera_x_pos_coarse
        cmpd  #$40+160+$20+$40         ; $40 of room each side, $20 rounds 160 up
        bhi   MarkObjGone.delete
        jmp   DisplaySprite

MarkObjGone3
        ldd   x_pos,u
        andb  #$C0
        subd  glb_camera_x_pos_coarse
        cmpd  #$40+160+$20+$40
        bhi   MarkObjGone.delete
        rts

MarkObjGone.delete
        ldb   respawn_index,u
        beq   >                        ; not spawned from the respawn table
        ldx   #Obj_respawn_data
        abx
        lda   ,x
        anda  #%01111111
        sta   ,x                       ; free to spawn again
!       jmp   DeleteObject
