* Object ids of stage 7 : the shared prefix, then the stage's own.
* Hand-maintained since the <objectindex> retirement (2026-08-11) — the dev
* owns the numbering, the builder places, links and bakes.

 IFNDEF OBJID_CONST_07
OBJID_CONST_07 equ 1

        INCLUDE "src/common/objid-common.const.asm"

ObjID_pow equ 30
ObjID_checkpoint equ 31
ObjID_bossmusic equ 32
* La bibliotheque d'ennemis que CE stage charge (ses lots — voir
* src/common/cast.const.asm et l'analyse des lots).
ObjID_patapata equ 33
ObjID_bink equ 34
ObjID_cancer equ 35
ObjID_bug equ 36
ObjID_pstaff equ 37
ObjID_scant equ 38
ObjID_mid equ 39
; le renderer groupe des chaines de bug — MEME valeur que l'equ de
; bug.unit.asm (47 : le premier id libre dans les trois stages a bugs)
ObjID_bugrender equ 47

objid.count equ 47
objid.animation equ ObjID_animation

* RunObjects scales an id with aslb+abx (id*2 in B, RunObjects.asm) : an id
* past 127 loses its top bit in the shift and indexes the wrong entry,
* silently. Ceiling for the whole co-loadable set, shared prefix included.
 IFGT objid.count-127
        ERROR object ids exceed the RunObjects ceiling (127)
 ENDC

 ENDC
