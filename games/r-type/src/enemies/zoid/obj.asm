;*******************************************************************************
; zoid — le parasite pondu par le brood, trois phases et DEUX ANCRAGES
;
; FICHE DE PORTAGE (base Ghidra `maincpu`, subsystem brood/zoid)
; -------------------------------------------------------------------------
;   40:8058 create_zoid ............ la ponte (implementee dans brood.Egg)
;   40:8d85 run_zoid_egg ........... l'oeuf, vole sur un script, suit le decor
;   40:8dc6 run_zoid_hatch ......... l'eclosion, 31 trames, immobile A L'ECRAN
;   40:8e15 run_zoid_parasite ...... le rodage, ancre ecran, vitesse 8.8
;   40:8efa zoid_retarget .......... le choix de cap (table de 16 ou joueur)
;   40:8ecc zoid_recoil_on_hit ..... le recul au coup encaisse
;   40:8e86 zoid_killed_by_player .. mort : score 0x86F8, explosion e7be
;   1000:3ee6 les seize destinations de rodage (positions d'ECRAN)
;   1000:3f6e la boite (+-10 x +-10 arcade -> rayons 4 et 8)
;
; L'OEUF. Ne a la position du parent (80c2/80c8), il vole sur une liste de
; segments moveByScript choisie par (orientation du brood, creneau de ponte)
; — six listes contigues a anim_zoid dans la LUT commune, TROIS commandes de
; script par trame (80be : MOV byte ptr [SI+0x17],0x3 — la plate Ghidra
; l'appelle « HP », c'est la vitesse d'interprete, le +0x17 de move_by_script).
; Il suit le decor (le tick applique 0x2ED0) : chez nous repere PLAYFIELD,
; c'est-a-dire AUCUN code — la logique d'ancrage est inversee entre les deux
; moteurs. Quatre poses tenues quatre trames, sur compteur libre.
; Il eclot a la FIN DU SCRIPT ou au PREMIER COUP encaisse (8dbb), le premier
; des deux ; le coup se lit sur AABB.p : toute entaille fait eclore.
;
; L'ECLOSION. 31 trames (+0x26 := $1F), pose = bits 3-4 du compte a rebours
; (elle descend 3,2,1,0). IMMOBILE A L'ECRAN : le tick 8dc6 n'applique PLUS
; 0x2ED0 — c'est ICI que l'ancrage bascule, pas a la fin de l'eclosion.
; x_pos/y_pos deviennent des accumulateurs 8.8 d'ecran (entier en octet
; haut), render_flags passe a zero. Invulnerable : le resultat de la
; collision est JETE (8dfa) — AABB.p est reposee a chaque trame, le contact
; blesse toujours le joueur. A la fin : 4 PV (8e08), verrou vierge, et
; +0x26 := 1 — il rode DES la trame suivante.
;
; LE RODAGE (8e15 + 8efa). Compte a rebours de 128 trames ; a l'echeance,
; nouveau cap : 75 % vers l'une des seize destinations d'ECRAN de 1000:3ee6,
; et une fois sur quatre un verrou s'arme pour que le PROCHAIN cap vise le
; joueur (verrou a un coup, il ne colle jamais). La vitesse est
; delta << 1 en 8.8 — soit delta/128 par trame : il ARRIVE quand le compte
; expire. La formule est invariante d'echelle, elle se recopie telle quelle
; en coordonnees v2. Quatre poses tenues huit trames.
;
; LE RECUL (8ecc). vx := 0 dans les deux cas. Le seuil arcade y >= 0xB0
; (v2 : y <= 165, l'axe arcade monte — les presets du brood le prouvent,
; plafond 368 -> 21) : repousse vers le BAS de 3 px arcade/trame (v2 +2,25,
; $0240), pose FIGEE (+0x38), fenetre (y_arc - 0xB0)/2 + 1 trames — en v2
; (165 - y) x 2/3 + 1, approchee par x171/256. Sous le seuil (pres du sol) :
; pas de recul, cap recalcule a la trame suivante. La plate Ghidra lit ce
; recul avec l'axe inverse (« knock upward ») ; les octets et les presets
; tranchent, le geste repousse vers le bas, loin du plafond.
;
; CONVERSIONS. Destinations et seuils par la formule de la table :
; x = (x_arc - 320) x 0,375 + 8, y = 297 - 0,75 x y_arc, repere ecran 0-base
; (l'octet x_pixel/y_pixel recoit +screen_left/+screen_top au dessin).
; FIX #1 : la destination 2 (352,144) convertit en y = 189, dont le bas de
; sprite (189+11) depasse la ligne 199 et ferait rejeter le dessin en bloc —
; ecretee a 188, un demi-pixel arcade.
;
; ABANDONNE (meme arbitrage que le brood) : les sons (0x5D ponte, 0x57 coup,
; 0x52 mort), le clignotement de coup par palette d'objet (0x55), et
; l'escalade de PV du second loop (8e08 : 70 PV si [0x2F2D] — pas de second
; loop chez nous).
;*******************************************************************************
; -----------------------------------------------------------------------------
; L'ETAT : dans zoid.equ — la ponte du brood, dans l'AUTRE unite, seme deux
; graines dans ces champs.
; -----------------------------------------------------------------------------
zoid.RECOILY    equ 165                ; arcade $B0 : la frontiere du recul
zoid.RECOILVY   equ $0240              ; arcade -3 px/trame -> v2 +2,25 vers le bas

zoid.Object
        lda   routine,u
        asla
        ldx   #zoid.Routines
        jmp   [a,x]
zoid.Routines
        fdb   zoid.Init
        fdb   zoid.Egg
        fdb   zoid.HatchTick
        fdb   zoid.Parasite
        fdb   zoid.Deleted

; -----------------------------------------------------------------------------
; 0) l'init : le script, la boite, et le rattrapage du retard de naissance.
; La ponte a laisse l'index de script dans zoid.count et le retard dans
; zoid.anim — lus AVANT de les recycler en compteur de phase et de pose.
; -----------------------------------------------------------------------------
zoid.Init
        ldb   zoid.count,u
        clra
        tfr   d,x
        jsr   moveByScript.initialize
        lda   #3                       ; 80be MOV byte ptr [SI+0x17],0x3
        sta   anim_frame_duration,u    ; trois commandes de script par trame
        lda   #render_playfieldcoord_mask
        sta   render_flags,u           ; l'oeuf suit le decor : repere monde
        ldb   #6
        stb   priority,u
        _Collision_AddAABB zoid.AABB,AABB_list_ennemy
        lda   #zoid_hitdamage
        sta   zoid.AABB+AABB.p,u
        _ldd  zoid_hitbox_x,zoid_hitbox_y
        std   zoid.AABB+AABB.rx,u
        clr   zoid.lock,u
        clr   zoid.freeze,u
        lda   #1
        sta   routine,u
        ; le rattrapage : chaque oeuf d'une meme gueule rejoue SES trames
        ; perdues, comme les wicks d'une rafale — zoid.anim les porte deja
        ; en tant qu'accumulateur de pose, zero est legitime.
        ldb   zoid.anim,u
        beq   zoid.EggShow             ; ne a l'heure : il se pose la
        ldx   #zoid.EggCB
        stx   moveByScript.callback
        jsr   moveByScript.runByB
        lda   moveByScript.anim.end
        bne   zoid.HatchInstall        ; un script si court n'existe pas, mais
        bra   zoid.EggShow             ; le chemin reste ferme proprement

