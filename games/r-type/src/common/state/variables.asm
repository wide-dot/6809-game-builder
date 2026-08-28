 IFNDEF GLOBAL_VARIABLES

; V2-DEVIATION: l'ancre passe de $9E84 a $9E80. En v1 elle etait DERIVEE — le
; premier octet libre apres un main qui finissait en $9E80 — donc elle n'avait
; pas de valeur propre. En v2 le contenu resident s'arrete bien plus bas et
; l'ancre est un choix de layout : $9E80 donne un bloc reserve de $80 pile, et
; il se retient. Les temoins du banc partagent ce bloc (bench.const.asm).
GLOBAL_VARIABLES         equ $9DCB ; ancre du bloc reserve `globals` ($9DCB-$9E5E)
                                   ; = GLOBALS_BASE (ram.const.asm) = layout —
                                   ; les trois bougent ENSEMBLE (2026-08-10 :
                                   ; -117 pour agrandir la pile, pool 45 -> 44)
globals.nextGameMode     equ GLOBAL_VARIABLES+0 ; 1 byte
globals.score            equ GLOBAL_VARIABLES+1 ; 3 bytes (24-bit, unit=100pts, MSB first; cap 99999=$01869F)
globals.lives            equ GLOBAL_VARIABLES+4 ; 1 byte
globals.backgroundSolid  equ GLOBAL_VARIABLES+5 ; 1 byte
globals.difficulty       equ GLOBAL_VARIABLES+6 ; 1 byte
globals.lifeUpIdx        equ GLOBAL_VARIABLES+7 ; 1 byte
globals.bossDefeated     equ GLOBAL_VARIABLES+8 ; 1 byte
globals.stageScoreBase   equ GLOBAL_VARIABLES+9 ; 3 bytes (score at stage start)
; --- arme missile joueur : STATUT D'ARME persistant (doit survivre au changement de stage) ---
globals.missileUnlocked  equ GLOBAL_VARIABLES+12 ; 1 byte (1 = missile débloqué par le bonus)

* LA TRAINEE DU JOUEUR : 32 positions (x,y) sur 4 octets, que le force pod
* relit avec 30 trames de retard pour le suivre en revenant au vaisseau.
*
* Elle vivait dans la page du JOUEUR tant qu'il etait seul a la lire. Le force
* pod vit dans SA page : quand il tourne, celle du joueur n'est pas montee, et
* deux etiquettes dans deux pages ne sont pas la meme variable — exactement ce
* que globals.missileUnlocked a deja enseigne. Elle rejoint donc la zone
* reservee, ou la v1 la met aussi (ram_data.asm du game mode).
*
* PIEGE : la v1 initialise le pointeur DEPUIS SON BINAIRE (`fdb
* player_pos_ring_buffer`). Un bloc <reserved> n'est ni charge ni mis a zero :
* le corps commun du stage doit le semer a l'ouverture, comme il seme les OST
* statiques. Cf. docs/lang/en/migration/reserved-ram-is-not-zeroed.md
player_pos_ring_buffer     equ GLOBAL_VARIABLES+13  ; 4*32 = 128 octets
player_pos_ring_buffer_ptr equ GLOBAL_VARIABLES+141 ; 2 octets

* L'etat du gestionnaire de missiles. Il vivait dans la page du JOUEUR, seul a
* le lire — et la note d'a cote disait de le ranger dans la RAM du stage. Les
* deux sont perimees depuis que le missile est porte : il est COMMUN (page du
* cast, partagee par tous les stages) et il decompte le meme compteur que le
* joueur incremente. Deux etiquettes dans deux pages ne sont pas la meme
* variable — meme lecon que globals.missileUnlocked et la trainee du joueur.
*
* Le bloc reserve n'est ni charge ni mis a zero : c'est l'Init du joueur qui
* seme les trois, comme la v1 (player1.asm).
missilePairCount           equ GLOBAL_VARIABLES+143 ; 1 octet, missiles vivants
missileTgtTop              equ GLOBAL_VARIABLES+144 ; 2 octets, OST cible du haut
missileTgtBot              equ GLOBAL_VARIABLES+146 ; 2 octets, OST cible du bas

