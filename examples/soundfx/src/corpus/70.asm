; soundFX.sms70.data
; Source : 70 (Master System FM), voie 7 — aussi sur 6.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.
soundFX.sms70.data
        ; header
        fcb     52                  ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $00,$00,0 ; instrument perso
        fcb     $01,$00,0
        fcb     $02,$05,0
        fcb     $03,$02,0
        fcb     $04,$F0,0
        fcb     $05,$E0,0
        fcb     $06,$02,0
        fcb     $07,$FF,0
        fcb     $30,$00,0 ; vol:4
        fcb     $20,$1B,1

        fcb     $20,$19,0
        fcb     $10,$20,1

        fcb     $20,$17,0
        fcb     $10,$81,1

        fcb     $20,$17,0
        fcb     $10,$01,1

        fcb     $20,$15,0
        fcb     $10,$20,1

        fcb     $20,$1B,0
        fcb     $10,$01,1

        fcb     $20,$19,0
        fcb     $10,$E5,1

        fcb     $20,$19,0
        fcb     $10,$B0,1

        fcb     $20,$19,0
        fcb     $10,$81,1

        fcb     $20,$19,0
        fcb     $10,$57,1

        fcb     $20,$19,0
        fcb     $10,$43,1

        fcb     $20,$19,0
        fcb     $10,$20,1

        fcb     $20,$19,0
        fcb     $10,$01,1

        fcb     $20,$17,0
        fcb     $10,$E5,1

        fcb     $20,$17,0
        fcb     $10,$B0,1

        fcb     $20,$17,0
        fcb     $10,$20,1

        fcb     $20,$15,0
        fcb     $10,$B0,1

        fcb     $20,$15,0
        fcb     $10,$57,1

        fcb     $20,$15,0
        fcb     $10,$20,1

        fcb     $20,$13,0
        fcb     $10,$B0,1

        fcb     $20,$13,0
        fcb     $10,$57,1

        fcb     $20,$13,0
        fcb     $10,$01,1
