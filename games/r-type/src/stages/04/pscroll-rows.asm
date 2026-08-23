;******************************************************************************
; pscroll — les routines de gravure d'une rangee, GENEREES
;
; tools/gen_pscroll.py — ne pas editer a la main.
;
; Une routine grave UNE RANGEE de cellules (6 lignes) x les 4 octets
; d'un plan sur une bande de 16 px. U pointe le chunk de la premiere
; ligne ; les immediats sont CUITS (ldd #, 3 cy) et la destination est
; fixe — c'est le chemin du FEED, pas celui de la mutation (voir
; etude-pscroll-gommes-stage4.md, §6.4).
;
; La combinaison ne mentionne pas le plan : le meme peigne (2 px, saut
; de 2 px) se retrouve dans les deux. 33 routines au lieu de 28.
;******************************************************************************

; pscroll.LINE_SIZE vient du module engine (pscroll.asm) : le pas de
; ligne du buffer, 80 o. Le generateur le SUPPOSE — si le module
; change de geometrie, cette valeur doit suivre ici aussi.

; --- la table des routines ---------------------------------------------
pscroll.row.tbl
        fdb   pscroll.row.00
        fdb   pscroll.row.01
        fdb   pscroll.row.02
        fdb   pscroll.row.03
        fdb   pscroll.row.04
        fdb   pscroll.row.05
        fdb   pscroll.row.06
        fdb   pscroll.row.07
        fdb   pscroll.row.08
        fdb   pscroll.row.09
        fdb   pscroll.row.10
        fdb   pscroll.row.11
        fdb   pscroll.row.12
        fdb   pscroll.row.13
        fdb   pscroll.row.14
        fdb   pscroll.row.15
        fdb   pscroll.row.16
        fdb   pscroll.row.17
        fdb   pscroll.row.18
        fdb   pscroll.row.19
        fdb   pscroll.row.20
        fdb   pscroll.row.21
        fdb   pscroll.row.22
        fdb   pscroll.row.23
        fdb   pscroll.row.24
        fdb   pscroll.row.25
        fdb   pscroll.row.26
        fdb   pscroll.row.27
        fdb   pscroll.row.28
        fdb   pscroll.row.29
        fdb   pscroll.row.30
        fdb   pscroll.row.31
        fdb   pscroll.row.32

pscroll.row.00                   ; fond
        leax  240,u
        ldd   #$0000
        std   80,x
        std   83,x
        std   ,x
        std   3,x
        std   -80,x
        std   -77,x
        std   80,u
        std   83,u
        std   ,u
        std   3,u
        std   -80,u
        std   -77,u
        rts

pscroll.row.01
        leax  240,u
        ldd   #$0000
        std   80,x
        std   ,x
        std   -80,x
        std   80,u
        std   ,u
        std   -80,u
        ldd   #$0D00
        std   83,x
        std   3,x
        ldd   #$DD00
        std   -77,x
        ldd   #$D700
        std   83,u
        ldd   #$CC00
        std   3,u
        ldd   #$0F00
        std   -77,u
        rts

pscroll.row.02
        leax  240,u
        ldd   #$0000
        std   80,x
        std   ,x
        std   -80,x
        std   80,u
        std   ,u
        std   -80,u
        ldd   #$DC00
        std   83,x
        std   3,x
        std   -77,x
        ldd   #$7A00
        std   83,u
        ldd   #$CF00
        std   3,u
        ldd   #$FF00
        std   -77,u
        rts

pscroll.row.03
        leax  240,u
        ldd   #$0000
        std   80,x
        std   ,x
        std   -80,x
        std   80,u
        std   ,u
        std   -80,u
        ldd   #$C000
        std   83,x
        std   3,x
        std   -77,x
        ldd   #$A000
        std   83,u
        ldd   #$F000
        std   3,u
        std   -77,u
        rts

pscroll.row.04
        leax  240,u
        ldd   #$0000
        std   80,x
        std   83,x
        std   ,x
        std   3,x
        std   -77,x
        std   83,u
        std   3,u
        std   -80,u
        std   -77,u
        ldd   #$000D
        std   -80,x
        std   80,u
        ldd   #$000C
        std   ,u
        rts

pscroll.row.05
        leax  240,u
        ldd   #$000D
        std   80,x
        std   ,x
        ldd   #$0000
        std   83,x
        std   3,x
        std   -77,x
        std   83,u
        std   3,u
        std   -77,u
        ldd   #$00DD
        std   -80,x
        ldd   #$00D7
        std   80,u
        ldd   #$00CC
        std   ,u
        ldd   #$000F
        std   -80,u
        rts

pscroll.row.06
        leax  240,u
        ldd   #$00DC
        std   80,x
        std   ,x
        std   -80,x
        ldd   #$0000
        std   83,x
        std   3,x
        std   -77,x
        std   83,u
        std   3,u
        std   -77,u
        ldd   #$007A
        std   80,u
        ldd   #$00CF
        std   ,u
        ldd   #$00FF
        std   -80,u
        rts

pscroll.row.07
        leax  240,u
        ldd   #$00C0
        std   80,x
        std   ,x
        std   -80,x
        ldd   #$0000
        std   83,x
        std   3,x
        std   -77,x
        std   83,u
        std   3,u
        std   -77,u
        ldd   #$00A0
        std   80,u
        ldd   #$00F0
        std   ,u
        std   -80,u
        rts

pscroll.row.08
        leax  240,u
        ldd   #$0000
        std   80,x
        std   83,x
        std   ,x
        std   3,x
        std   -77,x
        std   83,u
        std   3,u
        std   -80,u
        std   -77,u
        ldd   #$0D00
        std   -80,x
        std   80,u
        ldd   #$0C00
        std   ,u
        rts

pscroll.row.09
        leax  240,u
        ldd   #$0000
        std   80,x
        std   83,x
        std   ,x
        std   3,x
        std   -80,x
        std   80,u
        std   ,u
        std   -80,u
        std   -77,u
        ldd   #$000D
        std   -77,x
        std   83,u
        ldd   #$000C
        std   3,u
        rts

pscroll.row.10
        leax  240,u
        ldd   #$0D00
        std   80,x
        std   ,x
        ldd   #$000D
        std   83,x
        std   3,x
        ldd   #$DD00
        std   -80,x
        ldd   #$00DD
        std   -77,x
        ldd   #$D700
        std   80,u
        ldd   #$00D7
        std   83,u
        ldd   #$CC00
        std   ,u
        ldd   #$00CC
        std   3,u
        ldd   #$0F00
        std   -80,u
        ldd   #$000F
        std   -77,u
        rts

pscroll.row.11
        leax  240,u
        ldd   #$0000
        std   80,x
        std   ,x
        std   -80,x
        std   80,u
        std   ,u
        std   -80,u
        ldd   #$000D
        std   83,x
        std   3,x
        ldd   #$00DD
        std   -77,x
        ldd   #$00D7
        std   83,u
        ldd   #$00CC
        std   3,u
        ldd   #$000F
        std   -77,u
        rts

pscroll.row.12
        leax  240,u
        ldd   #$DC00
        std   80,x
        std   ,x
        std   -80,x
        ldd   #$00DC
        std   83,x
        std   3,x
        std   -77,x
        ldd   #$7A00
        std   80,u
        ldd   #$007A
        std   83,u
        ldd   #$CF00
        std   ,u
        ldd   #$00CF
        std   3,u
        ldd   #$FF00
        std   -80,u
        ldd   #$00FF
        std   -77,u
        rts

pscroll.row.13
        leax  240,u
        ldd   #$0000
        std   80,x
        std   ,x
        std   -80,x
        std   80,u
        std   ,u
        std   -80,u
        ldd   #$00DC
        std   83,x
        std   3,x
        std   -77,x
        ldd   #$007A
        std   83,u
        ldd   #$00CF
        std   3,u
        ldd   #$00FF
        std   -77,u
        rts

pscroll.row.14
        leax  240,u
        ldd   #$C000
        std   80,x
        std   ,x
        std   -80,x
        ldd   #$00C0
        std   83,x
        std   3,x
        std   -77,x
        ldd   #$A000
        std   80,u
        ldd   #$00A0
        std   83,u
        ldd   #$F000
        std   ,u
        std   -80,u
        ldd   #$00F0
        std   3,u
        std   -77,u
        rts

pscroll.row.15
        leax  240,u
        ldd   #$0000
        std   80,x
        std   ,x
        std   -80,x
        std   80,u
        std   ,u
        std   -80,u
        ldd   #$00C0
        std   83,x
        std   3,x
        std   -77,x
        ldd   #$00A0
        std   83,u
        ldd   #$00F0
        std   3,u
        std   -77,u
        rts

pscroll.row.16
        leax  240,u
        ldd   #$0000
        std   80,x
        std   83,x
        std   ,x
        std   3,x
        std   -80,x
        std   80,u
        std   ,u
        std   -80,u
        std   -77,u
        ldd   #$0D00
        std   -77,x
        std   83,u
        ldd   #$0C00
        std   3,u
        rts

