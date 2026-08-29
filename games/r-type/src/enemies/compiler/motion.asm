; ---------------------------------------------------------------------------
; LES SCRIPTS DE COMBAT DU COMPILER — table GENEREE, ne pas editer
; ---------------------------------------------------------------------------
; Rejeu : python3 tools/gen_compiler_motion.py (depuis games/r-type/).
; Un segment = {vx:word, vy:word, duree:word}, vitesses en 8.8 v2.
; vx = $8000 : fin du script, passer au suivant de la config.
; (vx = $0000 est un mouvement VERTICAL PUR, pas une fin.)

cpl.mot.right_a
        fdb   $0000,$0018,256   ; arcade    +0,  -32,256
        fdb   $FFB8,$0000,256   ; arcade  -192,   +0,256
        fdb   $0048,$FFBE,256   ; arcade  +192,  +88,256
        fdb   $FFD9,$002A,256   ; arcade  -104,  -56,256
        fdb   $0015,$FFD6,256   ; arcade   +56,  +56,256
        fdb   $0012,$0000,256   ; arcade   +48,   +0,256
        fdb   $0000,$0000,8     ; arcade    +0,   +0,8
        fdb   $FFD9,$0042,256   ; arcade  -104,  -88,256
        fdb   $FFCA,$002A,256   ; arcade  -144,  -56,256
        fdb   $0015,$000C,256   ; arcade   +56,  -16,256
        fdb   $0048,$FFB2,256   ; arcade  +192, +104,256
        fdb   $FFD9,$FFD6,256   ; arcade  -104,  +56,256
        fdb   $FFDF,$0000,256   ; arcade   -88,   +0,256
        fdb   $0048,$0042,256   ; arcade  +192,  -88,256
        fdb   $FFB8,$0000,256   ; arcade  -192,   +0,256
        fdb   $0021,$FFBE,256   ; arcade   +88,  +88,256
        fdb   $0027,$002A,256   ; arcade  +104,  -56,256
        fdb   $8000,0,0        ; fin : script suivant

cpl.mot.bottom_a
        fdb   $0000,$0018,256   ; arcade    +0,  -32,256
        fdb   $FFB8,$0000,256   ; arcade  -192,   +0,256
        fdb   $0048,$FFBE,256   ; arcade  +192,  +88,256
        fdb   $FFD9,$002A,256   ; arcade  -104,  -56,256
        fdb   $0015,$FFD6,256   ; arcade   +56,  +56,256
        fdb   $0000,$0042,256   ; arcade    +0,  -88,256
        fdb   $FFEB,$FFA0,256   ; arcade   -56, +128,256
        fdb   $FFD9,$0000,256   ; arcade  -104,   +0,256
        fdb   $0000,$0000,8     ; arcade    +0,   +0,8
        fdb   $FFF1,$001E,256   ; arcade   -40,  -40,256
        fdb   $0015,$0042,256   ; arcade   +56,  -88,256
        fdb   $0000,$FFE8,256   ; arcade    +0,  +32,256
        fdb   $0000,$FFD6,256   ; arcade    +0,  +56,256
        fdb   $0048,$0042,256   ; arcade  +192,  -88,256
        fdb   $FFB8,$0000,256   ; arcade  -192,   +0,256
        fdb   $0021,$FFBE,256   ; arcade   +88,  +88,256
        fdb   $0027,$002A,256   ; arcade  +104,  -56,256
        fdb   $8000,0,0        ; fin : script suivant

cpl.mot.left_a
        fdb   $0000,$0018,256   ; arcade    +0,  -32,256
        fdb   $FFB8,$0000,256   ; arcade  -192,   +0,256
        fdb   $0048,$FFBE,256   ; arcade  +192,  +88,256
        fdb   $FFD9,$002A,256   ; arcade  -104,  -56,256
        fdb   $0015,$FFD6,256   ; arcade   +56,  +56,256
        fdb   $FFCA,$0000,256   ; arcade  -144,   +0,256
        fdb   $0000,$0078,256   ; arcade    +0, -160,256
        fdb   $005D,$0000,256   ; arcade  +248,   +0,256
        fdb   $0000,$FFCA,256   ; arcade    +0,  +72,256
        fdb   $FFD9,$FFBE,256   ; arcade  -104,  +88,256
        fdb   $FFCA,$0000,256   ; arcade  -144,   +0,256
        fdb   $0000,$0000,8     ; arcade    +0,   +0,8
        fdb   $0000,$0000,8     ; arcade    +0,   +0,8
        fdb   $0048,$0042,256   ; arcade  +192,  -88,256
        fdb   $FFB8,$0000,256   ; arcade  -192,   +0,256
        fdb   $0021,$FFBE,256   ; arcade   +88,  +88,256
        fdb   $0027,$002A,256   ; arcade  +104,  -56,256
        fdb   $8000,0,0        ; fin : script suivant

