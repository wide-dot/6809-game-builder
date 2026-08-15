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
endstage.RALLY_X  equ 80             ; point de ralliement de l'autopilote (arcade X $200)
endstage.RALLY_Y  equ 130            ; (arcade Y $E0, axe retourne)
endstage.DEADBAND equ 3              ; zone morte par axe, en px
endstage.SHIP_INVINCIBLE equ -128    ; AABB.p du vaisseau pendant la sequence (négatif obligatoire)

; le combat de substitution : camera au bout de la carte, puis ce délai — le
; boss est répute battu quand il expire (le geste BOSS_ESCAPE du stage 1).
; La musique de boss, déclenchée par le marqueur de wave juste avant le bout
; de la carte, joue pendant ce temps. À remplacer stage par stage quand les
; vrais boss arriveront.
endlevel.BOSS_HOLD equ 500           ; ~10 s a 50 Hz

 ENDC
