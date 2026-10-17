; GENERE par tools/gen_ending.py depuis la ROM arcade — ne pas editer.
; Le directeur du generique (la flotte est dans fleet.asm).

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
