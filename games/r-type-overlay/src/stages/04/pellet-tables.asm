; GENERE par tools/gen_pellet_tables.py — NE PAS EDITER.
; Les tables de la couche gommes du stage 4. Voir l'en-tete de
; l'outil pour le modele d'ecran et la periodicite (3 octets par
; plan, 12 phases). Le rendu depuis ces valeurs a ete rejoue et
; compare pixel pour pixel a la carte : 622080 px, 0 divergence.

; 12 phases x 6 lignes x 2 plans x 9 octets — le motif repete
; d'une plage PLEINE, pret pour un PSHS de 9 octets.
pellet.tbl.run
; --- phase 0
        fcb   $0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0   ; ligne 0 plan C
        fcb   $C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC   ; ligne 0 plan A
        fcb   $0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0   ; ligne 1 plan C
        fcb   $C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC   ; ligne 1 plan A
        fcb   $DD,$DC,$CD,$DD,$DC,$CD,$DD,$DC,$CD   ; ligne 2 plan C
        fcb   $CD,$DD,$DC,$CD,$DD,$DC,$CD,$DD,$DC   ; ligne 2 plan A
        fcb   $D7,$7A,$AD,$D7,$7A,$AD,$D7,$7A,$AD   ; ligne 3 plan C
        fcb   $AD,$D7,$7A,$AD,$D7,$7A,$AD,$D7,$7A   ; ligne 3 plan A
        fcb   $CC,$CF,$FC,$CC,$CF,$FC,$CC,$CF,$FC   ; ligne 4 plan C
        fcb   $FC,$CC,$CF,$FC,$CC,$CF,$FC,$CC,$CF   ; ligne 4 plan A
        fcb   $0F,$FF,$F0,$0F,$FF,$F0,$0F,$FF,$F0   ; ligne 5 plan C
        fcb   $F0,$0F,$FF,$F0,$0F,$FF,$F0,$0F,$FF   ; ligne 5 plan A
; --- phase 1
        fcb   $C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC   ; ligne 0 plan C
        fcb   $DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D   ; ligne 0 plan A
        fcb   $C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC   ; ligne 1 plan C
        fcb   $DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D   ; ligne 1 plan A
        fcb   $CD,$DD,$DC,$CD,$DD,$DC,$CD,$DD,$DC   ; ligne 2 plan C
        fcb   $DC,$CD,$DD,$DC,$CD,$DD,$DC,$CD,$DD   ; ligne 2 plan A
        fcb   $AD,$D7,$7A,$AD,$D7,$7A,$AD,$D7,$7A   ; ligne 3 plan C
        fcb   $7A,$AD,$D7,$7A,$AD,$D7,$7A,$AD,$D7   ; ligne 3 plan A
        fcb   $FC,$CC,$CF,$FC,$CC,$CF,$FC,$CC,$CF   ; ligne 4 plan C
        fcb   $CF,$FC,$CC,$CF,$FC,$CC,$CF,$FC,$CC   ; ligne 4 plan A
        fcb   $F0,$0F,$FF,$F0,$0F,$FF,$F0,$0F,$FF   ; ligne 5 plan C
        fcb   $FF,$F0,$0F,$FF,$F0,$0F,$FF,$F0,$0F   ; ligne 5 plan A
; --- phase 2
        fcb   $DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D   ; ligne 0 plan C
        fcb   $0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0   ; ligne 0 plan A
        fcb   $DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D   ; ligne 1 plan C
        fcb   $0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0   ; ligne 1 plan A
        fcb   $DC,$CD,$DD,$DC,$CD,$DD,$DC,$CD,$DD   ; ligne 2 plan C
        fcb   $DD,$DC,$CD,$DD,$DC,$CD,$DD,$DC,$CD   ; ligne 2 plan A
        fcb   $7A,$AD,$D7,$7A,$AD,$D7,$7A,$AD,$D7   ; ligne 3 plan C
        fcb   $D7,$7A,$AD,$D7,$7A,$AD,$D7,$7A,$AD   ; ligne 3 plan A
        fcb   $CF,$FC,$CC,$CF,$FC,$CC,$CF,$FC,$CC   ; ligne 4 plan C
        fcb   $CC,$CF,$FC,$CC,$CF,$FC,$CC,$CF,$FC   ; ligne 4 plan A
        fcb   $FF,$F0,$0F,$FF,$F0,$0F,$FF,$F0,$0F   ; ligne 5 plan C
        fcb   $0F,$FF,$F0,$0F,$FF,$F0,$0F,$FF,$F0   ; ligne 5 plan A