pscroll.row.17
        leax  240,u
        ldd   #$0DDC
        std   80,x
        std   ,x
        ldd   #$C00D
        std   83,x
        std   3,x
        ldd   #$DDDC
        std   -80,x
        ldd   #$CDDD
        std   -77,x
        ldd   #$D77A
        std   80,u
        ldd   #$ADD7
        std   83,u
        ldd   #$CCCF
        std   ,u
        ldd   #$FCCC
        std   3,u
        ldd   #$0FFF
        std   -80,u
        ldd   #$F00F
        std   -77,u
        rts

pscroll.row.18
        leax  240,u
        ldd   #$DCC0
        std   80,x
        std   ,x
        ldd   #$0DDC
        std   83,x
        std   3,x
        ldd   #$DCCD
        std   -80,x
        ldd   #$DDDC
        std   -77,x
        ldd   #$7AAD
        std   80,u
        ldd   #$D77A
        std   83,u
        ldd   #$CFFC
        std   ,u
        ldd   #$CCCF
        std   3,u
        ldd   #$FFF0
        std   -80,u
        ldd   #$0FFF
        std   -77,u
        rts

pscroll.row.19
        leax  240,u
        ldd   #$C00D
        std   80,x
        std   ,x
        ldd   #$DCC0
        std   83,x
        std   3,x
        ldd   #$CDDD
        std   -80,x
        ldd   #$DCCD
        std   -77,x
        ldd   #$ADD7
        std   80,u
        ldd   #$7AAD
        std   83,u
        ldd   #$FCCC
        std   ,u
        ldd   #$CFFC
        std   3,u
        ldd   #$F00F
        std   -80,u
        ldd   #$FFF0
        std   -77,u
        rts

pscroll.row.20
        leax  240,u
        ldd   #$0D00
        std   80,x
        std   ,x
        ldd   #$0000
        std   83,x
        std   3,x
        std   -77,x
        std   83,u
        std   3,u
        std   -77,u
        ldd   #$DD00
        std   -80,x
        ldd   #$D700
        std   80,u
        ldd   #$CC00
        std   ,u
        ldd   #$0F00
        std   -80,u
        rts

pscroll.row.21
        leax  240,u
        ldd   #$DC00
        std   80,x
        std   ,x
        std   -80,x
        ldd   #$0000
        std   83,x
        std   3,x
        std   -77,x
        std   83,u
        std   3,u
        std   -77,u
        ldd   #$7A00
        std   80,u
        ldd   #$CF00
        std   ,u
        ldd   #$FF00
        std   -80,u
        rts

pscroll.row.22
        leax  240,u
        ldd   #$C000
        std   80,x
        std   ,x
        std   -80,x
        ldd   #$0000
        std   83,x
        std   3,x
        std   -77,u
        ldd   #$000D
        std   -77,x
        std   83,u
        ldd   #$A000
        std   80,u
        ldd   #$F000
        std   ,u
        std   -80,u
        ldd   #$000C
        std   3,u
        rts

pscroll.row.23
        leax  240,u
        ldd   #$DCC0
        std   80,x
        std   ,x
        ldd   #$0000
        std   83,x
        std   3,x
        std   -77,x
        std   83,u
        std   3,u
        std   -77,u
        ldd   #$DCCD
        std   -80,x
        ldd   #$7AAD
        std   80,u
        ldd   #$CFFC
        std   ,u
        ldd   #$FFF0
        std   -80,u
        rts

pscroll.row.24
        leax  240,u
        ldd   #$0000
        std   80,x
        std   ,x
        std   -80,x
        std   80,u
        std   ,u
        std   -80,u
        ldd   #$0DDC
        std   83,x
        std   3,x
        ldd   #$DDDC
        std   -77,x
        ldd   #$D77A
        std   83,u
        ldd   #$CCCF
        std   3,u
        ldd   #$0FFF
        std   -77,u
        rts

pscroll.row.25
        leax  240,u
        ldd   #$C00D
        std   80,x
        std   ,x
        ldd   #$0000
        std   83,x
        std   3,x
        std   -77,x
        std   83,u
        std   3,u
        std   -77,u
        ldd   #$CDDD
        std   -80,x
        ldd   #$ADD7
        std   80,u
        ldd   #$FCCC
        std   ,u
        ldd   #$F00F
        std   -80,u
        rts

pscroll.row.26
        leax  240,u
        ldd   #$0000
        std   80,x
        std   ,x
        std   -80,x
        std   80,u
        std   ,u
        std   -80,u
        ldd   #$DCC0
        std   83,x
        std   3,x
        ldd   #$DCCD
        std   -77,x
        ldd   #$7AAD
        std   83,u
        ldd   #$CFFC
        std   3,u
        ldd   #$FFF0
        std   -77,u
        rts

pscroll.row.27
        leax  240,u
        ldd   #$0DDC
        std   80,x
        std   ,x
        ldd   #$0000
        std   83,x
        std   3,x
        std   -77,x
        std   83,u
        std   3,u
        std   -77,u
        ldd   #$DDDC
        std   -80,x
        ldd   #$D77A
        std   80,u
        ldd   #$CCCF
        std   ,u
        ldd   #$0FFF
        std   -80,u
        rts

pscroll.row.28
        leax  240,u
        ldd   #$0000
        std   80,x
        std   ,x
        std   -80,x
        std   80,u
        std   ,u
        std   -80,u
        ldd   #$C00D
        std   83,x
        std   3,x
        ldd   #$CDDD
        std   -77,x
        ldd   #$ADD7
        std   83,u
        ldd   #$FCCC
        std   3,u
        ldd   #$F00F
        std   -77,u
        rts

pscroll.row.29
        leax  240,u
        ldd   #$DCC0
        std   80,x
        std   ,x
        std   -80,x
        ldd   #$0000
        std   83,x
        std   3,x
        std   -77,x
        std   83,u
        std   3,u
        std   -77,u
        ldd   #$7AA0
        std   80,u
        ldd   #$CFF0
        std   ,u
        ldd   #$FFF0
        std   -80,u
        rts

pscroll.row.30
        leax  240,u
        ldd   #$0000
        std   80,x
        std   ,x
        std   -80,u
        ldd   #$0DDC
        std   83,x
        std   3,x
        ldd   #$000D
        std   -80,x
        std   80,u
        ldd   #$DDDC
        std   -77,x
        ldd   #$D77A
        std   83,u
        ldd   #$000C
        std   ,u
        ldd   #$CCCF
        std   3,u
        ldd   #$0FFF
        std   -77,u
        rts

pscroll.row.31
        leax  240,u
        ldd   #$C00D
        std   80,x
        std   ,x
        ldd   #$DCC0
        std   83,x
        std   3,x
        std   -77,x
        ldd   #$CDDD
        std   -80,x
        ldd   #$ADD7
        std   80,u
        ldd   #$7AA0
        std   83,u
        ldd   #$FCCC
        std   ,u
        ldd   #$CFF0
        std   3,u
        ldd   #$F00F
        std   -80,u
        ldd   #$FFF0
        std   -77,u
        rts

pscroll.row.32
        leax  240,u
        ldd   #$000D
        std   80,x
        std   ,x
        ldd   #$DCC0
        std   83,x
        std   3,x
        std   -77,x
        ldd   #$00DD
        std   -80,x
        ldd   #$00D7
        std   80,u
        ldd   #$7AA0
        std   83,u
        ldd   #$00CC
        std   ,u
        ldd   #$CFF0
        std   3,u
        ldd   #$000F
        std   -80,u
        ldd   #$FFF0
        std   -77,u
        rts

; --- les 16 routines d'ecriture d'une cellule ---------------------------
; cas = (3*colonne - phase) mod 16. Entree : les bases/pages des deux
; plans dans pscroll.wr.*, pointant la ligne du buffer qui porte la
; ligne 0 du motif — soit la ligne la PLUS HAUTE de la rangee, l'axe du
; buffer croissant vers le haut de l'ecran.
pscroll.wr.00
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   #$0D
        sta   80,u
        sta   ,u
        lda   #$DD
        sta   -80,u
        lda   #$D7
        sta   80,x
        lda   #$CC
        sta   ,x
        lda   #$0F
        sta   -80,x
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   80,u
        anda  #$0F
        ora   #$C0
        sta   80,u
        lda   ,u
        anda  #$0F
        ora   #$C0
        sta   ,u
        lda   -80,u
        anda  #$0F
        ora   #$C0
        sta   -80,u
        lda   80,x
        anda  #$0F
        ora   #$A0
        sta   80,x
        lda   ,x
        anda  #$0F
        ora   #$F0
        sta   ,x
        lda   -80,x
        anda  #$0F
        ora   #$F0
        sta   -80,x
        rts

