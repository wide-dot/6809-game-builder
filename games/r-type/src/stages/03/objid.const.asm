* Object ids of stage 3 : the shared prefix, then the stage's own.
* Hand-maintained since the <objectindex> retirement (2026-08-11) — the dev
* owns the numbering, the builder places, links and bakes.

 IFNDEF OBJID_CONST_03
OBJID_CONST_03 equ 1

        INCLUDE "src/common/objid-common.const.asm"

ObjID_pow equ 32
ObjID_checkpoint equ 33
ObjID_bossmusic equ 34
* La bibliotheque d'ennemis que CE stage charge (ses lots — voir
* src/common/cast.const.asm et l'analyse des lots).
ObjID_patapata equ 35
ObjID_bink equ 36
* Le pilote de la couche battleship (warship/pilot.asm) — instancie par la
* wave comme en arcade (create_warship 0xc46e).
ObjID_warship_core equ 37
* Les tourelles autonomes de la coque : un seul objet, trois montages portes
* par le sous-type (haut, bas, grosse). Le script de spawn les fait naitre.
ObjID_warship_turret equ 38
* Les cinq assets de la couche mscroll : PAS des objets (jamais lances) —
* des entrees d'index que mscroll.setup resout en pages/adresses, le
* patron du banc examples/mscroll.
objid.bship.map    equ 39
objid.bship.tilesA equ 40
objid.bship.tilesB equ 41
objid.bship.bufA   equ 42
objid.bship.bufB   equ 43

objid.count equ 43
objid.animation equ ObjID_animation

* GARDE-FOU (26/08/2026). Les cinq entrees bship ne sont pas des objets, mais
* elles occupent des LIGNES d'index comme eux : elles doivent suivre le dernier
* identifiant d'objet sans trou ni recouvrement, et la derniere doit etre
* objid.count. Le redecoupage des identifiants (commun 0..31) a decale les
* ObjID_ et pas celles-ci : bship.map est tombe sur ObjID_bink, les cinq assets
* de la couche battleship ont ete resolus sur les mauvaises pages et le stage 3
* s'est fige au chargement, ecran noir. Le controle de densite des tables ne
* pouvait pas le voir — les longueurs restaient justes.
 IFNE objid.bship.map-(ObjID_warship_turret+1)
        ERROR les cinq entrees bship doivent suivre le dernier objet, sans trou
 ENDC
 IFNE objid.count-objid.bship.bufB
        ERROR objid.count doit designer la derniere entree d'index (bship.bufB)
 ENDC

* RunObjects scales an id with aslb+abx (id*2 in B, RunObjects.asm) : an id
* past 127 loses its top bit in the shift and indexes the wrong entry,
* silently. Ceiling for the whole co-loadable set, shared prefix included.
 IFGT objid.count-127
        ERROR object ids exceed the RunObjects ceiling (127)
 ENDC

 ENDC
