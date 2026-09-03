; ---------------------------------------------------------------------------
; Object - le reflet du counter-air (etincelle secondaire)
;
; input REG : [u] pointer to Object Status Table (OST)
; ---------
;       subtype : bit 0 => 0 = reflet du haut (bleu), 1 = reflet du bas (rouge)
;                 bit 1 => 0 = pod accroche devant, 1 = derriere (miroir, recule)
;
; ARCADE (run_counter_air_reflection 0x404E0F, doc/analyse-bit-device.md §1.6)
; ---------------------------------------------------------------------------
; Cree par la salve du counter-air aux deux coins du pod et sur chaque bit
; vivant (forcepod.asm ForcePodReflections). Degats 2 ; +8 px arcade par
; trame vers l'avant du pod (3 des notres) ; deux images en alternance
; toutes les 4 trames (normale / miroir vertical) ; boite 16/16 x 8/8 arcade
; (6/6 chez nous) ; a chaque trame il efface les gommes du stage 4 et sonde
; le decor. Il meurt hors ecran ; degats epuises ou decor rencontre, il
; s'arrete et joue son FONDU (huit images, la borne les lit a l'envers :
; fade7 en premier) sans plus rien toucher, puis disparait.
; V2-DEVIATION : pas de SFX (la borne joue le tir simple sous le palier 3).
; ---------------------------------------------------------------------------

AABB_0        equ ext_variables      ; AABB struct (9 bytes)
crTick        equ ext_variables+9    ; 1 byte  - trames ecoulees (clignotement)
crFade        equ ext_variables+10   ; 1 byte  - images de fondu restantes (8 -> 0)
crGumPrevX    equ ext_variables+11   ; 2 bytes - x de la trame d'avant (labour)

CR_POWER      equ 2                  ; arcade : damage_potential = 2
CR_STEP       equ 3                  ; arcade : 8 px/trame x 0,375

Object
        lda   routine,u
        asla
        ldx   #Routines
        jmp   [a,x]

Routines
        fdb   Init
        fdb   Live
        fdb   Fade
        fdb   AlreadyDeleted

Init
        lda   #2
        sta   priority,u
        lda   render_flags,u
        ora   #render_playfieldcoord_mask
        ldb   subtype,u
        bitb  #2
        beq   >
        ora   #render_xmirror_mask     ; pod derriere : l'etincelle recule, miroir
!       sta   render_flags,u
        ; x_vel est un s8.8 : la vitesse entiere dans l'octet haut
        lda   #CR_STEP
        bitb  #2
        beq   >
        nega
!       sta   x_vel,u
        clr   x_vel+1,u
        clr   x_sub,u
        clr   crTick,u
        ldd   x_pos,u
        std   crGumPrevX,u             ; amorcer le labour
        _Collision_AddAABB AABB_0,AABB_list_friend
        lda   #CR_POWER
        sta   AABB_0+AABB.p,u
        _ldd  6,6
        std   AABB_0+AABB.rx,u
        inc   routine,u
        ; fall through into Live for the first frame

Live
        ; degats epuises par la passe de collision : le fondu
        lda   AABB_0+AABB.p,u
        lbeq  FadeStart

        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       stb   crFrameDrop
Live.loop
        ; le pas, en s8.8 (idiome de ObjectMoveSync, axe X seul)
        ldb   x_vel,u
        sex
        sta   @a+1
        ldd   x_pos+1,u
        addd  x_vel,u
        std   x_pos+1,u
        lda   x_pos,u
@a      adca  #$00
        sta   x_pos,u
        inc   crTick,u

        ; hors ecran : disparition sans fondu
        ldd   x_pos,u
        subd  glb_camera_x_pos
        cmpd  #-9
        lblt  Delete
        cmpd  #160+9
        lbge  Delete

        ; le decor : la couche destructible est labouree plus bas, ici la
        ; solidite seule (le reflet mange les gommes et CONTINUE, comme la borne)
        ldd   x_pos,u
        std   terrainCollision.sensor.x
        ldd   y_pos,u
        std   terrainCollision.sensor.y
        ldb   #1                       ; foreground
        jsr   terrainCollision.do
        tstb
        bne   FadeStart
        lda   globals.backgroundSolid
        beq   >
        ldb   #0                       ; background
        jsr   terrainCollision.do
        tstb
        bne   FadeStart
