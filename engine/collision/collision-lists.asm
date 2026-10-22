* ---------------------------------------------------------------------------
* Collision lists
* ---------------
* The collision list heads, the module's : Collision.LISTS lists (the game's
* equ), each its first and last box (Collision_AddAABB's Y). A game names a
* list by its place (AABB_list_foe equ Collision.lists+1*4).
*
* Collision_ClearLists     every list emptied (the pool cleared :
*                          DeleteObject_All)
* ---------------------------------------------------------------------------

 IFDEF Collision.LISTS
Collision.lists         fill  0,Collision.LISTS*4

Collision_ClearLists
        ldd   #0
        ldx   #Collision.lists
!       std   ,x++
        cmpx  #Collision.lists+Collision.LISTS*4
        blo   <
        rts
 ENDC