; --- phase 3
        fcb   $0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0   ; ligne 0 plan C
        fcb   $C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC   ; ligne 0 plan A
        fcb   $0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0   ; ligne 1 plan C
        fcb   $C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC   ; ligne 1 plan A
        fcb   $DD,$DC,$CD,$DD,$DC,$CD,$DD,$DC,$CD   ; ligne 2 plan C
        fcb   $CD,$DD,$DC,$CD,$DD,$DC,$CD,$DD,$DC   ; ligne 2 plan A
        fcb   $D7,$7A,$AD,$D7,$7A,$AD,$D7,$7A,$AD   ; ligne 3 plan C
        fcb   $AD,$D7,$7A,$AD,$D7,$7A,$AD,$D7,$7A   ; ligne 3 plan A
        fcb   $CC,$CF,$FC,$CC,$CF,$FC,$CC,$CF,$FC   ; ligne 4 plan C
        fcb   $FC,$CC,$CF,$FC,$CC,$CF,$FC,$CC,$CF   ; ligne 4 plan A
        fcb   $0F,$FF,$F0,$0F,$FF,$F0,$0F,$FF,$F0   ; ligne 5 plan C
        fcb   $F0,$0F,$FF,$F0,$0F,$FF,$F0,$0F,$FF   ; ligne 5 plan A
; --- phase 4
        fcb   $C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC   ; ligne 0 plan C
        fcb   $DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D   ; ligne 0 plan A
        fcb   $C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC   ; ligne 1 plan C
        fcb   $DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D   ; ligne 1 plan A
        fcb   $CD,$DD,$DC,$CD,$DD,$DC,$CD,$DD,$DC   ; ligne 2 plan C
        fcb   $DC,$CD,$DD,$DC,$CD,$DD,$DC,$CD,$DD   ; ligne 2 plan A
        fcb   $AD,$D7,$7A,$AD,$D7,$7A,$AD,$D7,$7A   ; ligne 3 plan C
        fcb   $7A,$AD,$D7,$7A,$AD,$D7,$7A,$AD,$D7   ; ligne 3 plan A
        fcb   $FC,$CC,$CF,$FC,$CC,$CF,$FC,$CC,$CF   ; ligne 4 plan C
        fcb   $CF,$FC,$CC,$CF,$FC,$CC,$CF,$FC,$CC   ; ligne 4 plan A
        fcb   $F0,$0F,$FF,$F0,$0F,$FF,$F0,$0F,$FF   ; ligne 5 plan C
        fcb   $FF,$F0,$0F,$FF,$F0,$0F,$FF,$F0,$0F   ; ligne 5 plan A
; --- phase 5
        fcb   $DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D   ; ligne 0 plan C
        fcb   $0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0   ; ligne 0 plan A
        fcb   $DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D   ; ligne 1 plan C
        fcb   $0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0   ; ligne 1 plan A
        fcb   $DC,$CD,$DD,$DC,$CD,$DD,$DC,$CD,$DD   ; ligne 2 plan C
        fcb   $DD,$DC,$CD,$DD,$DC,$CD,$DD,$DC,$CD   ; ligne 2 plan A
        fcb   $7A,$AD,$D7,$7A,$AD,$D7,$7A,$AD,$D7   ; ligne 3 plan C
        fcb   $D7,$7A,$AD,$D7,$7A,$AD,$D7,$7A,$AD   ; ligne 3 plan A
        fcb   $CF,$FC,$CC,$CF,$FC,$CC,$CF,$FC,$CC   ; ligne 4 plan C
        fcb   $CC,$CF,$FC,$CC,$CF,$FC,$CC,$CF,$FC   ; ligne 4 plan A
        fcb   $FF,$F0,$0F,$FF,$F0,$0F,$FF,$F0,$0F   ; ligne 5 plan C
        fcb   $0F,$FF,$F0,$0F,$FF,$F0,$0F,$FF,$F0   ; ligne 5 plan A
