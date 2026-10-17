;*******************************************************************************
; mikun — FICHE DE PORTAGE (base Ghidra `maincpu`, subsystem mikun, 17/10/2026)
;
; LA LIGNE DE WAVE NE CREE PAS UN MIKUN : elle cree un EMETTEUR INVISIBLE qui
; en lance un a intervalle fixe, vise sur le joueur. 35 lignes au stage 8.
;
;   40:9660 create_mikun_emitter ........ ctor de l'emetteur
;   40:FA90 mikun_emitter_init_position . x 0x2C0, y 0x174 ou 0x9C (bit 4)
;   40:FAA5 mikun_emitter_init_variant .. periode (jeton & 15), compte initial
;   40:9674 run_mikun_emitter ........... son tick : invisible, sans boite
;   40:96E9 run_mikun ................... le mikun visible
;   1000:4284 vitesses par difficulte (le pool du pique du wick, 9010..90D0)
;   1000:428C recettes par direction   1000:436C l'AABB   1000:943C periodes
;   Tables : tools/gen_mikun.py -> tables.asm, depuis la ROM.
;
; L'EMETTEUR. Naissance (704, 372) ou (704, 156) arcade selon le bit 4 du
; jeton -> x = camera + 152, y = 18 ou 180. Son tick ajoute
; scroll_x_bg_delta (0x2ED4) a son x : au stage 8 il vaut scroll_amount
; (0x2ED0) a chaque trame (mesure sous MAME, 3 402 trames, 0 et -1 en
; alternance), donc l'emetteur est ANCRE AU DECOR — repere playfield, aucun
; code de defilement. Il se retire quand son x passe sous 0x140 (320), soit
; l'abscisse ecran 8.
;   La periode vient de 1000:943C[jeton & 15] (320 a 48 trames). Le compte a
; rebours initial est random_ax ET (periode - 1) — un MASQUE, pas un modulo
; (random_ax rejoue a l'identique, voir mikun.Rand) :
; avec 272 (masque $10F) il ne vaut que 0..15 ou 256..271, ce que la trace
; confirme (260, 262, 9, 10, 15, 3 sur les premiers emetteurs). Et un compte
; initial nul ne lance JAMAIS : DEC le porte a $FFFF, l'emetteur sort de
; l'ecran bien avant (fidele, voir mikun.Init).
;   Chaque trame : DEC du compte ; a zero, recharge de la periode et un mikun
; nait a la position de l'emetteur (mots entiers seulement), vise UNE FOIS
; sur le joueur (set_direction_to) : vitesse et poses sont celles de cette
; direction pour toute sa vie.
;
; LE MIKUN. Ligne droite a (vx, vy) fixes — de 2,25 a 3,1 px/trame arcade a
; la difficulte 0, la table de la difficulte courante (globals.difficulty).
; Deux poses par direction (recette, recette + 6), la seconde quand le bit 3
; du compteur global est arme : tous les mikuns battent ensemble, 8 trames
; chacune. Il tourne des sa trame de naissance (il suit l'emetteur dans la
; liste arcade : priorite 0x2010 contre 0x2000), confirme sur la trace.
;   Mort au premier coup (do_collision_v1, pas de PV), AABB 1000:436C
; -9..+9 sur les deux axes -> rayons 3 et 7. Score 0x86EC (indice 1), son
; 0x52, explosion_small_x2 (script 0x8530). Retrait silencieux hors de la
; fenetre is_visible_range (X 300..723, Y 124..403 arcade -> ecran 0..159,
; -6..204).
;
; LA COMPENSATION DE TRAME. Toutes les horloges sont des horloges de JEU ;
; chaque tour avance de gfxlock.frameDrop.count trames. Le compte a rebours
; peut donc lancer PLUSIEURS mikuns dans un tour, et chacun nait a sa trame :
; il emporte le nombre de trames qu'il a deja volees dans ce tour
; (mikun.uLate), de sa naissance comprise.
;
; SYNCHRONISATION AVEC LA BORNE (mesuree le 17/10/2026) : vaisseau immobile
; au meme point des deux cotes (513, 223 arcade), les 104 naissances de
; mikun du stage 8 (horloge 0 a 3100) tombent sur celles de MAME, 1,6 trame
; d'ecart en moyenne et 5 au plus — la granularite du rendu. C'est
; mikun.Rand qui la donne ; le generateur generique les desynchronisait.
;
; PLACE ET CYCLES (mesures sous toje, 17/10/2026)
; - 28 poses avec leur variante decalee d'un pixel (shifts 0,1) : sans elle
;   un mikun ne se pose qu'aux abscisses paires et avance par pas de deux
;   pixels TO8. La variante ne coute AUCUN cycle (BuildSprites choisit sur
;   la parite) ; elle double la place : 21,6 Ko, d'ou deux fichiers —
;   directions 0-7 avec le code (stage8.mikun), 8-15 dans stage8.mikun.img,
;   atteintes par ObjID_mikun_unit2 — dans l'arene stage8.gfx.
; - une pose : 421 a 686 cycles de dessin (559 en moyenne, comptage statique
;   du code compile) ; le vol et l'emetteur quelques centaines de plus.
; - cadence du stage 8 sur 3 800 trames : 10,7 img/s contre 11,6 sans
;   mikun (-8 %), -17 % au plus charge (14 emetteurs, ~10 mikuns, juste
;   avant la salle du boss).
;
; ECARTS ASSUMES
; - la fraction des positions : l'arcade ne copie que les mots entiers et
;   laisse l'octet de fraction de l'occupant precedent du slot (mesure : 14,
;   226…), le portage part de zero ;
; - la phase du compteur global de la borne, dont dependent les comptes
;   initiaux (mikun.Rand), est celle de l'etat d'entree de reference : en
;   partie reelle sur la borne elle depend du temps deja joue ;
; - le retard de wave de l'emetteur ne decale pas son x : la camera parcourt
;   0,1875 px par trame, au plus ~1 px — il avance en revanche son compte a
;   rebours (mikun.Init), dont la cadence de toute la nuee depend ;
; - la visee et le retrait de l'emetteur se font avec les positions du tour,
;   pas de la trame exacte du lancement (granularite du frame drop) ;
; - palettes par objet (0x60, explosion 0x6B) : abandonnees, palette TO8
;   globale du stage.
;*******************************************************************************

; --- l'emetteur ---------------------------------------------------------------
mikun.ePeriod   equ ext_variables      ; 0,1   periode d'emission
mikun.eCount    equ ext_variables+2    ; 2,3   compte a rebours, NON signe
; --- le mikun visible ---------------------------------------------------------
mikun.uAABB     equ ext_variables      ; 0..8  la boite
mikun.uVx       equ ext_variables+9    ; 9,10  vitesse 8.8 v2
mikun.uVy       equ ext_variables+11   ; 11,12
mikun.uPoses    equ ext_variables+13   ; 13,14 ses deux poses (mikun.Poses+dir)
mikun.uLate     equ ext_variables+15   ; 15,16 trames volees dans son tour de
                                       ;       naissance, la sienne comprise

mikun.SPAWNX    equ 152                ; arcade 704 : (704-320) x 0,375 + 8
mikun.Y_LOW     equ 18                 ; arcade 372 : 297 - 0,75 x 372
mikun.Y_HIGH    equ 180                ; arcade 156 : 297 - 0,75 x 156
mikun.LEFT      equ 8                  ; arcade 320 : le retrait de l'emetteur

;*******************************************************************************
; L'EMETTEUR — invisible, sans boite, ancre au decor.
;*******************************************************************************
mikun.Object
        lda   routine,u
        asla
        ldx   #mikun.Routines
        jmp   [a,x]
mikun.Routines
        fdb   mikun.Init
        fdb   mikun.Live
        fdb   mikun.Deleted

mikun.Init
        ; le jeton AVANT render_flags (il en partage l'octet), le retard de
        ; wave avant tout le reste (il aliase anim_frame_duration)
        ldb   wave_frame_drop,u
        clra
        std   mikun.drop
        ldb   subtype_w+1,u
        stb   mikun.tok
        clr   priority,u               ; il ne se dessine pas
        clr   render_flags,u
        ; fa90 : y 0x174 (bit 4 clair) ou 0x9C, x 0x2C0
        lda   mikun.tok
        bita  #$10
        bne   >
        ldd   #mikun.Y_LOW
        bra   @y
!       ldd   #mikun.Y_HIGH
@y      std   y_pos,u
        clr   y_pos+2,u
        ldd   glb_camera_x_pos
        addd  #mikun.SPAWNX
        std   x_pos,u
        clr   x_pos+2,u
        ; faa5 : periode = 943C[jeton & 15], compte = random_ax ET (periode-1)
        ldb   mikun.tok
        andb  #$0F
        aslb
        ldx   #mikun.Periods
        abx
        ldd   ,x
        std   mikun.ePeriod,u
        subd  #1
        std   mikun.tmp
        ldd   gfxlock.frame.gameCount  ; la trame arcade du tirage : celle de
        subd  mikun.drop               ; la ligne de wave, retard deduit
        jsr   mikun.Rand
        anda  mikun.tmp
        andb  mikun.tmp+1
        std   mikun.eCount,u
        bne   >
        ; un compte nul : le premier DEC le porte a $FFFF, et l'emetteur a
        ; quitte l'ecran bien avant d'y revenir — il ne lancera jamais
        ldd   #$FFFF
        std   mikun.eCount,u
!       inc   routine,u
        ; le retard de wave : les trames qu'il a deja vecues
        jmp   mikun.Emit

mikun.Live
        jsr   mikun.Frame
        jsr   mikun.Emit
        ; 96d6 : CMP pos_x,0x140 / JC unload
        ldd   x_pos,u
        subd  glb_camera_x_pos
        cmpd  #mikun.LEFT
        blt   mikun.Gone
        rts
mikun.Gone
        lda   #2
        sta   routine,u
        jmp   DeleteObject
mikun.Deleted
        rts

; -----------------------------------------------------------------------------
; Le compte a rebours sur mikun.drop trames de jeu. Il est NON signe et
; s'annule a l'arcade apres un DEC : la trame de lancement est donc la
; cd-ieme du tour, et le mikun y vit drop - cd + 1 trames, la sienne
; comprise. Puis la periode recharge et le reste du tour la decompte.
; -----------------------------------------------------------------------------
mikun.Emit
        ldd   mikun.eCount,u
@loop   cmpd  mikun.drop
        bhi   @wait                    ; il ne s'annule pas dans ce tour
        std   mikun.tmp                ; il s'annule a la trame cd
        ldd   mikun.drop
        subd  mikun.tmp
        std   mikun.drop               ; les trames qui suivent le lancement
        addd  #1
        std   mikun.late
        jsr   mikun.Spawn
        ldd   mikun.ePeriod,u          ; 967f : recharge
        bra   @loop
@wait   subd  mikun.drop
        std   mikun.eCount,u
        rts

; -----------------------------------------------------------------------------
; 9685 : le lancement. Position de l'emetteur (mots entiers), direction du
; joueur echantillonnee une fois, vitesse par (difficulte, direction), poses
; par direction.
; -----------------------------------------------------------------------------
mikun.Spawn
        jsr   LoadObject_x
        beq   @rts                     ; 968e : pool plein, lancement perdu
        lda   #ObjID_mikun_unit
        sta   id,x
        clr   routine,x
        ldd   x_pos,u                  ; 9690
        std   x_pos,x
        clr   x_pos+2,x
        ldd   y_pos,u
        std   y_pos,x
        clr   y_pos+2,x
        ldd   mikun.late
        std   mikun.uLate,x
        stx   mikun.child
        ldx   #player1                 ; 969d BX = PlayerOne
        jsr   setDirectionTo           ; Y = direction, 0..60 par pas de 4
        ldx   mikun.child
        tfr   y,d
        andb  #$3C
        stb   mikun.dir
        ; 96a6 : la table de la difficulte, + la direction (4 octets chacune)
        lda   globals.difficulty
        anda  #3
        ldb   #64
        mul
        addb  mikun.dir
        adca  #0
        addd  #mikun.Vel
        tfr   d,y
        ldd   ,y                       ; 96b5 vx
        std   mikun.uVx,x
        ldd   2,y                      ; 96bb vy
        std   mikun.uVy,x
        ldb   mikun.dir                ; 96c2 : direction/2 dans 428C — ici
        clra                           ; deux poses de deux octets, l'offset
        addd  #mikun.Poses             ; EST la direction
        std   mikun.uPoses,x
        ; les poses des directions 8 a 15 vivent dans stage8.mikun.img : meme
        ; code, autre identifiant, pour que BuildSprites monte leur page
        ldb   mikun.dir
        cmpb  #mikun.DIR_IMG2
        blo   >
        lda   #ObjID_mikun_unit2
        sta   id,x
!
        ;96ce MOV AL,0x60 / CALL get_palette_id — palette globale du stage
@rts    rts

; -----------------------------------------------------------------------------
; 40:EDE9 random_ax, COPIE PRIVEE. Pendant tout le stage 8, l'emetteur est le
; SEUL a tirer (trace MAME, PILOT_RNGLOG : 32 tirages, tous de 40:FABB), et la
; borne reensemence le generateur a (5,1,3) chaque fois que son compteur
; global passe un multiple de 512 (40:021D). La suite des comptes initiaux est
; donc fixee par la trame de chaque tirage, et c'est ce qui fait apparaitre
; les mikuns aux memes instants que sur la borne.
;   Le compteur global de la borne ne repart jamais a zero (40:0219 est son
; seul ecrivain) : sa phase a l'entree du stage depend de toute la partie.
; On prend celle de l'etat d'entree de reference (sta/rtype/stage8.sta,
; compteur 7834 a l'horloge de stage 0) : seule la valeur modulo 512 compte.
; D = horloge de stage de la trame du tirage
; -> D = AX : A = AH (l'ancien c), B = AL (le nouvel a)
; -----------------------------------------------------------------------------
mikun.Rand
        addd  #mikun.GC0&511           ; le compteur global de la borne
        lsra                           ; A = compteur / 512
        cmpa  mikun.epoch
        beq   @draw
        sta   mikun.epoch              ; un multiple de 512 passe depuis le
        ldd   #$0501                   ; tirage precedent : 40:EDD9
        std   mikun.rng                ; init_random_seed
        lda   #3
        sta   mikun.rng+2
@draw   ldd   mikun.rng+1              ; A = b, B = c
        pshs  b
        sta   mikun.rng+2              ; c := b
        adda  ,s                       ; nouvel a = b + c
        ldb   mikun.rng
        stb   mikun.rng+1              ; b := a
        sta   mikun.rng                ; a := nouvel a
        tfr   a,b                      ; AL = nouvel a
        puls  a,pc                     ; AH = ancien c

mikun.GC0       equ 7834               ; compteur global a l'entree du stage 8
mikun.rng       fcb 5,1,3              ; random_ax a, b, c (0x2F28)
mikun.epoch     fcb $FF                ; compteur / 512 du dernier tirage

; -----------------------------------------------------------------------------
; L'ouverture de tour, commune : le compte de trames de JEU de ce tour.
; -----------------------------------------------------------------------------
mikun.Frame
        ldb   gfxlock.frameDrop.count
        bne   >
        incb                           ; miroir du garde de runByFrameDrop
!       clra
        std   mikun.drop
        rts

mikun.drop      fdb 0
mikun.late      fdb 0
mikun.tmp       fdb 0
mikun.child     fdb 0
mikun.tok       fcb 0
mikun.dir       fcb 0

;*******************************************************************************
; LE MIKUN VISIBLE — ligne droite, repere playfield.
;*******************************************************************************
mikun.Unit
        lda   routine,u
        asla
        ldx   #mikun.UnitRoutines
        jmp   [a,x]
mikun.UnitRoutines
        fdb   mikun.UnitInit
        fdb   mikun.Fly
        fdb   mikun.UnitDeleted

mikun.UnitInit
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldb   #6
        stb   priority,u
        _Collision_AddAABB mikun.uAABB,AABB_list_ennemy
        lda   #mikun_hitdamage
        sta   mikun.uAABB+AABB.p,u
        _ldd  mikun_hitbox_x,mikun_hitbox_y
        std   mikun.uAABB+AABB.rx,u
        inc   routine,u
        ; PAS DE RTS : il vole des sa trame de naissance, et rattrape les
        ; trames du tour qui l'ont suivie
        ldd   mikun.uLate,u
        std   mikun.drop
        bra   mikun.FlyBody

mikun.Fly
        jsr   mikun.Frame
mikun.FlyBody
        lda   mikun.uAABB+AABB.p,u     ; 970c : touche -> explosion
        beq   mikun.Boom
        ldd   mikun.uVx,u              ; 96e9 move_x_pos_8_8
        leax  x_pos,u
        jsr   mikun.AddPos
        ldd   mikun.uVy,u              ; 96ef move_y_pos_8_8
        leax  y_pos,u
        jsr   mikun.AddPos
        ; 96f5 : la pose, la seconde quand le bit 3 du compteur global est arme
        ldx   mikun.uPoses,u
        lda   gfxlock.frame.gameCount+1
        bita  #8
        beq   >
        leax  2,x
!       ldd   ,x
        std   image_set,u
        ; 9715 is_visible_range : X 300..723, Y 124..403 -> ecran 0..159,
        ; -6..204, comme le wick
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   mikun.uAABB+AABB.cx,u
        cmpd  #159
        bhi   mikun.Vanish
        ldd   y_pos,u
        stb   mikun.uAABB+AABB.cy,u
        addd  #6
        cmpd  #204+6
        bhi   mikun.Vanish
        jmp   DisplaySprite

; 9728 : score 0x86EC, son 0x52, explosion_small_x2 (script 0x8530)
mikun.Boom
        ldb   #mikun_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        beq   mikun.Vanish
        _ldd  ObjID_explosion,explosion.subtype.smallx2+explosion.sfx.turret
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
; 971b : retrait silencieux (clear_missile_homing_targets, unload_palette :
; sans objet ici)
mikun.Vanish
        lda   #2
        sta   routine,u
        _Collision_RemoveAABB mikun.uAABB,AABB_list_ennemy
        jmp   DeleteObject
mikun.UnitDeleted
        rts

; -----------------------------------------------------------------------------
; Deplacer de la vitesse 8.8 en D, multipliee par mikun.drop, sur le champ
; pointe par X (haut, bas, fraction) : deux `mul` non signes, le produit
; tronque a seize bits etant juste en complement a deux (|v| <= 600 et
; drop <= 54 tiennent). Le geste de wick.AddPos.
; -----------------------------------------------------------------------------
mikun.AddPos
        pshs  a
        lda   mikun.drop+1
        mul
        std   mikun.tmp
        puls  a
        ldb   mikun.drop+1
        mul
        tfr   b,a
        clrb
        addd  mikun.tmp
        pshs  d
        ldb   ,s
        sex
        sta   @a+1
        puls  d
        addd  1,x
        std   1,x
        lda   ,x
@a      adca  #$00
        sta   ,x
        rts

        INCLUDE "src/enemies/mikun/tables.asm"
