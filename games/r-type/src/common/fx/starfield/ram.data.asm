* ===========================================================================
* Les variables du champ d'etoiles — DANS SON UNITE, pas en RAM residente
* ===========================================================================
* La v1 les declarait dans le ram_data de son game mode, faute de mieux : son
* code d'objet vivait en page cartouche, donc en lecture seule pour lui.
*
* En v2 l'unite est chargee dans une page de RAM (region overlay), et elle est
* montee chaque fois que ses routines tournent — elle peut donc porter ses
* propres variables. C'est autant de RAM residente economisee, et la zone est
* comptee : entre le pool d'objets et les temoins il ne reste que 1 Ko.
*
* Valable parce que la page des overlays est chargee UNE FOIS au boot
* (scenes.boot) et jamais rechargee : les valeurs survivent aux echanges de
* stage, comme en RAM residente. Une unite rechargee par scene remettrait ces
* octets a leur valeur de disque a chaque chargement.
*
* OVERLAY : les tables d'effacement (offsets et tours par buffer) sont
* parties avec la passe ERASE — l'effaceur global fait leur travail.
* Les 2 premiers blocs (9 o) doivent rester CONTIGUS et dans cet ordre :
* StarfieldInit les remet a zero en bloc.

starCurOff                  fdb   0,0,0        ; offset 8.8 courant, par plan (6 o)
starCurLap                  fcb   0,0,0        ; tour courant, par plan (3 o) ; plan 0 : 0/1
* -- fin du bloc remis a zero par StarfieldInit --
starPlaneIdx                fcb   0    ; plan courant 0..2
starCurIdx                  fcb   0    ; index dans starCurOff  (= plan*2)
starLapDisp                 fdb   0    ; deplacement de tour passe a StarSetup
starOffInt                  fcb   0    ; partie entiere de l'offset du plan
starFrameCnt                fcb   0    ; compteur de la boucle frame-drop
starDead                    fcb   1    ; !=0 : terminee, l'objet ne coute plus rien.
                                       ; NE MORT : c'est la wave qui le fait naitre
                                       ; (ObjID_starfield -> StarfieldInit), et une
                                       ; entree de stage sans etoiles ne doit rien
                                       ; dessiner — meme au tout premier boot.

* L'horloge de vie et le fondu de sortie (modele arcade, cf. obj.asm).
starLifetime                fdb   0    ; trames de jeu restantes ; 0 = terme
starFade                    fcb   0    ; !=0 : fondu en cours, compte en RENDUS
starPalier                  fcb   0    ; dernier palier de fondu atteint (0..3)
starTblPal                  fcb   0    ; le palier que planeTable porte
starApplyLvl                fcb   0    ; scratch de StarMasksApply (palier vise)
starApplyPl                 fcb   0    ; scratch de StarMasksApply (plans restants)

* La constante de reglage, reprise telle quelle de la v1. (star_cam_max, le
* mur camera regle a l'oeil, est retire : la duree du variant — armee par la
* wave comme dans l'arcade — donne le meme point de coupe.)
star_x_span                 equ   144  ; 8..151 inclus -> 144 colonnes
