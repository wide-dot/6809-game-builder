;*******************************************************************************
; La séquence de fin générique — le contrat partagé
;
; Les commandes, statuts et réglages du protocole de fin de niveau, tels que
; le stage 1 les a établis (timestamps.const.asm) : les stages 2-8 parlent le
; même protocole à l'objet commun endlevel. Le stage 1 garde son fichier —
; ses valeurs sont la chronologie arcade du Dobkeratops, celles-ci sont le
; réglage du combat de substitution.
;
; Gardé par IFNDEF : inclus par le main du stage ET par l'unité endlevel.
;*******************************************************************************
 IFNDEF ENDLEVEL_CONST
ENDLEVEL_CONST equ 1

; les commandes et statuts de l'objet (protocole du stage 1)
endstage.TICK          equ 0         ; command: run the end of stage tick
endstage.INIT          equ 1         ; command: reset the sequence state
endstage.BLIT          equ 2         ; command: in-lock blits (pixel fade)
endstage.STATUS_NONE   equ 0         ; status: nothing to do
endstage.STATUS_JINGLE equ 1         ; status: main must start the clear jingle
endstage.STATUS_DONE   equ 2         ; status: the level is over, main hands over

; la chronologie de la sequence (memes valeurs que le stage 1)
endstage.DURATION equ $C0            ; arcade: run_dobkeratops arms +0x22 = $C0 frames
endstage.JINGLE   equ $10            ; jingle + autopilote a T-$10 du compte a rebours
; ---------------------------------------------------------------------------
; LE POINT DE RALLIEMENT DE L'AUTOPILOTE — releve arcade (21/08/2026)
;
; L'autopilote arcade vit dans run_player_one (0x40:2027) : quand
; end_level_sequence_flag (0x2FC1) est non nul, EndLevelAutoPilot (0x40:208c)
; choisit une cible et tire le vaisseau vers elle. La cible depend de la
; VALEUR du drapeau : `INC DL / JZ` — 0xFF garde (X=0x200, Y=0xE0), toute
; autre valeur non nulle prend (X=0x190, Y=0x100).
;
; Les onze ecritures immediates du drapeau, relevees par balayage d'octets du
; binaire maincpu (les xrefs Ghidra en manquent — 0x40:B970 n'y figure pas) :
;
;   stage  boss           site arcade              valeur   cible arcade
;   -----  -------------  -----------------------  ------   ------------
;     1    Dobkeratops    0x40:9ADE                 0xFF    X=$200 Y=$E0
;     2    Gomander       0x40:A440 (timeout)       0xFF    X=$200 Y=$E0
;     2    Gomander       0x40:A545 (mort)          0xFF    X=$200 Y=$E0
;     3    Warship        0x40:C5B4                 0xFF    X=$200 Y=$E0
;     4    Compiler       0x40:A9D9                 0xFF    X=$200 Y=$E0
;     5    Bellmite       0x40:B42F                 0xFF    X=$200 Y=$E0
;     6    Dop swarm      0x40:B1C2                 0xFF    X=$200 Y=$E0
;     7    Bronco         0x40:B970                 0xFF    X=$200 Y=$E0
;     8    Bydo core      0x40:C21C                 0x0F    X=$190 Y=$100  <- fin du jeu
;
; (les deux dernieres ecritures immediates, 0x40:1F1B et 0x40:200F, valent 0 :
; ce sont des remises a zero, comme celle de l'init de stage en 0x40:0FE3.)
;
; LE STAGE 8 EST LE SEUL A DIFFERER, ET C'EST VOULU. Ce n'est pas le meme
; evenement : les stages 1 a 7 s'ACHEVENT (jingle, releve de score, stage
; suivant), le stage 8 TERMINE LE JEU. Le bydo core ne rend pas la main a un
; stage cleared mais a la sequence de fin — l'annotation du unload en
; 0x40:C280 le dit : « Bydo's own ObjectRecord unloads -> Stage 8 ending
; sequence takes over ». Le vaisseau n'est donc pas rallie au centre pour un
; releve de score, il est place pour la scene finale : plus a gauche et plus
; haut, ce qui degage le centre et le bas du champ.
;
; La valeur 0x0F n'a rien d'un chiffre magique : le test est `INC DL / JZ`,
; donc TOUT ce qui n'est ni 0 ni 0xFF prend la seconde cible. Un analyste
; avait annote « should be xff ? » sur cette ligne — c'est une melecture,
; corrigee dans le projet Ghidra le 21/08/2026.
;
; Verifie par balayage d'octets : le drapeau n'a QUE DEUX lecteurs dans toute
; la ROM (0x40:2084 et 0x40:20EA), tous deux dans run_player_one et tous deux
; de simples tests de non-nullite. La valeur ne sert donc a rien d'autre qu'a
; choisir la cible.
;
; Conversion (Conv.java, verifiee sur les deux valeurs deja portees) :
;   X_v2 = (X_arcade - 320) * 144/384 + 8
;   Y_v2 = (Y_arcade - 128 - 16) * -180/240 + 190      (axe arcade vers le haut)
; ---------------------------------------------------------------------------
endstage.RALLY_X  equ 80             ; arcade X $200 : (512-320)*0.375+8
endstage.RALLY_Y  equ 130            ; arcade Y $E0  : (224-144)*-0.75+190
; La cible de la SEQUENCE DE FIN (stage 8 seul).
endstage.RALLY_X_ENDING equ 38       ; arcade X $190 : (400-320)*0.375+8
endstage.RALLY_Y_ENDING equ 106      ; arcade Y $100 : (256-144)*-0.75+190

; ZONE MORTE — l'arcade compare |delta| a 4 px ARCADE sur LES DEUX axes
; (0x40:20B7 et 0x40:20CB). Les pixels arcade ne sont pas les notres et les
; deux axes n'ont pas le meme rapport : 4*144/384 = 1,5 -> 2 en X, et
; 4*180/240 = 3 en Y. Une valeur unique de 3 etait le chiffre du Y applique
; aux deux, soit une bande horizontale deux fois trop large (corrige le
; 21/08/2026). La vitesse de l'autopilote porte deja le meme partage :
; scale.XN1PX vaut 0,375 px/trame la ou scale.YN1PX vaut 0,75.
endstage.DEADBAND_X equ 2
endstage.DEADBAND_Y equ 3
endstage.SHIP_INVINCIBLE equ -128    ; AABB.p du vaisseau pendant la sequence (négatif obligatoire)

; le combat de substitution : camera au bout de la carte, puis ce délai — le
; boss est répute battu quand il expire (le geste BOSS_ESCAPE du stage 1).
; La musique de boss, déclenchée par le marqueur de wave juste avant le bout
; de la carte, joue pendant ce temps. À remplacer stage par stage quand les
; vrais boss arriveront.
endlevel.BOSS_HOLD equ 500           ; ~10 s a 50 Hz

 ENDC
