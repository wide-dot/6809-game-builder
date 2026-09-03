; soundFX.sms65.data
; Source : 65 (Master System FM), voie 6.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.
soundFX.sms65.data
        ; header
        fcb     17                  ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $30,$20,0 ; vol:2
        fcb     $20,$17,1

        fcb     $20,$17,0
        fcb     $10,$43,1

        fcb     $30,$00,0 ; vol:15
        fcb     $20,$00,2

        fcb     $30,$20,0 ; vol:2
        fcb     $20,$15,1

        fcb     $20,$13,0
        fcb     $10,$B0,1

        fcb     $20,$15,0
        fcb     $10,$E5,1

        fcb     $20,$17,0
        fcb     $10,$81,1

        fcb     $20,$1B,0
        fcb     $10,$01,1

        fcb     $30,$00,0 ; vol:15
