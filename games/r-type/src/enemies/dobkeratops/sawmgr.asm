; ===========================================================================
; sawmgr — la scie du Dobkeratops en MANAGER (02/09/2026, decision auteur).
; Conception : doc/analyse-saw-manager.md.
;
; La v1 (saw.asm) faisait UN objet OST par scie : une tete qui engendre un
; esclave tous les 4 pas pendant 32 pas, et chaque esclave rejoue la
; trajectoire de la tete avec 4*i pas de retard — meme vitesse, meme parabole
; decidee au 32e pas de SA vie. Neuf objets qui integrent neuf fois le meme
; chemin.
;
; Ici, UN objet maitre (un slot OST, spawne par la wave au boss comme le
; tailmgr) integre LA TETE seulement, une fois par pas, avec l'arithmetique v1
; a l'identique, et range sa position dans un ANNEAU. Le maillon i se lit a
; l'entree (age - 4*i) : zero calcul par maillon, et la chaine est sur le
; chemin de la tete par construction. Une seule chaine a la fois : le monstre
; tire tous les 128 pas et le trajet le plus long fait 113 pas (81 pour la
; tete depuis 1516, plus 32 pour le dernier maillon) — jamais deux en vol, ce
; que l'arcade montre aussi.
;
; Rotation : la tete avance d'une image par trame AFFICHEE, le maillon i montre
; l'image (tete + i) & 3 — chaque image de la chaine differe d'un cran de la
; precedente, quelle que soit la cadence.
;
; Dessin : BuildSprites appelle sm.DrawAll via le faux imageset (comme tirs et
; tailmgr) ; par maillon, _sprite.cull sur le VRAI descripteur de l'image puis
; la variante ND0/ND1 par parite — l'idiome des tirs.
;
; Collision comme v1 : une boite pour deux scies (les maillons impairs, la tete
; n'en portait pas), boite (3,6), scie intuable — un contact met le p de
; l'adversaire a zero. Balayage direct des listes player et friend, sans boite
; stockee (idiome tailmgr).
;
; Spawn : le monstre ecrit (x-6, y+9) et leve main.sawmgr.spawn (resident,
; stage1.sawmgr.res) ; le maitre consomme la demande dans son Run.
; ===========================================================================
SM_N      equ 9                      ; maillons : la tete + 8
SM_DECIDE equ 32                     ; pas avant la decision verticale (v1 anim_frame $20)
SM_RING   equ 64                     ; entrees d'anneau (puissance de 2 > 4*8)
SM_RMASK  equ SM_RING-1
SM_XVEL   equ -$0180                 ; 1,5 px a gauche par pas (v1 XVEL)

Object
        lda   routine,u
        beq   Init
        jmp   Run

; --- Init : au spawn du maitre ET au rejeu de checkpoint (l'etat de page n'est
; pas recharge) — tout a neuf, y compris une demande de spawn perimee.
Init
        clr   sm.killed
        clr   sm.alive
        clr   sm.img
        clr   main.sawmgr.spawn
        ldx   #sm.vis
        ldb   #SM_N
!       clr   ,x+
        decb
        bne   <
        _GetCartPageA
        ldb   id,u
        ldx   #Img_Page_Index
        sta   b,x                      ; notre page : c'est elle que le moteur monte
        sta   sm.FakeMf                ; page_draw du faux imageset
        ldd   #sm.FakeImg
        std   image_set,u
        lda   #128                     ; proxy gare au centre : toujours dans le
        sta   x_pixel,u                ; cadre, DrawAll appele a chaque rendu
        sta   y_pixel,u
        ldb   #5                       ; priorite de la scie v1
        stb   priority,u
        lda   #render_hide_mask        ; cache jusqu'au premier Run
        sta   render_flags,u
        inc   routine,u
        jmp   DisplaySprite

Run
        lda   sm.killed
        bne   @gone
        clr   render_flags,u           ; coordonnees ecran, visible
        ; --- la demande du monstre ---
        lda   main.sawmgr.spawn
        beq   @nospawn
        clr   main.sawmgr.spawn
        lda   sm.alive                 ; une chaine a la fois (arcade) : une demande
        bne   @nospawn                 ; pendant un vol serait ignoree — n'arrive
        jsr   Spawn                    ; pas (marge de 15 pas)
@nospawn
        lda   sm.alive
        beq   @idle
        ; --- les pas de la trame : la tete seule (v1 RunMaster : count 0 -> 1 pas) ---
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       pshs  b
        jsr   Step
        puls  b
        decb
        bne   <
        ; --- la rotation : une image par trame AFFICHEE ---
        inc   sm.img
        lda   sm.img
        anda  #3
        sta   sm.img
        jsr   Place                    ; naissance, vie, coords ecran, collisions
@idle
        lda   globals.bossDefeated     ; boss vaincu et plus rien en vol : le
        beq   >                        ; maitre rend son slot — par DeleteObject
        lda   sm.alive                 ; seulement (cf. tailmgr : un flag a la
        bne   >                        ; main fait fuir le slot)
        inc   sm.killed
        jmp   DeleteObject
!       jmp   DisplaySprite
@gone   rts

; --- Spawn : la chaine nait a l'origine demandee ; ring[0] = l'origine, c'est
; la que chaque maillon commence (v1 CreateSlave : x_pos_origin).
Spawn
        ldd   main.sawmgr.x
        std   sm.x
        clr   sm.x+2
        ldd   main.sawmgr.y
        std   sm.y
        clr   sm.y+2
        ldd   #0
        std   sm.age
        std   sm.yvel
        std   sm.ystep
        clr   sm.decided
        ldx   #sm.ring
        ldd   sm.x
        std   ,x
        ldd   sm.y
        std   2,x
        lda   #1
        sta   sm.alive
        rts

; --- Step : UN pas machine de la tete, arithmetique v1 a l'identique
; (SawMoveXLeft, puis SawMoveY une fois la decision prise : y += y_vel AVANT
; y_vel += step, signe teste sur l'ANCIEN y_vel). Puis age++, ecriture de
; l'anneau, et au 32e pas la decision verticale (CheckPlayerOnePos).
Step
        ldd   #SM_XVEL
        addd  sm.x+1
        std   sm.x+1
        bcs   >
        dec   sm.x
!       lda   sm.decided
        beq   @noy
        ldx   sm.ystep
        ldd   sm.yvel
        leax  d,x                      ; X = nouveau y_vel ; leax ne touche pas N
        tsta                           ; signe de l'ancien y_vel (v1 : bmi apres ldd)
        bmi   @neg
        addd  sm.y+1
        std   sm.y+1
        bcc   @ydone
        inc   sm.y
        bra   @ydone
@neg    addd  sm.y+1
        std   sm.y+1
        bcs   @ydone
        dec   sm.y
@ydone  stx   sm.yvel
@noy    ldd   sm.age
        addd  #1
        std   sm.age
        andb  #SM_RMASK
        lslb
        lslb                           ; entree * 4
        ldx   #sm.ring
        abx
        ldd   sm.x
        std   ,x
        ldd   sm.y
        std   2,x
        ldd   sm.age
        cmpd  #SM_DECIDE
        bne   @done
        ldx   <player1+y_pos           ; v1 : vitesse selon la hauteur du joueur
        cmpx  #102
        bls   @up
        cmpx  #115
        bls   @flat
        ldx   #12
        bra   @set
@up     ldx   #-12
        bra   @set
@flat   ldx   #0
@set    stx   sm.ystep
        inc   sm.decided
@done   rts

; --- Place : par maillon, ne ? vivant ? visible ? -> sm.vis / sm.pos, et la
; collision des maillons impairs. Un maillon est mort quand x + 8 <= camera
; (v1 RunCommon) ; les maillons meurent dans l'ordre, le dernier clot la
; chaine. Les gardes 16 bits rendent licite le repere ecran en 8 bits que
; _sprite.cull attend (la parabole sort par le bas de l'ecran).
Place
        clr   sm.i
@loop   ldb   sm.i
        lslb
        lslb
        clra
        std   sm.tmp                   ; 4*i
        ldd   sm.age
        subd  sm.tmp
        lbmi  @hide                    ; pas encore ne
        andb  #SM_RMASK
        lslb
        lslb
        ldx   #sm.ring
        abx                            ; X -> [x, y] du maillon
        ldd   ,x
        addd  #8
        cmpd  glb_camera_x_pos
        bhi   @live
        lda   sm.i                     ; mort : le dernier clot la chaine
        cmpa  #SM_N-1
        bne   @hide
        clr   sm.alive
        bra   @hide
@live   ldd   ,x
        subd  glb_camera_x_pos
        cmpd  #screen_right-screen_left
        bhi   @hide
        stb   sm.ccx                   ; cx collision (repere camera, sans +48)
        addb  #screen_left
        stb   sm.tx
        ldd   2,x
        subd  glb_camera_y_pos
        cmpd  #screen_height
        bhi   @hide
        stb   sm.ccy
        addb  #screen_top
        stb   sm.ty
        lda   sm.i
        ldb   #3
        mul
        ldx   #sm.pos
        leax  d,x
        lda   sm.tx
        sta   ,x
        lda   sm.ty
        sta   1,x
        lda   sm.img                   ; l'image : tete + i
        adda  sm.i
        anda  #3
        sta   2,x
        ldb   sm.i
        ldx   #sm.vis
        lda   #1
        sta   b,x
        lda   sm.i                     ; une boite pour deux : les impairs (v1)
        anda  #1
        beq   @next
        jsr   Collide
        bra   @next
@hide   ldb   sm.i
        ldx   #sm.vis
        clr   b,x
@next   inc   sm.i
        lda   sm.i
        cmpa  #SM_N
        lblo  @loop                    ; la boucle depasse 127 octets
        rts

; --- Collision : balayage des listes player et friend (idiome tailmgr), boite
; (dobkeratops_saw_hitbox_x, _y) centree sur sm.ccx/ccy ; la scie est intuable,
; un contact met le p de l'adversaire a zero (le joueur meurt, l'arme s'arrete).
Collide
        ldx   AABB_list_player
        beq   >
        bsr   ColScan
!       ldx   AABB_list_friend
        beq   >
        bsr   ColScan
!       rts
ColScan
@loop   ldb   AABB.p,x
        beq   @next                    ; boite desactivee
        bmi   @next                    ; intuable contre intuable : rien
        lda   #dobkeratops_saw_hitbox_x
        adda  AABB.rx,x
        asla
        sta   @rx
        asra
        adda  sm.ccx
        suba  AABB.cx,x
        cmpa  #0
@rx     equ *-1
        bhi   @next
        lda   #dobkeratops_saw_hitbox_y
        adda  AABB.ry,x
        asla
        sta   @ry
        asra
        adda  sm.ccy
        suba  AABB.cy,x
        cmpa  #0
@ry     equ *-1
        bhi   @next
        clr   AABB.p,x                 ; touche : l'adversaire perd
@next   ldx   AABB.next,x
        bne   @loop
        rts

; ===========================================================================
; sm.DrawAll — appele par BuildSprites via le faux imageset, notre page montee,
; sans OST sous la main. Par maillon visible : _sprite.cull sur le vrai
; descripteur, puis la variante par parite de x XOR le centre — l'idiome des
; tirs, a l'identique.
; ===========================================================================
sm.DrawAll
        clr   sm.i
@loop   ldb   sm.i
        ldx   #sm.vis
        tst   b,x
        beq   @next
        lda   sm.i
        ldb   #3
        mul
        ldx   #sm.pos
        leax  d,x                      ; X -> [x ecran, y ecran, img]
        ldb   2,x
        lslb
        ldy   #sm.Sets
        ldy   b,y                      ; Y = le descripteur de l'image
        ldd   ,x                       ; A = x ecran, B = y ecran
        tfr   y,x                      ; X = l'imageset (contrat de _sprite.cull)
        pshs  a,b
        _sprite.cull sm.DrawAll.off
        ldb   ,x                       ; le sous-ensemble sans miroir
        leay  b,x
        lda   ,s
        eora  imgset.center,x
        anda  #1
        asla
        ora   #1                       ; 1 = ND0, 3 = ND1
        ldb   a,y
        leay  b,y
        ldy   1,y                      ; la routine (la page est la notre)
        puls  a,b
        suba  imgset.center,x          ; le centre, comme le moteur
        jsr   DRS_XYToAddress
        ldu   <glb_screen_location_2
        jsr   ,y
        bra   @next
sm.DrawAll.off
        leas  2,s
@next   inc   sm.i
        lda   sm.i
        cmpa  #SM_N
        lblo  @loop                    ; la boucle depasse 127 octets
        rts

; --- les quatre images, dans l'ordre de rotation v1 (frame += 2 -> index + 1)
sm.Sets
        fdb   set_dobkeratops_saw_0,set_dobkeratops_saw_1
        fdb   set_dobkeratops_saw_2,set_dobkeratops_saw_3

; --- image-set fabrique : OVERLAY, parites {1,3} vers sm.DrawAll (cf. tirs)
sm.FakeImg
        fcb   sm.FakeSub-sm.FakeImg,sm.FakeSub-sm.FakeImg
        fcb   sm.FakeSub-sm.FakeImg,sm.FakeSub-sm.FakeImg
        fcb   8,8,0
sm.FakeSub
        fcb   0
        fcb   sm.FakeMf-sm.FakeSub
        fcb   0
        fcb   sm.FakeMf-sm.FakeSub
        fcb   0,0
sm.FakeMf
        fcb   0                        ; page, patchee a l'Init
        fdb   sm.DrawAll

; --- etat sur la page (Init remet a neuf ce qui doit l'etre) ----------------
sm.killed  fcb 0                     ; DeleteObject demande
sm.alive   fcb 0                     ; une chaine en vol
sm.decided fcb 0                     ; la parabole est decidee
sm.img     fcb 0                     ; image de la tete, 0..3
sm.i       fcb 0
sm.ccx     fcb 0                     ; collision : centre du maillon, repere camera
sm.ccy     fcb 0
sm.tx      fcb 0                     ; repere ecran
sm.ty      fcb 0
sm.tmp     fdb 0
sm.age     fdb 0                     ; pas depuis le spawn
sm.x       fcb 0,0,0                 ; tete, 16.8
sm.y       fcb 0,0,0
sm.yvel    fdb 0                     ; 8.8
sm.ystep   fdb 0                     ; -12, 0, +12
sm.vis     fill 0,SM_N               ; maillon dessine (1) ou non
sm.pos     fill 0,3*SM_N             ; [x ecran, y ecran, img] par maillon
sm.ring    fill 0,4*SM_RING          ; [x, y] de la tete, un par pas
