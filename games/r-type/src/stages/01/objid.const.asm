* Object ids of stage 1 : the shared prefix, then the stage's own.
* Hand-maintained since the <objectindex> retirement (2026-08-11) — the dev
* owns the numbering, the builder places, links and bakes.

 IFNDEF OBJID_CONST_01
OBJID_CONST_01 equ 1

        INCLUDE "src/common/objid-common.const.asm"

ObjID_patapata equ 30
ObjID_bug equ 31
ObjID_bink equ 32
ObjID_pow equ 33
* 34 : libre — ex-ObjID_fadetotunnel, retire le 16/08/2026 avec la palette
*      de tunnel. L'id n'est PAS recycle : les tables d'index sont indexees
*      par id, renumeroter les suivants les casserait toutes.
ObjID_scant equ 35
ObjID_pstaff equ 36
ObjID_cancer equ 37
ObjID_blaster equ 38
ObjID_shell equ 39
ObjID_tabrok equ 40
ObjID_bossmusic equ 41
ObjID_tailmgr equ 42
ObjID_dobkeratops equ 43
ObjID_dobkeratops_jaw equ 44
ObjID_dobkeratops_monster equ 45
* Le champ d'etoiles, arme par la WAVE comme dans l'arcade (type 0x84 de sa
* table de createurs -> ObjID_33 -> ce nom). L'objet est ephemere : il passe
* le variant au module pagine et rend son slot (stage.starfieldSpawner).
ObjID_starfield equ 46

objid.count equ 46
objid.animation equ ObjID_animation

* RunObjects scales an id with aslb+abx (id*2 in B, RunObjects.asm) : an id
* past 127 loses its top bit in the shift and indexes the wrong entry,
* silently. Ceiling for the whole co-loadable set, shared prefix included.
 IFGT objid.count-127
        ERROR object ids exceed the RunObjects ceiling (127)
 ENDC

 ENDC
