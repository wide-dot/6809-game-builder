; ---------------------------------------------------------------------------
; LA CASCADE DE MORT DU NOYAU DU VAISSEAU — table GENEREE, ne pas editer
; ---------------------------------------------------------------------------
; Rejeu : python3 tools/gen_core_death.py (depuis games/r-type/).
; Une entree = {dx, dy, subtype} : deux octets signes a ajouter a la
; position de l'enfant, puis le subtype d'explosion (animation + son).
; Une entree toutes les bosscascade.PERIOD (8) trames video ; la borne
; en jouait une toutes les 4 trames sur sa liste de 23 offsets qui boucle
; (0x1000:80CE), 320 trames — ici un spawn sur 2. Fin de table : $80.

; le pas du marcheur, en trames video : la table est echantillonnee dessus
bosscascade.PERIOD equ 8
bosscascade.SMALL equ explosion.subtype.smallx3+explosion.sfx.cascade
bosscascade.BIG   equ explosion.subtype.big.brown+explosion.sfx.cascade

bosscascade.table
        fcb   $FA,$00,bosscascade.BIG     ; t=  0  arcade  -16,  +0 (#0)
        fcb   $06,$FD,bosscascade.SMALL   ; t=  8  arcade  +16,  +4 (#2)
        fcb   $18,$F4,bosscascade.SMALL   ; t= 16  arcade  +64, +16 (#4)
        fcb   $39,$DC,bosscascade.BIG     ; t= 24  arcade +152, +48 (#6)
        fcb   $30,$EE,bosscascade.BIG     ; t= 32  arcade +128, +24 (#8)
        fcb   $15,$DC,bosscascade.SMALL   ; t= 40  arcade  +56, +48 (#10)
        fcb   $F1,$12,bosscascade.SMALL   ; t= 48  arcade  -40, -24 (#12)
        fcb   $0C,$F4,bosscascade.SMALL   ; t= 56  arcade  +32, +16 (#14)
        fcb   $27,$D0,bosscascade.SMALL   ; t= 64  arcade +104, +64 (#16)
        fcb   $36,$FD,bosscascade.SMALL   ; t= 72  arcade +144,  +4 (#18)
        fcb   $48,$EE,bosscascade.SMALL   ; t= 80  arcade +192, +24 (#20)
        fcb   $0C,$1E,bosscascade.SMALL   ; t= 88  arcade  +32, -40 (#22)
        fcb   $03,$02,bosscascade.BIG     ; t= 96  arcade   +8,  -2 (#1)
        fcb   $0A,$03,bosscascade.SMALL   ; t=104  arcade  +28,  -4 (#3)
        fcb   $1E,$24,bosscascade.BIG     ; t=112  arcade  +80, -48 (#5)
        fcb   $0C,$0C,bosscascade.SMALL   ; t=120  arcade  +32, -16 (#7)
        fcb   $F4,$30,bosscascade.SMALL   ; t=128  arcade  -32, -64 (#9)
        fcb   $2D,$06,bosscascade.SMALL   ; t=136  arcade +120,  -8 (#11)
        fcb   $18,$30,bosscascade.BIG     ; t=144  arcade  +64, -64 (#13)
        fcb   $2A,$24,bosscascade.BIG     ; t=152  arcade +112, -48 (#15)
        fcb   $00,$18,bosscascade.SMALL   ; t=160  arcade   +0, -32 (#17)
        fcb   $00,$36,bosscascade.SMALL   ; t=168  arcade   +0, -72 (#19)
        fcb   $21,$E8,bosscascade.BIG     ; t=176  arcade  +88, +32 (#21)
        fcb   $FA,$00,bosscascade.SMALL   ; t=184  arcade  -16,  +0 (#0)
        fcb   $06,$FD,bosscascade.SMALL   ; t=192  arcade  +16,  +4 (#2)
        fcb   $18,$F4,bosscascade.SMALL   ; t=200  arcade  +64, +16 (#4)
        fcb   $39,$DC,bosscascade.SMALL   ; t=208  arcade +152, +48 (#6)
        fcb   $30,$EE,bosscascade.SMALL   ; t=216  arcade +128, +24 (#8)
        fcb   $15,$DC,bosscascade.SMALL   ; t=224  arcade  +56, +48 (#10)
        fcb   $F1,$12,bosscascade.SMALL   ; t=232  arcade  -40, -24 (#12)
        fcb   $0C,$F4,bosscascade.SMALL   ; t=240  arcade  +32, +16 (#14)
        fcb   $27,$D0,bosscascade.SMALL   ; t=248  arcade +104, +64 (#16)
        fcb   $36,$FD,bosscascade.SMALL   ; t=256  arcade +144,  +4 (#18)
        fcb   $48,$EE,bosscascade.SMALL   ; t=264  arcade +192, +24 (#20)
        fcb   $0C,$1E,bosscascade.SMALL   ; t=272  arcade  +32, -40 (#22)
        fcb   $03,$02,bosscascade.SMALL   ; t=280  arcade   +8,  -2 (#1)
        fcb   $0A,$03,bosscascade.BIG     ; t=288  arcade  +28,  -4 (#3)
        fcb   $1E,$24,bosscascade.SMALL   ; t=296  arcade  +80, -48 (#5)
        fcb   $0C,$0C,bosscascade.SMALL   ; t=304  arcade  +32, -16 (#7)
        fcb   $F4,$30,bosscascade.SMALL   ; t=312  arcade  -32, -64 (#9)
        fcb   $80