; -----------------------------------------------------------------------------
; 1) l'oeuf : le vol par script, dans le monde.
; -----------------------------------------------------------------------------
zoid.Egg
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   zoid.drop
        ; touche ? toute entaille fait eclore avant l'heure (8dbb, voie CY
        ; de la collision)
        lda   zoid.AABB+AABB.p,u
        cmpa  #zoid_hitdamage
        bne   zoid.HatchInstall
        ; le script, compense du frame-drop
        ldx   #zoid.EggCB
        stx   moveByScript.callback
        jsr   moveByScript.runByFrameDrop
        lda   moveByScript.anim.end
        bne   zoid.HatchInstall        ; fin du script : il eclot (8dbb)
        lda   zoid.anim,u
        adda  zoid.drop+1
        sta   zoid.anim,u
zoid.EggShow
        ; la fenetre, comme le gouger : sorti du cadre = retrait silencieux
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   zoid.AABB+AABB.cx,u
        cmpd  #159
        lbhi  zoid.Vanish
        ldd   y_pos,u
        stb   zoid.AABB+AABB.cy,u
        addd  #6
        cmpd  #204+6
        lbhi  zoid.Vanish
        ; quatre poses tenues quatre trames (8d95 : >> 2)
        lda   zoid.anim,u
        lsra
        lsra
        anda  #3
        asla
        ldx   #zoid.EggSets
        ldx   a,x
        stx   image_set,u
        jmp   DisplaySprite

