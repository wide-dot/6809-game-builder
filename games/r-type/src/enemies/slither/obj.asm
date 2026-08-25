;*******************************************************************************
; slither — le serpent du stage 5, PORTE DE L'ARCADE
;
; FICHE DE PORTAGE (source : base Ghidra `maincpu`, subsystem enemy_slither)
; -------------------------------------------------------------------------
;   40:78f8 create_slither_manager ....... le MAITRE (slither.Object)
;   40:7935 tick_slither_segment_spawner . le script d'emission (RecInit ici)
;   1000:34ae slither_variant_priority_table  4400 4300 4200 4100
;   1000:34b6 slither_segment_script_short    1 tete + 9 corps + 1 queue = 11
;   1000:34e2 slither_segment_script_long     1 tete + 15 corps + 1 queue = 17
;   40:799c / 79c1  head_ctor / head_tick   (PV 0x0E, palette 0x25)
;   40:7a1e / 7a3f  body_ctor / body_tick   (PV 6, palette 0x26)
;   40:7ad9 / 7afa  tail_ctor / tail_tick   (PV 6, palette 0x25)
;   40:7c50         head_destroy            (score 7 : 800 points)
;   40:7c77         body_tail_destroy       (score 2 : 300 points)
;   40:7c9e / 7ca6  body/tail_detach_init   (le segment se detache)
;   40:7b85 / 7ba0  freeflight_explode_init (l'explosion retardee)
;   40:7d22 / 7d45  draw_*_with_hit_blink   (flash de coup, PAL_KIND 0x55)
;   1000:37c6       AABB tete  : 32x32 arcade centree
;   1000:37ce       AABB corps : 20x20 arcade centree
;   scripts de mouvement : table de SEIZE entrees a 1000:9274, pas de DEUX
;     octets (load_animation_script_preset, 40:f912). Les scripts sont DEJA
;     dans le pool commun du jeu ; seule la LUT les referencant a ete
;     completee (anim_slither, index.asm/index.equ).
;
; ARCHITECTURE : celle de l'outslay (v3), et pour les memes raisons — voir
; src/enemies/outslay/obj.asm, dont ce fichier est le calque. En resume :
;
;   - le MAITRE est le SEUL interprete. Son callback moveByScript, appele une
;     fois par TRAME VIDEO, pousse (x, y, pose) dans un ANNEAU RESIDENT de 256
;     entrees en trois plans d'octets ;
;   - 15 SEGMENTS SANS OST (les corps) : un record de 2 octets sur la
;     page du cast, une boite AABB STATIQUE dans la zone residente. Leur
;     position = l'anneau, lu a (ecriture - 1 - retard), le retard de chaque
;     record etant une CONSTANTE (RecInit, delais arcade cumules) ;
;   - 2 SUIVEURS A OST (la tete et la QUEUE) : leurs images vivent sur
;     D'AUTRES pages (stage5.cast.imgHead, stage5.cast.imgTail) que seul le
;     moteur sait monter. Ils lisent l'anneau a leur retard (0 pour la tete,
;     92 ou 146 pour la queue selon le script) et VALIDENT leur maitre
;     (id + routine) avant chaque lecture — le geste du rebound laser ;
;   - le RENDERER GROUPE (slither.Render) dessine les 15 slots publies par le
;     maitre via le faux imageset — un seul preambule BuildSprites.
;
; POURQUOI LA QUEUE EST UN SUIVEUR ET NON UN RECORD (decision auteur,
; 24/08/2026) : les seize poses du corps et les seize de la queue doivent
; partager la page du renderer groupe, qui les dessine toutes — et le
; direntry du cast pesait alors 18 688 octets pour 16 384. Elaguer les
; scripts de mouvement n'y suffisait pas (1 682 octets pour 2 304 manquants)
; et ils doivent de toute facon rester sur la page montee pendant que le
; maitre interprete. La queue etant UN segment a retard fixe, elle a
; exactement le profil du finalizer de l'outslay : passee en suiveur a OST,
; son art quitte la page du cast pour son propre direntry. Cout : une entree
; de repertoire et un ObjID.
;
; LES RETARDS (RecInit) sortent des lignes [handler][delai] du script arcade :
; la tete a 10, chaque corps 9, le dernier corps 10. Cumules depuis la tete :
;   court : 0, 10, 19, 28, 37, 46, 55, 64, 73, 82, puis la queue a 92
;   long  : 0, 10, 19, ..., 136, puis la queue a 146
; La tete ET la queue etant des suiveurs a OST, les tables ci-dessous ne
; portent que les CORPS — 9 entrees en court, 15 en long.
;
; CE QUI N'EST PAS PORTE (et pourquoi) :
; - le flash de coup (40:7d22/7d45, echange de palette 3 trames sur 4 pendant
;   12) : la palette TO8 est globale au stage, pas par objet. Meme abandon que
;   le swap du 2e loop de l'outslay.
; - la cadence de dessin modulee par le compteur de phase +0x20 (<0x1F un pas,
;   au-dela deux) : notre pose vient de l'anneau, donc du script lui-meme.
; - la CASCADE de mort (bit 0 = detachement, bit 1 = explosion retardee de
;   prev+4, chainee par +0x3C) : ecrite ici comme un etat de record (RS) mais
;   la derive libre du cadavre (40:7b85, deux scripts a 0xA380/0xA3E6) attend
;   son export. Un corps touche explose sur place, ce qui est le comportement
;   arcade a un mouvement pres.
; - le slither NE TIRE PAS : aucune routine de tir dans ses vingt membres.
;   Toute la machinerie d'horloge de tir de l'outslay tombe.
;
; NOMMAGE : tout le cast du stage 5 est une seule unite — prefixe `slither.`
; partout (voir src/stages/05/cast.unit.asm).
;*******************************************************************************

