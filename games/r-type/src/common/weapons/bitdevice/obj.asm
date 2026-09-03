; ---------------------------------------------------------------------------
; Object
;
; input REG : [u] pointer to Object Status Table (OST)
; ---------
;
; ---------------------------------------------------------------------------

; V2-DEVIATION: les en-tetes communs sont portes par l'unite hote
; (bitdevice.unit.asm), comme pour tout fichier v1 enveloppe.
; Includes v1 retires :
; INCLUDE "./engine/macros.asm"
; INCLUDE "./engine/collision/macros.asm"
; INCLUDE "./engine/collision/struct_AABB.equ"
; INCLUDE "./objects/player1/player1.equ"
; INCLUDE "./objects/player1/bitdevice/bitdevice.equ" ; bitdev.rtnid.* (static-slot seeding)
AABB_0            equ ext_variables    ; AABB struct (9 bytes)
; L'etat de poursuite du bit actif ne vit PAS dans ext_variables : il y a
; deux instances au plus, chacune a son bloc bit.state[subtype] en variables
; d'unite (decision auteur, 03/09/2026). ActiveInit l'efface.

Object
        lda   routine,u
        asla
        ldx   #Routines
        jmp   [a,x]

Routines
        fdb   InitOptionBox            ; 0 floating pickup
        fdb   LiveOptionBox            ; 1 floating pickup
        fdb   AlreadyDeletedOptionBox  ; 2 floating pickup
        fdb   Dormant                  ; 3 (legacy slot; unreachable, parked at Dormant)
        fdb   ActiveInit               ; 4 static slot: seed orbit + fall into tick
        fdb   ActiveTick               ; 5 static slot: orbit + AABB_0 + gated tick dmg
        fdb   Dormant                  ; 6 static slot: idle until activated / when lost

; Dormant : a static slot (bitdevTopOST/bitdevBotOST) idles here, drawing nothing
; and doing nothing, until the player collects a bit-device pickup (LiveOptionBox
; below activates a free slot by writing bitdev.rtnid.ActiveInit to slot+routine).
; A bit returns here (instead of DeleteObject) when it is lost/unloaded.
Dormant
        rts

InitOptionBox
        ldb   #2
        stb   priority,u
        lda   render_flags,u
        ora   #render_playfieldcoord_mask
        sta   render_flags,u
        ldx   #Ani_bitdevice1
        stx   anim,u
        inc   routine,u                 ; Set routine to LiveOptionBox

        _Collision_AddAABB AABB_0,AABB_list_bonus        
        lda   #127                        ; set damage potential for this hitbox
        sta   AABB_0+AABB.p,u
        _ldd  3,6                       ; set hitbox xy radius
        std   AABB_0+AABB.rx,u
        ldb   y_pos+1,u
        stb   AABB_0+AABB.cy,u
LiveOptionBox
        ldd   x_pos,u
        cmpd  glb_camera_x_pos
        ble   @delete
        lda   globals.bitdevice
        cmpa  #2
        blo   @canCollect              ; ignore contact if player1 already has the 2 bit devices
        lda   #127                     ; ... mais REARMER la boite : la passe de collision la
        sta   AABB_0+AABB.p,u          ;   met a 0 au premier contact, et le pickup restait
        bra   >                        ;   affiche et definitivement incollectable (p=0 =
@canCollect                            ;   boite desactivee, jamais reevaluee) meme si un bit
        lda   AABB_0+AABB.p,u          ;   etait perdu ensuite.
        beq   Collect                  ; was touched -> activate a static slot
!
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u
        jsr   AnimateSpriteSync
        jmp   DisplaySprite
@delete
        _Collision_RemoveAABB AABB_0,AABB_list_bonus
        inc   routine,u
        jmp   DeleteObject
AlreadyDeletedOptionBox
        rts

