; soundFX.sms53.data
; Source : 53 (Master System FM), voie 6.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.
soundFX.sms53.data
        ; header
        fcb     18                  ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $30,$C0,0 ; vol:3
        fcb     $20,$17,0
        fcb     $10,$E5,1

        fcb     $20,$19,0
        fcb     $10,$57,1

        fcb     $20,$1B,0
        fcb     $10,$B0,1

        fcb     $20,$19,0
        fcb     $10,$57,1

        fcb     $20,$17,0
        fcb     $10,$81,1

        fcb     $20,$19,0
        fcb     $10,$20,1

        fcb     $20,$1B,0
        fcb     $10,$01,1

        fcb     $20,$19,0
        fcb     $10,$84,1

        fcb     $30,$00,0 ; vol:15
