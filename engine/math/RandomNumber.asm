; ---------------------------------------------------------------------------
; RandomNumber - the next pseudo-random number in D (a 16 bit xorshift, by
; Samuel Devulder) ; InitRNG seeds it from the timer
; ---------------------------------------------------------------------------

InitRNG
        ldd   $E7C6
        std   RNG_seed
        rts

RandomNumber
        ldd   #0
RNG_seed equ *-2
        lsra              
        rorb              
        eorb  RNG_seed
        stb   @x
        rorb              
        eorb  RNG_seed+1
        tfr   b,a         
        eora  #0          
@x      equ   *-1                ; (dynamic)
        std   RNG_seed
        rts
