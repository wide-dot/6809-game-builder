;*******************************************************************************
; fast — FICHE DE PORTAGE (base Ghidra `maincpu`, subsystem fast, 17/10/2026)
;
;   40:8469 create_fast ......... x 0x2C8, y = pata_pata_preset_y[param & 15],
;                                  preset de tir (param >> 4), vx -2, vy 0
;   40:8490 run_fast ............ son tick ; 84CA la sonde, 8515 le rebond
;   40:8537 fast_destroy ........ score 0x86EC, son 0x50, explosion_small_x2
;   1000:39A6 son image (une pose)   1000:39AC sa boite (+/-12)
;
; Le « chasseur leger » du stage 7. Il derive vers la gauche a 2 px/trame
; arcade, ancre au decor (scroll_amount ajoute a son x : repere playfield,
; aucun code), et tire par le systeme commun (try_foe_fire, preset de tir).
; SES CAPTEURS : chaque trame il sonde le decor 0x20 px devant lui (vers la
; gauche). Bloque et immobile en Y : il s'arrete (vx 0) et part en Y a
; +/-1 px/trame, le sens tire sur le bit 0 du compteur global, pour 8 trames
; au moins. Bloque et deja en mouvement en Y : il sonde 0x18 px dans ce sens
; et rebondit (NEG vy) si c'est dur aussi. Libre : il epuise son delai puis
; reprend sa derive (vx -2, vy 0).
; Mort au premier coup (do_collision_v1), retrait silencieux sous x 0x140.
;
; CONVERSION : vx -2 arcade -> -0,75 px v2 (8.8 : -192) ; vy +/-1 arcade ->
; -/+0,75 (axe Y inverse) ; sonde devant -0x20 -> -12 px v2, sonde de cote
; 0x18 -> 18 lignes dans le sens de vy ; boite +/-12 -> rayons 4 et 9.
; LA COMPENSATION DE TRAME : la sonde et ses decisions sont rejouees trame par
; trame (elles changent la vitesse a mi-parcours), le deplacement aussi.
; LE SENS D'EVASION est la parite du compteur global a la trame de la
; decision : elle se prend trame rejouee par trame rejouee, l'origine est
; frame_time (GC0), la naissance est celle de la borne (une ligne de wave par
; trame, OBJECTWAVE_ONE_PER_FRAME) et l'abscisse de naissance recule de la
; camera deja parcourue. Verifie sous toje contre la trace MAME de l'etat
; d'entree : les trois evasions du debut de stage (bas, haut, bas) tombent a
; la meme trame et dans le meme sens, et aucune autre.
; ECARTS : la sonde lit la carte de collision du portage (cellules dures) et
; non les numeros de tuile du plan avant (memes reponses sur ce trajet) ; en
; partie reelle la parite depend du temps deja joue avant le stage ; palette
; par objet abandonnee.
;*******************************************************************************

fast.box        equ ext_variables      ; 0..8  la boite
fast.vx         equ ext_variables+9    ; 9,10  vitesse 8.8 v2
fast.vy         equ ext_variables+11   ; 11,12
fast.cool       equ ext_variables+13   ; 13    delai d'evasion (trames)

fast.VX         equ -192               ; 0xFE00 arcade : -2 x 0,375
fast.VY         equ 192                ; 0x0100 arcade : 1 x 0,75
fast.AHEAD      equ 12                 ; 0x20 arcade : la sonde devant
fast.SIDE       equ 18                 ; 0x18 arcade : la sonde de cote
fast.GC0        equ 63830              ; compteur global de la borne a l'horloge
                                       ; de stage 0 : frame_time (demi-trames) y
                                       ; vaut le debut du stage, un cran avant
                                       ; l'etat d'entree de reference (63831) ;
                                       ; seule la parite compte

fast.Object
        lda   routine,u
        asla
        ldx   #fast.Routines
        jmp   [a,x]
fast.Routines
        fdb   fast.Init
        fdb   fast.Live
        fdb   fast.Deleted

fast.Init
        ldb   wave_frame_drop,u        ; le retard, AVANT tout le reste
        stb   fast.late
        ; 8469 : x 0x2C8, y du preset 18DB0 (celui du pata-pata)
        ldd   glb_camera_x_pos
        addd  #144+8+3
        std   x_pos,u
        lda   glb_camera_x_pos+2       ; la fraction camera (cf. cytron)
        sta   x_pos+2,u
        ; le recul : la camera lue a deja avance de late x $30 (8.8) depuis la
        ; trame de naissance. 0,56 px pour trois trames, mais la sonde decide
        ; a la trame pres, et la parite du compteur avec elle
        lda   fast.late
        ldb   #$30
        mul                            ; A = entier du recul, B = sa fraction
        pshs  d
        lda   x_pos+2,u
        suba  1,s                      ; la fraction (emprunt -> C)
        sta   x_pos+2,u
        ldd   x_pos,u                  ; (ldd garde C)
        sbcb  ,s+                      ; l'entier, avec l'emprunt
        sbca  #0
        std   x_pos,u
        leas  1,s
        lda   subtype_w+1,u
        anda  #$0F
        ldx   #fast.PresetY
        ldb   a,x
        clra
        std   y_pos,u
        clr   y_pos+2,u
        ldb   subtype_w+1,u            ; le preset de tir, AVANT render_flags
        _loadFirePreset
        ldb   #6
        stb   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        _Collision_AddAABB fast.box,AABB_list_ennemy
        lda   #fast_hitdamage
        sta   fast.box+AABB.p,u
        _ldd  fast_hitbox_x,fast_hitbox_y
        std   fast.box+AABB.rx,u
        ldd   #fast.VX
        std   fast.vx,u
        ldd   #0
        std   fast.vy,u
        clr   fast.cool,u
        inc   routine,u
        ldb   fast.late                ; il rattrape les trames de son retard
        bra   fast.Run

