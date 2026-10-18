* ---------------------------------------------------------------------------
* palette.fade.to - fades a working palette into a target palette, a step a
*                   frame, the VBL polled : no IRQ needed
* palette.fade    - the same into a single colour
* ---------------------------------------------------------------------------
*
* palette.fade.to
*   In  : U the working palette, 16 entries of 2 bytes (GGGGRRRR, 0000BBBB :
*         the EF9369's format, Pal_buffer's), in RAM : changed in place
*         X the target, the same format, read only
*   Out : the working palette is the target, and so is the chip.
*         A, B, X, Y, U trashed ; DP untouched (extended addressing only) ;
*         no global variable.
*   Time: a frame a step, as many steps as the largest component distance :
*         15 at most, 300 ms at 50 Hz. A palette already at its target costs
*         a frame (written once).
*
* palette.fade
*   In  : U the working palette ; A the target's green|red, B its blue. The
*         colour is unfolded into 16 entries on the stack (32 bytes), then
*         palette.fade.to.
*
* Each frame : the beam out of the screen, 40 lines more to be in the
* border (the EF9369 written over the picture snows), every component one
* step towards its target, then the 16 entries written. Done when nothing
* moved. A step is 1/15 of a component : a plain fade, no table.
*
* The registers are the machine's map.const.asm (map.EF9369.A/.D,
* map.CF74021.SYS1) : include it before this file. Checked on TO8.
* V2-DEVIATION : v1's boot sector fade (engine/boot/boot-fd.asm, PalFade,
* PalRun) made a routine : 16 full entries, each to its own target ;
* migration/boot-palette-fade.md.
* ---------------------------------------------------------------------------
palette.fade
        ldx   #16
@fill   pshs  a,b                      ; an entry : A (green|red), B (blue)
        leax  -1,x
        bne   @fill
        tfr   s,x                      ; X : the target, 16 times the colour
        bsr   palette.fade.to
        leas  32,s
        rts

palette.fade.to
        pshs  u,x
        ldb   #$0F
        pshs  b                        ; the component's mask : red first
        clr   ,-s                      ; something moved
* the stack : 0,s moved / 1,s mask / 2,s X target / 4,s U working
@frame
        clr   ,s
@vbl1   tst   map.CF74021.SYS1
        bpl   @vbl1                    ; while the beam is out of the screen
@vbl2   tst   map.CF74021.SYS1
        bmi   @vbl2                    ; while it is in
        ldx   #320                     ; 40 lines of 8 loops : the border
@border leax  -1,x
        bne   @border
* --- the 16 entries a step towards their target ---------------------------
        ldu   4,s
        ldx   2,s
        ldy   #16
@entry
@gr     lda   ,u                       ; green|red
        anda  1,s                      ; the masked component
        ldb   ,x                       ; its target
        andb  1,s
        pshs  b
        cmpa  ,s+
        beq   @grNext                  ; at its target
        bhi   @grDec
        lda   #$11                     ; the step : $01 (red) or $10 (green)
        anda  1,s
        adda  ,u
        bra   @grSave
@grDec  lda   #$11
        anda  1,s
        nega
        adda  ,u                       ; no borrow into the other nibble : only
@grSave sta   ,u                       ; a component above 0 goes down
        inc   ,s
@grNext com   1,s                      ; the other component
        bmi   @gr                      ; $F0 : the second pass, green
* blue
        ldb   1,u
        cmpb  1,x
        beq   @bNext
        bhi   @bDec
        incb
        bra   @bSave
@bDec   decb
@bSave  stb   1,u
        inc   ,s
@bNext  leau  2,u
        leax  2,x
        leay  -1,y
        bne   @entry
* --- the 16 entries written, still in the border ---------------------------
        ldu   4,s
        clra
        sta   map.EF9369.A             ; colour 0, the index auto-incremented
        ldy   #16
@write  ldd   ,u++
        sta   map.EF9369.D             ; green and red
        stb   map.EF9369.D             ; blue
        leay  -1,y
        bne   @write
        tst   ,s
        bne   @frame                   ; something moved : the next frame
        leas  6,s
        rts

* ---------------------------------------------------------------------------
* palette.to8.monitor - the TO8 monitor menu's palette as the machine shows
* it at boot (v1's boot-fd.asm, pal_from and pal_len), unfolded into 16
* entries for palette.fade. In RAM : a fade changes it in place, copy it to
* keep it.
* ---------------------------------------------------------------------------
palette.to8.monitor
        fdb   $0000,$0000,$0000,$0000,$0000,$0000  ; 0-5   black
        fdb   $F00F                                ; 6     turquoise (border)
        fdb   $FF0F                                ; 7     white
        fdb   $7707,$7707,$7707                    ; 8-10  grey (lower background)
        fdb   $AA03                                ; 11    yellow (box inside)
        fdb   $330A,$330A,$330A,$330A              ; 12-15 mauve (TO8 background)
