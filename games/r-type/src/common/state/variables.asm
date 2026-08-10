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

 ENDC
