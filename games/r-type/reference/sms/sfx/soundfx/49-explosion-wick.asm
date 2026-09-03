; soundFX.sms49ExplosionWick.data
; Source : 49-explosion-wick (Master System FM), voie 6.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.
soundFX.sms49ExplosionWick.data
        ; header
        fcb     49                  ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $00,$00,0 ; instrument perso
        fcb     $01,$01,0
        fcb     $02,$03,0
        fcb     $03,$05,0
        fcb     $04,$F0,0
        fcb     $05,$F0,0
        fcb     $06,$16,0
        fcb     $07,$22,0
        fcb     $30,$00,0 ; vol:2
        fcb     $20,$17,0
        fcb     $10,$57,1

        fcb     $20,$1B,0
        fcb     $10,$01,1

        fcb     $20,$1B,0
        fcb     $10,$E5,1

        fcb     $20,$1D,0
        fcb     $10,$43,1

        fcb     $20,$1D,0
        fcb     $10,$E5,1

        fcb     $20,$1B,0
        fcb     $10,$43,1

        fcb     $20,$19,1

        fcb     $20,$1B,0
        fcb     $10,$E5,1

        fcb     $20,$1D,0
        fcb     $10,$57,1

        fcb     $20,$1F,0
        fcb     $10,$B0,1

        fcb     $20,$1F,1

        fcb     $20,$1F,0
        fcb     $10,$01,1

        fcb     $20,$1D,0
        fcb     $10,$43,1

        fcb     $20,$1B,0
        fcb     $10,$01,1

        fcb     $20,$1B,0
        fcb     $10,$81,1

        fcb     $20,$1B,0
        fcb     $10,$E5,1

        fcb     $20,$1D,0
        fcb     $10,$20,1

        fcb     $20,$1D,0
        fcb     $10,$81,1

        fcb     $20,$1F,0
        fcb     $10,$01,1

        fcb     $20,$1F,0
        fcb     $10,$43,1

        fcb     $20,$1F,0
        fcb     $10,$B0,1
