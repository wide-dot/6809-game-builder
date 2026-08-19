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

* LES TROIS VARIABLES DU MISSILE ONT DEMENAGE (2026-08-06) : le missile est
* porte, il vit dans la page du cast et decompte le compteur que le joueur
* incremente. Elles sont donc dans la zone reservee `globals`, comme
* globals.missileUnlocked et la trainee — la lecon du paragraphe ci-dessus,
* appliquee le jour ou elle est devenue vraie.

* LA TRAINEE DU JOUEUR A DEMENAGE (2026-08-05) : elle est dans la zone reservee
* `globals`, decrite par variables.asm. Le force pod la lit depuis SA page, ou
* celle du joueur n'est pas montee — une etiquette de cette page-ci ne pouvait
* donc plus servir. Meme lecon que globals.missileUnlocked, deux paragraphes
* plus haut.
