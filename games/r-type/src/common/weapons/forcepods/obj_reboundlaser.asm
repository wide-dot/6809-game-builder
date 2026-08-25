; ---------------------------------------------------------------------------
; Object - Rebound Laser
;
; Unlike arcade :
; - only the parent object go through collisions, childs follow the parent
;
; input REG : [u] pointer to Object Status Table (OST)
; ---------
; subtype: 0=front, 1=back
; x_pos: x position of the forcepod
; y_pos: y position of the forcepod
; ---------------------------------------------------------------------------

; V2-DEVIATION: les en-tetes communs sont portes par l'unite hote
; (reboundlaser.unit.asm), comme pour tout fichier v1 enveloppe.
; Includes v1 retires :
; INCLUDE "./engine/macros.asm"
; INCLUDE "./engine/collision/macros.asm"
; INCLUDE "./engine/collision/struct_AABB.equ"
; INCLUDE "./objects/player1/player1.equ"

AABB_0        equ ext_variables    ; AABB struct (9 bytes)
direction     equ ext_variables+9  ; 1 byte, diagonal: 0=upright, 2=downright, 4=downleft, 6=upleft - horizontal: 0=right, 2=left
nbPass        equ ext_variables+10 ; 1 byte, passagers derriere la tete
laserLifetime equ ext_variables+11 ; 1 byte, number of frames the laser is active
slotMask      equ ext_variables+12 ; 1 byte, mask to set/free slot occupation
parent        equ ext_variables+13 ; 2 bytes, parent object pointer (0=no parent, head of laser)
childId       equ ext_variables+15 ; 1 byte, index of the child laser (0=first child, 1=second child, ...)
isLastChild   equ ext_variables+16 ; 1 byte, 1=last child, 0=not last child
bufferBase    equ ext_variables+17 ; 2 bytes, index of the position buffer (aligned to 16 bytes)
bufferIndex   equ ext_variables+19 ; 1 byte, index in the 16 bytes buffer (0,2,4,6,8,10,12,14)
child         equ routine_tertiary ; 2 bytes, pointer to the next child object in the laser chain

LASER_LIFETIME equ $70 ; 112 frames

LASER_RIGHT_UP   equ 0
LASER_RIGHT_DOWN equ 2
LASER_LEFT_DOWN  equ 4
LASER_LEFT_UP    equ 6

LASER_RIGHT equ 0
LASER_LEFT  equ 2

SLOT_UP     equ 1
SLOT_CENTER equ 2
SLOT_DOWN   equ 4

Object
        lda   routine,u
        asla
        ldx   #Routines
        jmp   [a,x]

Routines
        fdb   Orchestrate
        fdb   StartLaser
        fdb   RunHorizontalLaser
        fdb   RunDiagonalLaser
        fdb   RunExplosion
        fdb   DoubleBufferingFlush
        fdb   Render

Rtn_Orchestrate          equ 0
Rtn_StartLaser           equ 1
Rtn_RunHorizontalLaser   equ 2
Rtn_RunDiagonalLaser     equ 3
Rtn_RunExplosion         equ 4
Rtn_DoubleBufferingFlush equ 5
Rtn_Render               equ 6   ; le renderer groupe des passagers (reboundmgr.asm)

glb.loopCounter    fcb 0
glb.childId        fcb 0
glb.prevSegment    fdb 0
glb.slotsState     fcb 0 ; bit0=up, bit1=center, bit2=down
glb.frameDrop      fcb 0
glb.buffer         fdb 0 ; temp for buffer address
glb.dataLocation   fdb 0
glb.renderLive     fcb 0 ; un renderer de la volee precedente vit-il encore ?

; V2-DEVIATION : la v1 aligne ses trois tampons cycliques par arithmetique sur
; le compteur d'adresse — `fill 0,32` de rab, puis `equ (*/32)*32` qui arrondit
; vers le bas. Ca ne tient que dans une unite assemblee a une adresse ABSOLUE :
; ici la section est relogeable, `*` reste symbolique, et l'expression n'est ni
; repliable a l'assemblage ni relogeable au chargement — un alignement ne se
; reloge pas, (base+offset)/32*32 n'est pas base+f(offset).
;
; `ALIGN 32` dit la meme chose a l'assembleur, qui rend une constante. Chaque
; `fill` etant un multiple de 32, aligner le PREMIER tampon aligne les trois.
; CONDITION : la region qui recoit cette unite doit demarrer sur un multiple de
; 32 — `reboundlaser` est en $1C:$0000, et le layout le garde.
                       ALIGN 32
