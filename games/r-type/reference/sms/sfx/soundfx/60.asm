; soundFX.sms60.data
; Source : 60 (Master System FM), voie 6.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.
soundFX.sms60.data
        ; header
        fcb     3                   ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $30,$00,0 ; vol:2
        fcb     $20,$11,32

        fcb     $30,$00,0 ; vol:15
