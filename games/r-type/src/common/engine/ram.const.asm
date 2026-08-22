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

; 46, et non les 50 de la v1 : le stage 1 porte le sequencement du boss (2),
; la sequence de fin (1) et la lib log residente (1) — voir les commits. Ce qui
; DOIT etre resident (cinq objets pagines l'appellent, et la fenetre cartouche
; ne monte qu'une page a la fois). La RAM residente de la page 1 est saturee —
; le moteur n'avait pas la marge — donc les octets sortent du
; pool. TROIS valeurs bougent ensemble et rien ne verifie leur accord :
; ce nombre, <reserved name="objects.pool"> et <region name="stage"> du layout.
;
; 46 -> 45 (banc d'echange) : le 46e slot rend ses 117 octets, dont 16 logent
; les temoins du banc (bench.const.asm, <reserved name="bench"> a $8766). La
; page 1 n'a pas un octet libre par construction — le bloc `globals` est plein
; a +147 et au-dessus c'est la pile — donc les temoins EMPRUNTENT un slot
; d'objet, rendu quand le banc partira. Le banc ne cree qu'une dizaine
; d'objets, la marge reste large.
;
; 44 -> 43 (2026-08-19, decision auteur) : le title a grossi d'un octet et son
; dernier octet — l'entree 15 de Pal_loading — atterrissait SUR bench.magic
; ($8766) : entree 15 bleue a l'ecran LOADING, en silence, jusqu'a ce que la
; garde <reserved> du builder le refuse. Le pool rend un slot : sa base monte
; a $8850, bench ($87DB) et cast ($87EB) remontent d'autant, et les unites
; title/stage disposent de $8000-$87DA (+117 octets).
;
; 43 -> 60 ET DEMENAGEMENT (2026-08-20, decision auteur) : depuis l'overlay,
; la demi-page 0 ($4000-$5FFF) n'a plus de cellules de fond — c'est de la RAM
; stable (PRC bit 0 epingle par _gfxlock.init sous OverlayMode, il ne suit
; plus la parite buffer : sans ca le pool n'existerait qu'une trame sur
; deux). Le pool ET les quatre OST statiques y demenagent : 60 slots
; dynamiques + fondu + les 3 slots d'armement (64 x 117 = $1D40, 704 octets
; de marge dans la demi-page). La page 1 rend $8850-$9DCA (~5,5 Ko) — la
; place du mscroll resident (stage 3) et de la zone par-stage. Les ancres
; qui bougent ENSEMBLE : ces equates, <reserved name="objects.*"> du
; config (passes en page $00) et l'ex <reserved name="background.save">
; retire.
nb_dynamic_objects           equ 60
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
* 2026-08-10 : $9E40 -> $9DCB (-117). La pile de 28 octets debordait : la
* chaine de mort d'un objet (RemoveAABB/DeleteObject/UnloadObject) sous IRQ
* plongeait sous $9ED4 et ecrasait player_pos_ring_buffer_ptr — premier octet
* sous le plancher — d'ou la trainee desalignee qui labourait la page directe
* puis la fenetre cartouche (gel au 2e passage du stage 1). Le pool rend un
* objet (nb_dynamic_objects 45 -> 44) : sa BASE ne bouge pas ($87DB), tout le
* haut descend de 117 et la pile passe a 145 octets ($9E5F-$9EF0).
* 2026-08-15 : profondeur MESUREE sous toje (sentinelle $55 sous S, campagne
* complete : morts, rechargements de checkpoint, game over, sequences de fin,
* stages 1..8) : 84 octets au pic. Le debordement de 28 etait donc reel, pas
* un bug annexe ; et les 145 gardent ~60 octets de marge — a re-mesurer quand
* les casts d'ennemis reels (chaines RunPgSubRoutine plus profondes) seront
* branches, avant d'envisager de rendre le pas de 117 au pool.
GLOBALS_BASE                 equ $9DCB
; Le pool vit dans la demi-page 0, ancre en $4000 et croissant — il ne derive
; plus de GLOBALS_BASE (2026-08-20, voir le recit au-dessus). GLOBALS_BASE ne
; borne plus que les globales/pile de la page 1.
Dynamic_Object_RAM           equ $4000
Dynamic_Object_RAM_End       equ Dynamic_Object_RAM+nb_dynamic_objects*object_size

* Les OST HORS POOL : des objets uniques, vivants pour toute la partie, que le
* jeu lance par _Obj_RunU avec l'adresse de leur OST. Ils ne passent pas par
* l'allocateur — la v1 les declarait de meme dans le ram_data de son game mode.
* Ils suivent le pool dans la demi-page 0 (fondu puis les 3 slots d'armement).
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
