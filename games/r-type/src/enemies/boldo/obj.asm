;*******************************************************************************
; boldo — FICHE DE PORTAGE (base Ghidra `maincpu`, subsystem enemy_boldo, 17/10/2026)
;
;   40:6E9B create_boldo .......... x 0x110, y 0x108, 200 PV (+0x2F = 0xC8)
;   40:6EC4 run_boldo ............. son tick : ancre au decor, la derive, le
;                                    dessin en quatre tranches, la collision
;   40:6F32 sa mort ............... son 0x53, score 0x870C, grosse explosion
;                                    grise et brune (E817) a sa place, puis une
;                                    chaine de petites (E7B6) depuis 1000:301C
;   1000:3042 .. 3066 ses quatre tranches (deux cellules chacune)
;   1000:3072 sa boite (+/-56, +/-18)
;
; L'obstacle flottant du stage 7 : il ne tire pas, il encaisse. Il nait a
; GAUCHE de l'ecran (x 0x110 : 48 px avant le bord, a moitie dehors), ancre
; au decor (son tick ajoute scroll_amount), et avance de 0,75 px/trame tant
; que le decor est libre 64 px devant lui — sur les deux plans — ou qu'il a
; passe x 0x280. Bloque, il recule avec le decor. Retrait silencieux hors de
; [0x108, 0x300) ; un coup joue le son 0x56 (le crochet de collision du
; moteur le fait pour toute boite qui encaisse).
;
; CONVERSION : x 0x110 -> ecran -10, y 0x108 -> 99 ; derive 0xC0 -> 72 (8.8) ;
; sonde a +64 -> +24 ; seuil 0x280 -> ecran 128 ; retrait 0x108 / 0x300 ->
; ecran -13 / 176 ; boite +/-56 x +/-18 -> rayons 21 et 13 ; la chaine
; d'explosions convertie offset par offset (x 0,375, y -0,75).
; LES 200 PV : le potentiel d'une boite est un octet signe (1..126) ; la
; boite en porte 125, la reserve le reste et la recharge a chaque rendu
; (le reacteur du stage 3 au second tour).
; LES QUATRE TRANCHES : notre moteur de sprites ne rogne pas, et le Boldo
; entre lentement par la gauche. Comme la borne, il se dessine en quatre
; colonnes de 12 px (tools/gen_boldo_slices.py) : lui porte la premiere, et
; trois tranches esclaves — le MEME objet ne avec son identifiant et un
; sous-type marque ($FF, puis le rang) — suivent sa position. Chacune
; s'affiche des qu'elle est entiere dans la fenetre.
; LA CHAINE : la borne avance son curseur de DEUX octets pour des paires de
; quatre (6F71) — dix-sept explosions qui se chevauchent, toutes la meme
; trame, tant que le pool tient. Repris tel quel.
; ECARTS : la sonde lit la carte de collision du portage ; le seuil 0x280 se
; juge au rendu (la camera du rendu, pas celle de chaque trame) ; palette
; par objet abandonnee.
;*******************************************************************************

boldo.box       equ ext_variables      ; 0..8  la boite (le pere)
boldo.extra     equ ext_variables+9    ; 9     la reserve de PV
boldo.father    equ ext_variables+9    ; 9,10  (tranche) l'OST du pere
boldo.slot      equ ext_variables+11   ; 11    (tranche) son decalage, 12 x rang
boldo.img       equ ext_variables+12   ; 12,13 (tranche) son image

boldo.SPAWNX    equ -10-18             ; arcade 0x110, centre -> premiere tranche
boldo.SPAWNY    equ 99                 ; arcade 0x108
boldo.DRIFT     equ 72                 ; 0x00C0 arcade : 0,75 x 0,375
boldo.AHEAD     equ 24                 ; 0x40 arcade
boldo.HALF      equ 18                 ; du centre a la premiere tranche
boldo.CAP       equ 125
boldo.HP        equ 200                ; 6eb6 : +0x2F = 0xC8

