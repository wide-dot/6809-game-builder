
; ---------------------------------------------------------------------------
; Object - Weapon
;
; input REG : [u] pointer to Object Status Table (OST)
; ---------
;
; ---------------------------------------------------------------------------

; V2-DEVIATION: les en-tetes communs sont portes par l'unite hote
; (simplefire.unit.asm), comme pour tout fichier v1 enveloppe.
; Includes v1 retires :
; INCLUDE "./engine/macros.asm"
; INCLUDE "./engine/collision/macros.asm"
; INCLUDE "./engine/collision/struct_AABB.equ"

AABB_0  equ ext_variables ; AABB struct (9 bytes)

Weapon
        lda   routine,u
        asla
        ldx   #Weapon_Routines
        jmp   [a,x]

Weapon_Routines
        fdb   Init
        fdb   Live
        fdb   Impact
        fdb   Delete
        fdb   AlreadyDeleted

glb.frameDrop      fcb 0

Init
        lda   #6
        ldb   subtype,u
        mul
        ldx   #SimpleFirePresets
        abx
        ldd   ,x
        std   image_set,u
        ldd   2,x
        std   x_vel,u
        ldd   4,x
        std   y_vel,u

        ldb   #2
        stb   priority,u
        lda   render_flags,u
        ora   #render_playfieldcoord_mask
        sta   render_flags,u

        _Collision_AddAABB AABB_0,AABB_list_friend
        leax  AABB_0,u
        lda   #1                       ; set damage potential for this hitbox
        sta   AABB.p,x
        _ldd  9,6                      ; set hitbox xy radius (arcade unique size: 24,8)
        std   AABB.rx,x

        inc   routine,u

Live
        ; delete weapon if no more damage potential
        lda   AABB_0+AABB.p,u
        lbeq  Delete

        ; check wall collision
        ldb   gfxlock.frameDrop.count
        bne   >                        ; count == 0 (1re boucle apres checkpoint.load) : le
        incb                           ; "dec / bne" ferait 256 tours, soit 512 terrainCollision.do
!       stb   glb.frameDrop
FrameDropLoop

        ; update position
        ldb   x_vel,u
        sex                            ; velocity is positive or negative, take care of that
        sta   @a+1
        ldd   x_pos+1,u                ; x_pos must be followed by x_sub in memory
        addd  x_vel,u
        std   x_pos+1,u                ; update low byte of x_pos and x_sub byte
        lda   x_pos,u
@a
        adca  #$00                     ; (dynamic) parameter is modified by the result of sign extend
        sta   x_pos,u                  ; update high byte of x_pos
;        
        ldb   y_vel,u
        sex                            ; velocity is positive or negative, take care of that
        sta   @b+1        
        ldd   y_pos+1,u                ; y_pos must be followed by y_sub in memory
        addd  y_vel,u
        std   y_pos+1,u                ; update low byte of y_pos and y_sub byte
        lda   y_pos,u
@b
        adca  #$00                     ; (dynamic) parameter is modified by the result of sign extend
        sta   y_pos,u                  ; update high byte of y_pos        

        ; check if the fire is on edge of the screen (right)
        ; if so, skip wall collision
        ldd   x_pos,u
        subd  glb_camera_x_pos
        ;cmpd  #-9
        ;blt   Delete
        cmpd  #144+9
        bge   Delete
        ldd   y_pos,u
        subd  glb_camera_y_pos
        cmpd  #-6
        blt   Delete
        cmpd  #180+6
        bge   Delete

        ; check for collision with the walls
        ldd   x_pos,u
        std   terrainCollision.sensor.x
        ldd   y_pos,u
        std   terrainCollision.sensor.y

        ; LA COUCHE DESTRUCTIBLE D'ABORD (24/08/2026, portage 1:1 de l'arcade).
        ; run_simple_fire (0x40:4F40) sonde la tuile, l'efface si c'est une
        ; gomme, PUIS teste la solidite — et la routine d'effacement rendant
        ; zero, ce test voit « solide » et le tir part en impact. Un tir simple
        ; y mange donc EXACTEMENT UNE cellule et meurt dessus ; les deux
        ; missiles ont le meme sort. Ce n'est visiblement pas voulu par la
        ; borne, mais c'est son comportement, et on le reproduit — sans imiter
        ; le XOR AX,AX : ici l'effaceur dit franchement « j'ai mange », et on
        ; prend la meme branche que le mur.
        ; Le crochet vaut un rts sur les stages sans couche destructible.
        ldx   x_pos,u
        ldb   y_pos+1,u
        jsr   [stage.gum.hook]
        bne   @impact
        ldb   #1 ; foreground
        jsr   terrainCollision.do
        tstb
        bne   @impact
        lda   globals.backgroundSolid
        beq   >
        ldb   #0 ; background
        jsr   terrainCollision.do
        tstb
        beq   >
@impact        
        ldd   #Img_weapon_impact0
        std   image_set,u
        inc   routine,u
        bra   @end
!
        dec   glb.frameDrop
        lbne  FrameDropLoop            ; le corps a grossi du crochet de couche
                                       ; destructible : la portee courte ne suffit plus
@end
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u            
        ldb   y_pos+1,u
        stb   AABB_0+AABB.cy,u  
        jmp   DisplaySprite

Impact
        inc   routine,u
        ldd   #Img_weapon_impact3
        std   image_set,u
        jmp   DisplaySprite

Delete 
        lda   #4 ; do not use inc here, it will lead to a bug.
        sta   routine,u
        _Collision_RemoveAABB AABB_0,AABB_list_friend
        jmp   DeleteObject

AlreadyDeleted
        rts ; once deleted, the object can be called again for double buffering update.

SimpleFirePresets
        ; Arcade reference speed : $0,$a00 $c00,$240 $d00,$0
        fdb   Img_shootup
        fdb   $0,-$780
        fdb   Img_shootupright
        fdb   $480,-$1b8
        fdb   Img_shootright
        fdb   $4e0,$0
        fdb   Img_shootdownright
        fdb   $480,$1b8
        fdb   Img_shootdown
        fdb   $0,$780
