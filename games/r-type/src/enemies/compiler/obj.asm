; ---------------------------------------------------------------------------
; Compiler — le boss du stage 4
;
; input REG : [u] pointer to Object Status Table (OST)
; ---------------------------------------------------------------------------
;
; FICHE DE PORTAGE — BLOC 1 : l'orchestrateur et les trois parties
; ================================================================
; arcade : create_compiler 0x40:A71D, tick_compiler_init_segments 0x40:A762,
;          tick_compiler_combat_monitor 0x40:A982, motion_step 0x40:AFE6
; donnees : compiler_variant_slot_table 0x1000:5ABA (8 variantes),
;           compiler_shared_base_motion_script 0x1000:5B54 (l'intro)
;
; CE QUE FAIT LA BORNE, ET CE QUE CE BLOC EN PORTE
; ------------------------------------------------
; Le boss est un vaisseau-mere en TROIS PARTIES MOBILES (droite, bas,
; gauche) qui naissent AU MEME POINT et paraissent d'abord assemblees en une
; seule silhouette — leurs sprites ont des ancres differentes, c'est ce qui
; les emboite. Elles derivent ensemble pendant l'intro, puis chacune part sur
; ses propres scripts.
;
; BLOC 1 (ici) : l'orchestrateur, les trois parties, et l'INTRO — le script
;   partage 0x5B54, un seul segment : vx = +1 px/trame arcade pendant 0x160
;   trames (~5,9 s), vy nul. C'est tout ce qui bouge a ce stade.
; BLOCS SUIVANTS (a venir) : les armes (le laser horizontal de la partie
;   droite, les trois tourelles), les scripts de combat (9 au total, tires
;   par la variante), les PV et la mort en cascade, l'auto-destruction.
;
; ECARTS ASSUMES
; --------------
; V2-DEVIATION: la variante est tiree au sort parmi 8 chez elle
;   ((random + player_x + player_y) & 7) et ne change que l'ORDRE des scripts
;   de combat. Sans scripts de combat, ce bloc n'en a pas besoin : la
;   variante viendra avec eux.
; V2-DEVIATION: pas de selecteur de difficulte en v2 — la cadence d'attaque
;   par difficulte (0x1000:5844) prendra sa premiere valeur, comme le reste
;   du cast.
; ---------------------------------------------------------------------------

AABB_0        equ ext_variables      ; AABB struct (9 bytes)
cpl.part      equ ext_variables+9    ; 0 = droite, 1 = bas, 2 = gauche
cpl.timer     equ ext_variables+10   ; WORD : trames restantes du segment
cpl.vx        equ ext_variables+12   ; WORD : la vitesse du segment (8.8)
; --- l'oscillateur du dome, porte par l'ORCHESTRATEUR (un seul, pas trois) ---
cpl.dome.step equ ext_variables+14     ; l'index dans cpl.dome.seq
cpl.dome.left equ ext_variables+15     ; trames restantes sur cette etape
; Le laser reutilise les cases de la partie : un slot ne porte jamais les deux.
cpl.laser.vx  equ cpl.vx               ; WORD : sa vitesse (8.8), vers la gauche

Object
        lda   routine,u
        asla
        ldx   #Routines
        jmp   [a,x]

Routines
        fdb   BossInit
        fdb   BossWatch
        fdb   PartInit
        fdb   PartLive
        fdb   AlreadyDeleted
        fdb   LaserInit
        fdb   LaserFly

; ---------------------------------------------------------------------------
; BossInit — A762 : l'orchestrateur engendre ses trois parties
;
; Un seul passage. La borne engendre aussi trois tourelles et pose les PV,
; la cadence et le masque de mort ; tout cela vient avec les blocs suivants.
; Elle n'affiche RIEN elle-meme : ce sont les parties qu'on voit.
; ---------------------------------------------------------------------------
BossInit
        ldb   #3                       ; les trois parties, dans l'ordre
        stb   cpl.part,u               ;   arcade : droite, bas, gauche
@spawn  ldb   cpl.part,u
        decb
        stb   cpl.part,u
        jsr   LoadObject_x             ; un slot pour la partie
        beq   @done                    ; pool plein : le boss sera partiel,
                                       ; comme la borne (elle court-circuite
                                       ; aussi vers le moniteur de combat)
        lda   #ObjID_compilerpart
        sta   id,x
        ldb   cpl.part,u
        stb   subtype_w+1,x            ; la partie que ce slot represente
        ; FIX #1 : le fils partage le dispatch de l'orchestrateur, son etat de
        ; depart doit donc etre POSE — un slot frais a routine=0, c'est-a-dire
        ; BossInit : chaque partie re-engendrait trois parties jusqu'a saturer
        ; le pool, et aucune n'atteignait PartInit (aucun sprite a l'ecran).
        lda   #2                       ; -> PartInit
        sta   routine,x
        ; A768 : les trois naissent AU MEME POINT — ce sont les ancres de
        ; leurs sprites qui les emboitent en une silhouette.
        ldd   #cpl.SPAWN_X
        addd  glb_camera_x_pos
        std   x_pos,x
        ldd   #cpl.SPAWN_Y
        std   y_pos,x
        tst   cpl.part,u
        bne   @spawn
