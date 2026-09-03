; soundFX.sms50.data
; Source : 50 (Master System FM), voie 6.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.
soundFX.sms50.data
        ; header
        fcb     18                  ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $30,$00,0 ; vol:3
        fcb     $20,$1F,0
        fcb     $10,$01,1

        fcb     $20,$1F,0
        fcb     $10,$FC,2

        fcb     $20,$1F,0
        fcb     $10,$01,1

        fcb     $20,$1F,0
        fcb     $10,$FC,1

        fcb     $20,$1F,0
        fcb     $10,$01,1

        fcb     $20,$1F,0
        fcb     $10,$FC,1

        fcb     $20,$1F,0
        fcb     $10,$01,1

        fcb     $20,$1F,0
        fcb     $10,$FC,1

        fcb     $30,$00,0 ; vol:15
