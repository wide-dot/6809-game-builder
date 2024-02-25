 SECTION code

joypad.md6.init

        ; configure MC6821 to be able to read joypads (0&1) direction
        lda   map.MC6821.CRA1      ; read Control Register A (CRA)
        anda  #$FB                 ; unset bit 2 
        sta   map.MC6821.CRA1      ; select Data Direction Register A (DDRA)
        clrb                       ; unset all bits
        stb   map.MC6821.PRA1      ; Peripherial Interface A (PIA) lines set as input
        ora   #$04                 ; set b2
        sta   map.MC6821.CRA1      ; select Peripherial Interface A (PIA) Register

        ; configure MC6821 to be able to read joypads (0&1) buttons
        lda   map.MC6821.CRA2      ; read Control Register B (CRB)
        anda  #$FB                 ; unset bit 2 
        sta   map.MC6821.CRA2      ; select Data Direction Register B (DDRB)
        ldb   #$0C                 ; set bit 2 (pin7 ctrl 0) and 3 (pin7 ctrl 1), warning : DAC bits set as output
        stb   map.MC6821.PRA2      ; Peripherial Interface B (PIB) lines set as input
        ora   #$04                 ; set b2
        sta   map.MC6821.CRA2      ; select Peripherial Interface B (PIB) Register
        rts

 ENDSECTION