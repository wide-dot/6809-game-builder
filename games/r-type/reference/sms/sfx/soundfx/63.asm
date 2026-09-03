; soundFX.sms63.data
; Source : 63 (Master System FM), voie 7 — aussi sur 8.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.
soundFX.sms63.data
        ; header
        fcb     9                   ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $30,$00,0 ; vol:2
        fcb     $20,$1B,0
        fcb     $10,$01,0
        fcb     $20,$1B,2

        fcb     $10,$20,0
        fcb     $20,$1B,2

        fcb     $10,$31,0
        fcb     $30,$00,1 ; vol:15

        fcb     $20,$00,0
