;*******************************************************************************
; outslay — le serpent symbiotique du stage 2
;
; FICHE DE PORTAGE (source : base Ghidra `maincpu`, subsystem actor/outslay)
; -------------------------------------------------------------------------
; L'outslay n'est pas UN objet mais une CHAINE. Un emetteur invisible pose,
; a intervalles, 22 segments qui partagent le MEME script de mouvement,
; rejoue chacun depuis son debut a la position de l'emetteur : le segment n
; refait le chemin avec n x ~10 trames de retard, et le serpent suit sa tete
; a la file. Rien d'autre ne relie les segments geometriquement.
;
;   40:915b create_outslay ............... l'emetteur (outslay.Object)
;   40:91cc tick_outslay_segment_chain ... deroule le script de chaine
;   1000:40c6 outslay_segment_spawn_script  (handler, delai) x 22 :
;             tete(10) cou(10) 17 x corps(11) corps(10) queue(10)
;             finalizer(0 = terminateur, l'emetteur se decharge ensuite)
;             ECART DE LA BASE GHIDRA : sa plate annonce 21 entrees / 84
;             octets ; les octets en donnent 22 / 88 — la table court de
;             0x40c6 a 0x411e, ou commence outslay_bydo_shot_table_loop1.
;   1000:4086 outslay_spawn_variant_table   8 variantes (script, X, Y)
;   40:9246 / 925b  head_install  / head_tick       (invulnerable)
;   40:92c3 / 92d8  neck_install  / neck_tick       (invulnerable)
;   40:933c / 9355  body_install  / body_tick       (meurt au 1er coup)
;   40:93fa / 9425  body_explode_init / _tick       (le cadavre derive)
;   40:94e1 / 94f6  tail_install  / tail_tick       (invulnerable)
;   40:9477 / 948c  finalizer_install / _tick       (invulnerable)
;   40:95a3         fire_bydo_shot_8way             (salve radiale de 8)
;   40:9569         silent_unload                   (fin de script)
;   1000:427c       outslay_aabb                    16x16 arcade, centree
;
; LA VARIANTE DU STAGE 2. La wave ne cite l'outslay qu'une fois
; ($0E88, subtype $0004) : bits 0-2 = 4 -> variante 4 du spawn table,
; script de mouvement 1000:a652 (= anim_1A652), X 0x2c8, Y 0x130 ; bit 2
; mis -> l'horloge de tir de la tete est forcee a $C0 (91af). Les sept
; autres variantes servent au combat contre Gomander, qui pose ses outslay
; par outslay_wavescript_tick (40:a5a4) en coordonnees ECRAN — elles
; n'ont pas de sens dans le repere playfield de la v2, et attendent le
; portage du boss. Rangees arcade, pour memoire :
;   0: a4e6 (452,265)  1: a530 (568,264)  2: a56e (408,176)  3: a626 (619,182)
;   4: a652 (712,304)  5..7: a7de (619,182)
;
; LE MOUVEMENT EST GRATUIT. Les segments arcade appellent move_by_script
; (40:f5c1) — la routine que la v2 a deja (moveByScript), MEME format
; d'octets — et le script 1000:a652 est DEJA dans le build : l'export
; d'animation de re.arcade.r-type le pose dans
; src/common/fx/animation/script.asm sous ref_1A652 (197 segments,
; 70 distincts, ~3370 pas, soit ~34 s a anim_frame_duration = 2). Le
; portage ne coute qu'une ligne d'index (index.asm + index.equ).
;
; CE QUI EST ABANDONNE (et pourquoi) :
; - la mort chainee (40:954b destroy_with_score, ~22 explosions en cascade)
;   ne se declenche que si le spawner est Gomander (`tick == 0xa523`).
;   Notre spawn vient de la wave : les segments meurent par la fin de leur
;   script. A reprendre le jour du boss.
; - le swap de palette du 2e loop (40:957c) et les palettes par objet :
;   palette TO8 globale (12 communs + 4 du stage).
; - le bruitage 0x5d de la salve : le tir ennemi est muet en v2 (aucun
;   _soundFX dans la chaine tryFoeFire / createFoeFire).
; - V2-DEVIATION : la parite de collision arcade (`global_counter XOR
;   priorite`, un segment sur deux par trame, tete sur paire et queue sur
;   impaire) est une economie de CPU propre a l'arcade. En v2 la passe
;   Collision_Run est globale et chaque AABB reste dans sa liste : tous les
;   segments collisionnent a chaque trame. Le serpent est donc legerement
;   plus mordant qu'en arcade.
; - V2-DEVIATION : l'arcade decremente la priorite d'affichage a chaque
;   segment (91e1, depuis $201f) pour que la queue passe derriere la tete.
;   Les 8 niveaux de priorite v2 ne peuvent pas porter 22 rangs : toute la
;   chaine est au niveau 6, comme pata-pata.
;
; LIMITE CONNUE, heritee de l'arcade : le pointeur d'aine (outslay.elder)
; n'est pas invalide quand l'aine rend son slot en fin de script. L'arcade
; vit avec — les slots y sont recycles de meme. En v2 le slot libere peut
; etre repris par un autre objet, et le cadet lirait alors ses ext_variables
; a +11 : au pire une salve parasite, dans les ~230 trames qui separent la
; fin de script du premier segment de celle du dernier, donc en toute fin de
; vie du serpent. Corriger couterait une passe de fixup a chaque mort.
;
; L'HORLOGE DE GRAINE decompte une fois par appel de routine, la ou l'arcade
; decompte une fois par tick : le rythme suit donc l'horloge de jeu (frame
; drop compense) et non l'horloge video. C'est la politique v2 pour les
; cadences (cf. arcade-to-v2.md, « Rythme et horloges »).
;
; NOMMAGE : le cast du stage 2 est UN direntry, tous les obj.asm sont
; assembles dans la MEME unite (cast.unit.asm) — chaque etiquette porte donc
; le prefixe `outslay.`, sinon le premier ennemi implemente interdit le
; second.
;*******************************************************************************

