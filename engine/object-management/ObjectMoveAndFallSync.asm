* ---------------------------------------------------------------------------
* ObjectMoveAndFallSync
* ---------------------
* Moves an object under a constant acceleration, once per elapsed frame :
* each frame the position takes the velocity, then the velocity takes the
* acceleration (Sonic 2's ObjectMoveAndFall, its gravity a parameter here).
* Over k elapsed frames (gfxlock.frameDrop.count, 0 counting for one, as in
* ObjectMoveSync) that is, exactly :
*
*   x     += k * x_vel
*   y     += k * y_vel + g * k(k-1)/2
*   y_vel += k * g
*
* ObjectMoveSync followed by the acceleration added k times misses the
* g * k(k-1)/2 term : a jump peaks higher the longer the loop. No v1
* equivalent (v1 objects looped over the frames) ; casebook
* docs/lang/en/migration/frame-drop-loops-are-multiplies.md.
*
* input REG : [u] pointer to Object Status Table (OST)
*             [d] acceleration g, s8.8 per frame (signed)
* trashes   : d
* ---------------------------------------------------------------------------
ObjectMoveAndFallSync
        sta   @sign                    ; bit 7 : the sign of g
        bpl   >
        _negd
!       std   @ag                      ; |g|
        jsr   ObjectMoveSync           ; k frames at the velocity of the first
        ldb   gfxlock.frameDrop.count
        bne   >
        ldb   #1
!       stb   @k
        ; --- y_vel += k*g, 16 bits as the k additions would leave it ---
        lda   @k
        ldb   @ag+1
        mul                            ; k * |g| low byte
        std   @p
        lda   @k
        ldb   @ag
        mul                            ; k * |g| high byte : its low byte counts
        tfr   b,a
        clrb
        addd  @p                       ; k * |g|, modulo $10000
        tst   @sign
        bpl   >
        _negd
!       addd  y_vel,u
        std   y_vel,u
        ; --- t = k(k-1)/2, 0 to 32385 ---
        lda   @k
        tfr   a,b
        decb
        mul                            ; k(k-1), even
        lsra
        rorb
        std   @t
        ; --- r = |g| * t, its low 24 bits (r2 r1 r0) ---
        lda   @ag+1
        ldb   @t+1
        mul                            ; gl * tl
        std   @r+1
        clr   @r
        lda   @ag
        ldb   @t+1
        mul                            ; gh * tl, << 8
        addd  @r
        std   @r
        lda   @ag+1
        ldb   @t
        mul                            ; gl * th, << 8
        addd  @r
        std   @r
        lda   @ag
        ldb   @t
        mul                            ; gh * th, << 16 : its low byte counts
        addb  @r
        stb   @r
        tst   @sign
        bpl   >
        com   @r                       ; a negative g falls upwards : -r
        com   @r+1
        com   @r+2
        inc   @r+2
        bne   >
        inc   @r+1
        bne   >
        inc   @r
        ; --- y (16.8) += r, two's complement on 24 bits ---
!       ldd   @r+1
        addd  y_pos+1,u                ; y_pos must be followed by y_sub in memory
        std   y_pos+1,u
        lda   @r
        adca  y_pos,u
        sta   y_pos,u
        rts
@ag     fdb   0
@sign   fcb   0
@k      fcb   0
@p      fdb   0
@t      fdb   0
@r      fcb   0,0,0