; --- LA ZONE RESIDENTE (unite d'arene : res.unit.asm, arene stage5.res) ----
; TROIS instances : la wave du stage 5 fait vivre jusqu'a trois serpents
; ensemble (mesure toje). Un anneau = trois plans contigus de 256 octets
; (x, y, pose) ; les boites vont par quinze.
slither.ring0     EXTERNAL
slither.ring1     EXTERNAL
slither.ring2     EXTERNAL
slither.boxes0    EXTERNAL
slither.boxes1    EXTERNAL
slither.boxes2    EXTERNAL

; --- LE MAITRE : ext_variables (l'etat moveByScript vit dans son OST) -------
slither.mFrames   equ ext_variables+0    ; 0,1  L'HORLOGE DE LA CHAINE : le
                                         ;      compte de poussees. Avance PAR
                                         ;      le callback pendant le script,
                                         ;      par la boucle pendant le drain.
slither.mEndF     equ ext_variables+2    ; 2,3  poussees a la fin du script
                                         ;      ($7FFF tant qu'elle n'est pas la)
slither.mActive   equ ext_variables+4    ; 4    nb de records eveilles (0..NREC)
slither.mState    equ ext_variables+5    ; 5    0 = script en cours, 1 = drain
slither.mNrec     equ ext_variables+6    ; 6    9 (court) ou 15 (long)
slither.mInit     equ ext_variables+7    ; 7,8  la table RecInit choisie
slither.mPhase    equ ext_variables+9    ; 9    parite de collision
slither.mInst     equ ext_variables+10   ; 10,11 le bloc d'instance pris a la
                                         ;       naissance, rendu a la mort

; --- LE SUIVEUR A OST (la tete) --------------------------------------------
slither.fMaster   equ ext_variables+0    ; 0,1  l'OST du maitre (valide avant usage)
slither.fDelay    equ ext_variables+2    ; 2    retard en trames (0 tete, 92/146 queue)
slither.fAABB     equ ext_variables+3    ; 3..11
; --- LE RENDERER GROUPE : son instance ---------------------------------------
slither.rInst     equ ext_variables+0    ; 0,1  le bloc dont il dessine les slots

; --- LES RECORDS (page du cast) : 2 octets par segment sans OST -------------
slither.RS        equ 0                  ; etat : 0 inactif, 1 vivant, 3 fini
slither.RC        equ 1                  ; libre (cascade a venir)
slither.RECSZ     equ 2
slither.NREC      equ 15                 ; les CORPS du script long (la
                                         ; tete et la queue sont des suiveurs)

slither.role.body equ 0
slither.role.tail equ 1

 IFNDEF SLITHER_CONST
SLITHER_CONST equ 1
 ENDC

; --- LES BLOCS D'INSTANCE (page du cast) ------------------------------------
; Le patron du gestionnaire de bug : un bloc par instance, le maitre en prend
; un a sa naissance et le rend a sa mort. La PROPRIETE se valide — un bloc est
; libre si son proprietaire n'est plus un maitre vivant, ce qui rattrape une
; instance perdue si un maitre disparaissait sans la rendre.
I.owner   equ 0                        ; 0,1  l'OST du maitre, 0 si libre
I.ring    equ 2                        ; 2,3  x a +0, y a +256, pose a +512
I.recs    equ 4                        ; 4,5
I.slots   equ 6                        ; 6,7
I.boxes   equ 8                        ; 8,9
I.SZ      equ 10
slither.NINST equ 3

; Le cache de pointeurs de l'instance COURANTE : le 6809 n'a pas assez de
; registres pour porter cinq bases a travers la marche, et les recharger a
; chaque rang couterait plus que ces cinq mots.
slither.cRing   fdb 0
slither.cRecs   fdb 0
slither.cSlots  fdb 0
slither.cBoxes  fdb 0

; X = un bloc d'instance. Z = 1 s'il est libre. La propriete se VALIDE : un
; proprietaire qui n'est plus un maitre vivant ne tient plus son instance.
slither.InstFree
        pshs  u,d
        ldu   I.owner,x
        beq   @free                    ; jamais pris
        lda   id,u
        cmpa  #ObjID_slither
        bne   @free                    ; le slot sert a autre chose
        lda   routine,u
        cmpa  #2                        ; maitre supprime
        beq   @free
        ldu   I.owner,x                 ; toujours a lui : occupe
        cmpu  #0
        bra   @out
@free   ldu   #0
        cmpu  #0
@out    puls  d,u,pc

; U = le maitre -> le cache pointe SON instance. A appeler avant toute
; utilisation de l'anneau, des records, des slots ou des boites.
slither.UseInst
        ldx   slither.mInst,u
        ldd   I.ring,x
        std   slither.cRing
        ldd   I.recs,x
        std   slither.cRecs
        ldd   I.slots,x
        std   slither.cSlots
        ldd   I.boxes,x
        std   slither.cBoxes
        rts

;*******************************************************************************
; LE MAITRE
;*******************************************************************************
slither.Object
        lda   routine,u
        asla
        ldx   #slither.MasterTab
        jmp   [a,x]
slither.MasterTab
        fdb   slither.MasterInit
        fdb   slither.MasterLive
        fdb   slither.Deleted

slither.MasterInit
        ; --- PRENDRE UNE INSTANCE, avant tout le reste ----------------------
        ; Plus rien de libre : la chaine est SAUTEE, comme la v1 saute un bug
        ; quand le pool est plein (semantique « alloc KO »). Mieux vaut un
        ; serpent absent que trois qui se pietinent — c'est precisement le
        ; defaut que cette instanciation repare.
        ldx   #slither.Insts
        ldb   #slither.NINST
@alloc  jsr   slither.InstFree
        beq   @taken
        leax  I.SZ,x
        decb
        bne   @alloc
        jmp   UnloadObject_u           ; aucune instance : pas de serpent
@taken  stu   I.owner,x
        stx   slither.mInst,u
        ; la zone de l'instance repart propre : records, slots et boites d'un
        ; serpent precedent n'ont rien a dire a celui-ci
        jsr   slither.UseInst
        ldx   slither.cRecs
        ldb   #slither.NREC*slither.RECSZ
!       clr   ,x+
        decb
        bne   <
        ldx   slither.cSlots
        ldb   #slither.NREC*slither.SLOTSZ
!       clr   ,x+
        decb
        bne   <
        ; Le retard de wave doit etre sauve AVANT l'init du script :
        ; wave_frame_drop ALIASE anim_frame_duration (+13), que
        ; moveByScript.initialize ecrase avec la vitesse. La lecon de
        ; l'outslay, payee sur machine.
        ldb   wave_frame_drop,u
        stb   @late
        ; --- CE QUE PORTE LE DESCRIPTEUR DE WAVE ----------------------------
        ; Contrairement a l'outslay, le slither n'a PAS de table de variantes
        ; a lui : 78f8 passe son CX a load_xy_preset et a
        ; load_animation_script_preset (40:f912). Donc, comme le bug :
        ;   subtype   & 3     -> la rangee de 1000:34ae, donc la LONGUEUR de
        ;                        la chaine (l'arcade compare la priorite a
        ;                        0x4280 : 4400/4300 -> long, 4200/4100 -> court)
        ;   subtype+1 & $0F   -> l'entree du preset XY commun (18dd0)
        ;   subtype+1 >> 4    -> la variante de script (1000:9274, seize
        ;                        pointeurs, pas de DEUX octets)
        ;
        ; ATTENTION : moveByScript.initialize prend un INDEX dans la LUT
        ; d'animation, PAS une adresse de script — `ldx [anim.addr + X]`, la
        ; base etant posee une fois par stage par moveByScript.register sur
        ; ObjID_animation. Lui passer une adresse fait lire n'importe ou : le
        ; maitre interpretait alors depuis $0000 et ne mourait jamais
        ; (24/08/2026). Les seize variantes du slither sont contiguës depuis
        ; anim_slither dans src/common/fx/animation/index.asm.
        ldb   subtype+1,u
        stb   @script
        ; la position, preset XY commun — le geste de l'InitCreator du bug
        andb  #$0F
        aslb
        ldx   #PresetXYIndex
        abx
        clra
        ldb   1,x
        std   y_pos,u
        clra
        ldb   ,x
        addd  glb_camera_x_pos
        std   x_pos,u
        ; le script de mouvement : l'INDEX de la variante dans la LUT commune
        ldb   #0
@script equ   *-1
        lsrb
        lsrb
        lsrb
        lsrb
        aslb                           ; deux octets par entree
        addb  #anim_slither            ; base des seize variantes
        clra
        tfr   d,x
        jsr   moveByScript.initialize
        lda   #2                       ; le spawner amorce +0x17 a 2
        sta   anim_frame_duration,u
        ; la table de retards et le compte, selon la longueur
        ldb   subtype,u
        andb  #3
        cmpb  #2
        bhs   @court
        ldx   #slither.RecInitLong
        ldd   #15*256+146              ; A = corps, B = le retard de la queue
        bra   >
@court  ldx   #slither.RecInitShort
        ldd   #9*256+92
!       stx   slither.mInit,u
        sta   slither.mNrec,u
        stb   @tailDelay
        ; --- le maitre ne dessine rien --------------------------------------
        clr   priority,u
        clr   render_flags,u           ; coordonnees ECRAN, comme l'outslay
        ; --- l'etat de chaine a zero ----------------------------------------
        clr   slither.mActive,u
        clr   slither.mState,u
        clr   slither.mPhase,u
        ldd   #0
        std   slither.mFrames,u
        ldd   #$7FFF
        std   slither.mEndF,u
        ; --- le renderer groupe, puis les suiveurs TETE et QUEUE ------------
        jsr   LoadObject_x
        beq   >
        lda   #ObjID_slither_render
        sta   id,x
        ldd   slither.mInst,u          ; le renderer dessine MON instance
        std   slither.rInst,x
!       lda   #ObjID_slither_head      ; le suiveur de TETE, retard 0
        clrb
        jsr   slither.SpawnFollower
        lda   #ObjID_slither_tail      ; le suiveur de QUEUE, retard du script
        ldb   #0
@tailDelay equ *-1
        jsr   slither.SpawnFollower
        inc   routine,u
        ; --- le retard de la wave : derouler l'interprete d'autant, chaque
        ; trame rattrapee poussant SON entree d'anneau --------------------
        ldb   #0
@late   equ   *-1
        beq   @done
        ldd   #slither.Push
        std   moveByScript.callback
        ldb   @late
        jsr   moveByScript.runByB
@done   rts

; Le callback de l'interprete : une fois par TRAME VIDEO, position a jour,
; U = le maitre, page du cast remontee par moveByScript.
slither.Push
        ; L'anneau de MON instance : trois plans contigus, x a +0, y a +256,
        ; pose a +512. Le cache est repose ici parce que le callback peut etre
        ; appele pour un autre maitre entre deux tours (rattrapage de retard).
        jsr   slither.UseInst
        ldb   slither.mFrames+1,u      ; n poussees faites -> la n-ieme s'ecrit
        lda   x_pos+1,u                ; en n (mod 256, l'octet deborde seul)
        ldx   slither.cRing
        abx
        sta   ,x
        lda   y_pos+1,u
        ldx   slither.cRing
        leax  256,x
        abx
        sta   ,x
        lda   anim_frame,u
        ldx   slither.cRing
        leax  512,x
        abx
        sta   ,x
        ldd   slither.mFrames,u        ; l'horloge avance AVEC la poussee
        addd  #1
        std   slither.mFrames,u
        lda   moveByScript.anim.end
        beq   >
        clr   moveByScript.anim.loops
!       rts

slither.MasterLive
        jsr   slither.UseInst          ; MON anneau, MES records, MES boites
        ; --- 1) l'horloge -----------------------------------------------
        ldb   gfxlock.frameDrop.count
        bne   >
        incb                           ; miroir du garde de runByFrameDrop
!       clra
        pshs  d
        lda   slither.mState,u
        beq   @interp
        ldd   slither.mFrames,u        ; drain : plus personne ne pousse, la
        addd  ,s                       ; boucle fait avancer l'horloge et les
        std   slither.mFrames,u        ; records descendent l'anneau ecrit
        bra   @act
@interp
        ; --- 2) l'interprete unique ---------------------------------------
        ldd   #slither.Push
        std   moveByScript.callback
        jsr   moveByScript.runByFrameDrop
        lda   moveByScript.anim.end
        beq   @act
        lda   #1
        sta   slither.mState,u
        ldd   slither.mFrames,u
        std   slither.mEndF,u
@act    leas  2,s
        ; --- 3) activation des records, dans l'ordre des retards ----------
