;*******************************************************************************
; outslay — le serpent symbiotique du stage 2
;
; FICHE DE PORTAGE (source : base Ghidra `maincpu`, subsystem actor/outslay)
; -------------------------------------------------------------------------
;   40:915b create_outslay ............... le MAITRE (outslay.Object)
;   40:91cc tick_outslay_segment_chain ... le script de chaine (RecInit ici)
;   1000:40c6 outslay_segment_spawn_script  22 spawns : tete, cou, 18 corps,
;             queue, finalizer — delais 10/11, CUMULES dans RecInit
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
; ARCHITECTURE V3 — UN INTERPRETE, DES SUIVEURS PAR HISTORIQUE (21/08/2026,
; decision auteur ; le patron est le rebound laser — forcepods/
; obj_reboundlaser.asm : « only the parent object go through collisions,
; childs follow the parent »).
;
; Les 22 segments partagent le MEME script de mouvement, decale dans le
; temps. Les premieres formes le faisaient interpreter par CHAQUE segment
; (22 OST, 22 moveByScript, 22 dispatches RunObjects avec montage de page) ;
; a frame drop 5, ~220 pas de script interpretes par boucle. Ici :
;
;   - le MAITRE (l'ancien emetteur) est le seul interprete. Son callback
;     moveByScript — appele une fois par TRAME VIDEO, position a jour, page
;     du cast remontee — pousse (x, y, pose) dans un ANNEAU RESIDENT de 256
;     entrees en trois plans d'octets (la reference ecran rend tout octet ;
;     256 = wrap gratuit, l'index d'anneau est un octet qui deborde seul) ;
;   - 20 SEGMENTS SANS OST (cou, 18 corps, queue) : un record de 2 octets
;     (etat, cran de tir) sur la page du cast, une boite AABB STATIQUE dans
;     la zone residente — la passe de collision du MOTEUR les traite comme
;     n'importe quelle boite, l'echange de degats reste chez lui. Leur
;     position = l'anneau, lu a (ecriture - 1 - retard) ; le retard de
;     chaque record est une CONSTANTE (RecInit, delais arcade cumules) ;
;   - 2 SUIVEURS A OST (tete, finalizer) : leurs images vivent sur l'AUTRE
;     page (stage2.cast.imgHead), que seul le moteur — resident — sait
;     monter. Ils lisent l'anneau (retards 0 et 227), passent par
;     DisplaySprite, et VALIDENT leur maitre (id + routine, le geste du
;     rebound laser) avant chaque lecture ;
;   - le RENDERER GROUPE (outslay.Render) dessine les 20 slots publies par
;     le maitre via le faux imageset — un seul preambule BuildSprites.
;
; Ce que la v3 supprime : 20 slots de pool, 20 dispatches RunObjects (et
; leurs montages de page), 21 interpreteurs, et les pointeurs d'aines —
; l'array ordonne EST la chaine, la « limite connue » du pointeur perime
; meurt ici. Ce qui reste au moteur : la collision et le dessin des bouts.
;
; LA VARIANTE. La wave cite l'outslay une fois ($0E88, token $04 -> variante
; 4, entree par le bord droit) ; le gomander pond les tokens 0..3 pendant
; son combat (wavescript 1000:4d62). L'horloge de tir de la tete depend du
; bit 2 du token (91af) : $C0 s'il est mis (la traversee), $50 sinon — les
; serpents du boss tirent plus souvent. Premiere echeance base+$28 (91a6).
;
; CE QUI EST ABANDONNE (et pourquoi) :
; - la mort chainee (40:954b) ne se declenche que sous Gomander (tick ==
;   0xa523) ; nos serpents meurent par la fin du script. Au boss de la
;   declencher le jour ou son corps existera.
; - le swap de palette du 2e loop (40:957c) : palette TO8 globale.
; - le bruitage 0x5d de la salve : le tir ennemi est muet en v2.
;
; LA PARITE DE COLLISION ARCADE EST PORTEE ((counter XOR priorite) & 1, un
; segment sur deux par boucle, tete opposee a la queue, finalizer toujours
; arme — 925b/94f6/93d9/948c). Le gate est le POTENTIEL : Collision_Do saute
; une boite a p=0 dans les DEUX sens (@skipu/@skipx). La phase bascule par
; TOUR DE BOUCLE — une parite tiree de frame.count derive sous frame drop
; pair, la lecon du tailmgr (TMcolPhase). Graine = rang & 1 : voisins
; opposes. Le verdict d'un coup au corps se lit a la transition armee ->
; desarmee, la seule ou un p nul veuille dire « touche ».
;
; REFERENCE ECRAN NATIVE (decision auteur) : x/y vivent dans le cadre
; 48-207 / 28-227 de DRS_XYToAddress. L'outslay ne lit jamais le delta
; camera arcade (0x2ED0) : sa choregraphie est ecrite en repere ecran — et
; c'est elle qui rend l'anneau petit (des octets) et la publication sans
; conversion. Les FRONTIERES convertissent : foefire et explosions
; repassent en playfield au spawn, le joueur dans le test de portee.
;
; NOMMAGE : tout le cast du stage 2 est une seule unite — prefixe `outslay.`
; partout (voir cast.unit.asm).
;*******************************************************************************