pscroll.wr.01
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   #$DC
        sta   80,u
        sta   ,u
        sta   -80,u
        lda   #$7A
        sta   80,x
        lda   #$CF
        sta   ,x
        lda   #$FF
        sta   -80,x
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   80,u
        anda  #$F0
        sta   80,u
        lda   ,u
        anda  #$F0
        sta   ,u
        lda   -80,u
        anda  #$F0
        ora   #$0D
        sta   -80,u
        lda   80,x
        anda  #$F0
        ora   #$0D
        sta   80,x
        lda   ,x
        anda  #$F0
        ora   #$0C
        sta   ,x
        lda   -80,x
        anda  #$F0
        sta   -80,x
        rts

pscroll.wr.02
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   #$0D
        sta   80,u
        sta   ,u
        lda   #$DD
        sta   -80,u
        lda   #$D7
        sta   80,x
        lda   #$CC
        sta   ,x
        lda   #$0F
        sta   -80,x
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   81,u
        anda  #$0F
        ora   #$C0
        sta   81,u
        lda   1,u
        anda  #$0F
        ora   #$C0
        sta   1,u
        lda   -79,u
        anda  #$0F
        ora   #$C0
        sta   -79,u
        lda   81,x
        anda  #$0F
        ora   #$A0
        sta   81,x
        lda   1,x
        anda  #$0F
        ora   #$F0
        sta   1,x
        lda   -79,x
        anda  #$0F
        ora   #$F0
        sta   -79,x
        rts

pscroll.wr.03
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   #$DC
        sta   81,u
        sta   1,u
        sta   -79,u
        lda   #$7A
        sta   81,x
        lda   #$CF
        sta   1,x
        lda   #$FF
        sta   -79,x
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   80,u
        anda  #$F0
        sta   80,u
        lda   ,u
        anda  #$F0
        sta   ,u
        lda   -80,u
        anda  #$F0
        ora   #$0D
        sta   -80,u
        lda   80,x
        anda  #$F0
        ora   #$0D
        sta   80,x
        lda   ,x
        anda  #$F0
        ora   #$0C
        sta   ,x
        lda   -80,x
        anda  #$F0
        sta   -80,x
        rts

pscroll.wr.04
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   #$0D
        sta   81,u
        sta   1,u
        lda   #$DD
        sta   -79,u
        lda   #$D7
        sta   81,x
        lda   #$CC
        sta   1,x
        lda   #$0F
        sta   -79,x
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   81,u
        anda  #$0F
        ora   #$C0
        sta   81,u
        lda   1,u
        anda  #$0F
        ora   #$C0
        sta   1,u
        lda   -79,u
        anda  #$0F
        ora   #$C0
        sta   -79,u
        lda   81,x
        anda  #$0F
        ora   #$A0
        sta   81,x
        lda   1,x
        anda  #$0F
        ora   #$F0
        sta   1,x
        lda   -79,x
        anda  #$0F
        ora   #$F0
        sta   -79,x
        rts

pscroll.wr.05
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   #$DC
        sta   81,u
        sta   1,u
        sta   -79,u
        lda   #$7A
        sta   81,x
        lda   #$CF
        sta   1,x
        lda   #$FF
        sta   -79,x
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   81,u
        anda  #$F0
        sta   81,u
        lda   1,u
        anda  #$F0
        sta   1,u
        lda   -79,u
        anda  #$F0
        ora   #$0D
        sta   -79,u
        lda   81,x
        anda  #$F0
        ora   #$0D
        sta   81,x
        lda   1,x
        anda  #$F0
        ora   #$0C
        sta   1,x
        lda   -79,x
        anda  #$F0
        sta   -79,x
        rts

pscroll.wr.06
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   #$0D
        sta   81,u
        sta   1,u
        lda   #$DD
        sta   -79,u
        lda   #$D7
        sta   81,x
        lda   #$CC
        sta   1,x
        lda   #$0F
        sta   -79,x
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   83,u
        anda  #$0F
        ora   #$C0
        sta   83,u
        lda   3,u
        anda  #$0F
        ora   #$C0
        sta   3,u
        lda   -77,u
        anda  #$0F
        ora   #$C0
        sta   -77,u
        lda   83,x
        anda  #$0F
        ora   #$A0
        sta   83,x
        lda   3,x
        anda  #$0F
        ora   #$F0
        sta   3,x
        lda   -77,x
        anda  #$0F
        ora   #$F0
        sta   -77,x
        rts

pscroll.wr.07
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   #$DC
        sta   83,u
        sta   3,u
        sta   -77,u
        lda   #$7A
        sta   83,x
        lda   #$CF
        sta   3,x
        lda   #$FF
        sta   -77,x
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   81,u
        anda  #$F0
        sta   81,u
        lda   1,u
        anda  #$F0
        sta   1,u
        lda   -79,u
        anda  #$F0
        ora   #$0D
        sta   -79,u
        lda   81,x
        anda  #$F0
        ora   #$0D
        sta   81,x
        lda   1,x
        anda  #$F0
        ora   #$0C
        sta   1,x
        lda   -79,x
        anda  #$F0
        sta   -79,x
        rts

pscroll.wr.08
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   #$0D
        sta   83,u
        sta   3,u
        lda   #$DD
        sta   -77,u
        lda   #$D7
        sta   83,x
        lda   #$CC
        sta   3,x
        lda   #$0F
        sta   -77,x
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   83,u
        anda  #$0F
        ora   #$C0
        sta   83,u
        lda   3,u
        anda  #$0F
        ora   #$C0
        sta   3,u
        lda   -77,u
        anda  #$0F
        ora   #$C0
        sta   -77,u
        lda   83,x
        anda  #$0F
        ora   #$A0
        sta   83,x
        lda   3,x
        anda  #$0F
        ora   #$F0
        sta   3,x
        lda   -77,x
        anda  #$0F
        ora   #$F0
        sta   -77,x
        rts

pscroll.wr.09
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   #$DC
        sta   83,u
        sta   3,u
        sta   -77,u
        lda   #$7A
        sta   83,x
        lda   #$CF
        sta   3,x
        lda   #$FF
        sta   -77,x
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   83,u
        anda  #$F0
        sta   83,u
        lda   3,u
        anda  #$F0
        sta   3,u
        lda   -77,u
        anda  #$F0
        ora   #$0D
        sta   -77,u
        lda   83,x
        anda  #$F0
        ora   #$0D
        sta   83,x
        lda   3,x
        anda  #$F0
        ora   #$0C
        sta   3,x
        lda   -77,x
        anda  #$F0
        sta   -77,x
        rts

pscroll.wr.10
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   #$0D
        sta   83,u
        sta   3,u
        lda   #$DD
        sta   -77,u
        lda   #$D7
        sta   83,x
        lda   #$CC
        sta   3,x
        lda   #$0F
        sta   -77,x
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   84,u
        anda  #$0F
        ora   #$C0
        sta   84,u
        lda   4,u
        anda  #$0F
        ora   #$C0
        sta   4,u
        lda   -76,u
        anda  #$0F
        ora   #$C0
        sta   -76,u
        lda   84,x
        anda  #$0F
        ora   #$A0
        sta   84,x
        lda   4,x
        anda  #$0F
        ora   #$F0
        sta   4,x
        lda   -76,x
        anda  #$0F
        ora   #$F0
        sta   -76,x
        rts

pscroll.wr.11
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   #$DC
        sta   84,u
        sta   4,u
        sta   -76,u
        lda   #$7A
        sta   84,x
        lda   #$CF
        sta   4,x
        lda   #$FF
        sta   -76,x
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   83,u
        anda  #$F0
        sta   83,u
        lda   3,u
        anda  #$F0
        sta   3,u
        lda   -77,u
        anda  #$F0
        ora   #$0D
        sta   -77,u
        lda   83,x
        anda  #$F0
        ora   #$0D
        sta   83,x
        lda   3,x
        anda  #$F0
        ora   #$0C
        sta   3,x
        lda   -77,x
        anda  #$F0
        sta   -77,x
        rts

pscroll.wr.12
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   #$0D
        sta   84,u
        sta   4,u
        lda   #$DD
        sta   -76,u
        lda   #$D7
        sta   84,x
        lda   #$CC
        sta   4,x
        lda   #$0F
        sta   -76,x
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   84,u
        anda  #$0F
        ora   #$C0
        sta   84,u
        lda   4,u
        anda  #$0F
        ora   #$C0
        sta   4,u
        lda   -76,u
        anda  #$0F
        ora   #$C0
        sta   -76,u
        lda   84,x
        anda  #$0F
        ora   #$A0
        sta   84,x
        lda   4,x
        anda  #$0F
        ora   #$F0
        sta   4,x
        lda   -76,x
        anda  #$0F
        ora   #$F0
        sta   -76,x
        rts

