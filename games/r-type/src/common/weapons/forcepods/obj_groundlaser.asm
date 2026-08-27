; ---------------------------------------------------------------------------
; Object - Ground laser (le laser JAUNE, « counter-ground »)
;
; input REG : [u] pointer to Object Status Table (OST)
; ---------
;       subtype : bit 0 => 0 = faisceau A, 1 = faisceau B
;                 bit 1 => 1 = pod amarre a l'ARRIERE (echange les mains)
;
; Portage arcade — pas de source v1, le stage 1 ne donne jamais ce cristal.
; Releve : doc/ground-laser-arcade.md, plan : doc/ground-laser-plan.md.
; Routines arcade : create_ground_laser 0x40:4763, run_ground_laser 0x40:47c9.
;
; C'EST UN SUIVEUR DE MUR. Deux faisceaux partent du pod, l'un vers le HAUT
; l'autre vers le BAS ; au contact du decor, l'un tourne dans le sens horaire
; et l'autre dans le sens anti-horaire. L'un longe donc le plafond, l'autre le
; sol, et les deux progressent vers la droite en epousant le relief. Amarrer le
; pod a l'arriere ajoute 4 a la rotation, ce qui echange les mains.
;
; ETAPE 3 du plan : la tete marche (etape 1), porte sa chaine (etape 2 — un
; anneau de positions ecrit par tick, des suiveurs echelonnes de deux ticks,
; le renderer groupe de groundmgr.asm), et MEURT comme la borne (etape 3) :
; une boite AABB sur la tete seule, potentiel 2/4 selon le palier, et quand
; il est draine la vague d'explosion remonte la chaine — quatre images a
; rebours, une cellule par trame. Trois OST par volee : deux tetes et le
; renderer.
; ---------------------------------------------------------------------------

AABB_0        equ ext_variables      ; AABB struct (9 bytes)
gl_dir        equ ext_variables+9    ; 1 octet - direction de marche 0/2/4/6
gl_rot        equ ext_variables+10   ; 1 octet - rotation 0/2/4/6
gl_life       equ ext_variables+11   ; 1 octet - trames restantes
gl_camx       equ ext_variables+12   ; 2 octets - camera x a la trame precedente
gl_camy       equ ext_variables+14   ; 2 octets - camera y a la trame precedente
gl_ridx       equ ext_variables+16   ; 1 octet - prochaine entree d'anneau (0..15)
gl_fill       equ ext_variables+17   ; 1 octet - entrees ecrites (sature a 16)

GL_LIFETIME   equ 112                ; arcade 0x70, identique au laser rebond
GL_POWER_LOW  equ 2                  ; potentiel de la tete, palier 2 (arm _a)
GL_POWER_HIGH equ 4                  ; palier 3 (arm _b) — la SEULE difference

Rtn_Spawn          equ 0
Rtn_Init           equ 1
Rtn_Live           equ 2
Rtn_AlreadyDeleted equ 3
Rtn_Render         equ 4             ; le renderer groupe (groundmgr.asm)
Rtn_Explode        equ 5             ; la vague d'explosion, tete vers queue

Object
        lda   routine,u
        asla
        ldx   #Routines
        jmp   [a,x]

Routines
        fdb   Spawn
        fdb   Init
        fdb   Live
        fdb   AlreadyDeleted
        fdb   Render
        fdb   Explode

; ---------------------------------------------------------------------------
; Spawn — le premier tour du faisceau A, qui met aussi le B au monde
;
; La borne n'a rien a decider ici : ses douze cellules ont des slots dedies, et
; la cellule 1 verifie que les sept suivantes sont libres avant d'armer la
; chaine. Chez nous les slots viennent du pool commun, donc on reconstruit
; l'equivalent en balayant la liste d'objets — le geste que le laser rebond a
; du apprendre : un compteur pose/leve reste colle des qu'un objet disparait
; autrement que par sa mort normale (mort du joueur, ManagedObjects_ClearAll,
; pool sature), et l'arme ne repart jamais.
; ---------------------------------------------------------------------------
Spawn
        clr   gl.renderLive
        ldx   object_list_first
        beq   @free
