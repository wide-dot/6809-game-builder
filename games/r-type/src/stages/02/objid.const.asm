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
* Les segments d'outslay : la chaine en pose 22, le role voyageant par le
* subtype. L'emetteur (ObjID_outslay) est ce que la wave spawne ; lui seul
* apparait dans wave.asm.
* DEUX ids, et c'est Img_Page_Index qui l'impose : cette table donne UNE page
* d'imagesets par identifiant, or les 16 poses de tete/finalizer vivent dans
* leur propre direntry (stage2.cast.imgHead) faute de tenir dans les 16 Ko du
* cast. Le code est le meme des deux cotes (outslay.Segment) ; seule la page
* d'images differe.
ObjID_outslay_segment equ 38
ObjID_outslay_head equ 39
* Le porteur du rendu groupe des segments : un seul objet moteur pour les 20
* sprites du corps (schema du tailmgr du Dobkeratops).
ObjID_outslay_render equ 40
* Le projectile de la salve en etoile : art et boite DEDIES cote arcade
* (tick 95f1, recipes 1000:417e, AABB 1000:4196), pas le bullet commun.
ObjID_outslay_shot equ 41
* L'animation de decor comme objet : le boss en instancie une par ouverture
* de tube, elle vit sa duree et se rend. Voir common/fx/tilemapanim/obj.asm.
ObjID_tilemapanim equ 42
* Le gouger a HUIT identifiants : un par direction, et le double parce que
* chaque pose est coupee en deux moities dessinees par DEUX objets.
* Ce n'est pas un caprice. Img_Page_Index ne donne QU'UNE page d'images par
* identifiant, et les 46 demi-sprites 24x48 du gouger pesent plus de deux
* pages : chaque direction a donc son direntry et son id, et l'objet bascule
* sur celui de sa variante des l'init sans en changer — la variante est figee
* a la naissance (meme motif que la tete et la queue du serpent).
* La coupe en deux, elle, vient du moteur : BuildSprites rejette EN BLOC un
* sprite qui deborde de l'ecran, la ou l'arcade le decoupe. Le gouger attend a
* demi enterre dans la paroi, donc il debordait toujours et n'etait pas dessine
* du tout. Coupe, seule la moitie enfouie est rejetee. Le parent porte la
* moitie HAUTE, son enfant la BASSE ; ils partagent la meme position, l'ancre
* de chaque demi-image faisant le reste.
ObjID_gouger_tl equ 43
ObjID_gouger_tr equ 44
ObjID_gouger_bl equ 45
ObjID_gouger_br equ 46
ObjID_gouger_tl_b equ 47
ObjID_gouger_tr_b equ 48
ObjID_gouger_bl_b equ 49
ObjID_gouger_br_b equ 50

objid.count equ 50
objid.animation equ ObjID_animation

* RunObjects scales an id with aslb+abx (id*2 in B, RunObjects.asm) : an id
* past 127 loses its top bit in the shift and indexes the wrong entry,
* silently. Ceiling for the whole co-loadable set, shared prefix included.
 IFGT objid.count-127
        ERROR object ids exceed the RunObjects ceiling (127)
 ENDC

 ENDC
