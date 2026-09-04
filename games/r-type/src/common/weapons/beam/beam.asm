; ---------------------------------------------------------------------------
; Object - Beam
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

AABB_0    equ ext_variables ; AABB struct (9 bytes)
halfWidth equ ext_variables+9 ; half width of the beam
impactX   equ ext_variables+11 ; impact x position
imgIdx    equ ext_variables+13 ; image index
beamTier  equ ext_variables+14 ; current power tier 0-4, derived from AABB.p each frame (arcade image_id band)

; temporary estimateddamage : 6,8,10,12,14 (TODO should get the real value from arcade)

Beam
        lda   routine,u
        asla
        ldx   #Beam_Routines
        jmp   [a,x]

; Le depart du pas courant, garde le temps d'un tick pour la boite balayee
; (meme patron que weapon.sweepFrom — un seul beam a la fois dans Live).
beam.sweepFrom fdb 0

Beam_Routines
        fdb   Init
        fdb   Live
        fdb   Impact
        fdb   Delete
        fdb   AlreadyDeleted

Init
; V2-DEVIATION: son neutralise (moteur audio non porte)
;        ;_soundFX.play soundFX.FireBlastSound,2
        ldb   #4
        stb   priority,u
        lda   render_flags,u
        ora   #render_playfieldcoord_mask
        sta   render_flags,u

        _Collision_AddAABB AABB_0,AABB_list_friend
        
        ; hitbox potential
        lda   subtype,u                ; damage potential / penetration budget
	asla
	asla
	adda  #4                       ; arcade: subtype*4+4 = {4,8,12,16,20} (= image_id)
        sta   AABB_0+AABB.p,u

        ; hitbox size — ry seul compte : rx est reecrit par la boite BALAYEE
        ; du premier tick (l'Init tombe dans Live), l'ancien 15 statique etait
        ; la compensation de frame rate, remplacee par le balayage (31/08/2026)
        _ldd  3,6                      ; set hitbox xy radius
        std   AABB_0+AABB.rx,u

        ; compute x position ; spawn tier = subtype (p = subtype*4+4 -> tier = subtype)
        lda   subtype,u
	sta   beamTier,u
	asla
	adda  subtype,u                ; mult by 3
	adda  #3                       ; set hitbox x radius (3 6 9 12 15)
	clr   halfWidth,u
	sta   halfWidth+1,u
	adda  x_pos+1,u
	bcc   >
	inc   x_pos,u
!	sta   x_pos+1,u

        ; compute y position
        ldd   y_pos,u
        addd  #2
        std   y_pos,u
        stb   AABB_0+AABB.cy,u

        ; --- L'ALLUMAGE NETTOIE DEVANT LE CANON (3168..3180)
        ; La borne y pose QUATRE grappes, a +0, +0x0E, +0x1C et +0x2A px
        ; arcade ; chacune fait deux tuiles de large, donc l'ensemble couvre
        ; 0x2A+8 = 50 px arcade, soit 19 chez nous. Un rectangle suffit.
        jsr   beam.gum.arm
        ldx   x_pos,u
        leay  19,x
        ldb   y_pos+1,u
        subb  #3
        lda   #$12                     ; bloc 1 x 2 cellules
        jsr   >0
beam.gum.call equ *-2

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
        ; ET LE PREMIER TICK TOUT DE SUITE — on TOMBE dans Live entier (meme
        ; geste que le tir simple) : rattrapage du frame drop des la trame de
        ; naissance, boite balayee de la position initiale a la position
        ; rattrapee. L'ancien `bra >` sautait le deplacement.

Live
        ; LE DERNIER COUP S'AFFICHE — meme retour que le tir simple : quand le
        ; budget de penetration tombe a zero dans la passe, le beam finissait
        ; en Delete muet ; il pose desormais son impact a la position courante.
        lda   AABB_0+AABB.p,u
        lbeq  beam.HitFeedback

        ; current power tier (arcade image_id band): tier = (p-1)>>2 -> {1..4}=0 ... {17..20}=4
        deca
        lsra
        lsra
        sta   beamTier,u                ; reused for the sprite below
        ; halfWidth = tier*3+3 (3 6 9 12 15) - shrinks with the beam (wall-rebound offset)
        asla
        adda  beamTier,u
        adda  #3
        clr   halfWidth,u
        sta   halfWidth+1,u

        ; --- LE SILLAGE : le beam CREUSE le champ, il n'y meurt pas
        ; 31D9 etape 6 : chaque tick, la borne efface CX grappes en avancant
        ; d'une cellule par grappe — une bande de deux rangees sur CX+1
        ; colonnes, refaite a chaque tick, AVANT de sonder le decor dur. C'est
        ; cet ordre qui fait le tunnel : les gommes ne l'arretent jamais.
        ;
        ; Notre compensation ne coute rien. Le beam avance d'UNE cellule par
        ; tick (8 px arcade = une tuile = nos 3 px = une cellule) alors que sa
        ; bande en fait six a onze : deux bandes consecutives se recouvrent a
        ; une colonne pres, donc la reunion de N bandes est UNE bande, allongee
        ; de N colonnes. On la demande d'un seul coup, du x d'avant le
        ; deplacement au bout de la portee — un appel par trame, quel que soit
        ; le frame drop, sans boucle de rattrapage ni division.
        ;
        ; V2-DEVIATION: la borne pose aussi une demande de son a chaque cellule
        ; effacee (SFX 0x5E, une fois par trame quel qu'en soit le nombre —
        ; 0x40:027A). Le moteur audio n'est pas porte : rien ici. Ce n'est PAS
        ; du score, verifie sur la plate de erase_green_ball_cell_stage4.
        ldx   x_pos,u
        stx   beam.sweepFrom           ; le depart du pas : la boite balayee
        pshs  x                        ; le depart, avant le deplacement

        ; update beam position
        lda   #3
        ldb   gfxlock.frameDrop.count
        mul
        addd  x_pos,u
        addd  glb_camera_x_pos
        subd  glb_camera_x_pos_old
        std   x_pos,u

        jsr   beam.gum.arm
        ldb   beamTier,u               ; la portee, en px : 3 * le nombre de
        ldx   #beam.gum.reach.tbl      ; grappes de la borne
        abx
        ldb   ,x
        clra
        addd  x_pos,u
        tfr   d,y                      ; l'arrivee
        puls  x                        ; le depart
        ldb   y_pos+1,u
        subb  #3                       ; 2736 : la grappe est sondee 4 px
                                       ; arcade plus haut, 3 lignes chez nous
        lda   #$12                     ; bloc 1 x 2 : la hauteur de la grappe
        jsr   >0
beam.gum.call2 equ *-2
!
        ; check wall collision
        ldd   impactX,u
        beq   >
        subd  halfWidth,u ; check collision on the right side
        cmpd  x_pos,u
        bhi   >
        jsr   RandomNumber
        clra
        andb  #%00000011
        _negd
        subd  #3 ; half width of the beam
        addd  impactX,u
        std   x_pos,u
        ; LA TRAME D'IMPACT GARDE SA BOITE BALAYEE — du depart du pas au point
        ; d'impact, largeur du beam comprise. Meme correctif que le tir simple :
        ; la branche court-circuitait la pose de boite, un beam ne a moins d'un
        ; pas du mur ne touchait rien du segment traverse (l'orbe du gomander).
        ; LA BOITE PAR SES BORDS (04/09/2026) — voir le site en vol plus bas.
        ldd   beam.sweepFrom
        subd  glb_camera_x_pos
        addd  halfWidth,u              ; l'arriere : la frontiere avant d'avant le pas
        tfr   d,x
        ldd   x_pos,u
        subd  glb_camera_x_pos
        addd  halfWidth,u              ; l'avant : le point d'impact
        leay  AABB_0,u
        jsr   AABB.spanX
        ldd   #set_beam_impact_0
        std   image_set,u
        inc   routine,u
        jmp   DisplaySprite
!
        ; update hitbox position — LA BOITE BALAYEE, PAR SES BORDS (voir le
        ; tir simple) : de la frontiere avant de la trame precedente (x d'avant
        ; le pas + demi-largeur du tier) a la frontiere courante, les deux
        ; calees dans l'octet par AABB.spanX. Un beam qui penetre y gagne
        ; double : la boite large du segment peut toucher PLUSIEURS ennemis
        ; dans la meme passe, comme l'arcade.
        ldd   beam.sweepFrom
        subd  glb_camera_x_pos
        addd  halfWidth,u              ; l'arriere : la frontiere avant d'avant le pas
        tfr   d,x
        ldd   x_pos,u
        subd  glb_camera_x_pos
        cmpd  #160-8/2                 ; delete beam if out of screen range
        bhs   Delete
        addd  halfWidth,u              ; l'avant : la frontiere courante
        leay  AABB_0,u
        jsr   AABB.spanX
        ldb   beamTier,u                ; sprite tier = current power band (arcade unified image_id)
        aslb
        ldx   #Ani_Beams
        ldx   b,x
        ldb   imgIdx,u
        incb
        andb  #%00000001
        stb   imgIdx,u
        aslb
        ldd   b,x
        std   image_set,u
        jmp   DisplaySprite

beam.HitFeedback
        ldd   #set_beam_impact_0
        std   image_set,u
        inc   routine,u                ; Live -> Impact : la fin d'anim commune
        jmp   DisplaySprite

Impact
        inc   routine,u
        ldd   #set_beam_impact_4
        std   image_set,u
        jmp   DisplaySprite

Delete 
        lda   #4 ; do not use inc here, it will lead to a bug.
        sta   routine,u
        _Collision_RemoveAABB AABB_0,AABB_list_friend
        jmp   DeleteObject

AlreadyDeleted
        rts ; once deleted, the object can be called again for double buffering update.

; Le crochet de couche destructible est un VECTEUR pose par le stage (il n'y a
; de gommes qu'au stage 4, et ce code-ci sert les huit). Son entree +6 est
; l'effacement en rectangle ; on l'installe dans les deux appels avant de
; charger les parametres, qui occupent A, B, X et Y a eux seuls.
beam.gum.arm
        ldd   stage.gum.hook
        addd  #6
        std   beam.gum.call
        std   beam.gum.call2
        rts

; green_ball_sweep_count_table (0x1000:183E), lue aux cinq paliers que le beam
; peut prendre : 5, 5, 6, 6, 7 grappes. Une grappe par cellule d'avance, donc
; la portee en px vaut trois fois ce nombre.
beam.gum.reach.tbl
        fcb   15,15,18,18,21

Ani_Beams
        fdb   Ani_beam0
        fdb   Ani_beam1
        fdb   Ani_beam2
        fdb   Ani_beam3
        fdb   Ani_beam4

Ani_beam0
        fdb   set_beam0_1
        fdb   set_beam0_0

Ani_beam1
        fdb   set_beam1_1
        fdb   set_beam1_0

Ani_beam2
        fdb   set_beam2_1
        fdb   set_beam2_0

Ani_beam3
        fdb   set_beam3_1
        fdb   set_beam3_0

Ani_beam4
        fdb   set_beam4_1
        fdb   set_beam4_0
