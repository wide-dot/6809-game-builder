; soundFX.sms72.data
; Source : 72 (Master System FM), voie 6.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.
soundFX.sms72.data
        ; header
        fcb     70                  ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $00,$C0,0 ; instrument perso
        fcb     $01,$02,0
        fcb     $02,$09,0
        fcb     $03,$00,0
        fcb     $04,$F3,0
        fcb     $05,$F5,0
        fcb     $06,$10,0
        fcb     $07,$80,0
        fcb     $30,$70,0 ; vol:3
        fcb     $20,$19,1

        fcb     $20,$19,0
        fcb     $10,$20,1

        fcb     $20,$19,0
        fcb     $10,$81,1

        fcb     $20,$19,0
        fcb     $10,$E5,1

        fcb     $20,$1B,0
        fcb     $10,$20,1

        fcb     $20,$19,0
        fcb     $10,$E5,1

        fcb     $20,$19,0
        fcb     $10,$81,1

        fcb     $20,$19,0
        fcb     $10,$43,1

        fcb     $20,$19,0
        fcb     $10,$01,1

        fcb     $30,$00,0 ; vol:3
        fcb     $20,$1F,1

        fcb     $20,$1D,0
        fcb     $10,$E5,1

        fcb     $20,$1D,0
        fcb     $10,$B0,1

        fcb     $20,$1D,0
        fcb     $10,$81,1

        fcb     $20,$1D,0
        fcb     $10,$57,1

        fcb     $20,$1D,0
        fcb     $10,$43,1

        fcb     $20,$1D,0
        fcb     $10,$20,1

        fcb     $20,$1D,0
        fcb     $10,$01,1

        fcb     $20,$1B,0
        fcb     $10,$E5,1

        fcb     $20,$1B,0
        fcb     $10,$B0,1

        fcb     $20,$1B,0
        fcb     $10,$81,1

        fcb     $20,$1B,0
        fcb     $10,$57,1

        fcb     $20,$1B,0
        fcb     $10,$43,1

        fcb     $20,$1B,0
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
