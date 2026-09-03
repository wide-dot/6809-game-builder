;*******************************************************************************
; gomander — le boss du stage 2
;
; FICHE DE PORTAGE (source : base Ghidra `maincpu`, subsystem actor/gomander)
; -------------------------------------------------------------------------
;   40:a22e create_gomander ......... pose le boss, FIGE LE SCROLL, BGM boss
;   40:a278 run_gomander_boss ....... machine a 12 etats
;   40:a3f4 _combat_join ............ la QUEUE COMMUNE : chaque etat y saute.
;                                     C'est elle qui porte le compteur de
;                                     combat, les jalons de fin et l'appel a
;                                     la wavescript des serpents.
;   40:a5a4 outslay_wavescript_tick . les 8 serpents du combat
;   1000:4d62 outslay_wavescript_table (token, delai) x 8
;   40:a4cd _arm_death_sequence ..... PV epuises : score, cascade, 384 trames
;   40:a523 _tick_death_sequence .... la mort, jalon a 128
;   40:a473 _silent_unload .......... relance l'autoscroll et se decharge
;   1000:54ea gomander_orb_sprite_offsets — les 8 premiers octets sont la
;                                     boite du point faible : -16..+16 en X,
;                                     -8..+8 en Y (arcade) -> 6 x 6 en large.
;
; CE QUE CETTE PASSE PORTE : la chronologie, les serpents, les deux sorties.
; CE QU'ELLE NE PORTE PAS, ET POURQUOI :
; - LE CORPS. Le Gomander n'est pas un sprite : `gomander_helper_blit_recipe`
;   (a578) recopie une bande de 4 x 12 cellules vers 0xd000, la VRAM de
;   TILEMAP DE FOND. Le boss est peint dans le decor. Le catalog de
;   re.arcade.r-type le dit aussi (`engine: tile_grid, indirect: true`) et
;   son extracteur de sprites ne decode pas ce moteur : il n'existe
;   aujourd'hui aucune image exploitable, ni animee ni fixe. Le boss est donc
;   INVISIBLE ici — il a sa position, ses PV, sa boite et toute son horloge.
; - LES ANIMATIONS d'engloutissement (les tubes qui avalent et recrachent les
;   serpents) : ce sont les etats phase_a / phase_b / engulf_loop. Leurs
;   DUREES sont portees, parce qu'elles font le rythme du combat ; seul le
;   repeint de tilemap qu'elles pilotent manque.
; - L'EMISSION D'ORBES (a5c5, script 1000:4d1c) : l'attaque propre du boss,
;   hors perimetre. L'appel reste en commentaire a sa place dans CombatJoin.
;
; LE RYTHME DU COMBAT, ET POURQUOI IL FAUT LES ETATS. Un coup ne compte que
; dans DEUX fenetres : orbe ouvert (224 trames) et orbe arme (15). Ailleurs
; l'arcade n'appelle meme pas la collision. Et un coup encaisse envoie le
; boss 224 trames en engloutissement invulnerable. Sans ces fenetres, huit
; points de vie tombent en une seconde de tir nourri : le rythme EST la
; machine a etats, meme depouillee de ses images.
;
; ARRET DU SCROLL — ECART ASSUME sur le geste du stage 1. Le stage 1 baisse
; `scroll_max` sur la salle du boss ; ici c'est `scroll_vel` qui passe a
; zero. Raison : la sequence de fin COMMUNE aux stages 2-8 (obj_endlevel)
; declenche sa victoire sur `camera >= scroll_max`. Baisser le plafond
; finirait donc le niveau en plein combat. Mettre la vitesse a zero est en
; plus exactement ce que fait create_gomander (a23d : les deux vitesses
; d'autoscroll ecrites a zero), et _silent_unload la relance de meme.
; Ce qui rend l'arret SUR en mode overlay : `DrawTiles` ne repeint que si
; `glb_camera_move` est leve, et `Scroll` ne le leve que quand la camera
; bouge — un scroll fige effacerait donc le decor sans le redessiner. La
; boucle overlay force deja ce drapeau a 1 avant DrawTiles (stage-main.asm,
; « le champ vient d'etre efface, le decor DOIT se repeindre chaque trame »).
; A NE PAS defaire : c'est ce qui autorise un boss a l'arret.
;
; L'arcade teste la boite de l'orbe avec
; `do_collision_with_player_and_weapons_v3_skip_player` — le JOUEUR est
; ignore, parce que le corps du boss est du decor et que c'est la collision
; terrain qui l'arrete. La boite vit donc dans AABB_list_target (creee pour
; ca le 31/08/2026) : armes et pod/bits la touchent (passe friend×target +
; WeaponContactTick), le contact joueur est impossible par construction —
; aucune passe player×target n'existe. L'ancienne deviation (boite dans
; ennemy, letale au contact) est levee.
;
; NOMMAGE : tout le cast du stage 2 est assemble dans une seule unite, donc
; chaque etiquette porte le prefixe `gomander.` (voir outslay/obj.asm).
;*******************************************************************************

; --- ext_variables (budget ext_variables_size = 20 octets) -------------------
gomander.AABB     equ ext_variables      ; 0..8  boite du point faible
gomander.combat   equ ext_variables+9    ; 9,10  compteur de combat, en trames
                                         ;       video (arcade [+0x10])
gomander.timer    equ ext_variables+11   ; 11,12 compte a rebours de l'etat
                                         ;       (arcade [+0x24]), puis de la
                                         ;       mort (arcade [+0x30])
gomander.cursor   equ ext_variables+13   ; 13    curseur wavescript, en octets
                                         ;       (arcade [+0x20])
gomander.delay    equ ext_variables+14   ; 14,15 compte a rebours du prochain
                                         ;       serpent (arcade [+0x22])
gomander.hp       equ ext_variables+16   ; 16    PV restants — miroir de AABB.p,
                                         ;       qui passe a -128 hors fenetre
gomander.d2nd     equ ext_variables+17   ; 17    la 2e deflagration est faite
                                         ;       (l'ex-savedVel : la fin arcade
                                         ;       ne re-scrolle jamais)

; L'ANIMATION DU TUBE. L'arcade repeint un rectangle de sa tilemap de fond
; (gomander_helper_blit_recipe, 0x40:A578) : le corps du boss est du DECOR, ce
; qui est aussi ce qui laisse le serpent passer derriere. Chez nous c'est
; tilemap.patch, rectangle en colonne 87 ligne 7 — position retrouvee par
; correlation, cf. tools/gen_engulf.py.
;
; L'ETAT VIT DANS L'OST DU BOSS, sur les octets 12-14 que le moteur
; d'animation de sprites y reserve deja (alias tanim.*). Rien a allouer : une
; animation appartient a un objet, et cet objet la porte. Le code ci-dessous
; n'ecrit jamais dans la carte — il empile une demande, et tilemap.flush
; l'applique une fois par trame depuis la boucle de jeu.
engulf            EXTERNAL
blink             EXTERNAL
; La porte de l'orbe, dans l'unite collision du stage (meme scene) : le
; loader resout l'adresse, l'index d'objets donne la page (ObjID_collision).
collision.orbGate.open  EXTERNAL
collision.orbGate.close EXTERNAL
tube0             EXTERNAL
tube1             EXTERNAL
tube2             EXTERNAL
tube3             EXTERNAL
; 19 — le curseur du script d'emission des ouvertures, en octets.
gomander.orbCursor equ ext_variables+19


; --- la chronologie arcade, en trames ----------------------------------------
gomander.ORB_FIRST   equ $01E0           ; a265 : 480, la premiere ouverture
gomander.ORB_OPEN    equ $00E0           ; 224, les suivantes
gomander.PHASE       equ 15              ; a2a3 / a2cd : les deux demi-phases
gomander.WINDOW      equ 30              ; la fenetre VULNERABLE (OrbArm).
                                         ; L'arcade dit 15 — mais a 60 fps ce
                                         ; sont 15 passes de collision, la ou
                                         ; notre frameDrop n'en laisse que 2.
                                         ; Doublee (decision auteur, 31/08) :
                                         ; ~4 passes, le rythme du cycle
                                         ; inchange.
gomander.ENGULF      equ 15              ; a2da : la TRAVERSEE apres un coup
                                         ; dure 15 trames — le « 224 » est
                                         ; l'attente OrbOpen qui SUIT (a3ea),
                                         ; pas l'engloutissement lui-meme
gomander.ORB_IDLE    equ 15              ; a3a6 : l'attente entre deux pulses
                                         ; sans coup — l'oeil bat toutes les
                                         ; 49 trames, pas toutes les 284
gomander.DEATH_2NDBLAST equ $0100        ; a52b : la 2e deflagration de la mort
gomander.WAVE_FIRST  equ $0164           ; a260 : 356, le premier serpent
gomander.LATCH       equ $1740           ; a424 : le niveau enchaine
gomander.TIMEOUT     equ $1780           ; a465 : delai depasse, aucun score
gomander.DEATH       equ $0180           ; a518 : 384 trames de mort
gomander.DEATH_LATCH equ $0080           ; a534 : le niveau enchaine

; --- les indices de routine ---------------------------------------------------
gomander.rt.orbOpen  equ 1
gomander.rt.phaseA   equ 2
gomander.rt.orbArm   equ 3
gomander.rt.phaseB   equ 4
gomander.rt.engulf   equ 5
gomander.rt.death    equ 6
gomander.rt.deleted  equ 7

gomander.Object
        lda   routine,u
        asla
        ldx   #gomander.Routines
        jmp   [a,x]

gomander.Routines
        fdb   gomander.Init
        fdb   gomander.OrbOpen         ; 40:a290 _tick_orb_open
        fdb   gomander.PhaseA          ; 40:a334 _tick_engulf_phase_a
        fdb   gomander.OrbArm          ; 40:a2b0 _tick_orb_arm_engulf
        fdb   gomander.PhaseB          ; 40:a375 _tick_engulf_phase_b
        fdb   gomander.Engulf          ; 40:a3b3 _tick_engulf_loop
        fdb   gomander.Death           ; 40:a523 _tick_death_sequence
        fdb   gomander.Deleted

gomander.Init
        ; a249 / a24e : (512, 260) en coordonnees ECRAN arcade. Conv donne
        ; (80, 103) ; le scroll etant fige des cette trame, l'ecran et le
        ; playfield ne divergeront plus.
        ldd   glb_camera_x_pos
        addd  #80
        std   x_pos,u
        ldd   #103
        std   y_pos,u
        ; Rien a dessiner : priorite 0, et aucun DisplaySprite dans ce fichier.
        clr   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ; a23d : le boss fige le defilement — et il ne repartira JAMAIS
        ; visiblement : la fin arcade se joue sur place (Finish pose
        ; scroll_max sur la camera), l'ancienne sauvegarde de vitesse a
        ; disparu avec le scroll-out.
        ldd   #0
        std   scroll_vel
        ; (d2nd part a zero gratuitement : LoadObject zere l'OST)
        ; LA PORTE SE REFERME D'OFFICE : un checkpoint ne recharge pas la
        ; carte depuis la disquette — mourir pendant la fenetre laissait le
        ; trou ouvert pour toute la reprise.
        jsr   gomander.GateClose
        ; a256 : 8 PV. La boite est celle de l'orbe (1000:54ea).
        _Collision_AddAABB gomander.AABB,AABB_list_target
        _ldd  gomander_hitbox_x,gomander_hitbox_y
        std   gomander.AABB+AABB.rx,u
        lda   #gomander_hitdamage
        sta   gomander.hp,u
        sta   gomander.AABB+AABB.p,u
        jsr   gomander.Shield          ; l'attente qui suit est invulnerable :
                                       ; sans ca la boite porte les PV des la
                                       ; premiere trame, oeil ferme
        ; La POSITION de la boite — oubliee a la premiere passe : cx/cy ne
        ; sortaient jamais des residus du slot, l'orbe collisionnait n'importe
        ; ou. Le boss est immobile et le scroll fige : une ecriture suffit.
        ; cx/cy parlent le repere 0-base des autres boites (x - camera, y).
        _ldd  80,103
        std   gomander.AABB+AABB.cx,u
        ; a26a / a260 / a265 : les trois horloges. Les trames perdues avant la
        ; creation, deposees par ObjectWave, avancent le combat d'autant.
        ldb   wave_frame_drop,u
        clra
        std   gomander.combat,u
        ldd   #gomander.WAVE_FIRST
        subb  wave_frame_drop,u
        sbca  #0
        std   gomander.delay,u
        clr   gomander.cursor,u
        ldd   #gomander.ORB_FIRST
        std   gomander.timer,u
        lda   #gomander.rt.orbOpen
        sta   routine,u
        clr   gomander.orbCursor,u     ; le script des ouvertures part au debut

        ; L'orbe part OUVERT : l'etat OrbOpen suit, et la carte doit le montrer
        ; des maintenant. On pose l'image 0 sans faire tourner d'horloge — la
        ; sequence ne demarre qu'a la phase A.
        ; EN FIN D'INIT, et pas au milieu : tilemap.anim.start clobbe A et U,
        ; et la premiere version s'inserait entre le `lda #gomander_hitdamage`
        ; et le SECOND `sta` qui le consomme (la boite recevait n'importe quoi),
        ; en empilant U APRES l'avoir charge (le `puls u` rendait alors
        ; l'adresse d'engulf.odd, et tout le reste de l'init ecrivait dedans).
        lda   #tanim.BACKWARD          ; l'oeil part FERME : a l'envers, `arm`
        jsr   gomander.EyeArm          ; pose la derniere image — arm/request
        rts                            ; preservent U (clobbent a, b, x, y)

; --- orbe ouvert : 224 trames, VULNERABLE (40:a290) --------------------------
gomander.OrbOpen
        ; PAS de HitCheck ici : _tick_orb_open (40:a290) ne teste que les PV
        ; epuises, et n'appelle ni le rendu de l'orbe ni la collision (0xf7e4)
        ; — contrairement au prologue a278 et a _tick_orb_arm_engulf. Le boss
        ; n'est donc PAS touchable pendant cette attente. L'y laisser touchable
        ; declenchait le flash pendant que l'oeil est ferme, ce qui n'a de sens
        ; ni pour le joueur ni face a l'arcade.
        jsr   gomander.Countdown
        lbgt  gomander.CombatJoin
        ldd   #gomander.PHASE          ; a2a3
        std   gomander.timer,u
        ; L'OEIL S'OUVRE. Le sens a ete inverse le 21/08/2026 : la seule
        ; fenetre VULNERABLE est l'etat suivant, OrbArm (15 trames, `Expose`),
        ; et c'est donc la que l'oeil doit etre ouvert. `OrbOpen`, malgre son
        ; nom, est la longue attente INVULNERABLE — 224 a 480 trames. Le sens
        ; d'origine, calque sur la table `fwd` de l'arcade, laissait l'oeil
        ; ouvert pendant l'attente et ferme pendant la fenetre de tir.
        lda   #tanim.BACKWARD          ; ferme -> ouvert
        jsr   gomander.EyeArm
        lda   #gomander.rt.phaseA
        sta   routine,u
        lda   gomander.hp,u            ; les phases tube ENCAISSENT (le pod
        sta   gomander.AABB+AABB.p,u   ; broie), seule l'attente est a l'abri
        lbra  gomander.CombatJoin

; --- phase A : 15 trames d'animation, boite ACTIVE (queue a278) --------------
gomander.PhaseA
        jsr   gomander.HitCheck        ; la queue commune arcade teste ici aussi
        jsr   gomander.EyeStep         ; l'horloge du decor, sur l'OST du boss
        jsr   gomander.Countdown
        lbgt  gomander.CombatJoin
        ldd   #gomander.WINDOW         ; a2cd (15 arcade -> 30, voir l'equate)
        std   gomander.timer,u
        lda   #gomander.rt.orbArm
        sta   routine,u
        jsr   gomander.GateOpen        ; l'oeil est ouvert : le decor s'ouvre
        lbra  gomander.CombatJoin      ; (la boite, elle, encaisse deja)

; --- orbe arme : 15 trames, VULNERABLE (40:a2b0) -----------------------------
gomander.OrbArm
        jsr   gomander.HitCheck
        jsr   gomander.Countdown
        lbgt  gomander.CombatJoin
        ldd   #gomander.PHASE
        std   gomander.timer,u
        clra                           ; l'oeil se referme : la meme, a l'endroit
        jsr   gomander.EyeArm
        lda   #gomander.rt.phaseB
        sta   routine,u
        jsr   gomander.GateClose       ; l'oeil se referme : le decor aussi —
        lbra  gomander.CombatJoin      ; la boite, elle, encaisse toujours

; --- phase B : 15 trames d'animation, boite ACTIVE (40:a375) -----------------
gomander.PhaseB
        jsr   gomander.HitCheck        ; la queue commune arcade teste ici aussi
        jsr   gomander.EyeStep         ; l'horloge du decor, sur l'OST du boss
        jsr   gomander.Countdown
        lbgt  gomander.CombatJoin
        ldd   #gomander.ORB_IDLE       ; a3a6 : 15 — le pulse rapide, l'oeil
        jsr   gomander.ReopenOrb       ; rebat dans 49 trames
        lbra  gomander.CombatJoin

; --- engloutissement : 224 trames apres un coup, invulnerable (40:a3b3) ------
gomander.Engulf
        jsr   gomander.HitCheck        ; un coup pendant la traversee la
        jsr   gomander.Countdown       ; RE-ARME — la queue a278 de l'arcade
        lbgt  gomander.CombatJoin
        ldd   #gomander.ORB_OPEN       ; a3ea : 224 — la longue pause qui suit
        jsr   gomander.ReopenOrb       ; un coup encaisse
        lbra  gomander.CombatJoin

gomander.ReopenOrb                     ; D = l'attente OrbOpen : ORB_IDLE au
        std   gomander.timer,u         ;   fil du pulse, ORB_OPEN apres un coup
        lda   #gomander.rt.orbOpen
        sta   routine,u
        ; ET LA BOITE SE REFERME. La cascade tombait ici dans Expose — « les
        ; coups comptent a nouveau » — ce qui etait juste tant qu'OrbOpen
        ; passait pour la fenetre de tir. L'arcade dit l'inverse : a290 n'y
        ; expose pas l'orbe et n'y teste aucun coup frais. Elle se rouvre a
        ; l'entree d'OrbArm, oeil ouvert.
        jmp   gomander.Shield

; La boite prend les PV restants : un tir la fait descendre, HitCheck lit la
; difference — et il ne tourne QUE fenetre ouverte (OrbArm), jamais sous
; bouclier. Hors fenetre la boite passe a ZERO : Collision_Do la saute, le
; tir TRAVERSE sans etre consomme — c'est l'arcade exacte, qui n'appelle
; meme pas la collision pendant les phases tube. (L'ancien bouclier a -128
; etait une boite invincible : elle absorbait les tirs au passage.)
gomander.Shield
        clr   gomander.AABB+AABB.p,u
        rts
; LA PORTE TERRAIN, DECOUPLEE DE L'EXPOSITION (31/08/2026, cadence arcade) :
; la boite encaisse pendant TOUTES les phases tube — la queue commune a278
; de l'arcade teste la collision dans ces etats, c'est ainsi que le pod
; broie en continu — mais le decor n'est traversable que l'oeil
; VISUELLEMENT ouvert (OrbArm).
gomander.GateOpen
        ldd   #collision.orbGate.open
        bra   gomander.orbGate
gomander.GateClose
        ldd   #collision.orbGate.close
gomander.orbGate
        std   PSR_Address
        lda   Obj_Index_Page+ObjID_collision
        sta   PSR_Page
        pshs  u
        jsr   RunPgSubRoutine          ; monte la page de la carte, poke, revient
        puls  u
        rts

; Le compte a rebours de l'etat, en trames video (Z/N poses a la sortie).
gomander.Countdown
        ldd   gomander.timer,u
        subb  gfxlock.frameDrop.count
        sbca  #0
        std   gomander.timer,u
        rts

; a2bd..a2c3 : le coup se lit comme une DIFFERENCE, et il n'en compte qu'un
; par exposition — l'arcade prend son instantane puis part en engloutissement.
gomander.HitCheck
        lda   gomander.AABB+AABB.p,u
        cmpa  gomander.hp,u
        beq   @none                    ; rien de neuf cette trame
        sta   gomander.hp,u            ; a2c0 : instantane des degats
        beq   @dead                    ; PV epuises -> a4cd
        ldd   #gomander.ENGULF         ; a2da : 15 trames de traversee
        std   gomander.timer,u
        lda   #gomander.rt.engulf
        sta   routine,u
        ; PAS de bouclier : l'arcade laisse la boite active pendant toute la
        ; traversee (le pod continue de broyer, un coup re-arme). Seule la
        ; PORTE terrain se referme — l'oeil n'est plus visuellement ouvert.
        jsr   gomander.GateClose
        ; a2e9..a331 : l'arcade seme ici DEUX acteurs de flash de palette
        ; (bancs 7 et 8 -> banc 4, 16 trames, une peinture sur 4). Une seule
        ; palette chez nous et aucune case propre au boss : le flash est un
        ; patch de tuiles recolorees (blink, trame 0 = le decor du niveau,
        ; trame 1 = le blanc/cyan du banc 4). final=0 : le pulse arcade finit
        ; lui aussi sur la palette normale.
        jsr   gomander.Flash
@none   rts
@dead   leas  2,s                      ; on ne revient pas dans l'etat
        lbra  gomander.ArmDeath

; L'animation de l'oeil, factorisee (la page du cast est PLEINE) :
; EyeArm arme l'anim avec A = tanim.flags (0 a l'endroit, BACKWARD a
; l'envers), EyeStep la fait avancer d'un tick.
gomander.EyeArm
        sta   tanim.flags,u
        ldx   #engulf
        lda   #engulf.FRAMES
        ldb   #engulf.HOLD
        jmp   tilemap.anim.arm
gomander.EyeStep
        ldx   #engulf
        lda   #engulf.FRAMES
        ldb   #engulf.HOLD
        jmp   tilemap.animate

; Le flash blink, partage entre le coup encaisse et le strobe d'agonie.
gomander.Flash
        jsr   LoadObject_x
        beq   @ret                     ; pool plein : pas de flash, tant pis
        lda   #ObjID_tilemapanim
        sta   id,x
        ldd   #blink
        std   tanimobj.desc,x
        ldd   #16                      ; [SI+10] arcade : 16 trames
        std   tanimobj.life,x
        clr   tanimobj.final,x
@ret    rts

; La grosse explosion sur le corps, partagee entre la mort et la 2e
; deflagration (l'arcade seme une cascade de 352 trames ; sans corps a
; faire exploser on en pose une a chaque jalon).
gomander.Boom
        jsr   LoadObject_x
        beq   @ret
        _ldd  ObjID_explosion,explosion.subtype.big+explosion.sfx.cascade
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
@ret    rts

; --- la queue commune : chaque etat y saute (40:a3f4) ------------------------
gomander.CombatJoin
        ldb   gfxlock.frameDrop.count  ; a421 : le compteur avance en trames
        clra                           ; video, pour que la duree reelle du
        addd  gomander.combat,u        ; combat soit celle de l'arcade
        std   gomander.combat,u
        cmpd  #gomander.TIMEOUT
        lbhs  gomander.Finish          ; a465 : delai depasse, AUCUN score
        cmpd  #gomander.LATCH
        blo   >
        lda   #1                       ; a440 : end_level_sequence_flag — en v2
        sta   globals.bossDefeated     ; c'est ce drapeau que la sequence lit
!       ; LES OUVERTURES. Elles ne battent PAS en continu : gomander_orb_emission_script
        ; (1000:4d1c) donne dix-sept instants du combat, chacun nommant UN tube,
        ; et l'arcade y cree un objet qui vit ~272 trames en repeignant ce
        ; tube-la (a5c5 / a638). Rapproche du script de vague, ces dix-sept se
        ; rangent en deux familles sans bavure : huit a 24-56 trames d'un
        ; serpent — il SORT — et huit a 336-354 — il RENTRE. Le tube s'ouvre
        ; pour le laisser passer, deux fois par serpent.
        ldb   gomander.orbCursor,u
        cmpb  #gomander.OrbScript.SIZE
        bhs   @tubesDone               ; script epuise
        ldx   #gomander.OrbScript
        abx
        ldd   gomander.combat,u
        cmpd  ,x
        blo   @tubesDone               ; le seuil n'est pas atteint
        pshs  u
        jsr   LoadObject_x
        beq   @noSlot
        lda   #ObjID_tilemapanim
        sta   id,x
        ldu   ,s                       ; l'OST du boss : `pshs u` l'a mis en ,s
                                       ; et non en 2,s — LoadObject_x le clobbe
        ldb   gomander.orbCursor,u
        pshs  x
        ldx   #gomander.OrbScript
        abx
        ldd   2,x                      ; le descripteur du tube
        puls  x
        std   tanimobj.desc,x
        ldd   #gomander.ORB_LIFE
        std   tanimobj.life,x
        lda   #$FF                     ; en mourant, laisser la derniere pose
        sta   tanimobj.final,x         ; peinte — comme le pellet arcade
@noSlot puls  u
        ldb   gomander.orbCursor,u     ; le curseur avance meme sans slot : une
        addb  #4                       ; emission ratee ne doit pas bloquer les
        stb   gomander.orbCursor,u     ; suivantes
@tubesDone
        ; a46c : les serpents.
        jmp   gomander.WaveTick

; --- la wavescript des serpents (40:a5a4) ------------------------------------
gomander.WaveTick
        lda   gomander.cursor,u
        cmpa  #gomander.WaveScript.end-gomander.WaveScript
        bhs   @ret                     ; script epuise
        ldd   gomander.delay,u
        subb  gfxlock.frameDrop.count
        sbca  #0
        std   gomander.delay,u
@due    ldd   gomander.delay,u
        bgt   @ret
        jsr   gomander.WaveSpawn
        lda   gomander.cursor,u
        cmpa  #gomander.WaveScript.end-gomander.WaveScript
        blo   @due                     ; un gros frame drop peut en devoir deux
@ret    rts

gomander.WaveSpawn
        ; Le retard : ce dont le compte a rebours a depasse zero. Il part avec
        ; le serpent dans wave_frame_drop, la ou ObjectWave depose le sien —
        ; l'emetteur d'outslay sait deja le rattraper.
        ldd   gomander.delay,u
        coma
        comb
        addd  #1
        stb   @late
        ldx   #gomander.WaveScript
        ldb   gomander.cursor,u
        abx
        ldb   1,x                      ; le token (octet bas du mot)
        stb   @token
        ldd   2,x                      ; le delai jusqu'au suivant
        cmpd  #$FFFF
        bne   >
        ldd   #$7FFF                   ; le sentinelle de la 8e entree : plus
        std   gomander.delay,u         ; jamais dans la fenetre de combat
        bra   @advance
!       addd  gomander.delay,u         ; recharge en gardant le reste negatif
        std   gomander.delay,u
@advance
        lda   gomander.cursor,u
        adda  #4
        sta   gomander.cursor,u
        jsr   LoadObject_x
        beq   @full                    ; pool plein : le script avance quand meme
        lda   #ObjID_outslay
        sta   id,x
        lda   #0
@token  equ   *-1
        sta   subtype_w+1,x            ; le token, la ou la wave le met : c'est
                                       ; l'octet BAS du subtype 16 bits, lu par
                                       ; l'Init de l'emetteur avant render_flags
        lda   #0
@late   equ   *-1
        sta   wave_frame_drop,x
@full   rts

; --- la mort par les armes (40:a4cd puis 40:a523) ----------------------------
gomander.ArmDeath
        jsr   gomander.GateClose       ; la mort peut tomber porte ouverte
        ldb   #gomander_scoreIdx       ; a4d5 : 0x8718
        jsr   AwardScore
        jsr   gomander.Boom            ; a4db : la cascade arcade, reduite a
                                       ; une explosion par jalon (cf. Boom)
        ldd   #gomander.DEATH          ; a518 : 384 trames
        std   gomander.timer,u
        lda   #gomander.rt.death
        sta   routine,u
        rts                            ; la boite reste en liste, potentiel 0
                                       ; (= desactivee) jusqu'au dechargement

gomander.Death
        jsr   gomander.Countdown
        lble  gomander.Finish          ; a528 : compte a rebours fini
        cmpd  #gomander.DEATH_LATCH
        bls   @finale
        ; a52b : la 2e deflagration, au passage sous $100 — UNE fois
        cmpd  #gomander.DEATH_2NDBLAST
        bhi   @ret
        tst   gomander.d2nd,u
        bne   @ret
        inc   gomander.d2nd,u
        jsr   gomander.Boom            ; a56c : la 2e deflagration
        bra   @ret
@finale
        lda   #1                       ; a545 : le niveau enchaine (fondu,
        sta   globals.bossDefeated     ; autopilote et releve par obj_endlevel)
        ; LA SECOUSSE (a54a : le scroll Y du fond alterne violemment chaque
        ; paire de trames). Notre overlay n'a pas de scroll vertical fin :
        ; V2-DEVIATION, l'agonie est un STROBE du decor — le flash blink
        ; retire toutes les 8 trames pendant les 128 dernieres.
        ldb   gomander.timer+1,u
        andb  #7
        bne   @ret
        jsr   gomander.Flash
@ret    rts

; --- la sortie, commune aux deux chemins (40:a473) ---------------------------
gomander.Finish
        ; a484 relance l'autoscroll — mais l'ecran arcade est alors DEJA fondu
        ; au noir : aucun scroll n'est jamais visible sur ce niveau. La fin se
        ; joue sur place : scroll_max descend SUR la camera (les deux buffers
        ; y reposent, le scroll est fige depuis le spawn), la condition de
        ; glissement d'obj_endlevel est vraie immediatement, et la sequence
        ; commune s'arme sans un pixel de defilement. scroll_vel reste a zero.
        jsr   gomander.GateClose
        ldd   glb_camera_x_pos
        std   scroll_max
        lda   #1
        sta   globals.bossDefeated
        _Collision_RemoveAABB gomander.AABB,AABB_list_target
        lda   #gomander.rt.deleted
        sta   routine,u
        jmp   UnloadObject_u           ; rien n'a ete dessine : pas de DeleteObject

gomander.Deleted
        rts

; 1000:4d62 outslay_wavescript_table — (token, delai) x 8. Les tokens 0..3
; designent les quatre variantes de serpent du combat (voir la table des
; variantes dans outslay/obj.asm) ; aucun ne porte le bit 2, donc l'horloge de
; tir de leur tete vaut $0050 et non $00C0 : ils tirent plus souvent que le
; serpent de la traversee. Le delai de la derniere entree est $FFFF —
; volontairement hors de la fenetre de combat.
gomander.WaveScript
        fdb   2,$03C0                  ; t = 356
        fdb   3,$0240                  ; t = 1316
        fdb   1,$0280                  ; t = 1892
        fdb   0,$0280                  ; t = 2532
        fdb   3,$0240                  ; t = 3172
        fdb   2,$03C0                  ; t = 3748
        fdb   0,$0280                  ; t = 4708
        fdb   1,$FFFF                  ; t = 5348, puis plus rien
gomander.WaveScript.end

* ---------------------------------------------------------------------------
* gomander_orb_emission_script (1000:4d1c), porte a l'identique : dix-sept
* couples (seuil de combat, tube). Les seuils sont en trames video, comme le
* compteur qui les lit.
* ---------------------------------------------------------------------------
gomander.ORB_LIFE equ 272              ; a5eb : 0x110 + (hasard & 3) ; on prend
                                       ; la borne basse, le hasard ne sert qu'a
                                       ; desynchroniser deux vies voisines
gomander.OrbScript
        fdb   $0038,tube0
        fdb   $0162,tube1
        fdb   $03E0,tube0
        fdb   $0510,tube3
        fdb   $0630,tube1
        fdb   $0760,tube2
        fdb   $0898,tube1
        fdb   $09E0,tube0
        fdb   $0B30,tube3
        fdb   $0C60,tube3
        fdb   $0D60,tube1
        fdb   $0EA0,tube1
        fdb   $1120,tube0
        fdb   $1260,tube0
        fdb   $13B0,tube3
        fdb   $14E0,tube2
        fdb   $1620,tube1
gomander.OrbScript.SIZE equ *-gomander.OrbScript
