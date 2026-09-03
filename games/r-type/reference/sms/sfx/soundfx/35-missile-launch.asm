; soundFX.sms35MissileLaunch.data
; Source : 35-missile-launch (Master System FM), voie 7.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.
soundFX.sms35MissileLaunch.data
        ; header
        fcb     16                  ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $00,$69,0 ; instrument perso
        fcb     $01,$01,0
        fcb     $02,$04,0
        fcb     $03,$07,0
        fcb     $04,$82,0
        fcb     $05,$D5,0
        fcb     $06,$30,0
        fcb     $07,$C7,0
        fcb     $30,$00,0 ; vol:8
        fcb     $20,$13,2

        fcb     $30,$00,0 ; vol:6
        fcb     $20,$13,2

        fcb     $30,$00,0 ; vol:4
        fcb     $20,$13,2

        fcb     $30,$00,0 ; vol:2
        fcb     $20,$13,48