@sloop  cmpx  #0
        beq   @free
        lda   id,x
        cmpa  #ObjID_forcepod_groundlaser
        bne   @snext
        lda   routine,x
        beq   @snext                 ; 0 = Spawn : nous-meme, ou un jumeau du meme tour
        cmpa  #Rtn_Render            ; le renderer ne bloque pas la volee, mais
        bne   @notrender             ;   on note qu'il vit : en creer un second
        inc   gl.renderLive          ;   dessinerait les douze slots en double
        bra   @snext
@notrender
        cmpa  #Rtn_AlreadyDeleted
        blo   gl.busy                  ; une tete vit encore : pas de nouvelle volee
@snext  ldx   run_object_next,x
        bne   @sloop
@free
        lda   subtype,u
        anda  #$fe                   ; nous : le faisceau A
        sta   subtype,u
        pshs  a
        ; le jumeau : meme cote de pod, autre faisceau. Il part a Init et non a
        ; Spawn, sans quoi il balayerait la liste, nous y trouverait et se
        ; supprimerait aussitot.
        jsr   LoadObject_x
        beq   @alone                 ; pool plein : le faisceau A part seul
        lda   #ObjID_forcepod_groundlaser
        sta   id,x
        lda   ,s
        ora   #1                     ; bit 0 = faisceau B
        sta   subtype,x
        lda   #Rtn_Init
        sta   routine,x
@alone  leas  1,s
        ; les slots de la volee precedente sont morts avec elle (une volee
        ; exige les deux tetes mortes) : on les eteint avant d'y republier
        jsr   groundmgr.reset
        ; le troisieme OST : celui qui dessinera les cellules des deux chaines
        ; — un seul, et pas un de plus (cf. gl.renderLive plus haut)
        lda   gl.renderLive
        bne   >
        jsr   LoadObject_x
        beq   >                      ; pool plein : les tetes marcheront sans dessin
        lda   #ObjID_forcepod_groundlaser
        sta   id,x
        lda   #Rtn_Render
        sta   routine,x
!       ; on tombe dans Init — la tete A demarre du meme tour
        bra   Init

gl.busy jmp   DeleteObject

gl.renderLive fcb 0

; ---------------------------------------------------------------------------
; Init — la naissance d'une tete
; ---------------------------------------------------------------------------
Init
        lda   #Rtn_Live
        sta   routine,u
        ldb   #4
        stb   priority,u
        lda   render_flags,u
        ora   #render_playfieldcoord_mask
        sta   render_flags,u
        lda   #GL_LIFETIME
        sta   gl_life,u

        ; La rotation : le faisceau (bit 0) donne 0 ou 2, l'amarrage arriere
        ; (bit 1) ajoute 4. C'est le geste de create_ground_laser, qui lit
        ; force_pod_position_flag et fait +4.
        lda   subtype,u
        anda  #1
        asla                          ; bit 0 -> rotation 0 ou 2
        pshs  a
        lda   subtype,u
        anda  #2
        asla                          ; bit 1 -> +4
        adda  ,s+
        sta   gl_rot,u

        ; La direction de depart est celle que porte l'entree de rotation.
        ldb   gl_rot,u
        aslb
        ldx   #gl.rotation
        abx
        lda   GL_START,x
        sta   gl_dir,u

        ; Le point de depart se lit sur le JOUEUR, pas sur l'OST du pod : c'est
        ; ce que font le counter-air et le rebond (`ldd player1+x_pos`), et le
        ; pod accroche vaut le vaisseau a +/-9 pres. Lire forcepodOST donnait
        ; une position fausse — le faisceau naissait 50 px trop haut.
        ldd   player1+x_pos
        ldx   #9
        tst   player1+forcepod_mount_side
        beq   >
        ldx   #-9
