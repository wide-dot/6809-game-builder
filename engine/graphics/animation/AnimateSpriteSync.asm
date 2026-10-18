* ---------------------------------------------------------------------------
* AnimateSpriteSync
* -----------------
* AnimateSprite once per elapsed frame (gfxlock.frameDrop.count) : the script
* and the commands are AnimateSprite's. A command that follows the image shown
* is run at once rather than one image late ($FF and $FE excepted).
*
* input REG : [u] the object
* trashes   : d, x, y
* V2-DEVIATION : a new animation's first image lasts D + 1 frames, this one
* counted ; past an image the overshoot c' is carried, D + 1 + c' clamped at
* 0 (v1 took the frame drop twice) ; casebook
* docs/lang/en/migration/frame-drop-timer-carry.md. The look-ahead reads the
* entry after the image shown (v1 read past a $FF or $FE).
* ---------------------------------------------------------------------------

        INCLUDE "./engine/graphics/animation/AnimateSprite.asm"

AnimateSpriteSync
        jsr   AnimateSprite.mount
        beq   @run
        lda   anim_flags,u
        anda  #anim_link_mask
        bne   @frame                   ; linked : on at its frame, its time left
        clr   anim_frame,u
        ldb   -1,x
        stb   anim_frame_duration,u    ; D + 1 frames, this one counted
        bra   @frame
@run    ldb   anim_frame_duration,u
        subb  gfxlock.frameDrop.count
        stb   anim_frame_duration,u
        bpl   @rts
        addb  -1,x                     ; the overshoot carried : D + 1 + c'
        incb
        bpl   >
        clrb                           ; one image per call at most
!       stb   anim_frame_duration,u
@frame  jsr   AnimateSprite.frame
        bcs   @rts                     ; a command, no image
        ldd   2,y                      ; the entry after the image
        cmpa  #$FA
        blo   @rts
        cmpa  #$FE
        bhs   @rts                     ; $FF, $FE : left to the next image
        leay  2,y
        jsr   AnimateSprite.command
@rts    jmp   AnimateSprite.rts
