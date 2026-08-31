* ===========================================================================
* Chronologie du boss du stage 01 — reprise 1:1 de la v1
* ===========================================================================
* Ces reperes sont des CONSTANTES de compilation : le boss les compare au
* compteur de trames de la partie. Chaque objet du boss etant sa propre
* assemblee, ils vivent dans un include partage, comme objid.const.asm.
*
* Source : game-mode/01/main.asm de la v1 (thomson-to8-game-engine,
* game-projects/r-type). Les commentaires d'origine sont conserves : ils
* portent le raisonnement d'arcade, pas la mecanique.
*
* La famille endstage.* decrit la SEQUENCE DE FIN : sa duree, ses reperes et le
* protocole de l'objet monte qui la joue (une commande en B, un statut en
* retour). Le stage et l'objet la partagent, d'ou l'include commun.

 IFNDEF TIMESTAMPS_CONST_01
TIMESTAMPS_CONST_01     equ 1

timestamp.DELETE_ALIEN_BODY equ $1D80
timestamp.NERV_VULNERABLE  equ $1BDF+456 ; nerves (eyes) armables, T0 = spawn du MONSTRE ($1BDF,
                                     ;   = T0 arcade : create_dobkeratops cree monstre et nerves
                                     ;   ENSEMBLE ; le portage etale les spawns wave, orbites a $1B7C).
                                     ;
                                     ;   L'arcade arme la nerve a T0+$280 (=640, compteur +0x22 de
                                     ;   run_dobkeratops_optical_nerves_intro @0x409F63). Reprendre
                                     ;   cet offset ABSOLU est faux ici : le portage a raccourci
                                     ;   l'intro du monstre (0x200=512 -> 360, "manual adjustment by
                                     ;   video") ET l'emergence (0x3F=63 -> 31). Chronologies :
                                     ;
                                     ;               explosions   combat   1res scies   nerve armee
                                     ;     arcade        416       575        591          640
                                     ;     portage       264       391        407          456
                                     ;
                                     ;   Ce qui compte est la RELATION, pas l'offset : l'arcade arme
                                     ;   la nerve 65 trames apres l'entree en combat et 49 apres la
                                     ;   premiere volee de scies (cf. le plate "chain routine when
                                     ;   scroll is over and monster has fired first saws"). Les deux
                                     ;   ancrages convergent ici sur 456. Garder $280 laissait 249
                                     ;   trames (~5 s) de monstre sorti et tirant avant que les nerves
                                     ;   ne soient touchables, contre ~1 s en arcade.
timestamp.ERASE_NERV_START equ $1BDF+456+$900 ; nerves auto-effacees (free-life). Arcade: le compteur
                                     ;   +0x3E ($900) part de l'armement de la nerve, donc il suit
                                     ;   NERV_VULNERABLE. Filet de securite : en jeu normal halfDamage
                                     ;   (monstre mi-vie) ou le tir du joueur tue les nerves bien avant.
timestamp.MOVEALIEN_DELAY  equ 0     ; arcade : run_dobkeratops relance le scroll du fond LA TRAME
                                     ;   MEME ou la derniere nerve meurt (poke 0x2ef4=0x40, $9A8C) —
                                     ;   les 140 trames de grace etaient une invention du portage
timestamp.MOVEALIEN_SPEED  equ $18   ; arcade 0x40/256 px/trame x 144/384 : la conversion X exacte
timestamp.MOVEALIEN_DIST   equ 71    ; la course de l'etau. Le corps (centre ecran 111, 80 px de
                                     ;   large) a son bord gauche a 71 px : 71 px de course posent
                                     ;   ce bord SUR le mur gauche — l'ecrasement arcade complet
                                     ;   (60 s'arretait 11 px avant le mur). La butee reste l'evenement
                                     ;   de gameplay du portage : elle tue P1 (MonsterMouth) et borne
                                     ;   le suivi de collision fond — l'arcade, elle, tue par contact
                                     ;   et ne s'arrete jamais, mais a ce point l'etau est deja ferme.
timestamp.BOSS_ESCAPE      equ $1BDF+$1000 ; boss escape / end-stage. Arcade: parent run_dobkeratops
                                     ;   +0x3E engagement timeout $1000 depuis T0 (= spawn monstre $1BDF)

endstage.DURATION equ $C0            ; arcade: run_dobkeratops arms +0x22 = $C0 frames
endstage.JINGLE   equ $10            ; arcade: jingle + ship autopilot fire when the countdown reaches $10
endstage.RALLY_X  equ 80             ; arcade X $200: CoordinatesConv round((512-320)*144/384)+8 = 80
endstage.RALLY_Y  equ 130            ; arcade Y $E0: CoordinatesConv round((224-128-16)*-180/240)+190 = 130 (arcade Y axis is up, flipped)
; DEAD BAND — the arcade compares |delta| to 4 ARCADE px on BOTH axes
; (run_player_one 0x40:20b7 and 0x40:20cb). Arcade pixels are not v2 pixels,
; and the two axes do not share a ratio : 4*144/384 = 1.5 -> 2 in X, and
; 4*180/240 = 3 in Y. A single value of 3 was the Y figure applied to both,
; making the horizontal band twice too wide (fixed 21/08/2026). The autopilot
; speed already carries the same split — scale.XN1PX is 0.375 px/frame where
; scale.YN1PX is 0.75.
endstage.DEADBAND_X equ 2            ; arcade 4 px * 144/384 = 1.5 -> 2
endstage.DEADBAND_Y equ 3            ; arcade 4 px * 180/240 = 3
endstage.bossStopX equ 1396          ; camera x that frames the boss room (was the old map_width-viewport_width)
endstage.SHIP_INVINCIBLE equ -128    ; player AABB.p during the end sequence. MUST be negative:
                                     ;   an invincible box is never modified by Collision_Do nor
                                     ;   TM_Collide. 127 (the ship's normal "weak" value) would be
                                     ;   cleared on the first contact -> death during the sequence.

; ObjID_endstage mounted-object protocol (logic lives in obj_endstage.asm)
endstage.TICK          equ 0         ; command: run the end of stage tick
endstage.INIT          equ 1         ; command: reset boss sequencing state
endstage.BLIT          equ 2         ; command: boss tile-erase black blits (call inside the gfx lock)
endstage.STATUS_NONE   equ 0         ; status: nothing to do
endstage.STATUS_JINGLE equ 1         ; status: main must start the stage clear jingle
; V2-DEVIATION : la v1 quitte le niveau depuis l'objet, par LoadGameModeNow —
; une machinerie de modes de jeu que la v2 n'a pas ; on sort d'un stage en
; changeant de scene, ce qui appartient au stage. L'objet rend donc un statut
; de plus, par le canal qui servait deja a lui faire demander le jingle.
endstage.STATUS_DONE   equ 2         ; status: the level is over, main hands over

 ENDC
