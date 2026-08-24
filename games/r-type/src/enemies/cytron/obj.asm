; ---------------------------------------------------------------------------
; Cytron — l'ennemi mecanique qui rampe sur les parois du stage 4
;
; input REG : [u] pointer to Object Status Table (OST)
; ---------------------------------------------------------------------------
;
; FICHE DE PORTAGE
; ================
; arcade : create_cytron 0x40:696E, run_cytron 0x40:69B4,
;          draw_cytron_sprite_with_hit_blink 0x40:6A78
; bestiaire : stage 4 et stage 6. Le stage 4 en fait naitre 38.
;
; CE QU'IL FAIT, dans l'ordre du tick arcade :
;   1. move_by_script — il avance selon un script bit-packe de la rom. Le
;      script FINI, l'arcade decharge l'objet en silence (0x6A42).
;   2. pos_x += scroll_amount — il est ANCRE AU DECOR. En v2 c'est implicite :
;      render_playfieldcoord_mask fait recular x_pos tout seul, donc rien a
;      faire ici (cf. arcade-to-v2.md, « le test est mecanique : le tick
;      arcade lit-il 0x2ED0 ? » — celui-ci le lit).
;   3. try_foe_fire — la cadence de tir, preset charge au spawn.
;   4. le sprite, avec clignotement de touche.
;   5. LA REPOUSSE — sa signature. Voir plus bas.
;   6. collision joueur + armes, clignotement 12 trames, SFX 0x56.
;   7. PV : damage_taken vs damage_max (3/5/8/14 selon la difficulte).
;
; LA REPOUSSE — ce que la plate Ghidra dit, et ce que le code fait
; ---------------------------------------------------------------
; La plate annonce « la cellule sous le centre du corps ». C'est faux, et
; l'ecart compte : run_cytron lit un couple (dx,dy) dans une table INDEXEE PAR
; LA POSE (0x1000:2D90), l'ajoute a sa position, sonde LA, puis restaure. Cette
; table est un CERCLE DE RAYON 12 px arcade sur seize directions — cytron seme
; sa gomme DERRIERE lui, dans l'axe de sa pose. C'est ce qui lui fait laisser
; une trainee et non un point.
;
; Il n'ecrit que dans une cellule qui lit exactement TILE_EMPTY (0xFA0), donc
; jamais dans le terrain dur ; et il est l'exact inverse de la Wave Cannon du
; joueur, qui ecrit 0xFA0 sur les gommes. Les deux forment la boucle du stage 4.
;
; Cote v2, 1 tuile arcade = 1 CELLULE de gomme, au pixel : 8 px arcade x 0,375
; = 3 px larges, 8 x 0,75 = 6 lignes. pellet.grow porte la regle (vide ET pas
; dur), exactement comme la sonde arcade.
;
; ECARTS ASSUMES
; --------------
; V2-DEVIATION: le clignotement de touche de l'arcade echange la palette de
;   l'objet (0x6A78 + get_palette_id 0x55). La v2 n'a pas de palette par objet
;   sur ce stage : la touche ne se voit donc pas. Le compteur est tenu quand
;   meme pour que le portage du clignotement soit un branchement, pas une
;   reecriture.
; V2-DEVIATION: les PV arcade sont indexes par la difficulte (3/5/8/14). La v2
;   n'a pas de selecteur de difficulte : on prend la premiere valeur, comme le
;   reste du cast.
; ---------------------------------------------------------------------------

AABB_0   equ ext_variables      ; AABB struct (9 bytes)
blink    equ ext_variables+9    ; compteur de clignotement de touche (1)

Object
        lda   routine,u
        asla
        ldx   #Routines
        jmp   [a,x]

Routines
        fdb   Init
        fdb   Live
        fdb   AlreadyDeleted

Init
        ; --- la position : preset XY indexe par le quartet BAS du subtype
        ; 696e : load_xy_preset copie (x,y) depuis bug_and_pow_armor_preset_xy
        lda   subtype_w+1,u
        anda  #$0F
        asla                           ; deux octets par entree
        ldx   #PresetXYIndex
        leax  a,x
        clra
        ldb   ,x                       ; x du preset
        addd  glb_camera_x_pos
        addd  #144+8
        std   x_pos,u
        clra
        ldb   1,x                      ; y du preset
        addb  #3                       ; 69ae : +0x08 += 4 px arcade = 3 lignes
        adca  #0
        std   y_pos,u

        ; --- le preset de tir (f932 : seuils + vitesse, par difficulte)
        ldb   subtype_w+1,u
        _loadFirePreset

        ldb   #6                       ; display priority
        stb   priority,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u

        ; --- la boite de collision (arcade 0x2E36 : -12..+12 sur les deux axes)
        _Collision_AddAABB AABB_0,AABB_list_ennemy
        lda   #cytron_hitdamage
        sta   AABB_0+AABB.p,u
        _ldd  cytron_hitbox_x,cytron_hitbox_y
        std   AABB_0+AABB.rx,u
        clr   blink,u

        ; --- le script de mouvement : le quartet HAUT du subtype le choisit.
        ; f95c : BX = (CL & 0xF0) >> 2, soit SEIZE variantes de 4 octets — et
        ; non quatre comme l'annonce la plate.
        lda   subtype_w+1,u
        anda  #$F0
        lsra
        lsra
        ldx   #cytron.script.tbl
        leax  a,x
        ldd   ,x
        pshs  d
        lda   2,x                      ; l'octet de variante = octets par trame
        sta   anim_frame_duration,u
        puls  x
        jsr   moveByScript.initialize

        ; les trames sautees avant la creation de l'objet — la trainee se seme
        ; PENDANT ce rattrapage : le cytron a bel et bien parcouru ces trames
        ; en arcade, et sa gomme avec.
        ldd   #cytron.tick
        std   moveByScript.callback
        ldb   wave_frame_drop
        jsr   moveByScript.runByB

        inc   routine,u
        bra   >
