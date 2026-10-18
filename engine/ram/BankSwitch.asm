; ---------------------------------------------------------------------------
; The cartridge window's page, RAM or a T.2 cartridge's ROM (bit 7 set),
; through glb_Page : the page macros call these under T2. Subroutines : no
; direct page operand, the caller's DP is anyone's. glb_Page at 0 : not in
; use (the tile loop's mode), GetCartPage reads the register.
; ---------------------------------------------------------------------------

SetCartPageA
        sta   >glb_Page
        bpl   @RAMPg
        lda   >$E7E6
        anda  #$DF                     ; bit 5 : 0 the cartridge, 1 RAM
        sta   >$E7E6
        lda   #$F0                     ; out of the T.2's command mode, should an
        sta   >$0555                   ; IRQ have come during a page change
        lda   #$AA                     ; the T.2's page switch sequence
        sta   >$0555
        lsra                           ; $55
        sta   >$02AA
        lda   #$C0
        sta   >$0555
        lda   >glb_Page
        anda  #$7F                     ; bit 7 clear
        sta   >$0555                   ; the T.2's page
        bra   @rts
@RAMPg  sta   >$E7E6                   ; a RAM page (bit 5 in its number)
@rts    rts

SetCartPageB
        stb   >glb_Page
        bpl   @RAMPg
        ldb   >$E7E6
        andb  #$DF
        stb   >$E7E6
        ldb   #$F0
        stb   >$0555
        ldb   #$AA
        stb   >$0555
        lsrb
        stb   >$02AA
        ldb   #$C0
        stb   >$0555
        ldb   >glb_Page
        andb  #$7F
        stb   >$0555
        bra   @rts
@RAMPg  stb   >$E7E6
@rts    rts

GetCartPageA
        lda   >glb_Page
        bne   @rts
        lda   >$E7E6
@rts    rts

GetCartPageB
        ldb   >glb_Page
        bne   @rts
        ldb   >$E7E6
@rts    rts

