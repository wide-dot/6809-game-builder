;*******************************************************************************
; bug — le gestionnaire de chaines, INSTANCIE (architecture outslay, 22/08/2026)
;
; TOUTES les chaines de bug passent ici — le code v1 par-objet est retire du
; chemin (obj_full reste inclus pour ses tables : ImageIndex, presets). Le
; createur devient le MAITRE, seul interprete du script ; les bugs sont des
; RECORDS sans OST qui lisent leur position dans un anneau d'historique.
;
; DEUX INSTANCES, dimensionnees sur la capacite MAX REELLE mesuree dans les
; waves des trois stages qui listent le bug (1, 4, 7) : jamais plus de deux
; chaines en vol, 48 records au pire (stage 7, t=1720 : la chaine de 10
; chevauche la chaine de 250 pendant ~314 trames).
;
;   LONGUE  anneau 1024 entrees, 40 records — la chaine $03 (250 bugs,
;           script 19B1C de 589 trames : lectures etalees sur ~605 trames)
;   COURTE  anneau 256 entrees, 12 records — toutes les autres (nb <= 10,
;           scripts 202-226 trames : etalement <= ~242)
;
; L'ALLOCATION (decision auteur) : la chaine $03 exige l'instance longue ;
; les autres prennent la courte, ou la longue si la courte est occupee. Les
; deux prises -> la chaine est SAUTEE, la semantique v1 de l'alloc KO.
;
; LA PROPRIETE se valide, elle ne se libere pas (l'idiome rebound-laser) :
; le bloc d'instance porte l'OST de son maitre, et un candidat la considere
; libre si ce proprietaire n'est plus un maitre de bug pointant sur elle.
; Un maitre efface par un nettoyage de pool (mort du joueur) ne fuit donc
; rien — et l'Init de l'instance re-nettoie records et slots.
;
; L'ANNEAU est ENTRELACE : une entree = 4 octets contigus (xH, xL, y, pose)
; a base + (horloge & masque) * 4. C'est ce qui rend la taille par instance
; invisible au code — les offsets 0..3 sont constants, seuls base et masque
; viennent du bloc d'instance.
;
; FIDELITE v1, verifiee point par point sur obj_main.asm :
;   - naissance : x = preset XY + camera (+24 pour les types 3..8), meme
;     point playfield pour toute la chaine ;
;   - coupure du point de spawn : x_spawn + 8 + 6 sous la camera -> plus
;     personne ne nait (v1 supprimait le createur) ;
;   - coupure d'un bug : x + 8 sous la camera -> mort muette ;
;   - mort par tir (p = 0) : score bug_scoreIdx + explosion smallx2 ;
;   - tir : cycle de presets Preset19260[offset + n mod 5], parametres
;     charges par loadFirePresetBug (PSR) a l'activation, compteur v1
;     reproduit a l'identique, salve par createFoeFire (PSR) en pokant la
;     position du record dans l'OST du maitre ;
;   - un record encore occupe a la naissance saute le bug SANS decaler la
;     cadence (l'alloc KO v1, encore).
;*******************************************************************************

; --- le maitre : ext_variables (l'etat moveByScript vit dans son OST) --------
bm.clock     equ ext_variables+0     ; 0,1  poussees pendant le script, puis
                                     ;      le temps du drain (voir outslay)
bm.endF      equ ext_variables+2     ; 2,3  poussees a la fin du script
bm.state     equ ext_variables+4     ; 4    0 = script en cours, 1 = drain
bm.spawned   equ ext_variables+5     ; 5    bugs nes ou sautes
bm.nb        equ ext_variables+6     ; 6    a engendrer (Preset19250)
bm.preset    equ ext_variables+7     ; 7    curseur du cycle de presets (0..4)
bm.presetOff equ ext_variables+8     ; 8    offset dans Preset19260
bm.startX    equ ext_variables+9     ; 9,10 le point de spawn, pour la coupure
bm.instp     equ ext_variables+11    ; 11,12 le bloc d'instance (InstL/InstS)

; --- le bloc d'instance (page de l'unite) ----------------------------------
I.owner      equ 0                   ; 0,1  l'OST du maitre proprietaire
I.ring       equ 2                   ; 2,3  base de l'anneau (entrelace x4)
I.mask       equ 4                   ; 4    masque de l'octet HAUT de l'index
I.nrec       equ 5                   ; 5    nombre de records
I.recs       equ 6                   ; 6,7  base des records
I.slots      equ 8                   ; 8,9  base des slots du renderer
I.boxes      equ 10                  ; 10,11 base des boites RESIDENTES
I.SIZE       equ 12

; --- les records (page de l'unite) : 9 octets ------------------------------
bm.RS        equ 0                   ; 0 libre, 1 vivant
bm.RVel      equ 1                   ; fireVelocityPreset (0 = pas de tir)
bm.RThr      equ 2                   ; fireThreshold
bm.RRst      equ 3                   ; fireReset (2)
bm.RCnt      equ 5                   ; fireCounter (2)
bm.RDelay    equ 7                   ; retard 16k, en trames (2)
bm.RECSZ     equ 9

bm.SLOTSZ    equ 5                   ; [vivant, x_pixel, y_pixel, routine(2)]
bugL.NREC    equ 40
bugS.NREC    equ 12

; --- le renderer : ext_variables ---------------------------------------------
rr.instp     equ ext_variables       ; 0,1  le bloc d'instance a dessiner

bugmgr.Object
        lda   routine,u
        suba  #5
        asla
        ldx   #bugmgr.Tab
        jmp   [a,x]
bugmgr.Tab
        fdb   bugmgr.Init
        fdb   bugmgr.Live
        fdb   bugmgr.Deleted

;*******************************************************************************
; L'INIT — l'instance d'abord (sans elle la chaine n'existe pas), puis le
; decodage v1 d'InitCreator, puis l'etat de chaine a zero
;*******************************************************************************
bugmgr.Init
        ; --- l'allocation : $03 exige la longue, les autres preferent la
        ; courte ; tout est pris -> la chaine est sautee (alloc KO v1) -------
        ldb   subtype,u
        andb  #3
        cmpb  #3
        beq   @long
        ldx   #bugmgr.InstS
        jsr   bugmgr.InstFree
        beq   @claim
@long   ldx   #bugmgr.InstL
        jsr   bugmgr.InstFree
        beq   @claim
        jmp   UnloadObject_u           ; jamais dessine : pas de DeleteObject
@claim  stu   I.owner,x
        stx   bm.instp,u
        ; wave_frame_drop ALIASE anim_frame_duration : le lire AVANT que la
        ; vitesse du script ne l'ecrase (la lecon du maitre outslay)
        ldb   wave_frame_drop,u
        stb   @late
        ; presets : offset et taille de chaine par le type (Preset19250)
        ldb   subtype,u
        andb  #3
        aslb
        ldx   #Preset19250
        abx
        ldd   ,x
        sta   bm.presetOff,u
        stb   bm.nb,u
        clr   bm.spawned,u
        clr   bm.preset,u
        ; l'animation, comme v1 (bits 3..6 du token)
        ldx   #anim_192EC
        ldb   subtype+1,u
        lsrb
        lsrb
        lsrb
        andb  #%00001110
        abx
        jsr   moveByScript.initialize
        ; le point de depart, comme v1 (bits 0..3 : preset XY + camera)
        ldb   subtype+1,u
        andb  #$0F
        stb   @type
        aslb
        ldx   #PresetXYIndex
        abx
        clra
        ldb   1,x
        std   y_pos,u
        ldd   #0
@type   equ   *-2
        cmpa  #3
        blo   >
        cmpa  #9
        bhs   >
        ldb   #24                      ; arcade 0x61EB : ADD [SI+4],0x40
!       clra
        addb  ,x
        addd  glb_camera_x_pos
        std   x_pos,u
        std   bm.startX,u
        lda   #2
        sta   anim_frame_duration,u    ; la vitesse du script (v1)
        ; le maitre ne dessine rien
        clr   priority,u
        ; l'etat de chaine a zero — l'instance a pu servir a une chaine
        ; precedente, records et slots compris
        clr   bm.state,u
        ldd   #0
        std   bm.clock,u
        ldd   #$7FFF
        std   bm.endF,u
        ldx   bm.instp,u
        ldb   I.nrec,x
        ldx   I.recs,x
@clr    clr   bm.RS,x
        leax  bm.RECSZ,x
        decb
        bne   @clr
        ldx   bm.instp,u
        ldb   I.nrec,x
        ldx   I.slots,x
@cls    clr   ,x
        leax  bm.SLOTSZ,x
        decb
        bne   @cls
        ; le renderer groupe de CETTE instance
        jsr   LoadObject_x
        beq   >
        lda   #ObjID_bugrender
        sta   id,x
        ldd   bm.instp,u
        std   rr.instp,x
!       lda   #6
        sta   routine,u
        ; le retard de la wave : derouler l'interprete d'autant, chaque trame
        ; rattrapee pousse SON entree d'anneau (le geste du maitre outslay)
        ldb   #0
@late   equ   *-1
        beq   @done
        ldd   #bugmgr.Push
        std   moveByScript.callback
        ldb   @late
        jsr   moveByScript.runByB
@done   rts

; X = un bloc d'instance. Z = 1 s'il est libre. La propriete se VALIDE :
; libre si le proprietaire n'existe plus, n'est plus un maitre de bug, ou ne
; pointe plus sur ce bloc — l'idiome du rebound laser, aucun release requis.
bugmgr.InstFree
        ldy   I.owner,x
        beq   @free                    ; jamais pris
        pshs  u
        cmpy  ,s++
        beq   @free                    ; le proprietaire, c'est moi
        lda   id,y
        cmpa  id,u                     ; encore un maitre de bug ? (id du
        bne   @free                    ; stage courant, quel qu'il soit)
        lda   routine,y
        cmpa  #5
        blo   @free
        cmpa  #6
        bhi   @free
        ldd   bm.instp,y
        pshs  x
        cmpd  ,s++
        bne   @free                    ; il vit sur l'AUTRE instance
        andcc #$FB                     ; Z = 0 : occupee
        rts
@free   orcc  #$04
        rts

; Le callback : une fois par TRAME VIDEO, position a jour, U = le maitre,
; page de l'unite remontee par moveByScript avant l'appel.
bugmgr.Push
        ldx   bm.instp,u
        ldd   bm.clock,u
        anda  I.mask,x                 ; index & taille d'anneau
        aslb                           ; * 4 : l'entree entrelacee
        rola
        aslb
        rola
        addd  I.ring,x
        tfr   d,x
        lda   x_pos,u
        sta   ,x                       ; x playfield, octet haut
        lda   x_pos+1,u
        sta   1,x                      ; x playfield, octet bas
        lda   y_pos+1,u
        sta   2,x                      ; y
        lda   anim_frame,u
        sta   3,x                      ; pose
        ldd   bm.clock,u
        addd  #1
        std   bm.clock,u
        lda   moveByScript.anim.end    ; fin de script : sortir de la boucle
        beq   >
        clr   moveByScript.anim.loops
!       rts

;*******************************************************************************
; LE TOUR DE BOUCLE — horloge, naissances, marche des records
;*******************************************************************************
bugmgr.Live
        ; --- 1) l'horloge : par les poussees pendant le script, par la boucle
        ; pendant le drain (voir le maitre outslay) ---------------------------
        lda   bm.state,u
        beq   @interp
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        addd  bm.clock,u
        std   bm.clock,u
        bra   @spawn
@interp
        ldd   #bugmgr.Push
        std   moveByScript.callback
        jsr   moveByScript.runByFrameDrop
        lda   moveByScript.anim.end
        beq   @spawn
        inc   bm.state,u               ; script fini : le drain commence
        ldd   bm.clock,u
        std   bm.endF,u
@spawn
        ; --- 2) les naissances : bug k nait a horloge = 16k + 1 -------------
@sloop  lda   bm.spawned,u
        cmpa  bm.nb,u
        bhs   @walk
        ldb   #16
        mul
        addd  #1                       ; naissance STRICTE (lecon outslay : a
        pshs  d                        ; l'egalite la lecture vaudrait -1)
        ldd   bm.clock,u
        cmpd  ,s++
        blt   @walk                    ; pas encore l'heure
        ; le point de spawn est-il encore a l'ecran ? (v1 : 0x6204, x=336-320)
        ldd   bm.startX,u
        subd  glb_camera_x_pos
        subd  #8+6
        bpl   @sok
        lda   bm.nb,u                  ; sorti a gauche : plus personne ne nait
        sta   bm.spawned,u
        bra   @walk
@sok    bsr   bugmgr.Activate
        inc   bm.spawned,u
        bra   @sloop
@walk
        clr   bugmgr.wAlive
        clr   bugmgr.wN
        lbra  bugmgr.wLoop

; --- la fin de vie du maitre (retour de la marche) ---------------------------
bugmgr.End
        lda   bm.state,u
        beq   @ret
        lda   bm.spawned,u
        cmpa  bm.nb,u
        blo   @ret
        lda   bugmgr.wAlive
        bne   @ret
        ldx   bm.instp,u               ; rendre l'instance (hygiene : la
        ldd   #0                       ; validation suffirait, mais autant
        std   I.owner,x                ; que le pool se lise a l'oeil)
        lda   #7
        sta   routine,u
        jmp   UnloadObject_u           ; jamais dessine : pas de DeleteObject
@ret    rts

bugmgr.Deleted
        rts

; -----------------------------------------------------------------------------
; L'ACTIVATION du record (bm.spawned mod nrec) : boite residente nettoyee et
; inseree, preset de tir charge (PSR, l'OST du maitre sert de tampon), retard
; fige. Un record encore occupe = bug saute, cadence intacte (alloc KO v1).
; -----------------------------------------------------------------------------
bugmgr.Activate
        ldx   bm.instp,u
        lda   bm.spawned,u
@mod    cmpa  I.nrec,x
        blo   >
        suba  I.nrec,x
        bra   @mod
!       sta   bugmgr.wN
        ldb   #bm.RECSZ
        mul
        addd  I.recs,x
        tfr   d,y
        lda   bm.RS,y
        lbne  @skip                    ; encore occupe : on saute ce bug
        ; le retard : 16 * spawned
        lda   bm.spawned,u
        ldb   #16
        mul
        std   bm.RDelay,y
        ; la boite residente : nettoyee ENTIEREMENT d'abord (prev/next
        ; residuels — reserved-ram-is-not-zeroed, la lecon des boites outslay)
        pshs  y
        jsr   bugmgr.WBoxPtr           ; X = la boite de wN
        ldb   #sizeof{AABB}
!       clr   ,x+
        decb
        bne   <
        leax  -sizeof{AABB},x
        lda   #bug_hitdamage
        sta   AABB.p,x
        lda   #bug_hitbox_x
        sta   AABB.rx,x
        lda   #bug_hitbox_y
        sta   AABB.ry,x
        pshs  u
        ldy   #AABB_list_ennemy
        jsr   Collision_AddAABB
        puls  u
        ; le preset de tir : B = Preset19260[offset + cycle], charge dans les
        ; champs de l'OST du maitre (tampon), copie dans le record
        ldb   bm.presetOff,u
        addb  bm.preset,u
        ldy   #Preset19260
        ldb   b,y
        tfr   u,x                      ; X = le tampon du chargeur
        _loadFirePresetBug
        puls  y                        ; le record
        lda   fireVelocityPreset,u
        sta   bm.RVel,y
        lda   fireThreshold,u
        sta   bm.RThr,y
        ldd   fireReset,u
        std   bm.RRst,y
        ldd   fireCounter,u
        std   bm.RCnt,y
        ; le cycle v1 : preset++ mod 5
        lda   bm.preset,u
        inca
        cmpa  #5
        bne   >
        clra
!       sta   bm.preset,u
        lda   #1
        sta   bm.RS,y
@skip   rts

; -----------------------------------------------------------------------------
; LA MARCHE : un record = position depuis l'anneau, coupures, boite, tir,
; publication. Les pointeurs se recalculent depuis wN — les aides clobbent.
; -----------------------------------------------------------------------------
bugmgr.wLoop
        ldb   bugmgr.wN
        lda   #bm.RECSZ
        mul
        ldx   bm.instp,u
        addd  I.recs,x
        tfr   d,y
        lda   bm.RS,y
        lbeq  bugmgr.wNext
        ; -- le drain : mon tour est-il passe ? ------------------------------
        lda   bm.state,u
        beq   @pos
        ldd   bm.clock,u
        subd  bm.RDelay,y
        cmpd  bm.endF,u
        lbge  bugmgr.DieSilent
@pos
        ; -- la position : l'anneau a (horloge - 1 - retard) -----------------
        ldd   bm.clock,u
        subd  #1
        subd  bm.RDelay,y
        anda  I.mask,x                 ; X porte encore l'instance
        aslb
        rola
        aslb
        rola
        addd  I.ring,x
        tfr   d,x
        lda   ,x
        sta   bugmgr.wXH
        lda   1,x
        sta   bugmgr.wXL
        lda   2,x
        sta   bugmgr.wY
        lda   3,x
        sta   bugmgr.wPose
        ; -- la coupure gauche (v1 : x + 8 sous la camera -> mort muette) ----
        ldd   bugmgr.wXH
        addd  #8
        cmpd  glb_camera_x_pos
        lbls  bugmgr.DieSilent
        ; -- la boite : touchee ? puis position ------------------------------
        jsr   bugmgr.WBoxPtr           ; X = la boite
        lda   AABB.p,x
        lbeq  bugmgr.Explode
        ldd   bugmgr.wXH
        subd  glb_camera_x_pos
        stb   AABB.cx,x
        lda   bugmgr.wY
        sta   AABB.cy,x
        ; -- le tir, compteur v1 reproduit a l'identique ---------------------
        lda   bm.RVel,y
        lbeq  @pub
        lda   #3
        sta   fireDisplayDelay,u
        ldx   #player1
        stx   FoeFireTarget
        lda   bm.RThr,y
        sta   @thr
        ldd   bm.RCnt,y
        ldx   gfxlock.frameDrop.count_w
!       addd  #1
        cmpd  #0
@thr    equ   *-1
        beq   @fire
        cmpd  bm.RRst,y
        bhs   @f0
        leax  -1,x
        bne   <
        std   bm.RCnt,y
        bra   @pub
@f0     ldd   #0
@fire   std   bm.RCnt,y
        ; poker la position du record dans le maitre, tirer, restaurer
        ldd   x_pos,u
        pshs  d
        ldd   y_pos,u
        pshs  d
        ldd   bugmgr.wXH
        std   x_pos,u
        clra
        ldb   bugmgr.wY
        std   y_pos,u
        lda   bm.RVel,y
        sta   fireVelocityPreset,u
        pshs  u,y
        lda   Obj_Index_Page+ObjID_createFoeFire
        sta   PSR_Page
        ldd   Obj_Index_Address+2*ObjID_createFoeFire
        std   PSR_Address
        jsr   RunPgSubRoutine
        puls  u,y
        puls  d
        std   y_pos,u
        puls  d
        std   x_pos,u
@pub
        ; -- la publication : coordonnees ecran, set par la pose -------------
        inc   bugmgr.wAlive
        ldd   bugmgr.wXH
        subd  glb_camera_x_pos
        addd  #screen_left
        tsta                           ; hors du cadre en octet : cache
        bne   @hide
        stb   bugmgr.wSx
        ; le slot D'ABORD : WSlotPtr recharge X avec le bloc d'instance
        ; (« les aides clobbent ») — pris en defaut le 22/08 : le set charge
        ; avant l'appel partait ecrase, RecPublish publiait InstS+14 comme
        ; routine et BuildSprites sautait dedans (gel du stage 4, t=1600)
        jsr   bugmgr.WSlotPtr          ; Y = le slot
        ldb   bugmgr.wPose
        andb  #$0F
        aslb
        ldx   #ImageIndex
        abx
        ldx   ,x                       ; le set de la direction
        lda   bugmgr.wSx
        ldb   bugmgr.wY
        addb  #screen_top
        jsr   bugmgr.RecPublish
        bra   bugmgr.wNext
@hide   jsr   bugmgr.WSlotPtr
        clr   ,y
bugmgr.wNext
        inc   bugmgr.wN
        ldx   bm.instp,u
        lda   bugmgr.wN
        cmpa  I.nrec,x
        lblo  bugmgr.wLoop
        lbra  bugmgr.End

; -- la mort par tir : score + explosion smallx2 (v1 @destroy, sans bruitage) -
bugmgr.Explode
        ldb   #bug_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        beq   bugmgr.DieSilent
        _ldd  ObjID_explosion,explosion.subtype.smallx2+explosion.sfx.small
        std   id,x
        ldd   bugmgr.wXH               ; le record vit en playfield : direct
        std   x_pos,x
        clra
        ldb   bugmgr.wY
        std   y_pos,x
        ; -- l'extinction : boite retiree, slot eteint, record libre ---------
bugmgr.DieSilent
        ldx   #AABB_list_ennemy
        stx   Collision_Remove_1
        stx   Collision_Remove_3
        leax  2,x
        stx   Collision_Remove_2
        jsr   bugmgr.WBoxPtr
        pshs  u
        jsr   Collision_RemoveAABB
        puls  u
        jsr   bugmgr.WSlotPtr
        clr   ,y
        ldb   bugmgr.wN
        lda   #bm.RECSZ
        mul
        ldx   bm.instp,u
        addd  I.recs,x
        tfr   d,y
        clr   bm.RS,y
        lbra  bugmgr.wNext

; les variables de marche, sur la page (ecrites page montee par RunObjects)
bugmgr.wN      fcb 0
bugmgr.wAlive  fcb 0
bugmgr.wXH     fcb 0
bugmgr.wXL     fcb 0
bugmgr.wY      fcb 0
bugmgr.wPose   fcb 0
bugmgr.wSx     fcb 0
bugmgr.di      fcb 0
bugmgr.dBase   fdb 0

; X = la boite RESIDENTE du record wN (l'instance donne la rangee)
bugmgr.WBoxPtr
        lda   bugmgr.wN
        ldb   #sizeof{AABB}
        mul
        ldx   bm.instp,u
        addd  I.boxes,x
        tfr   d,x
        rts

; Y = le slot du record wN
; X PRESERVE — l'outslay d'origine lit sa base de slots en immediat (mono-
; instance) et ne touche pas X ; ici elle vient du bloc d'instance, et le
; site de publication tient DEJA l'entree d'imageset dans X quand il appelle
; (RecPublish la consomme : geometrie + routine compilee). Sans le pshs, le
; slot recevait +14/15 du bloc d'instance comme routine de dessin — jsr en
; plein milieu d'une instruction de LiveCreator, PSR_Page pourri, montage
; d'une page fantome (gel du stage 7 au premier rendu de chaine, 22/08/2026).
bugmgr.WSlotPtr
        pshs  x
        lda   bugmgr.wN
        ldb   #bm.SLOTSZ
        mul
        ldx   bm.instp,u
        addd  I.slots,x
        tfr   d,y
        puls  x,pc

; -----------------------------------------------------------------------------
; Publier un record — le clone du RecPublish outslay : cull « entierement
; dans le cadre » en octets, geometrie lue dans l'imageset.
;   +4 x_size  +5 y_size  +6 center_offset  +11 x1  +12 y1  +14,15 routine
; entree : A = x ecran, B = y ecran, X = set, Y = slot
; -----------------------------------------------------------------------------
bugmgr.RecPublish
        pshs  a,b
        _sprite.cull bugmgr.RecPublish.off              ; le containment, comme le moteur
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
bugmgr.RecPublish.off
        clr   ,y
        puls  a,b,pc

;*******************************************************************************
; LE RENDERER GROUPE — un par instance (le maitre lui seme son bloc). Faux
; imageset choisi par l'instance : chaque DrawAll connait SES slots, parce
; que BuildSprites appelle la routine sans OST sous la main.
;*******************************************************************************

bugmgr.FakeImgL
        fcb   bugmgr.FakeSubL-bugmgr.FakeImgL,bugmgr.FakeSubL-bugmgr.FakeImgL
        fcb   bugmgr.FakeSubL-bugmgr.FakeImgL,bugmgr.FakeSubL-bugmgr.FakeImgL
        fcb   8,8,0
bugmgr.FakeSubL
        fcb   0
        fcb   bugmgr.FakeMfL-bugmgr.FakeSubL
        fcb   0
        fcb   bugmgr.FakeMfL-bugmgr.FakeSubL
        fcb   0,0
bugmgr.FakeMfL
        fcb   0                        ; page, patchee a l'Init du renderer
        fdb   bugmgr.DrawAllL

bugmgr.FakeImgS
        fcb   bugmgr.FakeSubS-bugmgr.FakeImgS,bugmgr.FakeSubS-bugmgr.FakeImgS
        fcb   bugmgr.FakeSubS-bugmgr.FakeImgS,bugmgr.FakeSubS-bugmgr.FakeImgS
        fcb   8,8,0
bugmgr.FakeSubS
        fcb   0
        fcb   bugmgr.FakeMfS-bugmgr.FakeSubS
        fcb   0
        fcb   bugmgr.FakeMfS-bugmgr.FakeSubS
        fcb   0,0
bugmgr.FakeMfS
        fcb   0                        ; page, patchee a l'Init du renderer
        fdb   bugmgr.DrawAllS

bug.Render
        lda   routine,u
        bne   bugmgr.RenderLive
        _GetCartPageA
        ldb   id,u
        ldx   #Img_Page_Index
        sta   b,x                      ; le moteur montera NOTRE page
        sta   bugmgr.FakeMfL           ; les deux faux sets vivent ici : les
        sta   bugmgr.FakeMfS           ; patcher tous les deux ne coute rien
        ldx   rr.instp,u
        ldd   #bugmgr.FakeImgL
        cmpx  #bugmgr.InstL
        beq   >
        ldd   #bugmgr.FakeImgS
!       std   image_set,u
        clr   render_flags,u           ; coordonnees ecran, boite parquee au
        lda   #120                     ; centre : jamais eliminee hors-champ
        sta   x_pixel,u
        lda   #135
        sta   y_pixel,u
        ldb   #6                       ; la priorite v1 du bug
        stb   priority,u
        inc   routine,u
        jmp   DisplaySprite
bugmgr.RenderLive
        bsr   bugmgr.SlotsLive
        bne   @seen
        lda   routine,u
        cmpa  #2
        bne   >
        jmp   DeleteObject
!       jmp   DisplaySprite
@seen   lda   #2
        sta   routine,u
        jmp   DisplaySprite

; Z = 0 s'il reste au moins un slot allume sur MON instance.
bugmgr.SlotsLive
        ldy   rr.instp,u
        ldb   I.nrec,y
        ldx   I.slots,y
@l      lda   ,x
        bne   @yes
        leax  bm.SLOTSZ,x
        decb
        bne   @l
        clra
@yes    rts

; Le dessin : par slot allume, l'adresse ecran puis la routine compilee.
; A rebours — le plus ancien recouvre, l'ordre v1 (celui du spawn).
bugmgr.DrawAllL
        ldx   #bugmgr.InstL
        bra   bugmgr.DrawCommon
bugmgr.DrawAllS
        ldx   #bugmgr.InstS
bugmgr.DrawCommon
        lda   I.nrec,x
        sta   bugmgr.di
        ldd   I.slots,x
        std   bugmgr.dBase
@loop   dec   bugmgr.di
        lda   bugmgr.di
        ldb   #bm.SLOTSZ
        mul
        addd  bugmgr.dBase
        tfr   d,x
        lda   ,x
        beq   @next
        ldd   1,x                      ; A = x_pixel, B = y_pixel (cadre DRS)
        pshs  x
        jsr   DRS_XYToAddress
        puls  x
        ldx   3,x
        ldu   <glb_screen_location_2
        jsr   ,x                       ; la routine consomme U
@next   tst   bugmgr.di
        bne   @loop
        rts

;*******************************************************************************
; LES DONNEES DE PAGE — anneaux entrelaces (zeros, zx0 les efface du disque),
; records, slots, et les deux blocs d'instance. Les boites sont RESIDENTES
; (res.unit.asm : bug.boxesL / bug.boxesS, membres des arenes stageN.res).
;*******************************************************************************
bug.ringL       fill  0,1024*4         ; (xH, xL, y, pose) entrelaces
bug.ringS       fill  0,256*4
bug.recsL       fill  0,bugL.NREC*bm.RECSZ
bug.recsS       fill  0,bugS.NREC*bm.RECSZ
bug.slotsL      fill  0,bugL.NREC*bm.SLOTSZ
bug.slotsS      fill  0,bugS.NREC*bm.SLOTSZ

bugmgr.InstL
        fdb   0                        ; owner
        fdb   bug.ringL
        fcb   $03                      ; masque haut : index & $3FF
        fcb   bugL.NREC
        fdb   bug.recsL
        fdb   bug.slotsL
        fdb   bug.boxesL
bugmgr.InstS
        fdb   0                        ; owner
        fdb   bug.ringS
        fcb   $00                      ; masque haut : index & $FF
        fcb   bugS.NREC
        fdb   bug.recsS
        fdb   bug.slotsS
        fdb   bug.boxesS