; --- LA ZONE RESIDENTE (layout : <reserved name="stage.outslay">) ------------
; Anneau et boites DOIVENT etre residents : le callback pousse depuis la page
; du cast, la passe de collision suit ses listes sans monter de page, et les
; suiveurs a OST lisent l'anneau depuis le chemin moteur.
outslay.res       equ $9A00
outslay.ringX     equ outslay.res          ; 256 octets — x ecran
outslay.ringY     equ outslay.res+256      ; 256 octets — y ecran
outslay.ringP     equ outslay.res+512      ; 256 octets — pose du script
outslay.boxes     equ outslay.res+768      ; 20 x sizeof{AABB} (9) = 180
outslay.res.END   equ outslay.res+768+20*9
 IFNE outslay.res.END-($9A00+$3B4)
        ERROR zone stage.outslay : accord layout/equates rompu (adresse ou taille)
 ENDC

; --- LE MAITRE : ext_variables (l'etat moveByScript vit dans son OST) --------
outslay.mClock    equ ext_variables+0    ; 0,1  horloge de graine (arcade [+0x20])
outslay.mClkBase  equ ext_variables+2    ; 2    periode : $C0 (bit2 du token) ou $50
outslay.mSeed     equ ext_variables+3    ; 3    graine de tir (1..4, 0 sinon)
outslay.mFrames   equ ext_variables+4    ; 4,5  L'HORLOGE DE LA CHAINE : le compte
                                         ;      de POUSSEES pendant le script (le
                                         ;      callback l'incremente — l'octet bas
                                         ;      EST l'index d'anneau), puis le temps
                                         ;      qui continue pendant le drain. Une
                                         ;      lecture s'indexe TOUJOURS dessus :
                                         ;      indexer sur un curseur d'ecriture
                                         ;      fige le serpent a la fin du script
                                         ;      (vecu — gel + effacement remontant)
outslay.mEndF     equ ext_variables+6    ; 6,7  poussees a la fin du script ($7FFF avant)
                                         ; 8    (libre — ex-index d'ecriture)
outslay.mActive   equ ext_variables+9    ; 9    nb de records eveilles (0..20)
outslay.mState    equ ext_variables+10   ; 10   0 = script en cours, 1 = drain
outslay.mFinDone  equ ext_variables+11   ; 11   1 = finalizer pose
outslay.mPhase    equ ext_variables+12   ; 12   parite de collision, bascule par boucle

; --- LES SUIVEURS A OST (tete / finalizer) -----------------------------------
outslay.fMaster   equ ext_variables+0    ; 0,1  l'OST du maitre (valide avant usage)
outslay.fDelay    equ ext_variables+2    ; 2    retard en trames (0 tete, 227 finalizer)
outslay.fPhase    equ ext_variables+3    ; 3    parite de collision (tete seulement)
outslay.fAABB     equ ext_variables+4    ; 4..12

; --- LES RECORDS (page du cast) : 2 octets par segment sans OST --------------
outslay.RS        equ 0                  ; etat : 0 inactif, 1 vivant, 2 cadavre, 3 fini
outslay.RC        equ 1                  ; cran de la cascade de tir
outslay.RECSZ     equ 2
outslay.NREC      equ 20

; roles des records (RecInit) et subtypes des suiveurs
outslay.role.neck equ 0
outslay.role.body equ 1
outslay.role.tail equ 2
outslay.sub.head  equ 0
outslay.sub.fin   equ 1

; 9388..93b2 : salve si Manhattan(joueur) < 0x90 = 144 px arcade. Echelles v2 :
; X 0.375, Y 0.75 (le double) -> |dx| + |dy|/2 < 54 en pixels larges.
outslay.fireRange equ 54

;*******************************************************************************
; LE MAITRE — create_outslay (40:915b) + la chaine (40:91cc) + les 20 records
;*******************************************************************************

outslay.Object
        lda   routine,u
        asla
        ldx   #outslay.MasterTab
        jmp   [a,x]
outslay.MasterTab
        fdb   outslay.MasterInit
        fdb   outslay.MasterLive
        fdb   outslay.Deleted

outslay.MasterInit
        ; DEUX champs a sauver avant de les recouvrir : le token (subtype_w+1,
        ; sous render_flags) et le retard de wave — wave_frame_drop ALIASE
        ; anim_frame_duration (+13), que l'init du script ecrase avec la
        ; vitesse. Vecu sur machine : le retard lu apres valait toujours 2.
        ldb   wave_frame_drop,u
        stb   @late
        ldb   subtype_w+1,u
        stb   @token
        andb  #7
        ldx   #outslay.Variants
        aslb                           ; 6 octets par rangee, comme l'arcade
        pshs  b
        aslb
        addb  ,s+
        abx
        ; 9183 / 918b : X et Y, constantes d'ECRAN (cadre 48/28 cuit en table)
        ldd   2,x
        std   x_pos,u
        ldd   4,x
        std   y_pos,u
        ; 917b + 921e..922a : le script de la variante, initialise UNE fois —
        ; le maitre est le seul interprete. 2 pas de deplacement par trame.
        ldx   ,x
        jsr   moveByScript.initialize
        lda   #2
        sta   anim_frame_duration,u
        ; 91a6 / 91af : l'horloge de tir. bit2 du token -> periode $C0, sinon
        ; $50 ; premiere echeance a periode + $28.
        ldb   #0
@token  equ   *-1
        andb  #4
        beq   >
        ldb   #$C0-$50
!       addb  #$50
        stb   outslay.mClkBase,u
        clra
        addd  #$28
        std   outslay.mClock,u
        ; le maitre ne dessine rien
        clr   priority,u
        clr   render_flags,u           ; coordonnees ECRAN
        ; l'etat de chaine a zero — records, slots, compteurs. Les slots du
        ; serpent precedent s'eteignent ici (le stage en pose neuf).
        clr   outslay.mSeed,u
        clr   outslay.mActive,u
        clr   outslay.mState,u
        clr   outslay.mFinDone,u
        clr   outslay.mPhase,u
        ldd   #0
        std   outslay.mFrames,u
        ldd   #$7FFF
        std   outslay.mEndF,u
        ldx   #outslay.Recs
        ldb   #outslay.NREC*outslay.RECSZ
!       clr   ,x+
        decb
        bne   <
        ldx   #outslay.Slots
        ldb   #outslay.SLOTS*outslay.SLOTSZ
!       clr   ,x+
        decb
        bne   <
        ; le renderer groupe, puis le suiveur TETE (retard 0)
        jsr   LoadObject_x
        beq   >
        lda   #ObjID_outslay_render
        sta   id,x
!       ldb   #outslay.sub.head
        jsr   outslay.SpawnFollower
        inc   routine,u
        ; le retard de la wave (sauve en tete d'Init) : derouler l'interprete
        ; d'autant — chaque trame rattrapee pousse SON entree d'anneau via le
        ; callback, la chaine entiere reste calee sur l'horodatage arcade.
        ldb   #0
@late   equ   *-1
        beq   @done
        ldd   #outslay.Push            ; chaque poussee du rattrapage avance
        std   moveByScript.callback    ; l'horloge elle-meme
        ldb   @late
        jsr   moveByScript.runByB
@done   rts

; Le callback de l'interprete : une fois par TRAME VIDEO, position a jour,
; U = le maitre, page du cast remontee par moveByScript. Le point de poussee.
outslay.Push
        ldb   outslay.mFrames+1,u      ; n poussees faites -> la n-ieme s'ecrit
        lda   x_pos+1,u                ; en n (mod 256, l'octet deborde seul)
        ldx   #outslay.ringX
        abx
        sta   ,x
        lda   y_pos+1,u
        ldx   #outslay.ringY
        abx
        sta   ,x
        lda   anim_frame,u
        ldx   #outslay.ringP
        abx
        sta   ,x
        ldd   outslay.mFrames,u        ; l'horloge avance AVEC la poussee : les
        addd  #1                       ; deux ne peuvent pas diverger
        std   outslay.mFrames,u
        ; fin de script : sortir de la boucle (le geste de l'ancien endCheck)
        lda   moveByScript.anim.end
        beq   >
        clr   moveByScript.anim.loops
!       rts

outslay.MasterLive
        ; --- 1) l'horloge. Pendant le script, elle avance PAR LES POUSSEES
        ; (le callback l'incremente : impossible de diverger de l'anneau) ;
        ; pendant le drain, plus personne ne pousse — c'est la boucle qui la
        ; fait avancer, en trames video, et les lectures des suiveurs
        ; continuent de descendre l'anneau deja ecrit jusqu'a leur fin.
        ldb   gfxlock.frameDrop.count
        bne   >
        incb                           ; miroir du garde de runByFrameDrop
!       clra
        pshs  d
        lda   outslay.mState,u
        beq   @interp
        ldd   outslay.mFrames,u
        addd  ,s
        std   outslay.mFrames,u
        bra   @seedclk
@interp
        ; --- 2) l'interprete unique, et le debut du drain a la fin ----------
        ldd   #outslay.Push
        std   moveByScript.callback
        jsr   moveByScript.runByFrameDrop
        lda   moveByScript.anim.end
        beq   @seedclk
        lda   #1                       ; 9569 : script fini — le maitre ne
        sta   outslay.mState,u         ; pousse plus, chaque suiveur draine
        ldd   outslay.mFrames,u        ; l'anneau deja ecrit, a son tour
        std   outslay.mEndF,u
@seedclk
        ; --- 3) la graine de tir de la tete (925b : remise a zero chaque
        ; boucle, semee quand l'horloge tombe) -------------------------------
        clr   outslay.mSeed,u
        ldd   outslay.mClock,u
        subd  ,s++
        std   outslay.mClock,u
        lbgt  @noseed
        ldb   outslay.mClkBase,u
        clra
        addd  outslay.mClock,u
        bgt   >
        ldb   outslay.mClkBase,u       ; drop enorme : repartir de la periode
        clra
!       std   outslay.mClock,u
        jsr   RandomNumber             ; 927d..9283 : graine 1..4
        andb  #3
        incb
        stb   outslay.mSeed,u
@noseed
        ; --- 4) activation des records, dans l'ordre des retards ------------
@act    ldb   outslay.mActive,u
        cmpb  #outslay.NREC
        bhs   @actEnd
        aslb
        ldx   #outslay.RecInit
        abx
        ldb   ,x                       ; le retard du prochain (octet)
        clra
        pshs  d
        ldd   outslay.mFrames,u
        cmpd  ,s++
        ble   @actEnd                  ; STRICTEMENT superieur : a egalite la
                                       ; lecture vaudrait -1, soit l'entree 255
                                       ; — une position rassise d'un serpent
                                       ; precedent. Le record nait a mFrames =
                                       ; retard + 1, ou sa lecture vaut 0 : le
                                       ; point de depart de la tete, ce qui est
                                       ; exactement le suivi a la file.
        ldb   1,x                      ; le role, tant que X pointe encore RecInit
        stb   outslay.wRole
        ; sa boite statique entre en liste, armee (voir le potentiel plus bas).
        ; La NETTOYER D'ABORD, prev/next compris : la zone reservee n'est pas
        ; zeroee (reserved-ram-is-not-zeroed.md — la lecon de la trainee du
        ; joueur, repayee ici : next residuel $FFFF, et le chemin « liste
        ; vide » de Collision_AddAABB n'ecrit pas le next de l'inseree — la
        ; passe partait dans des pseudo-boites a $FFFF et mangeait la boucle).
        lda   outslay.mActive,u
        ldb   #sizeof{AABB}
        mul
        addd  #outslay.boxes
        tfr   d,x
        ldb   #sizeof{AABB}
!       clr   ,x+
        decb
        bne   <
        leax  -sizeof{AABB},x
        lda   #outslay_hitbox_x
        sta   AABB.rx,x
        lda   #outslay_hitbox_y
        sta   AABB.ry,x
        ; LE POTENTIEL DE NAISSANCE — surtout pas zero. La marche de CE tour
        ; peut tomber sur la phase desarmee, et ce chemin lit p == 0 comme un
        ; coup encaisse : la phase dependant de (rang XOR mPhase), un segment
        ; sur deux naissait en CADAVRE (vecu). On le pose donc a sa valeur
        ; armee ; la parite le reprendra des le tour suivant.
        lda   #outslay_hitdamage_immune
        ldb   outslay.wRole            ; le role, releve avant de perdre X
        cmpb  #outslay.role.body
        bne   >
        lda   #outslay_hitdamage
!       sta   AABB.p,x
        pshs  u
        ldy   #AABB_list_ennemy
        jsr   Collision_AddAABB
        puls  u
        ; le record s'eveille
        ldb   outslay.mActive,u
        aslb
        ldx   #outslay.Recs
        abx
        lda   #1
        sta   outslay.RS,x
        clr   outslay.RC,x
        inc   outslay.mActive,u
        bra   @act
@actEnd
        ; --- 5) le finalizer, 227 trames apres la tete ----------------------
        lda   outslay.mFinDone,u
        bne   @fin
        ldd   outslay.mFrames,u
        cmpd  #227
        blt   @fin
        inc   outslay.mFinDone,u
        ldb   #outslay.sub.fin
        jsr   outslay.SpawnFollower
@fin
        ; --- 6) la parite globale et la pose du corps -----------------------
        lda   outslay.mPhase,u
        eora  #1
        sta   outslay.mPhase,u
        ; 93bc : 4 images, 8 trames de maintien — la MEME pose pour tous les
        ; corps, calculee une fois par boucle. L'octet BAS du compteur (+1 :
        ; l'ancienne version lisait l'octet HAUT du fdb, l'animation du corps
        ; etait quasi figee — bug dormant corrige ici).
        ldb   gfxlock.frame.count+1
        andb  #$18
        lsrb
        lsrb                           ; (count & $18) >> 3, puis * 2 : table fdb
        ldx   #outslay.BodySets
        abx
        ldd   ,x
        std   outslay.wBodySet
        ; --- 7) LA MARCHE DES 20 RECORDS ------------------------------------
        clr   outslay.wN
        lbra  outslay.Walk