* LE CROCHET DE COUCHE DESTRUCTIBLE (24/08/2026).
*
* Un stage peut porter une couche de decor que les tirs du joueur DETRUISENT —
* le champ de gommes du stage 4 aujourd'hui. Le code d'arme, lui, est COMMUN :
* il est charge une fois au boot et sert les huit stages, donc il ne peut pas
* referencer un symbole qui n'existe que sur l'un d'eux (le lien se resoudrait
* a zero sur les sept autres, et le premier tir sauterait dans le vide).
*
* D'ou ce vecteur : le corps commun du stage le pose sur le neutre, le stage
* qui a une couche destructible le pointe sur LE SIEN. Il designe une table de
* deux `jmp`, a la maniere de terrainCollision.unit :
*
*   +0  EFFACER    [x] = x de carte, [b] = ligne ecran
*                  rend Z=0 si quelque chose a ete detruit.
*                  `jsr [stage.gum.hook]` tombe dessus tel quel.
*   +3  CHERCHER   le senseur terrainCollision est deja pose par l'appelant
*                  rend D = le x de carte de la premiere cellule destructible
*                  a DROITE du senseur, 0 si aucune.
*                  `ldx stage.gum.hook / jsr 3,x`
*   +6  RECTANGLE  [x] = le coin haut-gauche du bloc au DEPART (x de carte),
*                  [y] = le meme x a l'ARRIVEE,
*                  [b] = la ligne ecran du haut,
*                  [a] = la taille du bloc, quartet HAUT = largeur, BAS =
*                        hauteur, en cellules ($12 = le beam, $44 = le pod).
*                  Efface la surface BALAYEE par le bloc entre les deux points.
*                  Les bords sont rabotes au champ, pas refuses.
*                  Pour une arme qui CREUSE au lieu de mourir sur la premiere
*                  cellule. Le depart et l'arrivee sont ce qui rend la
*                  compensation de trames gratuite : la reunion des passes
*                  d'une trame est un seul rectangle, quel qu'en soit le
*                  nombre.
*
* POURQUOI DEUX ENTREES (25/08/2026). Sonder a la position courante une fois
* par trame ne marche pas a bas regime : le tir simple avance de 6*frameDrop
* d'un coup — 24 px a 12 img/s, huit cellules — donc il enjambe des gommes et
* mange celle sur laquelle il retombe, loin devant son sprite d'impact. La
* recherche resout ca comme le mur l'est deja depuis la v1 : UN balayage a la
* naissance donne le point d'arrivee au pixel, et il ne depend plus du regime.
stage.gum.hook             equ GLOBAL_VARIABLES+148 ; 2 octets, vecteur

