; soundFX.sms37PodEject.data
; Source : 37-pod-eject (Master System FM), voie 6.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.
soundFX.sms37PodEject.data
        ; header
        fcb     20                  ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $30,$20,0 ; vol:2
        fcb     $20,$1B,2

        fcb     $20,$1B,0
        fcb     $10,$31,2

        fcb     $20,$1B,0
        fcb     $10,$10,1

        fcb     $20,$19,0
        fcb     $10,$E5,2

        fcb     $20,$19,0
        fcb     $10,$B0,1

        fcb     $20,$19,0
        fcb     $10,$98,2

        fcb     $20,$19,0
        fcb     $10,$81,1

        fcb     $20,$19,0
        fcb     $10,$6B,2

        fcb     $20,$19,0
        fcb     $10,$57,1

        fcb     $20,$19,0
        fcb     $10,$43,2