; ---------------------------------------------------------------------------
; Collect : the floating pickup was touched. Activate a free static bit-device
; slot (bitdevTopOST first, then bitdevBotOST), then delete the pickup. The bit
; count globals.bitdevice picks the slot: 0 -> TOP, 1 -> BOTTOM. The slot is
; activated by writing bitdev.rtnid.ActiveInit to slot+routine; ActiveInit seeds
; its orbit side/anim from globals.bitdevice and falls into ActiveTick.
;   [u] = floating pickup OST (deleted here)
; ---------------------------------------------------------------------------
Collect
        ldx   #bitdevTopOST            ; bit 0 (count 0) -> top slot
        lda   globals.bitdevice
        beq   >
        ldx   #bitdevBotOST            ; bit 1 (count 1) -> bottom slot
!
        lda   #bitdev.rtnid.ActiveInit
        sta   routine,x                ; activate the static slot (ActiveInit next frame)
        inc   globals.bitdevice        ; one more active bit device

        ; delete the floating pickup (transient): drop its bonus hitbox and free it
        _Collision_RemoveAABB AABB_0,AABB_list_bonus
        lda   #AlreadyDeletedRtn
        sta   routine,u
        jmp   DeleteObject

AlreadyDeletedRtn equ bitdev.rtnid.AlreadyDeleted

; ---------------------------------------------------------------------------
; ActiveInit : a static slot has just been activated by Collect. Seed its render
; state, orbit side (subtype + anim from the slot address), the pursuit state
; block bit.state[subtype] and the resting position, then fall straight into
; ActiveTick. The slot is NOT registered in AABB_list_friend (contact damage
; is applied by the shared WeaponContactTick pass).
;   [u] = static slot OST (bitdevTopOST / bitdevBotOST)
; ---------------------------------------------------------------------------
ActiveInit
        ; clean OST : slot statique re-active -> on repart d'un slot FRAIS. efface tout
        ; l'etat d'affichage reserve stale (mapping_frame, listes priorite par-buffer,
        ; bgdata...) qui bloquait le rendu a la re-acquisition. On re-pose l'id (lu par
        ; CheckSpritesRefresh) ; la routine est reposee plus bas par sta routine,u. (idem
        ; fix force pod Init).
        tfr   u,x
        clra
        ldb   #object_size
@clrOST sta   ,x+
        decb
        bne   @clrOST
        lda   #ObjID_bitdevice
        sta   id,u

        ldb   #2
        stb   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u

        ; Orbit side: TOP above the ship (repos y-24, Ani_bitdevice1), BOTTOM
        ; below it (repos y+24, Ani_bitdevice2). subtype = 0 haut / 1 bas,
        ; c'est l'index du bloc d'etat bit.state.
        ;
        ; Le cote se lit sur L'ADRESSE DU SLOT, pas sur le compte (25/08/2026).
        ; Il se lisait sur globals.bitdevice, qui vaut 1 quand Collect vient
        ; d'armer le slot du haut et 2 pour celui du bas — juste tant que les
        ; deux naissent l'un apres l'autre. La restauration d'armement en
        ; entree de stage les arme TOUS LES DEUX d'un coup, le compte valant
        ; deja 2 : les deux slots seraient partis en bas, superposes. Le slot
        ; EST le cote, il n'y a pas de raison de le deduire d'ailleurs.
        clra
        ldy   #Ani_bitdevice1
        cmpu  #bitdevTopOST
        beq   >
        inca
        ldy   #Ani_bitdevice2
!       sta   subtype,u
        sty   anim,u

        ; Le bit nait SUR sa position de repos, etat de poursuite a zero
        ; (balancier, spin, fenetre, direction), cible = la position de repos.
        ; x_pos amorce aussi le labour des gommes : le tick lit l'ancien x_pos
        ; comme depart, sans ca le premier balayage partirait de 0.
        ldb   #bit.SSIZE
        mul                            ; D = subtype * SSIZE (A = 0 ou 1)
        ldx   #bit.state
        leax  d,x
        ldb   #bit.SSIZE
@clrst  clr   ,x+
        decb
        bne   @clrst
        leax  -bit.SSIZE,x
        ldd   player1+x_pos
        std   x_pos,u
        std   bs.tx,x
        ldb   subtype,u
        lslb
        ldy   #bit.rest
        ldd   b,y                      ; le repos d'abord : ldd player1+y_pos
        addd  player1+y_pos            ; ecraserait l'index B (piege ldd)
        std   y_pos,u
        std   bs.ty,x
        clr   x_sub,u
        clr   y_sub,u

        lda   #bitdev.rtnid.ActiveTick
        sta   routine,u
        ; fall through into ActiveTick for the first frame