; Le callback de l'interprete : couper la boucle de rattrapage a la fin du
; script, sinon il lit au-dela — meme geste que le cadavre du slither.
zoid.EggCB
        lda   moveByScript.anim.end
        beq   >
        clr   moveByScript.anim.loops
!       rts

; -----------------------------------------------------------------------------
; La bascule d'ancrage : le tick 8dc6 n'applique plus le defilement, l'oeuf
; qui eclot se FIGE A L'ECRAN. x_pos/y_pos deviennent des accumulateurs 8.8
; d'ecran 0-base (entier en octet haut).
; -----------------------------------------------------------------------------
zoid.HatchInstall
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   x_pos,u
        clr   x_pos+1,u
        lda   y_pos+1,u
        sta   y_pos,u
        clr   y_pos+1,u
        clr   render_flags,u           ; coordonnees ECRAN
        lda   #$1F                     ; 8dbb : +0x26 := 31 trames d'eclosion
        sta   zoid.count,u
        lda   #2
        sta   routine,u
        ; il se dessine des cette trame, pose 3 (compteur haut)
        bra   zoid.HatchBody

; -----------------------------------------------------------------------------
; 2) l'eclosion : 31 trames immobiles, invulnerable.
; -----------------------------------------------------------------------------
zoid.HatchTick
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   zoid.drop
zoid.HatchBody
        ; le resultat de la collision est JETE (8dfa) — la boite reste armee,
        ; le contact blesse, mais les degats encaisses s'effacent
        lda   #zoid_hitdamage
        sta   zoid.AABB+AABB.p,u
        lda   zoid.count,u
        suba  zoid.drop+1
        bhi   @tick
        ; l'eclosion s'acheve (8e04..8e11) : 4 PV, verrou vierge, rodage
        ; des la prochaine trame
        lda   #zoid_hitdamage
        sta   zoid.lastP,u
        clr   zoid.lock,u
        clr   zoid.freeze,u
        clr   zoid.blink,u
        lda   #1
        sta   zoid.count,u
        lda   #3
        sta   routine,u
        clra                           ; la derniere pose, index 0
        bra   @pose
@tick   sta   zoid.count,u
        ; pose = bits 3-4 du compte a rebours : elle descend 3,2,1,0 (8dd1)
        lsra
        lsra
        lsra
        anda  #3
@pose   asla
        ldx   #zoid.HatchSets
        ldx   a,x
        stx   image_set,u
        lbra  zoid.ShowScreen

; -----------------------------------------------------------------------------
; 3) le parasite : le rodage a l'ecran.
; -----------------------------------------------------------------------------
zoid.Parasite
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       clra
        std   zoid.drop
        lda   zoid.AABB+AABB.p,u
        lbeq  zoid.Boom
        ; touche ? (8e6a : recul — sans son ni clignotement chez nous)
        cmpa  zoid.lastP,u
        beq   @timer
        sta   zoid.lastP,u
        ldb   #12                      ; 8e6f : +0x3d := 12, trois eclats a 25 %
        stb   zoid.blink,u
        lbsr  zoid.Recoil
        bra   @move
@timer  ; le compte a rebours de cap (8e15 : DEC, a zero -> retarget)
        lda   zoid.count,u
        suba  zoid.drop+1
        bhi   @run
        lbsr  zoid.Retarget
        bra   @move
