; soundFX.sms66.data
; Source : 66 (Master System FM), voie 6.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.
soundFX.sms66.data
        ; header
        fcb     29                  ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $00,$01,0 ; instrument perso
        fcb     $01,$0F,0
        fcb     $02,$00,0
        fcb     $03,$00,0
        fcb     $04,$F0,0
        fcb     $05,$F0,0
        fcb     $06,$F0,0
        fcb     $07,$FF,0
        fcb     $30,$00,0 ; vol:4
        fcb     $20,$13,0
        fcb     $10,$55,1

        fcb     $20,$15,0
        fcb     $10,$4E,1

        fcb     $20,$13,0
        fcb     $10,$55,1

        fcb     $20,$15,0
        fcb     $10,$4E,1

        fcb     $20,$13,0
        fcb     $10,$55,1

        fcb     $20,$15,0
        fcb     $10,$4E,1

        fcb     $20,$13,0
        fcb     $10,$55,1

        fcb     $20,$15,0
        fcb     $10,$4E,1

        fcb     $20,$13,0
        fcb     $10,$55,1

        fcb     $20,$15,0
        fcb     $10,$4E,1
