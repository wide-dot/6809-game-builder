; V2-DEVIATION: l'INCLUDE des macros est retire — elles ne servent qu'aux
; OBJETS qui appellent _loadFirePreset, et chaque unite d'ennemi les porte
; deja. Ici, dans le moteur resident, il n'y a rien qui les expanse.
;       INCLUDE "./global/projectile.macro.asm"

; -----------------------------------------------------------------------------
; tryFoeFire
; --------------
;
; -----------------------------------------------------------------------------
tryFoeFireShell
        clra                           ; no display delay
        ldx   #circleCenter
        stx   FoeFireTarget
        bra   tryFoeFireCommon
tryFoeFire ; 0xfa3a
        lda   #3
        ldx   #player1
        stx   FoeFireTarget
tryFoeFireCommon        
        sta   fireDisplayDelay,u
        ; L'HORLOGE DE TIR SANS BOUCLE (10/09/2026, decision auteur). La v1
        ; avancait le compteur TRAME PAR TRAME, une iteration de vingt cycles
        ; par trame ecoulee, a chaque tick de chaque tireur : 180 cycles par
        ; tourelle a neuf trames par rendu, un quart de son tick, quatorze
        ; tourelles au ventre du cuirasse (doc/profil-boucle-stage3-2026-09.md).
        ; Meme semantique en arithmetique : la premiere trame du tick ou le
        ; compteur ATTEINT le seuil tire, le compteur s'y arrete (les trames
        ; restantes du tick sont perdues, comme avant) ; sinon la premiere ou
        ; il atteint la remise a zero tire, compteur a zero ; sinon il avance
        ; du tick. Le seuil ne compte que s'il est devant le compteur : passe
        ; (ou nul), seule la remise a zero tire. Une quarantaine de cycles.
        ldd   fireCounter,u
        addd  gfxlock.frameDrop.count_w  ; le compteur au bout du tick, sans tir
        pshs  d
        ldb   fireThreshold,u
        clra                           ; D = le seuil
        cmpd  fireCounter,u
        bls   @noThr                   ; seuil deja passe, ou nul
        cmpd  ,s
        bhi   @noThr                   ; pas encore atteint dans ce tick
        leas  2,s
        bra   LAB_0000_fa50            ; D = le seuil : le compteur s'y arrete, et tire
@noThr  puls  d
        cmpd  fireReset,u
        bhs   LAB_0000_fa4b            ; la remise a zero est atteinte : tire a zero
        std   fireCounter,u
        rts
LAB_0000_fa4b
        ldd   #0
LAB_0000_fa50
        std   fireCounter,u
        ldb   fireVelocityPreset,u
        beq   >                        ; 0 in fireVelocityPreset means no fire
        lda   Obj_Index_Page+ObjID_createFoeFire
        sta   PSR_Page   
        ldd   Obj_Index_Address+2*ObjID_createFoeFire
        std   PSR_Address                  
        jmp   RunPgSubRoutine
!       rts

FoeFireTarget
        fdb   0
circleCenter equ *-x_pos
circleCenter.x_pos
        fdb   882 ; x_pos
        fcb   0   ; subpixel
circleCenter.y_pos
        fdb   101  ; y_pos