cpl.mot.right_b
        fdb   $0000,$FFD6,256   ; arcade    +0,  +56,256
        fdb   $FFB8,$0000,256   ; arcade  -192,   +0,256
        fdb   $0000,$002A,256   ; arcade    +0,  -56,256
        fdb   $0048,$0018,256   ; arcade  +192,  -32,256
        fdb   $FFD9,$FFBE,256   ; arcade  -104,  +88,256
        fdb   $0027,$0042,256   ; arcade  +104,  -88,256
        fdb   $FFEE,$FFBE,256   ; arcade   -48,  +88,256
        fdb   $FFCA,$002A,256   ; arcade  -144,  -56,256
        fdb   $0000,$FFD6,256   ; arcade    +0,  +56,256
        fdb   $FFEB,$0000,256   ; arcade   -56,   +0,256
        fdb   $0015,$0000,256   ; arcade   +56,   +0,256
        fdb   $0048,$0000,256   ; arcade  +192,   +0,256
        fdb   $0000,$002A,256   ; arcade    +0,  -56,256
        fdb   $FFD9,$0000,256   ; arcade  -104,   +0,256
        fdb   $0000,$FFD6,256   ; arcade    +0,  +56,256
        fdb   $0027,$0000,256   ; arcade  +104,   +0,256
        fdb   $0000,$002A,256   ; arcade    +0,  -56,256
        fdb   $8000,0,0        ; fin : script suivant

cpl.mot.bottom_b
        fdb   $0000,$0018,256   ; arcade    +0,  -32,256
        fdb   $FFB8,$0000,256   ; arcade  -192,   +0,256
        fdb   $0000,$FFE8,256   ; arcade    +0,  +32,256
        fdb   $0048,$0018,256   ; arcade  +192,  -32,256
        fdb   $FFD9,$FFBE,256   ; arcade  -104,  +88,256
        fdb   $0027,$0042,256   ; arcade  +104,  -88,256
        fdb   $FFEE,$FFBE,256   ; arcade   -48,  +88,256
        fdb   $FFCA,$002A,256   ; arcade  -144,  -56,256
        fdb   $0000,$0018,256   ; arcade    +0,  -32,256
        fdb   $0048,$0000,256   ; arcade  +192,   +0,256
        fdb   $0000,$0000,8     ; arcade    +0,   +0,8
        fdb   $FFB8,$0000,256   ; arcade  -192,   +0,256
        fdb   $0000,$FFE8,256   ; arcade    +0,  +32,256
        fdb   $0021,$0000,256   ; arcade   +88,   +0,256
        fdb   $0000,$0018,256   ; arcade    +0,  -32,256
        fdb   $0027,$0000,256   ; arcade  +104,   +0,256
        fdb   $0000,$FFE8,256   ; arcade    +0,  +32,256
        fdb   $8000,0,0        ; fin : script suivant

cpl.mot.left_b
        fdb   $0000,$FFD6,256   ; arcade    +0,  +56,256
        fdb   $FFB8,$0000,256   ; arcade  -192,   +0,256
        fdb   $0000,$002A,256   ; arcade    +0,  -56,256
        fdb   $0048,$0018,256   ; arcade  +192,  -32,256
        fdb   $FFD9,$FFBE,256   ; arcade  -104,  +88,256
        fdb   $FFDF,$0000,256   ; arcade   -88,   +0,256
        fdb   $0000,$0078,256   ; arcade    +0, -160,256
        fdb   $005D,$0000,256   ; arcade  +248,   +0,256
        fdb   $0000,$FFCA,256   ; arcade    +0,  +72,256
        fdb   $FFEB,$FFE8,256   ; arcade   -56,  +32,256
        fdb   $0000,$0018,256   ; arcade    +0,  -32,256
        fdb   $FFB8,$0000,256   ; arcade  -192,   +0,256
        fdb   $0000,$FFE8,256   ; arcade    +0,  +32,256
        fdb   $0021,$0000,256   ; arcade   +88,   +0,256
        fdb   $0000,$FFD6,256   ; arcade    +0,  +56,256
        fdb   $0027,$0000,256   ; arcade  +104,   +0,256
        fdb   $0000,$002A,256   ; arcade    +0,  -56,256
        fdb   $8000,0,0        ; fin : script suivant