; --- 8) la fin de vie du maitre (retour de la marche) ------------------------
outslay.MasterEnd
        lda   outslay.mState,u
        beq   @ret
        ldd   outslay.mFrames,u
        subd  #227
        cmpd  outslay.mEndF,u
        blt   @ret
        ; le dernier suiveur est passe : tout est eteint, on rend le slot
        lda   #2
        sta   routine,u
        jmp   UnloadObject_u           ; jamais dessine : pas de DeleteObject
@ret    rts

outslay.Deleted
        rts

; -----------------------------------------------------------------------------
; LA MARCHE : un record = position depuis l'anneau, slot, boite, cascade.
; Tous les pointeurs se recalculent depuis wN — les aides (LoadObject...)
; ont le droit de tout clobber.
; -----------------------------------------------------------------------------
outslay.Walk
@loop   ldb   outslay.wN
        aslb
        ldx   #outslay.Recs
        abx
        lda   outslay.RS,x
        lbeq  @next                    ; inactif
        cmpa  #3
        lbeq  @next                    ; fini
        sta   outslay.wState
        ; le retard et le role, constants (RecInit)
        ldb   outslay.wN
        aslb
        ldx   #outslay.RecInit
        abx
        ldd   ,x                       ; A = retard, B = role
        sta   outslay.wDelay
        stb   outslay.wRole
        ; -- le drain : le record s'eteint quand sa lecture atteint la fin --
        ldb   outslay.mState,u
        lbeq  @pos
        ldb   outslay.wDelay
        clra
        pshs  d
        ldd   outslay.mFrames,u
        subd  ,s++
        cmpd  outslay.mEndF,u
        lblt  @pos
        ; retirer la boite de la liste — les operandes de Remove se patchent
        ; par appel, comme le fait le macro
        ldx   #AABB_list_ennemy
        stx   Collision_Remove_1
        stx   Collision_Remove_3
        leax  2,x
        stx   Collision_Remove_2
        jsr   outslay.WBoxPtr
        pshs  u
        jsr   Collision_RemoveAABB
        puls  u
        jsr   outslay.WSlotPtr
        clr   ,y
        ldb   outslay.wN
        aslb
        ldx   #outslay.Recs
        abx
        lda   #3
        sta   outslay.RS,x
        lbra  @next
