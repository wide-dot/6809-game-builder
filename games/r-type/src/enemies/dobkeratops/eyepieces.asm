; ===========================================================================
; eyepieces — le dessin des morceaux de nerf en cours d'effacement.
;
; Appele en QUEUE du hook de bandes d'eyemgr, via le trampoline resident
; main.eyemgr.drawPieces qui monte cette page : le rts final retourne
; directement a BuildSprites. U n'est pas un parametre — chaque routine
; compilee consomme l'ancre, on la recharge de glb_screen_location_2 (posee
; par BuildSprites pour l'objet manager, partagee par tout le canevas).
;
; Un systeme en effacement (status 1) dessine ses morceaux d'indice >=
; removed : les retires forment toujours un PREFIXE (la numerotation du
; dataset suit l'ordre de retrait, cf. images/manifest.txt). Pas de test
; fenetre : on n'efface qu'a la camera arretee, le boss est entier a l'ecran.
;
; Parite unique (decision auteur) : la camera s'arrete a une abscisse fixe,
; les morceaux n'existent qu'en ND0 — la parite paire de l'ancre a l'arret
; est verifiee par le banc. Cf. le plan d'encodage du manifest.
; ===========================================================================
eyepieces.DrawAll
        clr   EPsys
EPd1    ldb   EPsys
        ldx   #main.eyemgr.status
        lda   b,x
        cmpa  #1
        bne   EPd4
        ldx   #main.eyemgr.removed
        lda   b,x
        sta   EPidx
        aslb
        ldx   #EP_index
        ldx   b,x
        ldb   ,x+                      ; nb total de morceaux
        stb   EPcnt
        ldb   EPidx
        aslb
        abx                            ; x -> premier morceau encore dessine
EPd2    lda   EPidx
        cmpa  EPcnt
        bhs   EPd4
        ldy   ,x++
        ldu   <glb_screen_location_2
        pshs  x
        jsr   ,y
        puls  x
        inc   EPidx
        bra   EPd2
EPd4    inc   EPsys
        ldb   EPsys
        cmpb  #4
        blo   EPd1
        rts

EPsys   fcb 0
EPidx   fcb 0
EPcnt   fcb 0

; la table generee : par systeme, les routines des morceaux dans l'ordre
        INCLUDE "src/enemies/dobkeratops/images/eyes-pieces.tables.asm"
