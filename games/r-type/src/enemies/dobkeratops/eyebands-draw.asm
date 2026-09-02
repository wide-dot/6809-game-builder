; ===========================================================================
; eyebands-draw — le hook de dessin des bandes de nerf, PARTAGE entre les
; deux unites de parite (eyemgr = ND0, eyemgrodd = ND1) : chacune l'inclut
; avec SA table EB_index, BuildSprites monte la page de la variante qu'il a
; choisie (cadres D0/D1 du descripteur EMImg) et appelle ce code.
;
; Entree : appele par BuildSprites, l'ancre du canevas resolue dans
; glb_screen_location_2 (partagee par toutes les images du chantier).
; Bandes des systemes INTACTS seulement, test de recouvrement du chemin
; xloop (bornes playfield precalculees par le generateur). Queue d'appel
; vers les morceaux (autre page) via le resident main.eyemgr.drawPieces —
; son rts retombe dans BuildSprites.
; ===========================================================================
EBDraw
        ; les bornes de la passe (celles que BuildSprites precalcule ; quatre
        ; lectures DP valent moins cher qu'un export moteur)
        ; Les bornes de la passe. EBxlo est la camera EXACTE : depuis le
        ; 02/09 la table declare la TRANCHE du decoupage et non le contenu,
        ; donc ses bornes sont celles que le blit ecrit vraiment — aucune
        ; marge n'est necessaire (voir gen_overlay_nerves.py).
        ldd   <glb_camera_x_pos
        std   EBxlo
        ldd   <glb_camera_x_pos
        addd  #160
        std   EBxhi
        clr   EBsys
EBd1    ldb   EBsys
        ldx   #main.eyemgr.status
        lda   b,x
        bne   EBd4                     ; en effacement ou fini : pas de bandes
        aslb
        ldx   #EB_index
        ldx   b,x
        lda   ,x+
        sta   EBcnt
EBd2    ; UNE BANDE N'APPARAIT QUE LORSQUE SA TRANCHE EST ENTIEREMENT
        ; ENTREE. Le test porte sur le DECOUPAGE THEORIQUE de 16 px, pas sur
        ; le contenu : la table declare la tranche depuis le 02/09, donc ses
        ; deux bornes sont celles que le blit ecrit vraiment.
        ;
        ; Les DEUX bords, et c'est la le point : tester le seul bord gauche
        ; faisait apparaitre la bande des qu'elle mordait l'ecran, et le blit
        ; compile n'ayant pas de decoupe, la part hors champ bouclait d'une
        ; ligne (xloop). Les bandes de face du boss n'ont pas ce defaut parce
        ; qu'elles ne traversent jamais la bordure : la wave les fait naitre
        ; une a une quand chacune est deja en place.
        ldd   ,x                       ; bord gauche de la tranche
        cmpd  EBxlo
        blt   EBd3                     ; pas encore entierement entree a gauche
        ldd   2,x                      ; bord droit + 1
        cmpd  EBxhi
        bgt   EBd3                     ; pas encore entierement entree a droite
        ldy   4,x
        ldu   <glb_screen_location_2
        pshs  x
        jsr   ,y
        puls  x
EBd3    leax  6,x
        dec   EBcnt
        bne   EBd2
EBd4    inc   EBsys
        ldb   EBsys
        cmpb  #4
        blo   EBd1
        jmp   main.eyemgr.drawPieces   ; page des morceaux -> rts vers BuildSprites

EBsys   fcb 0
EBcnt   fcb 0
EBxlo   fdb 0
EBxhi   fdb 0
