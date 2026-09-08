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
*                    entry `index` takes the next colour of `table`, `count`
*                    words in the GR0B form of a Pal_ table, cyclic — a ramp
*                    there and back is a breathing bar. Period 0 : no pulse.
*                    One palette write per step, not per unit. Pick an entry
*                    the picture on screen does not use, or it breathes too.
* loadbar.PARAMS bytes from `loadbar` are the parameters a caller sets, the
* state follows and is cleared by loader.loadbar.set.
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
loadbar.pulse.table  fdb   0
loadbar.PARAMS       equ   *-loadbar
loadbar.acc          fdb   0
loadbar.next         fcb   0
loadbar.total        fdb   0
loadbar.pulse.tick   fcb   0
loadbar.pulse.step   fcb   0
loadbar.keep         fcb   0 ; the mask of the neighbour pixel in the byte
loadbar.ours         fcb   0 ; our pixel's nibble
loadbar.STATE        equ   *-loadbar-loadbar.PARAMS

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
        ldx   loadbar.pulse.table,pcr
        ldd   a,x                      ; %GGGGRRRR %0000BBBB
        pshs  d
        lda   loadbar.pulse.index,pcr
        asla                           ; the EF9369 address counts bytes
        sta   map.EF9369.A
        puls  a
        sta   map.EF9369.D             ; green and red
        puls  a
        sta   map.EF9369.D             ; blue
        bra   @rts
@tick   stb   loadbar.pulse.tick,pcr
@rts    puls  b,pc
loadbar.SIZE        equ   *-loadbar
loadbar.hook.OFFSET equ   loadbar.hook-loadbar