glb.diagonalUpBuffer   equ *
                       fill 0,32*3 ; used to store up to 16 words group (x_pos, y_pos, image_set)
glb.diagonalDownBuffer equ *
                       fill 0,32*3 ; used to store up to 16 words group (x_pos, y_pos, image_set)
glb.horizontalBuffer   equ *
                       fill 0,32 ; used to store up to 16 words (x_pos)

DIV6u
  bsr  DIV3u
  lsra
  rorb
  lsr  2,x
  std  ,x
  rts

DIV3u
  ldb  1,x
  lda  #85
  mul
  std  1,x
  ldb  ,x
  lda  #85
  mul
  addb 1,x
  adca #0
  std  ,x
* partie optionnelle pour une vraie division par 3,
* sinon c'est division par 3.0117 (0.4% d'erreur)
  ldd  1,x
  addd #128   ; arrondi
  adda 2,x
  sta  2,x
  ldd  ,x
  adcb ,x
  adca #0
  std  ,x
* fin de la partie optionelle pour vraie division
  rts

Orchestrate
        ; a rebound laser can only be releases if the previous one was destroyed
        ; each of the 3 lasers (high, mid, low) are independent

        ; --- RESYNC : glb.slotsState est reconstruit depuis la liste d'objets, il n'est
        ; PLUS un latch. Il n'etait libere que par Destroy (segment isLastChild) ; tout
        ; segment disparu autrement laissait son bit colle et le rebound ne repartait
        ; JAMAIS. Cas nominal : mort du joueur pendant une volee -> le reload checkpoint
        ; passe par ManagedObjects_ClearAll, qui efface les OST sans executer Destroy, et
        ; glb.slotsState vit dans la page objet (hors de la plage $A000-$E000 de
        ; ClearDataMem) donc survit. Le balayage est self-healing pour toutes les autres
        ; pertes possibles (pool sature, maillon orphelin) et ne coute qu'un parcours de
        ; liste par appui sur le bouton de tir.
        ; Occupent un slot : routines 1..4 (StartLaser/Horizontal/Diagonal/Explosion).
        ; Ignores : 0 = orchestrateur (nous-meme, ou un precedent en attente de free) et
        ; 5 = DoubleBufferingFlush (Destroy a deja rendu le slot ET inverse slotMask).
        clr   glb.slotsState
        clr   glb.renderLive
        ldx   object_list_first
        beq   @synced
@sloop  lda   id,x
        cmpa  #ObjID_forcepod_reboundlaser
        bne   @snext
        lda   routine,x
        beq   @snext                  ; 0 = Rtn_Orchestrate
        cmpa  #Rtn_Render              ; le renderer groupe ne prend pas de slot,
        bne   @snotrender              ;   mais on note qu'il vit : en creer un
        inc   glb.renderLive           ;   second dessinerait tout en double
@snotrender
        cmpa  #Rtn_DoubleBufferingFlush
        bhs   @snext
        ldb   glb.slotsState
        orb   slotMask,x
        stb   glb.slotsState
@snext  ldx   run_object_next,x
        bne   @sloop
@synced
        lda   glb.slotsState
        ; n'initier une nouvelle volee que si TOUS les slots sont libres (la precedente est entierement finie).
        ; en stream slot-par-slot, le slot d'OBJET d'un head mort est reutilise en LIFO par un nouveau segment
        ; de meme id/routine -> le dernier maillon orpheline croit son parent vivant, ne meurt jamais, et son
        ; slot reste pris. Apres 1-2 volees les 3 slots collent et le rebound s'arrete.
        ; (equivalent arcade : rebound_laser_chain_ready_flag - on attend que la chaine soit prete)
        beq   >
        jmp   DeleteObject
!

        ; adjust x position based on the position of the forcepod
        ldb   subtype,u   ; get position of the forcepod
        beq   >
        ldd   player1+x_pos
        subd  #9
        bra   @end
!
        ldd   player1+x_pos
        addd  #11
@end    std   x_pos,u

        ; snap on tile grid (3px)
        leax  x_pos,u        
        jsr   DIV3u
        addd  x_pos,u        
        addd  x_pos,u        
        std   x_pos,u        
        std   terrainCollision.sensor.x

        ; snap on tile grid (6px)
        ldd   player1+y_pos
        std   y_pos,u
        leax  y_pos,u        
        jsr   DIV6u
        addd  y_pos,u        
        addd  y_pos,u        
        lslb
        rola        
        addd  #1 ; center of the tile
        std   y_pos,u
        std   terrainCollision.sensor.y

        ; check if the laser is born inside a wall
        ldb   #1 ; foreground
        jsr   terrainCollision.do
        tstb
        beq   >
        jmp   DeleteObject