* L'ARMEMENT DU JOUEUR — CE QUE LA PARTIE POSSEDE (25/08/2026).
*
* Ces cinq octets vivaient dans `player1+ext_variables`, donc dans la PAGE
* DIRECTE — et la page directe est balayee DEUX FOIS a chaque entree de stage
* (InitGlobals, puis ObjectDp_Clear via checkpoint.load). Le joueur perdait
* donc pod, bits, vitesse et missiles en passant d'un niveau au suivant, alors
* que la borne les conserve : la seule chose qu'on y perd, c'est en mourant.
*
* Ils rejoignent le bloc reserve pour la meme raison que
* globals.missileUnlocked juste au-dessus, dont le commentaire disait deja
* « STATUT D'ARME persistant (doit survivre au changement de stage) » — les
* quatre autres n'avaient simplement jamais suivi. Une seule copie de la
* verite, et plus aucun effaceur ne passe dessus.
*
* CE QUI RESTE DANS L'OST DU JOUEUR : beam_value (la charge se perd, comme en
* arcade), forcepod_attached et forcepod_mount_side — de l'etat COURANT du
* pod, pas de la propriete. Comme sur la borne, le pod reste ou il est pendant
* la sequence de fin ; c'est l'entree du stage suivant qui le remet accroche
* (decision auteur, 25/08/2026 : un rappel avait ete essaye, il rendait mal a
* l'ecran). Accroche, sa position se rederive du vaisseau a chaque trame — il
* n'y a donc rien a conserver de son etat courant.
*
* LE BLOC RESERVE N'EST NI CHARGE NI MIS A ZERO : c'est le semis de partie
* fraiche qui les efface, et la mort qui les reprend — voir
* checkpoint.armament dans src/common/flow/checkpoint.unit.asm : c'est
* checkpoint.reload — la porte de la MORT — qui les reprend, la ou
* checkpoint.load, l'ouverture d'un stage, les rend.
globals.forcepodlevel      equ GLOBAL_VARIABLES+150 ; 1 octet, 0 a 3 (0 = pas de pod)
globals.forcepodtype       equ GLOBAL_VARIABLES+151 ; 1 octet, = player_one_laser_type arcade
globals.bitdevice          equ GLOBAL_VARIABLES+152 ; 1 octet, nombre de bit devices (0, 1 ou 2)
globals.speedlevel         equ GLOBAL_VARIABLES+153 ; 2 octets, offset dans la table speed.preset

* LE PLAN DE FOND EST-IL DU SOL POUR LES ENNEMIS TERRESTRES ? (27/08/2026)
*
* A ne pas confondre avec globals.backgroundSolid, qui dit « les ARMES et le
* vaisseau doivent tester le second plan ». Les deux ne se recouvrent pas :
* le stage 1 arme backgroundSolid des son init, mais son plan de fond porte la
* SILHOUETTE DU BOSS — un cancer qui marcherait dessus aurait un comportement
* faux, et le test coûterait une sonde par direction et par trame pendant tout
* le niveau pour rien (releve auteur).
*
* Ce drapeau-ci ne concerne que les ennemis qui MARCHENT ou RAMPENT sur le
* decor (cancer, pow). Il n'est arme que la ou le plan de fond est vraiment du
* sol : le stage 4, dont le plan 0 est le champ de gommes. En arcade la
* question ne se pose pas — une gomme y EST une tuile d'avant-plan, et
* run_cancer comme run_pow_armor ne sondent QUE l'avant-plan
* (probe_foreground_tile, seuil 0xDFC : verifie au desassemblage 0x40:8A3A et
* 0x40:5791). C'est notre rangement en deux plans qui demande ce second test,
* donc c'est a nous de dire ou il a un sens.
globals.foeBgSolid         equ GLOBAL_VARIABLES+155 ; 1 octet, 0 = fond ignore

* LE FOND EST-IL UN SIMPLE NOIR ? (28/08/2026)
*
* Pose quand le champ d'etoiles prend l'ecran — la phase de boss. Le decor
* n'est alors plus visible : ni tuiles, ni champ de gommes, juste le noir et
* les etoiles, exactement comme le stage 1 pendant Dobkeratops.
*
* Ce que ca change dans la trame du stage 4 : l'effacement passe de pscroll
* (feed des bandes + blast du ruban, le poste le plus lourd du stage) au
* stack-blast commun playfield.clearBlast que sept stages sur huit utilisent
* deja ; et DrawTiles ne tourne plus. Le combat de boss est justement le
* moment ou l'on veut de la marge machine.
*
* Le plan de collision des gommes est coupe du meme geste
* (terrainCollision.planeOff) : le champ n'est plus a l'ecran, ses collisions
* n'ont plus de sens et sa lecture est du temps perdu.
globals.plainBackdrop      equ GLOBAL_VARIABLES+156 ; 1 octet, 0 = decor normal

* COMBIEN DE PIECES DU COMPILER SONT TOMBEES (29/08/2026)
*
* La borne fait porter ce compte a l'orchestrateur : chaque piece lui signale
* sa mort par un bit (droite 1, bas 2, gauche 4) et le moniteur de combat
* declenche la fin quand les trois sont la. Chez nous les pieces vivent dans
* des slots du pool sans renvoi vers leur parent : le compte passe par une
* globale, remise a zero a l'entree du stage comme tout le reste.
globals.compilerDead       equ GLOBAL_VARIABLES+157 ; 1 octet, 0..3
globals.ARMAMENT_SIZE      equ 5                    ; ce que checkpoint.armament efface

 ENDC