@aloop  ldb   slither.mActive,u
        cmpb  slither.mNrec,u
        bhs   @aend
        aslb
        ldx   slither.mInit,u
        abx
        ldb   ,x                       ; le retard du prochain (octet)
        clra
        pshs  d
        ldd   slither.mFrames,u
        cmpd  ,s++
        ble   @aend                    ; STRICTEMENT superieur : a egalite la
                                       ; lecture vaudrait -1, soit l'entree 255
                                       ; — une position rassise. Le record nait
                                       ; a mFrames = retard + 1.
        ldb   slither.mActive,u
        aslb
        ldx   slither.cRecs
        abx
        lda   #1
        sta   slither.RS,x             ; vivant
        clr   slither.RC,x
        ; --- la boite entre dans la liste du moteur -------------------------
        ; La NETTOYER D'ABORD, prev/next compris : l'arene arrive zeroee au
        ; chargement, mais un SECOND serpent dans le meme stage retrouverait
        ; les chainages du premier — et le chemin « liste vide » de
        ; Collision_AddAABB n'ecrit pas le next de l'inseree
        ; (reserved-ram-is-not-zeroed.md, la lecon de l'outslay).
        ldb   slither.mActive,u
        jsr   slither.BoxPtrB          ; X = boite
        ldb   #sizeof{AABB}
!       clr   ,x+
        decb
        bne   <
        leax  -sizeof{AABB},x
        lda   #slither_hitbox_x
        sta   AABB.rx,x
        lda   #slither_hitbox_y
        sta   AABB.ry,x
        ; LE POTENTIEL DE NAISSANCE — surtout pas zero. La marche de CE tour
        ; peut tomber sur la phase desarmee, et ce chemin lit p == 0 comme un
        ; coup encaisse : la phase dependant de (rang XOR mPhase), un segment
        ; sur deux naitrait en CADAVRE. On le pose arme ; la parite le
        ; reprendra des le tour suivant. (Vecu sur l'outslay.)
        lda   #slither_hitdamage
        sta   AABB.p,x
        pshs  u
        ldy   #AABB_list_ennemy
        jsr   Collision_AddAABB
        puls  u
        inc   slither.mActive,u
        lbra  @aloop
@aend
        ; --- 4) la marche des records --------------------------------------
        com   slither.mPhase,u         ; la parite bascule PAR TOUR DE BOUCLE
        jsr   slither.Walk
        ; --- 5) la fin : plus un record vivant apres le drain ---------------
        lda   slither.mState,u
        beq   >
        lda   slither.mActive,u
        cmpa  slither.mNrec,u
        blo   >
        ldb   #0
        ldx   slither.cRecs
