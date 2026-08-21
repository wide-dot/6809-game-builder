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
        fcb   $00,$0D,$DC,$00,$0D,$DC,$00,$0D,$DC   ; ligne 0 plan C
        fcb   $DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D   ; ligne 0 plan A
        fcb   $00,$0D,$DC,$00,$0D,$DC,$00,$0D,$DC   ; ligne 1 plan C
        fcb   $DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0,$0D   ; ligne 1 plan A
        fcb   $0D,$DD,$DC,$0D,$DD,$DC,$0D,$DD,$DC   ; ligne 2 plan C
        fcb   $DC,$CD,$DD,$DC,$CD,$DD,$DC,$CD,$DD   ; ligne 2 plan A
        fcb   $0D,$D7,$7A,$0D,$D7,$7A,$0D,$D7,$7A   ; ligne 3 plan C
        fcb   $7A,$AD,$D7,$7A,$AD,$D7,$7A,$AD,$D7   ; ligne 3 plan A
        fcb   $0C,$CC,$CF,$0C,$CC,$CF,$0C,$CC,$CF   ; ligne 4 plan C
        fcb   $CF,$FC,$CC,$CF,$FC,$CC,$CF,$FC,$CC   ; ligne 4 plan A
        fcb   $00,$0F,$FF,$00,$0F,$FF,$00,$0F,$FF   ; ligne 5 plan C
        fcb   $FF,$F0,$0F,$FF,$F0,$0F,$FF,$F0,$0F   ; ligne 5 plan A
; --- phase 2
        fcb   $00,$C0,$0D,$00,$C0,$0D,$00,$C0,$0D   ; ligne 0 plan C
        fcb   $0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0   ; ligne 0 plan A
        fcb   $00,$C0,$0D,$00,$C0,$0D,$00,$C0,$0D   ; ligne 1 plan C
        fcb   $0D,$DC,$C0,$0D,$DC,$C0,$0D,$DC,$C0   ; ligne 1 plan A
        fcb   $00,$CD,$DD,$00,$CD,$DD,$00,$CD,$DD   ; ligne 2 plan C
        fcb   $DD,$DC,$CD,$DD,$DC,$CD,$DD,$DC,$CD   ; ligne 2 plan A
        fcb   $00,$AD,$D7,$00,$AD,$D7,$00,$AD,$D7   ; ligne 3 plan C
        fcb   $D7,$7A,$AD,$D7,$7A,$AD,$D7,$7A,$AD   ; ligne 3 plan A
        fcb   $00,$FC,$CC,$00,$FC,$CC,$00,$FC,$CC   ; ligne 4 plan C
        fcb   $CC,$CF,$FC,$CC,$CF,$FC,$CC,$CF,$FC   ; ligne 4 plan A
        fcb   $00,$F0,$0F,$00,$F0,$0F,$00,$F0,$0F   ; ligne 5 plan C
        fcb   $0F,$FF,$F0,$0F,$FF,$F0,$0F,$FF,$F0   ; ligne 5 plan A
; --- phase 3
        fcb   $00,$DC,$C0,$00,$DC,$C0,$00,$DC,$C0   ; ligne 0 plan C
        fcb   $00,$0D,$DC,$00,$0D,$DC,$00,$0D,$DC   ; ligne 0 plan A
        fcb   $00,$DC,$C0,$00,$DC,$C0,$00,$DC,$C0   ; ligne 1 plan C
        fcb   $00,$0D,$DC,$00,$0D,$DC,$00,$0D,$DC   ; ligne 1 plan A
        fcb   $00,$DC,$CD,$00,$DC,$CD,$00,$DC,$CD   ; ligne 2 plan C
        fcb   $0D,$DD,$DC,$0D,$DD,$DC,$0D,$DD,$DC   ; ligne 2 plan A
        fcb   $00,$7A,$AD,$00,$7A,$AD,$00,$7A,$AD   ; ligne 3 plan C
        fcb   $0D,$D7,$7A,$0D,$D7,$7A,$0D,$D7,$7A   ; ligne 3 plan A
        fcb   $00,$CF,$FC,$00,$CF,$FC,$00,$CF,$FC   ; ligne 4 plan C
        fcb   $0C,$CC,$CF,$0C,$CC,$CF,$0C,$CC,$CF   ; ligne 4 plan A
        fcb   $00,$FF,$F0,$00,$FF,$F0,$00,$FF,$F0   ; ligne 5 plan C
        fcb   $00,$0F,$FF,$00,$0F,$FF,$00,$0F,$FF   ; ligne 5 plan A
