
; ---------------------------------------------------------------------------
; Object - Couter-air laser
;
; input REG : [u] pointer to Object Status Table (OST)
; ---------
;       subtype : bit 0 => 0=going right, 1=going left
;
; ---------------------------------------------------------------------------

; V2-DEVIATION: les en-tetes communs sont portes par l'unite hote
; (counterairlaser.unit.asm), comme pour tout fichier v1 enveloppe.
; Includes v1 retires :
; INCLUDE "./engine/macros.asm"
; INCLUDE "./engine/collision/macros.asm"
; INCLUDE "./engine/collision/struct_AABB.equ"

AABB_0        equ ext_variables    ; AABB struct (9 bytes)
caFrame       equ ext_variables+9  ; 1 byte - current frame
slave         equ ext_variables+10 ; 1 byte - pos related to player one
xPosOld       equ ext_variables+11 ; 2 bytes - old player one x_pos
impactX       equ ext_variables+13 ; 2 bytes - impact x position
parent        equ ext_variables+15 ; 2 bytes - parent object pointer
armed         equ ext_variables+17 ; 1 byte  - 1 = hitbox armee (segment deja apparu a l'ecran)
gumPrevX      equ ext_variables+18 ; 2 bytes - x de la tete a la trame precedente (labour)

stepMove      equ 6                ; number of pixels in horizontal axis
leftOffset    equ 11               ; init position when left
rightOffset   equ 8                ; init position when left
CA_POWER      equ 5                ; arcade: counter-air laser power (penetrates/depletes)

Object
        lda   routine,u
        asla
        ldx   #Routines
        jmp   [a,x]

Routines
        fdb   GenChilds
        fdb   LiveInit
        fdb   Live
        fdb   AlreadyDeleted

GenChilds
        ldd   #0
        std   glb_d2
        jsr   InitFirstChild

        inc   glb_d0_b
        ldd   glb_d2
        addd  glb_d1
        std   glb_d2
        jsr   GenChild

        inc   glb_d0_b
        ldd   glb_d2
        addd  glb_d1
        std   glb_d2
        jsr   GenChild

        inc   glb_d0_b
        ldd   glb_d2
        addd  glb_d1
        std   glb_d2
        jsr   GenChild
        
        jmp   LiveInit

InitFirstChild                   
        lda   #1
        sta   routine,u
        ldb   #4
        stb   priority,u
        lda   #CA_POWER                ; la tete nait a caFrame 7 = deja visible : armee
        sta   AABB_0+AABB.p,u
        _ldd  3,14                     ; set hitbox xy radius
        std   AABB_0+AABB.rx,u
        ldb   player1+y_pos+1
        stb   y_pos+1,u
        stb   AABB_0+AABB.cy,u
        ldb   render_flags,u
        lda   subtype,u                ; 4: pod hooked right, 5: pod hooked left
        anda  #1
        beq   @goRight
@goLeft
        orb   #render_xmirror_mask     ; use mirrored images when going left
        orb   #render_playfieldcoord_mask
        stb   render_flags,u
        ldd   #stepMove                ; sprites are prepared on the opposite side of the direction
        std   glb_d1
        _negd
        stb   x_vel,u
        ldd   player1+x_pos
        subd  #leftOffset
        bra   @end
@goRight
        orb   #render_playfieldcoord_mask
        stb   render_flags,u
        ldd   #-stepMove               ; sprites are prepared on the opposite side of the direction
        std   glb_d1
        _negd
        std   x_vel,u
        ldd   player1+x_pos
        addd  #rightOffset
@end
        ; compute wall hit destiny
        std   x_pos,u
        std   terrainCollision.sensor.x
        ldd   y_pos,u
        std   terrainCollision.sensor.y
        ldb   #1 ; foreground
        tst   x_vel,u
        bpl   >
        jsr   terrainCollision.xAxis.doLeft
        bra   @endif
!       jsr   terrainCollision.xAxis.doRight
@endif  ldd   terrainCollision.impact.x
        std   impactX,u
        
        lda   #6
        sta   slave,u
        lda   #7
        sta   glb_d0_b
        sta   caFrame,u
        ldd   x_pos,u                  ; cx en coords CAMERA (etait le poids faible de la
        subd  glb_camera_x_pos         ;   position playfield de player1 -> boite fantome
        stb   AABB_0+AABB.cx,u         ;   jusqu'au 1er Live)
        ldd   player1+x_pos
        std   xPosOld,u
        _Collision_AddAABB AABB_0,AABB_list_friend
 IFDEF t2        
        ldx   #counterAirImagesa
        stx   anim,u
 ENDC
        ldd   x_pos,u                  ; amorcer le labour : sans ca le premier
        std   gumPrevX,u               ; balayage partirait de zero
        stu   parent,u                 ; set self as parent
        rts

GenChild
        jsr   LoadObject_x
        bne   >
        leas  2,s                      ; skip return to caller
        jmp   LiveInit
!       lda   id,u
        sta   id,x
        lda   subtype,u
        sta   subtype,x
        lda   render_flags,u
        sta   render_flags,x
        lda   routine,u
        sta   routine,x
        lda   priority,u
        sta   priority,x
        lda   glb_d0_b
        sta   caFrame,x   
        clr   AABB_0+AABB.p,x          ; les 3 enfants naissent a caFrame 8/9/10, index sans
                                       ;   image : boite INERTE (p=0 -> ignoree par
                                       ;   Collision_Do) jusqu'a leur apparition, cf. Live.
                                       ;   armed,x vaut deja 0 (slot frais).
        ldd   AABB_0+AABB.rx,u         ; set hitbox xy radius
        std   AABB_0+AABB.rx,x         ; by copying 2 bytes
        ldd   x_pos,u
        addd  glb_d2                   ; sprites are prepared on the opposite side of the direction
        std   x_pos,x
        subd  glb_camera_x_pos         ; les 4 lignes suivantes ecrivaient sur ,u (le PARENT)
        stb   AABB_0+AABB.cx,x         ;   au lieu de ,x : l'enfant partait sans y_pos ni
        ldd   y_pos,u                  ;   cx/cy, et la cx du parent etait ecrasee par une
        std   y_pos,x                  ;   coordonnee playfield.
        stb   AABB_0+AABB.cy,x
        ldd   x_vel,u
        std   x_vel,x
        lda   slave,u
        sta   slave,x
        ldd   xPosOld,u
        std   xPosOld,x
        ldd   impactX,u
        std   impactX,x
        stu   parent,x
        pshs  u
        leau  ,x                       ; Collision routine use u as object pointer
        _Collision_AddAABB AABB_0,AABB_list_friend
 IFDEF t2
        ldx   #counterAirImages
        stx   anim,u
 ENDC        
        puls  u,pc

LiveInit
        inc   routine,u
        ldb   #0
        bra   @save
Live
        ; compute framedrop
        ldb   gfxlock.frameDrop.count
        asrb                           ; adjust speed
        bne   >
        incb                           ; min speed is 1 image segment
!       cmpb  #4                       ; maximum speed is 4 image segments
        blt   @save
        ldb   #4
@save   stb   counterAirLaser.frameDrop
;
        ; compute position and hitbox
        lda   #stepMove                ; image width
        mul                            ; process horizontal speed
        tst   x_vel,u
        bpl   >                        ; branch going right
        _negd
!       addd  x_pos,u   
        addd  glb_camera_x_pos         ; adjust scroll
        subd  glb_camera_x_pos_old
        std   x_pos,u
!
        ; check if laser is always attached to player one
        lda   caFrame,u
        suba  counterAirLaser.frameDrop
        bpl   >
        anda  #%00000011               ; loop thru 4 images
!       sta   caFrame,u
;
        ; track player's y_pos
        lda   slave,u 
        suba  counterAirLaser.frameDrop
        bmi   @updateCommon
        sta   slave,u
        ldd   player1+x_pos
        subd  xPosOld,u
        addd  x_pos,u
        std   x_pos,u
        ldd   player1+x_pos
        std   xPosOld,u
        ldb   player1+y_pos+1
        cmpb  y_pos+1,u
        beq   @updateCommon
        stb   y_pos+1,u
        stb   AABB_0+AABB.cy,u
        cmpu  parent,u  
        bne   @updateChild
        ldd   x_pos,u
        std   terrainCollision.sensor.x
        ldd   y_pos,u
        std   terrainCollision.sensor.y
        ldb   #1 ; foreground
        tst   x_vel,u
        bpl   >
        jsr   terrainCollision.xAxis.doLeft
        bra   @endif
!       jsr   terrainCollision.xAxis.doRight
@endif  ldd   terrainCollision.impact.x
        std   impactX,u
        bra   @updateEnd
@updateChild      
        ldx   parent,u
        lda   id,x
        cmpa  #ObjID_forcepod_counterairlaser
        bne   @updateCommon
        ldd   impactX,x
        std   impactX,u
@updateCommon
        lda   #-1
        sta   slave,u  
@updateEnd
        ;
        ; check out of screen range
        ldd   x_pos,u
        subd  glb_camera_x_pos
        bmi   @delete                  ; out of range on left
        stb   AABB_0+AABB.cx,u
        cmpd  #160-8/2                 ; out of screen range on right
        bgt   @delete
;
        ; check wall collision
        ldd   impactX,u
        beq   > ; no wall collision
        tst   x_vel,u
        bmi   @goingLeft
        subd  #3 ; half width of the weapon, to check collision on the right side of sprite
        cmpd  x_pos,u
        bls   @delete
        bra   >
@goingLeft
        addd  #3 ; half width of the weapon, to check collision on the left side of sprite
        cmpd  x_pos,u
        bhs   @delete
!
        ; --- LE LABOUR : LA TETE SEULE, ET A CHAQUE TRAME (voir plus bas)
        cmpu  parent,u
        bne   >
        jsr   CounterAirGumSweep
!
        ; compute current frame
        lda   caFrame,u
 IFDEF t2
        ldx   anim,u
 ELSE
        ldx   #counterAirImages
 ENDC        
        asla
        ldx   a,x
        stx   image_set,u
        beq   @caHidden                ; index 8/9/10 = fdb 0 : segment pas encore apparu
        ; premiere trame VISIBLE -> on arme la hitbox. Avant ce correctif les 3 enfants
        ; etaient inscrits dans AABB_list_friend avec p=CA_POWER des GenChild : ils
        ; infligeaient des degats PENETRANTS et INVISIBLES pendant 1 a 3 trames, pile sur
        ; le force pod (x_pos -6/-12/-18), en contournant le gate 1 degat / 16 trames de
        ; WeaponContactTick. On n'arme qu'une fois : sans le drapeau, un segment dont le
        ; potentiel est epuise se rechargerait a chaque trame.
        lda   armed,u
        bne   @caShown
        inc   armed,u
        lda   #CA_POWER
        sta   AABB_0+AABB.p,u
@caShown
        jmp   DisplaySprite
@caHidden
        rts
@delete
        _Collision_RemoveAABB AABB_0,AABB_list_friend
        lda   #3
        sta   routine,u
        jmp   DeleteObject
AlreadyDeleted
        rts

; ---------------------------------------------------------------------------
; CounterAirGumSweep — le plus gros effacement du jeu
; ---------------------------------------------------------------------------
; arcade : 0x40:4A28..4A88 (tir vers l'avant) et son miroir 0x4B57..4BB8, ou le
; `x -= 0x48` devient `x += 0x48`. ONZE blocs de 4x4 cellules d'un coup, poses
; aux centres suivants, en px arcade relatifs a la tete :
;
;      (x-72,y-12) (x-60,y-12)                              la TETE : deux
;      (x-72,y   ) (x-60,y   ) (x-48,y) (x-34,y) (x-20,y)   colonnes sur trois
;      (x-72,y+12) (x-60,y+12)          (x-6,y)  (x+8,y)    rangees, puis la
;                                                           QUEUE sur la rangee
;                                                           du milieu
;
; Les blocs se recouvrent largement (12 px d'ecart pour 32 px de large) : la
; surface reelle est un T. On la rend par DEUX rectangles au lieu de onze
; blocs — meme forme, deux appels.
;   tete  : 6 cellules de large sur 7 rangees, a la racine du tir
;   queue : 11 cellules de large sur 4 rangees, sur la rangee du milieu
;
; QUAND, ET QUI. Ici la reponse s'ecarte de la borne, et il faut savoir
; pourquoi (25/08/2026). Chez elle le counter-air est UN SEUL objet : les
; quatre segments sont quatre tranches de sprite du meme, sa tete est ANCREE au
; pod (pos = pod +-0x50) et ne voyage pas, son anneau d'animation fait seize
; trames, et le balayage tombe a `anim_phase == 0` — donc UNE FOIS, a la
; naissance. Elle creuse son couloir d'un coup et joue son animation dedans ;
; c'est ce qui donne le front de gommes net devant le tir.
;
; Notre portage (celui de la v1) en fait QUATRE OBJETS, et sa tete VOYAGE
; (stepMove px par pas d'animation). Un balayage unique a la naissance
; laisserait donc le tir survoler des gommes intactes tout le reste de sa vie —
; c'est exactement ce qu'on voyait : le sprite dessine par-dessus des gommes
; encore la, effacees plusieurs trames plus tard. On laboure donc A CHAQUE
; TRAME, et LE SILLAGE, de la position de la trame precedente a la position
; courante : la tete creuse toujours devant elle, et les trois segments qui la
; suivent avancent dans un couloir deja fait.
;
; LA TETE SEULE. Les trois autres segments ne labourent pas : ils sont derriere
; elle, dans le couloir. Un seul balayage par trame, donc le meme cout qu'avant
; — et c'est aussi le nombre d'appels que faisait la borne.
;
; V2-DEVIATION: la reflexion du counter-air (0x40:4E6B, une grappe 2x2) n'est
; pas portee — l'objet de reflexion ne l'est pas non plus.
; ---------------------------------------------------------------------------
CounterAirGumSweep
        ldd   stage.gum.hook
        addd  #6                       ; +6 : effacer un rectangle balaye
        std   counterAir.gum.call

        ldd   #-33                     ; --- LA TETE, a la racine du tir
        tst   x_vel,u
        bpl   >
        ldd   #16                      ; vers la gauche : elle passe de l'autre cote
!       std   counterAir.gum.off
        ldb   y_pos+1,u
        subb  #21
        bhs   >
        clrb                           ; le tir colle au haut du champ
!       lda   #$67                     ; 6 cellules de large, 7 rangees
        bsr   CounterAirGumRect

        ldd   #-24                     ; --- LA QUEUE
        tst   x_vel,u
        bpl   >
        ldd   #-9
!       std   counterAir.gum.off
        ldb   y_pos+1,u
        subb  #12
        bhs   >
        clrb
!       lda   #$B4                     ; 11 cellules de large, 4 rangees
        bsr   CounterAirGumRect

        ldd   x_pos,u                  ; la trame suivante partira d'ici
        std   gumPrevX,u
        rts

; input REG : [a] la taille du bloc, [b] la ligne ecran du haut
; input VAR : counterAir.gum.off, l'offset SIGNE du bord gauche
CounterAirGumRect
        sta   @size
        stb   @line
        ldd   gumPrevX,u               ; le depart
        addd  counterAir.gum.off
        bpl   >
        ldd   #0                       ; debut de carte : on colle au bord
!       tfr   d,x
        ldd   x_pos,u                  ; l'arrivee
        addd  counterAir.gum.off
        bpl   >
        ldd   #0
!       tfr   d,y
        ldb   #0
@line   equ   *-1
        lda   #0
@size   equ   *-1
        jsr   >0
counterAir.gum.call equ *-2
        rts

counterAir.gum.off  fdb 0

counterAirImages
        fdb   Img_counterairlaser_7
        fdb   Img_counterairlaser_6
        fdb   Img_counterairlaser_5
        fdb   Img_counterairlaser_4
        fdb   Img_counterairlaser_3
        fdb   Img_counterairlaser_2
        fdb   Img_counterairlaser_1
        fdb   Img_counterairlaser_0
        fdb   0
        fdb   0
        fdb   0

 IFDEF t2
counterAirImagesa
        fdb   Img_counterairlaser_7a
        fdb   Img_counterairlaser_6a
        fdb   Img_counterairlaser_5a
        fdb   Img_counterairlaser_4a
        fdb   Img_counterairlaser_3a
        fdb   Img_counterairlaser_2a
        fdb   Img_counterairlaser_1a
        fdb   Img_counterairlaser_0a
        fdb   0
        fdb   0
        fdb   0
 ENDC

; (la table counterAirHitboxes, hitbox par frame indexee comme counterAirImages, a ete
; retiree : jamais cablee, et ses entrees 19/22 auraient elargi l'emprise verticale de
; +36 a +57 % sur 4 frames sur 8. La hitbox reste constante a 3,14 posee a l'init.)

counterAirLaser.frameDrop
        fcb   0