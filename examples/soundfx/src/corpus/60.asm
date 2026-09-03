; soundFX.sms60.data
; Source : 60 (Master System FM), voie 6.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.
soundFX.sms60.data
        ; header
        fcb     10                  ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $00,$2B,0 ; instrument perso
        fcb     $01,$2B,0
        fcb     $02,$00,0
        fcb     $03,$07,0
        fcb     $04,$94,0
        fcb     $05,$72,0
        fcb     $06,$30,0
        fcb     $07,$27,0
        fcb     $30,$00,0 ; vol:2
        fcb     $20,$11,32
