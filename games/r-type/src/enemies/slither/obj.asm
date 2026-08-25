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
slither.mTailD    equ ext_variables+12   ; 12   le retard de la QUEUE : 92
                                         ;      (script court) ou 146 (long)
slither.mTailDone equ ext_variables+13   ; 13   1 = la queue est posee
slither.mHeadC    equ ext_variables+14   ; 14   le drapeau de cascade de la
                                         ;      TETE : 1 quand elle meurt au
                                         ;      tir (40:7c50). Le record de
                                         ;      rang 0 le lit comme son
                                         ;      predecesseur — la tete n'a pas
                                         ;      de record a elle.

; --- LE SUIVEUR A OST (la tete) --------------------------------------------
slither.fMaster   equ ext_variables+0    ; 0,1  l'OST du maitre (valide avant usage)
slither.fDelay    equ ext_variables+2    ; 2    retard en trames (0 tete, 92/146 queue)
slither.fAABB     equ ext_variables+3    ; 3..11
slither.fMode     equ ext_variables+12   ; 12   0 = dans la chaine, 1 = compte
                                         ;      a rebours du chapelet
slither.fDelayC   equ ext_variables+13   ; 13   ce compte a rebours
slither.fPrevP    equ ext_variables+14   ; 14   le potentiel du tour precedent
slither.fBlink    equ ext_variables+15   ; 15   1 = flash de coup cette trame
; --- LE RENDERER GROUPE : son instance ---------------------------------------
slither.rInst     equ ext_variables+0    ; 0,1  le bloc dont il dessine les slots

; --- LES RECORDS (page du cast) : 12 octets par segment sans OST -----------
; Ils tenaient en deux octets ; la cascade de mort leur demande l'etat d'un
; vol libre (position et vitesse en 8.8, vrillage) et le compte a rebours du
; chapelet. Ils restent sur la page du CAST : seuls l'anneau et les boites
; doivent etre residents (la passe de collision suit ses listes sans monter de
; page), alors que les records ne sont lus que par la marche et la cascade,
; qui tournent deja page du cast montee. L'arene residente du stage 5 n'aurait
; d'ailleurs pas pu les prendre — 3 249 octets demandes pour 2 800.
slither.RS        equ 0                  ; etat : 0 inactif, 1 vivant, 3 fini,
                                         ;        4 = detache (vol libre)
slither.RC        equ 1                  ; cascade, comme +0x1E de l'arcade :
                                         ;   0 rien, 1 (bit 0) detachement,
                                         ;   2 (bit 1) chapelet d'explosion
slither.RD        equ 2                  ; le compte a rebours du chapelet,
                                         ; pose a celui du predecesseur + 4