boldo.Object
        lda   routine,u
        asla
        ldx   #boldo.Routines
        jmp   [a,x]
boldo.Routines
        fdb   boldo.Init
        fdb   boldo.Live
        fdb   boldo.Deleted
        fdb   boldo.slice.Live
        fdb   boldo.Deleted

boldo.Init
        ldb   wave_frame_drop,u        ; le retard, AVANT tout le reste
        stb   boldo.late
        lda   subtype_w,u              ; une tranche : octet haut $FF
        cmpa  #$FF
        lbeq  boldo.slice.Init
        ; 6ea8 : x 0x110, y 0x108 — x en playfield : ancre au decor, le
        ; retard ne l'a pas deplace (il ne derive qu'a partir de son tick)
        ldd   glb_camera_x_pos
        addd  #boldo.SPAWNX
        std   x_pos,u
        clr   x_pos+2,u
        ldd   #boldo.SPAWNY
        std   y_pos,u
        clr   y_pos+2,u
        ldb   #6
        stb   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        _Collision_AddAABB boldo.box,AABB_list_ennemy
        lda   #boldo.CAP
        sta   boldo.box+AABB.p,u
        lda   #boldo.HP-boldo.CAP
        sta   boldo.extra,u
        _ldd  boldo_hitbox_x,boldo_hitbox_y
        std   boldo.box+AABB.rx,u
        ; les trois autres tranches
        ldy   #boldo.SliceImages
        lda   #12
@slice  pshs  a
        jsr   LoadObject_x
        puls  a
        beq   @done
        ldb   id,u
        stb   id,x
        ldb   #$FF
        stb   subtype_w,x
        sta   boldo.slot,x
        stu   boldo.father,x
        pshs  a
        ldd   ,y++
        std   boldo.img,x
        puls  a
        adda  #12
        cmpa  #48
        blo   @slice
@done   inc   routine,u
        ldb   boldo.late               ; il rattrape les trames de son retard
        bra   boldo.Run

boldo.Live
        jsr   boldo.Refill
        ldb   gfxlock.frameDrop.count
        bne   boldo.Run
        incb
boldo.Run
        stb   boldo.n
        lda   boldo.box+AABB.p,u       ; 6f14 : PV epuises -> la mort
        lbeq  boldo.Boom
        tst   boldo.n
        beq   @show
@frame  jsr   boldo.Step
        dec   boldo.n
        bne   @frame
@show   ldd   x_pos,u                  ; 6f23 : retrait hors de [0x108, 0x300)
        addd  #boldo.HALF
        subd  glb_camera_x_pos
        cmpd  #-13
        lblt  boldo.Vanish
        cmpd  #176
        lbge  boldo.Vanish
        tsta                           ; cx est un octet : un centre encore
        bpl   >                        ; hors ecran se borne a 0
        clrb
!       stb   boldo.box+AABB.cx,u
        ldb   y_pos+1,u
        stb   boldo.box+AABB.cy,u
        ldd   #set_boldo_0
        std   image_set,u
        jmp   DisplaySprite

; 6eca : une trame — passe 0x280, ou libre 64 px devant : la derive
boldo.Step
        ldd   x_pos,u
        addd  #boldo.HALF
        pshs  d
        subd  glb_camera_x_pos
        cmpd  #128
        puls  d
        bge   @drift
        addd  #boldo.AHEAD             ; 6ed4 : la sonde a +64
        std   terrainCollision.sensor.x
        ldd   y_pos,u
        std   terrainCollision.sensor.y
        jsr   terrainCollision.doFoe
        tstb
        bne   @rts                     ; 6ee1 : dur devant, il suit le decor
@drift  ldd   #boldo.DRIFT             ; 6ee9 : 0,75 px/trame
        leax  x_pos,u
        jmp   boldo.Add
@rts    rts

; La reserve : p += min(CAP - p, reserve), la reserve d'autant.
boldo.Refill
        ldb   boldo.extra,u
        beq   @rts
        lda   #boldo.CAP
        suba  boldo.box+AABB.p,u       ; A = la place dans la boite
        beq   @rts
        pshs  a
        cmpb  ,s+
        bls   @t                       ; la reserve tient : elle passe toute
        tfr   a,b                      ; sinon la place seule