@pos
        ; -- la position : l'anneau, a (horloge - 1 - retard) — l'octet bas
        ; de mFrames, valable script en cours COMME en drain ----------------
        ldb   outslay.mFrames+1,u
        decb
        subb  outslay.wDelay
        stb   outslay.wIdx
        ldx   #outslay.ringX
        abx
        lda   ,x
        sta   outslay.wPx
        ldb   outslay.wIdx
        ldx   #outslay.ringY
        abx
        lda   ,x
        sta   outslay.wPy
        ldb   outslay.wIdx
        ldx   #outslay.ringP
        abx
        lda   ,x
        sta   outslay.wPose
        ; -- le set d'images du role ----------------------------------------
        ldb   outslay.wRole
        beq   @neck
        cmpb  #outslay.role.tail
        beq   @tail
        lda   outslay.wState           ; le corps : vivant ou cadavre
        cmpa  #2
        beq   @corpse
        ldx   #0
outslay.wBodySet equ *-2
        bra   @pub
@corpse ldx   #set_outslay_broken_0
        bra   @pub
@neck   ldb   outslay.wPose
        bra   @nt
@tail   ldb   outslay.wPose            ; 94f6 : la moitie arriere du pool
        addb  #8
@nt     andb  #$0F
        aslb
        ldx   #outslay.NeckSets
        abx
        ldx   ,x