@fin    lda   slither.RS,x
        cmpa  #3
        bne   >                        ; il en reste un
        leax  slither.RECSZ,x
        incb
        cmpb  slither.mNrec,u
        blo   @fin
        jmp   slither.MasterEnd
!       rts

slither.MasterEnd
        ldx   slither.mInst,u          ; rendre l'instance
        ldd   #0
        std   I.owner,x
        lda   #2                       ; l'etat « supprime » du dispatch
        sta   routine,u
        jmp   UnloadObject_u

slither.Deleted
        rts

;*******************************************************************************
; LA MARCHE DES RECORDS — un tour par boucle de jeu
;*******************************************************************************
slither.Walk
        clr   slither.wN
@loop   ldb   slither.wN
        aslb
        ldx   slither.cRecs
        abx
        lda   slither.RS,x
        lbeq  @next                    ; inactif
        cmpa  #3
        lbeq  @next                    ; fini
        ; le retard et le role, constants (RecInit)
        ldb   slither.wN
        aslb
        ldx   slither.mInit,u
        abx
        ldd   ,x                       ; A = retard, B = role
        sta   slither.wDelay
        stb   slither.wRole
        ; --- le drain : le record s'eteint quand sa lecture atteint la fin --
        ldb   slither.mState,u
        beq   @pos
        ldb   slither.wDelay
        clra
        pshs  d
        ldd   slither.mFrames,u
        subd  ,s++
        cmpd  slither.mEndF,u
        blt   @pos
        jsr   slither.RecRetire
        lbra  @next
