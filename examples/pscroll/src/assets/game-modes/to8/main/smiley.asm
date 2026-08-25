;******************************************************************************
; Le smiley du banc — GENERE par tools/gen_smiley.py, ne pas editer.
;
; 32 cellules x 30 rangees, bit 7 = la cellule la plus a gauche. Le banc
; le dessine une rangee par trame en appelant pscroll.setCell, puis
; l'efface de la meme facon : c'est la mire des deux chemins de mutation.
;******************************************************************************
bench.smiley.W equ 32
bench.smiley.H equ 30
bench.smiley
        fcb   $00,$03,$C0,$00
        fcb   $00,$3F,$FC,$00
        fcb   $00,$FF,$FF,$00
        fcb   $01,$FF,$FF,$80
        fcb   $03,$FF,$FF,$C0
        fcb   $07,$FF,$FF,$E0
        fcb   $0F,$FF,$FF,$F0
        fcb   $1F,$FF,$FF,$F8
        fcb   $1F,$FF,$FF,$F8
        fcb   $3F,$FF,$FF,$FC
        fcb   $3F,$CF,$F3,$FC
        fcb   $3F,$CF,$F3,$FC
        fcb   $3F,$FF,$FF,$FC
        fcb   $7F,$FF,$FF,$FE
        fcb   $7F,$FF,$FF,$FE
        fcb   $7E,$7F,$FE,$7E
        fcb   $7F,$7F,$FE,$FE
        fcb   $3F,$3F,$FC,$FC
        fcb   $3F,$9F,$F9,$FC
        fcb   $3F,$CF,$F3,$FC
        fcb   $3F,$E3,$C7,$FC
        fcb   $1F,$F0,$0F,$F8
        fcb   $1F,$FF,$FF,$F8
        fcb   $0F,$FF,$FF,$F0
        fcb   $07,$FF,$FF,$E0
        fcb   $03,$FF,$FF,$C0
        fcb   $01,$FF,$FF,$80
        fcb   $00,$FF,$FF,$00
        fcb   $00,$3F,$FC,$00
        fcb   $00,$03,$C0,$00
