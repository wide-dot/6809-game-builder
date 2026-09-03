; soundFX.sms45ExplosionSmall.data
; Source : 45-explosion-small (Master System FM), voie 6.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.
soundFX.sms45ExplosionSmall.data
        ; header
        fcb     17                  ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $30,$C0,0 ; vol:1
        fcb     $20,$17,0
        fcb     $10,$81,1

        fcb     $20,$19,0
        fcb     $10,$B0,1

        fcb     $20,$1B,0
        fcb     $10,$20,1

        fcb     $20,$1D,0
        fcb     $10,$43,1

        fcb     $20,$1F,0
        fcb     $10,$01,1

        fcb     $20,$1B,0
        fcb     $10,$B0,1

        fcb     $20,$1B,0
        fcb     $10,$01,1

        fcb     $20,$19,0
        fcb     $10,$B0,1
