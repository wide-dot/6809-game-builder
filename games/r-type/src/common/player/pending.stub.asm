* ===========================================================================
* L'etat d'armement, en bouchon
* ===========================================================================
* Le joueur remet a zero l'etat du gestionnaire de missiles a son Init. Ces
* variables appartiennent au missile, qui n'est pas porte : elles vivent ici en
* attendant, dans la page du joueur, et disparaitront avec lui.
*
* Rien ne les lit d'autre que le joueur aujourd'hui — les remettre a zero est
* donc sans effet observable, mais garde le code du joueur FIDELE a la v1 :
* aucun site d'appel n'est neutralise ici, contrairement au son.
*
* CE QUI N'EST PLUS ICI : globals.missileUnlocked et globals.backgroundSolid.
* Ce sont des variables INTER-MAIN, et leur maison est la zone reservee
* `globals` que variables.asm decrit — la v1 les y met deja. Elles etaient des
* etiquettes de CETTE page tant que le joueur etait seul a les lire ; le tir
* ennemi lit backgroundSolid depuis SA page, et deux etiquettes dans deux pages
* ne sont pas la meme variable.

missilePairCount             fcb   0
missileTgtTop                fdb   0
missileTgtBot                fdb   0

* La trainee du joueur : 32 positions (x,y) que le force pod relit avec du
* retard pour le suivre. Elle vit dans la page du joueur, comme les variables
* du champ d'etoiles vivent dans la sienne — la RAM residente est comptee.
player_pos_ring_buffer_ptr   fdb   player_pos_ring_buffer
player_pos_ring_buffer       fill  0,4*32