; --- phase 4
        fcb   $00,$0D,$DC,$00,$0D,$DC,$00,$0D,$DC   ; ligne 0 plan C
        fcb   $00,$C0,$0D,$00,$C0,$0D,$00,$C0,$0D   ; ligne 0 plan A
        fcb   $00,$0D,$DC,$00,$0D,$DC,$00,$0D,$DC   ; ligne 1 plan C
        fcb   $00,$C0,$0D,$00,$C0,$0D,$00,$C0,$0D   ; ligne 1 plan A
        fcb   $00,$DD,$DC,$00,$DD,$DC,$00,$DD,$DC   ; ligne 2 plan C
        fcb   $00,$CD,$DD,$00,$CD,$DD,$00,$CD,$DD   ; ligne 2 plan A
        fcb   $00,$D7,$7A,$00,$D7,$7A,$00,$D7,$7A   ; ligne 3 plan C
        fcb   $00,$AD,$D7,$00,$AD,$D7,$00,$AD,$D7   ; ligne 3 plan A
        fcb   $00,$CC,$CF,$00,$CC,$CF,$00,$CC,$CF   ; ligne 4 plan C
        fcb   $00,$FC,$CC,$00,$FC,$CC,$00,$FC,$CC   ; ligne 4 plan A
        fcb   $00,$0F,$FF,$00,$0F,$FF,$00,$0F,$FF   ; ligne 5 plan C
        fcb   $00,$F0,$0F,$00,$F0,$0F,$00,$F0,$0F   ; ligne 5 plan A
; --- phase 5
        fcb   $00,$00,$0D,$00,$00,$0D,$00,$00,$0D   ; ligne 0 plan C
        fcb   $00,$DC,$C0,$00,$DC,$C0,$00,$DC,$C0   ; ligne 0 plan A
        fcb   $00,$00,$0D,$00,$00,$0D,$00,$00,$0D   ; ligne 1 plan C
        fcb   $00,$DC,$C0,$00,$DC,$C0,$00,$DC,$C0   ; ligne 1 plan A
        fcb   $00,$0D,$DD,$00,$0D,$DD,$00,$0D,$DD   ; ligne 2 plan C
        fcb   $00,$DC,$CD,$00,$DC,$CD,$00,$DC,$CD   ; ligne 2 plan A
        fcb   $00,$0D,$D7,$00,$0D,$D7,$00,$0D,$D7   ; ligne 3 plan C
        fcb   $00,$7A,$AD,$00,$7A,$AD,$00,$7A,$AD   ; ligne 3 plan A
        fcb   $00,$0C,$CC,$00,$0C,$CC,$00,$0C,$CC   ; ligne 4 plan C
        fcb   $00,$CF,$FC,$00,$CF,$FC,$00,$CF,$FC   ; ligne 4 plan A
        fcb   $00,$00,$0F,$00,$00,$0F,$00,$00,$0F   ; ligne 5 plan C
        fcb   $00,$FF,$F0,$00,$FF,$F0,$00,$FF,$F0   ; ligne 5 plan A
; --- phase 6
        fcb   $00,$00,$C0,$00,$00,$C0,$00,$00,$C0   ; ligne 0 plan C
        fcb   $00,$0D,$DC,$00,$0D,$DC,$00,$0D,$DC   ; ligne 0 plan A
        fcb   $00,$00,$C0,$00,$00,$C0,$00,$00,$C0   ; ligne 1 plan C
        fcb   $00,$0D,$DC,$00,$0D,$DC,$00,$0D,$DC   ; ligne 1 plan A
        fcb   $00,$00,$CD,$00,$00,$CD,$00,$00,$CD   ; ligne 2 plan C
        fcb   $00,$DD,$DC,$00,$DD,$DC,$00,$DD,$DC   ; ligne 2 plan A
        fcb   $00,$00,$AD,$00,$00,$AD,$00,$00,$AD   ; ligne 3 plan C
        fcb   $00,$D7,$7A,$00,$D7,$7A,$00,$D7,$7A   ; ligne 3 plan A
        fcb   $00,$00,$FC,$00,$00,$FC,$00,$00,$FC   ; ligne 4 plan C
        fcb   $00,$CC,$CF,$00,$CC,$CF,$00,$CC,$CF   ; ligne 4 plan A
        fcb   $00,$00,$F0,$00,$00,$F0,$00,$00,$F0   ; ligne 5 plan C
        fcb   $00,$0F,$FF,$00,$0F,$FF,$00,$0F,$FF   ; ligne 5 plan A
