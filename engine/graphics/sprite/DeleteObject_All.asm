* ---------------------------------------------------------------------------
* DeleteObject_All
* ----------------
* Every object deleted at once, as DeleteObject does one by one : the display
* structures of the sprite pack included, those of the optional modules the
* game declares, then the pool. What the game keeps of its own, it clears
* after this call. Every register is trashed.
*
* Included by the game after its sprite pack (opt-in). Its modules :
*   ObjectDp.ENABLED  define : the objects' direct page (ObjectDp.asm)
*   Collision.LISTS   equ n  : the collision list heads (collision-lists.asm)
* ---------------------------------------------------------------------------

DeleteObject_All
        jsr   DisplaySprite_ClearAll
 IFNDEF OverlayMode
        jsr   EraseSprites_ClearAll
 ENDC
 IFDEF ObjectDp.ENABLED
        jsr   ObjectDp_Clear
 ENDC
 IFDEF Collision.LISTS
        jsr   Collision_ClearLists
 ENDC
        jmp   ManagedObjects_ClearAll