!
        lda   globals.backgroundSolid
        beq   >
        ldb   #0 ; background
        jsr   terrainCollision.do
        tstb
        beq   >
        jmp   DeleteObject
!
        ; LE RENDERER GROUPE : les slots de la volee precedente sont morts
        ; avec elle (une volee exige les trois slots libres), on les eteint
        ; avant que les nouvelles chaines n'y publient.
        jsr   reboundmgr.reset

        ; initiate the lasers
        lda   glb.slotsState
        anda  #SLOT_UP                ; is slot up active?
        bne   >                       ; if yes, skip
        ldd   #glb.diagonalUpBuffer
        std   glb.buffer
        lda   #LASER_RIGHT_UP
        ldb   #SLOT_UP
        jsr   InitiateDiagonalLaser
!       lda   glb.slotsState          ; is slot center active?
        anda  #SLOT_CENTER            ; if yes, skip
        bne   >
        ldb   #SLOT_CENTER
        jsr   InitiateHorizontalLaser
!       lda   glb.slotsState          ; is slot down active?
        anda  #SLOT_DOWN              ; if yes, skip
        bne   >
        ldd   #glb.diagonalDownBuffer
        std   glb.buffer        
        lda   #LASER_RIGHT_DOWN
        ldb   #SLOT_DOWN
        jsr   InitiateDiagonalLaser
!
        ; l'objet qui dessinera les passagers des trois chaines — un seul, et
        ; pas un de plus (cf. glb.renderLive plus haut)
        lda   glb.renderLive
        bne   @noRender
        jsr   LoadObject_x
        beq   @noRender
        lda   #ObjID_forcepod_reboundlaser
        sta   id,x
        lda   #Rtn_Render
        sta   routine,x
        clr   routine_secondary,x
@noRender
        jmp   DeleteObject

InitiateDiagonalLaser
        stb   slotMask,u

        ; set direction based on the position of the forcepod
        ldb   subtype,u   ; get position of the forcepod
        beq   >
        adda  #4          ; UP and DOWN are inverted when rear mounted forcepod, it does not matter
        anda  #7
!       sta   direction,u

        ldd   #0
        std   parent,u
        sta   isLastChild,u
        stu   glb.prevSegment ; dummy value ... will set something on the orchestrate object when writing child,y        
        ldx   glb.buffer
        stx   bufferBase,u
        jsr   initBuffer
        leax  ,u                       ; 1er segment : X vaut bufferBase apres initBuffer. Si
                                       ;   LoadObject_x echoue ici, le chemin d'echec fait
                                       ;   "inc isLastChild,x" -> sans ca il corromprait
                                       ;   bufferBase+$36 (code). On vise l'orchestrateur (inoffensif).
        jsr   DiagonalLoadObject       ; la tete, et elle seule
        ; LA LONGUEUR. Les passagers ne sont plus des objets : la tete les
        ; porte, et le renderer groupe les dessine. Huit segments ne coutent
        ; donc plus qu'UN objet, la ou ils en coutaient huit — c'est ce qui
        ; rend la longueur de la borne payable.
        ; Deux au palier faible, huit au palier fort : c'est ce que donne la
        ; table de routage des slots d'arme de la borne (ES:0x1B80), decodee
        ; dans doc/rebound-laser-plan.md.
        ldb   #RB.MAXSEG-1
        lda   globals.forcepodlevel
        cmpa  #2
        bne   >
        ldb   #1
!       stb   nbPass,x
        rts

DiagonalLoadObject
        stx   @x
        jsr   LoadObject_x
        beq   >
        ldb   glb.slotsState
        orb   slotMask,u
        stb   glb.slotsState    
        jsr   InitLaserSegment
        lda   #Rtn_RunDiagonalLaser
        sta   routine_secondary,x
        rts
!
        ldx   #0
@x      equ *-2
        inc   isLastChild,x ; assign a last child when no more slots are available
        leas  2,s ; double return to skip following object allocation (no more slots available)
        rts

initBuffer
        ;ldd   #0 already done ...
        std   ,x
        std   2,x        
        std   4,x
        std   6,x
        std   8,x
        std   10,x
        std   12,x
        std   14,x
        std   16,x
        std   18,x
        std   20,x
        std   22,x
        std   24,x
        std   26,x
        std   28,x
        std   30,x
        rts

InitiateHorizontalLaser
        stb   slotMask,u

        ; set direction based on the position of the forcepod
        ldb   #LASER_RIGHT
        lda   subtype,u   ; get position of the forcepod
        beq   >
        ldb   #LASER_LEFT
