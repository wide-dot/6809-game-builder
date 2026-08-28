* Object ids of stage 4 : the shared prefix, then the stage's own.
* Hand-maintained since the <objectindex> retirement (2026-08-11) — the dev
* owns the numbering, the builder places, links and bakes.

 IFNDEF OBJID_CONST_04
OBJID_CONST_04 equ 1

        INCLUDE "src/common/objid-common.const.asm"

ObjID_pow equ 32
ObjID_checkpoint equ 33
ObjID_bossmusic equ 34
* La bibliotheque d'ennemis que CE stage charge (ses lots — voir
* src/common/cast.const.asm et l'analyse des lots).
ObjID_patapata equ 35
ObjID_bink equ 36
ObjID_cancer equ 37
ObjID_bug equ 38
ObjID_pstaff equ 39
* Le champ d'etoiles du boss Compiler, arme par la WAVE comme dans l'arcade
* (variant 1 — la sequence gauche classique, le sens droite arcade est mis de
* cote). L'objet est ephemere : il passe le variant au module pagine et rend
* son slot (stage.starfieldSpawner).
ObjID_starfield equ 40

* cytron : l'ennemi mecanique qui rampe sur les parois et fait REPOUSSER le
* champ de gommes. Le stage en fait naitre 38, sur neuf variantes de script.
ObjID_cytron equ 41

* geld : le mangeur de gommes — l'exact contraire du cytron (13 spawns).
ObjID_geld equ 42

* compiler : le BOSS du stage 4. L'orchestrateur ne dessine rien — il
* engendre les trois parties, qui sont ce que l'on voit.
ObjID_compiler     equ 43
ObjID_compilerpart equ 44

ObjID_bugrender equ 49 ; le renderer des chaines de bug — meme valeur que
                       ; l'equ de bug.unit.asm (47 partout) ; 45..48 libres
objid.count equ 49
objid.animation equ ObjID_animation

* RunObjects scales an id with aslb+abx (id*2 in B, RunObjects.asm) : an id
* past 127 loses its top bit in the shift and indexes the wrong entry,
* silently. Ceiling for the whole co-loadable set, shared prefix included.
 IFGT objid.count-127
        ERROR object ids exceed the RunObjects ceiling (127)
 ENDC

 ENDC