!       leax  d,x
        stx   x_pos,u
        ldd   player1+y_pos
        std   y_pos,u

        ; CALAGE SUR LA GRILLE de collision 3x6, comme la borne se cale sur sa
        ; grille de 8 px (`AND 0xFFF8` puis +2). Sans lui la marche vit a un
        ; offset de cellule arbitraire et les cellules de la chaine ne se
        ; joignent pas. Meme idiome que l'orchestrateur du rebond : DIV3u/DIV6u
        ; ecrivent le quotient DANS le champ, on le retriple ensuite.
        leax  x_pos,u
        jsr   DIV3u
        addd  x_pos,u
        addd  x_pos,u
        std   x_pos,u
        leax  y_pos,u
        jsr   DIV6u
        addd  y_pos,u
        addd  y_pos,u
        lslb
        rola
        addd  #1                     ; le dedans de la cellule, comme le rebond
        std   y_pos,u

        ; l'anneau demarre vide
        clr   gl_ridx,u
        clr   gl_fill,u

        ; La camera d'aujourd'hui, pour mesurer son delta a chaque trame.
        ldd   glb_camera_x_pos
        std   gl_camx,u
        ldd   glb_camera_y_pos
        std   gl_camy,u

        ; Refus de naitre dans un mur, comme la borne : elle sonde son centre
        ; des le premier tour et se decharge si c'est solide.
        jsr   gl.probeHere
        bne   gl.wall

        ; LA BOITE — la tete seule en porte une (decision auteur, fidelite
        ; arcade). Rayons (5,9) comme le rebond (extents arcade 12x12,
        ; `0x21D4`), et le potentiel de la table de routage : 2 au palier 2,
        ; 4 au palier 3 — le `+0x17`, seule difference entre les deux
        ; routines d'armement de la borne.
        ;
        ; ELLE N'ENTRE DANS AUCUNE LISTE : la tete confronte elle-meme sa
        ; boite aux ennemis, a chaque pas de sa marche — voir gl.hitEnemies,
        ; qui explique pourquoi. Rien n'est perdu : la passe globale ne
        ; confronte AABB_list_friend qu'a AABB_list_ennemy, exactement le
        ; travail repris ici. La passe s'en trouve meme allegee.
        lda   #GL_POWER_LOW
        ldb   globals.forcepodlevel
        cmpb  #3
        bne   >
        lda   #GL_POWER_HIGH
!       sta   AABB_0+AABB.p,u
        _ldd  5,9
        std   AABB_0+AABB.rx,u
        rts
gl.wall jmp   DeleteObject

; ---------------------------------------------------------------------------
; Live — la camera, puis la marche une fois par TICK, puis le dessin
;
; La compensation de frame-drop rejoue le pas `gfxlock.frameDrop.count` fois :
; a bas regime le faisceau avance d'autant de cellules qu'il aurait avancees
; de trames, et sa forme ne depend pas de la cadence.
;
; SUIVRE LA CAMERA, comme la borne (`pos += scroll_amount`, avant le pas) :
; ses cellules restent collees a l'ECRAN, le defilement les emporte. Nos
; coordonnees sont playfield — sans le delta camera le faisceau resterait sur
; place dans la CARTE et deriverait vers la gauche de l'ecran. (Un premier
; jet affirmait l'inverse, « le defilement est deja dans le rendu » : c'est
; vrai du dessin, pas du mouvement.) Le delta se mesure sur la position
; gardee en OST, ce qui absorbe aussi les trames sautees.
; ---------------------------------------------------------------------------
Live
        ; Ceinture : le potentiel ne peut plus tomber a zero ailleurs que dans
        ; la boucle ci-dessous (la boite n'est dans aucune liste, personne
        ; d'autre n'y touche), et la boucle explose alors sur place. Cette
        ; garde ne sert donc qu'a rattraper un potentiel arrive a zero par un
        ; chemin imprevu, plutot que de laisser marcher un faisceau mort.
        lda   AABB_0+AABB.p,u
        lbeq  gl.boom

        ldd   glb_camera_x_pos
        subd  gl_camx,u
        addd  x_pos,u
        std   x_pos,u
        ldd   glb_camera_x_pos
        std   gl_camx,u
        ldd   glb_camera_y_pos
        subd  gl_camy,u
        addd  y_pos,u
        std   y_pos,u
        ldd   glb_camera_y_pos
        std   gl_camy,u

        ; l'anneau de CETTE tete, choisi une fois pour la trame. Ce choix a
        ; coute DEUX bugs, un par forme :
        ;   - par D : `lda subtype,u` apres `ldd #ringA` detruit l'octet HAUT
        ;     de l'adresse — le faisceau A ecrivait en $00xx, sur le code du
        ;     hud, qui executait les positions comme du code (gel) ;
        ;   - X charge ENTRE le anda et le beq : LDX pose Z selon la valeur
        ;     (jamais nulle) — le beq n'etait plus jamais pris et les DEUX
        ;     tetes partageaient ringB (cellules fantomes en bas, 26/08).
        ; La forme sure : X charge AVANT le test, les drapeaux du anda
        ; arrivent intacts au beq.
        ldx   #groundmgr.ringA
        lda   subtype,u
        anda  #1
        beq   >
        ldx   #groundmgr.ringB