!       stb   direction,u

        ldd   #0
        std   parent,u
        sta   isLastChild,u
        stu   glb.prevSegment ; dummy value ... will set something on the orchestrate object when writing child,y
        ldx   #glb.horizontalBuffer
        stx   bufferBase,u
        jsr   initBuffer
        leax  ,u                       ; 1er segment : X vaut bufferBase ($3200) apres initBuffer.
                                       ;   Si LoadObject_x echoue ici (pool plein), le chemin d'echec
                                       ;   "inc isLastChild,x" corromprait $3200+$36 = $3236 (DIV3u).
                                       ;   On vise l'orchestrateur (isLastChild,u, inoffensif).
        jsr   HorizontalLoadObject     ; la tete, et elle seule
        ; LA LONGUEUR. Les passagers ne sont plus des objets : la tete les
        ; porte, et le renderer groupe les dessine. Huit segments ne coutent
        ; donc plus qu'UN objet, la ou ils en coutaient huit — c'est ce qui
        ; rend la longueur de la borne payable.
        ; Deux au palier faible, huit au palier fort : c'est ce que donne la
        ; table de routage des slots d'arme de la borne (ES:0x1B80), decodee
        ; dans doc/rebound-laser-plan.md.
        ldb   #RB.MAXSEG-1
        lda   globals.forcepodlevel
        cmpa  #2
        bne   >
        ldb   #1
!       stb   nbPass,x
        ; LES PORTEURS DE BOITE. La borne en arme plusieurs par chaine — les
        ; segments 1 et 5 en horizontal, 1, 4 et 7 en diagonale (0x40:41A0 et
        ; 0x3F5D) ; les autres sont du remplissage visuel. Le segment 1 EST la
        ; tete. Les autres deviennent des objets INVISIBLES : la tete les
        ; dessine deja avec le reste de la chaine, ils ne portent que leur
        ; boite et leur mort.
        ; Rien a armer au palier faible : deux segments, et le second est
        ; desarme chez la borne aussi.
        lda   globals.forcepodlevel
        cmpa  #2
        beq   >
        ldb   #3                       ; segment 5
        jsr   reboundBearer
!       rts

; entree : [x] la tete, [b] l'indice du passager qui portera la boite
; sortie : [x] preserve
reboundBearer
        pshs  b,x
        jsr   LoadObject_x             ; X = le porteur
        beq   reboundBearer.rts
        ldy   1,s                      ; Y = la tete
        lda   #ObjID_forcepod_reboundlaser
        sta   id,x
        lda   #7
        sta   priority,x
        lda   render_flags,y
        sta   render_flags,x
        lda   direction,y
        sta   direction,x
        lda   slotMask,y
        sta   slotMask,x
        ldd   bufferBase,y
        std   bufferBase,x
        sty   parent,x
        lda   ,s                       ; son rang dans la chaine
        sta   childId,x
        lda   routine_secondary,y
        sta   routine_secondary,x
        ldd   x_pos,y                  ; il nait sur la tete et rejoint sa place
        std   x_pos,x                  ;   dans l'anneau des la premiere trame
        ldd   y_pos,y
        std   y_pos,x
        lda   #Rtn_StartLaser
        sta   routine,x
reboundBearer.rts
        puls  b,x,pc

HorizontalLoadObject
        stx   @x
        jsr   LoadObject_x
        beq   >
        ldb   glb.slotsState
        orb   slotMask,u
        stb   glb.slotsState    
        jsr   InitLaserSegment
        lda   #Rtn_RunHorizontalLaser
        sta   routine_secondary,x
        ldd   #Img_reboundlaser_horizontal
        std   image_set,x
        rts
!
        ldx   #0
@x      equ *-2
        inc   isLastChild,x ; assign a last child when no more slots are available
        leas  2,s ; double return to skip following object allocation (no more slots available)
        rts

InitLaserSegment
        lda   #ObjID_forcepod_reboundlaser
        sta   id,x
        ldb   #7
        stb   priority,x
        lda   render_flags,x
        ora   #render_playfieldcoord_mask
        sta   render_flags,x
        lda   direction,u
        sta   direction,x
        lda   slotMask,u
        sta   slotMask,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
        lda   #Rtn_StartLaser
        sta   routine,x
        ldd   parent,u
        std   parent,x ; copy head of laser chain as parent for all children
        ldy   glb.prevSegment ; get previous segment and set new segment as child
        stx   child,y
        stx   glb.prevSegment
        ldd   #0
        std   child,x
        lda   glb.childId
        sta   childId,x
        inc   glb.childId    
        lda   isLastChild,u
        sta   isLastChild,x
        ldd   bufferBase,u
        std   bufferBase,x
        clr   bufferIndex,x
        rts