@pub    jsr   outslay.WSlotPtr         ; Y = slot
        lda   outslay.wPx
        ldb   outslay.wPy
        jsr   outslay.RecPublish
        ; -- la boite : position, puis parite -------------------------------
        jsr   outslay.WBoxPtr          ; X = boite
        lda   outslay.wPx
        suba  #screen_left
        sta   AABB.cx,x
        lda   outslay.wPy
        suba  #screen_top
        sta   AABB.cy,x
        ldb   outslay.wN
        eorb  outslay.mPhase,u
        andb  #1
        beq   @disarm
        ; la boucle armee : le corps vivant expose ses PV, le reste l'immunite
        lda   #outslay_hitdamage_immune
        ldb   outslay.wRole
        cmpb  #outslay.role.body
        bne   @arm
        ldb   outslay.wState
        cmpb  #1
        bne   @arm
        lda   #outslay_hitdamage
@arm    sta   AABB.p,x
        bra   @casc0
@disarm
        ; la fenetre armee se ferme : pour un corps vivant, p nul = touche
        ldb   outslay.wRole
        cmpb  #outslay.role.body
        bne   @dis2
        ldb   outslay.wState
        cmpb  #1
        bne   @dis2
        lda   AABB.p,x
        bne   @dis2
        jsr   outslay.RecExplode       ; 93fa : score, sfx, explosion, cadavre
        lda   #2
        sta   outslay.wState
        jsr   outslay.WBoxPtr
