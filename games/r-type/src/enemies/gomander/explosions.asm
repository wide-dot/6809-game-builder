; ---------------------------------------------------------------------------
; LA CASCADE DE MORT DU GOMANDER — table GENEREE, ne pas editer
; ---------------------------------------------------------------------------
; Rejeu : python3 tools/gen_gomander_death.py (depuis games/r-type/).
; Une entree = {dx, dy, subtype} : deux octets signes a ajouter a la
; position de l'enfant, puis le subtype d'explosion (animation + son).
; Une entree toutes les bosscascade.PERIOD (8) trames video ; la borne
; en jouait une par trame paire (0x1000:5602, 176 des 288 lues) — ici
; un spawn sur 4, pour 8 images par seconde. Fin de table : $80.

; le pas du marcheur, en trames video : la table est echantillonnee dessus
bosscascade.PERIOD equ 8
bosscascade.SMALL equ explosion.subtype.smallx3+explosion.sfx.cascade
bosscascade.BIG   equ explosion.subtype.big.brown+explosion.sfx.cascade

bosscascade.table
        fcb   $F4,$1B,bosscascade.BIG     ; t=  0  arcade  -32, -36 (554A)
        fcb   $27,$36,bosscascade.BIG     ; t=  8  arcade +104, -72 (551A)
        fcb   $21,$3C,bosscascade.SMALL   ; t= 16  arcade  +88, -80 (55AA)
        fcb   $1B,$03,bosscascade.SMALL   ; t= 24  arcade  +72,  -4 (5516)
        fcb   $E8,$0C,bosscascade.SMALL   ; t= 32  arcade  -64, -16 (5532)
        fcb   $06,$FD,bosscascade.BIG     ; t= 40  arcade  +16,  +4 (5522)
        fcb   $2A,$3C,bosscascade.SMALL   ; t= 48  arcade +112, -80 (54FE)
        fcb   $0F,$30,bosscascade.SMALL   ; t= 56  arcade  +40, -64 (5586)
        fcb   $F8,$3C,bosscascade.SMALL   ; t= 64  arcade  -20, -80 (55B6)
        fcb   $27,$36,bosscascade.BIG     ; t= 72  arcade +104, -72 (551A)
        fcb   $18,$3C,bosscascade.BIG     ; t= 80  arcade  +64, -80 (55A6)
        fcb   $1B,$03,bosscascade.SMALL   ; t= 88  arcade  +72,  -4 (5516)
        fcb   $01,$27,bosscascade.SMALL   ; t= 96  arcade   +2, -52 (556A)
        fcb   $EE,$54,bosscascade.SMALL   ; t=104  arcade  -48,-112 (55EA)
        fcb   $2A,$3C,bosscascade.BIG     ; t=112  arcade +112, -80 (54FE)
        fcb   $2A,$48,bosscascade.BIG     ; t=120  arcade +112, -96 (55CE)
        fcb   $0F,$24,bosscascade.SMALL   ; t=128  arcade  +40, -48 (556E)
        fcb   $27,$36,bosscascade.SMALL   ; t=136  arcade +104, -72 (551A)
        fcb   $00,$1E,bosscascade.SMALL   ; t=144  arcade   +0, -40 (555E)
        fcb   $1B,$03,bosscascade.SMALL   ; t=152  arcade  +72,  -4 (5516)
        fcb   $E8,$18,bosscascade.SMALL   ; t=160  arcade  -64, -32 (5546)
        fcb   $06,$48,bosscascade.BIG     ; t=168  arcade  +16, -96 (55AE)
        fcb   $2A,$3C,bosscascade.SMALL   ; t=176  arcade +112, -80 (54FE)
        fcb   $18,$2A,bosscascade.SMALL   ; t=184  arcade  +64, -56 (557E)
        fcb   $2A,$48,bosscascade.SMALL   ; t=192  arcade +112, -96 (55CE)
        fcb   $27,$36,bosscascade.BIG     ; t=200  arcade +104, -72 (551A)
        fcb   $06,$FD,bosscascade.SMALL   ; t=208  arcade  +16,  +4 (5522)
        fcb   $1B,$03,bosscascade.SMALL   ; t=216  arcade  +72,  -4 (5516)
        fcb   $E5,$30,bosscascade.SMALL   ; t=224  arcade  -72, -64 (5582)
        fcb   $18,$18,bosscascade.SMALL   ; t=232  arcade  +64, -32 (555A)
        fcb   $2A,$3C,bosscascade.SMALL   ; t=240  arcade +112, -80 (54FE)
        fcb   $FD,$2A,bosscascade.BIG     ; t=248  arcade   -8, -56 (5576)
        fcb   $12,$0C,bosscascade.BIG     ; t=256  arcade  +48, -16 (5542)
        fcb   $27,$36,bosscascade.SMALL   ; t=264  arcade +104, -72 (551A)
        fcb   $30,$4E,bosscascade.SMALL   ; t=272  arcade +128,-104 (55D6)
        fcb   $1B,$03,bosscascade.SMALL   ; t=280  arcade  +72,  -4 (5516)
        fcb   $24,$54,bosscascade.SMALL   ; t=288  arcade  +96,-112 (55FE)
        fcb   $0C,$06,bosscascade.SMALL   ; t=296  arcade  +32,  -8 (552E)
        fcb   $2A,$3C,bosscascade.SMALL   ; t=304  arcade +112, -80 (54FE)
        fcb   $06,$2A,bosscascade.SMALL   ; t=312  arcade  +16, -56 (557A)
        fcb   $01,$27,bosscascade.SMALL   ; t=320  arcade   +2, -52 (556A)
        fcb   $27,$36,bosscascade.SMALL   ; t=328  arcade +104, -72 (551A)
        fcb   $0F,$30,bosscascade.SMALL   ; t=336  arcade  +40, -64 (5586)
        fcb   $1B,$03,bosscascade.SMALL   ; t=344  arcade  +72,  -4 (5516)
        fcb   $80
