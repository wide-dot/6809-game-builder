* ---------------------------------------------------------------------------
* RunObjects
* ----------
* The object manager : a pool of nb_dynamic_objects slots, the stack of the
* free ones, and the run list, doubly linked, walked by RunObjects. A free
* slot is all zeros.
*
* InitStack                    every slot free, the run list empty
* ManagedObjects_ClearAll      every slot cleared, then InitStack ; in
*                              OverlayMode the display lists emptied too
* RunObjects                   runs the list's objects in order ; one may
*                              delete itself or others, or link new ones
*                              (run the same pass)
* RunFrozenObjects             clears every object's hide flag, runs nothing
* LoadObject_u / LoadObject_x  a free slot linked at the end of the list, in
*                              U / X ; Z set when the pool is full
* UnloadObject_u / _x          the object U / X unlinked, cleared, freed ;
*                              every register kept
* V2-DEVIATION : up to 256 objects (ObjID unsigned, abx) ; Obj_Index_Address
* read on its own unless OBJ_INDEX_LOCAL (a difference of two symbols does not
* link across units) ; ClearAll also frees the slots (v1 lost the slots in use).
* OverlayMode : the overlay DisplaySprite keeps a doubly linked list per
* priority across frames, its heads and tails in Tbl_Priority_First_Entry /
* Last_Entry ; ClearAll empties them, or they would still point into the
* cleared pool, and the next object given one of those slots would be linked
* to itself and drawn with another one's image.
* ---------------------------------------------------------------------------

object_list_first fdb   0
object_list_last  fdb   0

RunObjects.freeSlots    fill  0,nb_dynamic_objects*2 ; the free slots' addresses
RunObjects.freeSlotsEnd
RunObjects.freeSlot     fdb   0                      ; the top of that stack

ManagedObjects_ClearAll
 IFDEF OverlayMode
        ldd   #0                       ; the display lists : no object left
        ldx   #Tbl_Priority_First_Entry
!       std   ,x++
        cmpx  #Tbl_Priority_First_Entry+2+(nb_priority_levels*2)
        blo   <
        ldx   #Tbl_Priority_Last_Entry
!       std   ,x++
        cmpx  #Tbl_Priority_Last_Entry+2+(nb_priority_levels*2)
        blo   <
 ENDC
        ldd   #0
        ldx   #0
        leay  ,x
        ldu   #Dynamic_Object_RAM_End
!       pshu  d,x,y                    ; six bytes at a time
        cmpu  #Dynamic_Object_RAM+6
        bhs   <
!       cmpu  #Dynamic_Object_RAM      ; then one at a time
        beq   InitStack
        pshu  a
        bra   <

InitStack
        ldu   #RunObjects.freeSlotsEnd
        ldx   #Dynamic_Object_RAM_End-object_size
!       pshu  x                        ; the lowest slot ends on top
        leax  -object_size,x
        cmpu  #RunObjects.freeSlots
        bne   <
        stu   RunObjects.freeSlot
        ldx   #0
        stx   object_list_first
        stx   object_list_last
        stx   object_list_next
        rts

RunObjects
        ldu   object_list_first
        beq   @rts
@loop   ldb   id,u                     ; id 0 : a booked slot, nothing to run
        beq   @skip
        ldx   #Obj_Index_Page
        abx
        lda   ,x
        _SetCartPageA                  ; the object's page
 IFDEF OBJ_INDEX_LOCAL
        abx
 ELSE
        ldx   #Obj_Index_Address
        abx
        abx
 ENDC
        ldd   run_object_next,u        ; saved : the object may delete itself
        std   object_list_next
 IFDEF OBJ_INDEX_LOCAL
        jsr   [Obj_Index_Address-Obj_Index_Page,x]
 ELSE
        jsr   [,x]
 ENDC
        ldu   run_object_next,u        ; a child linked by the last object is here
        bne   @loop
        ldu   #0                       ; else the saved one
object_list_next equ *-2
        bne   @loop
@rts    rts
@skip   ldu   run_object_next,u
        bne   @loop
        rts

RunFrozenObjects
        ldu   object_list_first
        beq   @rts
!       lda   render_flags,u
        anda  #^render_hide_mask
        sta   render_flags,u
        ldu   run_object_next,u
        bne   <
@rts    rts

LoadObject_u
        ldu   RunObjects.freeSlot
        cmpu  #RunObjects.freeSlotsEnd
        bne   >
        rts                            ; Z set : the pool is full
!       pshs  x
        leax  2,u
        stx   RunObjects.freeSlot      ; popped
        ldu   ,u
        ldx   object_list_last
        beq   @first
        stu   run_object_next,x
        stx   run_object_prev,u
        stu   object_list_last         ; Z clear
        puls  x,pc
@first  stu   object_list_first
        stu   object_list_last         ; Z clear
        puls  x,pc

LoadObject_x
        pshs  u
        bsr   LoadObject_u
        tfr   u,x                      ; the flags kept
        puls  u,pc

UnloadObject_u
        pshs  d,x,y,u
        ldx   RunObjects.freeSlot
        stu   ,--x                     ; pushed
        stx   RunObjects.freeSlot
        cmpu  object_list_next         ; RunObjects' next : ours instead
        bne   >
        ldd   run_object_next,u
        std   object_list_next
!       ldx   run_object_prev,u
        ldy   run_object_next,u
        beq   @last
        stx   run_object_prev,y        ; the next one's previous : ours
        bra   >
@last   stx   object_list_last         ; the list's last : our previous
!       beq   @first                   ; Z from the store of X
        sty   run_object_next,x        ; the previous one's next : ours
        bra   @clear
@first  sty   object_list_first        ; the list's first : our next
@clear  leau  object_size,u
        ldd   #0
        ldx   #0
        leay  ,x
        fill  $36,(object_size/6)*2    ; pshu d,x,y : six bytes each
        IFEQ object_size%6-5
        pshu  a,x,y
        ENDC
        IFEQ object_size%6-4
        pshu  d,x
        ENDC
        IFEQ object_size%6-3
        pshu  a,x
        ENDC
        IFEQ object_size%6-2
        pshu  d
        ENDC
        IFEQ object_size%6-1
        pshu  a
        ENDC
        puls  d,x,y,u,pc

UnloadObject_x
        pshs  u
        tfr   x,u
        bsr   UnloadObject_u
        puls  u,pc