@done   lda   #1                       ; -> BossWatch
        sta   routine,u
        ; L'oscillateur part au repos (etape 0), et pose ses couleurs des
        ; cette trame : la palette du combat vient d'etre echangee, son etape 0
        ; en est deja la valeur — mais la poser ici rend l'orchestrateur seul
        ; maitre du dome, quel que soit l'ordre d'arrivee.
        clr   cpl.dome.step,u
        clr   cpl.dome.left,u
        bra   cpl.dome.tick

; ---------------------------------------------------------------------------
; BossWatch — A982 : le moniteur de combat
;
; BLOC 1 : il ne fait encore que l'OSCILLATION DU DOME. La borne y compte les
; trois drapeaux de mort et arme la sequence finale quand les trois tombent ;
; cela vient avec le bloc « degats et mort ».
; ---------------------------------------------------------------------------
BossWatch
cpl.dome.tick
        lda   cpl.dome.left,u
        suba  gfxlock.frameDrop.count  ; le decompte suit l'horloge de jeu
        bhi   @garde                   ; l'etape court toujours
        ; --- etape suivante ---------------------------------------------
        ldb   cpl.dome.step,u
        incb
        cmpb  #cpl.dome.CYCLE
        blo   >
        clrb                           ; le ping-pong reboucle
!       stb   cpl.dome.step,u
        aslb                           ; deux octets par entree : etape, duree
        ldx   #cpl.dome.seq
        abx
        lda   1,x                      ; la duree de la nouvelle etape
        sta   cpl.dome.left,u
        ; --- poser les trois couleurs -----------------------------------
        ; Les cases MATERIELLES 12, 13, 14 sont consecutives et reservees a
        ; nous seuls (arcade_to_sprites --reserver) : trois mots d'affilee
        ; dans Pal_buffer, a l'offset 12*2. C'est tout le cout de l'effet.
        ldb   ,x                       ; l'etape a jouer
        lda   #6                       ; trois mots par etape
        mul                            ; d = etape * 6
        ldx   #cpl.dome.pal
        leax  d,x
        ; U PORTE L'OST : on ne l'ecrase qu'ici, quand plus aucune variable
        ; d'objet n'est a lire, et on le rend avant de sortir.
        pshs  u
        ldu   #Pal_buffer+12*2         ; la premiere des trois cases
        ldy   ,x++
        sty   ,u++
        ldy   ,x++
        sty   ,u++
        ldy   ,x
        sty   ,u
        puls  u
        clr   PalRefresh               ; PalUpdateNow les posera cette trame
        rts
@garde  sta   cpl.dome.left,u
        rts

