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
        ldd   <glb_camera_x_pos
        subd  <glb_camera_x_offset
        subd  <glb_camera_x_offset
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
EBd2    ldd   ,x                       ; bord gauche playfield
        cmpd  EBxhi
        bge   EBd3
        ldd   2,x                      ; bord droit + 1
        cmpd  EBxlo
        blt   EBd3
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