@pos
        ; --- la position : l'anneau, a (horloge - 1 - retard) ---------------
        ldb   slither.mFrames+1,u
        decb
        subb  slither.wDelay
        stb   slither.wIdx
        ldx   slither.cRing
        abx
        lda   ,x
        sta   slither.wPx
        ldb   slither.wIdx
        ldx   slither.cRing
        leax  256,x
        abx
        lda   ,x
        sta   slither.wPy
        ldb   slither.wIdx
        ldx   slither.cRing
        leax  512,x
        abx
        lda   ,x
        sta   slither.wPose
        ; --- le set d'images du role ----------------------------------------
        ldb   slither.wPose
        andb  #$0F
        aslb
        ldx   #slither.BodySets        ; les records sont TOUS des corps
        abx
        ldx   ,x
        ; --- publier ---------------------------------------------------------
        jsr   slither.SlotPtrN         ; Y = slot
        lda   slither.wPx
        ldb   slither.wPy
        jsr   slither.RecPublish
        ; --- la boite : position, puis parite --------------------------------
        ldb   slither.wN
        jsr   slither.BoxPtrB
        lda   slither.wPx
        suba  #screen_left
        sta   AABB.cx,x
        lda   slither.wPy
        suba  #screen_top
        sta   AABB.cy,x
        ; LA PARITE ARCADE : un segment sur deux par boucle, voisins opposes.
        ; Le gate est le POTENTIEL — Collision_Do saute une boite a p = 0.
        ;
        ; ET SURTOUT : le verdict d'un coup se lit A LA FERMETURE de la
        ; fenetre armee, la seule ou un p nul veuille dire « touche ». Le lire
        ; en tete de marche, sans condition, tuait un segment sain a chaque
        ; tour desarme — c'est NOUS qui venions d'y mettre zero. Mesure avant
        ; correction : mActive montait a 9 mais un seul record restait vivant,
        ; d'ou une chaine qui se lisait comme deux ou trois morceaux epars.
        lda   slither.mPhase,u
        eora  slither.wN
        anda  #1
        beq   @disarm
        lda   #slither_hitdamage       ; boucle armee : exposer les PV
        sta   AABB.p,x
        bra   @next
@disarm lda   AABB.p,x                 ; la passe de collision l'a-t-elle vide ?
        bne   @clr
        jsr   slither.RecExplode       ; oui : score, explosion, retrait
        bra   @next
@clr    clr   AABB.p,x                 ; hors de la passe jusqu'au prochain tour
@next
        inc   slither.wN
        lda   slither.wN
        cmpa  slither.mNrec,u
        lblo  @loop
        rts

slither.wN      fcb 0
slither.wDelay  fcb 0
slither.wRole   fcb 0
slither.wIdx    fcb 0
slither.wPx     fcb 0
slither.wPy     fcb 0
slither.wPose   fcb 0

; B = rang -> X = la boite. (Le maitre est en U, la zone est residente.)
slither.BoxPtrB
        lda   #sizeof{AABB}
        mul
        addd  slither.cBoxes
        tfr   d,x
        rts

; le rang courant -> Y = le slot du renderer
slither.SlotPtrN
        lda   slither.wN
        ldb   #slither.SLOTSZ
        mul
        addd  slither.cSlots
        tfr   d,y
        rts

; Retirer un record : boite hors liste, slot eteint, etat « fini ».
slither.RecRetire
        ldx   #AABB_list_ennemy
        stx   Collision_Remove_1
        stx   Collision_Remove_3
        leax  2,x
        stx   Collision_Remove_2
        ldb   slither.wN
        jsr   slither.BoxPtrB
        pshs  u
        jsr   Collision_RemoveAABB
        puls  u
        jsr   slither.SlotPtrN
        clr   ,y
        ldb   slither.wN
        aslb
        ldx   slither.cRecs
        abx
        lda   #3
        sta   slither.RS,x
        rts