pscroll.wr.13
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   #$DC
        sta   84,u
        sta   4,u
        sta   -76,u
        lda   #$7A
        sta   84,x
        lda   #$CF
        sta   4,x
        lda   #$FF
        sta   -76,x
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   84,u
        anda  #$F0
        sta   84,u
        lda   4,u
        anda  #$F0
        sta   4,u
        lda   -76,u
        anda  #$F0
        ora   #$0D
        sta   -76,u
        lda   84,x
        anda  #$F0
        ora   #$0D
        sta   84,x
        lda   4,x
        anda  #$F0
        ora   #$0C
        sta   4,x
        lda   -76,x
        anda  #$F0
        sta   -76,x
        rts

pscroll.wr.14
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   #$0D
        sta   84,u
        sta   4,u
        lda   #$DD
        sta   -76,u
        lda   #$D7
        sta   84,x
        lda   #$CC
        sta   4,x
        lda   #$0F
        sta   -76,x
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   72,u
        anda  #$0F
        ora   #$C0
        sta   72,u
        lda   -8,u
        anda  #$0F
        ora   #$C0
        sta   -8,u
        lda   -88,u
        anda  #$0F
        ora   #$C0
        sta   -88,u
        lda   72,x
        anda  #$0F
        ora   #$A0
        sta   72,x
        lda   -8,x
        anda  #$0F
        ora   #$F0
        sta   -8,x
        lda   -88,x
        anda  #$0F
        ora   #$F0
        sta   -88,x
        rts

pscroll.wr.15
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   #$DC
        sta   72,u
        sta   -8,u
        sta   -88,u
        lda   #$7A
        sta   72,x
        lda   #$CF
        sta   -8,x
        lda   #$FF
        sta   -88,x
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   84,u
        anda  #$F0
        sta   84,u
        lda   4,u
        anda  #$F0
        sta   4,u
        lda   -76,u
        anda  #$F0
        ora   #$0D
        sta   -76,u
        lda   84,x
        anda  #$F0
        ora   #$0D
        sta   84,x
        lda   4,x
        anda  #$F0
        ora   #$0C
        sta   4,x
        lda   -76,x
        anda  #$F0
        sta   -76,x
        rts

; l'aiguillage : (3*colonne - phase) mod 16 -> la routine
pscroll.wr.tbl
        fdb   pscroll.wr.00
        fdb   pscroll.wr.01
        fdb   pscroll.wr.02
        fdb   pscroll.wr.03
        fdb   pscroll.wr.04
        fdb   pscroll.wr.05
        fdb   pscroll.wr.06
        fdb   pscroll.wr.07
        fdb   pscroll.wr.08
        fdb   pscroll.wr.09
        fdb   pscroll.wr.10
        fdb   pscroll.wr.11
        fdb   pscroll.wr.12
        fdb   pscroll.wr.13
        fdb   pscroll.wr.14
        fdb   pscroll.wr.15

; --- les 16 routines d'EFFACEMENT d'une cellule -------------------------
; Meme aiguillage que l'ecriture. La valeur est le fond, constante :
; l'octet plein ne se recharge donc qu'une fois.
pscroll.er.00
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   #$00
        sta   80,u
        sta   ,u
        sta   -80,u
        sta   80,x
        sta   ,x
        sta   -80,x
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   80,u
        anda  #$0F
        sta   80,u
        lda   ,u
        anda  #$0F
        sta   ,u
        lda   -80,u
        anda  #$0F
        sta   -80,u
        lda   80,x
        anda  #$0F
        sta   80,x
        lda   ,x
        anda  #$0F
        sta   ,x
        lda   -80,x
        anda  #$0F
        sta   -80,x
        rts

pscroll.er.01
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   #$00
        sta   80,u
        sta   ,u
        sta   -80,u
        sta   80,x
        sta   ,x
        sta   -80,x
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   80,u
        anda  #$F0
        sta   80,u
        lda   ,u
        anda  #$F0
        sta   ,u
        lda   -80,u
        anda  #$F0
        sta   -80,u
        lda   80,x
        anda  #$F0
        sta   80,x
        lda   ,x
        anda  #$F0
        sta   ,x
        lda   -80,x
        anda  #$F0
        sta   -80,x
        rts

pscroll.er.02
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   #$00
        sta   80,u
        sta   ,u
        sta   -80,u
        sta   80,x
        sta   ,x
        sta   -80,x
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   81,u
        anda  #$0F
        sta   81,u
        lda   1,u
        anda  #$0F
        sta   1,u
        lda   -79,u
        anda  #$0F
        sta   -79,u
        lda   81,x
        anda  #$0F
        sta   81,x
        lda   1,x
        anda  #$0F
        sta   1,x
        lda   -79,x
        anda  #$0F
        sta   -79,x
        rts

pscroll.er.03
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   #$00
        sta   81,u
        sta   1,u
        sta   -79,u
        sta   81,x
        sta   1,x
        sta   -79,x
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   80,u
        anda  #$F0
        sta   80,u
        lda   ,u
        anda  #$F0
        sta   ,u
        lda   -80,u
        anda  #$F0
        sta   -80,u
        lda   80,x
        anda  #$F0
        sta   80,x
        lda   ,x
        anda  #$F0
        sta   ,x
        lda   -80,x
        anda  #$F0
        sta   -80,x
        rts

pscroll.er.04
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   #$00
        sta   81,u
        sta   1,u
        sta   -79,u
        sta   81,x
        sta   1,x
        sta   -79,x
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   81,u
        anda  #$0F
        sta   81,u
        lda   1,u
        anda  #$0F
        sta   1,u
        lda   -79,u
        anda  #$0F
        sta   -79,u
        lda   81,x
        anda  #$0F
        sta   81,x
        lda   1,x
        anda  #$0F
        sta   1,x
        lda   -79,x
        anda  #$0F
        sta   -79,x
        rts

pscroll.er.05
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   #$00
        sta   81,u
        sta   1,u
        sta   -79,u
        sta   81,x
        sta   1,x
        sta   -79,x
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   81,u
        anda  #$F0
        sta   81,u
        lda   1,u
        anda  #$F0
        sta   1,u
        lda   -79,u
        anda  #$F0
        sta   -79,u
        lda   81,x
        anda  #$F0
        sta   81,x
        lda   1,x
        anda  #$F0
        sta   1,x
        lda   -79,x
        anda  #$F0
        sta   -79,x
        rts

pscroll.er.06
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   #$00
        sta   81,u
        sta   1,u
        sta   -79,u
        sta   81,x
        sta   1,x
        sta   -79,x
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   83,u
        anda  #$0F
        sta   83,u
        lda   3,u
        anda  #$0F
        sta   3,u
        lda   -77,u
        anda  #$0F
        sta   -77,u
        lda   83,x
        anda  #$0F
        sta   83,x
        lda   3,x
        anda  #$0F
        sta   3,x
        lda   -77,x
        anda  #$0F
        sta   -77,x
        rts

pscroll.er.07
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   #$00
        sta   83,u
        sta   3,u
        sta   -77,u
        sta   83,x
        sta   3,x
        sta   -77,x
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   81,u
        anda  #$F0
        sta   81,u
        lda   1,u
        anda  #$F0
        sta   1,u
        lda   -79,u
        anda  #$F0
        sta   -79,u
        lda   81,x
        anda  #$F0
        sta   81,x
        lda   1,x
        anda  #$F0
        sta   1,x
        lda   -79,x
        anda  #$F0
        sta   -79,x
        rts

pscroll.er.08
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   #$00
        sta   83,u
        sta   3,u
        sta   -77,u
        sta   83,x
        sta   3,x
        sta   -77,x
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   83,u
        anda  #$0F
        sta   83,u
        lda   3,u
        anda  #$0F
        sta   3,u
        lda   -77,u
        anda  #$0F
        sta   -77,u
        lda   83,x
        anda  #$0F
        sta   83,x
        lda   3,x
        anda  #$0F
        sta   3,x
        lda   -77,x
        anda  #$0F
        sta   -77,x
        rts

pscroll.er.09
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   #$00
        sta   83,u
        sta   3,u
        sta   -77,u
        sta   83,x
        sta   3,x
        sta   -77,x
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   83,u
        anda  #$F0
        sta   83,u
        lda   3,u
        anda  #$F0
        sta   3,u
        lda   -77,u
        anda  #$F0
        sta   -77,u
        lda   83,x
        anda  #$F0
        sta   83,x
        lda   3,x
        anda  #$F0
        sta   3,x
        lda   -77,x
        anda  #$F0
        sta   -77,x
        rts

pscroll.er.10
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   #$00
        sta   83,u
        sta   3,u
        sta   -77,u
        sta   83,x
        sta   3,x
        sta   -77,x
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   84,u
        anda  #$0F
        sta   84,u
        lda   4,u
        anda  #$0F
        sta   4,u
        lda   -76,u
        anda  #$0F
        sta   -76,u
        lda   84,x
        anda  #$0F
        sta   84,x
        lda   4,x
        anda  #$0F
        sta   4,x
        lda   -76,x
        anda  #$0F
        sta   -76,x
        rts