; --- ext_variables (budget ext_variables_size = 20 octets) -------------------
outslay.AABB      equ ext_variables      ; 0..8  segment : boite de collision
outslay.elder     equ ext_variables+9    ; 9,10  emetteur : le dernier-ne
                                         ;       segment  : le frere aine
                                         ;       (arcade [+0x3c], 91fd/9203)
outslay.cooldown  equ ext_variables+11   ; 11,12 segment : cran de la cascade
                                         ;       de tir (arcade [+0x24])
outslay.clock     equ ext_variables+13   ; 13,14 tete : horloge de graine
                                         ;       (arcade [+0x20], rechargee
                                         ;       depuis [+0x22])
outslay.cursor    equ ext_variables+15   ; 15    emetteur : index dans
                                         ;       ChainScript (arcade [+0x30])
outslay.delay     equ ext_variables+16   ; 16    emetteur : compte a rebours
                                         ;       du prochain segment ([+0x32])

; --- les roles de segment ----------------------------------------------------
; L'ordre n'est pas libre : le test « l'aine tire-t-il encore ? » de
; outslay_body_tick (9372..9382) accepte {corps, cadavre, cou} et refuse
; {tete, queue, finalizer}. Les trois roles tirants sont donc contigus, et
; le test devient un encadrement. Le role voyage par `subtype` au spawn puis
; devient l'index de routine (role + 1).
outslay.role.head      equ 0
outslay.role.neck      equ 1
outslay.role.body      equ 2
outslay.role.corpse    equ 3
outslay.role.tail      equ 4
outslay.role.finalizer equ 5

outslay.rt.head        equ outslay.role.head+1
outslay.rt.neck        equ outslay.role.neck+1
outslay.rt.body        equ outslay.role.body+1
outslay.rt.corpse      equ outslay.role.corpse+1
outslay.rt.tail        equ outslay.role.tail+1
outslay.rt.finalizer   equ outslay.role.finalizer+1
outslay.rt.deleted     equ outslay.role.finalizer+2

