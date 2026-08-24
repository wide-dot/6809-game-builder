; GENERE par tools/gen_pellet_tables.py — NE PAS EDITER.
; Les tables de la couche gommes du stage 4. Voir l'en-tete de
; l'outil pour le modele d'ecran et la periodicite (3 octets par
; plan, 12 phases). Le rendu depuis ces valeurs a ete rejoue et
; compare pixel pour pixel a la carte : 622080 px, 0 divergence.

; 12 phases x 6 lignes x 2 plans x 3 octets — UNE periode du motif.
; L'octet j d'un plan prend l'entree (j mod 3).
pellet.tbl.run
; --- phase 0
        fcb   $0D,$DC,$C0   ; ligne 0 plan C
        fcb   $C0,$0D,$DC   ; ligne 0 plan A
        fcb   $0D,$DC,$C0   ; ligne 1 plan C
        fcb   $C0,$0D,$DC   ; ligne 1 plan A
        fcb   $DD,$DC,$CD   ; ligne 2 plan C
        fcb   $CD,$DD,$DC   ; ligne 2 plan A
        fcb   $D7,$7A,$AD   ; ligne 3 plan C
        fcb   $AD,$D7,$7A   ; ligne 3 plan A
        fcb   $CC,$CF,$FC   ; ligne 4 plan C
        fcb   $FC,$CC,$CF   ; ligne 4 plan A
        fcb   $0F,$FF,$F0   ; ligne 5 plan C
        fcb   $F0,$0F,$FF   ; ligne 5 plan A
; --- phase 1
        fcb   $C0,$0D,$DC   ; ligne 0 plan C
        fcb   $DC,$C0,$0D   ; ligne 0 plan A
        fcb   $C0,$0D,$DC   ; ligne 1 plan C
        fcb   $DC,$C0,$0D   ; ligne 1 plan A
        fcb   $CD,$DD,$DC   ; ligne 2 plan C
        fcb   $DC,$CD,$DD   ; ligne 2 plan A
        fcb   $AD,$D7,$7A   ; ligne 3 plan C
        fcb   $7A,$AD,$D7   ; ligne 3 plan A
        fcb   $FC,$CC,$CF   ; ligne 4 plan C
        fcb   $CF,$FC,$CC   ; ligne 4 plan A
        fcb   $F0,$0F,$FF   ; ligne 5 plan C
        fcb   $FF,$F0,$0F   ; ligne 5 plan A
; --- phase 2
        fcb   $DC,$C0,$0D   ; ligne 0 plan C
        fcb   $0D,$DC,$C0   ; ligne 0 plan A
        fcb   $DC,$C0,$0D   ; ligne 1 plan C
        fcb   $0D,$DC,$C0   ; ligne 1 plan A
        fcb   $DC,$CD,$DD   ; ligne 2 plan C
        fcb   $DD,$DC,$CD   ; ligne 2 plan A
        fcb   $7A,$AD,$D7   ; ligne 3 plan C
        fcb   $D7,$7A,$AD   ; ligne 3 plan A
        fcb   $CF,$FC,$CC   ; ligne 4 plan C
        fcb   $CC,$CF,$FC   ; ligne 4 plan A
        fcb   $FF,$F0,$0F   ; ligne 5 plan C
        fcb   $0F,$FF,$F0   ; ligne 5 plan A
; --- phase 3
        fcb   $0D,$DC,$C0   ; ligne 0 plan C
        fcb   $C0,$0D,$DC   ; ligne 0 plan A
        fcb   $0D,$DC,$C0   ; ligne 1 plan C
        fcb   $C0,$0D,$DC   ; ligne 1 plan A
        fcb   $DD,$DC,$CD   ; ligne 2 plan C
        fcb   $CD,$DD,$DC   ; ligne 2 plan A
        fcb   $D7,$7A,$AD   ; ligne 3 plan C
        fcb   $AD,$D7,$7A   ; ligne 3 plan A
        fcb   $CC,$CF,$FC   ; ligne 4 plan C
        fcb   $FC,$CC,$CF   ; ligne 4 plan A
        fcb   $0F,$FF,$F0   ; ligne 5 plan C
        fcb   $F0,$0F,$FF   ; ligne 5 plan A
; --- phase 4
        fcb   $C0,$0D,$DC   ; ligne 0 plan C
        fcb   $DC,$C0,$0D   ; ligne 0 plan A
        fcb   $C0,$0D,$DC   ; ligne 1 plan C
        fcb   $DC,$C0,$0D   ; ligne 1 plan A
        fcb   $CD,$DD,$DC   ; ligne 2 plan C
        fcb   $DC,$CD,$DD   ; ligne 2 plan A
        fcb   $AD,$D7,$7A   ; ligne 3 plan C
        fcb   $7A,$AD,$D7   ; ligne 3 plan A
        fcb   $FC,$CC,$CF   ; ligne 4 plan C
        fcb   $CF,$FC,$CC   ; ligne 4 plan A
        fcb   $F0,$0F,$FF   ; ligne 5 plan C
        fcb   $FF,$F0,$0F   ; ligne 5 plan A
