; GENERE par tools/gen_ending.py depuis la ROM arcade — ne pas editer.
; Repere ARCADE (x a droite, y vers le haut), valeurs non converties.

; 1000:945C la flotte : {script (adresse arcade), y, rang de couleur}
ending.Fleet
        fdb   $94CA,$0170
        fcb   1                       ; palette $64
        fdb   $94DC,$0160
        fcb   0                       ; palette $02
        fdb   $94EE,$0158
        fcb   0                       ; palette $02
        fdb   $9520,$0140
        fcb   3                       ; palette $66
        fdb   $9542,$0138
        fcb   2                       ; palette $65
        fdb   $9564,$0130
        fcb   4                       ; palette $67
        fdb   $9586,$0128
        fcb   2                       ; palette $65
        fdb   $95B0,$0120
        fcb   1                       ; palette $64
        fdb   $95C2,$0118
        fcb   5                       ; palette $68
        fdb   $95D4,$00F8
        fcb   4                       ; palette $67
        fdb   $95E6,$00E8
        fcb   0                       ; palette $02
        fdb   $95F8,$00E0
        fcb   5                       ; palette $68
        fdb   $962A,$00D8
        fcb   2                       ; palette $65
        fdb   $963C,$00D0
        fcb   4                       ; palette $67
        fdb   $9666,$00C0
        fcb   3                       ; palette $66
        fdb   $9688,$00B8
        fcb   5                       ; palette $68
        fdb   $96B2,$00A8
        fcb   0                       ; palette $02
        fdb   $96C4,$00A0
        fcb   3                       ; palette $66
ending.FleetEnd

; les scripts de la flotte : la plage brute que les vaisseaux lisent
ending.SCRIPT_LO equ $94CA
ending.Scripts
        fcb   $00,$00,$00,$00,$00,$00,$E2,$96,$C0,$03,$40,$01,$00,$00,$E2,$96
        fcb   $00,$80,$00,$00,$00,$00,$00,$00,$E2,$96,$40,$01,$00,$01,$00,$00
        fcb   $E2,$96,$00,$80,$00,$00,$00,$00,$00,$00,$E2,$96,$B0,$00,$80,$01
        fcb   $00,$00,$E2,$96,$60,$01,$00,$00,$00,$00,$E2,$96,$E0,$01,$00,$00
        fcb   $00,$FF,$EE,$96,$00,$02,$00,$00,$00,$00,$E2,$96,$40,$02,$80,$01
        fcb   $00,$00,$E2,$96,$00,$80,$00,$00,$00,$00,$00,$00,$E2,$96,$C0,$00
        fcb   $80,$00,$00,$00,$E2,$96,$20,$02,$00,$00,$00,$00,$E2,$96,$60,$03
        fcb   $80,$00,$00,$00,$E2,$96,$00,$80,$00,$00,$00,$00,$00,$00,$E2,$96
        fcb   $C0,$02,$C0,$00,$28,$00,$D6,$96,$6A,$03,$00,$00,$00,$00,$E2,$96
        fcb   $2A,$04,$C0,$00,$00,$00,$E2,$96,$00,$80,$00,$00,$00,$00,$00,$00
        fcb   $E2,$96,$80,$02,$40,$01,$00,$00,$E2,$96,$4C,$03,$00,$00,$00,$00
        fcb   $E2,$96,$0C,$04,$40,$01,$00,$00,$E2,$96,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$E2,$96,$80,$00,$40,$00,$00,$00,$E2,$96,$80,$03,$00,$00
        fcb   $00,$00,$E2,$96,$40,$04,$40,$00,$D8,$FF,$EE,$96,$40,$06,$40,$00
        fcb   $00,$00,$E2,$96,$00,$80,$00,$00,$00,$00,$00,$00,$E2,$96,$40,$04
        fcb   $C0,$01,$00,$00,$E2,$96,$00,$80,$00,$00,$00,$00,$00,$00,$E2,$96
        fcb   $C0,$04,$00,$01,$00,$00,$E2,$96,$00,$80,$00,$00,$00,$00,$00,$00
        fcb   $E2,$96,$80,$01,$00,$01,$00,$00,$E2,$96,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$E2,$96,$80,$02,$80,$01,$00,$00,$E2,$96,$00,$80,$00,$00
        fcb   $00,$00,$00,$00,$E2,$96,$E0,$00,$80,$00,$00,$00,$E2,$96,$90,$02
        fcb   $00,$00,$00,$00,$E2,$96,$10,$03,$00,$00,$80,$00,$D6,$96,$50,$03
        fcb   $00,$00,$00,$00,$E2,$96,$50,$04,$80,$00,$00,$00,$E2,$96,$00,$80
        fcb   $00,$00,$00,$00,$00,$00,$E2,$96,$A0,$05,$40,$02,$00,$00,$E2,$96
        fcb   $00,$80,$00,$00,$00,$00,$00,$00,$E2,$96,$00,$02,$C0,$00,$00,$00
        fcb   $E2,$96,$E0,$02,$00,$00,$00,$00,$E2,$96,$60,$03,$C0,$00,$B0,$FF
        fcb   $EE,$96,$CA,$03,$C0,$00,$00,$00,$E2,$96,$00,$80,$00,$00,$00,$00
        fcb   $00,$00,$E2,$96,$40,$01,$40,$01,$00,$00,$E2,$96,$90,$01,$00,$00
        fcb   $00,$00,$E2,$96,$90,$03,$40,$01,$00,$00,$E2,$96,$00,$80,$00,$00
        fcb   $00,$00,$00,$00,$E2,$96,$80,$00,$80,$00,$00,$00,$E2,$96,$00,$02
        fcb   $00,$00,$00,$00,$E2,$96,$C0,$02,$80,$00,$20,$00,$D6,$96,$30,$03
        fcb   $80,$00,$00,$00,$E2,$96,$00,$80,$00,$00,$00,$00,$00,$00,$E2,$96
        fcb   $D0,$00,$40,$00,$00,$00,$E2,$96,$00,$80,$00,$00,$00,$00,$00,$00
        fcb   $E2,$96,$10,$02,$80,$01,$00,$00,$E2,$96,$00,$80

