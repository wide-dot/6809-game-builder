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
ObjID_loading     equ 34

objid.count equ 34
objid.animation equ ObjID_animation

* RunObjects scales an id with aslb+abx (id*2 in B, RunObjects.asm) : an id
* past 127 loses its top bit in the shift and indexes the wrong entry,
* silently. Ceiling for the whole co-loadable set, shared prefix included.
 IFGT objid.count-127
        ERROR object ids exceed the RunObjects ceiling (127)
 ENDC

 ENDC