!       stx   gl.ringp

        lda   gfxlock.frameDrop.count
        inca                           ; au moins un pas
        sta   gl.ticks
@tick
        jsr   gl.step1
        ; l'anneau, une entree par TICK et non par trame : c'est ce qui met
        ; l'echelonnement des suiveurs en ticks, et donc la forme de la chaine
        ; a l'abri des trames sautees (idiome du rebond)
        ldb   gl_ridx,u
        aslb
        aslb                           ; 4 octets par entree
        ldx   gl.ringp
        abx
        ldd   x_pos,u
        std   ,x
        ldd   y_pos,u
        std   2,x
        ldb   gl_ridx,u
        incb
        andb  #%00001111
        stb   gl_ridx,u
        ldb   gl_fill,u
        cmpb  #16
        bhs   >
        incb
        stb   gl_fill,u
!
        ; LA COLLISION, A CE PAS-CI. C'est tout l'interet de la faire dans la
        ; boucle : le potentiel se draine dans l'ordre du trajet, et si le
        ; faisceau s'epuise ici, il s'arrete ICI — les pas suivants ne sont ni
        ; parcourus, ni ecrits dans l'anneau, ni infliges a personne.
        jsr   gl.hitEnemies
        lbeq  gl.boom
        dec   gl.ticks
        bne   @tick

        ; SORTI DE L'ECRAN = MORT, comme le is_visible_range de la borne. Le
        ; mur virtuel de gl.probe ne le remplace PAS : il borne la marche a la
        ; fenetre des tables (x-camera 8..175), et un faisceau qui a franchi
        ; le bord visible y rampait invisible jusqu'au bout de ses 112 trames
        ; — gachette morte ~2 s, vecu le 26/08/2026. Seule la droite est un
        ; vrai debouche (les deux rotations progressent a droite, et les murs
        ; confinent y a 11..190) mais on teste les deux bords, comme la borne.
        ldd   x_pos,u
        subd  glb_camera_x_pos
        cmpd  #-8
        blt   gl.gone
        cmpd  #166
        bgt   gl.gone

        ; la vie s'egrene par TRAME, pas par tick — 112 trames comme la borne
        dec   gl_life,u
        beq   gl.gone

        ; (la boite a suivi la tete a chaque pas, dans gl.hitEnemies)

        ; plus de DisplaySprite : la tete et ses suiveurs se PUBLIENT, et la
        ; routine Render (troisieme OST) dessine les douze slots en une passe
        jsr   gl.pickImages
        clr   groundmgr.boom
        jmp   groundmgr.publishChain

gl.gone
        ; toutes les morts passent ici — duree de vie, sortie d'ecran, fin
        ; d'explosion. Rien a rendre : la boite n'est dans aucune liste.
        jsr   groundmgr.clearChain     ; la chaine s'eteint avec sa tete
        jmp   DeleteObject