pscroll.er.11
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   #$00
        sta   84,u
        sta   4,u
        sta   -76,u
        sta   84,x
        sta   4,x
        sta   -76,x
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   83,u
        anda  #$F0
        sta   83,u
        lda   3,u
        anda  #$F0
        sta   3,u
        lda   -77,u
        anda  #$F0
        sta   -77,u
        lda   83,x
        anda  #$F0
        sta   83,x
        lda   3,x
        anda  #$F0
        sta   3,x
        lda   -77,x
        anda  #$F0
        sta   -77,x
        rts

pscroll.er.12
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   #$00
        sta   84,u
        sta   4,u
        sta   -76,u
        sta   84,x
        sta   4,x
        sta   -76,x
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   84,u
        anda  #$0F
        sta   84,u
        lda   4,u
        anda  #$0F
        sta   4,u
        lda   -76,u
        anda  #$0F
        sta   -76,u
        lda   84,x
        anda  #$0F
        sta   84,x
        lda   4,x
        anda  #$0F
        sta   4,x
        lda   -76,x
        anda  #$0F
        sta   -76,x
        rts

pscroll.er.13
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   #$00
        sta   84,u
        sta   4,u
        sta   -76,u
        sta   84,x
        sta   4,x
        sta   -76,x
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   84,u
        anda  #$F0
        sta   84,u
        lda   4,u
        anda  #$F0
        sta   4,u
        lda   -76,u
        anda  #$F0
        sta   -76,u
        lda   84,x
        anda  #$F0
        sta   84,x
        lda   4,x
        anda  #$F0
        sta   4,x
        lda   -76,x
        anda  #$F0
        sta   -76,x
        rts

pscroll.er.14
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   #$00
        sta   84,u
        sta   4,u
        sta   -76,u
        sta   84,x
        sta   4,x
        sta   -76,x
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   72,u
        anda  #$0F
        sta   72,u
        lda   -8,u
        anda  #$0F
        sta   -8,u
        lda   -88,u
        anda  #$0F
        sta   -88,u
        lda   72,x
        anda  #$0F
        sta   72,x
        lda   -8,x
        anda  #$0F
        sta   -8,x
        lda   -88,x
        anda  #$0F
        sta   -88,x
        rts

pscroll.er.15
        lda   pscroll.wr.page0
        _SetCartPageA
        ldu   pscroll.wr.base0
        leax  -240,u
        lda   #$00
        sta   72,u
        sta   -8,u
        sta   -88,u
        sta   72,x
        sta   -8,x
        sta   -88,x
        lda   pscroll.wr.page1
        _SetCartPageA
        ldu   pscroll.wr.base1
        leax  -240,u
        lda   84,u
        anda  #$F0
        sta   84,u
        lda   4,u
        anda  #$F0
        sta   4,u
        lda   -76,u
        anda  #$F0
        sta   -76,u
        lda   84,x
        anda  #$F0
        sta   84,x
        lda   4,x
        anda  #$F0
        sta   4,x
        lda   -76,x
        anda  #$F0
        sta   -76,x
        rts

; l'aiguillage de l'effacement
pscroll.er.tbl
        fdb   pscroll.er.00
        fdb   pscroll.er.01
        fdb   pscroll.er.02
        fdb   pscroll.er.03
        fdb   pscroll.er.04
        fdb   pscroll.er.05
        fdb   pscroll.er.06
        fdb   pscroll.er.07
        fdb   pscroll.er.08
        fdb   pscroll.er.09
        fdb   pscroll.er.10
        fdb   pscroll.er.11
        fdb   pscroll.er.12
        fdb   pscroll.er.13
        fdb   pscroll.er.14
        fdb   pscroll.er.15

; --- le groupe de couture de chaque bande, et sa derniere bande ---------
pscroll.seamof.tbl
        fcb   0,0,0,0,0,0,0,0,0,0,1,1
        fcb   1,1,1,1,1,1,1,1,2,2,2,2
        fcb   2,2,2,2,2,2,3,3,3,3,3,3
        fcb   3,3,3,3,4,4,4,4,4,4,4,4
        fcb   4,4,5,5,5,5,5,5,5,5,5,5
        fcb   6,6,6,6,6,6,6,6,6,6,7,7

pscroll.seamlast.tbl
        fcb   9,19,29,39,49,59,69,79

; --- la premiere cellule de chaque bande --------------------------------
pscroll.chunkfirst.tbl
        fdb   0   ; bande 0
        fdb   6
        fdb   11
        fdb   16
        fdb   22
        fdb   27
        fdb   32
        fdb   38
        fdb   43
        fdb   48
        fdb   54   ; bande 10
        fdb   59
        fdb   64
        fdb   70
        fdb   75
        fdb   80
        fdb   86
        fdb   91
        fdb   96
        fdb   102
        fdb   107   ; bande 20
        fdb   112
        fdb   118
        fdb   123
        fdb   128
        fdb   134
        fdb   139
        fdb   144
        fdb   150
        fdb   155
        fdb   160   ; bande 30
        fdb   166
        fdb   171
        fdb   176
        fdb   182
        fdb   187
        fdb   192
        fdb   198
        fdb   203
        fdb   208
        fdb   214   ; bande 40
        fdb   219
        fdb   224
        fdb   230
        fdb   235
        fdb   240
        fdb   246
        fdb   251
        fdb   256
        fdb   262
        fdb   267   ; bande 50
        fdb   272
        fdb   278
        fdb   283
        fdb   288
        fdb   294
        fdb   299
        fdb   304
        fdb   310
        fdb   315
        fdb   320   ; bande 60
        fdb   326
        fdb   331
        fdb   336
        fdb   342
        fdb   347
        fdb   352
        fdb   358
        fdb   363
        fdb   368
        fdb   374   ; bande 70
        fdb   379
        fdb   384

; --- l'effacement deroule : une rangee, dix bandes ----------------------
; 12 std par bande, trois bases (X,Y,U) pour six lignes, offsets 8 bits.
; On entre par pscroll.zrow.entry[bande] et on sort en patchant un rts.
pscroll.zrow
pscroll.zrow.09
        std   73,x
        std   76,x
        std   -7,x
        std   -4,x
        std   73,y
        std   76,y
        std   -7,y
        std   -4,y
        std   73,u
        std   76,u
        std   -7,u
        std   -4,u
pscroll.zrow.08
        std   65,x
        std   68,x
        std   -15,x
        std   -12,x
        std   65,y
        std   68,y
        std   -15,y
        std   -12,y
        std   65,u
        std   68,u
        std   -15,u
        std   -12,u
pscroll.zrow.07
        std   57,x
        std   60,x
        std   -23,x
        std   -20,x
        std   57,y
        std   60,y
        std   -23,y
        std   -20,y
        std   57,u
        std   60,u
        std   -23,u
        std   -20,u
pscroll.zrow.06
        std   49,x
        std   52,x
        std   -31,x
        std   -28,x
        std   49,y
        std   52,y
        std   -31,y
        std   -28,y
        std   49,u
        std   52,u
        std   -31,u
        std   -28,u
pscroll.zrow.05
        std   41,x
        std   44,x
        std   -39,x
        std   -36,x
        std   41,y
        std   44,y
        std   -39,y
        std   -36,y
        std   41,u
        std   44,u
        std   -39,u
        std   -36,u
pscroll.zrow.04
        std   33,x
        std   36,x
        std   -47,x
        std   -44,x
        std   33,y
        std   36,y
        std   -47,y
        std   -44,y
        std   33,u
        std   36,u
        std   -47,u
        std   -44,u
pscroll.zrow.03
        std   25,x
        std   28,x
        std   -55,x
        std   -52,x
        std   25,y
        std   28,y
        std   -55,y
        std   -52,y
        std   25,u
        std   28,u
        std   -55,u
        std   -52,u
pscroll.zrow.02
        std   17,x
        std   20,x
        std   -63,x
        std   -60,x
        std   17,y
        std   20,y
        std   -63,y
        std   -60,y
        std   17,u
        std   20,u
        std   -63,u
        std   -60,u
pscroll.zrow.01
        std   9,x
        std   12,x
        std   -71,x
        std   -68,x
        std   9,y
        std   12,y
        std   -71,y
        std   -68,y
        std   9,u
        std   12,u
        std   -71,u
        std   -68,u
pscroll.zrow.00
        std   1,x
        std   4,x
        std   -79,x
        std   -76,x
        std   1,y
        std   4,y
        std   -79,y
        std   -76,y
        std   1,u
        std   4,u
        std   -79,u
        std   -76,u
        rts                            ; sortie naturelle : le run va
                                       ; jusqu'au bord du ruban

