* ---------------------------------------------------------------------------
* loadbar — a loading bar in a BM16 video page, fed by the loader's progress
*           hook (loader.progress.hook.set, contract in loader.const.asm)
* ---------------------------------------------------------------------------
*
* The loader counts units (sectors read, 512-byte slices expanded) against
* the total the directory announces ; this hook turns them into PIXELS.
* No division : an accumulator gains units x width at each call, and every
* time it exceeds the total one more pixel is drawn — additions and one 8x8
* multiply, so the bar costs a few dozen cycles between two sectors, plus a
* pixel when one is due. It never draws past its width and never moves
* back.
*
* A pixel is a nibble of one byte, over `height` lines. BM16 : 40 bytes per
* line per bank, four pixels per byte position — pixels 0 and 1 in the form
* bank byte (high nibble first), pixels 2 and 3 in the colour bank byte at
* +$2000 (the png2bin t3 layout : linear 4, planar 8) ; the page is reached
* through the cartridge window, mounted for the time of the pixel and put
* back as it was — the loader's own destination lives there. Pixel by pixel
* since 08/09/2026 : it advanced by four (a byte of each bank) before.
*
* THE HOOK RUNS WHILE THE LOAD OVERWRITES THE UNIT THAT BROUGHT IT : the
* splash lives in the engine's region, and the engine is the first file of
* the boot scene (measured : the bar froze at 40 %, the rest of the load
* executing the engine's bytes as a hook). So the block lives where no
* scene ever loads : since 08/09/2026 it is assembled INSIDE THE LOADER,
* after its code, and a game installs it with loader.loadbar.set (jump
* table, X = the seven parameters below). It is still written to be
* copied anywhere — parameters, state and code together, every reference
* relative to the PC, `loadbar.SIZE` bytes from `loadbar`, the entry point
* at `loadbar.hook.OFFSET` from the copy — for a build that wants it
* elsewhere. A fresh copy, or loader.loadbar.set, is a reset.
*
*   loadbar.page     the video page shown while loading (2 or 3)
*   loadbar.address  x + 40*y : first byte column, top line
*   loadbar.width    pixels, 1 to 160
*   loadbar.height   lines
*   loadbar.pixels   the byte written : colour c gives c*$11
*   loadbar.pulse.*  the PULSE (08/09/2026) : every `period` units the palette
*                    entry `index` takes the next colour of the table, `count`
*                    words (at most loadbar.PULSE_MAX) in the GR0B form of a
*                    Pal_ table, cyclic — a ramp there and back is a breathing
*                    bar. Period 0 : no pulse. One palette write per step, not
*                    per unit. Pick an entry the picture on screen does not
*                    use, or it breathes too.
*   width 0, period 0 : a HIDDEN bar — installed, nothing drawn, for a load
*   too short for a bar that may still need its text (below).
*
* THE TEXT (09/10/2026) : when a disk is missing, the loader's prompt
* writes "DISK n" in the bar's page — no mode, page or palette to change and
* take back, nothing erased after : the game redraws its screen.
* loader.loadbar.text.set (jump table) gives its place, the address x + 40*y
* of its top left byte (6 bytes wide, 5 lines ; 0 : no text, the loader's
* monitor prompt instead). Letters in the bar's colour on colour 0, the
* space between the word and the digit left as it is (the screen under the
* text is the game's : colour 0, cleared). The palette is the game's : a
* hidden bar over a screen faded to black lights the bar's entry itself.
* Written for SIZE, not speed (the author's rule : a prompt waits for the
* player) : a 3x5 font, a glyph a word (row 0 in bits 15-13), a letter in
* one byte position (two pixels in the form bank, the third and the gap in
* the colour bank), and only the digits of the target's disks
* (loader.dir.physicalDisks, from the builder).
* loadbar.PARAMS bytes from `loadbar` are the parameters a caller sets, the
* colour table follows them IN THE CALLER'S RECORD (`count` words) and is
* copied here too : the splash's own bytes are overwritten by the load its
* bar shows (seen 08/09/2026 : a pointer to the table gave the bar the colour
* of whatever the engine's code left there). The state comes last, cleared
* by loader.loadbar.set.
* map.CF74021.CART and map.EF9369.* come from the machine's map.const.asm,
* included first.
* ---------------------------------------------------------------------------
loadbar
loadbar.page         fcb   3
loadbar.address      fdb   0
loadbar.width        fcb   40
loadbar.height       fcb   4
loadbar.pixels       fcb   $11
loadbar.pulse.index  fcb   0
loadbar.pulse.period fcb   0
loadbar.pulse.count  fcb   0
loadbar.PARAMS       equ   *-loadbar
loadbar.PULSE_MAX    equ   8
loadbar.pulse.table  fill  0,loadbar.PULSE_MAX*2
loadbar.text         fdb   0   ; the text's place, 0 : none
loadbar.text.pairs   fill  0,4 ; two pixels as a byte, by their two bits (%00 : 0, never written)
loadbar.text.bits    fdb   0   ; the glyph being drawn (pairs+4)
loadbar.acc          fdb   0
loadbar.next         fcb   0
loadbar.total        fdb   0
loadbar.pulse.tick   fcb   0
loadbar.pulse.step   fcb   0
loadbar.keep         fcb   0 ; the mask of the neighbour pixel in the byte
loadbar.ours         fcb   0 ; our pixel's nibble
loadbar.STATE        equ   *-loadbar.acc

* entry : B = units just added, X = the loader's counters (done, total)
loadbar.hook
        pshs  b                        ; the units
        ldd   2,x
        beq   @done                    ; nothing measured yet : nothing to show
        std   loadbar.total,pcr
        lda   loadbar.width,pcr
        ldb   ,s
        mul                            ; units x width
        addd  loadbar.acc,pcr
        std   loadbar.acc,pcr
@loop   ldd   loadbar.acc,pcr
        subd  loadbar.total,pcr
        blo   @done                    ; not a column's worth yet
        std   loadbar.acc,pcr
        ldb   loadbar.next,pcr
        cmpb  loadbar.width,pcr
        bhs   @done                    ; the bar is full
        incb
        stb   loadbar.next,pcr
        decb                           ; B = the pixel, 0 to width-1
        ldx   loadbar.address,pcr
        pshs  b
        lsrb
        lsrb
        abx                            ; the byte position of that pixel
        puls  b
        andb  #%11                     ; its rank in the four
        cmpb  #2
        blo   >
        leax  $2000,x                  ; 2 and 3 : the colour bank
        subb  #2
!       lda   #$0F                     ; even : the high nibble, keep the low
        tstb
        beq   >
        lda   #$F0                     ; odd : the low nibble, keep the high
!       sta   loadbar.keep,pcr
        coma
        anda  loadbar.pixels,pcr       ; c*$11 masked : our nibble
        sta   loadbar.ours,pcr
        lda   map.CF74021.CART         ; the loader's own mapping, kept
        pshs  a
        lda   #$60                     ; RAM over the cartridge, writable
        ora   loadbar.page,pcr
        sta   map.CF74021.CART
        ldb   loadbar.height,pcr
@col    lda   ,x
        anda  loadbar.keep,pcr
        ora   loadbar.ours,pcr
        sta   ,x
        leax  40,x
        decb
        bne   @col
        puls  a
        sta   map.CF74021.CART
        bra   @loop
@done
        ; the pulse : `period` units per step, one palette write per step
        lda   loadbar.pulse.period,pcr
        beq   @rts
        ldb   ,s                       ; the units
        addb  loadbar.pulse.tick,pcr
        cmpb  loadbar.pulse.period,pcr
        blo   @tick
        subb  loadbar.pulse.period,pcr
        stb   loadbar.pulse.tick,pcr
        lda   loadbar.pulse.step,pcr
        inca
        cmpa  loadbar.pulse.count,pcr
        blo   >
        clra
!       sta   loadbar.pulse.step,pcr
        asla                           ; a word per colour
        leax  loadbar.pulse.table,pcr
        leax  a,x
        bsr   loadbar.colour
        bra   @rts
@tick   stb   loadbar.pulse.tick,pcr
@rts    puls  b,pc

* X = a colour, %GGGGRRRR %0000BBBB : into the bar's palette entry
loadbar.colour
        lda   loadbar.pulse.index,pcr
        asla                           ; the EF9369 address counts bytes
        sta   map.EF9369.A
        ldd   ,x
        sta   map.EF9369.D             ; green and red
        stb   map.EF9369.D             ; blue
        rts

* A = the disk number, 1 to 9 : "DISK n" at loadbar.text
loadbar.text.draw
        leau  loadbar.text.pairs,pcr   ; by two bits : %01 0 ink, %10 ink 0,
        ldb   loadbar.pixels-loadbar.text.pairs,u
        stb   3,u                      ; %11 ink ink
        andb  #$0F
        stb   1,u
        eorb  3,u
        stb   2,u
        ldb   map.CF74021.CART         ; the loader's own mapping, kept
        pshs  d                        ; with the digit
        ldb   loadbar.page-loadbar.text.pairs,u
        orb   #$60                     ; RAM over the cartridge, writable
        stb   map.CF74021.CART
        ldx   -2,u                     ; loadbar.text
        leay  loadbar.glyphs,pcr       ; D I S K
        ldb   #4
@word   pshs  b
        ldd   ,y++
        bsr   loadbar.glyph
        puls  b
        decb
        bne   @word
        leax  1,x                      ; the space, left as it is
        ldb   ,s                       ; the digit n : the n-th word from
        aslb                           ; here
        leay  b,y
        ldd   -2,y
        bsr   loadbar.glyph
        puls  d
        stb   map.CF74021.CART
        rts

* D = a glyph, X = its cell's top byte, U = loadbar.text.pairs : drawn,
* X on the next cell
loadbar.glyph
        std   4,u
        pshs  x
        lda   #5
@row    pshs  a
        clrb
        bsr   @bit
        bsr   @bit
        lda   b,u
        sta   ,x                       ; pixels 0-1 : the form bank
        clrb
        bsr   @bit
        aslb                           ; pixel 3 : the gap between letters
        lda   b,u
        sta   $2000,x                  ; pixels 2-3 : the colour bank
        leax  40,x
        puls  a
        deca
        bne   @row
        puls  x
        leax  1,x
        rts
@bit    lsl   5,u
        rol   4,u
        rolb
        rts

* 3x5, row 0 in bits 15-13 : D I S K, then the digits of the target's disks
 IFNDEF loader.dir.physicalDisks
loadbar.DIGITS equ 9
 ELSE
loadbar.DIGITS equ loader.dir.physicalDisks
 ENDC
loadbar.glyphs
        fdb   $D6DC,$E92E,$711C,$B75A
        fdb   $592E                    ; 1
 IFGE loadbar.DIGITS-2
        fdb   $E7CE                    ; 2
 ENDC
 IFGE loadbar.DIGITS-3
        fdb   $E59E                    ; 3
 ENDC
 IFGE loadbar.DIGITS-4
        fdb   $B792                    ; 4
 ENDC
 IFGE loadbar.DIGITS-5
        fdb   $F39E                    ; 5
 ENDC
 IFGE loadbar.DIGITS-6
        fdb   $F3DE                    ; 6
 ENDC
 IFGE loadbar.DIGITS-7
        fdb   $E492                    ; 7
 ENDC
 IFGE loadbar.DIGITS-8
        fdb   $F7DE                    ; 8
 ENDC
 IFGE loadbar.DIGITS-9
        fdb   $F79E                    ; 9
 ENDC
loadbar.SIZE        equ   *-loadbar
loadbar.hook.OFFSET equ   loadbar.hook-loadbar
