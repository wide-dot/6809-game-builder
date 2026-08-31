* Object ids of stage 1 : the shared prefix, then the stage's own.
* Hand-maintained since the <objectindex> retirement (2026-08-11) — the dev
* owns the numbering, the builder places, links and bakes.

 IFNDEF OBJID_CONST_01
OBJID_CONST_01 equ 1

        INCLUDE "src/common/objid-common.const.asm"

ObjID_patapata equ 32
ObjID_bug equ 33
ObjID_bink equ 34
ObjID_pow equ 35
* 34 : libre — ex-ObjID_fadetotunnel, retire le 16/08/2026 avec la palette
*      de tunnel. L'id n'est PAS recycle : les tables d'index sont indexees
*      par id, renumeroter les suivants les casserait toutes.
ObjID_scant equ 37
ObjID_pstaff equ 38
ObjID_cancer equ 39
ObjID_blaster equ 40
ObjID_shell equ 41
ObjID_tabrok equ 42
ObjID_bossmusic equ 43
ObjID_tailmgr equ 44
ObjID_dobkeratops equ 45
ObjID_dobkeratops_jaw equ 46
ObjID_dobkeratops_monster equ 47
* Le champ d'etoiles, arme par la WAVE comme dans l'arcade (type 0x84 de sa
* table de createurs -> ObjID_33 -> ce nom). L'objet est ephemere : il passe
* le variant au module pagine et rend son slot (stage.starfieldSpawner).
ObjID_starfield equ 48

ObjID_bugrender equ 49 ; le renderer des chaines de bug — meme valeur que
                       ; l'equ de bug.unit.asm (47 partout)

; le manager des nerfs optiques du dobkeratops (chantier nerfs-overlay)
ObjID_dobkeratops_eyes equ 50

objid.count equ 50
objid.animation equ ObjID_animation

* RunObjects scales an id with aslb+abx (id*2 in B, RunObjects.asm) : an id
* past 127 loses its top bit in the shift and indexes the wrong entry,
* silently. Ceiling for the whole co-loadable set, shared prefix included.
 IFGT objid.count-127
        ERROR object ids exceed the RunObjects ceiling (127)
 ENDC

 ENDC
