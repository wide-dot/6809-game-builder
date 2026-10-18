* ---------------------------------------------------------------------------
* DeleteObject
* ------------
* Takes an object out of its display list, if it is in one, then out of the
* run list, its data cleared and its slot freed (UnloadObject_u). Every
* register is kept.
*
* DeleteObject                 U the object
* DeleteObject_x / DeleteObject2  X the object
* V2-DEVIATION (18/10/2026) : rewritten from v1's : the unlink shared with
* DisplaySprite, an object never displayed no longer unlinked from list 0.
* ---------------------------------------------------------------------------

DeleteObject_x
DeleteObject2
        pshs  d,x,u
        tfr   x,u
        bra   >
DeleteObject
        pshs  d,x,u
!       tst   rsv_priority,u                ; displayed : out of its list first
        beq   >
        jsr   DisplaySprite.unlink
!       jsr   UnloadObject_u
        puls  d,x,u,pc
