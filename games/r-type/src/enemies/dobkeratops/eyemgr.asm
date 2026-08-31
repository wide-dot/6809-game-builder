; ===========================================================================
; eyemgr — le manager des quatre nerfs optiques du dobkeratops (chantier
; nerfs-overlay, 31/08/2026). Il REMPLACE les huit objets v1 (4 nerfs-hitbox
; qui devenaient effaceurs + leurs copies double-buffer, 4 elements d'oeil) :
; UN objet, quatre systemes.
;
; Modele : un systeme = des MORCEAUX unitaires (dataset images/eye-N/, cf.
; images/manifest.txt). Intact -> il se dessine en BANDES de 16 px (3 a 5
; appels) ; touche -> il s'efface en cessant de dessiner ses morceaux dans
; l'ordre de sa sequence (un tick par trame, transcription des tables
; EraserImages/ForegroundImages v1) ; fini -> plus rien. Les 45 effaceurs
; v1 qui REPEIGNAIENT par-dessus n'ont plus d'objet : en overlay, ne plus
; dessiner EST l'effacement.
;
; Dessin : le faux imageset EMImg porte la geometrie du canevas 80x180
; (celle de la face) — BuildSprites fait les tests fenetre, la parite et
; la conversion d'adresse, puis appelle le hook de la parite choisie avec l'ancre resolue
; dans glb_screen_location_2 ; toutes les images partagent le canevas, donc
; l'ancre. Chaque parite a SON unite (les deux jeux de bandes depassent
; 16 Ko ensemble) : D0 ici, D1 dans eyemgrodd — meme hook, incluse chacune
; avec sa table. Le hook trie ce qui se dessine ; il finit en queue d'appel sur
; main.eyemgr.drawPieces (RESIDENT), qui monte la page des morceaux — un
; jsr inter-page depuis la fenetre cartouche echangerait le code appelant.
; Meme patron que tailmgr (page_draw patche a l'Init, table adr_* locale).
;
; Collision : les 4 boites vivent dans une table RESIDENTE du stage
; (main.eyemgr.aabb) — les listes du moteur se parcourent toutes pages
; confondues. Liens mis a zero a l'Init, insertion a l'armement
; (NERV_VULNERABLE), retrait a la mort. Cf. le manager de tirs (mgr.asm).
;
; Couches : priorite 1 — les nerfs par-dessus tout, queue et monstre
; compris (decision auteur 31/08, l'ordre arcade). La v1 separait traits
; (8, sous le monstre) et elements d'oeil (1) ; le manager unifie a 1.
; ===========================================================================

EM_X    equ 1507                 ; l'ancre du corps (obj.asm Init) : toutes les
EM_Y    equ 100                  ;   images du chantier partagent son canevas
eyemgr.X equ EM_X                ; consomme par eyes-bands.tables.asm

rtnid.EMRun     equ 1
rtnid.EMDeleted equ 2            ; DeleteObject differe le retrait : rts

Object
        lda   routine,u
        beq   Init
        deca
        beq   Run
        rts                      ; EMDeleted

; ---------------------------------------------------------------------------
Init
        ; la page du manager dans les tables du moteur : Img_Page_Index pour
        ; que BuildSprites monte NOTRE page (faux imageset + bandes), et les
        ; deux cadres de dessin du descripteur
        _GetCartPageA
        ldb   id,u
        ldx   #Img_Page_Index
        sta   b,x
        sta   EMF0
        ; geometrie : l'ancre du corps
        ldd   #EM_X
        std   x_pos,u
        ldd   #EM_Y
        std   y_pos,u
        clr   anim_frame_duration,u    ; wave frame drop partage (idiome v1)
        ldd   subtype,u
        stb   priority,u
        ldd   #EMImg
        std   image_set,u
        lda   #render_playfieldcoord_mask|render_xloop_mask
        sta   render_flags,u
        ; etat resident : 4 systemes intacts, boites aux liens VIERGES
        ; (les tetes de liste sont a neuf : Collision_ClearLists a l'entree
        ; de stage — meme contrat que le manager de tirs)
        clr   EMarmed
        clra
        ldx   #main.eyemgr.status
        ldb   #8                       ; status[4] + removed[4] contigus
EMi1    sta   ,x+
        decb
        bne   EMi1
        ldx   #main.eyemgr.aabb
        ldb   #4*sizeof{AABB}
EMi2    sta   ,x+
        decb
        bne   EMi2
        lda   #4
        sta   main.eyemgr.eyesAlive
        ; purge d'un reliquat de checkpoint : le bloc resident du stage n'est
        ; pas recharge, un effacement interrompu laisserait le verrou arme et
        ; MonsterKill attendrait sans fin
        clr   main.dobkeratops.nervesErasing
        inc   routine,u
        jmp   DisplaySprite

; ---------------------------------------------------------------------------
Run
        lda   EMarmed
        bne   EMr1
        ; phase intro : nerfs visibles, invulnerables (arcade $280 apres T0)
        ldx   gfxlock.frame.gameCount
        cmpx  #timestamp.NERV_VULNERABLE
        blo   EMr2
        jsr   ArmAll
        bra   EMr2
EMr1    jsr   CheckKills
EMr2    jsr   StepSequences
        ; les quatre systemes finis (status 2 = %10 partout, and == 2) ->
        ; l'objet rend son slot. Marquage AVANT DeleteObject : le retrait est
        ; differe d'1-2 trames (meme idiome que DeleteEye v1).
        ldx   #main.eyemgr.status
        lda   ,x
        anda  1,x
        anda  2,x
        anda  3,x
        cmpa  #2
        bne   EMr3
        lda   #rtnid.EMDeleted
        sta   routine,u
        jmp   DeleteObject
EMr3    jmp   DisplaySprite

; ---------------------------------------------------------------------------
; ArmAll — NERV_VULNERABLE : pose les 4 boites (liste ennemy). La camera est
; a l'arret (DELETE_ALIEN_BODY la precede) : cx/cy se figent ici, la v1 les
; recalculait chaque trame pour rien.
ArmAll
        lda   #1
        sta   EMarmed
        ldy   #main.eyemgr.aabb
        ldx   #EMOffsets
        clr   EMsys
EMa1    ldd   x_pos,u
        subd  glb_camera_x_pos
        addd  ,x
        stb   AABB.cx,y
        ldd   y_pos,u
        subd  glb_camera_y_pos
        addd  2,x
        stb   AABB.cy,y
        lda   #dobkeratops_eye_hitdamage
        sta   AABB.p,y
        _ldd  dobkeratops_eye_hitbox_x,dobkeratops_eye_hitbox_y
        std   AABB.rx,y
        pshs  x,y
        tfr   y,x
        _Collision_AddAABB_x 0,AABB_list_ennemy
        puls  x,y
        leax  4,x
        leay  sizeof{AABB},y
        inc   EMsys
        lda   EMsys
        cmpa  #4
        blo   EMa1
        rts

; ---------------------------------------------------------------------------
; CheckKills — un systeme intact dont la boite tombe a p=0 est mort : par
; l'arme du joueur, ou de force (monstre mi-vie, boss vaincu, timeout
; free-life $900 — les trois chemins v1, meme traitement : score compris).
CheckKills
        ldb   main.dobkeratops.halfDamage
        bne   EMc1
        ldb   globals.bossDefeated
        bne   EMc1
        ldx   gfxlock.frame.gameCount
        cmpx  #timestamp.ERASE_NERV_START
        blo   EMc2
EMc1    jsr   ForceAll
EMc2    ldy   #main.eyemgr.aabb
        clr   EMsys
EMc3    ldb   EMsys
        ldx   #main.eyemgr.status
        lda   b,x
        bne   EMc4                     ; deja en effacement ou fini
        lda   AABB.p,y
        bne   EMc4
        jsr   Kill
EMc4    leay  sizeof{AABB},y
        inc   EMsys
        lda   EMsys
        cmpa  #4
        blo   EMc3
        rts

ForceAll
        ldy   #main.eyemgr.aabb
        ldx   #main.eyemgr.status
        ldb   #4
EMf1    lda   ,x+
        bne   EMf2
        clr   AABB.p,y
EMf2    leay  sizeof{AABB},y
        decb
        bne   EMf1
        rts

; ---------------------------------------------------------------------------
; Kill — le systeme EMsys (boite en Y) passe en effacement : boite retiree,
; sequence armee, verrou d'explosion pris, score et explosion — tout ce que
; l'arcade fait A L'IMPACT (run_dobkeratops_optical_nerves). Le compteur de
; nerfs vivants, lui, ne tombe qu'a la fin de la sequence (StepSequences),
; comme l'arcade au marqueur de fin de son script d'effacement.
Kill
        pshs  y
        tfr   y,x
        _Collision_RemoveAABB_x 0,AABB_list_ennemy
        ldb   EMsys
        ldx   #main.eyemgr.status
        lda   #1
        sta   b,x
        ldx   #main.eyemgr.removed
        clr   b,x
        aslb
        ldx   #ES_index
        ldx   b,x
        ldy   #EMseqPos
        stx   b,y
        inc   main.dobkeratops.nervesErasing
        ; PAS de decompte d'eyesAlive ici : l'arcade ne decremente son
        ; compteur de nerfs (+0x34) qu'au MARQUEUR DE FIN du script
        ; d'effacement (dobkeratops_erase_optical_nerves) — le scroll ne
        ; repart qu'une fois la derniere animation finie. Voir StepSequences.
        ldb   #dobkeratops_eye_scoreIdx
        jsr   AwardScore
        ; l'explosion a la position de l'oeil
        jsr   LoadObject_x
        beq   EMk2                     ; plus de slot libre
        _ldd  ObjID_explosion,explosion.subtype.smallx2
        std   id,x
        ldb   EMsys
        aslb
        aslb
        ldy   #EMOffsets
        leay  b,y
        ldd   x_pos,u
        addd  ,y
        std   x_pos,x
        ldd   y_pos,u
        addd  2,y
        std   y_pos,x
EMk2    puls  y,pc

; ---------------------------------------------------------------------------
; StepSequences — un tick d'effacement par trame et par systeme en cours :
; l'octet de sequence dit combien de morceaux partent ce tick (0-2, les
; trames vides des tables v1), $FF clot — le systeme est fini.
StepSequences
        clr   EMsys
