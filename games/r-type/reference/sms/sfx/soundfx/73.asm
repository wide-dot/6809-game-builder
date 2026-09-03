; soundFX.sms73.data
; Source : 73 (Master System FM), voie 4 — aussi sur 5.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.
soundFX.sms73.data
        ; header
        fcb     18                  ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $30,$B0,0 ; vol:1
        fcb     $20,$19,0
        fcb     $10,$81,0
        fcb     $20,$19,16

        fcb     $20,$19,8

        fcb     $10,$E5,0
        fcb     $20,$19,8

        fcb     $10,$B0,0
        fcb     $20,$19,8

        fcb     $10,$81,0
        fcb     $20,$19,8

        fcb     $10,$E5,0
        fcb     $20,$1B,8

        fcb     $10,$43,0
        fcb     $20,$1B,8

        fcb     $10,$20,0
        fcb     $30,$00,32 ; vol:15

        fcb     $20,$00,0
