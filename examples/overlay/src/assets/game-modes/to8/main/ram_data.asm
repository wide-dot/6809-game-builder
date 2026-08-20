* ===========================================================================
* Object sizing and RAM placement — the game's side of the contract
* ===========================================================================
* Under OverlayMode the OST keeps only the priority linkage as reserved
* space (object_rsvd_size 5 instead of 59) : object_size is 63 bytes here.
*
* The bench never calls LoadObject — its two objects are fixed blocks in the
* bench RAM, reset between tests. The dynamic pool equates still have to
* exist for RunObjects.asm (included for UnloadObject, the overlay pack's
* DeleteObject depends on it), so a token pool is declared after them.

nb_dynamic_objects           equ 4
ext_variables_size           equ 20  ; per dynamic object

* the two bench objects, adjacent : the reset clears them as one block
obj1                         equ $9000
obj2                         equ obj1+object_size

* the token dynamic pool, above the bench objects, below the results
Dynamic_Object_RAM           equ $9400
Dynamic_Object_RAM_End       equ Dynamic_Object_RAM+nb_dynamic_objects*object_size

* bench work variables
bench.gly_y1off              equ $9B00 ; word - glyph subset y1 offset, sign extended
bench.mrk_y1off              equ $9B02 ; word - marker subset y1 offset, sign extended
bench.tmp                    equ $9B04 ; word
bench.fail                   equ $9B06 ; byte - sticky failure flag of the running test
bench.bb                     equ $9B08 ; 4 bytes - VRAM bbox : first px, last px, first row, last row
bench.hit                    equ $9B0C ; byte - the scanned line held a pixel
bench.outp                   equ $9B0D ; word - anchor sweep result write pointer
bench.hdrp                   equ $9B0F ; word - anchor sweep header write pointer
bench.count                  equ $9B11 ; byte - probes left

* the background cell the bdraw probes save into (grows DOWN from the top)
bench.bgcell.top             equ $9A00

* results, loader-ut convention : magic, then one byte per test
res.magic                    equ $9C00 ; $CA once the game mode runs
res.base                     equ $9C01 ; tests write $01 at res.base+n-1
res.done                     equ $9C1F ; $0D once the sequence completed
res.sums                     equ $9C20 ; one word per test : VRAM checksum

* the anchor sweep : per probe (12x12..15x15, w-major) and per variant
* (bdraw first, draw second), the measured VRAM bounding box — 4 bytes
* [first px, last px, first row, last row], both routines called at the
* SAME fixed screen location. Headers : per probe [center_offset, x1_off,
* y1_off] read from the imageset. $CB at res.sweep.done when finished.
res.sweep                    equ $9D00 ; 16 probes x 2 variants x 4 bytes
res.sweep.hdr                equ $9D80 ; 16 probes x 3 bytes
res.sweep.done               equ $9DFE