; 9388..93b2 : la salve part si la distance de Manhattan au joueur est sous
; 0x90 = 144 pixels ARCADE. L'echelle v2 n'est pas la meme sur les deux axes
; (scale.asm : X 0.375, Y 0.75, soit deux fois X) : 144 px arcade valent 54
; px larges en X, et un delta Y v2 pese deux fois moins qu'un delta X pour
; revenir au repere arcade. Le test devient |dx| + |dy| / 2 < 54.
outslay.fireRange equ 54

;*******************************************************************************
; L'EMETTEUR — arcade create_outslay (40:915b) + tick_outslay_segment_chain
; (40:91cc). Invisible : ni sprite ni collision, il ne fait que poser les
; segments, puis se decharge sur le terminateur du script.
;*******************************************************************************

outslay.Object
        lda   routine,u
        asla
        ldx   #outslay.EmitRoutines
        jmp   [a,x]

outslay.EmitRoutines
        fdb   outslay.EmitInit
        fdb   outslay.EmitLive
        fdb   outslay.Deleted

outslay.EmitInit
        ; 9183 : [+0x04] = 0x2c8 — c'est exactement le bord droit que
        ; pata-pata cite (arcade fc7e), donc le meme point d'entree v2.
        ldd   glb_camera_x_pos
        addd  #144+8+3
        std   x_pos,u
        ; 918b : [+0x08] = 0x130 = 304. Conv : (304 - 144) * -0.75 + 190 = 70.
        ldd   #70
        std   y_pos,u
        ; L'emetteur ne dessine rien : priorite 0 = « rien a afficher ».
        clr   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldx   #0
        stx   outslay.elder,u          ; pas encore de dernier-ne
        clr   outslay.cursor,u         ; 91b4 : curseur en tete de script
        lda   #1                       ; 91b9 : [+0x32] = 1, premier segment
        sta   outslay.delay,u          ;        des la trame suivante
        inc   routine,u
        ; Les trames perdues avant la creation, deposees par ObjectWave :
        ; derouler la chaine d'autant pour rester cale sur l'horodatage.
        ldb   wave_frame_drop,u
        bra   outslay.EmitByB

outslay.EmitLive
        ldb   gfxlock.frameDrop.count
outslay.EmitByB
        tstb
        bne   outslay.EmitLoop
        incb                           ; jamais 256 tours si B vaut 0
outslay.EmitLoop
        jsr   outslay.EmitStep         ; le terminateur du script ne revient
        decb                           ; pas ici : il sort par @done
        bne   outslay.EmitLoop
        rts

; Un pas du script de chaine — arcade 91d3..923d.
outslay.EmitStep
        dec   outslay.delay,u
        bne   @ret                     ; 91d6 : pas encore
        ldx   #outslay.ChainScript
        ldb   outslay.cursor,u
        abx
        ldb   ,x                       ; 91db : le role du segment a poser
        pshs  b
        jsr   LoadObject_x             ; 91e5 : alloc ; Z = pool plein
        puls  b
        beq   @advance                 ; 91e9 : plein -> le script avance quand meme
        ; Deux identifiants pour un seul code : Img_Page_Index donne UNE page
        ; d'imagesets par id, et les poses de tete/finalizer vivent dans un
        ; autre direntry que le reste du corps.
        lda   #ObjID_outslay_head
        tstb                           ; role 0 = tete
        beq   @setid
        cmpb  #outslay.role.finalizer
        beq   @setid
        lda   #ObjID_outslay_segment
@setid  std   id,x                     ; id + subtype (= le role) d'un coup
        ldd   x_pos,u                  ; 9206 : l'enfant nait ou est l'emetteur
        std   x_pos,x
        ldd   y_pos,u                  ; 920c
        std   y_pos,x
        ldd   outslay.elder,u          ; 91fd : son aine = le dernier-ne
        std   outslay.elder,x
        stx   outslay.elder,u          ; 9203 : ...qui devient le dernier-ne
@advance
        ldx   #outslay.ChainScript
        ldb   outslay.cursor,u
        abx
        ldb   1,x                      ; 9232 : le delai jusqu'au suivant
        stb   outslay.delay,u
        beq   @done                    ; 923b : delai 0 = TERMINATEUR — le
                                       ; segment qu'on vient de poser est le
                                       ; dernier, l'emetteur a fini
        ldb   outslay.cursor,u
        addb  #2                       ; 923d : entree suivante
        stb   outslay.cursor,u
