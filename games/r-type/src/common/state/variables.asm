 IFNDEF GLOBAL_VARIABLES

; V2-DEVIATION: l'ancre passe de $9E84 a $9E80. En v1 elle etait DERIVEE — le
; premier octet libre apres un main qui finissait en $9E80 — donc elle n'avait
; pas de valeur propre. En v2 le contenu resident s'arrete bien plus bas et
; l'ancre est un choix de layout : $9E80 donne un bloc reserve de $80 pile, et
; il se retient. Les temoins du banc partagent ce bloc (bench.const.asm).
GLOBAL_VARIABLES         equ $9E80 ; ancre du bloc reserve `globals` ($9E80-$9EFF)
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
; NB : missilePairCount / missileTgtTop / missileTgtBot = état TRANSITOIRE in-stage
;      -> déclarés dans game-mode/<n>/ram_data.asm (fcb/fdb), PAS ici.

 ENDC
