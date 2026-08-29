; ---------------------------------------------------------------------------
; L'OSCILLATION DU DOME DU COMPILER — table GENEREE, ne pas editer
; ---------------------------------------------------------------------------
; Rejeu : python3 tools/gen_dome_pulse.py (depuis games/r-type/).
; Le pourquoi de chaque valeur est dans le script ; en deux mots : la borne
; pulse trois entrees de palette vers un vert sombre, et la courbe DAC du TO8
; n'a pas les niveaux intermediaires pour la suivre — on garde 4 paliers, sans
; noir ni aplat uni (decision auteur).
;
; Trois mots par etape, dans l'ordre des cases MATERIELLES 12, 13, 14 :
; halo, ombre, corps. Format $GR0B, celui de png2pal — le runtime les recopie
; tels quels dans Pal_buffer.
cpl.dome.pal
        fdb   $E304,$3000,$8000 ; e0 : halo 143,250,158 / ombre 0,143,0 / corps 0,204,0
        fdb   $9202,$2000,$6000 ; e1 : halo 122,212,122 / ombre 0,122,0 / corps 0,184,0
        fdb   $6101,$1000,$3000 ; e2 : halo 97,184,97 / ombre 0,97,0 / corps 0,143,0
        fdb   $3101,$1000,$2000 ; e3 : halo 97,143,97 / ombre 0,97,0 / corps 0,122,0

; Le cycle, en trames de jeu : l'etape a jouer puis sa duree. La 4e est une
; TENUE longue — le creux profond de l'arcade, dont on a coupe la couleur.
; Total 116 trames, la periode de la borne (128 ticks a 55 Hz).
cpl.dome.CYCLE equ 6
cpl.dome.seq
        fcb   0,12  ; etape 0, 12 trames
        fcb   1,12  ; etape 1, 12 trames
        fcb   2,11  ; etape 2, 11 trames
        fcb   3,58  ; etape 3, 58 trames
        fcb   2,11  ; etape 2, 11 trames
        fcb   1,12  ; etape 1, 12 trames
