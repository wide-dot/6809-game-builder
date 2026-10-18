* ---------------------------------------------------------------------------
* DisplaySprite
* -------------
* Puts an object in the display lists : a doubly linked list per priority
* (1 : the front pass, 2 : front, ... 8 : back), drawn back to front by
* BuildSprites. A new priority moves it to the end of that list ; priority 0
* takes it out. Displayed, its hide flag is cleared. Every register is kept.
*
* DisplaySprite                            U the object, its priority field ;
*                                          nothing done without an image
* DisplaySprite_x / DisplaySprite2         X the object, its priority field
* DisplaySprite_priority / DisplaySprite3  U the object, A the priority
* V2-DEVIATION (18/10/2026) : rewritten from v1's : priority 0 also clears
* rsv_priority (re-displayed at the same priority, the object stayed out of
* the lists), Y kept, the unlink shared with DeleteObject.
* ---------------------------------------------------------------------------

Tbl_Priority_First_Entry      fill  0,2+(nb_priority_levels*2) ; a priority's first object (entry 0 unused)
Tbl_Priority_Last_Entry       fill  0,2+(nb_priority_levels*2) ; a priority's last object (entry 0 unused)

DisplaySprite_priority
DisplaySprite3
        pshs  d,x,y,u
        bra   @start
DisplaySprite_x
DisplaySprite2
        pshs  d,x,y,u
        tfr   x,u
        bra   >
DisplaySprite
        pshs  d,x,y,u
!       ldx   image_set,u                   ; no image : nothing to display
        beq   @rts
        lda   priority,u
@start  ldb   render_flags,u
        andb  #^render_hide_mask            ; displayed : drawn again
        stb   render_flags,u
        cmpa  rsv_priority,u
        beq   @rts                          ; already in that list
        tst   rsv_priority,u
        beq   @link
        jsr   DisplaySprite.unlink          ; out of its list
@link   sta   rsv_priority,u
        tsta
        beq   @rts                          ; priority 0 : out of the lists
        asla
        ldy   #Tbl_Priority_Last_Entry      ; at the end of the new one
        ldx   a,y                           ; its last object
        bne   @append
        stu   a,y                           ; the only one
        ldy   #Tbl_Priority_First_Entry
        stu   a,y
        stx   rsv_priority_prev_obj,u       ; X = 0
        stx   rsv_priority_next_obj,u
@rts    puls  d,x,y,u,pc
@append stu   rsv_priority_next_obj,x
        stx   rsv_priority_prev_obj,u
        stu   a,y
        ldx   #0
        stx   rsv_priority_next_obj,u
        puls  d,x,y,u,pc

* ---------------------------------------------------------------------------
* DisplaySprite.unlink - takes object U out of the list of its rsv_priority
* (not 0) ; every register kept, the object's own links left as they were
* ---------------------------------------------------------------------------
DisplaySprite.unlink
        pshs  d,x,y
        ldb   rsv_priority,u
        aslb                                ; the list's entries
        ldx   rsv_priority_next_obj,u
        beq   @tail
        ldy   rsv_priority_prev_obj,u
        sty   rsv_priority_prev_obj,x       ; the next one's previous : ours
        bra   @head
@tail   ldy   #Tbl_Priority_Last_Entry
        ldx   rsv_priority_prev_obj,u
        stx   b,y                           ; the list's last : our previous
@head   ldx   rsv_priority_prev_obj,u
        beq   @first
        ldy   rsv_priority_next_obj,u
        sty   rsv_priority_next_obj,x       ; the previous one's next : ours
        puls  d,x,y,pc
@first  ldy   #Tbl_Priority_First_Entry
        ldx   rsv_priority_next_obj,u
        stx   b,y                           ; the list's first : our next
        puls  d,x,y,pc
