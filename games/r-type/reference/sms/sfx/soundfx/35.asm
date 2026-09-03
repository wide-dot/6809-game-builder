; soundFX.sms35.data
; Source : 35 (Master System FM), voie 7.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.
soundFX.sms35.data
        ; header
        fcb     9                   ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $30,$00,0 ; vol:8
        fcb     $20,$13,2

        fcb     $30,$00,0 ; vol:6
        fcb     $20,$13,2

        fcb     $30,$00,0 ; vol:4
        fcb     $20,$13,2

        fcb     $30,$00,0 ; vol:2
        fcb     $20,$13,48

        fcb     $30,$00,0 ; vol:15
