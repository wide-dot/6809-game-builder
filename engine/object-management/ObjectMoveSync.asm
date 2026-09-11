* ---------------------------------------------------------------------------
* Subroutine translating object speed to update object position
* This moves the object horizontally and vertically
* but does not apply gravity to it
* ---------------------------------------------------------------------------
; apply XY velocity in sync with framerate
; ----------------------------------------
; V2-DEVIATION (10/09/2026, decision auteur) : la v1 bouclait TRAME PAR TRAME
; sur le nombre de trames ecoulees, une quarantaine de cycles par trame et par
; objet mobile — 350 cycles par objet a neuf trames par rendu. L'integration
; d'une vitesse 8.8 constante sur k trames est k fois la vitesse : deux mul non
; signes par axe, produit tronque juste en complement a deux (le calcul de
; bullet.AddPos et layer.AddPos, mot pour mot), une centaine de cycles quel
; que soit le drop, et LES MEMES POSITIONS au bit pres. Zero trame ecoulee
; compte pour une, comme avant. Cas de migration :
; docs/lang/en/migration/frame-drop-loops-are-multiplies.md
ObjectMoveSync
        ldb   gfxlock.frameDrop.count  ; elapsed frames since last render
        bne   >
        ldb   #1
!       stb   @kx
        stb   @ky
        ; --- x : x_pos (16.8) += x_vel (8.8 signed) * k ---
        lda   x_vel+1,u                ; low byte of the velocity
        ldb   #0
@kx     equ   *-1
        mul                            ; low byte x k, in full
        std   @tx
        lda   x_vel,u                  ; high byte
        ldb   @kx
        mul                            ; high byte x k, its low byte shifted
        tfr   b,a
        clrb
        addd  #0
@tx     equ   *-2                      ; D = velocity x k, 8.8, exact in two's complement
        pshs  d
        ldb   ,s
        sex
        sta   @ax+1                    ; the sign of the product, for the high byte
        puls  d
        addd  x_pos+1,u                ; x_pos must be followed by x_sub in memory
        std   x_pos+1,u
        lda   x_pos,u
@ax     adca  #$00                     ; (dynamic) sign extension of the product
        sta   x_pos,u
        ; --- y ---
        lda   y_vel+1,u
        ldb   #0
@ky     equ   *-1
        mul
        std   @ty
        lda   y_vel,u
        ldb   @ky
        mul
        tfr   b,a
        clrb
        addd  #0
@ty     equ   *-2
        pshs  d
        ldb   ,s
        sex
        sta   @ay+1
        puls  d
        addd  y_pos+1,u                ; y_pos must be followed by y_sub in memory
        std   y_pos+1,u
        lda   y_pos,u
@ay     adca  #$00
        sta   y_pos,u
        rts