; --- phase 7
        fcb   $00,$00,$DC,$00,$00,$DC,$00,$00,$DC   ; ligne 0 plan C
        fcb   $00,$00,$0D,$00,$00,$0D,$00,$00,$0D   ; ligne 0 plan A
        fcb   $00,$00,$DC,$00,$00,$DC,$00,$00,$DC   ; ligne 1 plan C
        fcb   $00,$00,$0D,$00,$00,$0D,$00,$00,$0D   ; ligne 1 plan A
        fcb   $00,$00,$DC,$00,$00,$DC,$00,$00,$DC   ; ligne 2 plan C
        fcb   $00,$0D,$DD,$00,$0D,$DD,$00,$0D,$DD   ; ligne 2 plan A
        fcb   $00,$00,$7A,$00,$00,$7A,$00,$00,$7A   ; ligne 3 plan C
        fcb   $00,$0D,$D7,$00,$0D,$D7,$00,$0D,$D7   ; ligne 3 plan A
        fcb   $00,$00,$CF,$00,$00,$CF,$00,$00,$CF   ; ligne 4 plan C
        fcb   $00,$0C,$CC,$00,$0C,$CC,$00,$0C,$CC   ; ligne 4 plan A
        fcb   $00,$00,$FF,$00,$00,$FF,$00,$00,$FF   ; ligne 5 plan C
        fcb   $00,$00,$0F,$00,$00,$0F,$00,$00,$0F   ; ligne 5 plan A
; --- phase 8
        fcb   $00,$00,$0D,$00,$00,$0D,$00,$00,$0D   ; ligne 0 plan C
        fcb   $00,$00,$C0,$00,$00,$C0,$00,$00,$C0   ; ligne 0 plan A
        fcb   $00,$00,$0D,$00,$00,$0D,$00,$00,$0D   ; ligne 1 plan C
        fcb   $00,$00,$C0,$00,$00,$C0,$00,$00,$C0   ; ligne 1 plan A
        fcb   $00,$00,$DD,$00,$00,$DD,$00,$00,$DD   ; ligne 2 plan C
        fcb   $00,$00,$CD,$00,$00,$CD,$00,$00,$CD   ; ligne 2 plan A
        fcb   $00,$00,$D7,$00,$00,$D7,$00,$00,$D7   ; ligne 3 plan C
        fcb   $00,$00,$AD,$00,$00,$AD,$00,$00,$AD   ; ligne 3 plan A
        fcb   $00,$00,$CC,$00,$00,$CC,$00,$00,$CC   ; ligne 4 plan C
        fcb   $00,$00,$FC,$00,$00,$FC,$00,$00,$FC   ; ligne 4 plan A
        fcb   $00,$00,$0F,$00,$00,$0F,$00,$00,$0F   ; ligne 5 plan C
        fcb   $00,$00,$F0,$00,$00,$F0,$00,$00,$F0   ; ligne 5 plan A