; -----------------------------------------------------------------------------
; Publier un record — le cull « entierement dans le cadre » du moteur, en
; octets, la geometrie lue dans l'imageset.
;   +4 x_size  +5 y_size  +6 center_offset  +11 x1  +12 y1  +14,15 routine
; entree : A = x ecran, B = y ecran, X = set, Y = slot
; X PRESERVE (la lecon du gestionnaire de bug, 22/08/2026).
; -----------------------------------------------------------------------------
slither.RecPublish
        pshs  a,b
        lda   ,s
        adda  11,x
        suba  #screen_left
        cmpa  #screen_right-screen_left
        bhi   @off
        adda  4,x
        cmpa  #screen_right-screen_left+1
        bhi   @off
        lda   1,s
        adda  12,x
        suba  #screen_top
        cmpa  #screen_bottom-screen_top
        bhi   @off
        adda  5,x
        cmpa  #screen_bottom-screen_top+1
        bhi   @off
        lda   ,s
        suba  6,x
        sta   1,y
        lda   1,s
        sta   2,y
        ldd   14,x
        std   3,y
        lda   #1
        sta   ,y
        puls  a,b,pc
@off    clr   ,y
        puls  a,b,pc

; -----------------------------------------------------------------------------
; La mort d'un segment par tir : score + explosion, puis retrait.
; 40:7c77 destroy_slither_body_or_tail — score index 2 (300 points).
; -----------------------------------------------------------------------------
slither.RecExplode
        ldb   #slither_body_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        beq   @gone
        _ldd  ObjID_explosion,explosion.subtype.smallx2
        std   id,x
        ; la frontiere : l'explosion vit en coordonnees PLAYFIELD
        lda   slither.wPx
        clrb
        addd  glb_camera_x_pos
        std   x_pos,x
        clra
        ldb   slither.wPy
        std   y_pos,x
@gone   jsr   slither.RecRetire
        rts

;*******************************************************************************
; LA TETE — le suiveur a OST (retard 0)
;*******************************************************************************
; A = l'ObjID du suiveur, B = son retard en trames. U = le maitre.
slither.SpawnFollower
        pshs  u,a,b
        jsr   LoadObject_x
        beq   @out
        puls  u,a,b
        pshs  u,a,b
        sta   id,x
        stb   slither.fDelay,x
        stu   slither.fMaster,x        ; l'OST du maitre, valide avant usage
        clr   routine,x
@out    puls  u,a,b,pc

; Le suiveur a OST — la TETE (retard 0) ou la QUEUE (retard 92/146). Une
; seule implementation : l'identifiant porte la boite et le pool de poses,
; le retard vient du maitre a la naissance.
slither.Segment
        lda   routine,u
        bne   slither.FollowerLive
        ; --- l'init : la boite, la priorite, le mode ecran ------------------
        _Collision_AddAABB slither.fAABB,AABB_list_ennemy
        lda   id,u
        cmpa  #ObjID_slither_head
        bne   @queue
        lda   #slither_head_hitdamage
        sta   slither.fAABB+AABB.p,u
        _ldd  slither_head_hitbox_x,slither_head_hitbox_y
        bra   >
@queue  lda   #slither_hitdamage       ; la queue a les PV d'un corps (7afa)
        sta   slither.fAABB+AABB.p,u
        _ldd  slither_hitbox_x,slither_hitbox_y
!       std   slither.fAABB+AABB.rx,u
        ldb   #6
        stb   priority,u
        clr   render_flags,u           ; coordonnees ECRAN
        inc   routine,u
slither.FollowerLive
        ; --- valider le maitre AVANT de lire l'anneau (le geste du rebound
        ; laser) : un maitre mort laisse un pointeur perime -----------------
        ldx   slither.fMaster,u
        lda   id,x
        cmpa  #ObjID_slither
        lbne  @die
        lda   routine,x
        cmpa  #2
        lbeq  @die
        ; --- la position : l'anneau DE SON MAITRE, a (ecriture - 1 - retard)
        ; X porte l'OST du maitre, valide juste au-dessus : on y prend son
        ; bloc d'instance, donc SON anneau. Un suiveur qui lirait l'anneau
        ; d'un autre serpent en suivrait la trajectoire — c'est le defaut que
        ; l'instanciation repare.
        ldb   slither.mFrames+1,x
        decb
        subb  slither.fDelay,u
        stb   @idx
        ldx   slither.mInst,x          ; le bloc de l'instance du maitre
        ldx   I.ring,x                 ; son anneau : x a +0, y a +256, pose a +512
        stx   @ring
        abx
        lda   ,x
        sta   x_pixel,u
        ldb   #0
@idx    equ   *-1
        ldx   #0
@ring   equ   *-2
        leax  256,x
        abx
        lda   ,x
        sta   y_pixel,u
        ldb   @idx
        ldx   @ring
        leax  512,x
        abx
        ldb   ,x
        andb  #$0F
        aslb
        lda   id,u
        cmpa  #ObjID_slither_head
        bne   >
        ldx   #slither.HeadSets
        bra   @set
!       ldx   #slither.TailSets
@set    abx
        ldx   ,x
        stx   image_set,u
        ; --- la boite ---------------------------------------------------------
        lda   x_pixel,u
        suba  #screen_left
        sta   slither.fAABB+AABB.cx,u
        lda   y_pixel,u
        suba  #screen_top
        sta   slither.fAABB+AABB.cy,u
        lda   slither.fAABB+AABB.p,u
        beq   @dead
        jmp   DisplaySprite
@dead   ldb   #slither_head_scoreIdx  ; 7c50 : la tete vaut plus que son corps
        lda   id,u
        cmpa  #ObjID_slither_head
        beq   >
        ldb   #slither_body_scoreIdx   ; 7c77 : la queue compte comme un corps
