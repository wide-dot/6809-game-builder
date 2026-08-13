* Object ids of the title : the shared prefix, then the title's own.
* Hand-maintained — the dev owns the numbering, the builder places, links
* and bakes. Same shape as the stages : the title is the third unit of the
* exchange slot.

 IFNDEF OBJID_CONST_TITLE
OBJID_CONST_TITLE equ 1

        INCLUDE "src/common/objid-common.const.asm"

ObjID_logo        equ 30
ObjID_text        equ 31
ObjID_push_button equ 32
ObjID_scores      equ 33

objid.count equ 33
objid.animation equ ObjID_animation

 ENDC
