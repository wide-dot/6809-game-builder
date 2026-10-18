* ---------------------------------------------------------------------------
* PalUpdateNow
* ------------
* Writes the 16 colours at Pal_current to the palette chip when PalRefresh
* is 0 (a refresh asked for), then sets it back to $FF. An IRQ user routine,
* or called directly : it sets DP $E7 itself.
*
* trashes : d, x
* ---------------------------------------------------------------------------

PalRefresh      fcb   $FF            ; 0 : a refresh asked for
Pal_current     fdb   Pal_buffer     ; the colours written
Pal_buffer      fill  0,$20          ; 16 entries : GGGGRRRR, 0000BBBB

PalUpdateNow
        tst   PalRefresh
        bne   @rts
        pshs  dp
        ldd   #$E7
        tfr   b,dp
        ldx   Pal_current
        sta   <$DB                     ; colour 0, the index auto-incremented
        ldd   ,x
        sta   <$DA                     ; green and red
        stb   <$DA                     ; blue
        ldd   2,x
        sta   <$DA
        stb   <$DA
        ldd   4,x
        sta   <$DA
        stb   <$DA
        ldd   6,x
        sta   <$DA
        stb   <$DA
        ldd   8,x
        sta   <$DA
        stb   <$DA
        ldd   10,x
        sta   <$DA
        stb   <$DA
        ldd   12,x
        sta   <$DA
        stb   <$DA
        ldd   14,x
        sta   <$DA
        stb   <$DA
        ldd   16,x
        sta   <$DA
        stb   <$DA
        ldd   18,x
        sta   <$DA
        stb   <$DA
        ldd   20,x
        sta   <$DA
        stb   <$DA
        ldd   22,x
        sta   <$DA
        stb   <$DA
        ldd   24,x
        sta   <$DA
        stb   <$DA
        ldd   26,x
        sta   <$DA
        stb   <$DA
        ldd   28,x
        sta   <$DA
        stb   <$DA
        ldd   30,x
        sta   <$DA
        stb   <$DA
        com   PalRefresh               ; done : $FF
        puls  dp,pc
@rts    rts
