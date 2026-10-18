* ---------------------------------------------------------------------------
* PalRaster_1c
* ------------
* Changes one palette colour at the end of each screen line, until the
* table is read : 3 bytes a line, the colour's index then its value
* ($0BGR). An IRQ user routine (DP $E7) ; the timing is cycle exact.
* ---------------------------------------------------------------------------

PalRas_page   fcb   $00                ; the table's page
PalRas_start  fdb   $0000              ; the table
PalRas_end    fdb   $0000              ; its end

PalRaster_1c
        lda   PalRas_page
        _SetCartPageA
        ldx   PalRas_start

        lda   #32
!       bita  <$E7
        beq   <                        ; while spot is not in a visible screen col
!       bita  <$E7
        bne   <                        ; while spot is in a visible screen col
        mul                            ; tempo
        mul                            ; tempo
        nop                            ; tempo
!       tfr   a,b                      ; tempo
        tfr   a,b                      ; tempo
        tfr   a,b                      ; tempo
        ldd   1,x
        std   >*+8                     ; into the ldd #0 below
        lda   ,x
        sta   <$DB                     ; the colour's index
        ldd   #0
        stb   <$DA
        sta   <$DA
        leax  3,x
        cmpx  PalRas_end
        bne   <
        rts