@dis2   clr   AABB.p,x                 ; hors de la passe jusqu'au prochain tour
@casc0
        ; -- la cascade de tir (9367..93b9 ; l'ordre d'execution est garde :
        ; chaque record lit l'aine DEJA mis a jour cette boucle, comme les
        ; OST couraient dans l'ordre de spawn) -------------------------------
        ldb   outslay.wN
        beq   @seed
        decb
        aslb
        ldx   #outslay.Recs
        abx
        lda   outslay.RC,x             ; le cran de l'aine (record n-1)
        ldb   outslay.RS,x
        stb   outslay.wElderS
        bra   @casc
@seed   lda   outslay.mSeed,u          ; l'aine du cou est la tete du maitre
        ldb   #1
        stb   outslay.wElderS
@casc   deca                           ; cran - 1
        sta   outslay.wCool
        ldb   outslay.wRole
        cmpb  #outslay.role.body
        bne   @cstore                  ; cou et queue : heritage brut
        ldb   outslay.wState
        cmpb  #2
        beq   @cflor                   ; 9440 : le cadavre borne a 1, sans tir
        tsta                           ; le tour du corps vivant ?
        bne   @cstore
        ldb   outslay.wElderS          ; l'aine tire-t-il encore ? (9370..9382)
        cmpb  #3
        beq   @cstore                  ; aine eteint : le cran meurt a zero
        jsr   outslay.RecInRangeFire   ; a portee -> salve, C=1
        bcc   @cone                    ; hors de portee : repropager le 1
        clr   outslay.wCool
        bra   @cstore
@cone   lda   #1
        sta   outslay.wCool
        bra   @cstore
@cflor  tsta
        bne   @cstore
        lda   #1
        sta   outslay.wCool
@cstore ldb   outslay.wN
        aslb
        ldx   #outslay.Recs
        abx
        lda   outslay.wCool
        sta   outslay.RC,x
@next   inc   outslay.wN
        lda   outslay.wN
        cmpa  #outslay.NREC
        lblo  @loop
        lbra  outslay.MasterEnd

; les variables de marche, sur la page (ecrites page montee par RunObjects)
outslay.wN      fcb 0
outslay.wState  fcb 0
outslay.wRole   fcb 0
outslay.wDelay  fcb 0
outslay.wIdx    fcb 0
outslay.wPx     fcb 0
outslay.wPy     fcb 0
outslay.wPose   fcb 0
outslay.wCool   fcb 0
outslay.wElderS fcb 0
outslay.wSh     fcb 0

; X = la boite statique du record wN
outslay.WBoxPtr
        lda   outslay.wN
        ldb   #sizeof{AABB}
        mul
        addd  #outslay.boxes
        tfr   d,x
        rts

; Y = le slot du record wN
outslay.WSlotPtr
        lda   outslay.wN
        ldb   #outslay.SLOTSZ
        mul
        addd  #outslay.Slots
        tfr   d,y
        rts

; -----------------------------------------------------------------------------
; Publier un record : le cull « entierement dans le cadre » du moteur, en
; octets et referentiel decale, puis la recopie. La GEOMETRIE vient de
; l'imageset, jamais de constantes recopiees.
;   +4 x_size  +5 y_size  +6 center_offset  +11 x1  +12 y1  +14,15 routine
; entree : A = x ecran, B = y ecran, X = set, Y = slot
; -----------------------------------------------------------------------------
outslay.RecPublish
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
        suba  6,x                      ; le centre pair/impair, comme le moteur
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
; La portee puis la salve — 9388..93b2 + 40:95a3. C=1 si la salve est partie.
; Le joueur (playfield) est amene en ecran ; les tirs repartent en playfield.
; -----------------------------------------------------------------------------
outslay.RecInRangeFire
        ldd   player1+x_pos
        subd  glb_camera_x_pos
        addd  #screen_left
        pshs  d
        ldb   outslay.wPx
        clra
        subd  ,s++
        bpl   >
        coma
        comb
        addd  #1                       ; |dx|
!       pshs  d
        ldd   player1+y_pos
        addd  #screen_top
        pshs  d
        ldb   outslay.wPy
        clra
        subd  ,s++
        bpl   >
        coma
        comb
        addd  #1                       ; |dy|
!       lsra                           ; |dy| / 2 : l'axe Y pese double
        rorb
        addd  ,s++
        cmpd  #outslay.fireRange
        bhs   @no
        ; 95a3 : huit tirs en etoile. FRONTIERE : conversion playfield UNE fois.
        ldb   outslay.wPx
        clra
        subd  #screen_left
        addd  glb_camera_x_pos
        std   outslay.wFx
        ldb   outslay.wPy
        clra
        subd  #screen_top
        std   outslay.wFy
        clr   outslay.wSh
@loop   jsr   LoadObject_x
        beq   @full
        lda   #ObjID_foefire
        sta   id,x
        ldd   #0
outslay.wFx equ *-2
        std   x_pos,x
        ldd   #0
outslay.wFy equ *-2
        std   y_pos,x
        ldb   outslay.wSh
        aslb
        aslb                           ; 4 octets par direction
        ldy   #outslay.ShotVelocity
        leay  b,y
        ldd   ,y
        std   x_vel,x
        ldd   2,y
        std   y_vel,x
@full   inc   outslay.wSh
        lda   outslay.wSh
        cmpa  #8
        blo   @loop
        orcc  #1                       ; C = 1 : salve partie
        rts
@no     andcc #$FE
        rts

; -----------------------------------------------------------------------------
; La mort d'un corps — 40:93fa. Score, bruitage, explosion ; le record devient
; un cadavre qui suit toujours l'anneau (l'emplacement n'est pas rendu).
; -----------------------------------------------------------------------------
outslay.RecExplode
        ldb   #outslay_scoreIdx        ; 9410 : 0x86ec
        jsr   AwardScore
        _soundFX.play soundFX.ExplosionSound,1
        jsr   LoadObject_x
        beq   @mark
        _ldd  ObjID_explosion,explosion.subtype.smallx2
        std   id,x
        ldb   outslay.wPx              ; FRONTIERE : l'explosion vit en playfield
        clra
        subd  #screen_left
        addd  glb_camera_x_pos
        std   x_pos,x
        ldb   outslay.wPy
        clra
        subd  #screen_top
        std   y_pos,x
@mark   ldb   outslay.wN
        aslb
        ldx   #outslay.Recs
        abx
        lda   #2                       ; cadavre
        sta   outslay.RS,x
        rts

; B = subtype (0 tete, 1 finalizer). Le maitre ecrit sa propre adresse dans
; l'enfant AVANT son premier tour, comme le rebound laser.
outslay.SpawnFollower
        pshs  b
        jsr   LoadObject_x
        puls  b
        beq   @rts
        lda   #ObjID_outslay_head
        std   id,x                     ; id + subtype d'un coup
        stu   outslay.fMaster,x
@rts    rts

;*******************************************************************************
; LES SUIVEURS A OST — tete et finalizer, images sur stage2.cast.imgHead.
; Chemin moteur (coordonnees ECRAN, DisplaySprite) ; la position vient de
; l'anneau, le maitre est valide avant chaque lecture (id + routine).
;*******************************************************************************

outslay.Segment
        lda   routine,u
        asla
        ldx   #outslay.FolTab
        jmp   [a,x]
outslay.FolTab
        fdb   outslay.FolInit
        fdb   outslay.FolLive
        fdb   outslay.Deleted

; PROFONDEUR. BuildSprites parcourt les rangs de 8 vers 1 : 8 est dessine en
; PREMIER (donc au fond), 1 en dernier (devant). Le serpent tient sur trois
; rangs pour se recouvrir comme l'arcade — tete dessus, chaque suivant dessous :
;   5  la tete       dessinee en dernier, au-dessus de tout le corps
;   6  le renderer   les 20 records, parcourus a rebours (cf. outslay.DrawAll)
;   7  le finalizer  dessine en premier, tout au fond
; Les trois vivaient au rang 6 : leur ordre dependait alors de l'ordre
; d'INSERTION dans la liste du rang (BuildSprites part de la derniere entree et
; remonte les `prev`), c'est-a-dire de l'ordre de passage dans RunObjects. Ca
; tombait juste par accident ; c'est maintenant une decision.
outslay.FolInit
        lda   subtype,u                ; 0 tete, 1 finalizer — AVANT render_flags
        beq   @head
        lda   #227
        ldb   #7                       ; le finalizer ferme la marche
        bra   >
@head   ldb   #5                       ; la tete passe devant (A vaut deja 0)
!       sta   outslay.fDelay,u
        stb   priority,u
        clr   render_flags,u           ; coordonnees ECRAN
        _Collision_AddAABB outslay.fAABB,AABB_list_ennemy
        _ldd  outslay_hitbox_x,outslay_hitbox_y
        std   outslay.fAABB+AABB.rx,u
        clr   outslay.fAABB+AABB.p,u   ; la parite l'armera (le finalizer des
        clr   outslay.fPhase,u         ; son premier tour : arme chaque boucle)
        inc   routine,u
