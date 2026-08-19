* Object ids of stage 2 : the shared prefix, then the stage's own.
* Hand-maintained since the <objectindex> retirement (2026-08-11) — the dev
* owns the numbering, the builder places, links and bakes.

 IFNDEF OBJID_CONST_02
OBJID_CONST_02 equ 1

        INCLUDE "src/common/objid-common.const.asm"

ObjID_pow equ 30
ObjID_checkpoint equ 31
ObjID_bossmusic equ 32
* Le cast du chantier 3 — squelettes (spawn + delete immédiat), les
* implémentations viendront de la référence arcade, ennemi par ennemi.
ObjID_gouger equ 33
ObjID_wick equ 34
ObjID_brood equ 35
ObjID_outslay equ 36
ObjID_gomander equ 37

objid.count equ 37
objid.animation equ ObjID_animation

* RunObjects scales an id with aslb+abx (id*2 in B, RunObjects.asm) : an id
* past 127 loses its top bit in the shift and indexes the wrong entry,
* silently. Ceiling for the whole co-loadable set, shared prefix included.
 IFGT objid.count-127
        ERROR object ids exceed the RunObjects ceiling (127)
 ENDC

 ENDC
