; soundFX.sms42.data
; Source : 42 (Master System FM), voie 6 — aussi sur 7.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.
soundFX.sms42.data
        ; header
        fcb     42                  ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $30,$40,0 ; vol:2
        fcb     $20,$1D,0
        fcb     $10,$01,0
        fcb     $20,$1B,2

        fcb     $10,$57,0
        fcb     $20,$1B,2

        fcb     $10,$01,0
        fcb     $20,$17,1

        fcb     $10,$B0,0
        fcb     $20,$19,2

        fcb     $20,$1B,2

        fcb     $10,$43,0
        fcb     $20,$1D,1

        fcb     $20,$1B,2

        fcb     $10,$E5,0
        fcb     $20,$19,2

        fcb     $10,$57,0
        fcb     $20,$19,1

        fcb     $10,$01,0
        fcb     $20,$19,2

        fcb     $10,$20,0
        fcb     $20,$17,2

        fcb     $10,$B0,0
        fcb     $20,$19,1

        fcb     $10,$57,0
        fcb     $20,$19,2

        fcb     $10,$01,0
        fcb     $20,$19,2

        fcb     $10,$B0,0
        fcb     $20,$19,1

        fcb     $10,$43,0
        fcb     $20,$19,2

        fcb     $10,$E5,0
        fcb     $20,$19,2

        fcb     $10,$81,0
        fcb     $20,$1B,1

        fcb     $10,$20,0
        fcb     $20,$19,2

        fcb     $10,$E5,0
        fcb     $20,$1B,2

        fcb     $10,$57,0
        fcb     $30,$00,1 ; vol:15