; --- phase 5
        fcb   $DC,$C0,$0D   ; ligne 0 plan C
        fcb   $0D,$DC,$C0   ; ligne 0 plan A
        fcb   $DC,$C0,$0D   ; ligne 1 plan C
        fcb   $0D,$DC,$C0   ; ligne 1 plan A
        fcb   $DC,$CD,$DD   ; ligne 2 plan C
        fcb   $DD,$DC,$CD   ; ligne 2 plan A
        fcb   $7A,$AD,$D7   ; ligne 3 plan C
        fcb   $D7,$7A,$AD   ; ligne 3 plan A
        fcb   $CF,$FC,$CC   ; ligne 4 plan C
        fcb   $CC,$CF,$FC   ; ligne 4 plan A
        fcb   $FF,$F0,$0F   ; ligne 5 plan C
        fcb   $0F,$FF,$F0   ; ligne 5 plan A
; --- phase 6
        fcb   $0D,$DC,$C0   ; ligne 0 plan C
        fcb   $C0,$0D,$DC   ; ligne 0 plan A
        fcb   $0D,$DC,$C0   ; ligne 1 plan C
        fcb   $C0,$0D,$DC   ; ligne 1 plan A
        fcb   $DD,$DC,$CD   ; ligne 2 plan C
        fcb   $CD,$DD,$DC   ; ligne 2 plan A
        fcb   $D7,$7A,$AD   ; ligne 3 plan C
        fcb   $AD,$D7,$7A   ; ligne 3 plan A
        fcb   $CC,$CF,$FC   ; ligne 4 plan C
        fcb   $FC,$CC,$CF   ; ligne 4 plan A
        fcb   $0F,$FF,$F0   ; ligne 5 plan C
        fcb   $F0,$0F,$FF   ; ligne 5 plan A
; --- phase 7
        fcb   $C0,$0D,$DC   ; ligne 0 plan C
        fcb   $DC,$C0,$0D   ; ligne 0 plan A
        fcb   $C0,$0D,$DC   ; ligne 1 plan C
        fcb   $DC,$C0,$0D   ; ligne 1 plan A
        fcb   $CD,$DD,$DC   ; ligne 2 plan C
        fcb   $DC,$CD,$DD   ; ligne 2 plan A
        fcb   $AD,$D7,$7A   ; ligne 3 plan C
        fcb   $7A,$AD,$D7   ; ligne 3 plan A
        fcb   $FC,$CC,$CF   ; ligne 4 plan C
        fcb   $CF,$FC,$CC   ; ligne 4 plan A
        fcb   $F0,$0F,$FF   ; ligne 5 plan C
        fcb   $FF,$F0,$0F   ; ligne 5 plan A
; --- phase 8
        fcb   $DC,$C0,$0D   ; ligne 0 plan C
        fcb   $0D,$DC,$C0   ; ligne 0 plan A
        fcb   $DC,$C0,$0D   ; ligne 1 plan C
        fcb   $0D,$DC,$C0   ; ligne 1 plan A
        fcb   $DC,$CD,$DD   ; ligne 2 plan C
        fcb   $DD,$DC,$CD   ; ligne 2 plan A
        fcb   $7A,$AD,$D7   ; ligne 3 plan C
        fcb   $D7,$7A,$AD   ; ligne 3 plan A
        fcb   $CF,$FC,$CC   ; ligne 4 plan C
        fcb   $CC,$CF,$FC   ; ligne 4 plan A
        fcb   $FF,$F0,$0F   ; ligne 5 plan C
        fcb   $0F,$FF,$F0   ; ligne 5 plan A
; --- phase 9
        fcb   $0D,$DC,$C0   ; ligne 0 plan C
        fcb   $C0,$0D,$DC   ; ligne 0 plan A
        fcb   $0D,$DC,$C0   ; ligne 1 plan C
        fcb   $C0,$0D,$DC   ; ligne 1 plan A
        fcb   $DD,$DC,$CD   ; ligne 2 plan C
        fcb   $CD,$DD,$DC   ; ligne 2 plan A
        fcb   $D7,$7A,$AD   ; ligne 3 plan C
        fcb   $AD,$D7,$7A   ; ligne 3 plan A
        fcb   $CC,$CF,$FC   ; ligne 4 plan C
        fcb   $FC,$CC,$CF   ; ligne 4 plan A
        fcb   $0F,$FF,$F0   ; ligne 5 plan C
        fcb   $F0,$0F,$FF   ; ligne 5 plan A