outslay.FolLive
        ; le maitre, valide comme le rebound laser valide son parent
        ldx   outslay.fMaster,u
        lda   id,x
        cmpa  #ObjID_outslay
        lbne  outslay.FolUnload
        lda   routine,x
        cmpa  #1
        lbne  outslay.FolUnload
        ; ou en est MA lecture ? (horloge du maitre - mon retard)
        ldb   outslay.fDelay,u
        clra
        pshs  d
        ldd   outslay.mFrames,x
        subd  ,s++                     ; D = ma lecture ; la pile est rendue ici
        lble  @hide                    ; pas encore ne : mon entree n'existe pas
        ; Le drain : mon tour est-il passe ? TST, PAS LDA — A porte l'octet
        ; HAUT de la lecture, et un LDA ici la tronquait a son octet bas : la
        ; comparaison passait sur (mState:bas) au lieu de la lecture entiere,
        ; la tete ne mourait jamais, repartait 256 entrees en arriere dans
        ; l'anneau — donc DERRIERE la queue, la chaine n'en couvrant que 227
        ; (vecu, lu dans l'OST : mFrames 1629, mEndF 1542, tete toujours en vie).
        tst   outslay.mState,x
        beq   @read
        cmpd  outslay.mEndF,x
        lbge  outslay.FolUnload
@read
        ; la position, a (horloge - 1 - retard) — voir la marche du maitre
        ldb   outslay.mFrames+1,x
        decb
        subb  outslay.fDelay,u
        stb   @idx
        ldx   #outslay.ringX
        abx
        lda   ,x
        ldb   #0
@idx    equ   *-1
        ldx   #outslay.ringY
        abx
        ldb   ,x
        std   xy_pixel,u               ; le chemin ecran du moteur lit ces octets
        ; la boite, dans le repere 0-base des autres
        suba  #screen_left
        sta   outslay.fAABB+AABB.cx,u
        subb  #screen_top
        stb   outslay.fAABB+AABB.cy,u
        ; la pose : la tete lit le pool tel quel, le finalizer decale de 8 (948c)
        ldb   @idx
        ldx   #outslay.ringP
        abx
        ldb   ,x
        lda   subtype,u
        beq   >
        addb  #8
!       andb  #$0F
        aslb
        ldx   #outslay.HeadImages
        abx
        ldd   ,x
        std   image_set,u
        ; la parite : la tete une boucle sur deux, le finalizer toujours (948c)
        lda   subtype,u
        bne   @armed
        lda   outslay.fPhase,u
        eora  #1
        sta   outslay.fPhase,u
        beq   @off
@armed  lda   #outslay_hitdamage_immune
        bra   >
@off    clra
!       sta   outslay.fAABB+AABB.p,u
        jmp   DisplaySprite
@hide   lda   render_flags,u           ; pas encore ne : rien a montrer
        ora   #render_hide_mask
        sta   render_flags,u
        rts

outslay.FolUnload
        lda   #2
        sta   routine,u
        _Collision_RemoveAABB outslay.fAABB,AABB_list_ennemy
        jmp   DeleteObject

;*******************************************************************************
; LE RENDERER GROUPE — un objet moteur pour les 20 slots (schema du tailmgr) :
; faux imageset, Img_Page_Index patche avec sa page, un seul preambule
; BuildSprites, DrawAll dessine tout. Il vit tant qu'un slot est allume.
;*******************************************************************************

outslay.SLOTS   equ outslay.NREC       ; un slot par record
outslay.SLOTSZ  equ 5                  ; [vivant, x_pixel, y_pixel, routine(2)]

outslay.FakeImg
        fcb   outslay.FakeSub-outslay.FakeImg,outslay.FakeSub-outslay.FakeImg
        fcb   outslay.FakeSub-outslay.FakeImg,outslay.FakeSub-outslay.FakeImg
        fcb   8,8,0
outslay.FakeSub
        fcb   0
        fcb   outslay.FakeMf-outslay.FakeSub
        fcb   0
        fcb   outslay.FakeMf-outslay.FakeSub
        fcb   0,0
outslay.FakeMf
        fcb   0                        ; page, patchee a l'Init
        fdb   outslay.DrawAll

outslay.Render
        lda   routine,u
        bne   outslay.RenderLive
        _GetCartPageA
        ldb   id,u
        ldx   #Img_Page_Index
        sta   b,x                      ; le moteur montera NOTRE page
        sta   outslay.FakeMf
        ldd   #outslay.FakeImg
        std   image_set,u
        clr   render_flags,u           ; coordonnees ecran, boite parquee au
        lda   #120                     ; centre : jamais eliminee hors-champ
        sta   x_pixel,u
        lda   #135
        sta   y_pixel,u
        ldb   #6
        stb   priority,u
        inc   routine,u
        jmp   DisplaySprite
outslay.RenderLive
        bsr   outslay.SlotsLive
        bne   @seen
        lda   routine,u
        cmpa  #2
        bne   >
        jmp   DeleteObject
!       jmp   DisplaySprite
@seen   lda   #2
        sta   routine,u
        jmp   DisplaySprite

; Z = 0 s'il reste au moins un slot allume.
outslay.SlotsLive
        ldx   #outslay.Slots
        ldb   #outslay.SLOTS
@l      lda   ,x
        bne   @yes
        leax  outslay.SLOTSZ,x
        decb
        bne   @l
        clra
@yes    rts

outslay.Slots   fill 0,outslay.SLOTS*outslay.SLOTSZ
outslay.Recs    fill 0,outslay.NREC*outslay.RECSZ
outslay.di      fcb 0

; Le dessin : par slot allume, l'adresse ecran puis la routine compilee.
; LE RECOUVREMENT DU SERPENT (21/08/2026). Pas de tri par sprite ici : c'est
; un peintre, le dernier dessine passe DESSUS. Le parcours va donc A REBOURS,
; de la queue (slot 19) vers le cou (slot 0), pour que chaque segment recouvre
; celui qui le suit — comme l'arcade, qui DECREMENTE la priorite a chaque
; enfant engendre (91e1) et met donc la tete devant.
; La tete et le finalizer ne passent pas par ici (ce sont des sprites moteur) :
; ils encadrent le lot par leur RANG de priorite, cf. outslay.FolInit.
outslay.DrawAll
        lda   #outslay.SLOTS
        sta   outslay.di
@loop   dec   outslay.di
        lda   outslay.di
        ldb   #outslay.SLOTSZ
        mul
        ldx   #outslay.Slots
        leax  d,x
        lda   ,x
        beq   @next
        ldd   1,x                      ; A = x_pixel, B = y_pixel (cadre DRS)
        pshs  x
        jsr   DRS_XYToAddress
        puls  x
        ldx   3,x
        ldu   <glb_screen_location_2
        jsr   ,x                       ; la routine consomme U
@next   tst   outslay.di
        bne   @loop
        rts

;*******************************************************************************
; LES TABLES
;*******************************************************************************

; 1000:40c6, les delais CUMULES depuis la tete (t = 0) : cou +10, dix-sept
; corps a +11, le dernier corps a +11 puis +10 avant la queue — b1 20, b2 31,
; ..., b17 196, b18 207, queue 217 ; le finalizer (227) est un suiveur OST.
; Chaque paire = (retard, role).
outslay.RecInit
        fcb   10,outslay.role.neck
        fcb   20,outslay.role.body
        fcb   31,outslay.role.body
        fcb   42,outslay.role.body
        fcb   53,outslay.role.body
        fcb   64,outslay.role.body
        fcb   75,outslay.role.body
        fcb   86,outslay.role.body
        fcb   97,outslay.role.body
        fcb   108,outslay.role.body
        fcb   119,outslay.role.body
        fcb   130,outslay.role.body
        fcb   141,outslay.role.body
        fcb   152,outslay.role.body
        fcb   163,outslay.role.body
        fcb   174,outslay.role.body
        fcb   185,outslay.role.body
        fcb   196,outslay.role.body
        fcb   207,outslay.role.body
        fcb   217,outslay.role.tail

; 1000:4086 outslay_spawn_variant_table — (script, X ecran, Y ecran), la
; valeur Conv (viewport) gardee en clair, le cadre DRS (+48, +28) cuit.
; Variantes 0..3 : les serpents du combat contre Gomander ; 4 : la traversee ;
; 5..7 jamais citees (rangee 3 recopiee pour que le masque & 7 reste sur).
outslay.Variants
        fdb   anim_1A4E6,58+screen_left,99+screen_top      ; 0 — arcade (452,265)
        fdb   anim_1A530,101+screen_left,100+screen_top    ; 1 — arcade (568,264)
        fdb   anim_1A56E,41+screen_left,166+screen_top     ; 2 — arcade (408,176)
        fdb   anim_1A626,120+screen_left,162+screen_top    ; 3 — arcade (619,182)
        fdb   anim_1A652,144+8+3+screen_left,70+screen_top ; 4 — arcade (712,304)
        fdb   anim_1A626,120+screen_left,162+screen_top    ; 5 — jamais cite
        fdb   anim_1A626,120+screen_left,162+screen_top    ; 6 — jamais cite
        fdb   anim_1A626,120+screen_left,162+screen_top    ; 7 — jamais cite

; 1000:411e — les 8 directions de la salve, echelle TO8 en 8.8. Export
; rejouable de re.arcade.r-type (PresetWordXYVel, records de 6 octets).
outslay.ShotVelocity
        INCLUDE "src/enemies/outslay/1411e_outslay-shotVelocity.asm"

; Les pools de poses. Tete et finalizer partagent 1000:419e (le finalizer
; decale de 8) — suiveurs OST, chemin moteur, images sur l'autre page. Cou
; et queue partagent 1000:41fe — records, publies par set.
outslay.HeadImages
        fdb   set_outslay_head_0,set_outslay_head_1
        fdb   set_outslay_head_2,set_outslay_head_3
        fdb   set_outslay_head_4,set_outslay_head_5
        fdb   set_outslay_head_6,set_outslay_head_7
        fdb   set_outslay_head_8,set_outslay_head_9
        fdb   set_outslay_head_10,set_outslay_head_11
        fdb   set_outslay_head_12,set_outslay_head_13
        fdb   set_outslay_head_14,set_outslay_head_15

outslay.NeckSets
        fdb   set_outslay_neck_0,set_outslay_neck_1
        fdb   set_outslay_neck_2,set_outslay_neck_3
        fdb   set_outslay_neck_4,set_outslay_neck_5
        fdb   set_outslay_neck_6,set_outslay_neck_7
        fdb   set_outslay_neck_8,set_outslay_neck_9
        fdb   set_outslay_neck_10,set_outslay_neck_11
        fdb   set_outslay_neck_12,set_outslay_neck_13
        fdb   set_outslay_neck_14,set_outslay_neck_15

; 1000:425e — les 4 images d'animation du corps.
outslay.BodySets
        fdb   set_outslay_body_0,set_outslay_body_1
        fdb   set_outslay_body_2,set_outslay_body_3
