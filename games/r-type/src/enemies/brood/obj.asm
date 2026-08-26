;*******************************************************************************
; brood — SQUELETTE, avec sa FICHE DE PORTAGE complete (relevee le 26/08/2026)
;
; Organisme FIXE monte sur la paroi, qui ouvre la gueule et crache des
; parasites ZOID. Deux lignes de wave au stage 2, une par orientation :
;   $06,$E0 octet $01 -> sol,     gueule vers le HAUT
;   $08,$B4 octet $00 -> plafond, gueule vers le BAS
; Alias v1 : baldur (la wave v1 ecrivait ObjID_baldur ; le catalog arcade et
; routines.yaml disent brood).
;
; FICHE DE PORTAGE (base Ghidra `maincpu`, subsystems brood et zoid)
; -------------------------------------------------------------------------
;   40:7d68 create_brood ............... le spawner
;   40:7dbb run_brood ................. entree, attend d'etre a l'ecran
;   40:7e18 .... settle    40:7e80 idle_a   40:7eeb spawn
;   40:7f49 idle_b         40:7fad exit_wait
;   40:7fff brood_destroyed   40:8022 brood_unload_silent
;   40:8058 create_zoid ............... la ponte, trois creneaux
;   40:8d85 run_zoid_egg   40:8dc6 hatch   40:8e15 parasite
;   40:8efa zoid_retarget  40:8ecc zoid_recoil_on_hit
;   1000:37de presets d'orientation   37e6 les poses ENTRELACEES
;   1000:3846 les boites par orientation
;   1000:3ee6 les seize destinations de rodage   3f6e la boite du zoid
;
; L'ORIENTATION N'EST PAS UNE VARIANTE COMME UNE AUTRE : le bit 0 de l'octet
; de wave choisit un MONTAGE, et il commande a la fois l'ordonnee de
; naissance, la rangee de poses et la boite de collision.
;   orientation 0 : y arcade 368 -> 21   (plafond, gueule en bas)
;   orientation 1 : y arcade 160 -> 177  (sol, gueule en haut)
; X est fixe a $02D0 comme le gouger — soit 158 chez nous.
;
; LES POSES SONT ENTRELACEES, et c'est ce qui rend la table lisible :
; brood_anim_frames_interleaved (1000:37e6) alterne les deux orientations,
;   [0] plafond ferme   [1] sol ferme     [2] plafond entrouvert  [3] sol ...
;   [6] plafond GUEULE OUVERTE            [7] sol GUEULE OUVERTE
; Nos huit PNG sortent de cette table meme (000_0137e6.png et suivants) :
; l'index d'image vaut donc directement `trame x 2 + orientation`. Rien a
; remapper — pour une fois.
;
; LES BOITES sont ASYMETRIQUES et differentes par orientation (1000:3846) :
;   plafond : x -24..+24  y -16..+32 arcade -> rayon 9 et 18, centre a -6
;   sol     : x -24..+24  y -32..+16        -> rayon 9 et 18, centre a +6
; L'axe Y arcade monte : le corps est du cote de la paroi dans les deux cas.
; Notre AABB portant un centre et des rayons, le decalage se pose sur cy.
;
; LA CHAINE DE PHASES. Chacune defile avec la carte, dessine, teste la
; collision, teste les PV (40) et fait descendre un compteur :
;   entree    attend x < $0270 (entre a l'ecran), puis compteur = 8
;   settle    DESCEND de compteur*4-2 px par trame, 8 trames — une chute qui
;             ralentit, l'organisme se pose sur la paroi. Puis compteur = $3F
;   idle_a    63 trames d'OUVERTURE de gueule : l'offset d'animation vaut
;             (-compteur & $30) x 1,5 et parcourt 0, 24, 48, 72
;   spawn     192 trames GUEULE OUVERTE, pose fixe ; create_zoid est appele a
;             chaque trame mais ne pond qu'a trois valeurs precises du
;             compteur — $C0, $80 et $40
;   idle_b    63 trames de FERMETURE, l'offset parcourt 72, 48, 24, 0
;   exit_wait defile jusqu'a x < $0130, puis retrait silencieux
; Mort : son 0x52, score $8700, grosse explosion gris-brun (40:e817).
;
; LA PONTE, ET SON PIEGE DE DIFFICULTE. Trois creneaux, mais le troisieme
; ($40) est conditionne a une difficulte non nulle. A la difficulte 0, celle
; du reste du cast, UN BROOD NE POND QUE DEUX ZOIDS. Le troisieme n'existe
; pas chez nous, et ce n'est pas une simplification.
;
; LE ZOID, trois phases et DEUX ANCRAGES — le cas que la skill signale :
;   oeuf      suit le decor (il lit 0x2ED0), avance sur un script de
;             deplacement, quatre poses tenues quatre trames. Il eclot a la
;             FIN DU SCRIPT ou au premier coup encaisse, ce qui arrive en
;             premier. Puis 31 trames d'eclosion.
;   eclosion  IMMOBILE, quatre poses tenues huit trames, index pris dans les
;             bits hauts du compte a rebours. Invulnerable : le resultat de
;             la collision est jete. A la fin : 4 PV, et il passe parasite.
;   parasite  NE SUIT PLUS LE DECOR — verifie sur les octets, son tick
;             n'ouvre pas sur `a1 d0 2e`. Il rode en coordonnees ECRAN, ce
;             que confirment ses seize destinations, toutes des positions
;             d'ecran. Vitesse 8.8, quatre poses tenues huit trames.
;
; LE RODAGE (zoid_retarget) est une jolie mecanique a un verrou :
;   . il tire une destination au hasard parmi seize, et pose
;     vx = (cible_x - x) << 1, vy de meme — soit un pas de delta/128 par
;     trame : il ARRIVE juste quand le compte a rebours de 128 trames expire.
;   . une fois sur quatre, il arme un verrou pour le PROCHAIN rodage, qui
;     visera alors le JOUEUR au lieu de la table. Le verrou est a un coup :
;     il se consomme et ne colle jamais.
; Soit environ trois rodages au hasard pour un rodage sur le joueur.
;
; CE QUI DEMANDERA UN ARBITRAGE
; - les sons (0x5D ponte, 0x57 coup, 0x52 mort) : aucun dans ce portage.
; - le clignotement de coup passe par une palette d'objet, globale chez nous :
;   meme choix que le serpent et le gouger, une image blanche ou rien.
; - `still-open` etait un dossier d'images VIDE, laisse par un export : retire.
;*******************************************************************************
; -----------------------------------------------------------------------------
; L'ETAT
; -----------------------------------------------------------------------------
brood.AABB      equ ext_variables      ; 0..8  la boite
brood.orient    equ ext_variables+9    ; 9     0 = plafond, 1 = sol
brood.count     equ ext_variables+10   ; 10,11 le compteur de phase
brood.frame     equ ext_variables+12   ; 12    l'index de pose, 0..3
brood.lastP     equ ext_variables+13   ; 13    dernier potentiel vu (coup ?)
brood.blink     equ ext_variables+14   ; 14    compteur d'eclat blanc (+0x3d)

brood.SPAWNX    equ 144+8+6            ; arcade $02D0, comme le gouger
brood.ENTRY     equ 122                ; arcade $0270 : entre dans le cadre
brood.EXIT      equ 2                  ; arcade $0130 : sorti par la gauche
brood.SETTLE    equ 384                ; 2 px arcade/trame en 8.8 v2 (x 0,75)
brood.OPENING   equ $3F                ; 63 trames d'ouverture, et de fermeture
brood.SPAWNING  equ $C0                ; 192 trames gueule ouverte

brood.Object
        lda   routine,u
        asla
        ldx   #brood.Routines
        jmp   [a,x]
brood.Routines
        fdb   brood.Init
        fdb   brood.Entry
        fdb   brood.Settle
        fdb   brood.IdleA
        fdb   brood.Spawn
        fdb   brood.IdleB
        fdb   brood.Exit
        fdb   brood.Deleted

; -----------------------------------------------------------------------------
brood.Init
        ldb   subtype_w+1,u            ; le 5e octet du descripteur de wave
        andb  #1                       ; bit 0 : le MONTAGE
        stb   brood.orient,u
        aslb
        ldx   #brood.PresetY
        abx
        ldd   ,x
        std   y_pos,u
        ldd   glb_camera_x_pos
        addd  #brood.SPAWNX
        std   x_pos,u
        clr   x_pos+2,u
        clr   y_pos+2,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldb   #6
        stb   priority,u
        _Collision_AddAABB brood.AABB,AABB_list_ennemy
        lda   #brood_hitdamage
        sta   brood.AABB+AABB.p,u
        _ldd  brood_hitbox_x,brood_hitbox_y
        std   brood.AABB+AABB.rx,u
        clr   brood.frame,u
        lda   #brood_hitdamage
        sta   brood.lastP,u
        clr   brood.blink,u
        ldd   #0
        std   brood.count,u
        inc   routine,u
        rts

; --- 1) l'entree : il defile jusqu'a etre dans le cadre ----------------------
brood.Entry
        jsr   brood.Frame
        lbne  brood.Gone
        ldd   x_pos,u
        subd  glb_camera_x_pos
        cmpd  #brood.ENTRY
        lbhs  brood.Show               ; pas encore : il attend en defilant
        ldd   #8
        std   brood.count,u
        inc   routine,u
        lbra  brood.Show

