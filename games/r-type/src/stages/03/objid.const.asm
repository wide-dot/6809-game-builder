* Object ids of stage 3 : the shared prefix, then the stage's own.
* Hand-maintained since the <objectindex> retirement (2026-08-11) — the dev
* owns the numbering, the builder places, links and bakes.

 IFNDEF OBJID_CONST_03
OBJID_CONST_03 equ 1

        INCLUDE "src/common/objid-common.const.asm"

ObjID_pow equ 30
ObjID_checkpoint equ 31
ObjID_bossmusic equ 32
* La bibliotheque d'ennemis que CE stage charge (ses lots — voir
* src/common/cast.const.asm et l'analyse des lots).
ObjID_patapata equ 33
ObjID_bink equ 34
* Le pilote de la couche battleship (warship/pilot.asm) — instancie par la
* wave comme en arcade (create_warship 0xc46e).
ObjID_warship_core equ 35
* Les cinq assets de la couche mscroll : PAS des objets (jamais lances) —
* des entrees d'index que mscroll.setup resout en pages/adresses, le
* patron du banc examples/mscroll.
objid.bship.map    equ 36
objid.bship.tilesA equ 37
objid.bship.tilesB equ 38
objid.bship.bufA   equ 39
objid.bship.bufB   equ 40

objid.count equ 40
objid.animation equ ObjID_animation

* RunObjects scales an id with aslb+abx (id*2 in B, RunObjects.asm) : an id
* past 127 loses its top bit in the shift and indexes the wrong entry,
* silently. Ceiling for the whole co-loadable set, shared prefix included.
 IFGT objid.count-127
        ERROR object ids exceed the RunObjects ceiling (127)
 ENDC

 ENDC
