* ---------------------------------------------------------------------------
* AnimateSprite
* -------------
* Plays an animation script on an object : image_set takes the script's
* images in turn, each for D + 1 frames, and the object's flips
* (status_flags) are copied to the sprite's (render_flags).
*
* A script is D, the byte before its label, then a word per image, ended by
* a command :
*   $FF       restart
*   $FE n     back n images
*   $FD aaaa  animation aaaa from the next call
*   $FC       routine,u + 1
*   $FB       restart, routine_secondary,u cleared
*   $FA       routine_secondary,u + 1
* anim,u is the script, or negative an offset in the object's Ani_Asd_Index
* table ; the script's page is the object's Ani_Page_Index entry.
*
* AnimateSprite       U the object : one frame per call
* AnimateSpriteSync   U the object : one frame per elapsed frame, its own
*                     file, sharing this one's body
* trashes   : d, x, y
* V2-DEVIATION : ObjID unsigned (abx, past 127 objects) ; the flips merged
* without self-modifying code ; the body shared with AnimateSpriteSync.
* ---------------------------------------------------------------------------

 IFNDEF ANIMATE_SPRITE
ANIMATE_SPRITE equ 1

AnimateSprite
        bsr   AnimateSprite.mount
        beq   @run
        lda   anim_flags,u
        anda  #anim_link_mask
        bne   @frame                   ; linked : on at its frame, its time left
        clr   anim_frame,u
        bra   @load
@run    dec   anim_frame_duration,u
        bpl   AnimateSprite.rts
@load   ldb   -1,x
        stb   anim_frame_duration,u    ; D + 1 frames
@frame  bsr   AnimateSprite.frame
AnimateSprite.rts
        lda   #0                       ; (dynamic) the caller's page
AnimateSprite.page equ *-1
        _SetCartPageA
        rts

* ---------------------------------------------------------------------------
* AnimateSprite.mount - the caller's page kept, the script's mounted ; X the
* script, Z set when it is the animation already playing
* ---------------------------------------------------------------------------
AnimateSprite.mount
        _GetCartPageA
        sta   AnimateSprite.page
        ldx   #Ani_Page_Index
        ldb   id,u
        abx
        lda   ,x
        _SetCartPageA
        ldx   anim,u
        bpl   >                        ; the script
        ldx   #Ani_Asd_Index           ; negative : an offset in the object's table
        abx
        abx                            ; ObjID * 2, unsigned
        ldx   [,x]
        ldb   anim+1,u
        abx
        ldx   ,x
!       cmpx  prev_anim,u
        beq   >
        stx   prev_anim,u              ; a new animation : Z clear
!       rts

* ---------------------------------------------------------------------------
* AnimateSprite.frame - the entry at anim_frame : an image is shown (C clear,
* Y its entry), a command is run (C set)
* AnimateSprite.command - A the command, Y its entry
* ---------------------------------------------------------------------------
AnimateSprite.frame
        ldb   anim_frame,u
        clra
        aslb
        rola
        leay  d,x
        ldd   ,y
        cmpa  #$FA
        bhs   AnimateSprite.command
AnimateSprite.image
        std   image_set,u
        lda   status_flags,u
        eora  render_flags,u
        anda  #render_xmirror_mask|render_ymirror_mask
        eora  render_flags,u
        sta   render_flags,u           ; the object's flips, the other flags kept
        inc   anim_frame,u
        andcc #%11111110               ; C clear : an image
        rts
AnimateSprite.command
        inca
        bne   @fe
        clr   anim_frame,u             ; $FF
        leay  ,x
        ldd   ,y
        bra   AnimateSprite.image
@fe     inca
        bne   @fd
        negb                           ; $FE n
        addb  anim_frame,u
        stb   anim_frame,u
        clra
        aslb
        rola
        leay  d,x
        ldd   ,y
        bra   AnimateSprite.image
@fd     inca
        bne   @fc
        ldd   1,y                      ; $FD aaaa
        std   anim,u
        bra   @done
@fc     inca
        bne   @fb
        inc   routine,u                ; $FC
        clr   anim_frame_duration,u
        inc   anim_frame,u
        bra   @done
@fb     inca
        bne   @fa
        clr   anim_frame,u             ; $FB
        clr   routine_secondary,u
        bra   @done
@fa     inc   routine_secondary,u      ; $FA
@done   orcc  #%00000001               ; C set : a command
        rts

 ENDC