; --- 2) la chute : il emerge de la paroi, 8 trames --------------------------
; L'arcade ecrit `orientation x 4 - 2`, PAS `compteur x 4 - 2` comme l'annonce
; sa plate — les deux lectures de [BP+0x28] du meme bloc le montrent, la
; seconde etant commentee « BX = variant ». C'est donc une constante par
; montage, +/-2 px arcade par trame : le plafond descend, le sol remonte, et
; l'organisme sort du mur de douze pixels en huit trames.
brood.Settle
        jsr   brood.Frame
        lbne  brood.Gone
        ldd   #brood.SETTLE
        tst   brood.orient,u
        beq   >
        ldd   #-brood.SETTLE           ; il remonte, sur le sol
!       leax  y_pos,u
        jsr   brood.AddPos
        jsr   brood.Tick
        lbne  brood.Show
        ldd   #brood.OPENING
        std   brood.count,u
        inc   routine,u
        lbra  brood.Show

; --- 3) l'ouverture de la gueule, 63 trames ---------------------------------
; L'index de pose vient des bits 4-5 du COMPLEMENT du compteur : il monte de 0
; a 3 pendant que le compteur descend.
brood.IdleA
        jsr   brood.Frame
        lbne  brood.Gone
        ldb   brood.count+1,u
        negb
        lsrb
        lsrb
        lsrb
        lsrb
        andb  #3
        stb   brood.frame,u
        jsr   brood.Tick
        lbne  brood.Show
        ldd   #brood.SPAWNING
        std   brood.count,u
        inc   routine,u
        lbra  brood.Show

