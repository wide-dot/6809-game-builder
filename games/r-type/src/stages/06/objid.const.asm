* Object ids of stage 6 : the shared prefix, then the stage's own.
* Hand-maintained since the <objectindex> retirement (2026-08-11) — the dev
* owns the numbering, the builder places, links and bakes.

 IFNDEF OBJID_CONST_06
OBJID_CONST_06 equ 1

        INCLUDE "src/common/objid-common.const.asm"

ObjID_pow equ 33
ObjID_checkpoint equ 34
ObjID_bossmusic equ 35
* La bibliotheque d'ennemis que CE stage charge (ses lots — voir
* src/common/cast.const.asm et l'analyse des lots).
ObjID_bink equ 36
* Le BOSS : l'essaim de Dops, un maitre (les seize Dops, en repere arcade) et
* son renderer groupe, dans leur propre direntry (entree de wave 34 arcade).
ObjID_dopswarm equ 37
ObjID_dopswarm_render equ 38
* Les Dops de la wave (stage6.cast) : le code et la carte a part, les images
* de l'essaim.
ObjID_dop equ 39
* Les Newts de la wave et leurs tirs (stage6.cast).
ObjID_newt equ 40

objid.count equ 40
objid.animation equ ObjID_animation

* RunObjects scales an id with aslb+abx (id*2 in B, RunObjects.asm) : an id
* past 127 loses its top bit in the shift and indexes the wrong entry,
* silently. Ceiling for the whole co-loadable set, shared prefix included.
 IFGT objid.count-127
        ERROR object ids exceed the RunObjects ceiling (127)
 ENDC

 ENDC
