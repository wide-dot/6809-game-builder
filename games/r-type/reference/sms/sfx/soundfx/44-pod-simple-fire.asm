; soundFX.sms44PodSimpleFire.data
; Source : 44-pod-simple-fire (Master System FM), voie 6.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.
soundFX.sms44PodSimpleFire.data
        ; header
        fcb     7                   ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $30,$C0,0 ; vol:1
        fcb     $20,$19,0
        fcb     $10,$01,3

        fcb     $20,$19,0
        fcb     $10,$57,3

        fcb     $20,$19,0
        fcb     $10,$B0,3
