* Object indexes — the game's side of the object/image contract
* ===========================================================================
* Hand-written like examples/sprites : per object id, the page holding its
* imageset, the page and entry point of its code. The whole swarm shares
* id 1 and its ObjectRunSwarm routine ; ids 2 and 3 stay wired to it, no
* object uses them.
* _SetCartPageA writes its byte straight to $E7E6, so these are register
* values, not page numbers : the RAM over cartridge bits belong here.
Img_Page_Index
        fcb   $00                       ; id 0 : free slot
        fcb   map.RAM_OVER_CART+assets.sprites.page   ; id 1 : blockA on RAMA
        fcb   map.RAM_OVER_CART+assets.sprites.page   ; id 2 : blockB on RAMB
        fcb   map.RAM_OVER_CART+assets.sprites.page   ; id 3 : overlay bar on RAMB
Obj_Index_Page
        fcb   $00
        fcb   map.RAM_OVER_CART+assets.gm.main.page  ; the object code is in the game mode
        fcb   map.RAM_OVER_CART+assets.gm.main.page
        fcb   map.RAM_OVER_CART+assets.gm.main.page
        fcb   map.RAM_OVER_CART+assets.map.page      ; map and buffers mount in
        fcb   assets.tilesA.page                     ; cartridge space, tilesets
        fcb   assets.tilesB.page                     ; in the data window
        fcb   map.RAM_OVER_CART+assets.bufB.page
Obj_Index_Address
        fdb   $0000
        fdb   ObjectRunSwarm              ; run routine of every swarm object
        fdb   ObjectRunSwarm              ; ids 2 and 3 unused, kept wired
        fdb   ObjectRunSwarm
        fdb   assets.map.address        ; vscroll data, the v1 way : raw
        fdb   assets.tilesA.address     ; binaries at literal places
        fdb   assets.tilesB.address
        fdb   assets.bufB.address

* vscroll object ids, following the three sprite ids above
objid.map    equ 4
objid.tilesA equ 5
objid.tilesB equ 6
objid.bufB   equ 7

* 200 lines from the start view plus the extra line of the buffer objects
vscroll.BUFFER_LINES equ 201