; ---------------------------------------------------------------------------
; ActiveTick : per-frame active bit device. Poursuite ARCADE (run_bit_devices,
; doc/analyse-bit-device.md §1.2), puis AABB_0 pour cette trame. Enemy contact
; is NOT applied here: the force pod and BOTH bit devices share one global,
; frame-drop-gated pass (WeaponContactTick, collision phase in main.asm) that
; hits each overlapping enemy for 1 every 16 frames -- the arcade [0x2eb6]&0x0F
; gate. The slot is never in any friend list and is never consumed.
;
; LE MODELE ARCADE, par trame :
;  1. balancier : +5 la trame ou la direction tenue CHANGE vers une direction
;     non nulle (plafond $E0), -1 par trame, plancher 0 ;
;  2. fenetre de 8 trames : au bout, si 7 trames ou plus se sont passees sans
;     changement, le balancier retombe a 0 ; sans changement, spin++ ;
;  3. cible = vaisseau + repos (y -+ 24) + un decalage A L'OPPOSE de la
;     direction tenue (le bit TRAINE derriere), amplitude par palier du
;     balancier (swing>>6 : 6/12/18/24 px en X, 10/22/34/46 en Y) ;
;  4. la cible poursuivie est celle de la trame D'AVANT (l'anneau arcade a un
;     retard d'une entree) ;
;  5. poursuite par axe a vitesse v (table par swing>>3 quand une direction
;     est tenue, sinon l'entree 0) : au-dela de pos+int(v) le bit avance de v,
;     en deca de pos-int(v) il recule, entre les deux il ne bouge pas.
; Px arcade -> notres : X x0.375, Y x0.75 ; une trame arcade = une trame
; compensee : la boucle rejoue le modele frameDrop fois avec la direction et
; la position courantes du vaisseau (le tick tourne apres player1).
;   [u] = static slot OST
; ---------------------------------------------------------------------------
ActiveTick
        ldd   x_pos,u
        std   bit.prevx                ; la position de la trame d'avant, pour
                                       ; BitGumSweep
        lda   subtype,u
        ldb   #bit.SSIZE
        mul
        ldx   #bit.state
        leax  d,x                      ; X = l'etat de CETTE instance
        ldb   gfxlock.frameDrop.count
        bne   >
        ldb   #1
!       stb   bit.loop
@frame
        ; --- 1. la direction tenue et son changement ---
        lda   joypad.held.dpad
        anda  #joypad.0.DPAD
        sta   bit.dir
        clr   bit.change
        cmpa  bs.lastdir,x
        beq   @swing
        sta   bs.lastdir,x
        tsta
        beq   @swing                   ; retour au neutre : pas un changement
        inc   bit.change
        ldb   bs.swing,x
        cmpb  #$E0
        bhs   @swing
        addb  #5
        stb   bs.swing,x
@swing  ldb   bs.swing,x
        beq   >
        dec   bs.swing,x
!
        ; --- 2. la fenetre de 8 trames et le spin ---
        inc   bs.win,x
        lda   bs.win,x
        cmpa  #8
        blo   @spin
        clr   bs.win,x
        lda   bs.spin,x
        cmpa  #7
        blo   >
        clr   bs.swing,x               ; 7 trames sans changement : le
!       clr   bs.spin,x                ; balancier retombe
@spin   tst   bit.change
        bne   @target
        inc   bs.spin,x
@target
        ; --- 3. la cible : vaisseau + repos + decalage oppose a la direction ---
        lda   bs.swing,x
        lsra
        lsra
        lsra
        lsra
        lsra
        lsra                           ; palier 0..3
        sta   bit.bucket
        ldy   #bit.ampx
        ldb   a,y
        clra
        std   bit.off                  ; +amp
        lda   bit.dir
        bita  #joypad.0.LEFT           ; gauche tenue : le bit traine a DROITE
        bne   @xoff
        bita  #joypad.0.RIGHT          ; droite tenue : a GAUCHE
        beq   @xzero
        ldd   #0
        subd  bit.off
        std   bit.off
        bra   @xoff
@xzero  ldd   #0
        std   bit.off
@xoff   ldd   player1+x_pos
        addd  bit.off
        ldy   bs.tx,x                  ; la cible de la trame d'avant...
        std   bs.tx,x
        sty   bit.tgtx                 ; ... est celle qu'on poursuit
        ldb   bit.bucket
        ldy   #bit.ampy
        ldb   b,y
        clra
        std   bit.off
        lda   bit.dir
        bita  #joypad.0.UP             ; haut tenu : le bit traine EN DESSOUS
        bne   @yoff
        bita  #joypad.0.DOWN           ; bas tenu : au-dessus
        beq   @yzero
        ldd   #0
        subd  bit.off
        std   bit.off
        bra   @yoff
@yzero  ldd   #0
        std   bit.off
@yoff   ldb   subtype,u
        lslb
        ldy   #bit.rest
        ldd   b,y                      ; le repos, -24 en haut, +24 en bas
        addd  player1+y_pos            ; (le repos d'abord : ldd ecraserait B)
        addd  bit.off
        ldy   bs.ty,x
        std   bs.ty,x
        sty   bit.tgty
        ; --- 4. la vitesse : table par swing>>3, entree 0 sans direction ---
        clra
        tst   bit.dir
        beq   >
        lda   bs.swing,x
        lsra
        lsra
        lsra
        anda  #$1F
!       lsla
        sta   bit.vidx
        ; --- 5. la poursuite, axe X ---
        ldb   bit.vidx
        ldy   #bit.velx
        ldd   b,y
        std   bit.vel                  ; v en 8.8, A = int(v)
        tfr   a,b
        clra
        std   bit.vint
        addd  x_pos,u
        cmpd  bit.tgtx
        blt   @xfwd                    ; cible au-dela de pos+int(v) : avance
        ldd   x_pos,u
        subd  bit.vint
        cmpd  bit.tgtx
        ble   @yaxis                   ; dans la bande morte : immobile
        ldd   x_pos+1,u                ; cible en deca de pos-int(v) : recule
        subd  bit.vel
        std   x_pos+1,u
        bcc   @yaxis
        dec   x_pos,u
        bra   @yaxis
@xfwd   ldd   x_pos+1,u
        addd  bit.vel
        std   x_pos+1,u
        bcc   @yaxis
        inc   x_pos,u
@yaxis
        ; --- 5. la poursuite, axe Y ---
        ldb   bit.vidx
        ldy   #bit.vely
        ldd   b,y
        std   bit.vel
        tfr   a,b
        clra
        std   bit.vint
        addd  y_pos,u
        cmpd  bit.tgty
        blt   @yfwd
        ldd   y_pos,u
        subd  bit.vint
        cmpd  bit.tgty
        ble   @next
        ldd   y_pos+1,u
        subd  bit.vel
        std   y_pos+1,u
        bcc   @next
        dec   y_pos,u
        bra   @next
@yfwd   ldd   y_pos+1,u
        addd  bit.vel
        std   y_pos+1,u
        bcc   @next
        inc   y_pos,u
@next   dec   bit.loop
        lbne  @frame

        ; --- la boite de cette trame ---
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u
        ldb   y_pos+1,u
        stb   AABB_0+AABB.cy,u

        ; position the hitbox radius. ARCADE : demi-largeurs 12/12 px arcade
        ; (0x17EE), soit 4,5/9 des notres — la boite v1 (3,6) etait celle du
        ; bonus, moitie moins large (doc/analyse-bit-device.md, 03/09/2026).
        _ldd  4,9
        std   AABB_0+AABB.rx,u

        ; enemy contact is applied by the shared, frame-drop-gated WeaponContactTick
        ; (collision phase, main.asm). Arcade: the force pod and BOTH bit devices
        ; share ONE global 1/16-frame gate ([0x2eb6]&0x0F), 1 dmg per enemy/window.
        ldy   bit.prevx
        bsr   BitGumSweep
        jsr   AnimateSpriteSync
        jmp   DisplaySprite

; ---------------------------------------------------------------------------
; BitGumSweep — le bit laboure les gommes du stage 4, comme le pod
; ---------------------------------------------------------------------------
; ARCADE : run_bit_devices appelle clear_green_ball_helper_stage4 a chaque
; trame (un amas 2x2 de cellules sous le bit, credit de bonus compris), pour
; chacun des deux bits (doc/analyse-bit-device.md §1.5). Idiome de
; ForcePodGumSweep : l'entree +6 du crochet efface le rectangle BALAYE entre
; la position de la trame d'avant et la courante — la compensation de trames
; est gratuite. Bloc 3x3 cellules ($33) pour les 24 px arcade du bit, la ou
; le pod prend $44 pour ses 32 ; coin haut-gauche = centre - (4, 9). Hors
; stage 4 le crochet est stage.gum.none : un jsr pour rien.
; Le depart est le x_pos que le tick a range dans bit.prevx AVANT de le
; faire bouger, ActiveInit l'amorce.
;   [u] = static slot OST, [y] = x_pos de la trame d'avant
; ---------------------------------------------------------------------------
BitGumSweep
        ldd   stage.gum.hook
        addd  #6                       ; +6 : effacer un rectangle balaye
        std   @call
        ldd   x_pos,u
        subd  #4                       ; le coin haut-gauche : une cellule et
        tfr   d,x                      ; demie a gauche du centre
        leay  -4,y
        ldb   y_pos+1,u
        subb  #9                       ; ... et une rangee et demie au-dessus
        bhs   >
        clrb                           ; le bit colle au haut du champ
!       lda   #$33                     ; bloc 3 x 3 cellules
        jsr   >0
@call   equ   *-2
        rts

; ---------------------------------------------------------------------------
; L'etat de poursuite, une instance par slot (subtype 0 haut / 1 bas)
; ---------------------------------------------------------------------------
bs.swing          equ 0                ; le balancier (0..$E4)
bs.spin           equ 1                ; trames sans changement dans la fenetre
bs.win            equ 2                ; la fenetre de 8 trames
bs.lastdir        equ 3                ; la direction tenue a la trame d'avant
bs.tx             equ 4                ; la cible de la trame d'avant, x
bs.ty             equ 6                ; ... et y
bit.SSIZE         equ 8
bit.state         fcb   0,0,0,0,0,0,0,0 ; haut
                  fcb   0,0,0,0,0,0,0,0 ; bas

; les brouillons du tick (une trame, une instance a la fois)
bit.prevx         fdb   0
bit.loop          fcb   0
bit.dir           fcb   0
bit.change        fcb   0
bit.bucket        fcb   0
bit.vidx          fcb   0
bit.off           fdb   0
bit.tgtx          fdb   0
bit.tgty          fdb   0
bit.vel           fdb   0
bit.vint          fdb   0

; le repos : au-dessus (haut) ou en dessous (bas) du vaisseau, 0x20 arcade
bit.rest          fdb   -24,24
; l'amplitude du decalage par palier du balancier (arcade 16/32/48/64 en X,
; 14/30/46/62 en Y)
bit.ampx          fcb   6,12,18,24
bit.ampy          fcb   10,22,34,46
; la vitesse de poursuite en 8.8, par swing>>3 (arcade 4..15 px/trame)
bit.velx
        fdb   $0180,$02A0,$02A0,$02A0,$02A0,$02A0,$02A0,$02A0
        fdb   $0300,$0300,$0300,$0300,$0300,$0300,$0360,$0360
        fdb   $03C0,$03C0,$0420,$0420,$0420,$0480,$0480,$04E0
        fdb   $0480,$04E0,$04E0,$0540,$0540,$05A0,$05A0,$05A0
bit.vely
        fdb   $0300,$0540,$0540,$0540,$0540,$0540,$0540,$0540
        fdb   $0600,$0600,$0600,$0600,$0600,$0600,$06C0,$06C0
        fdb   $0780,$0780,$0840,$0840,$0840,$0900,$0900,$09C0
        fdb   $0900,$09C0,$09C0,$0A80,$0A80,$0B40,$0B40,$0B40