!       jsr   AwardScore
        jsr   LoadObject_x
        beq   @die
        _ldd  ObjID_explosion,explosion.subtype.smallx2
        std   id,x
        lda   x_pixel,u
        clrb
        addd  glb_camera_x_pos
        std   x_pos,x
        clra
        ldb   y_pixel,u
        std   y_pos,x
@die    _Collision_RemoveAABB slither.fAABB,AABB_list_ennemy
        lda   #2
        sta   routine,u
        jmp   DeleteObject

;*******************************************************************************
; LE RENDERER GROUPE — un faux imageset dont la routine dessine les 16 slots
;*******************************************************************************
slither.SLOTSZ  equ 5                  ; etat, x, y, routine(2)

; TROIS faux imagesets, un par instance : BuildSprites appelle la routine de
; dessin SANS OST sous la main, donc l'instance a dessiner ne peut etre portee
; que par l'imageset lui-meme. C'est le geste du gestionnaire de bug.
slither.FakeImg0
        fcb   slither.FakeSub0-slither.FakeImg0,slither.FakeSub0-slither.FakeImg0
        fcb   slither.FakeSub0-slither.FakeImg0,slither.FakeSub0-slither.FakeImg0
        fcb   8,8,0
slither.FakeSub0
        fcb   0
        fcb   slither.FakeMf0-slither.FakeSub0
        fcb   0
        fcb   slither.FakeMf0-slither.FakeSub0
        fcb   0,0
slither.FakeMf0
        fcb   0                        ; page, patchee a l'Init du renderer
        fdb   slither.DrawAll0

slither.FakeImg1
        fcb   slither.FakeSub1-slither.FakeImg1,slither.FakeSub1-slither.FakeImg1
        fcb   slither.FakeSub1-slither.FakeImg1,slither.FakeSub1-slither.FakeImg1
        fcb   8,8,0
slither.FakeSub1
        fcb   0
        fcb   slither.FakeMf1-slither.FakeSub1
        fcb   0
        fcb   slither.FakeMf1-slither.FakeSub1
        fcb   0,0
slither.FakeMf1
        fcb   0                        ; page, patchee a l'Init du renderer
        fdb   slither.DrawAll1

slither.FakeImg2
        fcb   slither.FakeSub2-slither.FakeImg2,slither.FakeSub2-slither.FakeImg2
        fcb   slither.FakeSub2-slither.FakeImg2,slither.FakeSub2-slither.FakeImg2
        fcb   8,8,0
slither.FakeSub2
        fcb   0
        fcb   slither.FakeMf2-slither.FakeSub2
        fcb   0
        fcb   slither.FakeMf2-slither.FakeSub2
        fcb   0,0
slither.FakeMf2
        fcb   0                        ; page, patchee a l'Init du renderer
        fdb   slither.DrawAll2

slither.Render
        lda   routine,u
        bne   slither.RenderLive
        _GetCartPageA
        ldb   id,u
        ldx   #Img_Page_Index
        sta   b,x                      ; le moteur montera NOTRE page
        sta   slither.FakeMf0          ; les trois faux sets vivent ici : les
        sta   slither.FakeMf1          ; patcher tous ne coute rien
        sta   slither.FakeMf2
        ldx   slither.rInst,u          ; MON instance -> MON faux set
        ldd   #slither.FakeImg0
        cmpx  #slither.Insts+I.SZ
        blo   >
        ldd   #slither.FakeImg1
        cmpx  #slither.Insts+2*I.SZ
        blo   >
        ldd   #slither.FakeImg2
!       std   image_set,u
        clr   render_flags,u
        lda   #120                     ; boite parquee au centre : jamais
        sta   x_pixel,u                ; eliminee hors-champ
        lda   #135
        sta   y_pixel,u
        ldb   #6
        stb   priority,u
        inc   routine,u
        jmp   DisplaySprite
; Le cycle de vie du renderer, calque sur outslay.RenderLive. Le VERROU
; « deja vu » (routine := 2) est ce qui evite de mourir a la naissance : a
; l'instant ou le renderer est pose, le maitre n'a encore eveille aucun
; record, donc aucun slot n'est allume. Sans le verrou il se supprimerait
; avant d'avoir rien dessine ; avec, il attend d'avoir vu la chaine vivre,
; et ne s'en va qu'une fois qu'elle s'est entierement eteinte.
slither.RenderLive
        bsr   slither.SlotsLive
        bne   @seen
        lda   routine,u
        cmpa  #2                       ; a-t-il deja vu la chaine ?
        bne   >
        jmp   DeleteObject             ; vue puis eteinte : son travail est fini
!       jmp   DisplaySprite            ; pas encore nee : attendre
@seen   lda   #2
        sta   routine,u
        jmp   DisplaySprite

; Z = 0 s'il reste au moins un slot allume.
slither.SlotsLive
        ldx   slither.rInst,u
        ldx   I.slots,x
        ldb   #slither.NREC
@l      lda   ,x
        bne   @yes
        leax  slither.SLOTSZ,x
        decb
        bne   @l
        clra
@yes    rts

; Le dessin : par slot allume, l'adresse ecran puis la routine compilee.
; A rebours — le plus ancien recouvre, l'ordre du spawn.
slither.DrawAll0
        ldx   #slither.Insts
        bra   slither.DrawCommon
