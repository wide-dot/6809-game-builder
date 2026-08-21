;*******************************************************************************
; L'ANIMATION DE DECOR COMME OBJET
;
; Un objet dont le seul travail est de faire vivre une animation de tilemap
; pendant une duree donnee, puis de se rendre. Il n'a ni sprite, ni boite, ni
; position : il empile des demandes (voir tilemap-patch.asm) et compte.
;
; Pourquoi un objet plutot qu'un etat dans celui qui le lance : parce que la
; duree de vie EST le probleme. Le gomander declenche l'animation d'un tube a
; dix-sept instants du combat, chacune vivant environ 272 trames, avec un
; recouvrement de deux au plus. Porter ca dans le boss demanderait un curseur,
; un decompte et un tube courant par animation simultanee ; l'instancier rend
; l'allocation, la duree de vie et la liberation a l'object manager, qui sait
; deja les faire.
;
; C'EST L'ARCADE. gomander_helper_spawn_orb_pellet (0x40:A5C5) cree lui aussi
; un objet par emission, avec une vie de 0x110 + (hasard & 3) trames, et c'est
; tick_gomander_orb_pellet_run (0x40:A638) qui repeint tant qu'il vit.
;
; LA POSE NE VIENT PAS D'UNE HORLOGE PROPRE : l'arcade la tire de
; (compteur global & 4), donc deux tubes animes en meme temps battent
; ensemble. On garde ca — l'objet ne retient que la derniere parite posee,
; pour n'empiler qu'au changement.
;
; A LA FIN, ON LAISSE LA DERNIERE POSE. L'arcade fait pareil : le pellet cesse
; de blitter et la tilemap garde ce qu'il y avait. Le decor ne revient a son
; etat d'origine qu'au retour de checkpoint (<tilereset>).
;*******************************************************************************

tanimobj.desc     equ ext_variables      ; 0,1  le descripteur a jouer
tanimobj.phase    equ ext_variables+2    ; 2    derniere parite posee
tanimobj.life     equ ext_variables+3    ; 3,4  duree restante, en trames video

tilemapanim.Object
        lda   routine,u
        asla
        ldx   #tilemapanim.Tab
        jmp   [a,x]
tilemapanim.Tab
        fdb   tilemapanim.Init
        fdb   tilemapanim.Live
        fdb   tilemapanim.Deleted

tilemapanim.Init
        ; Rien a dessiner : ni priorite, ni image, ni boite. Le createur a
        ; seme le descripteur et la duree.
        clr   priority,u
        lda   #-1                      ; parite impossible : la premiere trame
        sta   tanimobj.phase,u         ; pose la premiere image
        inc   routine,u

tilemapanim.Live
        ldd   tanimobj.life,u
        subb  gfxlock.frameDrop.count
        sbca  #0
        std   tanimobj.life,u
        ble   tilemapanim.Done
        ; la pose, sur l'horloge GLOBALE comme l'arcade
        lda   gfxlock.frame.count+1
        lsra
        lsra
        anda  #1
        cmpa  tanimobj.phase,u
        beq   @rts
        sta   tanimobj.phase,u
        tfr   a,b
        ldx   tanimobj.desc,u
        jsr   tilemap.request
@rts    rts

tilemapanim.Done
        inc   routine,u
        jmp   DeleteObject

tilemapanim.Deleted
        rts
