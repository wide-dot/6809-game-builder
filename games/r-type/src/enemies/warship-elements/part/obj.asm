;*******************************************************************************
; Les 27 SOUS-PARTIES de coque du vaisseau (stage 3)
;
; FICHE DE PORTAGE (base Ghidra `maincpu`, subsystem warship)
; -------------------------------------------------------------------------
;   40:c656..c78e  les 27 vignettes d'installation (recette + face)
;   40:c797 warship_part_install   40:c7c3 son tick
;   40:c83b sa mort  40:c846 la cascade d'explosions  40:c8d6/c8e8 l'epave
;   1000:7302.. les recettes      1000:77b8.. les boites
;
; ELLES N'ONT PAS DE SPRITE, et c'est ce qui les rend simples. La plate de
; c797 le dit sans detour : « The sub-part has NO per-frame sprite paint. Its
; visible presence on screen comes from the warship's BG tilemap. » Chez nous
; cette tilemap est la couche mscroll, deja peinte a chaque trame : une
; sous-partie n'est donc QU'UNE BOITE de collision qui la chevauche, avec ses
; 12 PV. Rien a dessiner, seulement a toucher.
;
; D'ou une consequence de conception : SANS retour visuel, le joueur ne saurait
; pas qu'il touche. L'arcade repond par une explosion cosmetique a chaque coup
; encaisse, tiree a un decalage aleatoire (c7c3) — ce n'est pas une decoration,
; c'est le SEUL retour de la piece. On la porte donc telle quelle.
;
; ECART v2 ASSUME, comme les tourelles : la position vit dans le repere de la
; COUCHE et l'ecran s'en deduit par `carte - camera`, la ou l'arcade pousse le
; delta de scroll a chaque trame. Doc : doc/warship-parts-plan.md
;
; ECART v2 ASSUME (2) : l'arcade ne teste la collision qu'UNE TRAME SUR DEUX
; (`global_counter & 1 XOR face`), pour amortir le cout de 27 pieces sondees a
; la main. Chez nous la boite est inscrite dans la liste et c'est le moteur de
; collision qui la confronte : il n'y a pas de sondage par objet a amortir, et
; alterner reviendrait a inscrire et retirer la boite une trame sur deux —
; plus cher, et moins juste. On teste donc a chaque trame.
;
; DIFFERE a la tranche 3 : l'EPAVE. La mort arcade blitte une grille de tuiles
; dans la tilemap de fond (c8e8, dimensions et contenu dans la queue de la
; recette). La couche v2 est un tampon de code compile ; la repeindre demande
; le meme outillage que l'edition du champ de gommes du stage 4. Ici la piece
; meurt en explosion et laisse la coque intacte.
;
; DIFFERE aussi : le signal de mort du parent (`parent.[+0x3e]`), qui fait
; mourir toutes les pieces avec le vaisseau — il viendra avec le coeur.
;*******************************************************************************
; -----------------------------------------------------------------------------
; L'ETAT
; -----------------------------------------------------------------------------
part.AABB       equ ext_variables      ; 0..8  la boite
part.mapX       equ ext_variables+9    ; 9,10  abscisse dans la COUCHE
; Meme precaution que les tourelles : la camera.y de la couche est REPLIEE,
; donc on garde l'ordonnee d'ECRAN a la naissance et la camera de ce moment,
; jamais une ordonnee absolue. Voir warship-elements/layer.asm.
part.y0         equ ext_variables+11   ; 11,12 ordonnee ECRAN a la naissance
part.cam0       equ ext_variables+13   ; 13,14 la camera.y de ce moment
part.cx         equ ext_variables+15   ; 15    excentrage du centre, signe
part.cy         equ ext_variables+16   ; 16
part.lastP      equ ext_variables+17   ; 17    dernier potentiel vu (le coup)

part.HP         equ 12                 ; 40:c797 MOV byte ptr [BP+0x2f],0xc

part.Object
        lda   routine,u
        asla
        ldx   #part.Routines
        jmp   [a,x]
part.Routines
        fdb   part.Init
        fdb   part.Live
        fdb   part.Deleted

