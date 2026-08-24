;*******************************************************************************
; halfpage.ut — LA DEMI-PAGE $4000-$5FFF SE COMMUTE-T-ELLE ?
;*******************************************************************************
; La question, posee le 24/08 : ram.set choisit la demi-page vue en
; $4000-$5FFF par le BIT 0 du numero de page, qu'il pousse dans le port C du
; 6846 ($E7C3). Sur r-type ce chemin est un no-op mesure — le bit relu vaut
; toujours 0 — alors que l'auteur atteste que le mecanisme marchait avant le
; passage en mode overlay. Ce banc tranche SANS le jeu autour : il ecrit une
; marque dans chaque moitie et relit.
;
; Le soupcon a verifier : DDRC ($E7C2), le registre de DIRECTION du port. A
; zero, toutes les lignes sont en ENTREE — ecrire PRC n'a alors aucun effet et
; la relecture rend le niveau d'entree. Le banc mesure l'etat initial, teste
; tel quel, PUIS met le bit 0 en sortie et refait le meme test. Si la seconde
; serie passe et la premiere echoue, la cause est la.
;
; Temoins en $9C00 (convention maison), magic $CA :
;   +0 $CA magic          +1 DDRC initial      +2 PRC initial
;   +3 PRC apres ora #1   (le bit a-t-il pris ?)
;   +4 $4000 relu en demi-page 0   (attendu $A0)
;   +5 $4000 relu en demi-page 1   (attendu $B1 si la commutation marche,
;                                   $A0 si les deux vues sont la meme RAM)
;   +6 DDRC apres l'avoir mis a $01
;   +7 PRC apres ora #1, DDRC configure
;   +8 $4000 relu en demi-page 0, DDRC configure   (attendu $A0)
;   +9 $4000 relu en demi-page 1, DDRC configure   (attendu $B1)
;  +10 verdict : $01 = commute des le depart, $02 = commute une fois DDRC pose,
;                $FF = ne commute jamais
;
; ROND-POINT DU BIT SEUL (24/08, sur demande) : le debogueur toje rend
; toujours 0 sur $E7xx (read_memory ne lit pas les registres reels — verifie,
; c'est un artefact de sonde, pas un fait machine). Ici on ecrit 0/1/0/1 sur le
; SEUL bit 0 et on relit CHAQUE FOIS depuis le CODE, sans passer par $4000 :
;   +11 PRC apres bit=0   +12 PRC apres bit=1
;   +13 PRC apres bit=0   +14 PRC apres bit=1
;   +15 verdict rond-point : $01 = le bit se lit 0/1/0/1 comme ecrit,
;                             $FF = au moins une lecture ne correspond pas
;*******************************************************************************

ut.WITNESS equ $9C00
ut.VIDEO   equ $4000

        lda   #$CA
        sta   ut.WITNESS

        ; --- l'etat que le boot a laisse
        lda   MC6846.DDRC
        sta   ut.WITNESS+1
        lda   MC6846.PRC
        sta   ut.WITNESS+2

        lbsr  ut.essai                 ; premiere serie, DDRC tel quel
        sta   ut.WITNESS+5             ; (essai rend la marque de la moitie 1)
        lda   ut.tmp.prc
        sta   ut.WITNESS+3
        lda   ut.tmp.half0
        sta   ut.WITNESS+4

        ; --- DDRC bit 0 en SORTIE, puis on refait exactement le meme essai
        lda   #$01
        sta   MC6846.DDRC
        lda   MC6846.DDRC
        sta   ut.WITNESS+6

        lbsr  ut.essai
        sta   ut.WITNESS+9
        lda   ut.tmp.prc
        sta   ut.WITNESS+7
        lda   ut.tmp.half0
        sta   ut.WITNESS+8

        ; --- le verdict
        lda   #$FF
        ldb   ut.WITNESS+4             ; serie 1 : moitie 0 == $A0 ...
        cmpb  #$A0
        bne   ut.verdict.deux
        ldb   ut.WITNESS+5             ; ... et moitie 1 == $B1 ?
        cmpb  #$B1
        bne   ut.verdict.deux
        lda   #$01                     ; commute des le depart
        bra   ut.verdict.pose
ut.verdict.deux
        ldb   ut.WITNESS+8             ; serie 2, DDRC configure
        cmpb  #$A0
        bne   ut.verdict.pose
        ldb   ut.WITNESS+9
        cmpb  #$B1
        bne   ut.verdict.pose
        lda   #$02                     ; commute une fois DDRC pose
ut.verdict.pose
        sta   ut.WITNESS+10

        ; --- le rond-point : 0/1/0/1, RIEN d'autre que le bit
        ldx   #ut.WITNESS+11
        bsr   ut.roundtrip             ; bit=0
        bsr   ut.roundtrip1            ; bit=1
        bsr   ut.roundtrip             ; bit=0
        bsr   ut.roundtrip1            ; bit=1

        lda   #$01                     ; verdict rond-point
        ldb   ut.WITNESS+11
        andb  #1
        bne   ut.rt.mauvais
        ldb   ut.WITNESS+12
        andb  #1
        beq   ut.rt.mauvais
        ldb   ut.WITNESS+13
        andb  #1
        bne   ut.rt.mauvais
        ldb   ut.WITNESS+14
        andb  #1
        beq   ut.rt.mauvais
        bra   ut.rt.pose
ut.rt.mauvais
        lda   #$FF
ut.rt.pose
        sta   ut.WITNESS+15
ut.fin  bra   ut.fin                   ; le banc se lit en RAM, il ne rend rien

; pose le bit a 0, relit, range en [x] ; x avance de 1
ut.roundtrip
        lda   map.HALFPAGE
        anda  #%11111110
        sta   map.HALFPAGE
        bra   ut.rt.read
; pose le bit a 1, relit, range en [x] ; x avance de 1
ut.roundtrip1
        lda   map.HALFPAGE
        ora   #%00000001
        sta   map.HALFPAGE
ut.rt.read
        lda   map.HALFPAGE
        sta   ,x+
        rts

; -----------------------------------------------------------------------------
; ut.essai — ecrire une marque par moitie, puis relire les deux
; -----------------------------------------------------------------------------
; sortie : [a] la marque relue en moitie 1
;          ut.tmp.half0 la marque relue en moitie 0
;          ut.tmp.prc   PRC relu juste apres avoir pose son bit 0
; -----------------------------------------------------------------------------
ut.essai
        ; moitie 0 : y poser $A0
        lda   MC6846.PRC
        anda  #%11111110
        sta   MC6846.PRC
        lda   #$A0
        sta   ut.VIDEO

        ; moitie 1 : y poser $B1
        lda   MC6846.PRC
        ora   #%00000001
        sta   MC6846.PRC
        lda   MC6846.PRC               ; le bit a-t-il pris ?
        sta   ut.tmp.prc
        lda   #$B1
        sta   ut.VIDEO

        ; relire la moitie 0 : si la commutation marche, $A0 y est INTACT
        lda   MC6846.PRC
        anda  #%11111110
        sta   MC6846.PRC
        lda   ut.VIDEO
        sta   ut.tmp.half0

        ; relire la moitie 1 : $B1
        lda   MC6846.PRC
        ora   #%00000001
        sta   MC6846.PRC
        lda   ut.VIDEO
        rts

ut.tmp.prc   fcb 0
ut.tmp.half0 fcb 0