; l'entree, par emplacement de ruban de la PREMIERE bande du run
pscroll.zrow.entry
        fdb   pscroll.zrow.00
        fdb   pscroll.zrow.01
        fdb   pscroll.zrow.02
        fdb   pscroll.zrow.03
        fdb   pscroll.zrow.04
        fdb   pscroll.zrow.05
        fdb   pscroll.zrow.06
        fdb   pscroll.zrow.07
        fdb   pscroll.zrow.08
        fdb   pscroll.zrow.09

pscroll.ZROW_STEP equ 6*2*3          ; octets par bande dans la sequence

; --- l'offset d'une mutation, en deux termes ---------------------------
; dst = pscroll.ROW_BIAS*LINE_SIZE + rowbase[rangee] + bandoff[bande] + 1
; rowbase : le terme de rangee, axe du buffer inverse (rangee 0 en bas)
pscroll.rowbase.tbl
        fdb   14320   ; rangee 0
        fdb   13840
        fdb   13360
        fdb   12880
        fdb   12400
        fdb   11920
        fdb   11440
        fdb   10960
        fdb   10480
        fdb   10000
        fdb   9520   ; rangee 10
        fdb   9040
        fdb   8560
        fdb   8080
        fdb   7600
        fdb   7120
        fdb   6640
        fdb   6160
        fdb   5680
        fdb   5200
        fdb   4720   ; rangee 20
        fdb   4240
        fdb   3760
        fdb   3280
        fdb   2800
        fdb   2320
        fdb   1840
        fdb   1360
        fdb   880
        fdb   400

; bandoff : l'emplacement dans la ligne (INVERSE : la bande c peint la
; colonne 9-c) MOINS le cisaillement de ses coutures. Signe.
pscroll.bandoff.tbl
        fdb   72   ; bande 0
        fdb   64
        fdb   56
        fdb   48
        fdb   40
        fdb   32
        fdb   24
        fdb   16
        fdb   8
        fdb   0
        fdb   -8   ; bande 10
        fdb   -16
        fdb   -24
        fdb   -32
        fdb   -40
        fdb   -48
        fdb   -56
        fdb   -64
        fdb   -72
        fdb   -80
        fdb   -88   ; bande 20
        fdb   -96
        fdb   -104
        fdb   -112
        fdb   -120
        fdb   -128
        fdb   -136
        fdb   -144
        fdb   -152
        fdb   -160
        fdb   -168   ; bande 30
        fdb   -176
        fdb   -184
        fdb   -192
        fdb   -200
        fdb   -208
        fdb   -216
        fdb   -224
        fdb   -232
        fdb   -240
        fdb   -248   ; bande 40
        fdb   -256
        fdb   -264
        fdb   -272
        fdb   -280
        fdb   -288
        fdb   -296
        fdb   -304
        fdb   -312
        fdb   -320
        fdb   -328   ; bande 50
        fdb   -336
        fdb   -344
        fdb   -352
        fdb   -360
        fdb   -368
        fdb   -376
        fdb   -384
        fdb   -392
        fdb   -400
        fdb   -408   ; bande 60
        fdb   -416
        fdb   -424
        fdb   -432
        fdb   -440
        fdb   -448
        fdb   -456
        fdb   -464
        fdb   -472
        fdb   -480
        fdb   -488   ; bande 70
        fdb   -496

; --- les colonnes : 30 index de routine par (bande, plan, phase) -------
; Seules les colonnes NON VIDES portent une sequence ; les autres
; pointent 0 dans l'index, et le feed se contente alors d'y poser le
; fond (57 bandes sur 72 dans ce niveau).
pscroll.col.10.0.0
        fcb   0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0
pscroll.col.10.0.1
        fcb   0,0,0,0,0,0,0,0,0,0,0,2,2,2,2,2,2,2,2,2,2,2,2,2,0,0,0,0,0,0
pscroll.col.10.1.0
        fcb   0,0,0,0,0,0,0,0,0,0,0,3,3,3,3,3,3,3,3,3,3,3,3,3,0,0,0,0,0,0
pscroll.col.10.1.1
        fcb   0,0,0,0,0,0,0,0,0,0,0,4,4,4,4,4,4,4,4,4,4,4,4,4,0,0,0,0,0,0
pscroll.col.11.0.0
        fcb   0,0,0,0,0,0,0,0,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,0,0,0,0,0,0
pscroll.col.11.0.1
        fcb   0,0,0,0,0,0,0,0,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,0,0,0,0,0,0
pscroll.col.11.1.0
        fcb   0,0,0,0,0,0,0,0,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,0,0,0,0,0,0
pscroll.col.11.1.1
        fcb   0,0,0,0,0,0,0,0,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,0,0,0,0,0,0
pscroll.col.29.1.1
        fcb   0,0,0,0,0,0,0,0,0,0,0,9,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
pscroll.col.30.0.0
        fcb   0,0,0,0,0,0,0,0,11,11,11,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
pscroll.col.30.0.1
        fcb   0,0,0,0,0,0,0,0,13,13,13,12,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
pscroll.col.30.1.0
        fcb   0,0,0,0,0,0,0,0,15,15,15,14,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
pscroll.col.30.1.1
        fcb   0,0,0,0,0,0,0,0,16,16,16,16,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
pscroll.col.50.1.1
        fcb   0,0,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,0,0
pscroll.col.51.0.0
        fcb   0,0,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,0,0
pscroll.col.51.0.1
        fcb   0,0,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,0,0
pscroll.col.51.1.0
        fcb   0,0,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,0,0
pscroll.col.51.1.1
        fcb   0,0,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,0,0
pscroll.col.52.0.0
        fcb   0,0,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,0,0
pscroll.col.52.0.1
        fcb   0,0,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,0,0
pscroll.col.52.1.0
        fcb   0,0,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,0,0
pscroll.col.52.1.1
        fcb   0,0,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,0,0
pscroll.col.53.0.0
        fcb   0,0,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,0,0
pscroll.col.53.0.1
        fcb   0,0,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,0,0
pscroll.col.53.1.0
        fcb   0,0,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,0,0
pscroll.col.53.1.1
        fcb   0,0,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,9,9
pscroll.col.54.0.0
        fcb   0,0,17,17,17,17,17,20,20,20,20,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17
pscroll.col.54.0.1
        fcb   0,0,18,18,18,18,18,21,21,21,21,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18
pscroll.col.54.1.0
        fcb   0,0,19,19,19,19,19,22,22,22,22,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19
pscroll.col.54.1.1
        fcb   0,0,17,17,17,17,17,11,11,11,11,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17
pscroll.col.55.0.0
        fcb   24,24,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,23,23,23,23,23
pscroll.col.55.0.1
        fcb   26,26,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,25,25,25,25,25
pscroll.col.55.1.0
        fcb   28,28,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,27,27,27,27,27
pscroll.col.55.1.1
        fcb   30,30,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,29,29,29,29,29
pscroll.col.56.0.0
        fcb   19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,0,0,0,0,0
pscroll.col.56.0.1
        fcb   17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,0,0,0,0,0
pscroll.col.56.1.0
        fcb   18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,0,0,0,0,0
pscroll.col.56.1.1
        fcb   31,31,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,0,0,0,0,0
pscroll.col.57.0.0
        fcb   0,0,17,17,17,17,17,17,17,17,17,17,17,20,20,20,20,17,17,17,17,17,17,17,17,0,0,0,0,0
pscroll.col.57.0.1
        fcb   0,0,18,18,18,18,18,18,18,18,18,18,18,21,21,21,21,18,18,18,18,18,18,18,18,0,0,0,0,0
pscroll.col.57.1.0
        fcb   0,0,19,19,19,19,19,19,19,19,19,19,19,22,22,22,22,19,19,19,19,19,19,19,19,0,0,0,0,0
pscroll.col.57.1.1
        fcb   0,0,17,17,17,17,17,17,17,17,17,17,17,11,11,11,11,17,17,17,17,17,17,17,17,0,0,0,0,0
pscroll.col.58.0.0
        fcb   0,0,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,0,0,0,0,0
pscroll.col.58.0.1
        fcb   0,0,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,0,0,0,0,0
pscroll.col.58.1.0
        fcb   0,0,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,0,0,0,0,0
pscroll.col.58.1.1
        fcb   0,0,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,0,0,0,0,0
pscroll.col.59.0.0
        fcb   0,0,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,0,0,0,0,0
pscroll.col.59.0.1
        fcb   0,0,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,0,0,0,0,0
pscroll.col.59.1.0
        fcb   0,0,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,0,0,0,0,0
pscroll.col.59.1.1
        fcb   0,0,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,0,0,0,0,0
pscroll.col.60.0.0
        fcb   0,0,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,0,0,0,0,0
pscroll.col.60.0.1
        fcb   0,0,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,0,0,0,0,0
pscroll.col.60.1.0
        fcb   0,0,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,0,0,0,0,0
pscroll.col.60.1.1
        fcb   0,0,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,0,0,0,0,0
pscroll.col.61.0.0
        fcb   24,24,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,1,1,1,1,24
pscroll.col.61.0.1
        fcb   26,26,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,2,2,2,2,26