; -----------------------------------------------------------------------------
; L'init : la position se fige dans le repere de la couche, la boite vient de
; la recette (sous-type = le rang de la piece, 0..26).
; -----------------------------------------------------------------------------
part.Init
        jsr   layer.evenX              ; le pas de la couche est de 2 px :
        std   part.mapX,u              ; meme arrondi qu'elle (layer.asm)
        ldd   x_pos,u
        subd  glb_camera_x_pos
        addd  part.mapX,u
        std   part.mapX,u
        ldd   y_pos,u
        std   part.y0,u
        ldd   mscroll.camera.y
        std   part.cam0,u

        lda   subtype,u
        asla
        asla                           ; quatre octets par entree
        ldx   #part.Boxes
        leax  a,x
        ldd   ,x                       ; A = rx, B = ry
        std   part.AABB+AABB.rx,u
        ldd   2,x                      ; A = cx, B = cy
        sta   part.cx,u
        stb   part.cy,u

        lda   #render_playfieldcoord_mask
        sta   render_flags,u
        ldb   #6
        stb   priority,u
        _Collision_AddAABB part.AABB,AABB_list_ennemy
        lda   #part.HP
        sta   part.AABB+AABB.p,u
        sta   part.lastP,u

        inc   routine,u
        ; PAS DE RTS : elle vit des sa premiere trame

; -----------------------------------------------------------------------------
part.Live
        lda   part.AABB+AABB.p,u
        lbeq  part.Boom                ; les 12 PV sont tombes

        ; --- la couche la porte ---------------------------------------------
        jsr   layer.evenX
        pshs  d
        ldd   part.mapX,u
        subd  ,s++
        addd  glb_camera_x_pos
        std   x_pos,u
        ldd   part.y0,u
        ldx   part.cam0,u
        jsr   layer.followY
        std   y_pos,u

        ; --- la fenetre ------------------------------------------------------
        ldd   x_pos,u
        subd  glb_camera_x_pos
        addb  part.cx,u
        stb   part.AABB+AABB.cx,u
        subb  part.cx,u
        cmpd  #layer.XGONE
        lbhi  part.Vanish
        ldd   y_pos,u
        addb  part.cy,u
        stb   part.AABB+AABB.cy,u
        subb  part.cy,u
        addd  #6
        cmpd  #204+6
        lbhi  part.Vanish

        ; --- LE SEUL RETOUR VISUEL : l'eclat au coup encaisse ----------------
        ; La piece n'a pas de sprite ; sans cette explosion le joueur tire dans
        ; la coque sans rien voir. L'arcade la tire a un decalage aleatoire de
        ; +-15 px arcade, soit +-5 chez nous (c7c3).
        lda   part.AABB+AABB.p,u
        cmpa  part.lastP,u
        beq   @rien
        sta   part.lastP,u
        jsr   LoadObject_x
        beq   @rien
        _ldd  ObjID_explosion,explosion.subtype.smallx2
        std   id,x
        jsr   RandomNumber
        andb  #7
        subb  #4                       ; -4..+3, l'ecart de l'arcade a l'echelle
        sex
        addd  x_pos,u
        std   x_pos,x
        jsr   RandomNumber
        andb  #7
        subb  #4
        sex
        addd  y_pos,u
        std   y_pos,x
@rien   rts                            ; rien a dessiner : la couche EST le corps

; -----------------------------------------------------------------------------
part.Boom
        ldb   #warship_subpart_scoreIdx
        jsr   AwardScore
        jsr   LoadObject_x
        beq   part.Vanish
        _ldd  ObjID_explosion,explosion.subtype.big.brown
        std   id,x
        ldd   x_pos,u
        std   x_pos,x
        ldd   y_pos,u
        std   y_pos,x
part.Vanish
        lda   #2
        sta   routine,u
        _Collision_RemoveAABB part.AABB,AABB_list_ennemy
        jmp   DeleteObject
part.Deleted
        rts

        INCLUDE "src/enemies/warship-elements/part/boxes.asm"
