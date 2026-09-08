* ---------------------------------------------------------------------------
* loadbar — a loading bar in a BM16 video page, fed by the loader's progress
*           hook (loader.progress.hook.set, contract in loader.const.asm)
* ---------------------------------------------------------------------------
*
* The loader counts units (sectors read, 512-byte slices expanded) against a
* total it measures from the directory ; this hook turns them into columns.
* No division : an accumulator gains units x width at each call, and every
* time it exceeds the total one column is drawn — additions and one 8x8
* multiply, so the bar costs a few dozen cycles between two sectors, plus a
* column when one is due. It never draws past its width and never moves
* back : a total that grows (a scene measured after another started) only
* slows it down.
*
* A column is one byte of each bank, four pixels of one colour, over
* `height` lines. BM16 : 40 bytes per line per bank, the form bank at
* position 0 of the page, the colour bank at position $2000 ; the page is
* reached through the cartridge window, mounted for the time of the column
* and put back as it was — the loader's own destination lives there.
*
* THE HOOK RUNS WHILE THE LOAD OVERWRITES THE UNIT THAT BROUGHT IT : the
* splash lives in the engine's region, and the engine is the first file of
* the boot scene (measured : the bar froze at 40 %, the rest of the load
* executing the engine's bytes as a hook). So the block is written to be
* COPIED somewhere no scene ever loads — a <reserved> block of the layout —
* and runs there : parameters, state and code together, every reference
* relative to the PC, `loadbar.SIZE` bytes from `loadbar`, the entry point
* at `loadbar.hook.OFFSET` from the copy. Set the parameters in the unit's
* copy, copy the block, install copy + offset. A fresh copy is a reset.
*
*   loadbar.page     the video page shown while loading (2 or 3)
*   loadbar.address  x + 40*y : first byte column, top line
*   loadbar.width    columns, 1 to 40 (four pixels each)
*   loadbar.height   lines
*   loadbar.pixels   the byte written : colour c gives c*$11
* map.CF74021.CART comes from the machine's map.const.asm, included first.
* ---------------------------------------------------------------------------
loadbar
loadbar.page    fcb   3
loadbar.address fdb   0
loadbar.width   fcb   40
loadbar.height  fcb   4
loadbar.pixels  fcb   $11
loadbar.acc     fdb   0
loadbar.next    fcb   0
loadbar.total   fdb   0

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
        decb
        lda   map.CF74021.CART         ; the loader's own mapping, kept
        pshs  a
        lda   #$60                     ; RAM over the cartridge, writable
        ora   loadbar.page,pcr
        sta   map.CF74021.CART
        ldx   loadbar.address,pcr
        abx                            ; the column
        lda   loadbar.pixels,pcr
        ldb   loadbar.height,pcr
@col    sta   ,x                       ; form bank
        sta   $2000,x                  ; colour bank
        leax  40,x
        decb
        bne   @col
        puls  a
        sta   map.CF74021.CART
        bra   @loop
@done   puls  b,pc
loadbar.SIZE        equ   *-loadbar
loadbar.hook.OFFSET equ   loadbar.hook-loadbar