slither.RX        equ 3                  ; 3,4  x en 8.8 pendant le vol libre
slither.RY        equ 5                  ; 5,6  y en 8.8
slither.RVX       equ 7                  ; 7,8  vitesse x en 8.8
slither.RVY       equ 9                  ; 9,10 vitesse y en 8.8
slither.RP        equ 11                 ; le compteur de vrillage
slither.RECSZ     equ 12                 ; DUPLIQUE dans res.unit.asm, qui
                                         ; s'assemble seul : bouger les deux
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
        ;                        la chaine. L'arcade compare cette valeur a
        ;                        0x4280 (40:7922) et le sens est celui du
        ;                        DESASSEMBLAGE, pas celui de la plate qui dit
        ;                        l'inverse : `MOV AX,short / CMP [SI+34],4280
        ;                        / JNC garde-le-court`. JNC saute quand il n'y
        ;                        a PAS de retenue, donc quand la valeur est
        ;                        SUPERIEURE ou egale. Table : 4400 4300 4200
        ;                        4100, donc variantes 0 et 1 -> COURT,
        ;                        2 et 3 -> LONG.
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
        ; --- la position : preset XY commun, en repere ECRAN ----------------
        ; 78f8 passe CX a load_xy_preset (40:f88c), qui lit la table 0x8DD0 —
        ; seize entrees, converties ici en deux octets (x, y) dans le repere
        ; du cadre de jeu. PAS d'ajustement au passage : le +24 que le bug
        ; applique pour ses presets 3 a 8 vit dans SON code (0x61EB), pas dans
        ; le helper.
        ;
        ; REPERE : le bug ajoute glb_camera_x_pos parce qu'il travaille en
        ; PLAYFIELD (render_playfieldcoord_mask). Nous sommes en repere ECRAN,
        ; comme l'outslay dont la table a le cadre 48/28 cuit dedans — le
        ; maitre a render_flags nul, l'anneau ne garde qu'un OCTET de x, et la
        ; publication compare a screen_left/right. Ajouter la camera faisait
        ; croitre x_pos sans borne au fil du niveau : son octet bas repassait
        ; par zero et la chaine sautait a l'ecran. Le cadre se cuit donc ici.
        andb  #$0F
        aslb
        ldx   #PresetXYIndex
        abx
        clra
        ldb   1,x
        addd  #screen_top
        std   y_pos,u
        clra
        ldb   ,x
        addd  #screen_left
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
        bhs   @long                    ; variantes 2 et 3 : la chaine longue
        ldx   #slither.RecInitShort    ; variantes 0 et 1 : la courte
        ldd   #9*256+92                ; A = corps, B = le retard de la queue
        bra   >
@long   ldx   #slither.RecInitLong
        ldd   #15*256+146
!       stx   slither.mInit,u
        sta   slither.mNrec,u
        ; LE RETARD DE LA QUEUE VIT DANS L'OST, pas dans un operande
        ; auto-modifie : cet octet-la est unique pour toute la page, donc
        ; PARTAGE par les trois serpents. Le dernier maitre a s'initialiser
        ; ecrasait la valeur avant que le precedent ne l'ait consommee — une
        ; chaine courte heritait du retard 146 d'une longue et sa queue se
        ; retrouvait 64 trames trop loin : un element isole suivant la file a
        ; distance (constat auteur). Meme famille de defaut que la zone
        ; residente partagee, au meme endroit du raisonnement.
        stb   slither.mTailD,u
        clr   slither.mTailDone,u
        clr   slither.mHeadC,u           ; aucune cascade en cours
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
        ; La QUEUE n'est PAS posee ici : son heure vient 92 ou 146 trames plus
        ; tard. La poser tout de suite la ferait lire l'anneau a un index que
        ; le maitre n'a pas encore ecrit — vecu, une queue a x=0 y=0. C'est le
        ; geste du finalizer de l'outslay, pose quand son retard est atteint.
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
        jsr   slither.RecPtrB
        lda   #1
        sta   slither.RS,x             ; vivant
        clr   slither.RC,x
        clr   slither.RD,x
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
        ; --- 3bis) la QUEUE, quand son retard est atteint -------------------
        ; Meme garde que l'eveil d'un record : STRICTEMENT superieur, sinon la
        ; premiere lecture vaudrait -1, soit l'entree 255 — une position
        ; rassise d'un serpent precedent.
        lda   slither.mTailDone,u
        bne   @tail
        ldb   slither.mTailD,u
        clra
        pshs  d
        ldd   slither.mFrames,u
        cmpd  ,s++
        bls   @tail
        inc   slither.mTailDone,u
        lda   #ObjID_slither_tail
        ldb   slither.mTailD,u
        jsr   slither.SpawnFollower
@tail
        ; --- 3ter) la CASCADE DE MORT, un cran par trame --------------------
        jsr   slither.Cascade
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
        bne   >                        ; il en reste un (vivant OU en vol libre)
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
; -----------------------------------------------------------------------------
; LA CASCADE DE MORT — 40:7a3f (body_tick) lit +0x1E du PREDECESSEUR
;
;   bit 0 (drapeau 1) : la TETE est morte au tir (40:7c50). Chaque segment se
;                       DETACHE : vol libre balistique et vrillage sur place.
;   bit 1 (drapeau 2) : un CORPS est mort au tir (40:7c77). Ce qui suit part en
;                       CHAPELET : le compte a rebours de chacun vaut celui de
;                       son predecesseur + 4 trames, puis le cadavre s'en va
;                       sur un des deux scripts de vol libre.
;
; L'arcade propage UN CRAN PAR TRAME, chaque segment lisant son predecesseur au
; tour suivant. On descend donc les rangs A REBOURS : le rang n lit le rang
; n-1 tel qu'il etait a l'entree de la trame, puisqu'on ne l'a pas encore
; touche. En montant, la cascade traverserait toute la chaine en une trame et
; le chapelet perdrait justement son etalement.
;
; Le predecesseur du rang 0 est la TETE, qui n'a pas de record : son drapeau
; vit dans l'OST du maitre (slither.mHeadC).
; -----------------------------------------------------------------------------
slither.Cascade
        lda   slither.mNrec,u
        beq   @out
        deca
@loop   sta   slither.wN
        ldb   slither.wN
        jsr   slither.RecPtrB          ; X = MON record
        lda   slither.RS,x
        cmpa  #1
        bne   @next                    ; seul un segment dans la chaine adopte
        lda   slither.RC,x
        bne   @next                    ; deja marque : on n'adopte qu'une fois
        ldb   slither.wN
        beq   @head
        decb
        pshs  x
        jsr   slither.RecPtrB          ; X = le predecesseur
        lda   slither.RC,x
        ldb   slither.RD,x
        puls  x
        bra   @adopt
@head   lda   slither.mHeadC,u         ; le rang 0 suit la tete
        clrb
@adopt  bita  #2                       ; l'arcade teste le bit 1 D'ABORD
        bne   @chain
        bita  #1
        beq   @next
        lda   #1                       ; detachement : la marche s'en occupe
        sta   slither.RC,x
        lbra  @next
@chain  lda   #2
        sta   slither.RC,x
        addb  #4                       ; l'etalement du chapelet
        stb   slither.RD,x
@next   lda   slither.wN
        beq   @out
        deca
        bra   @loop
@out    rts

; B = rang -> X = son record. (Le cache d'instance doit etre pose.)
slither.RecPtrB
        lda   #slither.RECSZ
        mul
        addd  slither.cRecs
        tfr   d,x
        rts

; -----------------------------------------------------------------------------
; LES SEIZE DIRECTIONS DU VOL LIBRE — 1000:8fd0, converties a l'echelle TO8.
; L'arcade y range seize vitesses 8.8 sur un cercle de rayon ~2.125 px/trame ;
; l'index est priority & 0x0F, ce qui donne a chaque segment sa direction.
; Echelle du jeu : x 0.375 en X, x 0.75 en Y — la meme que les boites.
; Ex. l'entree 4 vaut +2.375 en X arcade, soit +0.891 ici (228/256).
; -----------------------------------------------------------------------------
slither.DetachVel
        fdb   0,408      ; 0
        fdb   78,384     ; 1
        fdb   150,300    ; 2
        fdb   204,180    ; 3
        fdb   228,0      ; 4
        fdb   204,-180   ; 5
        fdb   150,-300   ; 6
        fdb   78,-384    ; 7
        fdb   0,-408     ; 8
        fdb   -78,-384   ; 9
        fdb   -150,-300  ; 10
        fdb   -204,-180  ; 11
        fdb   -228,0     ; 12
        fdb   -204,180   ; 13
        fdb   -150,300   ; 14
        fdb   -78,384    ; 15

slither.Walk
        clr   slither.wN
@loop   clr   slither.wFree            ; dans la chaine, sauf preuve du contraire
        ldb   slither.wN
        jsr   slither.RecPtrB
        lda   slither.RS,x
        lbeq  @next                    ; inactif
        cmpa  #3
        lbeq  @next                    ; fini
        cmpa  #4
        lbeq  @drift                   ; detache : il ne lit plus l'anneau
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
        ; --- la cascade : ce record quitte-t-il la chaine cette trame ? ------
        ; L'ordre est celui de 40:7a3f — le compte a rebours court AVANT tout
        ; le reste, et le segment continue de suivre la chaine tant qu'il n'est
        ; pas echu.
        ldb   slither.wN
        jsr   slither.RecPtrB
        lda   slither.RD,x
        beq   @nodelay
        deca
        sta   slither.RD,x
        bne   @nodelay
        jsr   slither.RecCorpse        ; echu : le cadavre part sur son script
        lbra  @next
@nodelay
        lda   slither.RC,x
        cmpa  #1
        bne   @img
        jsr   slither.RecDetach        ; la tete est morte : vol libre
        ; il publie une derniere fois avec la pose de la chaine ; des la
        ; trame suivante c'est @drift qui le mene
@img
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
        ; LA CADENCE DE COLLISION suit l'arcade, et elle DIFFERE selon l'etat :
        ; un corps de la chaine est teste une trame sur DEUX (40:7a3f gate le
        ; test par global_counter XOR priority), mais un segment DETACHE l'est
        ; a CHAQUE trame — 40:7cd3 appelle la passe sans porte, tout comme la
        ; tete et la queue. On sort donc du schema de parite des qu'il vole.
        lda   slither.wFree
        bne   @libre
        lda   slither.mPhase,u
        eora  slither.wN
        anda  #1
        beq   @disarm
        lda   #slither_hitdamage       ; boucle armee : exposer les PV
        sta   AABB.p,x
        lbra  @next
@disarm lda   AABB.p,x                 ; la passe de collision l'a-t-elle vide ?
        bne   @clr
        jsr   slither.RecExplode       ; oui : score, explosion, retrait
        lbra  @next
@clr    clr   AABB.p,x                 ; hors de la passe jusqu'au prochain tour
        lbra  @next
@libre  lda   AABB.p,x                 ; vol libre : arme a chaque trame, et le
        beq   @boom                    ; verdict se lit au tour suivant
        lda   #slither_hitdamage
        sta   AABB.p,x
        lbra  @next
@boom   jsr   slither.RecExplode
        lbra  @next
; --- LE VOL LIBRE (40:7cd3) -------------------------------------------------
; Le segment ne lit plus l'anneau : il derive en 8.8 et vrille sur place.
; L'arcade avance image_id d'UN par trame et indexe (image_id & 0x1E) * 3 sur
; un pas de six octets — soit une pose toutes les DEUX trames, et seulement
; les seize premieres, celles de la famille rotation.
@drift  inc   slither.wFree            ; en vol libre : cadence de collision a part
        ; LA COMPENSATION DE FRAME-DROP. Tout le reste de la chaine l'a : le
        ; maitre passe par moveByScript.runByFrameDrop pendant le script et
        ; avance son horloge de frameDrop.count pendant le drain. Le vol libre
        ; n'appliquait sa vitesse QU'UNE FOIS par appel d'objet — sur une
        ; machine qui laisse tomber une trame sur deux, un cadavre partait
        ; deux fois trop lentement. Meme garde que runByFrameDrop : un compte
        ; nul vaut un.
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       stb   slither.wDrop
        ; La compensation se fait SANS BOUCLE : position += vitesse x n en
        ; deux mul par axe, a temps constant. Deux choses la rendent courte.
        ; D'abord le signe se traite tout seul — le produit tronque a 16 bits
        ; est le meme en complement a deux, donc deux mul NON SIGNES suffisent
        ; pour une vitesse 8.8 signee. Ensuite on n'assemble jamais le delta :
        ; le produit de l'octet BAS s'ajoute a la position entiere (sa retenue
        ; remonte d'elle-meme), et celui de l'octet HAUT au seul octet haut,
        ; ce qui evite le decalage et la pile.
        ; A n = 7 : ~130 cycles par segment contre ~364 pour la boucle.
        lda   slither.RVX+1,x
        ldb   slither.wDrop
        mul
        addd  slither.RX,x
        std   slither.RX,x
        lda   slither.RVX,x
        ldb   slither.wDrop
        mul
        addb  slither.RX,x
        stb   slither.RX,x
        lda   slither.RVY+1,x
        ldb   slither.wDrop
        mul
        addd  slither.RY,x
        std   slither.RY,x
        lda   slither.RVY,x
        ldb   slither.wDrop
        mul
        addb  slither.RY,x
        stb   slither.RY,x
        lda   slither.RP,x             ; le vrillage est une horloge, lui aussi
        adda  slither.wDrop
        sta   slither.RP,x
        lda   slither.RX,x             ; l'octet haut est le pixel
        sta   slither.wPx
        lda   slither.RY,x
        sta   slither.wPy
        lda   slither.RP,x
        anda  #$1E
        lsra
        sta   slither.wPose
        ; sorti du cadre : l'arcade recycle (is_visible_range). En octets, un
        ; x passe sous screen_left repasse par 255 — donc au-dela de la
        ; largeur : le meme test attrape les deux bords.
        lda   slither.wPx
        suba  #screen_left
        cmpa  #screen_right-screen_left
        bhi   @gone
        lda   slither.wPy
        suba  #screen_top
        cmpa  #screen_bottom-screen_top
        lbls  @img                     ; la boucle de rattrapage a eloigne @img
@gone   jsr   slither.RecRetire
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
slither.wDrop   fcb 0                  ; trames a rattraper dans le vol libre
slither.wFree   fcb 0                  ; 1 = le record courant est detache

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
        jsr   slither.RecPtrB
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
; DETACHER un record — 40:7c9e puis 40:7cab. Il quitte l'anneau et part en
; balistique. X = son record, wN son rang, wPx/wPy sa derniere position.
; -----------------------------------------------------------------------------
slither.RecDetach
        lda   slither.wPx              ; la position devient un 8.8
        clrb
        std   slither.RX,x
        lda   slither.wPy
        clrb
        std   slither.RY,x
        ; la direction : l'arcade indexe la table par priority & 0x0F, ce qui
        ; donne a chaque segment la sienne. Le RANG joue ici ce role — il est
        ; ce qui distingue nos segments les uns des autres.
        ldb   slither.wN
        andb  #$0F
        aslb
        aslb                           ; quatre octets par direction
        pshs  x
        ldx   #slither.DetachVel
        abx
        ldd   ,x
        ldy   2,x
        puls  x
        std   slither.RVX,x
        sty   slither.RVY,x
        ; 40:7cca tire l'image de depart au hasard : les segments ne vrillent
        ; pas en choeur
        pshs  x
        jsr   RandomNumber
        puls  x
        stb   slither.RP,x
        lda   #4
        sta   slither.RS,x
        rts

; -----------------------------------------------------------------------------
; LE CADAVRE DU CHAPELET — 40:7b85. Le compte a rebours est echu : le segment
; sort de la chaine et part sur un des deux scripts de vol libre. Il lui faut
; un interprete a lui, donc un OST : c'est le seul endroit du serpent ou un
; segment sans OST en reclame un. Faute d'OST il explose sur place, ce qui est
; la degradation la plus douce — un segment qui disparait, pas un qui reste.
; X = son record, wPx/wPy/wPose sa position et sa pose.
; -----------------------------------------------------------------------------
slither.RecCorpse
        jsr   LoadObject_x
        beq   @fail
        lda   #ObjID_slither_corpse
        sta   id,x
        clr   routine,x
        lda   #2                       ; mode 2 : le script
        sta   slither.dMode,x
        lda   slither.wPx
        sta   x_pixel,x
        lda   slither.wPy
        sta   y_pixel,x
        lda   slither.wPose
        sta   anim_frame,x             ; c'est elle qui choisit le script
        jmp   slither.RecRetire
@fail   jmp   slither.RecExplode

; -----------------------------------------------------------------------------
; La mort d'un segment par tir : score + explosion, puis retrait.
; 40:7c77 destroy_slither_body_or_tail — score index 2 (300 points).
; -----------------------------------------------------------------------------
slither.RecExplode
        ; 40:7c77 pose cascade_flag := 2 AVANT de rendre l'objet. C'est LA
        ; source du chapelet : sans elle un corps tue laisse un trou permanent
        ; au lieu d'emporter tout ce qui le suit — et, la cascade se propageant
        ; de rang en rang, ce trou a RC = 0 BLOQUE ensuite le detachement de la
        ; tete pour tout ce qui est derriere (constat auteur). Le record est
        ; retire juste apres, mais son RC survit : c'est lui que son successeur
        ; lit a la trame suivante.
        ldb   slither.wN
        jsr   slither.RecPtrB
        lda   #2
        sta   slither.RC,x
        ldb   #slither_body_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        beq   @gone
        _ldd  ObjID_explosion,explosion.subtype.smallx2
        std   id,x
        ; FRONTIERE : l'explosion vit en PLAYFIELD, nous en ECRAN. La forme
        ; est celle de l'outslay (outslay/obj.asm) : l'octet de position part
        ; dans B — pas dans A, sinon il vaut 256 fois trop — et le cadre se
        ; retranche sur les DEUX axes avant d'ajouter la camera. Ecrit a
        ; l'envers, l'explosion naissait a des milliers de pixels et ne se
        ; voyait jamais (constat auteur : « ni explosion ni chapelet »).
        ldb   slither.wPx
        clra
        subd  #screen_left
        addd  glb_camera_x_pos
        std   x_pos,x
        ldb   slither.wPy
        clra
        subd  #screen_top
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
        ; On teste la QUEUE, pas la tete : pendant son flash la tete porte
        ; ObjID_slither_head_hit, et tout test « est-ce la tete ? » la
        ; ferait basculer du cote de la queue.
        lda   id,u
        cmpa  #ObjID_slither_tail
        beq   @queue
        lda   #slither_head_hitdamage
        sta   slither.fAABB+AABB.p,u
        _ldd  slither_head_hitbox_x,slither_head_hitbox_y
        bra   >
@queue  lda   #slither_hitdamage       ; la queue a les PV d'un corps (7afa)
        sta   slither.fAABB+AABB.p,u
        _ldd  slither_hitbox_x,slither_hitbox_y
!       std   slither.fAABB+AABB.rx,u
        lda   slither.fAABB+AABB.p,u
        sta   slither.fPrevP,u
        clr   slither.fBlink,u
        ldb   #6
        stb   priority,u
        clr   render_flags,u           ; coordonnees ECRAN
        ; L'OST est RECYCLE : ces deux octets portent ce qu'y a laisse l'objet
        ; precedent. Sans ce nettoyage une queue pouvait naitre en croyant
        ; compter le chapelet d'un serpent deja mort.
        clr   slither.fMode,u
        clr   slither.fDelayC,u
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
        ; --- le drain : MEME regle que les records (slither.Walk) -----------
        ; Passe la fin du script plus personne ne pousse l'anneau, et l'horloge
        ; continue d'avancer : chaque lecteur descend la zone ECRITE vers la
        ; position finale. Un lecteur qui l'a entierement consommee lit alors
        ; des entrees vieilles de 256 trames — la trajectoire du tour
        ; precedent. La TETE, a retard 0, sort de la zone ecrite des la
        ; PREMIERE trame de drain : sans ce test elle survit au serpent et
        ; rejoue son propre passage tres loin derriere (constat auteur). Les
        ; records avaient le test depuis toujours, les suiveurs non.
        lda   slither.mState,x
        beq   @vivant
        ldb   slither.fDelay,u
        clra
        pshs  d
        ldd   slither.mFrames,x
        subd  ,s++
        cmpd  slither.mEndF,x
        lbge  @die
@vivant
        ; --- LE FLASH DE COUP ------------------------------------------------
        ; L'arcade fait clignoter le segment touche douze trames, trois sur
        ; quatre (40:7d22). A notre cadence une trame rendue vaut ~7 trames de
        ; jeu : UNE trame blanche couvre donc deja la duree du clignotement
        ; arcade, et le motif 3-sur-4 n'a plus de sens (decision auteur).
        ; Le potentiel d'un SUIVEUR n'est pas rearme — pose une fois a l'init,
        ; la passe de collision le decremente — il accumule donc vraiment les
        ; degats, comme le +0x1f de l'arcade. Une BAISSE est un coup encaisse.
        ; Seule la tete flashe : elle seule encaisse plusieurs coups (14
        ; contre 6), un corps ou la queue meurt bien avant d'avoir pu flasher.
        lda   id,u
        cmpa  #ObjID_slither_tail
        beq   @noflash
        lda   slither.fAABB+AABB.p,u
        beq   @noflash                 ; a zero : le chemin de mort s'en charge
        cmpa  slither.fPrevP,u
        bhs   @noflash
        sta   slither.fPrevP,u
        lda   #1
        sta   slither.fBlink,u
@noflash
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
        stb   anim_frame,u             ; la pose du tour, que le cadavre relira
        andb  #$0F
        aslb
        lda   id,u
        cmpa  #ObjID_slither_tail
        bne   @tete
        ldx   #slither.TailSets
        bra   @set
@tete   lda   slither.fBlink,u
        beq   @normal
        clr   slither.fBlink,u         ; une seule trame
        lda   #ObjID_slither_head_hit  ; CE changement d'identifiant est ce qui
        sta   id,u                     ; fait monter l'autre page d'images
        ldx   #slither.HeadHitSets
        bra   @set
@normal lda   #ObjID_slither_head
        sta   id,u
        ldx   #slither.HeadSets
@set    abx
        ldx   ,x
        stx   image_set,u
        ; --- la cascade, cote QUEUE (40:7afa) --------------------------------
        ; Son predecesseur est le DERNIER record. La TETE, elle, est la SOURCE
        ; de la cascade (40:7c50) et n'a pas de predecesseur a lire.
        lda   id,u
        cmpa  #ObjID_slither_tail
        bne   @nocasc
        lda   slither.fMode,u
        bne   @counting
        ldx   slither.fMaster,u
        ldy   slither.mInst,x
        ldy   I.recs,y
        lda   slither.mNrec,x
        deca
        ldb   #slither.RECSZ
        mul
        leay  d,y                      ; Y = le dernier record
        lda   slither.RC,y
        beq   @nocasc
        cmpa  #2
        bne   @tnow                    ; bit 0 : elle se detache tout de suite
        ldb   slither.RD,y             ; bit 1 : elle prend son rang dans le
        addb  #4                       ; chapelet, quatre trames plus tard
        stb   slither.fDelayC,u
        lda   #1
        sta   slither.fMode,u
        bra   @nocasc
@tnow   lda   #1
        bra   @tcorpse
@counting
        dec   slither.fDelayC,u
        bne   @nocasc
        lda   #2                       ; echu : le cadavre part sur son script
@tcorpse
        jsr   slither.TailCorpse
        lbra  @die
@nocasc
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
@dead   lda   id,u
        cmpa  #ObjID_slither_tail
        beq   @dtail
        ; 40:7c50 : la tete pose son drapeau AVANT de mourir. C'est le bit 0,
        ; celui qui detache toute la chaine — elle est la source de la cascade.
        ldx   slither.fMaster,u        ; valide : on vient de le lire ce tour
        lda   #1
        sta   slither.mHeadC,x
        ldb   #slither_head_scoreIdx   ; 7c50 : la tete vaut plus que son corps
        bra   @dscore
@dtail  ldb   #slither_body_scoreIdx   ; 7c77 : la queue compte comme un corps
@dscore jsr   AwardScore
        jsr   LoadObject_x
        beq   @die
        _ldd  ObjID_explosion,explosion.subtype.smallx2
        std   id,x
        ldb   x_pixel,u                ; meme frontiere, voir slither.RecExplode
        clra
        subd  #screen_left
        addd  glb_camera_x_pos
        std   x_pos,x
        ldb   y_pixel,u
        clra
        subd  #screen_top
        std   y_pos,x
@die    _Collision_RemoveAABB slither.fAABB,AABB_list_ennemy
        lda   #2
        sta   routine,u
        jmp   DeleteObject

;*******************************************************************************
; LE RENDERER GROUPE — un faux imageset dont la routine dessine les 16 slots
;*******************************************************************************
; -----------------------------------------------------------------------------
; LA QUEUE DEVIENT UN CADAVRE — elle a un OST, mais pas les huit octets qu'il
; faudrait pour porter un vol libre (ext_variables_size vaut 20 et sa boite en
; occupe neuf). Elle passe donc la main a un objet cadavre, comme un record.
; A = le mode (1 vol libre, 2 script). U = la queue.
; -----------------------------------------------------------------------------
slither.TailCorpse
        pshs  a
        jsr   LoadObject_x
        beq   @out
        lda   #ObjID_slither_tail_corpse
        sta   id,x
        clr   routine,x
        lda   ,s
        sta   slither.dMode,x
        lda   x_pixel,u
        sta   x_pixel,x
        lda   y_pixel,u
        sta   y_pixel,x
        lda   anim_frame,u
        sta   anim_frame,x
        lda   ,s
        cmpa  #1
        bne   @out
        ; La direction : l'arcade indexe la table par priority & 0x0F. La queue
        ; n'a pas de rang dans les records ; sa POSE joue ce role — elle varie
        ; d'un serpent a l'autre et reste deterministe.
        ldb   anim_frame,u
        andb  #$0F
        aslb
        aslb
        pshs  x
        ldx   #slither.DetachVel
        abx
        ldd   ,x
        ldy   2,x
        puls  x
        std   slither.dVX,x
        sty   slither.dVY,x
@out    puls  a,pc

;*******************************************************************************
; LE CADAVRE — 40:7cd3 (vol libre) et 40:7bfc / 40:7bbb (chapelet)
;
; Un segment qui a quitte la chaine. Deux modes, exactement ceux de l'arcade :
;   1 : balistique 8.8 dans une des seize directions, et vrillage a demi-
;       cadence. C'est ce que devient toute la chaine quand la TETE meurt.
;   2 : un des deux scripts de vol libre (1000:A3E6 si la pose est < 9, sinon
;       1000:A380), joue par l'interprete. C'est le CHAPELET : chaque segment
;       part quatre trames apres son predecesseur.
;
; Il reste touchable dans les deux modes (l'arcade garde la boite du corps) et
; disparait a la sortie du cadre ou a la fin de son script.
;*******************************************************************************
slither.dMode   equ ext_variables+0    ; 1 ou 2
slither.dSpin   equ ext_variables+1    ; le compteur de vrillage (mode 1)
slither.dVX     equ ext_variables+2    ; 2,3  vitesse 8.8
slither.dVY     equ ext_variables+4    ; 4,5
slither.dPX     equ ext_variables+6    ; 6,7  position 8.8 (mode 1)
slither.dPY     equ ext_variables+8    ; 8,9
slither.dAABB   equ ext_variables+10   ; 10..18

slither.Corpse
        lda   routine,u
        bne   slither.CorpseLive
        _Collision_AddAABB slither.dAABB,AABB_list_ennemy
        lda   #slither_hitdamage       ; les PV d'un corps, dans les deux modes
        sta   slither.dAABB+AABB.p,u
        _ldd  slither_hitbox_x,slither_hitbox_y
        std   slither.dAABB+AABB.rx,u
        ldb   #6
        stb   priority,u
        clr   render_flags,u           ; coordonnees ECRAN, comme la chaine
        clr   slither.dSpin,u          ; l'OST est recycle : pas d'heritage
        lda   x_pixel,u                ; la position devient un 8.8
        clrb
        std   slither.dPX,u
        lda   y_pixel,u
        clrb
        std   slither.dPY,u
        clra                           ; ... et un 16 bits pour l'interprete
        ldb   x_pixel,u
        std   x_pos,u
        clra
        ldb   y_pixel,u
        std   y_pos,u
        lda   slither.dMode,u
        cmpa  #2
        bne   @armed
        ; 40:7b85 choisit le script sur la pose : < 9 -> A3E6, sinon A380.
        ; Les deux entrees sont contiguës dans la LUT commune.
        ldb   #anim_slither_corpse
        lda   anim_frame,u
        cmpa  #9
        blo   >
        addb  #2
!       clra
        tfr   d,x
        jsr   moveByScript.initialize
@armed  inc   routine,u

slither.CorpseLive
        lda   slither.dMode,u
        cmpa  #2
        beq   @script
        ; --- mode 1 : la balistique et le vrillage, frame-drop compense -----
        ; Le mode 2 l'est deja par construction (runByFrameDrop) ; celui-ci
        ; doit le faire a la main, sinon le cadavre derive au ralenti.
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       stb   slither.wDrop
        ; Meme calcul sans boucle que le vol libre des records — voir la-bas
        ; pour le pourquoi des deux mul non signes.
        lda   slither.dVX+1,u
        ldb   slither.wDrop
        mul
        addd  slither.dPX,u
        std   slither.dPX,u
        lda   slither.dVX,u
        ldb   slither.wDrop
        mul
        addb  slither.dPX,u
        stb   slither.dPX,u
        lda   slither.dVY+1,u
        ldb   slither.wDrop
        mul
        addd  slither.dPY,u
        std   slither.dPY,u
        lda   slither.dVY,u
        ldb   slither.wDrop
        mul
        addb  slither.dPY,u
        stb   slither.dPY,u
        lda   slither.dSpin,u
        adda  slither.wDrop
        sta   slither.dSpin,u
        lda   slither.dPX,u
        sta   x_pixel,u
        lda   slither.dPY,u
        sta   y_pixel,u
        ldb   slither.dSpin,u
        andb  #$1E                     ; une pose toutes les DEUX trames,
        lsrb                           ; et seulement les seize premieres
        bra   @pose
        ; --- mode 2 : l'interprete ------------------------------------------
@script ldd   #slither.CorpseCB
        std   moveByScript.callback
        jsr   moveByScript.runByFrameDrop
        lda   moveByScript.anim.end
        lbne  @gone                    ; script fini : il s'efface
        lda   x_pos+1,u
        sta   x_pixel,u
        lda   y_pos+1,u
        sta   y_pixel,u
        ldb   anim_frame,u
        andb  #$0F
@pose   aslb
        ldx   #slither.BodySets
        lda   id,u
        cmpa  #ObjID_slither_tail_corpse
        bne   >
        ldx   #slither.TailSets
!       abx
        ldx   ,x
        stx   image_set,u
        ; --- la boite --------------------------------------------------------
        lda   x_pixel,u
        suba  #screen_left
        sta   slither.dAABB+AABB.cx,u
        lda   y_pixel,u
        suba  #screen_top
        sta   slither.dAABB+AABB.cy,u
        lda   slither.dAABB+AABB.p,u
        beq   @hit
        ; hors du cadre : l'arcade recycle (is_visible_range)
        lda   x_pixel,u
        suba  #screen_left
        cmpa  #screen_right-screen_left
        bhi   @gone
        lda   y_pixel,u
        suba  #screen_top
        cmpa  #screen_bottom-screen_top
        bhi   @gone
        jmp   DisplaySprite
@hit    ldb   #slither_body_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        beq   @gone
        _ldd  ObjID_explosion,explosion.subtype.smallx2
        std   id,x
        ldb   x_pixel,u                ; meme frontiere, voir slither.RecExplode
        clra
        subd  #screen_left
        addd  glb_camera_x_pos
        std   x_pos,x
        ldb   y_pixel,u
        clra
        subd  #screen_top
        std   y_pos,x
@gone   _Collision_RemoveAABB slither.dAABB,AABB_list_ennemy
        lda   #2
        sta   routine,u
        jmp   DeleteObject

; Le callback de l'interprete. Il ne pousse rien — mais il DOIT couper la
; boucle de rattrapage quand le script se termine, sinon l'interprete lit
; au-dela de sa fin. Meme geste que slither.Push.
slither.CorpseCB
        lda   moveByScript.anim.end
        beq   >
        clr   moveByScript.anim.loops
!       rts

;*******************************************************************************
; LE RENDERER GROUPE (suite)
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
; Les seize poses BLANCHES de la tete. Elles vivent sur LEUR page — voir
; stage5.cast.imgHeadHit dans le config — que seul ObjID_slither_head_hit
; monte. C'est pourquoi l'objet change d'identifiant le temps du flash.
slither.HeadHitSets
        fdb   set_slither_headhit_0,set_slither_headhit_1
        fdb   set_slither_headhit_2,set_slither_headhit_3
        fdb   set_slither_headhit_4,set_slither_headhit_5
        fdb   set_slither_headhit_6,set_slither_headhit_7
        fdb   set_slither_headhit_8,set_slither_headhit_9
        fdb   set_slither_headhit_10,set_slither_headhit_11
        fdb   set_slither_headhit_12,set_slither_headhit_13
        fdb   set_slither_headhit_14,set_slither_headhit_15

slither.HeadSets
        fdb   set_slither_head_0,set_slither_head_1
        fdb   set_slither_head_2,set_slither_head_3
        fdb   set_slither_head_4,set_slither_head_5
        fdb   set_slither_head_6,set_slither_head_7
        fdb   set_slither_head_8,set_slither_head_9
        fdb   set_slither_head_10,set_slither_head_11
        fdb   set_slither_head_12,set_slither_head_13
        fdb   set_slither_head_14,set_slither_head_15
