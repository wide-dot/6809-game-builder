* ---------------------------------------------------------------------------
* ObjectMoveSync
* --------------
* ObjectMove once per elapsed frame : k = gfxlock.frameDrop.count (0 counts
* for one), the position takes k times the velocity, exact to the subpixel.
*
* input REG : [u] the object
* trashes   : d
* V2-DEVIATION : two mul per axis where v1 looped over the frames, the same
* positions ; casebook docs/lang/en/migration/frame-drop-loops-are-multiplies.md
* ---------------------------------------------------------------------------

ObjectMoveSync
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       stb   ObjectMoveSync.k
        lda   x_vel+1,u
        mul                            ; the low byte x k, in full
        std   @tx
        lda   x_vel,u
        ldb   #0
ObjectMoveSync.k equ *-1               ; (dynamic) k
        mul                            ; the high byte x k : its low byte counts
        tfr   b,a
        clrb
        addd  #0
@tx     equ   *-2                      ; the velocity x k, exact in two's complement
        bpl   >
        dec   x_pos,u                  ; negative : its high byte is $FF
!       addd  x_pos+1,u                ; x_pos must be followed by x_sub in memory
        std   x_pos+1,u
        bcc   >
        inc   x_pos,u
!       lda   y_vel+1,u
        ldb   ObjectMoveSync.k
        mul
        std   @ty
        lda   y_vel,u
        ldb   ObjectMoveSync.k
        mul
        tfr   b,a
        clrb
        addd  #0
@ty     equ   *-2
        bpl   >
        dec   y_pos,u
!       addd  y_pos+1,u                ; y_pos must be followed by y_sub in memory
        std   y_pos+1,u
        bcc   >
        inc   y_pos,u
!       rts
