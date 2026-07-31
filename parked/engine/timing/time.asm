; -----------------------------------------------------------------------------
; time.ms.wait - Wait for a number of milliseconds
; -----------------------------------------------------------------------------
; Input: X (16 bits) = number of milliseconds to wait
; Modifies: D, X
; -----------------------------------------------------------------------------

time.ms.wait EXPORT

 SECTION code

time.ms.wait
@outerLoop
        ldd     #99        ; nb of inner loop for 1ms, taking into account the outer loop
                           ; (-1 inner loop, as duration is the same for both loops)
                           ; call cost and return cost are not included in the timing
@innerLoop
        andcc   #$ff       ; (3 cycles) - used for timing only
        subd    #1         ; (4 cycles)
        bne     @innerLoop ; (3 cycles)
        nop                ; (2 cycles) - used for timing only
        leax    -1,x       ; (5 cycles) Decrement millisecond counter
        bne     @outerLoop ; (3 cycles) Continue if not finished
        rts
 ENDSECTION