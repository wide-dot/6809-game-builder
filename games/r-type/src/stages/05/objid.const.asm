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
* Le CADAVRE d'un corps : ne du chapelet d'explosion (40:7b85), il part sur
* un des deux scripts de vol libre et n'appartient plus a la chaine. C'est un
* objet a OST parce qu'il lui faut un interprete moveByScript a lui ; ses
* images sont celles du CORPS, donc sur la page du cast.
ObjID_slither_corpse equ 39
* Le cadavre de la QUEUE : meme code, mais ses images sont celles de la queue,
* donc sur imgTail et pas sur la page du cast — d'ou un identifiant a lui,
* Img_Page_Index n'en donnant qu'UNE par identifiant.
ObjID_slither_tail_corpse equ 40
* La TETE PENDANT SON FLASH DE COUP. Meme code, meme objet — seules ses
* images changent, et elles vivent sur une autre page. Img_Page_Index n'en
* donnant qu'UNE par identifiant, l'objet BASCULE d'identifiant le temps
* d'une trame. Meme motif que le cadavre de la queue ci-dessus.
ObjID_slither_head_hit equ 41
* Et la QUEUE pendant son flash, pour la meme raison.
ObjID_slither_tail_hit equ 42
* Le SECOND renderer groupe : meme boucle, meme instance, mais il ne dessine
* que les slots MARQUES et sa page d'images est celle des poses blanches du
* corps. Un renderer ne montant qu'une page, il en faut deux.
ObjID_slither_render_hit equ 43

objid.count equ 43
objid.animation equ ObjID_animation

* RunObjects scales an id with aslb+abx (id*2 in B, RunObjects.asm) : an id
* past 127 loses its top bit in the shift and indexes the wrong entry,
* silently. Ceiling for the whole co-loadable set, shared prefix included.
 IFGT objid.count-127
        ERROR object ids exceed the RunObjects ceiling (127)
 ENDC

 ENDC
