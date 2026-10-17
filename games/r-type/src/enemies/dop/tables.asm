; GENERE par tools/gen_dopswarm.py depuis la ROM arcade — ne pas editer.
; Repere ARCADE (x a droite, y vers le haut), valeurs non converties.

; 1000:C5E3 le script de l'essaim : {curseur, jeton}
dsw.Script
        fdb   $0000,$2020  ; C5E3
        fdb   $0064,$2120  ; C5E7
        fdb   $00C8,$2120  ; C5EB
        fdb   $012C,$2020  ; C5EF
        fdb   $0190,$2120  ; C5F3
        fdb   $01F4,$2020  ; C5F7
        fdb   $0258,$2020  ; C5FB
        fdb   $02BC,$2120  ; C5FF
        fdb   $0320,$2060  ; C603
        fdb   $0384,$2120  ; C607
        fdb   $03E8,$2120  ; C60B
        fdb   $044C,$2160  ; C60F
        fdb   $04B0,$2020  ; C613
        fdb   $0514,$2120  ; C617
        fdb   $0578,$2060  ; C61B
        fdb   $05DC,$2020  ; C61F
        fdb   $869F,$2000  ; C623

; 1000:931C le decalage de table de vitesse, par bits 4-5 du jeton
dsw.VelSet
        fcb   $00,$10,$20,$30

; 1000:2A80 les vitesses, 8.8 : quatre jeux de {vx, vy} par voie
dsw.Vel
        fdb   $0080,$0000,$0000,$FF80,$FF80,$0000,$0000,$0080  ; +$00
        fdb   $0100,$0000,$0000,$FF00,$FF00,$0000,$0000,$0100  ; +$10
        fdb   $0200,$0000,$0000,$FE00,$FE00,$0000,$0000,$0200  ; +$20
        fdb   $0300,$0000,$0000,$FD00,$FD00,$0000,$0000,$0300  ; +$30

; 1000:2A40 la sonde : {premier pas x, y, pas x, y} par voie, A puis B
dsw.Look
        fdb   28,12,0,-12  ; A voie 0
        fdb   -12,-24,12,0  ; A voie 1
        fdb   -24,12,0,-12  ; A voie 2
        fdb   -12,24,12,0  ; A voie 3
        fdb   24,12,0,-12  ; B voie 0
        fdb   -12,-24,12,0  ; B voie 1
        fdb   -28,12,0,-12  ; B voie 2
        fdb   -12,24,12,0  ; B voie 3

; 1000:9324 le depart d'un Dop ordinaire, par bits 0-3 du jeton :
; {x ecran, y, voie}
dsw.Preset
        fdb   712,344,2  ; 0
        fdb   712,328,2  ; 1
        fdb   712,264,2  ; 2
        fdb   712,200,2  ; 3
        fdb   712,184,2  ; 4
        fdb   648,136,3  ; 5
        fdb   576,136,3  ; 6
        fdb   480,136,3  ; 7
        fdb   384,136,3  ; 8
        fdb   312,184,0  ; 9
        fdb   312,264,0  ; A
        fdb   312,344,0  ; B
        fdb   384,392,1  ; C
        fdb   480,392,1  ; D
        fdb   576,392,1  ; E
        fdb   648,392,1  ; F