pscroll.col.61.1.0
        fcb   28,28,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,3,3,3,3,28
pscroll.col.61.1.1
        fcb   30,30,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,4,4,4,4,30
pscroll.col.62.0.0
        fcb   19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,26,26,26,26,19
pscroll.col.62.0.1
        fcb   17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,28,28,28,28,17
pscroll.col.62.1.0
        fcb   18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,30,30,30,30,18
pscroll.col.62.1.1
        fcb   31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,32,32,32,32,31

; --- l'index : ((bande * 2 + plan) * 2 + phase) -> sequence, 0 si vide -
pscroll.col.tbl
        fdb   0                    ; bande 00 plan 0 phase 0
        fdb   0                    ; bande 00 plan 0 phase 1
        fdb   0                    ; bande 00 plan 1 phase 0
        fdb   0                    ; bande 00 plan 1 phase 1
        fdb   0                    ; bande 01 plan 0 phase 0
        fdb   0                    ; bande 01 plan 0 phase 1
        fdb   0                    ; bande 01 plan 1 phase 0
        fdb   0                    ; bande 01 plan 1 phase 1
        fdb   0                    ; bande 02 plan 0 phase 0
        fdb   0                    ; bande 02 plan 0 phase 1
        fdb   0                    ; bande 02 plan 1 phase 0
        fdb   0                    ; bande 02 plan 1 phase 1
        fdb   0                    ; bande 03 plan 0 phase 0
        fdb   0                    ; bande 03 plan 0 phase 1
        fdb   0                    ; bande 03 plan 1 phase 0
        fdb   0                    ; bande 03 plan 1 phase 1
        fdb   0                    ; bande 04 plan 0 phase 0
        fdb   0                    ; bande 04 plan 0 phase 1
        fdb   0                    ; bande 04 plan 1 phase 0
        fdb   0                    ; bande 04 plan 1 phase 1
        fdb   0                    ; bande 05 plan 0 phase 0
        fdb   0                    ; bande 05 plan 0 phase 1
        fdb   0                    ; bande 05 plan 1 phase 0
        fdb   0                    ; bande 05 plan 1 phase 1
        fdb   0                    ; bande 06 plan 0 phase 0
        fdb   0                    ; bande 06 plan 0 phase 1
        fdb   0                    ; bande 06 plan 1 phase 0
        fdb   0                    ; bande 06 plan 1 phase 1
        fdb   0                    ; bande 07 plan 0 phase 0
        fdb   0                    ; bande 07 plan 0 phase 1
        fdb   0                    ; bande 07 plan 1 phase 0
        fdb   0                    ; bande 07 plan 1 phase 1
        fdb   0                    ; bande 08 plan 0 phase 0
        fdb   0                    ; bande 08 plan 0 phase 1
        fdb   0                    ; bande 08 plan 1 phase 0
        fdb   0                    ; bande 08 plan 1 phase 1
        fdb   0                    ; bande 09 plan 0 phase 0
        fdb   0                    ; bande 09 plan 0 phase 1
        fdb   0                    ; bande 09 plan 1 phase 0
        fdb   0                    ; bande 09 plan 1 phase 1
        fdb   pscroll.col.10.0.0
        fdb   pscroll.col.10.0.1
        fdb   pscroll.col.10.1.0
        fdb   pscroll.col.10.1.1
        fdb   pscroll.col.11.0.0
        fdb   pscroll.col.11.0.1
        fdb   pscroll.col.11.1.0
        fdb   pscroll.col.11.1.1
        fdb   0                    ; bande 12 plan 0 phase 0
        fdb   0                    ; bande 12 plan 0 phase 1
        fdb   0                    ; bande 12 plan 1 phase 0
        fdb   0                    ; bande 12 plan 1 phase 1
        fdb   0                    ; bande 13 plan 0 phase 0
        fdb   0                    ; bande 13 plan 0 phase 1
        fdb   0                    ; bande 13 plan 1 phase 0
        fdb   0                    ; bande 13 plan 1 phase 1
        fdb   0                    ; bande 14 plan 0 phase 0
        fdb   0                    ; bande 14 plan 0 phase 1
        fdb   0                    ; bande 14 plan 1 phase 0
        fdb   0                    ; bande 14 plan 1 phase 1
        fdb   0                    ; bande 15 plan 0 phase 0
        fdb   0                    ; bande 15 plan 0 phase 1
        fdb   0                    ; bande 15 plan 1 phase 0
        fdb   0                    ; bande 15 plan 1 phase 1
        fdb   0                    ; bande 16 plan 0 phase 0
        fdb   0                    ; bande 16 plan 0 phase 1
        fdb   0                    ; bande 16 plan 1 phase 0
        fdb   0                    ; bande 16 plan 1 phase 1
        fdb   0                    ; bande 17 plan 0 phase 0
        fdb   0                    ; bande 17 plan 0 phase 1
        fdb   0                    ; bande 17 plan 1 phase 0
        fdb   0                    ; bande 17 plan 1 phase 1
        fdb   0                    ; bande 18 plan 0 phase 0
        fdb   0                    ; bande 18 plan 0 phase 1
        fdb   0                    ; bande 18 plan 1 phase 0
        fdb   0                    ; bande 18 plan 1 phase 1
        fdb   0                    ; bande 19 plan 0 phase 0
        fdb   0                    ; bande 19 plan 0 phase 1
        fdb   0                    ; bande 19 plan 1 phase 0
        fdb   0                    ; bande 19 plan 1 phase 1
        fdb   0                    ; bande 20 plan 0 phase 0
        fdb   0                    ; bande 20 plan 0 phase 1
        fdb   0                    ; bande 20 plan 1 phase 0
        fdb   0                    ; bande 20 plan 1 phase 1
        fdb   0                    ; bande 21 plan 0 phase 0
        fdb   0                    ; bande 21 plan 0 phase 1
        fdb   0                    ; bande 21 plan 1 phase 0
        fdb   0                    ; bande 21 plan 1 phase 1
        fdb   0                    ; bande 22 plan 0 phase 0
        fdb   0                    ; bande 22 plan 0 phase 1
        fdb   0                    ; bande 22 plan 1 phase 0
        fdb   0                    ; bande 22 plan 1 phase 1
        fdb   0                    ; bande 23 plan 0 phase 0
        fdb   0                    ; bande 23 plan 0 phase 1
        fdb   0                    ; bande 23 plan 1 phase 0
        fdb   0                    ; bande 23 plan 1 phase 1
        fdb   0                    ; bande 24 plan 0 phase 0
        fdb   0                    ; bande 24 plan 0 phase 1
        fdb   0                    ; bande 24 plan 1 phase 0
        fdb   0                    ; bande 24 plan 1 phase 1
        fdb   0                    ; bande 25 plan 0 phase 0
        fdb   0                    ; bande 25 plan 0 phase 1
        fdb   0                    ; bande 25 plan 1 phase 0
        fdb   0                    ; bande 25 plan 1 phase 1
        fdb   0                    ; bande 26 plan 0 phase 0
        fdb   0                    ; bande 26 plan 0 phase 1
        fdb   0                    ; bande 26 plan 1 phase 0
        fdb   0                    ; bande 26 plan 1 phase 1
        fdb   0                    ; bande 27 plan 0 phase 0
        fdb   0                    ; bande 27 plan 0 phase 1
        fdb   0                    ; bande 27 plan 1 phase 0
        fdb   0                    ; bande 27 plan 1 phase 1
        fdb   0                    ; bande 28 plan 0 phase 0
        fdb   0                    ; bande 28 plan 0 phase 1
        fdb   0                    ; bande 28 plan 1 phase 0
        fdb   0                    ; bande 28 plan 1 phase 1
        fdb   0                    ; bande 29 plan 0 phase 0
        fdb   0                    ; bande 29 plan 0 phase 1
        fdb   0                    ; bande 29 plan 1 phase 0
        fdb   pscroll.col.29.1.1
        fdb   pscroll.col.30.0.0
        fdb   pscroll.col.30.0.1
        fdb   pscroll.col.30.1.0
        fdb   pscroll.col.30.1.1
        fdb   0                    ; bande 31 plan 0 phase 0
        fdb   0                    ; bande 31 plan 0 phase 1
        fdb   0                    ; bande 31 plan 1 phase 0
        fdb   0                    ; bande 31 plan 1 phase 1
        fdb   0                    ; bande 32 plan 0 phase 0
        fdb   0                    ; bande 32 plan 0 phase 1
        fdb   0                    ; bande 32 plan 1 phase 0
        fdb   0                    ; bande 32 plan 1 phase 1
        fdb   0                    ; bande 33 plan 0 phase 0
        fdb   0                    ; bande 33 plan 0 phase 1
        fdb   0                    ; bande 33 plan 1 phase 0
        fdb   0                    ; bande 33 plan 1 phase 1
        fdb   0                    ; bande 34 plan 0 phase 0
        fdb   0                    ; bande 34 plan 0 phase 1
        fdb   0                    ; bande 34 plan 1 phase 0
        fdb   0                    ; bande 34 plan 1 phase 1
        fdb   0                    ; bande 35 plan 0 phase 0
        fdb   0                    ; bande 35 plan 0 phase 1
        fdb   0                    ; bande 35 plan 1 phase 0
        fdb   0                    ; bande 35 plan 1 phase 1
        fdb   0                    ; bande 36 plan 0 phase 0
        fdb   0                    ; bande 36 plan 0 phase 1
        fdb   0                    ; bande 36 plan 1 phase 0
        fdb   0                    ; bande 36 plan 1 phase 1
        fdb   0                    ; bande 37 plan 0 phase 0
        fdb   0                    ; bande 37 plan 0 phase 1
        fdb   0                    ; bande 37 plan 1 phase 0
        fdb   0                    ; bande 37 plan 1 phase 1
        fdb   0                    ; bande 38 plan 0 phase 0
        fdb   0                    ; bande 38 plan 0 phase 1
        fdb   0                    ; bande 38 plan 1 phase 0
        fdb   0                    ; bande 38 plan 1 phase 1
        fdb   0                    ; bande 39 plan 0 phase 0
        fdb   0                    ; bande 39 plan 0 phase 1
        fdb   0                    ; bande 39 plan 1 phase 0
        fdb   0                    ; bande 39 plan 1 phase 1
        fdb   0                    ; bande 40 plan 0 phase 0
        fdb   0                    ; bande 40 plan 0 phase 1
        fdb   0                    ; bande 40 plan 1 phase 0
        fdb   0                    ; bande 40 plan 1 phase 1
        fdb   0                    ; bande 41 plan 0 phase 0
        fdb   0                    ; bande 41 plan 0 phase 1
        fdb   0                    ; bande 41 plan 1 phase 0
        fdb   0                    ; bande 41 plan 1 phase 1
        fdb   0                    ; bande 42 plan 0 phase 0
        fdb   0                    ; bande 42 plan 0 phase 1
        fdb   0                    ; bande 42 plan 1 phase 0
        fdb   0                    ; bande 42 plan 1 phase 1
        fdb   0                    ; bande 43 plan 0 phase 0
        fdb   0                    ; bande 43 plan 0 phase 1
        fdb   0                    ; bande 43 plan 1 phase 0
        fdb   0                    ; bande 43 plan 1 phase 1
        fdb   0                    ; bande 44 plan 0 phase 0
        fdb   0                    ; bande 44 plan 0 phase 1
        fdb   0                    ; bande 44 plan 1 phase 0
        fdb   0                    ; bande 44 plan 1 phase 1
        fdb   0                    ; bande 45 plan 0 phase 0
        fdb   0                    ; bande 45 plan 0 phase 1
        fdb   0                    ; bande 45 plan 1 phase 0
        fdb   0                    ; bande 45 plan 1 phase 1
        fdb   0                    ; bande 46 plan 0 phase 0
        fdb   0                    ; bande 46 plan 0 phase 1
        fdb   0                    ; bande 46 plan 1 phase 0
        fdb   0                    ; bande 46 plan 1 phase 1
        fdb   0                    ; bande 47 plan 0 phase 0
        fdb   0                    ; bande 47 plan 0 phase 1
        fdb   0                    ; bande 47 plan 1 phase 0
        fdb   0                    ; bande 47 plan 1 phase 1
        fdb   0                    ; bande 48 plan 0 phase 0
        fdb   0                    ; bande 48 plan 0 phase 1
        fdb   0                    ; bande 48 plan 1 phase 0
        fdb   0                    ; bande 48 plan 1 phase 1
        fdb   0                    ; bande 49 plan 0 phase 0
        fdb   0                    ; bande 49 plan 0 phase 1
        fdb   0                    ; bande 49 plan 1 phase 0
        fdb   0                    ; bande 49 plan 1 phase 1
        fdb   0                    ; bande 50 plan 0 phase 0
        fdb   0                    ; bande 50 plan 0 phase 1
        fdb   0                    ; bande 50 plan 1 phase 0
        fdb   pscroll.col.50.1.1
        fdb   pscroll.col.51.0.0
        fdb   pscroll.col.51.0.1
        fdb   pscroll.col.51.1.0
        fdb   pscroll.col.51.1.1
        fdb   pscroll.col.52.0.0
        fdb   pscroll.col.52.0.1
        fdb   pscroll.col.52.1.0
        fdb   pscroll.col.52.1.1
        fdb   pscroll.col.53.0.0
        fdb   pscroll.col.53.0.1
        fdb   pscroll.col.53.1.0
        fdb   pscroll.col.53.1.1
        fdb   pscroll.col.54.0.0
        fdb   pscroll.col.54.0.1
        fdb   pscroll.col.54.1.0
        fdb   pscroll.col.54.1.1
        fdb   pscroll.col.55.0.0
        fdb   pscroll.col.55.0.1
        fdb   pscroll.col.55.1.0
        fdb   pscroll.col.55.1.1
        fdb   pscroll.col.56.0.0
        fdb   pscroll.col.56.0.1
        fdb   pscroll.col.56.1.0
        fdb   pscroll.col.56.1.1
        fdb   pscroll.col.57.0.0
        fdb   pscroll.col.57.0.1
        fdb   pscroll.col.57.1.0
        fdb   pscroll.col.57.1.1
        fdb   pscroll.col.58.0.0
        fdb   pscroll.col.58.0.1
        fdb   pscroll.col.58.1.0
        fdb   pscroll.col.58.1.1
        fdb   pscroll.col.59.0.0
        fdb   pscroll.col.59.0.1
        fdb   pscroll.col.59.1.0
        fdb   pscroll.col.59.1.1
        fdb   pscroll.col.60.0.0
        fdb   pscroll.col.60.0.1
        fdb   pscroll.col.60.1.0
        fdb   pscroll.col.60.1.1
        fdb   pscroll.col.61.0.0
        fdb   pscroll.col.61.0.1
        fdb   pscroll.col.61.1.0
        fdb   pscroll.col.61.1.1
        fdb   pscroll.col.62.0.0
        fdb   pscroll.col.62.0.1
        fdb   pscroll.col.62.1.0
        fdb   pscroll.col.62.1.1
        fdb   0                    ; bande 63 plan 0 phase 0
        fdb   0                    ; bande 63 plan 0 phase 1
        fdb   0                    ; bande 63 plan 1 phase 0
        fdb   0                    ; bande 63 plan 1 phase 1
        fdb   0                    ; bande 64 plan 0 phase 0
        fdb   0                    ; bande 64 plan 0 phase 1
        fdb   0                    ; bande 64 plan 1 phase 0
        fdb   0                    ; bande 64 plan 1 phase 1
        fdb   0                    ; bande 65 plan 0 phase 0
        fdb   0                    ; bande 65 plan 0 phase 1
        fdb   0                    ; bande 65 plan 1 phase 0
        fdb   0                    ; bande 65 plan 1 phase 1
        fdb   0                    ; bande 66 plan 0 phase 0
        fdb   0                    ; bande 66 plan 0 phase 1
        fdb   0                    ; bande 66 plan 1 phase 0
        fdb   0                    ; bande 66 plan 1 phase 1
        fdb   0                    ; bande 67 plan 0 phase 0
        fdb   0                    ; bande 67 plan 0 phase 1
        fdb   0                    ; bande 67 plan 1 phase 0
        fdb   0                    ; bande 67 plan 1 phase 1
        fdb   0                    ; bande 68 plan 0 phase 0
        fdb   0                    ; bande 68 plan 0 phase 1
        fdb   0                    ; bande 68 plan 1 phase 0
        fdb   0                    ; bande 68 plan 1 phase 1
        fdb   0                    ; bande 69 plan 0 phase 0
        fdb   0                    ; bande 69 plan 0 phase 1
        fdb   0                    ; bande 69 plan 1 phase 0
        fdb   0                    ; bande 69 plan 1 phase 1
        fdb   0                    ; bande 70 plan 0 phase 0
        fdb   0                    ; bande 70 plan 0 phase 1
        fdb   0                    ; bande 70 plan 1 phase 0
        fdb   0                    ; bande 70 plan 1 phase 1
        fdb   0                    ; bande 71 plan 0 phase 0
        fdb   0                    ; bande 71 plan 0 phase 1
        fdb   0                    ; bande 71 plan 1 phase 0
        fdb   0                    ; bande 71 plan 1 phase 1

pscroll.CHUNKS    equ 72      ; bandes de 16 px dans le niveau
pscroll.ROWS      equ 30      ; rangees de cellules
pscroll.CELL_H    equ 6       ; lignes par rangee
pscroll.CELLS     equ 384     ; cellules dans la largeur de carte
pscroll.MAP_STRIDE equ 48     ; octets par rangee du bitfield