@t      pshs  b
        lda   boldo.extra,u
        suba  ,s
        sta   boldo.extra,u
        lda   boldo.box+AABB.p,u
        adda  ,s+
        sta   boldo.box+AABB.p,u
@rts    rts

; 6f32 : son 0x53, score 0x870C, la grosse explosion grise et brune a sa
; place, puis les dix-sept petites de 1000:301C
boldo.Boom
        ldb   #boldo_scoreIdx
        jsr   AwardScore
        ldd   x_pos,u
        addd  #boldo.HALF
        std   x_pos,u                  ; le centre, pour les explosions
        jsr   LoadObject_x
        beq   boldo.Vanish
        _ldd  ObjID_explosion,explosion.subtype.big.brown+explosion.sfx.big
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
        ldy   #boldo.Chain
@chain  jsr   LoadObject_x             ; 6f5c : pool plein, la chaine s'arrete
        beq   boldo.Vanish
        _ldd  ObjID_explosion,explosion.subtype.smallx3+explosion.sfx.none
        std   id,x
        ldb   ,y+
        sex
        addd  x_pos,u
        std   x_pos,x
        ldb   ,y+
        sex
        addd  y_pos,u
        std   y_pos,x
        cmpy  #boldo.Chain.end
        blo   @chain
boldo.Vanish
        lda   #2
        sta   routine,u
        _Collision_RemoveAABB boldo.box,AABB_list_ennemy
        jmp   DeleteObject
boldo.Deleted
        rts

;*******************************************************************************
; Une tranche : la position du pere, decalee de son rang. Elle tourne apres
; lui (ajoutee en fin de liste) et le suit dans la mort.
;*******************************************************************************
boldo.slice.Init
        ldb   #6
        stb   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        lda   #3
        sta   routine,u
boldo.slice.Live
        ldx   boldo.father,u
        lda   id,x                     ; le pere vit encore ?
        cmpa  id,u
        bne   @gone
        lda   routine,x
        cmpa  #1
        bne   @gone
        ldb   boldo.slot,u
        clra
        addd  x_pos,x
        std   x_pos,u
        ldd   y_pos,x
        std   y_pos,u
        ldd   boldo.img,u
        std   image_set,u
        jmp   DisplaySprite
@gone   lda   #4
        sta   routine,u
        jmp   DeleteObject

; D = vitesse 8.8, X = le champ position (haut, bas, fraction) : une trame
boldo.Add
        pshs  a                        ; la partie entiere, signee
        addb  2,x                      ; la fraction
        stb   2,x
        puls  b                        ; (puls ne touche pas CC : la retenue reste)
        sex                            ; (sex non plus)
        adcb  1,x
        adca  ,x
        std   ,x
        rts

boldo.n         fcb 0
boldo.late      fcb 0

boldo.SliceImages
        fdb   set_boldo_1,set_boldo_2,set_boldo_3

; 1000:301C, lu par paires qui se chevauchent : (dx, dy) arcade -> v2
boldo.Chain
        fcb   8,-6                     ; 20,8
        fcb   3,24                     ; 8,-32
        fcb   -12,-8                   ; -32,10
        fcb   4,29                     ; 10,-39
        fcb   -15,6                    ; -39,-8
        fcb   -3,-39                   ; -8,52
        fcb   20,-2                    ; 52,2
        fcb   1,-20                    ; 2,26
        fcb   10,10                    ; 26,-13
        fcb   -5,-7                    ; -13,9
        fcb   3,-9                     ; 9,12
        fcb   4,0                      ; 12,0
        fcb   0,3                      ; 0,-4
        fcb   -2,10                    ; -4,-14
        fcb   -5,3                     ; -14,-4
        fcb   -2,-39                   ; -4,52
        fcb   20,-24                   ; 52,32
boldo.Chain.end