; ---------------------------------------------------------------------------
; PartInit — A76E : une partie, posee et armee sur le script d'intro
; ---------------------------------------------------------------------------
PartInit
        lda   subtype_w+1,u
        sta   cpl.part,u
        clr   x_sub,u
        clr   y_sub,u
        ; 5B54 : le script d'intro, un seul segment — vx = +1 px/trame
        ; arcade (0,375 px v2), vy nul, pendant 0x160 trames.
        ldd   #cpl.INTRO_VX
        std   cpl.vx,u
        ldd   #cpl.INTRO_DUR
        std   cpl.timer,u
        ; l'image de CETTE partie : une pose chacune, la silhouette est faite
        ; de leur assemblage
        ldb   cpl.part,u
        aslb
        ldx   #cpl.images
        abx
        ldd   ,x
        std   image_set,u
        ldb   #4                       ; priorite : devant le fond, derriere
        stb   priority,u               ;   le vaisseau
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        inc   routine,u                ; -> PartLive
        lbra  PartLive.draw

; ---------------------------------------------------------------------------
; PartLive — AFE6 (motion_step) : la derive du segment courant
;
; BLOC 1 : le seul segment est celui de l'intro. Quand son compte tombe, la
; partie s'immobilise — la borne enchainerait sur les scripts de combat.
; ---------------------------------------------------------------------------
PartLive
        ldd   cpl.timer,u
        lbeq  PartLive.draw            ; segment epuise : immobile (bloc 1)
        ldb   gfxlock.frameDrop.count  ; le decompte suit l'horloge de jeu
        clra
        pshs  d
        ldd   cpl.timer,u
        subd  ,s++
        bhi   >
        ldd   #0                       ; le segment est fini
!       std   cpl.timer,u
        ; le pas du segment, compense par le frame drop
        ldb   cpl.vx+1,u
        lda   gfxlock.frameDrop.count
        mul
        jsr   moveXPos8.8
