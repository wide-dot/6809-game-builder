; soundFX.HitSound.data
; Source : 51-boss-hit (Master System FM), voie 6.
; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main :
;     tools/sms_sfx_to_soundfx.py --instrument 3 \
;         reference/sms/sfx/asm/51-boss-hit.asm > src/common/fx/soundfx/hit-piano.asm
; (le label a ete renomme soundFX.HitSound.data)
;
; LE COUP ENCAISSE, ennemi comme boss (borne $56 et $57). Le son d'origine
; joue sur l'instrument personnalise du YM2413, que la musique utilise aussi :
; le bruitage le reecrirait sous elle. Force au piano (instrument 3 de la ROM
; du chip), il n'y touche plus — choix de l'auteur au testeur, cf.
; examples/soundfx et doc/inventaire-sons.md.
soundFX.HitSound.data
        ; header
        fcb     16                  ; Number of commands
        fcb     5                   ; Channel number (5)

        fcb     $30,$30,0 ; vol:0 ; instrument 3 impose
        fcb     $20,$13,0
        fcb     $10,$57,1

        fcb     $20,$15,0
        fcb     $10,$E5,1

        fcb     $20,$15,0
        fcb     $10,$20,1

        fcb     $30,$30,0 ; vol:0 ; instrument 3 impose
        fcb     $20,$15,0
        fcb     $10,$43,1

        fcb     $20,$17,0
        fcb     $10,$20,1

        fcb     $20,$19,0
        fcb     $10,$81,1

        fcb     $20,$19,0
        fcb     $10,$E5,1

