* ===========================================================================
* Object indexes — the game's side of the object/image contract
* ===========================================================================
* v1 generated these three tables during its global placement pass
* (BuildDisk.writeImgPgIndex / writeObjIndex) : per object id, the page and
* the entry point of its code, and the page holding its imageset.
*
* v2 has no object pipeline yet (roadmap item 7), so the bench writes them by
* hand. The values come from the declarative layout: <region name="sprites">
* generates sprites.page, and the imageset symbols are resolved by the load
* time linker. Entry 0 is the reserved "free slot" id.

* _SetCartPageA writes its byte straight to $E7E6, so these are register
* values, not page numbers : the RAM over cartridge bits belong here.
Img_Page_Index
        fcb   $00                       ; id 0 : free slot
        fcb   map.RAM_OVER_CART+sprites.page   ; id 1 : the bench sprite

Obj_Index_Page
        fcb   $00
        fcb   map.RAM_OVER_CART+gamemode.page  ; the object code is in the game mode

Obj_Index_Address
        fdb   $0000
        fdb   ObjectRun                 ; run routine of the bench object

* AnimateSprite mounts the page holding the animation table the same way, and
* reads Ani_Asd_Index only when anim,u is negative — a signed offset into a
* per object table of animations. The bench points anim,u straight at its
* animation, so that path is never taken ; the symbol still has to resolve.
* The animation table is generated into the sprites direntry, next to the
* imagesets it points at, so that is the page to mount. This index has to
* follow wherever the build puts the table.
Ani_Page_Index
        fcb   $00
        fcb   map.RAM_OVER_CART+sprites.page

Ani_Asd_Index
        fdb   $0000
        fdb   $0000