; --- 4) la ponte, 192 trames gueule ouverte ---------------------------------
brood.Spawn
        jsr   brood.Frame
        lbne  brood.Gone
        lda   #3                       ; la pose « gueule ouverte », figee
        sta   brood.frame,u
        ldd   brood.count,u
        std   brood.was                ; le compteur AVANT le decompte
        jsr   brood.Tick
        pshs  cc
        jsr   brood.Hatch
        puls  cc
        lbne  brood.Show
        ldd   #brood.OPENING
        std   brood.count,u
        inc   routine,u
        lbra  brood.Show

; --- 5) la fermeture, 63 trames ---------------------------------------------
brood.IdleB
        jsr   brood.Frame
        lbne  brood.Gone
        ldb   brood.count+1,u
        lsrb
        lsrb
        lsrb
        lsrb
        andb  #3
        stb   brood.frame,u
        jsr   brood.Tick
        lbne  brood.Show
        inc   routine,u                ; pas de compteur : il attend de sortir
        lbra  brood.Show

; --- 6) la sortie ------------------------------------------------------------
brood.Exit
        jsr   brood.Frame
        lbne  brood.Gone
        ldd   x_pos,u
        subd  glb_camera_x_pos
        cmpd  #brood.EXIT
        lbhs  brood.Show
        lbra  brood.Gone               ; retrait silencieux

