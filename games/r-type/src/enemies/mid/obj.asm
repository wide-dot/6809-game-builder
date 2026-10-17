;*******************************************************************************
; mid — FICHE DE PORTAGE (base Ghidra `maincpu`, subsystem enemy_mid, 17/10/2026)
;
;   40:5CEA create_mid ............ x 0x2C8, y = pata_pata_preset_y[param & 15],
;                                    table de difficulte 1000:298A, un tirage
;                                    random_ax (+0x12, que le Mid ne relit pas)
;   40:5D2D run_mid ............... son tick : -2 px/trame, la pose, le laser,
;                                    la collision une trame sur deux
;   40:5D9A mid_spawn_horizontal_laser_child   le compte du laser
;   40:E6AB run_horizontal_laser .. le laser enfant (ctor puis tick E6C0)
;   1000:299A ses 8 poses (une recette chacune)  1000:29CA sa boite (+/-9, +/-5)
;   1000:84CE les 4 images du laser (deux cellules)  1000:84FE sa boite (+/-16, +/-4)
;
; Le « vaisseau tournoyant aux lasers percants » des stages 5 et 7. Il naît au
; bord droit et file vers la gauche a 2 px/trame arcade SUR L'ECRAN : son tick
; ne lit pas scroll_amount (0x2ED0), il est ancre a l'ecran, pas au decor. Il
; tourne sur huit poses, une toutes les 4 trames, en phase sur le compteur
; global plus un octet de son enregistrement (+0x20) qu'il n'ecrit jamais :
; l'allocateur ne remet pas les enregistrements a zero, c'est le reste de
; l'occupant precedent. Toutes les `periode` trames il lache un laser
; horizontal qui file vers la gauche, lui aussi ancre a l'ecran, et tue le
; vaisseau au contact (collision_to_player_one : les armes le traversent).
; Mort au premier coup (do_collision_with_player_and_weapons_v1), score 0x86F4,
; son 0x50, explosion_small_x2 ; retrait silencieux sous x 0x140.
;
; LA DIFFICULTE (1000:298A, quatre paires {vx du laser, periode}) :
;   0 : -6 px/trame, 48 trames    1 : -8, 32    2 : -10, 16    3 : -12, 8
; Le premier laser part au bout d'une periode (le compte part de la periode).
;
; CONVERSION : -2 px arcade -> -0,75 px v2 (8.8 : -192) ; laser -6..-12 ->
; -2,25..-4,5 px (8.8 : -576..-1152) ; boites +/-9 x +/-5 -> rayons 3 et 4,
; +/-16 x +/-4 -> 6 et 3 ; retrait du laser sous x 300 (is_visible_range) ->
; ecran 0,5.
; L'ANCRAGE A L'ECRAN : nous vivons en playfield, donc le Mid et son laser sont
; tires par la camera a chaque rendu (x += camera - camera_old, comme le tabrok
; en chute) ; leur mouvement propre est rejoue trame par trame.
; LE LASER est le MEME objet (meme unite, meme page) ne avec l'identifiant de
; son pere et un sous-type marque ($FF en octet haut) : pas d'identifiant a
; aligner entre les stages 5 et 7. Il nait a la trame ou le compte tombe, et
; rattrape les trames qui restent du rendu de son pere (la borne le cree de
; priorite plus basse : son premier tick est la trame suivante).
; ECARTS : la phase de pose est tiree au hasard a la naissance (l'octet laisse
; par l'occupant precedent du slot) ; la collision est testee a chaque rendu
; (la borne : une trame sur deux) ; le son du laser (0x59) n'a pas de source
; chez nous ; palettes par objet abandonnees.
;*******************************************************************************

mid.box         equ ext_variables      ; 0..8  la boite
mid.vx          equ ext_variables+9    ; 9,10  vx 8.8 du laser (Mid) / la sienne (laser)
mid.timer       equ ext_variables+11   ; 11    compte avant le prochain laser
mid.period      equ ext_variables+12   ; 12    sa periode
mid.phase       equ ext_variables+13   ; 13    phase de pose (0..$1C, pas de 4)

mid.VX          equ -192               ; 0xFE00 arcade : -2 x 0,375

mid.Object
        lda   routine,u
        asla
        ldx   #mid.Routines
        jmp   [a,x]
mid.Routines
        fdb   mid.Init
        fdb   mid.Live
        fdb   mid.Deleted
        fdb   mid.laser.Live
        fdb   mid.Deleted

mid.Init
        ldb   wave_frame_drop,u        ; le retard, AVANT tout le reste
        stb   mid.late
        tst   subtype_w,u              ; le laser : octet haut $FF
        lbmi  mid.laser.Init
        ; 5cf7 : x 0x2C8, y du preset 18DB0 (celui du pata-pata) — x en
        ; ecran : le retard a deja fait avancer le Mid, pas le decor
        ldd   glb_camera_x_pos
        addd  #144+8+3
        std   x_pos,u
        lda   glb_camera_x_pos+2       ; la fraction camera
        sta   x_pos+2,u
        lda   subtype_w+1,u
        anda  #$0F
        ldx   #mid.PresetY
        ldb   a,x
        clra
        std   y_pos,u
        clr   y_pos+2,u
        ; 5cfa : la paire de la difficulte
        ldb   globals.difficulty
        aslb
        aslb
        ldx   #mid.Diff
        abx
        ldd   ,x
        std   mid.vx,u
        lda   2,x
        sta   mid.period,u
        sta   mid.timer,u              ; 5d11 : le compte part de la periode
        ; +0x20 : le reste de l'occupant precedent
        jsr   RandomNumber
        andb  #$1C
        stb   mid.phase,u
        ldb   #6
        stb   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        _Collision_AddAABB mid.box,AABB_list_ennemy
        lda   #mid_hitdamage
        sta   mid.box+AABB.p,u
        _ldd  mid_hitbox_x,mid_hitbox_y
        std   mid.box+AABB.rx,u
        inc   routine,u
        ldb   mid.late                 ; il rattrape les trames de son retard
        bra   mid.Run

mid.Live
        jsr   mid.Drag
        ldb   gfxlock.frameDrop.count
        bne   mid.Run
        incb
mid.Run
        stb   mid.n
        lda   mid.box+AABB.p,u         ; 5d59 : touche -> explosion
        lbeq  mid.Boom
        tst   mid.n
        beq   @show
@frame  ldd   #mid.VX                  ; 5d2d : -2 px/trame, une trame
        leax  x_pos,u
        jsr   mid.Add
        dec   mid.timer,u              ; 5d9a : le compte du laser
        bne   >
        lda   mid.period,u
        sta   mid.timer,u
        jsr   mid.Fire
!       dec   mid.n
        bne   @frame
@show   ldd   x_pos,u                  ; 5d61 : sous x 0x140, retrait
        subd  glb_camera_x_pos
        cmpd  #8
        lblt  mid.Vanish
        stb   mid.box+AABB.cx,u
        ldb   y_pos+1,u
        stb   mid.box+AABB.cy,u
        ; 5d33 : ((compteur + phase) & $1C) / 4 -> une pose toutes les 4 trames
        ldb   gfxlock.frame.gameCount+1
        addb  mid.phase,u
        andb  #$1C
        lsrb
        ldx   #mid.Images
        ldd   b,x
        std   image_set,u
        jmp   DisplaySprite

; 5da5 : le laser, a la position du Mid, sa vitesse de la difficulte. Il
; rattrape les trames qui restent dans ce rendu apres celle-ci.
mid.Fire
        jsr   LoadObject_x
        beq   @rts                     ; pool plein : le tir est perdu (5dae)
        lda   id,u
        sta   id,x
        lda   #$FF
        sta   subtype_w,x
        ldb   mid.n
        decb
        stb   wave_frame_drop,x
        ldd   x_pos,u
        std   x_pos,x
        lda   x_pos+2,u
        sta   x_pos+2,x
        ldd   y_pos,u
        std   y_pos,x
        ldd   mid.vx,u
        std   mid.vx,x
        ; 5dc2 : son 0x59, le tir laser — pas de source chez nous
@rts    rts

; 5d70 : score 0x86F4, son 0x50, explosion_small_x2
mid.Boom
        ldb   #mid_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        beq   mid.Vanish
        _ldd  ObjID_explosion,explosion.subtype.smallx2+explosion.sfx.small
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
mid.Vanish
        lda   #2
        sta   routine,u
        _Collision_RemoveAABB mid.box,AABB_list_ennemy
        jmp   DeleteObject
mid.Deleted
        rts

;*******************************************************************************
; Le laser horizontal (40:E6AB) : il file, il tue au contact, il sort.
;*******************************************************************************
mid.laser.Init
        ldb   #6
        stb   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ; e6e0 : collision_to_player_one — le contact tue, les armes passent
        _Collision_AddAABB mid.box,AABB_list_ennemy_unkillable
        lda   #$FF
        sta   mid.box+AABB.p,u
        _ldd  midlaser_hitbox_x,midlaser_hitbox_y
        std   mid.box+AABB.rx,u
        lda   #3
        sta   routine,u
        ldb   mid.late
        bra   mid.laser.Run

mid.laser.Live
        jsr   mid.Drag
        ldb   gfxlock.frameDrop.count
        bne   mid.laser.Run
        incb
mid.laser.Run
        tstb
        beq   @show
@frame  pshs  b
        ldd   mid.vx,u                 ; e6c0 : sa vitesse, une trame
        leax  x_pos,u
        jsr   mid.Add
        puls  b
        decb
        bne   @frame
@show   ldd   x_pos,u                  ; e6f0 : is_visible_range, x < 300
        subd  glb_camera_x_pos
        bmi   mid.laser.Vanish
        stb   mid.box+AABB.cx,u
        ldb   y_pos+1,u
        stb   mid.box+AABB.cy,u
        ; e6c6 : (compteur & 6) / 2 -> une image toutes les 2 trames
        ldb   gfxlock.frame.gameCount+1
        andb  #6
        ldx   #mid.LaserImages
        ldd   b,x
        std   image_set,u
        jmp   DisplaySprite
mid.laser.Vanish
        lda   #4
        sta   routine,u
        _Collision_RemoveAABB mid.box,AABB_list_ennemy_unkillable
        jmp   DeleteObject

;*******************************************************************************
; L'ancrage a l'ecran : tire par la camera, une fois par rendu
mid.Drag
        ldd   x_pos,u
        addd  glb_camera_x_pos
        subd  glb_camera_x_pos_old
        std   x_pos,u
        rts

; D = vitesse 8.8, X = le champ position (haut, bas, fraction) : une trame
mid.Add
        pshs  a                        ; la partie entiere, signee
        addb  2,x                      ; la fraction
        stb   2,x
        puls  b                        ; (puls ne touche pas CC : la retenue reste)
        sex                            ; (sex non plus)
        adcb  1,x
        adca  ,x
        std   ,x
        rts

mid.n           fcb 0
mid.late        fcb 0

; 1000:298A : par difficulte, la vitesse du laser (8.8 v2) et sa periode
mid.Diff
        fdb   -576
        fcb   48,0                     ; 0 : 0xFA00, 0x30
        fdb   -768
        fcb   32,0                     ; 1 : 0xF800, 0x20
        fdb   -960
        fcb   16,0                     ; 2 : 0xF600, 0x10
        fdb   -1152
        fcb   8,0                      ; 3 : 0xF400, 0x08

; 1000:299A : les huit poses, dans l'ordre de la borne
mid.Images
        fdb   set_mid_0,set_mid_1,set_mid_2,set_mid_3
        fdb   set_mid_4,set_mid_5,set_mid_6,set_mid_7
; 1000:84CE : les quatre images du laser
mid.LaserImages
        fdb   set_midlaser_0,set_midlaser_1,set_midlaser_2,set_midlaser_3

mid.PresetY                            ; 1000:8DB0 pata_pata_preset_y
        INCLUDE "src/common/lib/presets/18db0_preset-y.asm"