; ---------------------------------------------------------------------------
; gl.boom — le potentiel est draine : la tete devient la vague d'explosion
;
; On arrive ici depuis la boucle de marche, au pas EXACT ou le potentiel s'est
; epuise : x_pos/y_pos et la derniere entree d'anneau designent deja ce point,
; il n'y a rien a rembobiner. C'est ce que la passe globale ne pouvait pas
; donner — elle n'aurait connu que la position finale du tick.
; ---------------------------------------------------------------------------
gl.boom
        clr   AABB_0+AABB.p,u          ; plus aucun contact pendant l'explosion
        lda   #Rtn_Explode
        sta   routine,u
        clr   gl_life,u                ; gl_life devient e, l'age de la vague
        ; on tombe dans Explode — la premiere image part cette trame, comme
        ; le rebond enchaine sur RunExplosion

; ---------------------------------------------------------------------------
; Explode — la vague remonte la chaine, une cellule par trame
;
; La borne : la tete joue son compte 0x18 (quatre images de six trames, A
; REBOURS — rangees 3,2,1,0) ; chaque suiveur guette le handler de la cellule
; qui le precede et explose une trame apres elle. Ici la tete orchestre tout :
; la cellule j explose de e=j a e=j+23, les positions sont GELEES (l'anneau
; n'avance plus), et les cellules pas encore atteintes scintillent encore.
;
; V2-DEVIATION : pas de suivi camera pendant l'explosion — la borne laisse
; ses cellules collees a l'ECRAN (elles derivent sur le decor pendant ~25
; trames) ; nos suiveurs lisent l'anneau en coordonnees CARTE, la vague reste
; donc collee au DECOR, tout entiere et d'un bloc.
; ---------------------------------------------------------------------------
Explode
        jsr   gl.pickImages
        lda   #1
        sta   groundmgr.boom
        lda   gl_life,u
        sta   groundmgr.e
        jsr   groundmgr.publishChain
        clr   groundmgr.boom
        lda   gl_life,u
        adda  gfxlock.frameDrop.count
        inca
        sta   gl_life,u
        cmpa  #24+GL.NSEG              ; la vague a traverse toute la chaine
        bhs   gl.gone
        rts

; ---------------------------------------------------------------------------
; gl.pickImages — le scintillement de la trame, pour la tete et les suiveurs
;
; Quatre pas sur le compteur global, une image toutes les deux trames
; (arcade : global_counter AND 6, puis stride 6). Le faisceau B joue le cycle
; A L'ENVERS — le NEG que la borne applique sur le bit de parite +0x1D — ce
; qui desynchronise le scintillement des deux faisceaux.
; ---------------------------------------------------------------------------
gl.pickImages
        lda   gfxlock.frame.count+1
        anda  #6
        ldb   subtype,u
        bitb  #1
        beq   >
        nega
        anda  #6
!       sta   gl.imgoff
        ldx   #gl.imagesF              ; le set de SUIVEUR de la trame...
        ldd   a,x
        std   groundmgr.fset
        lda   gl.imgoff
        ldx   #gl.images               ; ...et celui de TETE
        ldd   a,x
        std   image_set,u
        rts

gl.ticks  fcb 0
gl.imgoff fcb 0
gl.ringp  fdb 0

; ---------------------------------------------------------------------------
; gl.step1 — un pas de la marche
; ---------------------------------------------------------------------------
gl.step1
        ; 1. avancer d'une cellule dans la direction courante
        ldb   gl_dir,u
        aslb
        ldx   #gl.step
        abx
        ldd   ,x
        addd  x_pos,u
        std   x_pos,u
        ldd   2,x
        addd  y_pos,u
        std   y_pos,u

        ; 2. le decor est-il solide la ou on vient d'arriver ?
        jsr   gl.probeHere
        beq   gl.corner

        ; 3. oui : defaire le pas, et tourner du virage AU MUR
        ldb   gl_dir,u
        aslb
        ldx   #gl.step
        abx
        ldd   x_pos,u
        subd  ,x
        std   x_pos,u
        ldd   y_pos,u
        subd  2,x
        std   y_pos,u
        ldb   gl_rot,u
        aslb
        ldx   #gl.rotation
        abx
        lda   GL_WALL,x
        adda  gl_dir,u
        anda  #6                       ; modulo 8, jamais de diagonale
        sta   gl_dir,u