EMs1    ldb   EMsys
        ldx   #main.eyemgr.status
        lda   b,x
        cmpa  #1
        bne   EMs3
        aslb
        ldx   #EMseqPos
        ldy   b,x
        lda   ,y+
        cmpa  #$FF
        beq   EMs2
        sty   b,x                      ; curseur avance
        ldb   EMsys
        ldx   #main.eyemgr.removed
        adda  b,x
        sta   b,x
        bra   EMs3
EMs2    ldb   EMsys                    ; sequence finie -> DEAD
        ldx   #main.eyemgr.status
        lda   #2
        sta   b,x
        dec   main.dobkeratops.nervesErasing
        ; l'arcade : DEC parent.nerves_alive au marqueur de fin du script
        ; d'effacement — le corps ne repart (allEyesDead -> moveAlienStart)
        ; qu'une fois le DERNIER effacement joue, pas au dernier impact
        dec   main.eyemgr.eyesAlive
        bne   EMs3
        jsr   main.dobkeratops.allEyesDead
EMs3    inc   EMsys
        ldb   EMsys
        cmpb  #4
        blo   EMs1
        rts

; ---------------------------------------------------------------------------
; Le faux imageset : geometrie du canevas partage (centre -1 comme la face,
; enveloppe des nerfs x1=-35/y1=-78, 73x157), quatre sous-ensembles miroir
; identiques, cadres D0/D1 -> les deux entrees du hook (la parite que
; BuildSprites a choisie est l'information a transmettre).
EMImg
        fcb   EMSub-EMImg,EMSub-EMImg,EMSub-EMImg,EMSub-EMImg
        fcb   73,157,$FF
EMSub
        fcb   0                        ; B0
        fcb   EMF0-EMSub               ; D0
        fcb   0                        ; B1
        fcb   EMF1-EMSub               ; D1
        fcb   -35,-78                  ; x1,y1
EMF0
        fcb   0                        ; page_draw (patchee a l'Init)
        fdb   EBDraw
EMF1
        ; la variante decalee vit dans sa propre unite (les deux parites de
        ; bandes depassent 16 Ko ensemble) : page et adresse par le lien
        fcb   map.RAM_OVER_CART+eyemgrD1.Draw$PAGE
        fdb   eyemgrD1.Draw

; ---------------------------------------------------------------------------
; les offsets des yeux (v1 AABBOffsets) : centre de boite et point
; d'explosion, relatifs a l'ancre du corps
EMOffsets
        fdb   -32,-60
        fdb     1,-12
        fdb     1,24
        fdb   -32,64

EMarmed  fcb 0
EMsys    fcb 0
EMseqPos fdb 0,0,0,0

; le hook de dessin (parite paire) et ses tables generees, puis les sequences
        INCLUDE "src/enemies/dobkeratops/eyebands-draw.asm"
        INCLUDE "src/enemies/dobkeratops/images/eyes-bands-nd0.tables.asm"
        INCLUDE "src/enemies/dobkeratops/images/eyes-seq.tables.asm"