brood.Deleted
        rts

; -----------------------------------------------------------------------------
; LA PONTE. L'arcade appelle son spawner a CHAQUE trame et c'est lui qui se
; limite a trois valeurs du compteur : $C0, $80 et $40. Avec la compensation de
; trame le compteur SAUTE de plusieurs unites, donc le creneau ne s'atteint
; pas, il se FRANCHIT — on pond si le seuil est tombe entre l'avant et l'apres.
; Le troisieme creneau est refuse en difficulte 0 : un brood n'y pond que DEUX
; zoids. Voir doc/arcade-difficulty-reference.md.
; -----------------------------------------------------------------------------
brood.Hatch
        ldx   #brood.Slots
@loop   ldd   ,x++
        beq   @rts
        cmpd  brood.was
        bhi   @loop                    ; le seuil est au-dessus du depart
        cmpd  brood.count,u
        bls   @loop                    ; pas encore franchi
        cmpd  #$40
        bne   @pond
        tst   globals.difficulty       ; le troisieme, seulement au-dela de 0
        beq   @loop
@pond   pshs  x
        jsr   brood.Egg
        puls  x
        bra   @loop
@rts    rts

; La ponte elle-meme (create_zoid 40:8058, moins le choix de creneau et la
; garde de difficulte, deja faits par brood.Hatch). A l'entree : D = le seuil
; franchi, X pointe APRES lui dans brood.Slots, U = le brood.
; L'oeuf nait a la position du parent (80c2/80c8) et recoit deux graines que
; l'init du zoid consommera : l'index de sa liste de segments — base +
; orientation x 6 + creneau x 2, les six listes etant contigues a anim_zoid —
; et son RETARD de ponte (seuil - compteur) : chaque oeuf d'une meme gueule
; rejoue ses propres trames perdues, comme les wicks d'une rafale.
; Abandonne ici : le son de ponte 0x5D et les palettes d'objet (80ce..80de).
brood.Egg
        subd  brood.count,u
        pshs  b                        ; le retard, <= frame-drop, tient sur un octet
        tfr   x,d
        subd  #brood.Slots+2
        andb  #%00000110               ; B = creneau x 2 (X avait avance de 2)
        pshs  b
        lda   brood.orient,u
        ldb   #6
        mul                            ; B = orientation x 6
        addb  ,s+
        addb  #anim_zoid
        pshs  b                        ; l'index, en attendant l'allocation
        jsr   LoadObject_x
        beq   @full
        lda   #ObjID_zoid
        sta   id,x
        clr   routine,x
        puls  b
        stb   zoid.count,x             ; graine 1 : l'index de script
        puls  b
        stb   zoid.anim,x              ; graine 2 : le retard de naissance
        ldd   x_pos,u                  ; 80c2 : il nait a la gueule du parent
        std   x_pos,x
        clr   x_pos+2,x
        ldd   y_pos,u
        std   y_pos,x
        clr   y_pos+2,x
        rts
@full   leas  2,s
        rts

brood.Slots
        fdb   $C0,$80,$40,0

; -----------------------------------------------------------------------------
; Le decompte de phase, compense : Z = 1 quand il vient d'echoir.
; -----------------------------------------------------------------------------
brood.Tick
        ldd   brood.count,u
        subd  brood.drop
        bgt   >
        ldd   #0
!       std   brood.count,u
        rts

