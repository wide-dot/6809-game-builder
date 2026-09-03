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
old_xpos1         equ ext_variables+9  ; word
old_ypos1         equ ext_variables+11 ; word
old_xpos2         equ ext_variables+13 ; word
old_ypos2         equ ext_variables+15 ; word
offsety           equ ext_variables+17 ; word

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
        ldx   #25
        stx   offsety,u
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
; state, orbit side (offsety + anim from the bit index), tracking history (from
; the player) and tick accumulator, then fall straight into ActiveTick. The slot
; is NOT registered in AABB_list_friend (it does its own gated tick collision).
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

        ; Orbit side: TOP above the ship (offsety +25, Ani_bitdevice1), BOTTOM
        ; below it (offsety -25, Ani_bitdevice2).
        ;
        ; Le cote se lit sur L'ADRESSE DU SLOT, pas sur le compte (25/08/2026).
        ; Il se lisait sur globals.bitdevice, qui vaut 1 quand Collect vient
        ; d'armer le slot du haut et 2 pour celui du bas — juste tant que les
        ; deux naissent l'un apres l'autre. La restauration d'armement en
        ; entree de stage les arme TOUS LES DEUX d'un coup, le compte valant
        ; deja 2 : les deux slots seraient partis en bas, superposes. Le slot
        ; EST le cote, il n'y a pas de raison de le deduire d'ailleurs.
        ldx   #25
        ldy   #Ani_bitdevice1
        cmpu  #bitdevTopOST
        beq   >
        ldx   #-25
        ldy   #Ani_bitdevice2
!       stx   offsety,u
        sty   anim,u

        ; seed delayed tracking history from the player's current position
        ldd   player1+x_pos
        std   old_xpos1,u
        std   old_xpos2,u
        std   x_pos,u                  ; amorcer le labour des gommes : le tick
                                       ; lit l'ancien x_pos comme depart, sans
                                       ; ca le premier balayage partirait de 0
        ldd   player1+y_pos
        std   old_ypos1,u
        std   old_ypos2,u

        lda   #bitdev.rtnid.ActiveTick
        sta   routine,u
        ; fall through into ActiveTick for the first frame

; ---------------------------------------------------------------------------
; ActiveTick : per-frame active bit device. Orbit/track the player (the original
; in-place Live logic) and position AABB_0 for this frame. Enemy contact is NOT
; applied here: the force pod and BOTH bit devices share one global, frame-drop-
; gated pass (WeaponContactTick, collision phase in main.asm) that hits each
; overlapping enemy for 1 every 16 frames -- the arcade [0x2eb6]&0x0F gate. The
; slot is never in any friend list and is never consumed.
;   [u] = static slot OST
; ---------------------------------------------------------------------------
ActiveTick
        ldy   x_pos,u                  ; la position de la trame d'avant, pour
                                       ; BitGumSweep (Y traverse le tick intact)
        ldd   glb_camera_x_pos
        subd  glb_camera_x_pos_old
        addd  old_xpos1,u
        std   old_xpos1,u

        ldd   glb_camera_x_pos
        subd  glb_camera_x_pos_old
        addd  old_xpos2,u
        std   x_pos,u

        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u
        ldd   old_ypos2,u
        subd  offsety,u
        std   y_pos,u
        stb   AABB_0+AABB.cy,u

        ldd   old_xpos1,u
        std   old_xpos2,u
        ldd   old_ypos1,u
        std   old_ypos2,u

        ldd   player1+x_pos
        std   old_xpos1,u
        ldd   player1+y_pos
        std   old_ypos1,u

        ; position the hitbox radius. ARCADE : demi-largeurs 12/12 px arcade
        ; (0x17EE), soit 4,5/9 des notres — la boite v1 (3,6) etait celle du
        ; bonus, moitie moins large (doc/analyse-bit-device.md, 03/09/2026).
        _ldd  4,9
        std   AABB_0+AABB.rx,u

        ; enemy contact is applied by the shared, frame-drop-gated WeaponContactTick
        ; (collision phase, main.asm). Arcade: the force pod and BOTH bit devices
        ; share ONE global 1/16-frame gate ([0x2eb6]&0x0F), 1 dmg per enemy/window.
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
; Le depart n'a pas de variable a lui (ext_variables est plein) : c'est le
; x_pos que le tick a lu dans Y AVANT de l'ecraser, ActiveInit l'amorce.
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

