* Object ids of stage 5 : the shared prefix, then the stage's own.
* Hand-maintained since the <objectindex> retirement (2026-08-11) — the dev
* owns the numbering, the builder places, links and bakes.

 IFNDEF OBJID_CONST_05
OBJID_CONST_05 equ 1

        INCLUDE "src/common/objid-common.const.asm"

ObjID_pow equ 30
ObjID_checkpoint equ 31
ObjID_bossmusic equ 32
* La bibliotheque d'ennemis que CE stage charge (ses lots — voir
* src/common/cast.const.asm et l'analyse des lots).
ObjID_cancer equ 33
ObjID_mid equ 34
* Le serpent du stage 5. QUATRE identifiants pour un ennemi :
*  - le MAITRE, qui interprete le script et ne dessine rien ;
*  - la TETE et la QUEUE, suiveurs a OST — leurs imagesets vivent dans
*    D'AUTRES direntries (stage5.cast.imgHead, stage5.cast.imgTail), et
*    `Img_Page_Index` ne donne qu'UNE page par identifiant : un objet
*    reparti sur plusieurs direntries en veut un par page (meme decoupe que
*    ObjID_outslay_segment / ObjID_outslay_head) ;
*  - le RENDERER GROUPE, qui dessine les quinze slots publies en un seul
*    preambule BuildSprites.
ObjID_slither equ 35
ObjID_slither_head equ 36
ObjID_slither_tail equ 37
ObjID_slither_render equ 38

objid.count equ 38
objid.animation equ ObjID_animation

* RunObjects scales an id with aslb+abx (id*2 in B, RunObjects.asm) : an id
* past 127 loses its top bit in the shift and indexes the wrong entry,
* silently. Ceiling for the whole co-loadable set, shared prefix included.
 IFGT objid.count-127
        ERROR object ids exceed the RunObjects ceiling (127)
 ENDC

 ENDC