@ret    rts
@done                                  ; 9242 : unload_managed_object
        lda   #2                       ; l'emetteur passe en Deleted
        sta   routine,u
        leas  2,s                      ; NE PAS revenir dans la boucle d'appel :
                                       ; l'OST est rendue a la ligne suivante, et
                                       ; la relire (ne serait-ce que `routine,u`)
                                       ; ferait tourner un tour de plus sur un
                                       ; slot libre, voire y poser un segment au
                                       ; role aberrant.
        jmp   UnloadObject_u           ; rien n'a ete dessine : pas de DeleteObject

;*******************************************************************************
; UN SEGMENT — les cinq ticks arcade, un role par routine.
;*******************************************************************************

outslay.Segment
        lda   routine,u
        asla
        ldx   #outslay.Routines
        jmp   [a,x]

outslay.Routines
        fdb   outslay.Init
        fdb   outslay.LiveHead         ; 40:925b
        fdb   outslay.LiveNeck         ; 40:92d8
        fdb   outslay.LiveBody         ; 40:9355
        fdb   outslay.LiveCorpse       ; 40:9425
        fdb   outslay.LiveTail         ; 40:94f6
        fdb   outslay.LiveFinalizer    ; 40:948c
        fdb   outslay.Deleted

outslay.Init
        ; Le role est arrive par le subtype ; il devient l'index de routine.
        ldb   subtype,u
        incb
        stb   routine,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldb   #6
        stb   priority,u
        ; 92ab / 93e0 : tous les segments portent la meme boite (1000:427c),
        ; 16x16 arcade centree -> 6 x 12 en large-dot.
        _Collision_AddAABB outslay.AABB,AABB_list_ennemy
        _ldd  outslay_hitbox_x,outslay_hitbox_y
        std   outslay.AABB+AABB.rx,u
        ; 933c : SEUL le corps est vulnerable, et il meurt au premier coup.
        ; Les quatre autres roles reappliquent [+0x1f] = 0 / [+0x2f] = $ff a
        ; chaque trame (929b/929f) : en v2 un potentiel negatif dit la meme
        ; chose une fois pour toutes.
        lda   #outslay_hitdamage
        ldb   subtype,u
        cmpb  #outslay.role.body
        beq   >
        lda   #outslay_hitdamage_immune