!
        dec   crFrameDrop
        lbne  Live.loop

        lbsr  ReflectGumSweep

        ; clignotement : normale / miroir vertical toutes les 4 trames
        ldb   subtype,u
        andb  #1
        aslb                           ; variante haut/bas -> 0 / 2
        lda   crTick,u
        anda  #4
        beq   >
        incb
!       aslb
        ldx   #reflectImages
        ldx   b,x
        stx   image_set,u

        ; la boite de cette trame
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u
        ldb   y_pos+1,u
        stb   AABB_0+AABB.cy,u
        jmp   DisplaySprite

; ---------------------------------------------------------------------------
; FadeStart : le reflet s'arrete, ne touche plus rien, et joue ses huit images
; ---------------------------------------------------------------------------
FadeStart
        _Collision_RemoveAABB AABB_0,AABB_list_friend
        clr   AABB_0+AABB.p,u
        lda   render_flags,u
        anda  #^render_xmirror_mask    ; le fondu n'a pas de miroir (arcade)
        sta   render_flags,u
        lda   #8
        sta   crFade,u
        lda   #2
        sta   routine,u
        ; fall through
Fade
        lda   crFade,u
        suba  gfxlock.frameDrop.count
        bhi   >
        clra
!       sta   crFade,u
        beq   FadeDone                 ; la boite est deja retiree (FadeStart)
        deca                           ; 7 -> 0 : la borne lit sa table a l'envers
        asla
        ldx   #reflectFade
        ldx   a,x
        stx   image_set,u
        jmp   DisplaySprite

; ---------------------------------------------------------------------------
; Delete / FadeDone — LA BOITE NE SE RETIRE QU'UNE FOIS
; ---------------------------------------------------------------------------
; Collision_RemoveAABB delie le noeud par SES PROPRES prev/next et ne les
; efface pas (c'est le role de _Collision_CleanLinksAABB) : un second retrait
; rejoue le deliage avec des liens PERIMES et ecrit dans des noeuds qui ne
; sont plus les voisins — la liste friend se corrompt, et le jeu part en vrille
; au bout de quelques fondus. C'est ce que faisait le chemin
; Live -> FadeStart (retrait) -> Fade -> Delete (retrait a nouveau).
; Depuis : FadeStart retire, et le fondu fini passe par FadeDone qui ne
; retire plus rien. Delete reste l'entree des morts SANS fondu (hors ecran),
; ou la boite est encore dans la liste.
; ---------------------------------------------------------------------------
Delete
        _Collision_RemoveAABB AABB_0,AABB_list_friend
FadeDone
        lda   #3
        sta   routine,u
        jmp   DeleteObject

AlreadyDeleted
        rts

; ---------------------------------------------------------------------------
; ReflectGumSweep — le reflet laboure les gommes du stage 4
; ---------------------------------------------------------------------------
; ARCADE : clear_green_ball_helper_stage4 a chaque trame, un amas 2x2 de
; cellules. Idiome du pod : l'entree +6 du crochet efface le rectangle balaye
; entre la trame d'avant et la courante, bloc $22, coin = centre - (3, 6).
; Hors stage 4 le crochet est stage.gum.none.
; ---------------------------------------------------------------------------
ReflectGumSweep
        ldd   stage.gum.hook
        addd  #6
        std   @call
        ldd   x_pos,u
        ldy   crGumPrevX,u
        std   crGumPrevX,u
        subd  #3
        tfr   d,x
        leay  -3,y
        ldb   y_pos+1,u
        subb  #6
        bhs   >
        clrb
!       lda   #$22
        jsr   >0
@call   equ   *-2
        rts

; le compteur de boucle de trames, variable d'unite (idiome du tir simple)
crFrameDrop     fcb   0

reflectImages
        fdb   Img_careflect_up0
        fdb   Img_careflect_up1
        fdb   Img_careflect_dn0
        fdb   Img_careflect_dn1
reflectFade
        fdb   Img_careflect_fade0
        fdb   Img_careflect_fade1
        fdb   Img_careflect_fade2
        fdb   Img_careflect_fade3
        fdb   Img_careflect_fade4
        fdb   Img_careflect_fade5
        fdb   Img_careflect_fade6
        fdb   Img_careflect_fade7
