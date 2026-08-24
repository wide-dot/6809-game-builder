
; ---------------------------------------------------------------------------
; Object - Weapon
;
; input REG : [u] pointer to Object Status Table (OST)
; ---------
;
; ---------------------------------------------------------------------------

; V2-DEVIATION: les entrees d'imageset passent de Img_<nom> a set_<nom>,
; le nom que gfxcomp genere (meme ecart que pata-pata et le joueur).
; V2-DEVIATION: les en-tetes v1 sont retires — l'unite enveloppe les
; porte (macros, collision, equates), et le son n'est pas porte.
; Includes v1 retires :
;   INCLUDE "./engine/macros.asm"
;           INCLUDE "./engine/collision/macros.asm"
;           INCLUDE "./engine/collision/struct_AABB.equ"
;           INCLUDE "./objects/soundFX/soundFX.const.asm"
;           INCLUDE "./engine/sound/soundFX.macro.asm"

AABB_0  equ ext_variables ; AABB struct (9 bytes)
impactX equ ext_variables+9 ; impact x position

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

Init
        _soundFX.play soundFX.FireSound,0
        ldd   x_pos,u
        addd  #8+3
        std   x_pos,u
        ldd   y_pos,u
        addd  #2
        std   y_pos,u
        ldd   #set_weapon
        std   image_set,u
        ldb   #2
        stb   priority,u
        lda   render_flags,u
        ora   #render_playfieldcoord_mask
        sta   render_flags,u

        _Collision_AddAABB AABB_0,AABB_list_friend
        
        lda   #1                       ; set damage potential for this hitbox
        sta   AABB_0+AABB.p,u
        _ldd  15,1                     ; set hitbox xy radius (x should be 3, but 15 for framerate compensation)
        std   AABB_0+AABB.rx,u

        ldb   y_pos+1,u
        stb   AABB_0+AABB.cy,u

        ; compute wall hit destiny
        ldd   x_pos,u
        std   terrainCollision.sensor.x
        ldd   y_pos,u
        std   terrainCollision.sensor.y
        ldb   #1 ; foreground
        jsr   terrainCollision.xAxis.doRight
        ldd   terrainCollision.impact.x
        std   impactX,u
        inc   routine,u
        bra   >

Live
        ; delete weapon if no more damage potential
        lda   AABB_0+AABB.p,u
        lbeq  Delete                   ; le corps a grossi du crochet de couche
                                       ; destructible : portee courte insuffisante

        ; update weapon position
        lda   #6
        ldb   gfxlock.frameDrop.count
        mul
        addd  x_pos,u
        addd  glb_camera_x_pos
        subd  glb_camera_x_pos_old
        std   x_pos,u
!
        ; LA COUCHE DESTRUCTIBLE (24/08/2026) : le tir mange UNE cellule de
        ; gomme et meurt dessus. C'est le comportement de la borne — son
        ; effaceur rend zero, et le test de solidite qui suit voit « solide »
        ; et envoie le tir en impact (0x40:4F55). Le crochet vaut un rts sur
        ; les stages sans couche destructible.
        ; Ce tir-ci n'a pas de boucle de rattrapage : il avance de
        ; 6*frameDrop d'un coup, donc une sonde par tour, a l'arrivee.
        ldx   x_pos,u
        ldb   y_pos+1,u
        jsr   [stage.gum.hook]
        beq   @noGum
        ldd   x_pos,u                  ; la hitbox suit le point d'impact
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u
        ldd   #set_weapon_impact0
        std   image_set,u
        inc   routine,u
        jmp   DisplaySprite
@noGum
        ; check wall collision
        ldd   impactX,u
        beq   >
        subd  #3 ; half width of the weapon, to check collision on the right side
        cmpd  x_pos,u
        bhi   >
        jsr   RandomNumber
        clra
        andb  #%00000011
        _negd
        subd  #3 ; half width of the weapon
        addd  impactX,u
        std   x_pos,u
        subd  glb_camera_x_pos         ; recaler la hitbox sur le point d'impact : cette
        stb   AABB_0+AABB.cx,u         ;   branche ne l'ecrivait pas, et sur la trame de
                                       ;   naissance (tir ne DANS le mur) elle restait a 0,
                                       ;   soit une boite active au bord gauche de la camera
        ldd   #set_weapon_impact0
        std   image_set,u
        inc   routine,u
        jmp   DisplaySprite
!
        ; update hitbox position
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u

        ; delete weapon if out of screen range
        cmpd  #160-8/2                 ; delete weapon if out of screen range
        bhs   Delete
        jmp   DisplaySprite

Impact
        inc   routine,u
        ldd   #set_weapon_impact3
        std   image_set,u
        jmp   DisplaySprite

Delete 
        lda   #4 ; do not use inc here, it will lead to a bug.
        sta   routine,u
        _Collision_RemoveAABB AABB_0,AABB_list_friend
        jmp   DeleteObject

AlreadyDeleted
        rts ; once deleted, the object can be called again for double buffering update.