StartLaser
        lda   routine_secondary,u
        sta   routine,u
        ldd   parent,u
        beq   >
        ; for children — les PORTEURS de boite, les seuls enfants qui restent
        lda   childId,u
        inca
        asla
        adda  #LASER_LIFETIME ; for parent a is implicitely 0
        sta   laserLifetime,u
        lda   #1                       ; le potentiel arcade d'un porteur de
        sta   AABB_0+AABB.p,u          ;   milieu de chaine (la tete a 2)
        _ldd  5,9
        std   AABB_0+AABB.rx,u
        ldb   y_pos+1,u
        stb   AABB_0+AABB.cy,u
        _Collision_AddAABB AABB_0,AABB_list_friend
        jmp   Object ; run the laser now
!
        ; for parent
        lda   #LASER_LIFETIME ; for parent a is implicitely 0
        sta   laserLifetime,u

        ; set hitbox
        lda   #2                       ; set damage potential for this hitbox
        sta   AABB_0+AABB.p,u
        _ldd  5,9                     ; set hitbox xy radius (arcade radius: 12x12px)
        std   AABB_0+AABB.rx,u
        ldb   y_pos+1,u
        stb   AABB_0+AABB.cy,u         ; fixed y position for horizontal laser   
        _Collision_AddAABB AABB_0,AABB_list_friend
        jmp   Object ; run the laser now

DoubleBufferingFlush
        rts

RunHorizontalChildLaser
        ; simplyfied code for childs
        lda   id,x
        cmpa  #ObjID_forcepod_reboundlaser
        lbne  Destroy
        ldb   routine,x
        cmpb  #Rtn_RunHorizontalLaser
        lbne  Destroy
        ldb   laserLifetime,u
        subb  gfxlock.frameDrop.count
        stb   laserLifetime,u
        lbmi  Destroy
        ldb   bufferIndex,x ; get index in the buffer
        lda   childId,u
        asla
        asla  ; *4
        adda  #6 ; start offset for child id 0
        sta   @a
        subb  #0
@a      equ *-1
        andb  #%00011111
        ldx   bufferBase,x  ; get actual position of parent in buffer
        ldd   b,x
        std   x_pos,u
        ; INVISIBLE : la tete le dessine avec le reste de la chaine. Il ne tient
        ; que sa boite — et sa mort.
        lda   AABB_0+AABB.p,u
        lbeq  reboundBearerHit
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u
        rts

RunHorizontalLaser
        ; simplyfied code for childs
        ldx   parent,u
        bne   RunHorizontalChildLaser

        ; check collision potential
        ldb   AABB_0+AABB.p,u
        lbeq  InitExplosion

        ; load buffer base
        ldx   bufferBase,u
        ldb   bufferIndex,u
        leax  b,x
        stx   glb.buffer

        ldb   gfxlock.frameDrop.count
        bne   >                        ; count == 0 (1re boucle apres checkpoint.load) :
        incb                           ; le "dec / bne" ferait 256 tours
!       stb   glb.frameDrop
RunHorizontalLaser.frameDropLoop

        ; update position
        ldx   #HorizontalVelocityPresets
        lda   direction,u
        ldd   a,x
        addd  x_pos,u
        std   x_pos,u
        ldx   glb.buffer
        std   ,x
        std   terrainCollision.sensor.x        

        ; check if the laser is on edge of the screen (right)
        ; if so, skip wall collision
        jsr   isInCollisionRange
        lbeq  RunHorizontalLaser.forward

        ; check for collision with the walls
        ldd   y_pos,u
        std   terrainCollision.sensor.y

        ldb   #1 ; foreground
        jsr   terrainCollision.do
        tstb
        bne   RunHorizontalLaser.rebound
        lda   globals.backgroundSolid
        lbeq  RunHorizontalLaser.forward
        ldb   #0 ; background
        jsr   terrainCollision.do
        tstb
        lbeq  RunHorizontalLaser.forward

RunHorizontalLaser.rebound
        ldb   direction,u
        eorb  #%00000010
        stb   direction,u

