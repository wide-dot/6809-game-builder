* ---------------------------------------------------------------------------
* PalCycling
* ----------
* An IRQ user routine : every PalCyc_frames_init calls, the first 3 colours
* of Pal_current turn (0 <- 2, 1 <- 0, 2 <- 1) and a refresh is asked for ;
* then PalUpdateNow.
*
* trashes : d, x, u
* feature request : the first colour and the count as parameters
* ---------------------------------------------------------------------------

PalCyc_frames      fcb 0               ; the countdown
PalCyc_frames_init fcb 0               ; the calls between two turns

PalCycling
        dec   PalCyc_frames
        bne   >
        lda   PalCyc_frames_init
        sta   PalCyc_frames
        clr   PalRefresh
        ldx   Pal_current
        ldu   4,x
        ldd   2,x
        std   4,x
        ldd   ,x
        std   2,x
        stu   ,x
!       jmp   PalUpdateNow
