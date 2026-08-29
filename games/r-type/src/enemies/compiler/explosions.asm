; ---------------------------------------------------------------------------
; LES CHAPELETS D'EXPLOSION DU COMPILER — table GENEREE, ne pas editer
; ---------------------------------------------------------------------------
; Rejeu : python3 tools/gen_compiler_death.py (depuis games/r-type/).
; Une entree = deux octets signes {dx, dy}, a ajouter au centre de la piece.
; L'ordre est celui de la borne : c'est lui qui dessine la forme du nuage.

cpl.boom.right
        fcb   $00,$00          ; arcade   +0,  +0
        fcb   $0C,$E2          ; arcade  +32, +40
        fcb   $18,$FA          ; arcade  +64,  +8
        fcb   $0C,$EE          ; arcade  +32, +24
        fcb   $03,$DC          ; arcade   +8, +48
        fcb   $09,$00          ; arcade  +24,  +0
        fcb   $18,$DC          ; arcade  +64, +48
        fcb   $0F,$06          ; arcade  +40,  -8
        fcb   $00,$EE          ; arcade   +0, +24
        fcb   $0F,$D6          ; arcade  +40, +56
        fcb   $1B,$F4          ; arcade  +72, +16
        fcb   $06,$E8          ; arcade  +16, +32
        fcb   $12,$00          ; arcade  +48,  +0
        fcb   $09,$D6          ; arcade  +24, +56
        fcb   $18,$E8          ; arcade  +64, +32
        fcb   $03,$06          ; arcade   +8,  -8
        fcb   $00,$E2          ; arcade   +0, +40
        fcb   $18,$06          ; arcade  +64,  -8
        fcb   $06,$F4          ; arcade  +16, +16
        fcb   $12,$EE          ; arcade  +48, +24
        fcb   $00,$FA          ; arcade   +0,  +8
        fcb   $12,$E2          ; arcade  +48, +40
        fcb   $0F,$FA          ; arcade  +40,  +8

cpl.boom.bottom
        fcb   $06,$0C          ; arcade  +16, -16
        fcb   $F4,$06          ; arcade  -32,  -8
        fcb   $03,$2A          ; arcade   +8, -56
        fcb   $FA,$1E          ; arcade  -16, -40
        fcb   $EE,$24          ; arcade  -48, -48
        fcb   $F7,$36          ; arcade  -24, -72
        fcb   $FA,$00          ; arcade  -16,  +0
        fcb   $09,$18          ; arcade  +24, -32
        fcb   $09,$36          ; arcade  +24, -72
        fcb   $00,$12          ; arcade   +0, -24
        fcb   $FA,$2A          ; arcade  -16, -56
        fcb   $F1,$00          ; arcade  -40,  +0
        fcb   $03,$1E          ; arcade   +8, -40
        fcb   $F4,$2A          ; arcade  -32, -56
        fcb   $F4,$12          ; arcade  -32, -24
        fcb   $09,$06          ; arcade  +24,  -8
        fcb   $FD,$30          ; arcade   -8, -64
        fcb   $0C,$2A          ; arcade  +32, -56
        fcb   $F4,$1E          ; arcade  -32, -40
        fcb   $03,$06          ; arcade   +8,  -8
        fcb   $FA,$0C          ; arcade  -16, -16

cpl.boom.left
        fcb   $F1,$00          ; arcade  -40,  +0
        fcb   $FD,$E2          ; arcade   -8, +40
        fcb   $E8,$F4          ; arcade  -64, +16
        fcb   $03,$00          ; arcade   +8,  +0
        fcb   $EE,$DC          ; arcade  -48, +48
        fcb   $F7,$EE          ; arcade  -24, +24
        fcb   $E5,$E2          ; arcade  -72, +40
        fcb   $03,$EE          ; arcade   +8, +24
        fcb   $F1,$E8          ; arcade  -40, +32
        fcb   $E5,$00          ; arcade  -72,  +0
        fcb   $FA,$FA          ; arcade  -16,  +8
        fcb   $E5,$EE          ; arcade  -72, +24
        fcb   $F7,$DC          ; arcade  -24, +48
        fcb   $03,$DC          ; arcade   +8, +48
        fcb   $FD,$EE          ; arcade   -8, +24
        fcb   $EE,$F4          ; arcade  -48, +16
        fcb   $F7,$00          ; arcade  -24,  +0
        fcb   $EB,$00          ; arcade  -56,  +0
        fcb   $EB,$E8          ; arcade  -56, +32
        fcb   $F1,$DC          ; arcade  -40, +48
        fcb   $F4,$F4          ; arcade  -32, +16
        fcb   $06,$E2          ; arcade  +16, +40

; Le nombre d'entrees de chaque liste, dans l'ordre des pieces
; (droite, bas, gauche) — le marcheur s'y arrete.
cpl.boom.count
        fcb   23,21,22

cpl.boom.index
        fdb   cpl.boom.right,cpl.boom.bottom,cpl.boom.left
