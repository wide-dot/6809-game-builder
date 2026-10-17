* Object ids of stage 8 : the shared prefix, then the stage's own.
* Hand-maintained since the <objectindex> retirement (2026-08-11) — the dev
* owns the numbering, the builder places, links and bakes.

 IFNDEF OBJID_CONST_08
OBJID_CONST_08 equ 1

        INCLUDE "src/common/objid-common.const.asm"

ObjID_pow equ 33
ObjID_checkpoint equ 34
ObjID_bossmusic equ 35
* Le BOSS : le Bydo core, un maitre (toute sa famille, en repere arcade) et
* le renderer groupe de ses Win, dans leur propre direntry (entree de wave
* bydo $0040).
ObjID_bydo equ 36
ObjID_bydo_render equ 37
* La FIN DU JEU : le directeur du generique et la flotte, et le renderer
* groupe de la flotte (stage8.ending), nes par le main apres le fondu.
ObjID_ending equ 38
ObjID_ending_render equ 39

objid.count equ 39
objid.animation equ ObjID_animation

* RunObjects scales an id with aslb+abx (id*2 in B, RunObjects.asm) : an id
* past 127 loses its top bit in the shift and indexes the wrong entry,
* silently. Ceiling for the whole co-loadable set, shared prefix included.
 IFGT objid.count-127
        ERROR object ids exceed the RunObjects ceiling (127)
 ENDC

 ENDC
