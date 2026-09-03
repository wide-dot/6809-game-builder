; soundFX.sms94Countdown02.data
; Source : 94-countdown02 (Master System FM), voie 0 — aussi sur 1, 2, 3.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.
soundFX.sms94Countdown02.data
        ; header
        fcb     26                  ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $30,$A0,0 ; vol:1
        fcb     $20,$17,0
        fcb     $30,$A0,4 ; vol:2

        fcb     $30,$A0,2 ; vol:3

        fcb     $30,$A0,3 ; vol:4

        fcb     $30,$A0,8 ; vol:5

        fcb     $30,$A0,0 ; vol:1
        fcb     $20,$17,2

        fcb     $30,$A0,2 ; vol:2

        fcb     $30,$A0,2 ; vol:3

        fcb     $30,$A0,2 ; vol:4

        fcb     $30,$A0,3 ; vol:5

        fcb     $30,$A0,6 ; vol:1

        fcb     $20,$17,2

        fcb     $30,$A0,0 ; vol:2
        fcb     $30,$A0,3 ; vol:3

        fcb     $30,$A0,2 ; vol:4

        fcb     $30,$A0,3 ; vol:5

        fcb     $30,$A0,6 ; vol:1

        fcb     $20,$17,2

        fcb     $30,$A0,0 ; vol:2
        fcb     $30,$A0,3 ; vol:3

        fcb     $30,$A0,2 ; vol:4

        fcb     $30,$A0,3 ; vol:5

        fcb     $30,$00,7 ; vol:15

        fcb     $20,$00,0