; --- phase 9
        fcb   $00,$00,$00,$00,$00,$00,$00,$00,$00   ; ligne 0 plan C
        fcb   $00,$00,$DC,$00,$00,$DC,$00,$00,$DC   ; ligne 0 plan A
        fcb   $00,$00,$00,$00,$00,$00,$00,$00,$00   ; ligne 1 plan C
        fcb   $00,$00,$DC,$00,$00,$DC,$00,$00,$DC   ; ligne 1 plan A
        fcb   $00,$00,$0D,$00,$00,$0D,$00,$00,$0D   ; ligne 2 plan C
        fcb   $00,$00,$DC,$00,$00,$DC,$00,$00,$DC   ; ligne 2 plan A
        fcb   $00,$00,$0D,$00,$00,$0D,$00,$00,$0D   ; ligne 3 plan C
        fcb   $00,$00,$7A,$00,$00,$7A,$00,$00,$7A   ; ligne 3 plan A
        fcb   $00,$00,$0C,$00,$00,$0C,$00,$00,$0C   ; ligne 4 plan C
        fcb   $00,$00,$CF,$00,$00,$CF,$00,$00,$CF   ; ligne 4 plan A
        fcb   $00,$00,$00,$00,$00,$00,$00,$00,$00   ; ligne 5 plan C
        fcb   $00,$00,$FF,$00,$00,$FF,$00,$00,$FF   ; ligne 5 plan A
; --- phase 10
        fcb   $00,$00,$00,$00,$00,$00,$00,$00,$00   ; ligne 0 plan C
        fcb   $00,$00,$0D,$00,$00,$0D,$00,$00,$0D   ; ligne 0 plan A
        fcb   $00,$00,$00,$00,$00,$00,$00,$00,$00   ; ligne 1 plan C
        fcb   $00,$00,$0D,$00,$00,$0D,$00,$00,$0D   ; ligne 1 plan A
        fcb   $00,$00,$00,$00,$00,$00,$00,$00,$00   ; ligne 2 plan C
        fcb   $00,$00,$DD,$00,$00,$DD,$00,$00,$DD   ; ligne 2 plan A
        fcb   $00,$00,$00,$00,$00,$00,$00,$00,$00   ; ligne 3 plan C
        fcb   $00,$00,$D7,$00,$00,$D7,$00,$00,$D7   ; ligne 3 plan A
        fcb   $00,$00,$00,$00,$00,$00,$00,$00,$00   ; ligne 4 plan C
        fcb   $00,$00,$CC,$00,$00,$CC,$00,$00,$CC   ; ligne 4 plan A
        fcb   $00,$00,$00,$00,$00,$00,$00,$00,$00   ; ligne 5 plan C
        fcb   $00,$00,$0F,$00,$00,$0F,$00,$00,$0F   ; ligne 5 plan A
; --- phase 11
        fcb   $00,$00,$00,$00,$00,$00,$00,$00,$00   ; ligne 0 plan C
        fcb   $00,$00,$00,$00,$00,$00,$00,$00,$00   ; ligne 0 plan A
        fcb   $00,$00,$00,$00,$00,$00,$00,$00,$00   ; ligne 1 plan C
        fcb   $00,$00,$00,$00,$00,$00,$00,$00,$00   ; ligne 1 plan A
        fcb   $00,$00,$00,$00,$00,$00,$00,$00,$00   ; ligne 2 plan C
        fcb   $00,$00,$0D,$00,$00,$0D,$00,$00,$0D   ; ligne 2 plan A
        fcb   $00,$00,$00,$00,$00,$00,$00,$00,$00   ; ligne 3 plan C
        fcb   $00,$00,$0D,$00,$00,$0D,$00,$00,$0D   ; ligne 3 plan A
        fcb   $00,$00,$00,$00,$00,$00,$00,$00,$00   ; ligne 4 plan C
        fcb   $00,$00,$0C,$00,$00,$0C,$00,$00,$0C   ; ligne 4 plan A
        fcb   $00,$00,$00,$00,$00,$00,$00,$00,$00   ; ligne 5 plan C
        fcb   $00,$00,$00,$00,$00,$00,$00,$00,$00   ; ligne 5 plan A

; 12 phases x 6 lignes x 2 plans x 2 octets — les bords de plage
; (gauche, droite), ou un seul des deux pixels est de la gomme.
pellet.tbl.edge
; --- phase 0
        fcb   $0D,$0D   ; ligne 0 plan C
        fcb   $C0,$C0   ; ligne 0 plan A
        fcb   $0D,$0D   ; ligne 1 plan C
        fcb   $C0,$C0   ; ligne 1 plan A
        fcb   $DD,$DD   ; ligne 2 plan C
        fcb   $CD,$C0   ; ligne 2 plan A
        fcb   $D7,$D7   ; ligne 3 plan C
        fcb   $AD,$A0   ; ligne 3 plan A
        fcb   $CC,$CC   ; ligne 4 plan C
        fcb   $FC,$F0   ; ligne 4 plan A
        fcb   $0F,$0F   ; ligne 5 plan C
        fcb   $F0,$F0   ; ligne 5 plan A