; --- phase 6
        fcb   $0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0   ; ligne 0 plan C
        fcb   $C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC   ; ligne 0 plan A
        fcb   $0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0   ; ligne 1 plan C
        fcb   $C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC   ; ligne 1 plan A
        fcb   $DD,$DC,$CD,$DD,$DC,$CD,$DD,$DC,$CD   ; ligne 2 plan C
        fcb   $CD,$DD,$DC,$CD,$DD,$DC,$CD,$DD,$DC   ; ligne 2 plan A
        fcb   $D7,$7A,$AD,$D7,$7A,$AD,$D7,$7A,$AD   ; ligne 3 plan C
        fcb   $AD,$D7,$7A,$AD,$D7,$7A,$AD,$D7,$7A   ; ligne 3 plan A
        fcb   $CC,$CF,$FC,$CC,$CF,$FC,$CC,$CF,$FC   ; ligne 4 plan C
        fcb   $FC,$CC,$CF,$FC,$CC,$CF,$FC,$CC,$CF   ; ligne 4 plan A
        fcb   $0F,$FF,$F0,$0F,$FF,$F0,$0F,$FF,$F0   ; ligne 5 plan C
        fcb   $F0,$0F,$FF,$F0,$0F,$FF,$F0,$0F,$FF   ; ligne 5 plan A
; --- phase 7
        fcb   $C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC   ; ligne 0 plan C
        fcb   $DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D   ; ligne 0 plan A
        fcb   $C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC   ; ligne 1 plan C
        fcb   $DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D   ; ligne 1 plan A
        fcb   $CD,$DD,$DC,$CD,$DD,$DC,$CD,$DD,$DC   ; ligne 2 plan C
        fcb   $DC,$CD,$DD,$DC,$CD,$DD,$DC,$CD,$DD   ; ligne 2 plan A
        fcb   $AD,$D7,$7A,$AD,$D7,$7A,$AD,$D7,$7A   ; ligne 3 plan C
        fcb   $7A,$AD,$D7,$7A,$AD,$D7,$7A,$AD,$D7   ; ligne 3 plan A
        fcb   $FC,$CC,$CF,$FC,$CC,$CF,$FC,$CC,$CF   ; ligne 4 plan C
        fcb   $CF,$FC,$CC,$CF,$FC,$CC,$CF,$FC,$CC   ; ligne 4 plan A
        fcb   $F0,$0F,$FF,$F0,$0F,$FF,$F0,$0F,$FF   ; ligne 5 plan C
        fcb   $FF,$F0,$0F,$FF,$F0,$0F,$FF,$F0,$0F   ; ligne 5 plan A
; --- phase 8
        fcb   $DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D   ; ligne 0 plan C
        fcb   $0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0   ; ligne 0 plan A
        fcb   $DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D   ; ligne 1 plan C
        fcb   $0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0   ; ligne 1 plan A
        fcb   $DC,$CD,$DD,$DC,$CD,$DD,$DC,$CD,$DD   ; ligne 2 plan C
        fcb   $DD,$DC,$CD,$DD,$DC,$CD,$DD,$DC,$CD   ; ligne 2 plan A
        fcb   $7A,$AD,$D7,$7A,$AD,$D7,$7A,$AD,$D7   ; ligne 3 plan C
        fcb   $D7,$7A,$AD,$D7,$7A,$AD,$D7,$7A,$AD   ; ligne 3 plan A
        fcb   $CF,$FC,$CC,$CF,$FC,$CC,$CF,$FC,$CC   ; ligne 4 plan C
        fcb   $CC,$CF,$FC,$CC,$CF,$FC,$CC,$CF,$FC   ; ligne 4 plan A
        fcb   $FF,$F0,$0F,$FF,$F0,$0F,$FF,$F0,$0F   ; ligne 5 plan C
        fcb   $0F,$FF,$F0,$0F,$FF,$F0,$0F,$FF,$F0   ; ligne 5 plan A