gl.corner
        ; 4. LA SONDE DE COIN, touche ou pas. On regarde une cellule dans la
        ; direction opposee au virage de mur : si elle est LIBRE, on y tourne.
        ; C'est ce qui fait epouser une surface qui se derobe au lieu
        ; d'attendre de la percuter — sans elle, le faisceau decolle a chaque
        ; angle sortant.
        ldb   gl_rot,u
        aslb
        ldx   #gl.rotation
        abx
        ; sauf sur la direction de DEPART de cette rotation : le faisceau
        ; cherche encore sa paroi, il ne suit pas de coin.
        lda   GL_START,x
        cmpa  gl_dir,u
        beq   @rts
        lda   GL_CORNER,x
        adda  gl_dir,u
        anda  #6
        pshs  a                        ; la direction candidate, gardee
        tfr   a,b
        aslb
        ldx   #gl.step
        abx
        ldd   x_pos,u
        addd  ,x
        std   terrainCollision.sensor.x
        ldd   y_pos,u
        addd  2,x
        std   terrainCollision.sensor.y
        jsr   gl.probe
        puls  a
        tstb
        bne   @rts                     ; solide : on garde la direction
        sta   gl_dir,u                 ; libre : on tourne dedans
@rts    rts

; ---------------------------------------------------------------------------
; gl.hitEnemies — confronter la boite de la tete aux ennemis, ICI, a ce pas
;
; input  : [u] l'OST de la tete, sa position deja posee par gl.step1
; output : Z=1 si le potentiel est epuise — le faisceau doit exploser a ce pas
;
; POURQUOI CETTE ROUTINE EXISTE. A bas regime la tete rejoue jusqu'a neuf pas
; dans une seule trame, soit 42 px en y pour une boite qui n'en fait que 18.
; La passe globale, qui ne voit que la position FINALE, laisse alors passer un
; ennemi entier entre deux trames — il tient tout entier dans le trou. La borne
; n'a pas ce probleme : un pas de 8 px pour une demi-boite de 12, son balayage
; est continu par construction. Le trou est donc un artefact de notre
; compensation de frame-drop, et le corriger, c'est retrouver la continuite de
; l'arcade — pas s'en ecarter.
;
; Teste pas par pas, trois choses tombent juste d'un coup : le potentiel se
; draine dans l'ORDRE du trajet, le faisceau s'arrete exactement la ou il
; s'epuise (rien inflige au-dela), et l'anneau n'a rien a rembobiner puisque
; les pas suivants ne sont jamais joues.
;
; LE CORPS EST UNE COPIE de la boucle interne de Collision_Do
; (engine/collision/collision-do.asm) : meme test de chevauchement, meme duel
; de potentiels. Toute evolution du duel la-bas doit etre reportee ici.
; La tete n'etant dans aucune liste, il n'y a pas de double comptage — et rien
; n'est perdu : la passe ne confronte AABB_list_friend qu'a AABB_list_ennemy.
; ---------------------------------------------------------------------------
gl.hitEnemies
        ; la boite suit la tete : centre en coordonnees ECRAN, comme le moteur
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u
        ldb   y_pos+1,u
        stb   AABB_0+AABB.cy,u

        pshs  u
        leau  AABB_0,u                 ; U = notre AABB, comme dans Collision_Do
        ldx   AABB_list_ennemy
        beq   gl.hit.done
