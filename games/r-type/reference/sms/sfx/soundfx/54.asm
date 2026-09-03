; soundFX.sms54.data
; Source : 54 (Master System FM), voie 6.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.
soundFX.sms54.data
        ; header
        fcb     27                  ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $30,$20,0 ; vol:3
        fcb     $20,$1B,0
        fcb     $10,$43,2

        fcb     $20,$1B,0
        fcb     $10,$E5,2

        fcb     $20,$1D,0
        fcb     $10,$B0,1

        fcb     $20,$1F,0
        fcb     $10,$57,2

        fcb     $20,$1E,0
        fcb     $10,$40,1

        fcb     $20,$17,0
        fcb     $10,$FE,2

        fcb     $20,$1F,0
        fcb     $10,$E5,1

        fcb     $20,$1D,0
        fcb     $10,$81,2

        fcb     $20,$1D,0
        fcb     $10,$01,1

        fcb     $20,$1B,0
        fcb     $10,$57,2

        fcb     $20,$1B,0
        fcb     $10,$20,1

        fcb     $20,$1B,0
        fcb     $10,$81,2

        fcb     $20,$1B,0
        fcb     $10,$01,1
