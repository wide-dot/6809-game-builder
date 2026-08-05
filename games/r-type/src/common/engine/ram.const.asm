* Garde d'inclusion : un membre de pageset porte plusieurs units qui
* incluent chacun cet en-tete. Un en-tete doit pouvoir etre inclus deux
* fois — c'est vrai independamment du pageset.
 IFNDEF RTYPE_RAM_CONST
RTYPE_RAM_CONST equ 1

* ===========================================================================
* Object pool geometry and resident RAM — frozen for the whole game
* ===========================================================================
* Lane 4 of the stage boundary : these equates are baked into the engine when
* it is assembled, and the engine is assembled once. Every stage therefore
* shares them, which is the decision recorded in the boundary analysis — v1
* already used the same values in all its game modes.
*
* Everything is an equate, never a fill : a v2 unit is relocatable, its first
* byte is its entry point, and reserving space with fill would both push the
* entry point away from offset zero and leave the tables wherever the linker
* happened to put the code.

* Les pas de moveByScript, dans l'echelle de la v1 (global/scale.asm) : un
* pixel horizontal vaut 0,375 et un vertical 0,75 dans le repere du jeu.
moveByScript.NEGXSTEP        equ -$0060
moveByScript.POSXSTEP        equ  $0060
moveByScript.NEGYSTEP        equ -$00C0
moveByScript.POSYSTEP        equ  $00C0

nb_dynamic_objects           equ 50
nb_graphical_objects         equ 64
ext_variables_size           equ 20  ; per dynamic object

* The dynamic object pool, in resident RAM above the stage region. La geometrie
* est celle de la v1 pour le niveau 1 (game-mode/01/ram_data.asm) :
* nb_dynamic_objects = 50, nb_graphical_objects = 64. object_size vaut 117, donc
* le pool prend $16DA octets. Le second n'est pas gratuit — il dimensionne les
* tables sous-objets et les listes « unset » des buffers de priorite, soit
* 8 x nb_graphical_objects, +256 octets au moteur — mais 50 objets dont 32
* seulement peuvent etre dessines n'aurait pas de sens.
* Le pool remonte jusqu'au bloc `globals` : entre lui et les globales,
* il n'y a plus que l'OST statique du fondu. C'est le trou libre de 1 547 octets
* qui trainait entre les deux, absorbe.
* L'ANCRE, et le piege qu'elle porte : cette valeur DOIT etre l'adresse du bloc
* reserve `globals` du layout (to8.config.xml) et de GLOBAL_VARIABLES
* (state/variables.asm). Rien ne verifie l'accord — le layout decrit la RAM au
* builder, ces equates la decrivent a l'assembleur, et les deux se croient.
* Vecu le 2026-08-05 : le bloc globals a recule de $40 pour loger la trainee du
* joueur, l'ancre est restee a $9E80, et les OST statiques ont recouvert la
* trainee sans un mot. Les trois valeurs bougent ENSEMBLE.
GLOBALS_BASE                 equ $9E40
Dynamic_Object_RAM_End       equ GLOBALS_BASE-nb_static_objects*object_size
Dynamic_Object_RAM           equ Dynamic_Object_RAM_End-nb_dynamic_objects*object_size

* Les OST HORS POOL : des objets uniques, vivants pour toute la partie, que le
* jeu lance par _Obj_RunU avec l'adresse de leur OST. Ils ne passent pas par
* l'allocateur — la v1 les declarait de meme dans le ram_data de son game mode.
* Ils vivent juste au-dessus du pool, sous les temoins du banc en $9C00.
* Les QUATRE OST statiques de la v1 (game-mode/01/ram_data.asm), dans son ordre
* et contigus. Trois d'entre eux attendent encore leur objet — le force pod et
* les deux bit devices ne sont pas portes — mais leur PLACE est reservee des
* maintenant : c'est elle qui fige la carte de la page residente, et la reserver
* apres coup obligerait a re-decouper regions et pool.
*
* NE PAS RETAILLER un seul de ces emplacements : la v1 le dit en toutes lettres
* pour le fondu, qui ecrit o_fade_curwait au-dela de ce qu'un OST trimme
* couvrirait, et deborderait alors sur son voisin.
*
* La v1 les amorce a leur routine Dormant dans Level01_Start puis au
* rechargement de checkpoint ; ces deux gestes viendront avec les objets.
nb_static_objects            equ 4

palettefade                  equ Dynamic_Object_RAM_End
forcepodOST                  equ palettefade+object_size
bitdevTopOST                 equ forcepodOST+object_size
bitdevBotOST                 equ bitdevTopOST+object_size

* L'OST DU JOUEUR vit en PAGE DIRECTE, pas dans le pool : le joueur tourne a
* chaque trame et ses champs sont lus sans arret, donc la v1 lui donnait
* l'espace utilisateur de la page directe (149 o pour un OST de 117).
player1                      equ dp

* L'etat de la boucle de stage : RUNNING tourne le jeu, DEAD deroule la mort
* (le joueur y bascule a la fin de son explosion), CHECKPOINT recharge. Des
* CONSTANTES partagees a l'assemblage ; la variable, elle, vit dans le stage
* et traverse le lien (le joueur l'ecrit en EXTERNAL).
mainloop.state.RUNNING       equ   0
mainloop.state.DEAD          equ   2
mainloop.state.CHECKPOINT    equ   4

 ENDC