Live
        ldd   #cytron.tick
        std   moveByScript.callback
        jsr   moveByScript.runByFrameDrop
!       lda   moveByScript.anim.end
        bne   cytron.dead                  ; 6a42 : script fini = decharge silencieuse
        jsr   tryFoeFire
        lda   AABB_0+AABB.p,u
        beq   cytron.blown
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u
        ldb   y_pos+1,u
        stb   AABB_0+AABB.cy,u

        ; --- LA REPOUSSE : elle n'est plus ici. Une gomme par TICK COMPENSE,
        ; semee par cytron.tick depuis la boucle de moveByScript (voir plus
        ; bas) — une par tour de jeu trouait la trainee des que le moteur
        ; perdait une trame.

        ; --- le sprite ------------------------------------------------------
        lda   blink,u                  ; V2-DEVIATION: le compteur est tenu, le
        beq   >                        ; clignotement ne se voit pas (pas de
        dec   blink,u                  ; palette par objet sur ce stage)
!       ldx   #ImageIndex
        ldb   anim_frame,u             ; la POSE vient du script
        andb  #$0F
        aslb
        ldd   b,x
        std   image_set,u
        jmp   DisplaySprite

cytron.blown
        ldb   #cytron_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        beq   cytron.dead
        _ldd  ObjID_explosion,explosion.subtype.smallx2
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
cytron.dead
        lda   #2
        sta   routine,u
        _Collision_RemoveAABB AABB_0,AABB_list_ennemy
        jmp   DeleteObject
AlreadyDeleted
        rts

; ---------------------------------------------------------------------------
; cytron.tick — LE TICK ARCADE, UN PAR TRAME COMPENSEE
;
; moveByScript appelle ce callback une fois par tour de sa boucle de
; rattrapage, position deja mise a jour et page de l'appelant remontee. C'est
; le seul endroit ou l'on voit les trames perdues une par une — et c'est donc
; la que la repousse doit vivre. Semee depuis Live, elle ne posait QU'UNE
; gomme par tour de jeu : un cytron qui rattrapait cinq trames avancait de
; cinq pas et n'en semait qu'une, d'ou une trainee en pointille dont le pas
; variait avec la charge (releve du 24/08/2026).
;
; L'ordre est celui du tick arcade : script fini -> l'objet se decharge sans
; rien semer (0x6A42), sinon il seme (69d9). growTrail finit en jmp sur le
; relais resident, dont le rts rend la main a la boucle.
; ---------------------------------------------------------------------------
cytron.tick
        lda   moveByScript.anim.end
        beq   growTrail
        clr   moveByScript.anim.loops  ; exit parent loop
        rts

; ---------------------------------------------------------------------------
; growTrail — semer une gomme dans l'axe de la pose
;
; 69d9..6a1d : la position, decalee du couple (dx,dy) de la pose, donne la
; cellule a sonder ; l'ecriture n'a lieu que si elle lit TILE_EMPTY. Le
; decalage est en px ARCADE : x0,375 en X et x0,75 en Y pour passer en unites
; v2 — soit, pour les seize valeurs de la table, un simple decalage puisque
; toutes valent 0, 4, 8, 10 ou 12.
; ---------------------------------------------------------------------------
growTrail
        ldb   anim_frame,u
        andb  #$0F
        aslb
        aslb                           ; 4 octets par pose
        ldx   #cytron.trail.tbl
        abx
        ldd   ,x                       ; dx, en px arcade (signe)
        _asrd                          ; x0,375 ~ x3/8 : (d + d + d) >> 3
        pshs  d
        ldd   ,x
        aslb
        rola
        addd  ,s++
        _asrd
        _asrd                          ; (3 * dx) / 8
        addd  x_pos,u
        subd  glb_camera_x_pos
        pshs  d                        ; x ecran de la cellule visee
        ldd   2,x                      ; dy
        pshs  d
        ldd   2,x
        aslb
        rola
        addd  ,s++
        _asrd
        _asrd                          ; (3 * dy) / 4 = x0,75
        addd  y_pos,u
        tfr   b,a                      ; la ligne ecran tient dans un octet
        puls  x                        ; x ecran
        tfr   a,b                      ; b = ligne ecran, x = x ecran
        jmp   pscroll.gum.grow         ; la regle « vide ET pas dur » est la-bas
                                       ; — le relais RESIDENT, jamais l'appel
                                       ; direct (page du cytron != page pscroll)

; V2-DEVIATION: la v1 nommait ses entrees d'imageset Img_<nom>, gfxcomp les
; genere en set_<nom>. Seize poses : ce sont les seize directions du cercle de
; repousse, et le script les pose lui-meme.
ImageIndex
        fdb   set_cytron_0
        fdb   set_cytron_1
        fdb   set_cytron_2
        fdb   set_cytron_3
        fdb   set_cytron_4
        fdb   set_cytron_5
        fdb   set_cytron_6
        fdb   set_cytron_7
        fdb   set_cytron_8
        fdb   set_cytron_9
        fdb   set_cytron_10
        fdb   set_cytron_11
        fdb   set_cytron_12
        fdb   set_cytron_13
        fdb   set_cytron_14
        fdb   set_cytron_15

PresetXYIndex ; 0x18dd0
        INCLUDE "src/common/lib/presets/18dd0_preset-xy.asm"

; les scripts de mouvement, exportes de la rom arcade
        INCLUDE "src/enemies/cytron/movescript.asm"
