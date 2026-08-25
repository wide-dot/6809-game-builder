;*******************************************************************************
; gouger — SQUELETTE, mais avec sa FICHE DE PORTAGE complete (releve 25/08/2026)
;
; L'ennemi DOMINANT du stage 2 : 29 des 34 spawns de cast. Il se tient sur le
; decor — plafond ou sol — puis plonge en diagonale vers l'intrus.
;
; FICHE DE PORTAGE (source : base Ghidra `maincpu`, subsystem enemy_gouger)
; -------------------------------------------------------------------------
;   40:6f89 create_gouger .............. le spawner
;   40:6fd0 run_gouger ................. le tick, machine a TROIS etats
;   40:7048 .... phase B, la plongee
;   40:7106 .... phase C, le recul apres un coup (0x17 = 23 trames)
;   40:70e3 .... la mort ; 40:7155 .... le retrait silencieux
;   40:7168 draw_gouger_with_hit_blink . le clignotement de coup
;   40:f9f0 load_gouger_preset ......... les quatre variantes
;   1000:9384 la table des variantes (4 x 7 mots)
;   1000:93bc la case +0x34 (4 mots)
;   1000:307e..30fe les quatre tables de poses (16 mots = 8 poses x2)
;   1000:31ee l'AABB
;
; CE QUE PORTE LE DESCRIPTEUR DE WAVE. Le 5e octet, et lui seul (le subtype
; vaut $00 sur les 29 lignes) :
;   bits 0-1 -> la VARIANTE de mouvement (load_gouger_preset, CL & 3) : d'ou il
;               part (plafond ou sol) et dans quel sens il file.
;   bits 2-3 -> le DECLENCHEUR, en +0x34 (load_motion_param_preset_4). Ses
;               quatre valeurs sont $FFFF, $0080, $0180, $0200 :
;                 $FFFF -> bit 15 arme : il plonge quand le joueur se presente
;                          dans la direction gravee en +0x36 ;
;                 sinon -> c'est un COMPTE A REBOURS en trames (128, 384, 512),
;                          decremente a chaque tour, et il plonge a zero sans
;                          se soucier du joueur.
; Les quatre variantes sont toutes employees par la wave.
;
; LES QUATRE VARIANTES, et elles tombent une a une sur nos dossiers d'images :
;
;   var  y      vx      vy     traine x  traine y  poses     images
;   ---  -----  ------  -----  --------  --------  --------  -------------
;    0   $0178  +1.500  -2.000   +0.375    -0.500  1000:30DE  top-LEFT
;    1   $0178  -1.500  -2.000   -0.375    -0.500  1000:30BE  top-RIGHT
;    2   $0098  +1.500  +2.000   +0.375    +0.500  1000:309E  bottom-LEFT
;    3   $0098  -1.500  +2.000   -0.375    +0.500  1000:307E  bottom-RIGHT
;
; ATTENTION AU NOM DES DOSSIERS : gauche et droite sont l'INVERSE de ce que le
; signe de vx laisse croire. La correspondance n'est pas deduite, elle est
; MESUREE — les fichiers sources portent l'adresse arcade de leur meta-sprite
; (000_013116.png…), et ces adresses sont exactement celles que la base de la
; variante enumere. Le nom decrit vraisemblablement le coin d'ou le gouger
; EMERGE, pas son sens de deplacement : au plafond, celui qui part vers la
; gauche arrive bien du coin haut-droit.
; Se fier au signe de vx aurait donne a chaque variante l'art d'une autre
; direction — silencieux au build, penible a l'ecran.
;
; L'axe Y arcade monte : $0178 (376) est donc le PLAFOND et $0098 (152) le
; SOL — les variantes 0 et 1 descendent (vy negatif), les 2 et 3 montent.
; X est fixe a $02D0, juste a droite de l'ecran.
;
; LES POSES. La table d'une variante fait seize mots, mais ce sont HUIT slots
; repetes deux fois — et le cycle fait un aller-retour :
;   30FE 312E 315E 318E 315E 312E 30FE 31BE   (var 3, les autres sont
;                                              identiques a l'adresse pres)
; L'index arcade vaut (anim & 0x3C) >> 1, soit un slot toutes les QUATRE
; trames ; ramene a nos images : slot = (anim >> 2) & 7. La plongee, elle,
; force l'offset 4 — donc le SLOT 2, fixe.
;
; MAIS CES HUIT SLOTS NE FONT PAS HUIT IMAGES. L'aller-retour repasse par les
; memes poses : n'en sont importees que les DISTINCTES
; (arcade_to_sprites.py --dedup, ecrit le 25/08/2026 pour ca). Chaque dossier
; porte sa table slot -> pose dans cycle.txt :
;
;   top-right     5 poses   0 1 2 3 2 1 0 4
;   top-left      5 poses   0 1 2 3 2 1 0 4
;   bottom-right  4 poses   0 1 2 3 2 1 0 3   <- sa 8e pose est identique a la 4e
;   bottom-left   5 poses   0 1 2 3 2 1 0 4
;
; 19 sprites au lieu de 32, soit 41 % de moins, sans rien perdre.
;
; LA POSE MANQUANTE DE bottom-right VIENT DE LA ROM, pas de l'export — verifie.
; Un descripteur fait 48 octets, soit QUATRE tranches de douze, une par
; variante (d'ou les ecarts de 0x0C entre 30FE, 310A, 3116, 3122). Pour la
; variante 3, les tranches des slots 3 et 7 sont identiques octet pour octet
; (tuiles 0x0524 et 0x0530 des deux cotes), alors que les tranches des trois
; autres variantes different bien (0x0530/0x0524 contre 0x0540/0x0534). La
; donnee d'origine repete cette pose pour cette direction-la, c'est tout. La table de
; bottom-right differe d'une entree : le code objet porte donc DEUX tables, pas
; une. Verification independante : les doublons attendus depuis la table arcade
; se retrouvaient exactement dans les images converties avant deduplication.
;
; Chaque pose est un META-SPRITE de DEUX sprites (write_2_sprites) : nos PNG
; 24x48 sont les deux tranches deja composees.
;
; LE FLASH DE COUP : une image blanche par orientation, quatre en tout
; (images/hit/00..03, dans l'ordre des variantes). C'est la POSE 2 qui est
; blanchie — celle que la plongee fige, donc la plus vue. Voir
; tools/gen_gouger_hit.py.
;
; LA MACHINE A TROIS ETATS
;
;   A — cache. Il defile avec la carte et attend son declencheur (voir plus
;       haut : direction du joueur, ou compte a rebours). Plafond ou sol ne se
;       lit PAS ici mais dans la variante — la plate Ghidra pretendait le
;       contraire, elle est corrigee.
;       Son dessin n'est pas une animation : l'index est reconstruit depuis la
;       base a chaque trame, donc rien ne s'accumule. Il montre la POSE 1, sauf
;       UNE trame sur 64 — quand (+0x34 & $3F) vaut zero — ou il montre la
;       POSE 2 : un sursaut d'une trame. Seules les variantes a compte a
;       rebours sursautent ; celle qui guette le joueur ne passe jamais par la.
;       La collision, la mort et le recul sont deja actifs dans cette phase.
;
;   B — la plongee. Chaque trame : x_pos += scroll_amount (verrou de defilement),
;       puis SONDE DU DECOR au centre.
;         . case VIDE  -> vitesse PRIMAIRE (+0x30/+0x32) et pose FIXE (2).
;         . case SOLIDE-> vitesse de TRAINEE (+0x38/+0x3A), animation, et le
;                         son 0x5F toutes les 0x20 trames.
;       ATTENTION : la plate Ghidra affirmait l'inverse. Le desassemblage est
;       sans ambiguite — `CMP AX,0xFA0 / JZ 0x7086`, et 0x7086 prend la vitesse
;       primaire. Or 0xFA0 est la case VIDE (seule case franchissable, cf. la
;       fiche de probe_foreground_tile) : le gouger RAMPE sur le decor en
;       s'animant, et PLONGE quand il n'y a plus rien sous lui. La plate est
;       corrigee dans la base.
;
;   C — le recul, 0x17 = 23 trames apres chaque coup encaisse. Il continue de
;       defiler et de s'animer, et clignote une trame sur quatre.
;
; PV = 10 (le spawner ecrase la table de difficulte par un $0A inconditionnel).
; Mort : son 0x53, score $86F8, puis grosse explosion gris-brun (40:e817).
; Retrait silencieux hors cadre, mais SEULEMENT si aucun coup n'a ete encaisse
; cette trame — le test de visibilite est dans cette branche-la.
;
; LA SONDE, cote v2. L'arcade lit l'index de tuile et le compare a 0xFA0 ;
; nous avons terrainCollision.do, qui rend B != 0 sur du solide :
;       ldd   <x>  / std terrainCollision.sensor.x
;       ldd   <y>  / std terrainCollision.sensor.y
;       ldb   #1   / jsr terrainCollision.do / tstb
; B = 0 vaut donc « case vide » et rend exactement le test arcade.
;
; CE QUI DEMANDERA UN ARBITRAGE
; - le clignotement de coup passe par un echange de palette d'objet ; la
;   palette TO8 est globale au stage. Meme choix que pour le serpent :
;   une image blanche, ou rien.
; - les sons (0x5F traine, 0x57 coup, 0x53 mort) : aucun ennemi de ce portage
;   n'a de son a ce jour.
; - 23 sprites de 24x48 a compiler (19 poses + 4 blanches), soit ~11,7 Ko a
;   l'estimation de 0,44 octet par pixel relevee sur le serpent. L'arene
;   stage2.foes n'occupe que trois de ses sept pages ; les sprites y prendront
;   leur propre entree de repertoire, le cast n'ayant pas la place.
; - PAS de variante decalee d'un pixel, vu la taille des sprites — meme choix
;   que pour l'outslay.
;*******************************************************************************

; -----------------------------------------------------------------------------
; L'ETAT, dans ext_variables (20 octets disponibles)
; -----------------------------------------------------------------------------
AABB_0          equ ext_variables      ; 0..8   la boite
gouger.var      equ ext_variables+9    ; 9      la variante, 0..3
gouger.trig     equ ext_variables+10   ; 10,11  le declencheur : $FFFF = guetter
                                       ;        le joueur, sinon compte a rebours
gouger.anim     equ ext_variables+12   ; 12,13  le compteur d'animation
gouger.recoil   equ ext_variables+14   ; 14     le compte a rebours du recul
gouger.prevP    equ ext_variables+15   ; 15     le potentiel du tour precedent
gouger.blink    equ ext_variables+16   ; 16     1 = blanc cette trame

gouger.RECOIL   equ 23                 ; 0x17 trames de jeu, comme l'arcade

gouger.Object
        lda   routine,u
        asla
        ldx   #gouger.Routines
        jmp   [a,x]
gouger.Routines
        fdb   gouger.Init
        fdb   gouger.Hidden            ; phase A
        fdb   gouger.Dive              ; phase B
        fdb   gouger.Recoil            ; phase C
        fdb   gouger.Deleted

; -----------------------------------------------------------------------------
gouger.Init
        ldb   subtype_w+1,u            ; le 5e octet du descripteur de wave
        pshs  b
        andb  #3                       ; bits 0-1 : la variante
        stb   gouger.var,u
        aslb
        ldx   #gouger.PresetY
        abx
        ldd   ,x
        std   y_pos,u
        ldd   glb_camera_x_pos
        addd  #144+10                  ; juste a droite du cadre
        std   x_pos,u
        clr   x_pos+2,u                ; la fraction repart nette
        clr   y_pos+2,u
        puls  b                        ; bits 2-3 : le declencheur
        lsrb
        lsrb
        andb  #3
        aslb
        ldx   #gouger.PresetTrig
        abx
        ldd   ,x
        std   gouger.trig,u
        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        _Collision_AddAABB AABB_0,AABB_list_ennemy
        lda   #gouger_hitdamage
        sta   AABB_0+AABB.p,u
        sta   gouger.prevP,u
        _ldd  gouger_hitbox_x,gouger_hitbox_y
        std   AABB_0+AABB.rx,u
        ldb   #6
        stb   priority,u
        ; L'IDENTIFIANT BASCULE ICI, et une seule fois. Les 23 sprites du
        ; gouger pesent plus de deux pages, donc chaque direction a son
        ; direntry — or Img_Page_Index ne donne qu'UNE page d'images par
        ; identifiant. La variante etant figee a la naissance, l'objet prend
        ; l'id de sa direction et n'en change plus. Meme motif que la tete et
        ; la queue du serpent.
        ldb   gouger.var,u
        ldx   #gouger.Ids
        abx
        lda   ,x
        sta   id,u
        ldd   #0
        std   gouger.anim,u
        clr   gouger.recoil,u
        clr   gouger.blink,u
        inc   routine,u
        rts

; -----------------------------------------------------------------------------
; PHASE A — cache. Il defile avec la carte (coordonnees playfield : la camera
; s'en charge, la ou l'arcade ajoute scroll_amount a la main) et attend son
; declencheur. Il est deja touchable.
; -----------------------------------------------------------------------------
gouger.Hidden
        jsr   gouger.Frame
        lbne  gouger.Gone
        ldd   gouger.trig,u
        bmi   @regard                  ; bit 15 arme : il guette le joueur
        subd  gouger.drop              ; sinon : un compte a rebours de JEU
        bhi   @attend
        ldd   #0
        std   gouger.trig,u
        bra   @plonge
@attend std   gouger.trig,u
        andb  #$3F                     ; le sursaut : une trame sur 64
        bne   @pose1
        ldb   #2
        bra   @dessine
@pose1  ldb   #1
        bra   @dessine
@regard ldb   gouger.var,u
        aslb
        ldx   #gouger.Compass
        abx
        ldd   ,x
        pshs  d                        ; la direction attendue
        ldx   #player1
        jsr   setDirectionTo           ; rend la direction dans Y
        tfr   y,d
        cmpd  ,s++
        beq   @plonge
        ldb   #1                       ; il guette : toujours la pose 1
        bra   @dessine
@plonge lda   #2
        sta   routine,u
        ldb   #1
@dessine
        jsr   gouger.Draw
        jmp   DisplaySprite

; -----------------------------------------------------------------------------
; PHASE B — la sonde de decor decide de tout : case VIDE il plonge a la vitesse
; primaire sur une pose fixe, case SOLIDE il rampe en s'animant.
; -----------------------------------------------------------------------------
gouger.Dive
        jsr   gouger.Frame
        lbne  gouger.Gone
        ldd   x_pos,u
        std   terrainCollision.sensor.x
        ldd   y_pos,u
        std   terrainCollision.sensor.y
        ldb   #1
        jsr   terrainCollision.do
        tstb
        bne   @rampe
        ldx   #gouger.VelPrim          ; case vide : la plongee
        jsr   gouger.Move
        ldb   #2                       ; la pose que l'arcade fige
        bra   @dessine
@rampe  ldx   #gouger.VelTrail         ; case solide : la reptation
        jsr   gouger.Move
        jsr   gouger.Anim
@dessine
        jsr   gouger.Draw
        jmp   DisplaySprite

; -----------------------------------------------------------------------------
; PHASE C — le recul, 23 trames de jeu apres un coup encaisse.
; -----------------------------------------------------------------------------
gouger.Recoil
        jsr   gouger.Frame
        lbne  gouger.Gone
        lda   gouger.recoil,u
        suba  gouger.drop+1
        bhi   @encore
        clra
        sta   gouger.recoil,u
        lda   #2                       ; fini : retour a la plongee
        sta   routine,u
        lda   AABB_0+AABB.p,u
        sta   gouger.prevP,u           ; ... en prenant acte du coup
        bra   @suite
@encore sta   gouger.recoil,u
@suite  jsr   gouger.Anim
        jsr   gouger.Draw
        jmp   DisplaySprite

; -----------------------------------------------------------------------------
; L'ouverture de trame, commune aux trois phases : le compte de trames de jeu,
; le verdict de mort, le coup encaisse, la boite et la sortie de cadre.
; Z = 0 s'il faut s'en aller.
; -----------------------------------------------------------------------------
gouger.Frame
        ldb   gfxlock.frameDrop.count
        bne   >
        incb                           ; miroir du garde de runByFrameDrop
!       clra
        std   gouger.drop
        lda   AABB_0+AABB.p,u
        beq   @mort
        cmpa  gouger.prevP,u           ; un coup depuis le tour precedent ?
        bhs   @cadre
        sta   gouger.prevP,u
        lda   #1
        sta   gouger.blink,u           ; une trame blanche
        lda   routine,u
        cmpa  #3
        beq   @cadre                   ; deja en recul : on ne le relance pas
        lda   #gouger.RECOIL
        sta   gouger.recoil,u
        lda   #3
        sta   routine,u
@cadre  ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u
        addd  #gouger_hitbox_x
        bmi   @part                    ; sorti par la gauche
        ldb   y_pos+1,u
        stb   AABB_0+AABB.cy,u
        andcc #$FB                     ; Z = 1 : il reste
        rts
@mort   ldb   #gouger_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        beq   @part
        _ldd  ObjID_explosion,explosion.subtype.big
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
@part   orcc  #$04                     ; Z = 0 : il s'en va
        rts

gouger.Gone
        lda   #4
        sta   routine,u
        _Collision_RemoveAABB AABB_0,AABB_list_ennemy
        jmp   DeleteObject
gouger.Deleted
        rts

; -----------------------------------------------------------------------------
; L'animation : une horloge de JEU. B rend le slot du cycle, 0..7.
; -----------------------------------------------------------------------------
gouger.Anim
        ldd   gouger.anim,u
        addd  gouger.drop
        std   gouger.anim,u
        lsrb                           ; une pose toutes les quatre trames
        lsrb
        andb  #7
        rts

; -----------------------------------------------------------------------------
; Le dessin : B = le SLOT du cycle. La table de la variante le ramene a une
; pose, puis la pose a un set. Une trame blanche l'emporte sur tout.
; -----------------------------------------------------------------------------
gouger.Draw
        lda   gouger.blink,u
        beq   @normal
        clr   gouger.blink,u           ; une seule trame
        ldb   gouger.var,u
        aslb
        ldx   #gouger.HitSets
        abx
        bra   @pose
@normal pshs  b
        ldb   gouger.var,u
        aslb
        ldx   #gouger.Cycles
        abx
        ldx   ,x                       ; X = la table slot -> pose
        puls  b
        ldb   b,x                      ; B = la pose
        aslb
        pshs  b
        ldb   gouger.var,u
        aslb
        ldx   #gouger.PoseSets
        abx
        ldx   ,x                       ; X = les poses de la variante
        puls  b
        abx
@pose   ldx   ,x
        stx   image_set,u
        rts

; -----------------------------------------------------------------------------
; Deplacer des deux vitesses 8.8 pointees par X, compensees du frame-drop.
; Le produit vitesse x n tient sur seize bits (384 x 8 = 3072) et le calcul
; tronque a seize bits est juste en complement a deux — meme raison que pour le
; vol libre du serpent, voir slither/obj.asm.
; -----------------------------------------------------------------------------
gouger.Move
        ldb   gouger.var,u
        aslb
        aslb                           ; quatre octets par variante
        abx
        pshs  x
        ldd   ,x
        leax  x_pos,u
        jsr   gouger.AddPos
        puls  x
        ldd   2,x
        leax  y_pos,u
; D = vitesse 8.8 signee, X = le champ position (haut, bas, fraction)
gouger.AddPos
        pshs  a                        ; l'octet haut de la vitesse
        lda   gouger.drop+1
        mul                            ; D = octet bas x n
        std   gouger.tmp
        puls  a
        ldb   gouger.drop+1
        mul                            ; D = octet haut x n
        tfr   b,a                      ; ... decale de huit bits
        clrb
        addd  gouger.tmp               ; le delta complet, tronque a 16 bits
        pshs  d
        ldb   ,s                       ; son octet haut : le signe
        sex
        sta   @a+1
        puls  d
        addd  1,x                      ; les deux octets bas de la position
        std   1,x
        lda   ,x
@a      adca  #$00
        sta   ,x
        rts

gouger.drop     fdb 0                  ; trames de jeu de ce tour
gouger.tmp      fdb 0

; -----------------------------------------------------------------------------
; LES TABLES. Tout vient du releve arcade — voir la fiche en tete de fichier.
; -----------------------------------------------------------------------------
; y = (396 - y_arcade) x 0.75, conversion deduite du preset commun 1930c et
; verifiee sur ses six valeurs. Le sprite fait 48 de haut et son ancre est au
; centre : le gouger deborde du cadre, il est a demi enterre dans le decor.
gouger.PresetY
        fdb   15  ; var 0, plafond ($0178)
        fdb   15  ; var 1, plafond
        fdb   183  ; var 2, sol ($0098)
        fdb   183  ; var 3, sol
; $FFFF = guetter le joueur ; sinon un compte a rebours en trames
gouger.PresetTrig
        fdb   $FFFF,128,384,512
; la direction attendue, gravee en +0x36 par le prereglage
gouger.Compass
        fdb   $0018,$0028,$0008,$0038
; vitesses a l'echelle du jeu (x 0.375 en x, x 0.75 en y). L'axe Y arcade
; MONTE, le notre descend : le signe de vy est donc inverse.
gouger.VelPrim
        fdb    144,384  ; var 0 : plafond, vers la droite
        fdb   -144,384  ; var 1 : plafond, vers la gauche
        fdb    144,-384  ; var 2 : sol, vers la droite
        fdb   -144,-384  ; var 3 : sol, vers la gauche
gouger.VelTrail
        fdb     36,96
        fdb    -36,96
        fdb     36,-96
        fdb    -36,-96
; le cycle slot -> pose, tel que --dedup l'a ecrit dans cycle.txt
gouger.CycA
        fcb   0,1,2,3,2,1,0,4
gouger.CycB
        fcb   0,1,2,3,2,1,0,3          ; bottom-right : sa 8e pose = la 4e
gouger.Cycles
        fdb   gouger.CycA  ; var 0, top-left
        fdb   gouger.CycA  ; var 1, top-right
        fdb   gouger.CycA  ; var 2, bottom-left
        fdb   gouger.CycB  ; var 3, bottom-right
gouger.PoseSets
        fdb   gouger.SetsTL,gouger.SetsTR,gouger.SetsBL,gouger.SetsBR
gouger.SetsTL
        fdb   set_gouger_tl_0,set_gouger_tl_1,set_gouger_tl_2
        fdb   set_gouger_tl_3,set_gouger_tl_4
gouger.SetsTR
        fdb   set_gouger_tr_0,set_gouger_tr_1,set_gouger_tr_2
        fdb   set_gouger_tr_3,set_gouger_tr_4
gouger.SetsBL
        fdb   set_gouger_bl_0,set_gouger_bl_1,set_gouger_bl_2
        fdb   set_gouger_bl_3,set_gouger_bl_4
gouger.SetsBR
        fdb   set_gouger_br_0,set_gouger_br_1,set_gouger_br_2
        fdb   set_gouger_br_3
gouger.HitSets
        fdb   set_gouger_hit_tl_0,set_gouger_hit_tr_0
        fdb   set_gouger_hit_bl_0,set_gouger_hit_br_0
; l'identifiant de chaque direction : c'est lui qui porte la page d'images
gouger.Ids
        fcb   ObjID_gouger_tl,ObjID_gouger_tr
        fcb   ObjID_gouger_bl,ObjID_gouger_br