; --- phase 10
        fcb   $C0,$0D,$DC   ; ligne 0 plan C
        fcb   $DC,$C0,$0D   ; ligne 0 plan A
        fcb   $C0,$0D,$DC   ; ligne 1 plan C
        fcb   $DC,$C0,$0D   ; ligne 1 plan A
        fcb   $CD,$DD,$DC   ; ligne 2 plan C
        fcb   $DC,$CD,$DD   ; ligne 2 plan A
        fcb   $AD,$D7,$7A   ; ligne 3 plan C
        fcb   $7A,$AD,$D7   ; ligne 3 plan A
        fcb   $FC,$CC,$CF   ; ligne 4 plan C
        fcb   $CF,$FC,$CC   ; ligne 4 plan A
        fcb   $F0,$0F,$FF   ; ligne 5 plan C
        fcb   $FF,$F0,$0F   ; ligne 5 plan A
; --- phase 11
        fcb   $DC,$C0,$0D   ; ligne 0 plan C
        fcb   $0D,$DC,$C0   ; ligne 0 plan A
        fcb   $DC,$C0,$0D   ; ligne 1 plan C
        fcb   $0D,$DC,$C0   ; ligne 1 plan A
        fcb   $DC,$CD,$DD   ; ligne 2 plan C
        fcb   $DD,$DC,$CD   ; ligne 2 plan A
        fcb   $7A,$AD,$D7   ; ligne 3 plan C
        fcb   $D7,$7A,$AD   ; ligne 3 plan A
        fcb   $CF,$FC,$CC   ; ligne 4 plan C
        fcb   $CC,$CF,$FC   ; ligne 4 plan A
        fcb   $FF,$F0,$0F   ; ligne 5 plan C
        fcb   $0F,$FF,$F0   ; ligne 5 plan A

; Les octets de BORD, par ligne. Un octet de bord n'a qu'UN pixel
; dans la plage : celui de gauche est le d=0 d'une gomme, celui de
; droite le d=2. Sa valeur ne depend donc ni de la phase, ni du plan,
; ni de l'alignement — 12 octets pour tout le champ.
pellet.tbl.edge
        fcb   $00,$C0   ; ligne 0 : bord gauche, bord droit
        fcb   $00,$C0   ; ligne 1 : bord gauche, bord droit
        fcb   $0D,$C0   ; ligne 2 : bord gauche, bord droit
        fcb   $0D,$A0   ; ligne 3 : bord gauche, bord droit
        fcb   $0C,$F0   ; ligne 4 : bord gauche, bord droit
        fcb   $00,$F0   ; ligne 5 : bord gauche, bord droit

; La geometrie, indexee par scroll_tile_pos_offset24 (0..23) — le
; decalage px de la camera dans l'octet de carte courant, que le
; scroll tient a jour. Comme un octet de carte fait 24 px et que
; 24 est multiple de 12, la PHASE du motif ne depend que de lui :
; pas de division a faire au runtime.
;   fdb  offset de la phase dans pellet.tbl.run (phase x 108)
;   fcb  premiere cellule relative a dessiner
;   fcb  nombre de cellules a parcourir
pellet.tbl.geo
        fdb   288
        fcb   0,48   ; offset24 0, phase 8
        fdb   252
        fcb   0,49   ; offset24 1, phase 7
        fdb   216
        fcb   0,49   ; offset24 2, phase 6
        fdb   180
        fcb   1,48   ; offset24 3, phase 5
        fdb   144
        fcb   1,49   ; offset24 4, phase 4
        fdb   108
        fcb   1,49   ; offset24 5, phase 3
        fdb   72
        fcb   2,48   ; offset24 6, phase 2
        fdb   36
        fcb   2,49   ; offset24 7, phase 1
        fdb   0
        fcb   2,49   ; offset24 8, phase 0
        fdb   396
        fcb   3,48   ; offset24 9, phase 11
        fdb   360
        fcb   3,49   ; offset24 10, phase 10
        fdb   324
        fcb   3,49   ; offset24 11, phase 9
        fdb   288
        fcb   4,48   ; offset24 12, phase 8
        fdb   252
        fcb   4,49   ; offset24 13, phase 7
        fdb   216
        fcb   4,49   ; offset24 14, phase 6
        fdb   180
        fcb   5,48   ; offset24 15, phase 5
        fdb   144
        fcb   5,49   ; offset24 16, phase 4
        fdb   108
        fcb   5,49   ; offset24 17, phase 3
        fdb   72
        fcb   6,48   ; offset24 18, phase 2
        fdb   36
        fcb   6,49   ; offset24 19, phase 1
        fdb   0
        fcb   6,49   ; offset24 20, phase 0
        fdb   396
        fcb   7,48   ; offset24 21, phase 11
        fdb   360
        fcb   7,49   ; offset24 22, phase 10
        fdb   324
        fcb   7,49   ; offset24 23, phase 9

; j mod 3, pour indexer le motif periodique par l'indice d'octet.
; 64 entrees : l'indice d'octet d'un plan ne depasse pas 38.
pellet.tbl.mod3
        fcb   0,1,2,0,1,2,0,1,2,0,1,2,0,1,2,0
        fcb   1,2,0,1,2,0,1,2,0,1,2,0,1,2,0,1
        fcb   2,0,1,2,0,1,2,0,1,2,0,1,2,0,1,2
        fcb   0,1,2,0,1,2,0,1,2,0,1,2,0,1,2,0
