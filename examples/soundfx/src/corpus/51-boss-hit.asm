; soundFX.sms51BossHit.data
; Source : 51-boss-hit (Master System FM), voie 6.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.
soundFX.sms51BossHit.data
        ; header
        fcb     24                  ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $00,$03,0 ; instrument perso
        fcb     $01,$21,0
        fcb     $02,$00,0
        fcb     $03,$00,0
        fcb     $04,$41,0
        fcb     $05,$F1,0
        fcb     $06,$00,0
        fcb     $07,$54,0
        fcb     $30,$00,0 ; vol:0
        fcb     $20,$13,0
        fcb     $10,$57,1

        fcb     $20,$15,0
        fcb     $10,$E5,1

        fcb     $20,$15,0
        fcb     $10,$20,1

        fcb     $30,$E0,0 ; vol:0
        fcb     $20,$15,0
        fcb     $10,$43,1

        fcb     $20,$17,0
        fcb     $10,$20,1

        fcb     $20,$19,0
        fcb     $10,$81,1

        fcb     $20,$19,0
        fcb     $10,$E5,1