; --- phase 1
        fcb   $00,$00   ; ligne 0 plan C
        fcb   $DC,$DC   ; ligne 0 plan A
        fcb   $00,$00   ; ligne 1 plan C
        fcb   $DC,$DC   ; ligne 1 plan A
        fcb   $0D,$0D   ; ligne 2 plan C
        fcb   $DC,$DC   ; ligne 2 plan A
        fcb   $0D,$0D   ; ligne 3 plan C
        fcb   $7A,$7A   ; ligne 3 plan A
        fcb   $0C,$0C   ; ligne 4 plan C
        fcb   $CF,$CF   ; ligne 4 plan A
        fcb   $00,$00   ; ligne 5 plan C
        fcb   $FF,$FF   ; ligne 5 plan A
; --- phase 2
        fcb   $00,$00   ; ligne 0 plan C
        fcb   $0D,$0D   ; ligne 0 plan A
        fcb   $00,$00   ; ligne 1 plan C
        fcb   $0D,$0D   ; ligne 1 plan A
        fcb   $00,$00   ; ligne 2 plan C
        fcb   $DD,$DD   ; ligne 2 plan A
        fcb   $00,$00   ; ligne 3 plan C
        fcb   $D7,$D7   ; ligne 3 plan A
        fcb   $00,$00   ; ligne 4 plan C
        fcb   $CC,$CC   ; ligne 4 plan A
        fcb   $00,$00   ; ligne 5 plan C
        fcb   $0F,$0F   ; ligne 5 plan A
; --- phase 3
        fcb   $00,$00   ; ligne 0 plan C
        fcb   $00,$00   ; ligne 0 plan A
        fcb   $00,$00   ; ligne 1 plan C
        fcb   $00,$00   ; ligne 1 plan A
        fcb   $00,$00   ; ligne 2 plan C
        fcb   $0D,$0D   ; ligne 2 plan A
        fcb   $00,$00   ; ligne 3 plan C
        fcb   $0D,$0D   ; ligne 3 plan A
        fcb   $00,$00   ; ligne 4 plan C
        fcb   $0C,$0C   ; ligne 4 plan A
        fcb   $00,$00   ; ligne 5 plan C
        fcb   $00,$00   ; ligne 5 plan A
; --- phase 4
        fcb   $00,$00   ; ligne 0 plan C
        fcb   $00,$00   ; ligne 0 plan A
        fcb   $00,$00   ; ligne 1 plan C
        fcb   $00,$00   ; ligne 1 plan A
        fcb   $00,$00   ; ligne 2 plan C
        fcb   $00,$00   ; ligne 2 plan A
        fcb   $00,$00   ; ligne 3 plan C
        fcb   $00,$00   ; ligne 3 plan A
        fcb   $00,$00   ; ligne 4 plan C
        fcb   $00,$00   ; ligne 4 plan A
        fcb   $00,$00   ; ligne 5 plan C
        fcb   $00,$00   ; ligne 5 plan A
; --- phase 5
        fcb   $00,$00   ; ligne 0 plan C
        fcb   $00,$00   ; ligne 0 plan A
        fcb   $00,$00   ; ligne 1 plan C
        fcb   $00,$00   ; ligne 1 plan A
        fcb   $00,$00   ; ligne 2 plan C
        fcb   $00,$00   ; ligne 2 plan A
        fcb   $00,$00   ; ligne 3 plan C
        fcb   $00,$00   ; ligne 3 plan A
        fcb   $00,$00   ; ligne 4 plan C
        fcb   $00,$00   ; ligne 4 plan A
        fcb   $00,$00   ; ligne 5 plan C
        fcb   $00,$00   ; ligne 5 plan A