@run    sta   zoid.count,u
@move   ; les vitesses 8.8, compensees, sur les accumulateurs d'ecran —
        ; les deux mul non signes, produit tronque juste en complement a deux
        lda   x_vel+1,u
        ldb   zoid.drop+1
        mul
        addd  x_pos,u
        std   x_pos,u
        lda   x_vel,u
        ldb   zoid.drop+1
        mul
        addb  x_pos,u
        stb   x_pos,u
        lda   y_vel+1,u
        ldb   zoid.drop+1
        mul
        addd  y_pos,u
        std   y_pos,u
        lda   y_vel,u
        ldb   zoid.drop+1
        mul
        addb  y_pos,u
        stb   y_pos,u
        ; l'ecran ne se quitte pas : l'accumulateur est borne au cadre, la
        ; vitesse continue de pousser et le prochain cap ramene au centre
        ; (le recul peut projeter loin sous 199 — l'arcade laisse couler,
        ; notre octet d'ecran ne le peut pas)
        lda   x_vel,u
        bmi   @xneg
        lda   x_pos,u
        cmpa  #159
        bls   @x
        lda   #159
        sta   x_pos,u
        bra   @x
@xneg   lda   x_pos,u
        cmpa  #160
        blo   @x
        clr   x_pos,u
@x      lda   y_vel,u
        bmi   @yneg
        lda   y_pos,u
        cmpa  #188
        bls   @y
        lda   #188
        sta   y_pos,u
        bra   @y
@yneg   lda   y_pos,u
        cmpa  #189
        blo   @y
        clr   y_pos,u
@y      ; quatre poses tenues huit trames — figees a la 0 pendant le recul
        lda   zoid.freeze,u
        bne   @pose0
        lda   zoid.anim,u
        adda  zoid.drop+1
        sta   zoid.anim,u
        lsra
        lsra
        lsra
        anda  #3
        asla
        bra   @eclat
@pose0  clra
@eclat  ; l'eclat blanc : compteur decremente puis teste, un sur quatre (8ea9).
        ; UNE seule blanche (decision auteur : les quatre poses de rodage sont
        ; trop proches pour qu'un eclat d'une trame montre la difference) —
        ; elle vit dans SA page, portee par l'identifiant (Img_Page_Index).
        ldb   zoid.blink,u
        beq   @norm
        subb  zoid.drop+1
        bgt   >
        clrb
!       stb   zoid.blink,u
        andb  #3
        bne   @norm
        ldx   #set_zoid_hit_0
        lda   #ObjID_zoid_hit
        bra   @set
@norm   ldx   #zoid.Sets
        ldx   a,x
        lda   #ObjID_zoid
@set    sta   id,u
        stx   image_set,u
        ; retombe dans le dessin ecran

; -----------------------------------------------------------------------------
; Le dessin en repere ecran : la boite en 0-base, les octets x/y_pixel
; decales du cadre.
; -----------------------------------------------------------------------------
zoid.ShowScreen
        lda   x_pos,u
        sta   zoid.AABB+AABB.cx,u
        adda  #screen_left
        sta   x_pixel,u
        lda   y_pos,u
        sta   zoid.AABB+AABB.cy,u
        adda  #screen_top
        sta   y_pixel,u
        jmp   DisplaySprite

; -----------------------------------------------------------------------------
; Le choix de cap (8efa). D'abord le verrou : arme, il vise le joueur et se
; consomme. Sinon une destination au hasard parmi seize, et une fois sur
; quatre le verrou s'arme pour le cap SUIVANT.
; -----------------------------------------------------------------------------
zoid.Retarget
        clr   zoid.freeze,u            ; 8efa : le fige se libere ici
        lda   zoid.lock,u
        beq   @table
        clr   zoid.lock,u              ; 8f29 : verrou a un coup
        ldb   player1+y_pos+1
        pshs  b                        ; ty
        ldd   player1+x_pos
        subd  glb_camera_x_pos         ; le joueur vit dans le monde
        pshs  b                        ; tx, ecran 0-base, dessus
        bra   @aim
@table  jsr   RandomNumber
        andb  #$0F                     ; 8f3f : idx = rand & 15
        cmpb  #4
        bhs   >
        inc   zoid.lock,u              ; 25 % : le PROCHAIN cap vise le joueur
!       aslb
        ldx   #zoid.Prowl
        abx
        ldd   ,x                       ; A = tx, B = ty
        pshs  d                        ; tx dessus (,s), ty dessous (1,s)
@aim    ; vx = (tx - x) << 1 en 8.8 : il arrive quand les 128 trames expirent
        clra
        ldb   x_pos,u
        std   zoid.tmp
        clra
        ldb   ,s                       ; tx
        subd  zoid.tmp
        aslb
        rola
        std   x_vel,u
        clra
        ldb   y_pos,u
        std   zoid.tmp
        clra
        ldb   1,s                      ; ty
        subd  zoid.tmp
        aslb
        rola
        std   y_vel,u
        leas  2,s
        lda   #128                     ; 8f26 : +0x26 := $80
        sta   zoid.count,u
        rts

; -----------------------------------------------------------------------------
; Le recul au coup (8ecc). vx := 0 dans les deux branches ; au-dessus de la
; frontiere il est repousse vers le bas, pose figee, fenetre proportionnelle
; a la hauteur ; pres du sol, pas de recul et cap immediat.
; -----------------------------------------------------------------------------
zoid.Recoil
        ldd   #0
        std   x_vel,u
        lda   y_pos,u
        cmpa  #zoid.RECOILY
        bhi   @floor
        ldd   #zoid.RECOILVY
        std   y_vel,u
        lda   #1
        sta   zoid.freeze,u            ; 8ee6 : +0x38 := 1, pose figee
        ; fenetre = (165 - y) x 2/3 + 1 — le x2/3 approche par x171/256
        lda   #zoid.RECOILY
        suba  y_pos,u
        ldb   #171
        mul
        inca
        sta   zoid.count,u
        rts
@floor  ldd   #0
        std   y_vel,u                  ; pas de recul contre le sol
        lda   #1
        sta   zoid.count,u             ; 8ef3 : cap recalcule a la trame suivante
        rts

; -----------------------------------------------------------------------------
; La mort (8e86) : score, deux petites explosions (e7be), retrait. Les
; coordonnees d'ecran repassent dans le monde pour l'explosion.
; -----------------------------------------------------------------------------
zoid.Boom
        ldb   #zoid_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        beq   zoid.Vanish
        _ldd  ObjID_explosion,explosion.subtype.smallx2+explosion.sfx.turret
        std   id,x
        ldb   x_pos,u
        clra
        addd  glb_camera_x_pos
        std   x_pos,x
        ldb   y_pos,u
        clra
        std   y_pos,x
zoid.Vanish
        lda   #4
        sta   routine,u
        _Collision_RemoveAABB zoid.AABB,AABB_list_ennemy
        jmp   DeleteObject
zoid.Deleted
        rts

zoid.drop       fdb 0
zoid.tmp        fdb 0

; Les seize destinations de rodage (1000:3ee6), converties une a une par la
; formule de la table, en repere ecran 0-base. Quatre y figurent deux fois,
; comme dans la ROM. FIX #1 : la deuxieme, y 189 -> 188.
zoid.Prowl
        fcb   20,69                    ; ($0160,$0130)
        fcb   20,188                   ; ($0160,$0090) — ecretee, voir FIX #1
        fcb   131,45                   ; ($0288,$0150)
        fcb   125,171                  ; ($0278,$00A8)
        fcb   26,141                   ; ($0170,$00D0)
        fcb   47,159                   ; ($01A8,$00B8)
        fcb   38,117                   ; ($0190,$00F0)
        fcb   26,141                   ; ($0170,$00D0)
        fcb   47,51                    ; ($01A8,$0148)
        fcb   80,99                    ; ($0200,$0108)
        fcb   140,123                  ; ($02A0,$00E8)
        fcb   47,51                    ; ($01A8,$0148)
        fcb   107,147                  ; ($0248,$00C8)
        fcb   107,63                   ; ($0248,$0138)
        fcb   122,81                   ; ($0270,$0120)
        fcb   140,123                  ; ($02A0,$00E8)

zoid.EggSets
        fdb   set_zoid_egg_0,set_zoid_egg_1,set_zoid_egg_2,set_zoid_egg_3
zoid.HatchSets
        fdb   set_zoid_hatch_0,set_zoid_hatch_1,set_zoid_hatch_2,set_zoid_hatch_3
zoid.Sets
        fdb   set_zoid_0,set_zoid_1,set_zoid_2,set_zoid_3
