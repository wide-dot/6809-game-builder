
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
impactX equ ext_variables+9  ; impact x position (mur OU gomme : LE destin)
gumHit  equ ext_variables+11 ; != 0 si ce destin est une gomme a manger

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

        ; --- LE DESTIN DU TIR, calcule UNE FOIS a la naissance
        ; La sonde de ligne rend le bord gauche de la premiere cellule 3x6
        ; pleine a droite. On la joue DEUX FOIS sur le meme senseur : le decor
        ; dur (plan 1), puis la couche destructible du stage par le crochet
        ; (plan 0 — les gommes du stage 4). Le plus proche des deux gagne :
        ; le tir meurt sur le premier obstacle, et on sait lequel.
        ldd   x_pos,u
        std   terrainCollision.sensor.x
        ldd   y_pos,u
        std   terrainCollision.sensor.y
        ldb   #1 ; foreground
        jsr   terrainCollision.xAxis.doRight
        ldd   terrainCollision.impact.x
        std   impactX,u
        clr   gumHit,u

        ; le senseur est toujours pose : le crochet rebalaie LA MEME ligne
        ldx   stage.gum.hook
        jsr   3,x                      ; +3 : chercher (cf. state/variables.asm)
        cmpd  #0
        beq   @destiny                 ; pas de couche destructible, ou rien devant
        ldx   impactX,u
        beq   @gum                     ; pas de mur : la gomme decide seule
        cmpd  impactX,u
        bhs   @destiny                 ; le mur vient avant, le tir n'ira pas plus loin
@gum    std   impactX,u                ; UN seul destin, et c'est une gomme
        inc   gumHit,u
@destiny
        inc   routine,u
        bra   >

Live
        ; delete weapon if no more damage potential
        lda   AABB_0+AABB.p,u
        lbeq  Delete                   ; le corps a grossi : portee courte
                                       ; insuffisante

        ; update weapon position
        lda   #6
        ldb   gfxlock.frameDrop.count
        mul
        addd  x_pos,u
        addd  glb_camera_x_pos
        subd  glb_camera_x_pos_old
        std   x_pos,u
!
        ; check wall collision — LE MEME CHEMIN POUR LE MUR ET POUR LA GOMME.
        ; impactX porte le destin choisi a la naissance ; il ne reste qu'a
        ; guetter l'arrivee. Il n'y a PLUS de sonde par trame : elle ne pouvait
        ; pas suivre a bas regime (6*frameDrop = 24 px d'un coup a 12 img/s,
        ; huit cellules enjambees) et mangeait une gomme loin devant le sprite
        ; d'impact. Cf. src/common/state/variables.asm.
        ldd   impactX,u
        beq   >
        subd  #3 ; half width of the weapon, to check collision on the right side
        cmpd  x_pos,u
        bhi   >

        ; LA COUCHE DESTRUCTIBLE (24/08/2026) : le tir mange UNE cellule de
        ; gomme et meurt dessus. Ici la cellule est celle que la sonde a
        ; designee, au pixel — pas celle sur laquelle le tir est retombe.
        ;
        ; ET IL MEURT SANS IMAGE D'IMPACT (decision auteur, 25/08/2026) : ce
        ; qu'on doit voir, c'est la gomme qui disparait, pas une gerbe blanche
        ; par-dessus. L'impact reste pour le decor dur, qui lui ne cede pas.
        tst   gumHit,u
        beq   @wall
        ldx   impactX,u
        ldb   y_pos+1,u
        jsr   [stage.gum.hook]         ; +0 : effacer
        lbra  Delete
@wall
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