; les trois poses (cellules 0x20, 0x22, 0x24) : recettes arcade
ending.Poses
        fdb   $96D6,$96E2,$96EE

; les descripteurs : {ligne de tilemap, rang de chaine + 1 (0 = blanche)}
ending.Desc
        fcb   $10,1                  ; 8A02 THANKS TO YOUR BRAVE
        fcb   $14,2                  ; 8A20 FIGHTING/ THE COSMOS
        fcb   $18,3                  ; 8A3E RESTORED PEACE.
        fcb   $1C,4                  ; 8A5C THE BYDE EMPIRE WAS
        fcb   $20,5                  ; 8A7A ANNIHILATED TO NEVER
        fcb   $24,6                  ; 8A98 SCARE PEOPLE AGAIN/
        fcb   $28,7                  ; 8AB6 YOUR NAME WILL REMAIN
        fcb   $2C,8                  ; 8AD4 IN THE UNIVERSE FOREVER/
        fcb   $30,9                  ; 8AF2 THANK YOU FOR PLAYING
        fcb   $34,10                  ; 8B10 THE GAME TO THE END/
        fcb   $38,0                  ; 8B2E 
        fcb   $39,11                  ; 8B4C          STAFF OF IREM
        fcb   $3D,0                  ; 8B6A 
        fcb   $10,0                  ; 8912 
        fcb   $14,0                  ; 8930 
        fcb   $18,0                  ; 894E 
        fcb   $1C,0                  ; 896C 
        fcb   $20,0                  ; 898A 
        fcb   $24,0                  ; 89A8 
        fcb   $28,0                  ; 89C6 
        fcb   $2C,0                  ; 89E4 
        fcb   $1C,12                  ; 8B88 ENJOY THE BONUS GAME AGAIN :

; les deux premieres lignes (40:EEE5), la table du directeur (1000:88E8,
; en rang de descripteur, $FF = fin) et ENJOY (40:EF64)
ending.D_FIRST0 equ 0
ending.D_FIRST1 equ 1
ending.D_ENJOY  equ 21
ending.Lines
        fcb   2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,20,$FF
