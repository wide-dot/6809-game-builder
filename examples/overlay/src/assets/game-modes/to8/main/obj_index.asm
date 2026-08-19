* ===========================================================================
* Object indexes — the game's side of the object/image contract
* ===========================================================================
* v2 has no object pipeline yet (roadmap item 7), so the bench writes them by
* hand, exactly like examples/sprites. Entry 0 is the reserved "free slot" id.
*
* _SetCartPageA writes its byte straight to $E7E6, so these are register
* values, not page numbers : the RAM over cartridge bits belong here.
Img_Page_Index
        fcb   $00                       ; id 0 : free slot
        fcb   map.RAM_OVER_CART+assets.sprites.page   ; id 1 : glyph
        fcb   map.RAM_OVER_CART+assets.sprites.page   ; id 2 : marker

* RunObjects is included for UnloadObject only (the overlay pack's
* DeleteObject calls it) ; the bench never runs an object, but the symbols
* have to resolve.
Obj_Index_Page
        fcb   $00
        fcb   map.RAM_OVER_CART+assets.gm.main.page
        fcb   map.RAM_OVER_CART+assets.gm.main.page

Obj_Index_Address
        fdb   $0000
        fdb   $0000
        fdb   $0000