RunHorizontalLaser.forward
        ; move to next position in the buffer
        ldb   bufferIndex,u
        addb  #2
        andb  #%00011111
        stb   bufferIndex,u
        ldx   bufferBase,u
        leax  b,x          
        stx   glb.buffer

        dec   glb.frameDrop
        bne   RunHorizontalLaser.frameDropLoop

        ; no collision to walls
        jsr   isInLivingArea
        beq   Destroy
        ; check if the laser is still alive
        ldb   laserLifetime,u
        subb  gfxlock.frameDrop.count
        stb   laserLifetime,u
        lbmi  Destroy  

        ; update hitbox position
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u            

        jmp   reboundmgr.publishChain  ; la tete ET ses passagers, meme chemin

Destroy
        pshs  x                        ; la chaine s'eteint : sans ca ses
        clrb                           ;   passagers resteraient affiches. Un
        ldx   parent,u                 ;   PORTEUR n'emporte que ce qui est
        beq   >                        ;   derriere lui, la tete emporte tout.
        ldb   childId,u
!       jsr   reboundmgr.clearChainFrom
        puls  x
        lda   isLastChild,u
        beq   >
        com   slotMask,u
        ldb   glb.slotsState
        andb  slotMask,u
        stb   glb.slotsState
!
        lda   #Rtn_DoubleBufferingFlush
        sta   routine,u
        lda   AABB_0+AABB.rx,u         ; les porteurs ont une boite eux aussi :
        beq   >                        ;   le test sur parent qui etait ici la
        _Collision_RemoveAABB AABB_0,AABB_list_friend  ; leur faisait fuir
!       jmp   DeleteObject

isInLivingArea
        ; check if the laser is in living range
        ; if not, destroy the laser
        lda   globals.forcepodlevel
        cmpa  #2
        beq   >        
        ; longer laser
        ldd   x_pos,u
        subd  glb_camera_x_pos
        cmpd  #-8*8 ; 20px on arcade: 20x3.75=7.5px
        blt   @false
        cmpd  #144+8*8
        bge   @false
        ldd   y_pos,u
        subd  glb_camera_y_pos
        cmpd  #-15*8 ; 20px on arcade: 20x0.75=15px
        blt   @false
        cmpd  #180+15*8
        bge   @false
@true   lda   #1
        rts
@false  clra
        rts
!       ; shorter laser
        ldd   x_pos,u
        subd  glb_camera_x_pos
        cmpd  #-8*2 ; 20px on arcade: 20x3.75=7.5px
        blt   @false
        cmpd  #144+8*2
        bge   @false
        ldd   y_pos,u
        subd  glb_camera_y_pos
        cmpd  #-15*2 ; 20px on arcade: 20x0.75=15px
        blt   @false
        cmpd  #180+15*2
        bge   @false
        lda   #1
        rts

isInCollisionRange
        ldd   x_pos,u
        subd  glb_camera_x_pos
        cmpd  #8
        blt   @false ; not tested in arcade but we have different behavior in collision testing that make this check mandatory
        cmpd  #144+8-2 ; center of sprite is 2px from the right edge of sprite (similar to arcade)
        bge   @false
        ldd   y_pos,u
        cmpd  #8 ; value set by test ...
        blt   @false ; not tested in arcade but we have different behavior in collision testing that make this check mandatory
        cmpd  #180+18 ; value set by test ...
        bge   @false ; not tested in arcade but we have different behavior in collision testing that make this check mandatory
@true   lda   #1 ; return value
        rts
@false
        lda   AABB_0+AABB.rx,u
        beq   >
        _Collision_RemoveAABB AABB_0,AABB_list_friend
        clr   AABB_0+AABB.rx,u ; flag hitbox as disabled
        ; implicit return value: bit zero set by previous instruction
!       rts

RunDiagonalChildLaser
        ; simplyfied code for childs
        lda   id,x
        cmpa  #ObjID_forcepod_reboundlaser
        lbne   Destroy        
        ldb   routine,x
        cmpb  #Rtn_RunDiagonalLaser
        lbne  Destroy        
        ldb   laserLifetime,u
        subb  gfxlock.frameDrop.count
        stb   laserLifetime,u        
        lbmi  Destroy        
        ldb   bufferIndex,x ; get index in the buffer
        lda   childId,u
        asla
        asla  ; *4
        adda  #6 ; start offset for child id 0
        sta   @a
        subb  #0
@a      equ *-1
        andb  #%00011111
        ldy   bufferBase,x  ; get actual position of parent in buffer
        leay  b,y
        ldd   ,y
        std   x_pos,u
        ldd   32,y
        std   y_pos,u
        lda   AABB_0+AABB.p,u          ; INVISIBLE, cf. le porteur horizontal
        lbeq  reboundBearerHit
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u
        ldb   y_pos+1,u
        stb   AABB_0+AABB.cy,u
        rts