gl.hit.loop
        ldb   AABB.p,u
        beq   gl.hit.done              ; epuise : inutile de tester la suite
        ldb   AABB.p,x
        beq   gl.hit.next              ; boite desactivee
        lda   AABB.rx,u
        adda  AABB.rx,x
        asla
        sta   gl.hit.rx
        asra
        adda  AABB.cx,u
        suba  AABB.cx,x
        cmpa  #0
gl.hit.rx equ *-1
        bhi   gl.hit.next
        lda   AABB.ry,u
        adda  AABB.ry,x
        asla
        sta   gl.hit.ry
        asra
        adda  AABB.cy,u
        suba  AABB.cy,x
        cmpa  #0
gl.hit.ry equ *-1
        bhi   gl.hit.next
        ; --- le duel de potentiels
        ldb   AABB.p,x
        bpl   >
        ldb   AABB.p,u
        bmi   gl.hit.next              ; les deux invincibles : rien ne bouge
        clr   AABB.p,u                 ; X invincible, nous perdons
        bra   gl.hit.next
!       lda   AABB.p,u
        bpl   >
gl.hit.xWeak
        clr   AABB.p,x                 ; nous invincible, X perd
        bra   gl.hit.next
!       cmpb  #127
        beq   gl.hit.xWeak
        cmpa  #127
        beq   gl.hit.uWeak
        clrb
        suba  AABB.p,x
        bmi   gl.hit.loose
        sta   AABB.p,u                 ; gagne ou nul : on garde la difference
        stb   AABB.p,x
        bra   gl.hit.next
gl.hit.uWeak
        clr   AABB.p,u
        bra   gl.hit.next
gl.hit.loose
        nega
        sta   AABB.p,x
        stb   AABB.p,u
gl.hit.next
        ldx   AABB.next,x
        bne   gl.hit.loop
gl.hit.done
        lda   AABB.p,u                 ; Z=1 -> potentiel epuise
        puls  u,pc