; -----------------------------------------------------------------------------
; Le dessin : la pose vaut `index x 2 + orientation`, la table arcade etant
; ENTRELACEE par montage et nos PNG en sortant tels quels.
; -----------------------------------------------------------------------------
brood.Show
        ldb   brood.blink,u            ; l'eclat : une trame sur quatre du
        beq   @norm                    ; compteur de coup (8035)
        andb  #3
        bne   @norm
        ldb   brood.frame,u            ; fermee (pose 0) ou MI-OUVERTE pour
        beq   >                        ; toutes les poses non fermees —
        ldb   #2                       ; decision auteur, 26/08/2026
!       addb  brood.orient,u
        aslb
        ldx   #brood.HitSets
        abx
        ldx   ,x
        stx   image_set,u
        lda   #ObjID_brood_hit         ; les blanches vivent dans LEUR page :
        sta   id,u                     ; l'identifiant la porte (Img_Page_Index)
        jmp   DisplaySprite
@norm   lda   #ObjID_brood
        sta   id,u
        ldb   brood.frame,u
        aslb
        addb  brood.orient,u
        aslb
        ldx   #brood.Sets
        abx
        ldx   ,x
        stx   image_set,u
        jmp   DisplaySprite

; -----------------------------------------------------------------------------
; L'ouverture de trame : le compte de trames de JEU, la mort, et la boite.
; Z = 0 s'il faut s'en aller.
; -----------------------------------------------------------------------------
brood.Frame
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   brood.drop
        lda   brood.AABB+AABB.p,u
        beq   @mort
        ; touche ? le compteur d'eclat se seme a 12 (8035 : 3 eclats a 25 %)
        cmpa  brood.lastP,u
        beq   >
        sta   brood.lastP,u
        ldb   #12
        stb   brood.blink,u
!       ldb   brood.blink,u
        beq   @vif
        subb  brood.drop+1
        bgt   >
        clrb
!       stb   brood.blink,u
@vif    ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   brood.AABB+AABB.cx,u
        ldb   y_pos+1,u
        ; LE CENTRE DE LA BOITE est excentre de six pixels vers la paroi : la
        ; boite arcade est asymetrique, et differente par montage.
        tst   brood.orient,u
        beq   >
        addb  #brood_cy_offset
        bra   @cy
!       subb  #brood_cy_offset
@cy     stb   brood.AABB+AABB.cy,u
        orcc  #$04                     ; Z = 1 : il reste
        rts
@mort   ldb   #brood_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        beq   @part
        _ldd  ObjID_explosion,explosion.subtype.big.brown
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
@part   andcc #$FB
        rts

brood.Gone
        lda   #7
        sta   routine,u
        _Collision_RemoveAABB brood.AABB,AABB_list_ennemy
        jmp   DeleteObject

; -----------------------------------------------------------------------------
; Deplacer de la vitesse 8.8 en D, compensee du frame-drop. Meme calcul que le
; gouger et le wick : deux `mul` non signes.
; -----------------------------------------------------------------------------
brood.AddPos
        pshs  a
        lda   brood.drop+1
        mul
        std   brood.tmp
        puls  a
        ldb   brood.drop+1
        mul
        tfr   b,a
        clrb
        addd  brood.tmp
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

brood.drop      fdb 0
brood.tmp       fdb 0
brood.was       fdb 0

; y = 297 - 0,75 x y_arcade, comme partout — presets 1000:37de.
brood.PresetY
        fdb   21                       ; montage 0 : plafond ($0170 = 368)
        fdb   177                      ; montage 1 : sol     ($00A0 = 160)
; Les poses, ENTRELACEES par montage comme la table arcade : index x 2 + orient
brood.Sets
        fdb   set_brood_0,set_brood_1  ; ferme        : plafond, sol
        fdb   set_brood_2,set_brood_3  ; entrouvert
        fdb   set_brood_4,set_brood_5  ; plus ouvert
        fdb   set_brood_6,set_brood_7  ; GUEULE OUVERTE
; Les blanches : orientation + 2 x (pose != fermee)
brood.HitSets
        fdb   set_brood_hit_0,set_brood_hit_1  ; fermee     : plafond, sol
        fdb   set_brood_hit_2,set_brood_hit_3  ; mi-ouverte : plafond, sol
