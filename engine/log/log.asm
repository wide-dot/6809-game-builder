* ===========================================================================
* log - the probe routine (~55 bytes)
* ===========================================================================
* Included by every assembly that hosts probe sites: the resident engine and
* each machine loader. The copies are independent code but share the ONE
* block at log.BLOCK - the supervisor watches the block, not the routine.
*
* info  : publish and return with the caller intact (D,X,Y,U and CC).
* error : publish and freeze on log.halt, IRQs masked for good. The block
*         is frozen BY CONSTRUCTION - error never returns, so no guard is
*         needed to preserve the first event.
*
* Block accesses are forced extended (>) : the block sits at $9EF0-$9EFF,
* never inside any host's direct page, whatever SETDP is in effect here.

log.write
        pshs  cc              ; the site's CC - info gives it back
        orcc  #$50            ; an IRQ probing while the block is half
                              ; written would mix two events
        std   >log.d          ; THE PHOTOGRAPH FIRST: four extended stores,
        stx   >log.x          ; no register modified
        sty   >log.y
        stu   >log.u
 IFDEF T2
        jsr   GetCartPageA    ; the T2 gate array does not read back
 ELSE
        lda   >map.CF74021.CART
 ENDC
        sta   >log.page
        ldx   1,s             ; return address = the site's fdb
        ldd   ,x++            ; D = code... and N = bit 15: the ldd IS the test
        bmi   log.write.error ; IMMEDIATELY - a stx would destroy N
        ; ----- info: publish, give everything back -----
        stx   1,s             ; return address moved past the fdb
        stx   >log.pc
        std   >log.code       ; <-- THE SIGNAL (watchpoint target)
        ldd   >log.d          ; D and X restored (Y,U never touched)
        ldx   >log.x
        puls  cc,pc           ; CC restored - the site's IRQ state included

log.write.error
        stx   >log.pc         ; same meaning: site+5
        std   >log.code       ; <-- THE SIGNAL
log.halt
        bra   log.halt        ; never returns - the emulator's anchor