; ---------------------------------------------------------------------------
; gl.probeHere / gl.probe — le decor est-il solide ?
;
; gl.probeHere sonde le centre de l'objet, gl.probe un point deja pose dans
; terrainCollision.sensor. Les DEUX plans sont testes, comme la borne qui
; compare ses deux identifiants de tuile a deux sentinelles ; le second ne
; l'est que si le stage declare son fond solide.
;
; HORS CARTE = SOLIDE, comme la borne : hors du tilemap sa sonde rend un id
; sous la sentinelle, donc un mur. Chez nous loadMap indexe ses tables SANS
; borne (yOffset couvre y 11..190, xOffset une fenetre de 168 px a droite de
; la camera, index tronque a l'octet) : sonder hors domaine lisait du code
; comme si c'etait la carte — le faisceau traversait le plafond et s'evadait
; en y negatif (bug du premier jet, 26/08/2026). Ce mur borne la MARCHE, il
; ne remplace pas le is_visible_range de la borne : la sortie d'ecran reste
; un critere de mort a part entiere, teste dans Live.
;
; sortie : Z=1 libre, Z=0 solide.
; ---------------------------------------------------------------------------
gl.probeHere
        ldd   x_pos,u
        std   terrainCollision.sensor.x
        ldd   y_pos,u
        std   terrainCollision.sensor.y
gl.probe
        ldd   terrainCollision.sensor.y
        cmpd  #11                      ; premiere ligne de yOffset (equ *-22)
        blt   @solid
        cmpd  #190                     ; derniere : 30 lignes de 6 px
        bgt   @solid
        ldd   terrainCollision.sensor.x
        subd  glb_camera_x_pos
        cmpd  #8                       ; bord gauche de xOffset (equ *-8)
        blt   @solid
        cmpd  #175                     ; 7 blocs de 24 px
        bgt   @solid
        ldb   #1                       ; premier plan
        jsr   terrainCollision.do
        tstb
        bne   @solid
        lda   globals.backgroundSolid
        beq   @free
        ldb   #0                       ; arriere-plan, si le stage le declare
        jsr   terrainCollision.do
        tstb
        bne   @solid
@free   clrb
        rts
@solid  ldb   #1
        rts

AlreadyDeleted
        rts

; ---------------------------------------------------------------------------
; DIV3u / DIV6u — les reciproques de division du calage grille
; input : [x] pointe un champ position 16.8 (int 2 octets + sub 1 octet)
; sortie : le quotient ECRIT dans le champ, et dans D
; COPIE d'obj_reboundlaser.asm : les deux unites sont des direntries separes,
; chacune dans sa page — pas d'appel de l'une a l'autre.
; ---------------------------------------------------------------------------
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

; ---------------------------------------------------------------------------
; LES TABLES — APRES le code, et ce n'est pas un gout de presentation.
;
; `groundlaser.Object` etiquette le PREMIER OCTET de ce fichier : l'unite
; l'expose comme son entree, et l'index d'objets y saute. Ces trois tables
; ouvraient le fichier — le jeu executait donc la table des pas comme du
; code, et le vaisseau du joueur disparaissait au premier tir (26/08/2026).
; Cas de migration : docs/lang/en/migration/unit-entry-point.md
; ---------------------------------------------------------------------------
; Les quatre directions cardinales. La borne code 0=HAUT 2=GAUCHE 4=BAS
; 6=DROITE et masque par 6, donc jamais de diagonale ; on garde son codage pour
; que les tables se lisent en face du desassemblage.
; Son pas de 8 px devient (3, 6) chez nous — soit EXACTEMENT une cellule de la
; carte de collision. La marche est « une cellule par pas », sans reste.
; Indexe par direction*2, quatre octets par entree (arcade ES:0x2114).
GL_STEP_X     equ 3
GL_STEP_Y     equ 6
gl.step
        fdb   0,-GL_STEP_Y           ; 0 : HAUT
        fdb   -GL_STEP_X,0           ; 2 : GAUCHE
        fdb   0,GL_STEP_Y            ; 4 : BAS
        fdb   GL_STEP_X,0            ; 6 : DROITE

; Les quatre rotations. La borne les etale sur deux tables de 8 et 96 octets
; (ES:0x2124 et ES:0x212C) ; decodees, elles tiennent en trois nombres :
;
;   - le virage AU MUR, quand le pas rentre dans du solide ;
;   - le virage DE COIN, toujours l'oppose du precedent, tente a chaque pas
;     vers le vide pour epouser une surface qui se derobe ;
;   - la direction de DEPART, seule ligne ou le virage de coin ne s'applique
;     pas : tant que le faisceau cherche encore sa paroi, il ne suit pas de
;     coin. C'est l'unique exception de la table arcade.
;
; Indexe par rotation*2, quatre octets par entree.
gl.rotation
        fcb   6,2,0,0                ; rot 0 : horaire,      depart HAUT
        fcb   2,6,4,0                ; rot 2 : anti-horaire, depart BAS
        fcb   2,6,0,0                ; rot 4 : anti-horaire, depart HAUT
        fcb   6,2,4,0                ; rot 6 : horaire,      depart BAS

GL_WALL       equ 0                  ; offsets dans une entree de gl.rotation
GL_CORNER     equ 1
GL_START      equ 2

; Les quatre images du scintillement. La borne les choisit sur son compteur
; global (`AND 6`), une image toutes les deux trames.
gl.images
        fdb   Img_groundlaser_0
        fdb   Img_groundlaser_1
        fdb   Img_groundlaser_2
        fdb   Img_groundlaser_3
gl.imagesF                           ; les suiveurs, meme phase (base 0x21A4)
        fdb   Img_groundlaser_f0
        fdb   Img_groundlaser_f1
        fdb   Img_groundlaser_f2
        fdb   Img_groundlaser_f3
gl.imagesX                           ; l'explosion (recette 0x21BC), jouee a
        fdb   Img_groundlaser_x0     ; REBOURS par groundmgr.boomSet
        fdb   Img_groundlaser_x1
        fdb   Img_groundlaser_x2
        fdb   Img_groundlaser_x3
