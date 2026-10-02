; GENERE par tools/gen_hitflash_manager.py — le flash de coup : par taille de
; boite (rx, ry), l'image blanche calee sur le centre de la boite.
; fcb rx,ry / fdb set ; fin : rx = 0. Voir explosion.asm (hitflash.*).
hitflash.Sizes
        fcb   4,4
        fdb   set_expHit_0 ; petites tourelles haut+bas : ellipse 7x13, centre (+0.5,+0.5) depuis la boite, couvre 88 % des poses (9x13)
        fcb   4,6
        fdb   set_expHit_1 ; grosse tourelle : ellipse 11x20, centre (+1.0,+3.5) depuis la boite, couvre 89 % des poses (17x17)
        fcb   4,8
        fdb   set_expHit_2 ; tourelle frontale : ellipse 7x12, centre (+1.0,+0.5) depuis la boite, couvre 66 % des poses (13x13)
        fcb   4,9
        fdb   set_expHit_3 ; Cytron : ellipse 9x13, centre (-1.0,+1.0) depuis la boite, couvre 82 % des poses (13x15)
        fcb   0,0
