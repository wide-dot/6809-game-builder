; GENERE par tools/gen_clear_timeline.py — NE PAS EDITER.
; La timeline d'effacement du stage 01 : seulement les CHANGEMENTS de
; fenetre, precalcules pour clearblast.asm. Une entree = [camera(2),
; operande LDS plan couleur(2), offset de saut(2)] ; sentinelle $FFFF.
; t/b = rangees de tuiles zappees en haut/bas de la fenetre.
clear.timeline
        fdb   0,$BBF8,0   ; t=0 b=1 lignes 11-178
        fdb   589,$BBF8,106   ; t=1 b=1 lignes 23-178
        fdb   648,$BBF8,0   ; t=0 b=1 lignes 11-178
        fdb   817,$BBF8,106   ; t=1 b=1 lignes 23-178
        fdb   912,$BBF8,0   ; t=0 b=1 lignes 11-178
        fdb   1081,$BBF8,106   ; t=1 b=1 lignes 23-178
        fdb   1428,$BBF8,0   ; t=0 b=1 lignes 11-178
        fdb   $FFFF                ; fin — la camera n'y va jamais