; Un porteur touche. La borne fait disparaitre les segments DERRIERE lui et
; laisse le porteur suivant continuer : on tronque donc la chaine de la tete a
; son rang, on eteint les slots au-dela, et il devient son explosion.
reboundBearerHit
        ldx   parent,u
        lda   childId,u
        cmpa  nbPass,x
        bhs   >
        sta   nbPass,x
!       ldb   childId,u
        jsr   reboundmgr.clearChainFrom
        ldb   #Rtn_RunExplosion
        stb   routine,u
        clr   anim_frame,u
        jmp   RunExplosion

RunDiagonalLaser
        ; simplyfied code for childs
        ldx   parent,u
        bne   RunDiagonalChildLaser

        ; check collision potential
        ldb   AABB_0+AABB.p,u
        lbeq  InitExplosion

        ; load buffer base
        ldx   bufferBase,u
        ldb   bufferIndex,u
        leax  b,x
        stx   glb.buffer

        ldb   gfxlock.frameDrop.count
        bne   >                        ; count == 0 (1re boucle apres checkpoint.load) :
        incb                           ; le "dec / bne" ferait 256 tours
!       stb   glb.frameDrop
RunDiagonalLaser.frameDropLoop

        ; update position
        ldx   #DiagonalVelocityPresets
        ldb   direction,u
        aslb
        abx
        ldd   y_pos,u
        addd  2,x
        std   y_pos,u
        std   terrainCollision.sensor.y
        ldd   x_pos,u
        addd  ,x
        std   x_pos,u
        std   terrainCollision.sensor.x

        ; check if the laser is on edge of the screen (right)
        ; if so, skip wall collision
        jsr   isInCollisionRange
        lbeq  RunDiagonalLaser.forward

        ; check for collision with the walls
        ldd   x_pos,u
        std   terrainCollision.sensor.x
        ldd   y_pos,u
        std   terrainCollision.sensor.y

        ldb   #1 ; foreground
        jsr   terrainCollision.do
        tstb
        bne   RunDiagonalLaser.rebound
        lda   globals.backgroundSolid
        lbeq  RunDiagonalLaser.forward
        ldb   #0 ; background
        jsr   terrainCollision.do
        tstb
        lbeq  RunDiagonalLaser.forward

RunDiagonalLaser.rebound
        ldx   #ReboundPresets
        ldb   direction,u
        aslb                    ; mult by 6
        stb   @b
        aslb
        addb  #0
@b      equ   *-1
        abx
        ldd   x_pos,u
        addd  ,x
        std   terrainCollision.sensor.x
        ldd   y_pos,u
        addd  2,x
        std   terrainCollision.sensor.y
        stx   glb.dataLocation

        ; second collision check
        ldb   #1 ; foreground
        jsr   terrainCollision.do
        tstb
        bne   RunDiagonalLaser.rebound2
        lda   globals.backgroundSolid
        beq   >
        ldb   #0 ; background
        jsr   terrainCollision.do
        tstb
        bne   RunDiagonalLaser.rebound2
!
        ; apply based on first collision only
        ldd   terrainCollision.sensor.x
        std   x_pos,u
        ldd   terrainCollision.sensor.y
        std   y_pos,u
        ldx   glb.dataLocation
        ldd   4,x
        std   image_set,u
        lda   direction,u
        adda  #2
        anda  #%00000111
        sta   direction,u        
        jmp   RunDiagonalLaser.afterCollision

RunDiagonalLaser.rebound2    
        ldx   glb.dataLocation    
        ldd   x_pos,u
        addd  6,x
        std   terrainCollision.sensor.x
        ldd   y_pos,u
        addd  8,x
        std   terrainCollision.sensor.y
        ldb   #1 ; foreground
        jsr   terrainCollision.do
        tstb
        bne   RunDiagonalLaser.reboundBack
        lda   globals.backgroundSolid
        beq   >
        ldb   #0 ; background
        jsr   terrainCollision.do
        tstb
        bne   RunDiagonalLaser.reboundBack
!
        ; apply based on second collision only
        ldd   terrainCollision.sensor.x
        std   x_pos,u
        ldd   terrainCollision.sensor.y
        std   y_pos,u
        ldx   glb.dataLocation
        ldd   10,x
        std   image_set,u
        lda   direction,u
        adda  #6
        anda  #%00000111
        sta   direction,u        
        jmp   RunDiagonalLaser.afterCollision

RunDiagonalLaser.reboundBack
        ldx   glb.dataLocation    
        ldd   terrainCollision.sensor.x
        addd  ,x
        std   x_pos,u
        ldd   terrainCollision.sensor.y
        addd  2,x
        std   y_pos,u
        ldb   direction,u
        addb  #4
        andb  #%00000111
        stb   direction,u