fast.Live
        ldb   gfxlock.frameDrop.count
        bne   fast.Run
        incb
fast.Run
        stb   fast.n
        lda   fast.box+AABB.p,u        ; 84ae : touche -> explosion
        lbeq  fast.Boom
        tst   fast.n
        beq   @show
@frame  jsr   fast.Step                ; une trame arcade
        dec   fast.n
        bne   @frame
@show   jsr   tryFoeFire
        ldd   x_pos,u                  ; 84b6 : sous x 0x140, retrait
        subd  glb_camera_x_pos
        cmpd  #8
        lblt  fast.Vanish
        stb   fast.box+AABB.cx,u
        ldb   y_pos+1,u
        stb   fast.box+AABB.cy,u
        ldd   #set_fast_0
        std   image_set,u
        jmp   DisplaySprite

; une trame : le deplacement (8496), puis la sonde et ses decisions (84ca)
fast.Step
        ldd   fast.vx,u
        leax  x_pos,u
        jsr   fast.Add
        ldd   fast.vy,u
        leax  y_pos,u
        jsr   fast.Add
        ldd   x_pos,u                  ; 84cd : la sonde devant
        subd  #fast.AHEAD
        cmpd  glb_camera_x_pos         ; pas a gauche de l'ecran 0 : l'index
        bge   >                        ; de colonne de la sonde est un octet
        ldd   glb_camera_x_pos         ; (ses 4 derniers px, juste avant le
!       std   terrainCollision.sensor.x ; retrait)
        ldd   y_pos,u
        std   terrainCollision.sensor.y
        jsr   terrainCollision.doFoe
        tstb
        beq   @clear
        ldd   fast.vy,u                ; 84dc : bloque — deja en mouvement en Y ?
        bne   @side
        ldd   #0                       ; 84e3 : l'arret, et l'evasion en Y
        std   fast.vx,u
        ldd   #fast.VY                 ; 0xFF00 arcade : -1 sur un axe qui monte,
        pshs  d                        ; donc vers le bas a l'ecran
        ldb   gfxlock.frame.gameCount+1 ; la trame rejouee : celle du rendu
        subb  fast.n                   ; moins les trames qui restent apres elle
        addb  #(fast.GC0+1)&$FF        ; le compteur global de la borne
        bitb  #1                       ; 84eb : son bit 0
        puls  d                        ; (puls ne touche pas CC)
        beq   >
        ldd   #-fast.VY                ; 84f3 : 0x0100, vers le haut
!       std   fast.vy,u
        lda   #8                       ; 84f9 : 8 trames au moins
        sta   fast.cool,u
        rts
@clear  lda   fast.cool,u              ; 84ff : libre — le delai s'epuise
        beq   @drift
        dec   fast.cool,u
        rts
@drift  ldd   #fast.VX                 ; 850a : la derive reprend
        std   fast.vx,u
        ldd   #0
        std   fast.vy,u
        rts
@side   ldd   y_pos,u                  ; 8515 : la sonde de cote, dans le sens
        tst   fast.vy,u                ; de vy
        bmi   @up
        addd  #fast.SIDE
        bra   @probe
@up     subd  #fast.SIDE
@probe  std   terrainCollision.sensor.y
        ldd   x_pos,u
        std   terrainCollision.sensor.x
        jsr   terrainCollision.doFoe
        tstb
        beq   @rts
        ldd   #0                       ; 8533 : dur aussi, il rebondit
        subd  fast.vy,u
        std   fast.vy,u
@rts    rts

; D = vitesse 8.8, X = le champ position (haut, bas, fraction) : une trame
fast.Add
        pshs  a                        ; la partie entiere, signee
        addb  2,x                      ; la fraction
        stb   2,x
        puls  b                        ; (puls ne touche pas CC : la retenue reste)
        sex                            ; (sex non plus)
        adcb  1,x
        adca  ,x
        std   ,x
        rts

; 8537 : score 0x86EC, son 0x50, explosion_small_x2
fast.Boom
        ldb   #fast_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        beq   fast.Vanish
        _ldd  ObjID_explosion,explosion.subtype.smallx2+explosion.sfx.small
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
fast.Vanish
        lda   #2
        sta   routine,u
        _Collision_RemoveAABB fast.box,AABB_list_ennemy
        jmp   DeleteObject
fast.Deleted
        rts

fast.n          fcb 0
fast.late       fcb 0

fast.PresetY                           ; 1000:8DB0 pata_pata_preset_y
        INCLUDE "src/common/lib/presets/18db0_preset-y.asm"