; --- phase 9
        fcb   $0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0   ; ligne 0 plan C
        fcb   $C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC   ; ligne 0 plan A
        fcb   $0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0   ; ligne 1 plan C
        fcb   $C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC   ; ligne 1 plan A
        fcb   $DD,$DC,$CD,$DD,$DC,$CD,$DD,$DC,$CD   ; ligne 2 plan C
        fcb   $CD,$DD,$DC,$CD,$DD,$DC,$CD,$DD,$DC   ; ligne 2 plan A
        fcb   $D7,$7A,$AD,$D7,$7A,$AD,$D7,$7A,$AD   ; ligne 3 plan C
        fcb   $AD,$D7,$7A,$AD,$D7,$7A,$AD,$D7,$7A   ; ligne 3 plan A
        fcb   $CC,$CF,$FC,$CC,$CF,$FC,$CC,$CF,$FC   ; ligne 4 plan C
        fcb   $FC,$CC,$CF,$FC,$CC,$CF,$FC,$CC,$CF   ; ligne 4 plan A
        fcb   $0F,$FF,$F0,$0F,$FF,$F0,$0F,$FF,$F0   ; ligne 5 plan C
        fcb   $F0,$0F,$FF,$F0,$0F,$FF,$F0,$0F,$FF   ; ligne 5 plan A
; --- phase 10
        fcb   $C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC   ; ligne 0 plan C
        fcb   $DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D   ; ligne 0 plan A
        fcb   $C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC   ; ligne 1 plan C
        fcb   $DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D   ; ligne 1 plan A
        fcb   $CD,$DD,$DC,$CD,$DD,$DC,$CD,$DD,$DC   ; ligne 2 plan C
        fcb   $DC,$CD,$DD,$DC,$CD,$DD,$DC,$CD,$DD   ; ligne 2 plan A
        fcb   $AD,$D7,$7A,$AD,$D7,$7A,$AD,$D7,$7A   ; ligne 3 plan C
        fcb   $7A,$AD,$D7,$7A,$AD,$D7,$7A,$AD,$D7   ; ligne 3 plan A
        fcb   $FC,$CC,$CF,$FC,$CC,$CF,$FC,$CC,$CF   ; ligne 4 plan C
        fcb   $CF,$FC,$CC,$CF,$FC,$CC,$CF,$FC,$CC   ; ligne 4 plan A
        fcb   $F0,$0F,$FF,$F0,$0F,$FF,$F0,$0F,$FF   ; ligne 5 plan C
        fcb   $FF,$F0,$0F,$FF,$F0,$0F,$FF,$F0,$0F   ; ligne 5 plan A
; --- phase 11
        fcb   $DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D   ; ligne 0 plan C
        fcb   $0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0   ; ligne 0 plan A
        fcb   $DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D   ; ligne 1 plan C
        fcb   $0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0   ; ligne 1 plan A
        fcb   $DC,$CD,$DD,$DC,$CD,$DD,$DC,$CD,$DD   ; ligne 2 plan C
        fcb   $DD,$DC,$CD,$DD,$DC,$CD,$DD,$DC,$CD   ; ligne 2 plan A
        fcb   $7A,$AD,$D7,$7A,$AD,$D7,$7A,$AD,$D7   ; ligne 3 plan C
        fcb   $D7,$7A,$AD,$D7,$7A,$AD,$D7,$7A,$AD   ; ligne 3 plan A
        fcb   $CF,$FC,$CC,$CF,$FC,$CC,$CF,$FC,$CC   ; ligne 4 plan C
        fcb   $CC,$CF,$FC,$CC,$CF,$FC,$CC,$CF,$FC   ; ligne 4 plan A
        fcb   $FF,$F0,$0F,$FF,$F0,$0F,$FF,$F0,$0F   ; ligne 5 plan C
        fcb   $0F,$FF,$F0,$0F,$FF,$F0,$0F,$FF,$F0   ; ligne 5 plan A

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
