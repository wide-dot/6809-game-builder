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
* Les 4 premiers blocs (27 o) doivent rester CONTIGUS et dans cet ordre :
* StarfieldInit les remet a zero en bloc.

starCurOff                  fdb   0,0,0        ; offset 8.8 courant, par plan (6 o)
starPrevOff                 fdb   0,0,0,0,0,0  ; offset du dernier trace [plan][buffer] (12 o)
                                               ; index = plan*4 + buffer*2
starCurLap                  fcb   0,0,0        ; tour courant, par plan (3 o) ; plan 0 : 0/1
starPrevLap                 fcb   0,0,0,0,0,0  ; tour du dernier trace [plan][buffer] (6 o)
                                               ; index = plan*2 + buffer
* -- fin du bloc remis a zero par StarfieldInit --
starBufOff                  fcb   0    ; 0 ou 2 selon gfxlock.backBuffer.id
starPlaneIdx                fcb   0    ; plan courant 0..2
starCurIdx                  fcb   0    ; index dans starCurOff  (= plan*2)
starPrevIdx                 fcb   0    ; index dans starPrevOff (= plan*4 + buffer*2)
starPrevLapIdx              fcb   0    ; index dans starPrevLap  (= plan*2 + buffer)
starLapDisp                 fdb   0    ; deplacement de tour passe a StarSetup
starOffInt                  fcb   0    ; partie entiere de l'offset du plan
starFrameCnt                fcb   0    ; compteur de la boucle frame-drop
starNoDraw                  fcb   0    ; !=0 : extinction en cours
starOffCnt                  fcb   0    ; rendus d'effacement pendant l'extinction
starDead                    fcb   0    ; !=0 : terminee, l'objet ne coute plus rien

* Les deux constantes de reglage, reprises telles quelles de la v1.
star_x_span                 equ   144  ; 8..151 inclus -> 144 colonnes
star_cam_max                equ   436  ; extinction quand l'entree du vaisseau
                                       ; touche le bord droit (reglage a l'oeil)