; FIX #2 : NE DESSINER QU'ENTIER A L'ECRAN. Les sprites compiles ne clippent
; pas — l'arcade spawne a x ecran -16 et laisse son MATERIEL rogner, nous
; n'avons pas ce luxe : le dessin partiel d'une piece de 66 px a -16 ecrivait
; hors du champ et CORROMPAIT la RAM residente (pscroll.res, atteste par
; l'anneau de trace : pscroll.do saute en $0050 des le spawn du boss, machine
; figee — le « gel a la camera 929 » des essais precedents, qui etait en fait
; le gel A L'HEURE DE WAVE DU BOSS). Pendant la derive d'intro, chaque piece
; apparait quand son bord gauche franchit le bord de l'ecran ; sa position
; finale (x = 116) est entiere a l'ecran.
; ---------------------------------------------------------------------------
; cpl.fire — AB01 (droite) / ADFB (gauche) : la salve de lasers horizontaux
; ---------------------------------------------------------------------------
; La borne decide a chaque trame, pour la partie droite comme pour la gauche :
;   - le joueur doit etre A DROITE de la piece (elle tire vers la gauche) ;
;   - il doit etre dans une fenetre verticale, comptee depuis la piece :
;     0..0x50 px arcade pour la droite, 0..0x30 pour la gauche — la piece
;     gauche vise plus serre ;
;   - un compteur de cadence doit tomber a zero ; il se recharge alors depuis
;     la valeur de difficulte (nous prenons la premiere, comme tout le cast).
; Le laser nait devant la piece (+0x50 px arcade a droite, +0x10 a gauche,
; donc DANS le corps) a une hauteur tiree d'un pool de huit offsets, et part
; vers la gauche a 3 px/trame arcade.
; ---------------------------------------------------------------------------
cpl.fire
        lda   cpl.timer+1,u            ; la cadence (l'octet bas suffit)
        suba  gfxlock.frameDrop.count
        bhi   @wait
        ; --- le joueur est-il devant, et dans la fenetre ? ---------------
        ldd   player1+x_pos
        subd  x_pos,u
        bmi   @rearm                   ; il est DERRIERE la piece
        ldd   player1+y_pos
        subd  y_pos,u
        addd  #cpl.FIRE_WINY0
        bmi   @rearm                   ; au-dessus de la fenetre
        ldb   cpl.part,u
        cmpb  #2                        ; 2 = la piece GAUCHE, fenetre serree
        beq   @gauche
        cmpd  #cpl.FIRE_WINY_R
        bra   @teste
@gauche cmpd  #cpl.FIRE_WINY_L
@teste  bhi   @rearm                   ; sous la fenetre
        bsr   cpl.laser.spawn
@rearm  lda   #cpl.FIRE_PERIOD         ; le compteur se recharge
@wait   sta   cpl.timer+1,u
        rts

; ---------------------------------------------------------------------------
; cpl.laser.spawn — AB3A : un laser, devant la piece, a hauteur tiree
; ---------------------------------------------------------------------------
cpl.laser.spawn
        jsr   LoadObject_x
        beq   @none                    ; pool plein : pas de tir, la borne
                                       ; renonce aussi
        lda   #ObjID_compilerlaser
        sta   id,x
        lda   #5                       ; -> LaserInit
        sta   routine,x
        ; la hauteur : un des huit offsets du pool de la piece
        jsr   RandomNumber
        andb  #7
        aslb
        ldy   #cpl.laser.poolR
        lda   cpl.part,u
        cmpa  #2
        bne   >
        ldy   #cpl.laser.poolL         ; la piece gauche a son propre pool
!       ldd   b,y
        addd  y_pos,u
        std   y_pos,x
        ; l'avance : devant la piece a droite, dans le corps a gauche
        ldd   #cpl.FIRE_AHEAD_R
        lda   cpl.part,u
        cmpa  #2
        bne   >
        ldd   #cpl.FIRE_AHEAD_L
!       addd  x_pos,u
        std   x_pos,x
        clr   x_sub,x
        clr   y_sub,x
@none   rts

PartLive.draw
        ldb   cpl.part,u
        ldx   #cpl.halfw
        abx
        ldb   ,x                       ; la demi-largeur de CETTE piece
        clra
        pshs  d
        ldd   x_pos,u
        subd  glb_camera_x_pos         ; x ecran du centre
        subd  ,s                       ; le bord gauche depasse ?
        bmi   @hide
        addd  ,s
        addd  ,s++                     ; le bord droit depasse ?
        cmpd  #cpl.SCREEN_W
        bhi   @hide2
        jmp   DisplaySprite
@hide   leas  2,s
@hide2  rts

; ---------------------------------------------------------------------------
; LaserInit / LaserFly — E6AB : le laser horizontal du Compiler
; ---------------------------------------------------------------------------
; Il vole vers la GAUCHE a vitesse constante, cycle sur quatre poses, et tue
; le joueur au contact (la borne pose player_one_die_flag). Il ne rebondit
; pas, ne vise pas : c'est un rideau que le joueur doit eviter.
; V2-DEVIATION : pas de selecteur de difficulte — on prend la premiere entree
; de la table de vitesses (0x1000:5848), comme tout le cast.
; ---------------------------------------------------------------------------
LaserInit
        ldd   #cpl.LASER_VX
        std   cpl.laser.vx,u
        ldb   #3                       ; devant le decor, derriere le vaisseau
        stb   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        _Collision_AddAABB AABB_0,AABB_list_ennemy
        lda   #compilerlaser_hitdamage
        sta   AABB_0+AABB.p,u
        _ldd  compilerlaser_hitbox_x,compilerlaser_hitbox_y
        std   AABB_0+AABB.rx,u
        inc   routine,u                ; -> LaserFly
LaserFly
        ; il avance, puis se montre — l'ordre de la borne
        ldb   cpl.laser.vx+1,u
        lda   gfxlock.frameDrop.count
        mul
        _negd                          ; vers la gauche
        jsr   moveXPos8.8
        ; quatre poses, deux trames chacune (frame_duration 2 au catalogue)
        lda   gfxlock.frame.count+1
        lsra
        anda  #3
        asla
        ldx   #cpl.laser.images
        ldd   a,x
        std   image_set,u
        ; sorti par la gauche ? le laser ne revient jamais
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u
        addd  #compilerlaser_hitbox_x
        bmi   @gone
        ldd   y_pos,u
        stb   AABB_0+AABB.cy,u
        jmp   DisplaySprite
@gone   lda   #4                       ; -> AlreadyDeleted
        sta   routine,u
        _Collision_RemoveAABB AABB_0,AABB_list_ennemy
        jmp   DeleteObject

AlreadyDeleted
        rts
