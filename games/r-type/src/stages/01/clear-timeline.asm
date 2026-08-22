; GENERE par tools/gen_clear_timeline.py — NE PAS EDITER.
; La timeline d'effacement du stage 01 : seulement les CHANGEMENTS de
; fenetre, precalcules pour clearblast.asm. Une entree = [camera(2),
; operande LDS plan couleur(2), offset de saut(2)] ; sentinelle $FFFF.
; t/b = rangees de tuiles zappees en haut/bas de la fenetre.
clear.timeline
        fdb   0,$BDD8,0   ; t=0 b=0 lignes 11-190
        fdb   $FFFF                ; fin — la camera n'y va jamais
