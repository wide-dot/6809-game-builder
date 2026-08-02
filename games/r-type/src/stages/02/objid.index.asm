* Index d'objets — genere par tools/gen_objid.py, ne pas editer

Obj_Index_Page
        fcb   0                        ; id 0 : slot reserve, jamais execute
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_pow
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_bossmusic

Obj_Index_Address
        fdb   0
        fdb   stage.placeholder        ; ObjID_pow
        fdb   stage.placeholder        ; ObjID_bossmusic