RunDiagonalLaser.forward
        ldx   #DiagonalImages
        lda   direction,u
        ldd   a,x
        std   image_set,u

RunDiagonalLaser.afterCollision

        ; store new position in history buffer
        ldx   glb.buffer
        ldd   x_pos,u
        std   ,x ; store new x position
        ldd   y_pos,u
        std   32,x ; store new y position
        ldd   image_set,u
        std   64,x ; store new image

        ; move to next position in the buffer
        ldb   bufferIndex,u
        addb  #2
        andb  #%00011111
        stb   bufferIndex,u
        ldx   bufferBase,u
        leax  b,x          
        stx   glb.buffer

        dec   glb.frameDrop
        lbne  RunDiagonalLaser.frameDropLoop

        jsr   isInLivingArea
        lbeq  Destroy
        ; check if the laser is still alive
        ldb   laserLifetime,u
        subb  gfxlock.frameDrop.count
        stb   laserLifetime,u
        lbmi  Destroy  

        ; update hitbox position
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u            
        ldb   y_pos+1,u
        stb   AABB_0+AABB.cy,u            
        
        jmp   reboundmgr.publishChain  ; la tete ET ses passagers, meme chemin

InitExplosion
        ; LE SPLIT EST RETIRE (25/08/2026). Il promouvait le troisieme segment
        ; en nouvelle tete — nouveau parent, nouvelle boite, index d'anneau
        ; recule — pour que la moitie arriere de la chaine continue. C'etait une
        ; invention v1 qui APPROXIMAIT les boites de milieu de chaine de la
        ; borne (segments 1 et 5 en horizontal, 1, 4 et 7 en diagonale) avec une
        ; seule boite au depart. La borne ne promeut personne : les passagers
        ; derriere un porteur mort disparaissent, le porteur suivant continue.
        ;
        ; Et il n'a plus de chaine d'OBJETS sur laquelle operer : les passagers
        ; sont des lignes d'anneau depuis que le renderer groupe les dessine.
        ; `ldx child,u` rendait zero et la promotion ecrivait en $0010.
        jsr   reboundmgr.clearChain    ; la chaine s'eteint avec sa tete
        ldb   #Rtn_RunExplosion        ; la tete devient son explosion
        stb   routine,u
        clr   anim_frame,u
        ; please do not change priority here, there is a bug in priority change ...

RunExplosion
        ldx   #ExplosionImages
        ldb   anim_frame,u
        cmpb  #4
        bne   >
        jmp   Destroy
!
        aslb
        ldd   b,x
        std   image_set,u
        inc   anim_frame,u
        jmp   DisplaySprite

ExplosionImages
        fdb   Img_reboundlaser_explosion_0
        fdb   Img_reboundlaser_explosion_1
        fdb   Img_reboundlaser_explosion_2
        fdb   Img_reboundlaser_explosion_3

DiagonalVelocityPresets ; y values are inverted compared to arcade
        fdb   3  ; x velocity for up right
        fdb   -6 ; y velocity for up right
        fdb   3  ; x velocity for down right
        fdb   6  ; y velocity for down right
        fdb   -3 ; x velocity for down left
        fdb   6  ; y velocity for down left
        fdb   -3 ; x velocity for up left
        fdb   -6 ; y velocity for up left

HorizontalVelocityPresets
        fdb   3  ; x velocity for right
        fdb   -3 ; x velocity for left

ReboundPresets
        fdb   0
        fdb   6
        fdb   Img_reboundlaser_angle_0 ; /\
        fdb   -3
        fdb   0
        fdb   Img_reboundlaser_angle_1 ; >
        fdb   -3
        fdb   0
        fdb   Img_reboundlaser_angle_2 ; >
        fdb   0
        fdb   -6
        fdb   Img_reboundlaser_angle_3 ; \/
        fdb   0
        fdb   -6
        fdb   Img_reboundlaser_angle_4 ; \/
        fdb   3
        fdb   0
        fdb   Img_reboundlaser_angle_5 ; <
        fdb   3
        fdb   0
        fdb   Img_reboundlaser_angle_6 ; <
        fdb   0
        fdb   6
        fdb   Img_reboundlaser_angle_7 ; /\

DiagonalImages
        fdb   Img_reboundlaser_diagonal_0 ; right up
        fdb   Img_reboundlaser_diagonal_1 ; right down
        fdb   Img_reboundlaser_diagonal_2 ; left down
        fdb   Img_reboundlaser_diagonal_3 ; left up
