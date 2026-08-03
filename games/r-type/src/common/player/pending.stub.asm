* ===========================================================================
* L'etat d'armement, en bouchon
* ===========================================================================
* Le joueur remet a zero l'etat du gestionnaire de missiles a son Init, et lit
* le verrou du bonus. Ces variables appartiennent a la chaine de tir, qui n'est
* pas portee : elles vivent ici en attendant, dans la page du joueur, et
* disparaitront quand src/common/weapons arrivera.
*
* Rien ne les lit d'autre que le joueur aujourd'hui — les remettre a zero est
* donc sans effet observable, mais garde le code du joueur FIDELE a la v1 :
* aucun site d'appel n'est neutralise ici, contrairement au son.

missilePairCount             fcb   0
missileTgtTop                fdb   0
missileTgtBot                fdb   0
globals.missileUnlocked      fcb   0

* L'arriere-plan solide : le tir et le missile le testent pour savoir si le
* decor de fond arrete les projectiles. Le stage ne le pose pas encore.
globals.backgroundSolid      fcb   0

* La trainee du joueur : 32 positions (x,y) que le force pod relit avec du
* retard pour le suivre. Elle vit dans la page du joueur, comme les variables
* du champ d'etoiles vivent dans la sienne — la RAM residente est comptee.
player_pos_ring_buffer_ptr   fdb   player_pos_ring_buffer
player_pos_ring_buffer       fill  0,4*32
