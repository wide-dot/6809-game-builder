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
        fcb   $12,$0C,bosscascade.SMALL   ; t= 16  arcade  +48, -16 (5542)
        fcb   $E5,$30,bosscascade.SMALL   ; t= 24  arcade  -72, -64 (5582)
        fcb   $18,$2A,bosscascade.SMALL   ; t= 32  arcade  +64, -56 (557E)
        fcb   $D9,$36,bosscascade.BIG     ; t= 40  arcade -104, -72 (54F2)
        fcb   $F4,$06,bosscascade.SMALL   ; t= 48  arcade  -32,  -8 (5526)
        fcb   $0C,$18,bosscascade.SMALL   ; t= 56  arcade  +32, -32 (5556)
        fcb   $F8,$3C,bosscascade.SMALL   ; t= 64  arcade  -20, -80 (55B6)
        fcb   $27,$36,bosscascade.BIG     ; t= 72  arcade +104, -72 (551A)
        fcb   $18,$3C,bosscascade.BIG     ; t= 80  arcade  +64, -80 (55A6)
        fcb   $E2,$54,bosscascade.SMALL   ; t= 88  arcade  -80,-112 (55E6)
        fcb   $01,$27,bosscascade.SMALL   ; t= 96  arcade   +2, -52 (556A)
        fcb   $E5,$F4,bosscascade.SMALL   ; t=104  arcade  -72, +16 (54F6)
        fcb   $03,$18,bosscascade.BIG     ; t=112  arcade   +8, -32 (5552)
        fcb   $D6,$4E,bosscascade.BIG     ; t=120  arcade -112,-104 (55D2)
        fcb   $E5,$00,bosscascade.SMALL   ; t=128  arcade  -72,  +0 (550A)
        fcb   $27,$36,bosscascade.SMALL   ; t=136  arcade +104, -72 (551A)
        fcb   $00,$1E,bosscascade.SMALL   ; t=144  arcade   +0, -40 (555E)
        fcb   $2D,$36,bosscascade.SMALL   ; t=152  arcade +120, -72 (551E)
        fcb   $F7,$36,bosscascade.SMALL   ; t=160  arcade  -24, -72 (5572)
        fcb   $E5,$F4,bosscascade.BIG     ; t=168  arcade  -72, +16 (54F6)
        fcb   $EC,$3C,bosscascade.SMALL   ; t=176  arcade  -52, -80 (559E)
        fcb   $15,$4A,bosscascade.SMALL   ; t=184  arcade  +56, -99 (55E2)
        fcb   $15,$F7,bosscascade.SMALL   ; t=192  arcade  +56, +12 (5512)
        fcb   $E8,$0C,bosscascade.BIG     ; t=200  arcade  -64, -16 (5532)
        fcb   $D3,$36,bosscascade.SMALL   ; t=208  arcade -120, -72 (5506)
        fcb   $2D,$36,bosscascade.SMALL   ; t=216  arcade +120, -72 (551E)
        fcb   $E5,$30,bosscascade.SMALL   ; t=224  arcade  -72, -64 (5582)
        fcb   $18,$18,bosscascade.SMALL   ; t=232  arcade  +64, -32 (555A)
        fcb   $2A,$3C,bosscascade.SMALL   ; t=240  arcade +112, -80 (54FE)
        fcb   $21,$3C,bosscascade.BIG     ; t=248  arcade  +88, -80 (55AA)
        fcb   $E5,$00,bosscascade.BIG     ; t=256  arcade  -72,  +0 (550A)
        fcb   $F7,$54,bosscascade.SMALL   ; t=264  arcade  -24,-112 (55EE)
        fcb   $EB,$FA,bosscascade.SMALL   ; t=272  arcade  -56,  +8 (550E)
        fcb   $10,$42,bosscascade.SMALL   ; t=280  arcade  +44, -88 (55BE)
        fcb   $03,$18,bosscascade.SMALL   ; t=288  arcade   +8, -32 (5552)
        fcb   $D9,$36,bosscascade.SMALL   ; t=296  arcade -104, -72 (54F2)
        fcb   $2A,$3C,bosscascade.SMALL   ; t=304  arcade +112, -80 (54FE)
        fcb   $EE,$0C,bosscascade.SMALL   ; t=312  arcade  -48, -16 (5536)
        fcb   $D6,$42,bosscascade.SMALL   ; t=320  arcade -112, -88 (5502)
        fcb   $0F,$24,bosscascade.SMALL   ; t=328  arcade  +40, -48 (556E)
        fcb   $0F,$30,bosscascade.SMALL   ; t=336  arcade  +40, -64 (5586)
        fcb   $FA,$06,bosscascade.SMALL   ; t=344  arcade  -16,  -8 (552A)
        fcb   $80
