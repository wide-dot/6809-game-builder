; soundFX.sms50EnemyHit.data
; Source : 50-enemy-hit (Master System FM), voie 6.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.
soundFX.sms50EnemyHit.data
        ; header
        fcb     25                  ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $00,$69,0 ; instrument perso
        fcb     $01,$01,0
        fcb     $02,$04,0
        fcb     $03,$07,0
        fcb     $04,$82,0
        fcb     $05,$D5,0
        fcb     $06,$30,0
        fcb     $07,$C7,0
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