cpl.mot.right_c
        fdb   $FFB8,$0000,256   ; arcade  -192,   +0,256
        fdb   $0000,$0018,256   ; arcade    +0,  -32,256
        fdb   $0000,$FFBE,256   ; arcade    +0,  +88,256
        fdb   $0048,$0000,256   ; arcade  +192,   +0,256
        fdb   $0000,$0000,8     ; arcade    +0,   +0,8
        fdb   $0000,$0000,8     ; arcade    +0,   +0,8
        fdb   $0000,$006C,256   ; arcade    +0, -144,256
        fdb   $0000,$0000,8     ; arcade    +0,   +0,8
        fdb   $FFD9,$000C,256   ; arcade  -104,  -16,256
        fdb   $FFDF,$0000,256   ; arcade   -88,   +0,256
        fdb   $0000,$FF88,256   ; arcade    +0, +160,256
        fdb   $0000,$0078,256   ; arcade    +0, -160,256
        fdb   $0000,$FF88,256   ; arcade    +0, +160,256
        fdb   $0000,$0078,256   ; arcade    +0, -160,256
        fdb   $0000,$FF88,256   ; arcade    +0, +160,256
        fdb   $0048,$0000,256   ; arcade  +192,   +0,256
        fdb   $0000,$002A,256   ; arcade    +0,  -56,256
        fdb   $8000,0,0        ; fin : script suivant

cpl.mot.bottom_c
        fdb   $FFB8,$0000,256   ; arcade  -192,   +0,256
        fdb   $0000,$0018,256   ; arcade    +0,  -32,256
        fdb   $0000,$FFBE,256   ; arcade    +0,  +88,256
        fdb   $0048,$0000,256   ; arcade  +192,   +0,256
        fdb   $0000,$0042,256   ; arcade    +0,  -88,256
        fdb   $FFD9,$FFA0,256   ; arcade  -104, +128,256
        fdb   $FFDF,$001E,256   ; arcade   -88,  -40,256
        fdb   $FFFA,$0042,256   ; arcade   -16,  -88,256
        fdb   $0000,$FFA0,256   ; arcade    +0, +128,256
        fdb   $0063,$0000,256   ; arcade  +264,   +0,256
        fdb   $0000,$0060,256   ; arcade    +0, -128,256
        fdb   $0000,$FFA0,256   ; arcade    +0, +128,256
        fdb   $0000,$0060,256   ; arcade    +0, -128,256
        fdb   $0000,$FFA0,256   ; arcade    +0, +128,256
        fdb   $0000,$0060,256   ; arcade    +0, -128,256
        fdb   $FFEB,$0000,256   ; arcade   -56,   +0,256
        fdb   $0000,$FFE8,256   ; arcade    +0,  +32,256
        fdb   $8000,0,0        ; fin : script suivant

cpl.mot.left_c
        fdb   $FFB8,$0000,256   ; arcade  -192,   +0,256
        fdb   $0000,$0018,256   ; arcade    +0,  -32,256
        fdb   $0000,$FFBE,256   ; arcade    +0,  +88,256
        fdb   $0048,$0000,256   ; arcade  +192,   +0,256
        fdb   $FFB8,$0000,256   ; arcade  -192,   +0,256
        fdb   $0000,$0078,256   ; arcade    +0, -160,256
        fdb   $0021,$FFF4,256   ; arcade   +88,  +16,256
        fdb   $0027,$0000,256   ; arcade  +104,   +0,256
        fdb   $FFD9,$000C,256   ; arcade  -104,  -16,256
        fdb   $FFDF,$0000,256   ; arcade   -88,   +0,256
        fdb   $0000,$FF88,256   ; arcade    +0, +160,256
        fdb   $0000,$0078,256   ; arcade    +0, -160,256
        fdb   $0000,$FF88,256   ; arcade    +0, +160,256
        fdb   $0000,$0078,256   ; arcade    +0, -160,256
        fdb   $0000,$FF88,256   ; arcade    +0, +160,256
        fdb   $0048,$0000,256   ; arcade  +192,   +0,256
        fdb   $0000,$002A,256   ; arcade    +0,  -56,256
        fdb   $8000,0,0        ; fin : script suivant

; Les trois configs de chaque piece : trois scripts, dans l'ordre ou
; la piece les enchaine. Le tirage du spawn choisit la ligne.
cpl.cfg.right
        fdb   cpl.mot.right_b,cpl.mot.right_c,cpl.mot.right_a
        fdb   cpl.mot.right_b,cpl.mot.right_a,cpl.mot.right_c
        fdb   cpl.mot.right_c,cpl.mot.right_a,cpl.mot.right_b

cpl.cfg.bottom
        fdb   cpl.mot.bottom_b,cpl.mot.bottom_c,cpl.mot.bottom_a
        fdb   cpl.mot.bottom_b,cpl.mot.bottom_a,cpl.mot.bottom_c
        fdb   cpl.mot.bottom_c,cpl.mot.bottom_a,cpl.mot.bottom_b

cpl.cfg.left
        fdb   cpl.mot.left_b,cpl.mot.left_c,cpl.mot.left_a
        fdb   cpl.mot.left_b,cpl.mot.left_a,cpl.mot.left_c
        fdb   cpl.mot.left_c,cpl.mot.left_a,cpl.mot.left_b

