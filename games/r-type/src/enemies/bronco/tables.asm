; GENERE par tools/gen_bronco.py depuis la ROM arcade — ne pas editer.
; Repere ARCADE (x a droite, y vers le haut), valeurs non converties.

; 1000:611E les x de chute des debris (0x8000 : le curseur revient)
bro.DebrisX
        fdb   $01E0,$0220,$0160,$0260,$01A0,$0260,$8000

; 1000:612C la repartition : 32 rangs d'installateur (bro.I_*)
bro.Dispatch
        fcb   0,10,5,8,0,1,6,3  ; BB40 BC63 BBA2 BC08 BB40 BB72 BBAE BB8A
        fcb   4,5,9,0,1,2,3,4  ; BB96 BBA2 BC31 BB40 BB72 BB7E BB8A BB96
        fcb   6,5,7,10,1,2,3,4  ; BBAE BBA2 BBC3 BC63 BB72 BB7E BB8A BB96
        fcb   2,3,4,5,9,0,2,5  ; BB7E BB8A BB96 BBA2 BC31 BB40 BB7E BBA2

; 1000:627C les x des poursuivants (0x8000 : aucun, 0 : le curseur revient)
bro.ChaserX
        fdb   $0200,$8000,$0158,$8000,$0238,$8000,$0190,$8000,$0268,$8000,$8000,$01C8,$0190,$8000,$0238,$8000,$0000

; 1000:6312 les images des sous-enfants : rang dans les debris
bro.SubImg
        fcb   0,4,6,2

; 1000:631A la vitesse x de l'attaquant principal (8.8)
bro.MainVx
        fdb   $FF00,$FF00,$FF00,$FF00,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0100,$0100,$0100,$0100

; 1000:60B6 les douze explosions d'un segment, {dx, dy}
bro.SegBoom
        fdb   4,2,-10,-4,8,-13,-8,10,24,5,3,20
        fdb   -24,7,12,-3,-3,-14,20,-3,-24,4,24,28

; 1000:27FE create_bonus : l'octet haut, par (type & 7) * 2 + (compteur & 2) / 2
bro.Bonus
        fcb   $00,$00,$02,$02,$04,$04,$0A,$0A,$06,$06,$08,$08,$0A,$00,$0C,$0C

; move_by_script : les plages brutes (debut arcade, longueur, donnees)
bro.Ranges
        fdb   $A7FC,32,bro.RA7FC
        fdb   $AA54,26,bro.RAA54
        fdb   $AB28,18,bro.RAB28
        fdb   $B071,109,bro.RB071
        fdb   $B10A,2,bro.RB10A
        fdb   0
bro.RA7FC
        fcb   $5C,$AA,$5C,$AA,$5C,$AA,$5C,$AA,$54,$AA,$00,$00,$0A,$A8,$5C,$AA
        fcb   $5C,$AA,$71,$B0,$99,$B0,$BD,$B0,$28,$AB,$28,$AB,$00,$00,$0A,$B1
bro.RAA54
        fcb   $00,$00,$00,$00,$00,$00,$00,$04,$88,$60,$60,$60,$60,$60,$60,$60
        fcb   $60,$60,$60,$60,$60,$60,$60,$60,$64,$80
bro.RAB28
        fcb   $85,$18,$78,$18,$78,$18,$78,$18,$78,$18,$78,$18,$78,$18,$78,$18
        fcb   $7C,$8D
bro.RB071
        fcb   $88,$60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$78,$60
        fcb   $60,$60,$60,$78,$87,$60,$60,$60,$60,$60,$78,$60,$60,$60,$78,$60
        fcb   $60,$78,$60,$60,$60,$78,$60,$64,$87,$78,$00,$60,$78,$60,$00,$78
        fcb   $60,$60,$00,$78,$60,$78,$00,$86,$60,$78,$60,$00,$78,$78,$00,$60
        fcb   $78,$60,$00,$78,$78,$60,$00,$78,$78,$00,$60,$7C,$86,$78,$78,$00
        fcb   $60,$78,$78,$00,$78,$00,$78,$78,$00,$78,$85,$78,$00,$78,$78,$78
        fcb   $00,$78,$78,$00,$78,$18,$78,$00,$78,$78,$00,$18,$7C
bro.RB10A
        fcb   $84,$18