slither.DrawAll1
        ldx   #slither.Insts+I.SZ
        bra   slither.DrawCommon
slither.DrawAll2
        ldx   #slither.Insts+2*I.SZ
slither.DrawCommon
        ldd   I.slots,x
        std   slither.dSlots
        lda   #slither.NREC
        sta   slither.di
@loop   dec   slither.di
        lda   slither.di
        ldb   #slither.SLOTSZ
        mul
        addd  slither.dSlots
        tfr   d,x
        lda   ,x
        beq   @next
        ldd   1,x                      ; A = x_pixel, B = y_pixel
        pshs  x
        jsr   DRS_XYToAddress
        puls  x
        ldx   3,x
        ldu   <glb_screen_location_2
        jsr   ,x                       ; la routine consomme U
@next   tst   slither.di
        bne   @loop
        rts

slither.di      fcb 0
slither.dSlots  fdb 0

;*******************************************************************************
; LES TABLES
;*******************************************************************************
; Les records et les slots des TROIS instances, sur la page du cast (seuls
; l'anneau et les boites doivent etre residents : le callback pousse depuis
; cette page-ci, et la passe de collision suit ses listes sans monter de page).
slither.Recs    fill  0,3*slither.NREC*slither.RECSZ
slither.Slots   fill  0,3*slither.NREC*slither.SLOTSZ

; Les trois blocs d'instance. L'ordre des champs suit I.owner/ring/recs/slots
; /boxes ; le proprietaire est pose a l'allocation et rendu a la mort.
slither.Insts
        fdb   0
        fdb   slither.ring0
        fdb   slither.Recs
        fdb   slither.Slots
        fdb   slither.boxes0
        fdb   0
        fdb   slither.ring1
        fdb   slither.Recs+slither.NREC*slither.RECSZ
        fdb   slither.Slots+slither.NREC*slither.SLOTSZ
        fdb   slither.boxes1
        fdb   0
        fdb   slither.ring2
        fdb   slither.Recs+2*slither.NREC*slither.RECSZ
        fdb   slither.Slots+2*slither.NREC*slither.SLOTSZ
        fdb   slither.boxes2

; Les retards cumules des SANS-OST (la tete, retard 0, est le suiveur a OST).
; Script court (1000:34b6) : 9 corps. La queue (retard 92) est un suiveur.
slither.RecInitShort
        fcb   10,slither.role.body
        fcb   19,slither.role.body
        fcb   28,slither.role.body
        fcb   37,slither.role.body
        fcb   46,slither.role.body
        fcb   55,slither.role.body
        fcb   64,slither.role.body
        fcb   73,slither.role.body
        fcb   82,slither.role.body
        fcb   0,0                      ; bourrage : la table longue fait foi
        fcb   0,0
        fcb   0,0
        fcb   0,0
        fcb   0,0
        fcb   0,0

; Script long (1000:34e2) : 15 corps. La queue (retard 146) est un suiveur.
slither.RecInitLong
        fcb   10,slither.role.body
        fcb   19,slither.role.body
        fcb   28,slither.role.body
        fcb   37,slither.role.body
        fcb   46,slither.role.body
        fcb   55,slither.role.body
        fcb   64,slither.role.body
        fcb   73,slither.role.body
        fcb   82,slither.role.body
        fcb   91,slither.role.body
        fcb   100,slither.role.body
        fcb   109,slither.role.body
        fcb   118,slither.role.body
        fcb   127,slither.role.body
        fcb   136,slither.role.body

; Pas de table de scripts ici : ils vivent dans le POOL COMMUN
; (src/common/fx/animation/script.asm), qui les portait deja tous — les 77
; segments et les 351 mots de script du slither y etaient, mesure. Seules
; SEIZE entrees de LUT manquaient, ajoutees a index.asm. Le moteur ne sait de
; toute facon interpreter qu'une seule page a la fois, celle qu'a epinglee
; moveByScript.register.

; Les seize poses, par role.
slither.BodySets
        fdb   set_slither_body_0,set_slither_body_1
        fdb   set_slither_body_2,set_slither_body_3
        fdb   set_slither_body_4,set_slither_body_5
        fdb   set_slither_body_6,set_slither_body_7
        fdb   set_slither_body_8,set_slither_body_9
        fdb   set_slither_body_10,set_slither_body_11
        fdb   set_slither_body_12,set_slither_body_13
        fdb   set_slither_body_14,set_slither_body_15
slither.TailSets
        fdb   set_slither_tail_0,set_slither_tail_1
        fdb   set_slither_tail_2,set_slither_tail_3
        fdb   set_slither_tail_4,set_slither_tail_5
        fdb   set_slither_tail_6,set_slither_tail_7
        fdb   set_slither_tail_8,set_slither_tail_9
        fdb   set_slither_tail_10,set_slither_tail_11
        fdb   set_slither_tail_12,set_slither_tail_13
        fdb   set_slither_tail_14,set_slither_tail_15
slither.HeadSets
        fdb   set_slither_head_0,set_slither_head_1
        fdb   set_slither_head_2,set_slither_head_3
        fdb   set_slither_head_4,set_slither_head_5
        fdb   set_slither_head_6,set_slither_head_7
        fdb   set_slither_head_8,set_slither_head_9
        fdb   set_slither_head_10,set_slither_head_11
        fdb   set_slither_head_12,set_slither_head_13
        fdb   set_slither_head_14,set_slither_head_15