!       sta   outslay.AABB+AABB.p,u
        ; 921e..922a : le script de mouvement de la tete, rejoue depuis son
        ; debut, et [+0x17] = 2 pas de deplacement par trame.
        ldx   #anim_1A652
        jsr   moveByScript.initialize
        lda   #2
        sta   anim_frame_duration,u
        ; 91a6 / 91af : l'horloge de graine de la tete. L'enfant recoit
        ; [+0x20] = [+0x20 de l'emetteur] + 0x28 et [+0x22] = [+0x20], soit
        ; $E8 avant la premiere graine puis $C0 de periode (le subtype $04
        ; de la wave porte le bit 2, qui force ce $C0).
        ldd   #$00E8
        std   outslay.clock,u
        ldx   #0
        stx   outslay.cooldown,u
        ; Repartir dans la routine du role, pour afficher des cette trame.
        lda   routine,u
        asla
        ldx   #outslay.Routines
        jmp   [a,x]

; --- la tete : 40:925b -------------------------------------------------------
outslay.LiveHead
        jsr   outslay.Move
        ; 926d : la graine est remise a zero a CHAQUE trame, puis semee
        ; seulement quand l'horloge tombe.
        ldx   #0
        stx   outslay.cooldown,u
        ldd   outslay.clock,u          ; 9272 : DEC [+0x20]
        subd  #1
        std   outslay.clock,u
        bne   @noseed
        ldd   #$00C0                   ; 9277 : rechargement depuis [+0x22]
        std   outslay.clock,u
        jsr   RandomNumber             ; 927d
        andb  #3                       ; 9280
        incb                           ; 9283 : graine 1..4
        clra
        std   outslay.cooldown,u
@noseed
        ldb   anim_frame,u             ; 9287 : la pose vient du script
        ldx   #outslay.HeadImages
        jmp   outslay.ShowAndCollide

; --- le cou : 40:92d8 --------------------------------------------------------
; Le cou herite du cran de son aine — l'arcade le remet a zero quand cet aine
; est la tete, parce que la tete porte une graine et non un cran propage. La
; tete mettant deja son propre cran a zero a chaque trame sauf celle de la
; graine, l'heritage brut donne le meme resultat : le cou porte la graine
; d'un cran plus bas, et la cascade commence chez lui.
outslay.LiveNeck
        jsr   outslay.Move
        jsr   outslay.InheritCooldown
        ldb   anim_frame,u
        ldx   #outslay.NeckImages
        jmp   outslay.ShowAndCollide

; --- la queue : 40:94f6 ------------------------------------------------------
; Meme pool que le cou, moitie arriere : ([+0x16] + 8) & 0xf.
outslay.LiveTail
        jsr   outslay.Move
        jsr   outslay.InheritCooldown
        jsr   outslay.OppositePose
        ldx   #outslay.NeckImages
        jmp   outslay.ShowAndCollide

; --- le finalizer : 40:948c --------------------------------------------------
; Miroir de la tete : meme pool, indexe ([+0x16] + 8) & 0xf.
outslay.LiveFinalizer
        jsr   outslay.Move
        jsr   outslay.InheritCooldown
        jsr   outslay.OppositePose
        ldx   #outslay.HeadImages
        jmp   outslay.ShowAndCollide

; --- le corps : 40:9355 ------------------------------------------------------
outslay.LiveBody
        jsr   outslay.Move
        jsr   outslay.FireChain
        lda   outslay.AABB+AABB.p,u    ; 93e6 : touche = mort au premier coup
        lbeq  outslay.Explode
        jsr   outslay.BodyPose
        ldx   #outslay.BodyImages
        jmp   outslay.ShowAndCollide

; --- le cadavre : 40:9425 ----------------------------------------------------
; L'emplacement n'est PAS rendu : le corps detruit derive le long du meme
; chemin, collisionne encore (mais immunise) et ne tire plus. Son cran est
; borne a 1 (9440) : il ne peut plus satisfaire la condition « l'aine portait
; exactement 1 » qui declenche une salve.
outslay.LiveCorpse
        jsr   outslay.Move
        ldx   outslay.elder,u
        beq   >
        ldd   outslay.cooldown,x
        subd  #1
        bne   >
        ldd   #1                       ; 9440 : plancher a 1
!       std   outslay.cooldown,u
        ldb   #0                       ; 9444 : outslay_explode_recipe
        ldx   #outslay.BrokenImages
        jmp   outslay.ShowAndCollide

outslay.Deleted
        rts

;*******************************************************************************
; Les briques communes
;*******************************************************************************

; Le script de mouvement, et la fin de vie qu'il commande. Arcade 9265..926a :
; move_by_script rend CF quand le script est epuise, et le segment sort en
; silence — ni score ni bruitage.
outslay.Move
        ldd   #outslay.endCheck
        std   moveByScript.callback
        jsr   moveByScript.runByFrameDrop
        lda   moveByScript.anim.end
        beq   >
        leas  2,s                      ; on ne revient pas a l'appelant
        jmp   outslay.Unload
!       rts

outslay.endCheck
        lda   moveByScript.anim.end
        beq   >
        clr   moveByScript.anim.loops  ; sortir de la boucle parente
!       rts

outslay.Unload                         ; 40:9569 outslay_silent_unload
        lda   #outslay.rt.deleted
        sta   routine,u
        _Collision_RemoveAABB outslay.AABB,AABB_list_ennemy
        jmp   DeleteObject

; B = index d'image, X = table d'imagesets.
outslay.ShowAndCollide
        aslb
        ldd   b,x
        std   image_set,u
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   outslay.AABB+AABB.cx,u
        ldb   y_pos+1,u
        stb   outslay.AABB+AABB.cy,u
        jmp   DisplaySprite

; Les deux bouts « arriere » lisent la moitie haute de leur pool.
outslay.OppositePose
        ldb   anim_frame,u
        addb  #8
        andb  #$0F
        rts

; 93bc..93cc : 4 images, 8 trames de maintien, periode 32.
outslay.BodyPose
        ldb   gfxlock.frame.count
        andb  #$18
        lsrb
        lsrb
        lsrb
        rts

; Les roles qui ne decident rien propagent le cran de leur aine, un cran plus
; bas — c'est ce qui fait descendre la graine le long du serpent.
outslay.InheritCooldown
        ldx   outslay.elder,u
        beq   >
        ldd   outslay.cooldown,x
        subd  #1
        std   outslay.cooldown,u
!       rts

; La cascade de tir du corps — arcade 9367..93b9.
; L'aine porte un cran ; on prend cran - 1. S'il ne tombe pas exactement a
; zero, on le propage tel quel. S'il tombe a zero, c'est notre tour de
; decider : l'aine doit encore etre un role tirant (cou, corps, cadavre) et
; le joueur doit etre a portee. Detruire un corps casse donc la chaine a sa
; position — c'est le « incapable of ranged attacks » du bestiaire.
outslay.FireChain
        ldx   outslay.elder,u
        beq   @ret
        ldd   outslay.cooldown,x
        subd  #1
        bne   @store                   ; 936e : ce n'etait pas notre tour
        ldb   routine,x                ; 9370..9382 : l'aine tire-t-elle ?
        cmpb  #outslay.rt.neck
        blo   @none                    ; la tete ne propage pas
        cmpb  #outslay.rt.corpse
        bhi   @none                    ; queue et finalizer non plus
        ldd   #1                       ; 9387 : l'aine portait exactement 1
        jsr   outslay.InRange          ; 9388..93b2
        bcc   @store                   ; hors de portee : on repropage le 1
        jsr   outslay.Fire8Way         ; 93b4
        ldd   #0                       ; 93b7 : cran consomme
        bra   @store
@none   ldd   #0                       ; 9384 : role refuse, le cran meurt ici
@store  std   outslay.cooldown,u
@ret    rts

; C = 1 si le joueur est a portee de salve. D est preserve.
outslay.InRange
        pshs  d
        ldd   player1+x_pos
        subd  x_pos,u
        bpl   >
        coma
        comb
        addd  #1                       ; |dx|
!       pshs  d
        ldd   player1+y_pos
        subd  y_pos,u
        bpl   >
        coma
        comb
        addd  #1                       ; |dy|
!       lsra                           ; |dy| / 2 : l'axe Y porte deux fois
        rorb                           ; l'echelle de l'axe X
        addd  ,s++
        cmpd  #outslay.fireRange
        puls  d,pc

; 40:95a3 : huit tirs bydo en etoile, un par direction de la table.
; L'arcade met un seul bruitage APRES la boucle (id 0x5d) — le tir ennemi est
; muet en v2 (ni tryFoeFire ni createFoeFire ne jouent quoi que ce soit), la
; ligne reste ici pour memoire :
;   95e9 : enqueue_event(sfx 0x5d)
outslay.Fire8Way
        pshs  d,y
        clrb
@loop   pshs  b
        jsr   LoadObject_x
        beq   @full
        lda   #ObjID_foefire
        sta   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
        ldb   ,s
        lslb
        lslb                           ; 4 octets par direction
        ldy   #outslay.ShotVelocity
        leay  b,y
        ldd   ,y
        std   x_vel,x
        ldd   2,y
        std   y_vel,x
@full   puls  b
        incb
        cmpb  #8
        bne   @loop
        puls  d,y,pc

; Le corps meurt — arcade 40:93fa body_explode_init. Le slot n'est PAS rendu :
; il passe en cadavre, qui garde le chemin et l'AABB mais ne tire plus. Rien
; n'est dessine cette trame : comme chez pata-pata, la mort se lit AVANT le
; dessin, la ou l'arcade dessinait puis testait la collision.
outslay.Explode
        ldb   #outslay_scoreIdx        ; 9410 : recompense 0x86ec
        jsr   AwardScore
        _soundFX.play soundFX.ExplosionSound,1
        jsr   LoadObject_x
        beq   >
        _ldd  ObjID_explosion,explosion.subtype.smallx2
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
!       lda   #outslay.rt.corpse
        sta   routine,u
        lda   #outslay_hitdamage_immune ; 9457 : le cadavre est immunise
        sta   outslay.AABB+AABB.p,u
        rts

;*******************************************************************************
; Les tables
;*******************************************************************************

; 1000:40c6 outslay_segment_spawn_script — (role, delai) x 22. Les handlers
; arcade sont remplaces par le role ; les delais sont ceux de la ROM.
outslay.ChainScript
        fcb   outslay.role.head,10       ; 40c6 : 9246, delai 10
        fcb   outslay.role.neck,10       ; 40ca : 92c3, delai 10
        fcb   outslay.role.body,11       ; 40ce : 933c, delai 11
        fcb   outslay.role.body,11       ; 40d2
        fcb   outslay.role.body,11       ; 40d6
        fcb   outslay.role.body,11       ; 40da
        fcb   outslay.role.body,11       ; 40de
        fcb   outslay.role.body,11       ; 40e2
        fcb   outslay.role.body,11       ; 40e6
        fcb   outslay.role.body,11       ; 40ea
        fcb   outslay.role.body,11       ; 40ee
        fcb   outslay.role.body,11       ; 40f2
        fcb   outslay.role.body,11       ; 40f6
        fcb   outslay.role.body,11       ; 40fa
        fcb   outslay.role.body,11       ; 40fe
        fcb   outslay.role.body,11       ; 4102
        fcb   outslay.role.body,11       ; 4106
        fcb   outslay.role.body,11       ; 410a
        fcb   outslay.role.body,11       ; 410e
        fcb   outslay.role.body,10       ; 4112 : le dernier corps attend moins
        fcb   outslay.role.tail,10       ; 4116 : 94e1, delai 10
        fcb   outslay.role.finalizer,0   ; 411a : 9477, delai 0 = terminateur

; 1000:411e outslay_bydo_shot_table_loop1 — les 8 directions de la salve,
; converties a l'echelle TO8 en 8.8. Export rejouable de re.arcade.r-type
; (Preset.PresetWordXYVel, records de 6 octets : tick_handler, vx, vy).
; La table loop2 (1000:414e), deux fois plus rapide, ne sert qu'au second
; tour de jeu — la v2 n'a pas de second tour.
outslay.ShotVelocity
        INCLUDE "src/enemies/outslay/1411e_outslay-shotVelocity.asm"

; Les poses. 40:9294 (tete) et 40:948c (finalizer) partagent un pool de 16
; (outslay_head_finalizer_sprite_recipes, 1000:419e), le finalizer le lisant
; decale de 8 ; cou et queue partagent l'autre (1000:41fe). Les 16 poses sont
; toutes visitees par le script de la variante 4.
outslay.HeadImages
        fdb   set_outslay_head_0,set_outslay_head_1
        fdb   set_outslay_head_2,set_outslay_head_3
        fdb   set_outslay_head_4,set_outslay_head_5
        fdb   set_outslay_head_6,set_outslay_head_7
        fdb   set_outslay_head_8,set_outslay_head_9
        fdb   set_outslay_head_10,set_outslay_head_11
        fdb   set_outslay_head_12,set_outslay_head_13
        fdb   set_outslay_head_14,set_outslay_head_15

outslay.NeckImages
        fdb   set_outslay_neck_0,set_outslay_neck_1
        fdb   set_outslay_neck_2,set_outslay_neck_3
        fdb   set_outslay_neck_4,set_outslay_neck_5
        fdb   set_outslay_neck_6,set_outslay_neck_7
        fdb   set_outslay_neck_8,set_outslay_neck_9
        fdb   set_outslay_neck_10,set_outslay_neck_11
        fdb   set_outslay_neck_12,set_outslay_neck_13
        fdb   set_outslay_neck_14,set_outslay_neck_15

; 1000:425e outslay_body_sprite_recipes — 4 images d'animation.
outslay.BodyImages
        fdb   set_outslay_body_0,set_outslay_body_1
        fdb   set_outslay_body_2,set_outslay_body_3

; 1000:4276 outslay_explode_recipe — l'epave du corps detruit.
outslay.BrokenImages
        fdb   set_outslay_broken_0