; --- phase 6
        fcb   $00,$00   ; ligne 0 plan C
        fcb   $00,$00   ; ligne 0 plan A
        fcb   $00,$00   ; ligne 1 plan C
        fcb   $00,$00   ; ligne 1 plan A
        fcb   $00,$00   ; ligne 2 plan C
        fcb   $00,$00   ; ligne 2 plan A
        fcb   $00,$00   ; ligne 3 plan C
        fcb   $00,$00   ; ligne 3 plan A
        fcb   $00,$00   ; ligne 4 plan C
        fcb   $00,$00   ; ligne 4 plan A
        fcb   $00,$00   ; ligne 5 plan C
        fcb   $00,$00   ; ligne 5 plan A
; --- phase 7
        fcb   $00,$00   ; ligne 0 plan C
        fcb   $00,$00   ; ligne 0 plan A
        fcb   $00,$00   ; ligne 1 plan C
        fcb   $00,$00   ; ligne 1 plan A
        fcb   $00,$00   ; ligne 2 plan C
        fcb   $00,$00   ; ligne 2 plan A
        fcb   $00,$00   ; ligne 3 plan C
        fcb   $00,$00   ; ligne 3 plan A
        fcb   $00,$00   ; ligne 4 plan C
        fcb   $00,$00   ; ligne 4 plan A
        fcb   $00,$00   ; ligne 5 plan C
        fcb   $00,$00   ; ligne 5 plan A
; --- phase 8
        fcb   $00,$00   ; ligne 0 plan C
        fcb   $00,$00   ; ligne 0 plan A
        fcb   $00,$00   ; ligne 1 plan C
        fcb   $00,$00   ; ligne 1 plan A
        fcb   $00,$00   ; ligne 2 plan C
        fcb   $00,$00   ; ligne 2 plan A
        fcb   $00,$00   ; ligne 3 plan C
        fcb   $00,$00   ; ligne 3 plan A
        fcb   $00,$00   ; ligne 4 plan C
        fcb   $00,$00   ; ligne 4 plan A
        fcb   $00,$00   ; ligne 5 plan C
        fcb   $00,$00   ; ligne 5 plan A
; --- phase 9
        fcb   $00,$00   ; ligne 0 plan C
        fcb   $00,$00   ; ligne 0 plan A
        fcb   $00,$00   ; ligne 1 plan C
        fcb   $00,$00   ; ligne 1 plan A
        fcb   $00,$00   ; ligne 2 plan C
        fcb   $00,$00   ; ligne 2 plan A
        fcb   $00,$00   ; ligne 3 plan C
        fcb   $00,$00   ; ligne 3 plan A
        fcb   $00,$00   ; ligne 4 plan C
        fcb   $00,$00   ; ligne 4 plan A
        fcb   $00,$00   ; ligne 5 plan C
        fcb   $00,$00   ; ligne 5 plan A
; --- phase 10
        fcb   $00,$00   ; ligne 0 plan C
        fcb   $00,$00   ; ligne 0 plan A
        fcb   $00,$00   ; ligne 1 plan C
        fcb   $00,$00   ; ligne 1 plan A
        fcb   $00,$00   ; ligne 2 plan C
        fcb   $00,$00   ; ligne 2 plan A
        fcb   $00,$00   ; ligne 3 plan C
        fcb   $00,$00   ; ligne 3 plan A
        fcb   $00,$00   ; ligne 4 plan C
        fcb   $00,$00   ; ligne 4 plan A
        fcb   $00,$00   ; ligne 5 plan C
        fcb   $00,$00   ; ligne 5 plan A
; --- phase 11
        fcb   $00,$00   ; ligne 0 plan C
        fcb   $00,$00   ; ligne 0 plan A
        fcb   $00,$00   ; ligne 1 plan C
        fcb   $00,$00   ; ligne 1 plan A
        fcb   $00,$00   ; ligne 2 plan C
        fcb   $00,$00   ; ligne 2 plan A
        fcb   $00,$00   ; ligne 3 plan C
        fcb   $00,$00   ; ligne 3 plan A
        fcb   $00,$00   ; ligne 4 plan C
        fcb   $00,$00   ; ligne 4 plan A
        fcb   $00,$00   ; ligne 5 plan C
        fcb   $00,$00   ; ligne 5 plan A
