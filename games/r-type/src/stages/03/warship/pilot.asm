; ---------------------------------------------------------------------------
; warship_core — le pilote de la couche battleship (stage 3)
;
; Portage du maitre du vaisseau arcade, reduit a son role de PILOTE de
; couche : l'arcade (create_warship 0xc46e, tick_warship_master 0xc4bc)
; confisque les deux axes de scroll de la couche background en poussant les
; consignes de son script interne (0x1000:6f8a) dans les registres globaux
; [0x2EF4]/[0x2EF8] a chaque trame, integres par auto_scroll (0x40:0467).
;
; ICI l'integration est reproduite A LA TRAME PRES (decision auteur,
; 20/08/2026) : le pilote depile les trames video ecoulees UNE PAR UNE —
; chaque trame porte la vitesse du segment auquel elle appartient — et
; pousse la somme exacte au module par mscroll.camera.impulse (les vitesses
; module restent a zero). Le mode vitesse (camera.speed x trames ecoulees)
; integrait tout un frame-drop a la vitesse de l'ancien segment quand une
; frontiere tombait au milieu : erreur bornee mais reelle, corrigee.
;
; Le script (warship/camera-script.asm, export re.arcade --extract-warship,
; unite stage3.camscript montee comme la wave) : des entrees de 5 octets
; [fdb speedx 8.8, fdb speedy 8.8, fcb trames], frames=0 = fin — la
; derniere entree porte (0,0).
;
; Instancie par la WAVE comme en arcade (t=$0100 = spawn ts $2000, priorite
; 0xff00 chez eux — ici l'ordre de la liste d'objets suffit, le pilote ne
; dessine rien). Avant lui, l'autoscroll du checkpoint ($0030, pose par
; stage.setup en mode vitesse) fait entrer le vaisseau ; pilotInit reprend
; la main en remettant les vitesses module a zero.
;
; NON PORTE (viendra avec le combat) :
;   - 0xc4bf/0xc4c9 : les jalons musique de boss (0x1180/0x12c0)
;   - 0xc61f warship_scrolling_spawner : le spawn des 27 parties et des
;     ennemis externes, a seuil sur mscroll.camera.x (phase 2)
;   - 0xc55d : le fade-out de fin de script -> stage 4 (ici : dormance)
; ---------------------------------------------------------------------------

; l'etat du pilote, dans l'espace libre de son OST
pilot.cursor   equ ext_variables   ; WORD position dans le script
pilot.counter  equ ext_variables+2 ; WORD trames restantes du segment courant
pilot.sx       equ ext_variables+4 ; WORD vitesse x du segment courant (8.8)
pilot.sy       equ ext_variables+6 ; WORD vitesse y du segment courant (8.8)

; L'origine d'authoring de level3_bc dans le repere de la couche : de combien
; la silhouette du .bin est decalee par rapport a la carte de tuiles du
; battleship. CALIBREES au banc d'overlay (rouge sur le vaisseau dessine).
warship.COLL_KX equ 0
warship.COLL_KY equ 0


warship.pilot
        lda   routine,u
        asla
        ldx   #Routines
        jmp   [a,x]

Routines
        fdb   pilotInit
        fdb   pilotLive
        fdb   pilotDone

pilotInit
        ldd   #warship.camera.script
        std   pilot.cursor,u
        ldd   #1                       ; premiere trame -> premier segment
        std   pilot.counter,u
        ldd   #0
        std   pilot.sx,u
        std   pilot.sy,u
        ; le pilote prend l'integration : vitesses module a zero (fin de
        ; l'autoscroll du checkpoint), il pousse desormais des deplacements
        std   mscroll.camera.speedx
        std   mscroll.camera.speed
        lda   #1
        sta   routine,u
        rts

pilotLive
        ; La silhouette de collision suit la couche : bases relues chaque
        ; trame — position d'apres le dernier move, une trame de retard,
        ; assume (decision auteur : le vaisseau est lent).
        ldd   mscroll.camera.x
        subd  #warship.COLL_KX
        std   terrainCollision.bgLayer.x
        ldd   mscroll.camera.y
        subd  #warship.COLL_KY
        std   terrainCollision.bgLayer.y
        ; ZERO TRAME ECOULEE : rien a depiler. La boucle de depilage est un
        ; do-while (decb/bne), donc un compteur nul y vaudrait 256 tours —
        ; un quart de minute de script avale d'un coup. mscroll.move se garde
        ; de la meme facon en tete de sa propre integration ; ici c'est aussi
        ; l'ordre d'appel qui est en jeu : stage.setup fait tourner RunObjects
        ; AVANT le premier gfxlock.loop, et frameDrop.count n'est pose par
        ; personne d'autre.
        tst   gfxlock.frameDrop.count
        bne   >
        rts
        ; la page du script, montee AVANT tout (le mount passe par A)
!       lda   #map.RAM_OVER_CART+stage3.camscript.page
        _SetCartPageA                  ; RunObjects remonte a l'objet suivant
        ; depiler les trames ecoulees une par une : le decompte de segment et
        ; l'accumulation partagent la meme trame, comme le tick arcade
        ldd   #0
        pshs  a,b                      ; 2,s : dy accumule (8.8)
        pshs  a,b                      ;  ,s : dx accumule (8.8)
        ldb   gfxlock.frameDrop.count  ; nb de trames video ecoulees (>=1, garde ci-dessus)
@frame  pshs  b                        ; le decompte survit aux ldd du tick
        ldx   pilot.counter,u          ; -- une trame video --
        leax  -1,x
        bne   @tick
        ; fin du segment : le suivant est effectif DES cette trame
        ldx   pilot.cursor,u
        ldy   ,x++
        sty   pilot.sx,u
        ldy   ,x++
        sty   pilot.sy,u
        ldb   ,x+
        beq   @end                     ; frames=0 : fin de script — la
                                       ; derniere entree vient de poser (0,0)
        stx   pilot.cursor,u
        clra
        tfr   d,x                      ; X = duree du segment neuf
@tick   stx   pilot.counter,u
        ldd   pilot.sx,u
        addd  1,s
        std   1,s
        ldd   pilot.sy,u
        addd  3,s
        std   3,s
        puls  b
        decb
        bne   @frame
        ; livrer le deplacement exact au module (applique au prochain move)
@done   puls  x                        ; X = dx
        puls  a,b                      ; D = dy
        jmp   mscroll.camera.impulse
;
@end    leas  1,s                      ; le decompte n'a plus d'objet : les
                                       ; trames restantes sont a (0,0)
        lda   #2                       ; le pilote passe en dormance : la
        sta   routine,u                ;   couche reste ou le script l'a laissee
        ; LA FIN DU SCRIPT EST LA FIN DU STAGE (arcade 0xc55d : le meme point
        ; d'entree sert la fin de script ET la mort du noyau, et il arme la
        ; sequence de fin de niveau).
        ; Ici il n'y a rien de plus a faire que lever le drapeau : l'objet de
        ; fin generique (common/flow/endlevel) le lit et arme tout le reste —
        ; decompte, jingle, autopilot, fondu pixel, releve de score, puis le
        ; statut DONE que stage.endTick convertit en stage.handOver vers le
        ; stage 4. C'est le geste que son propre commentaire attend d'un vrai
        ; boss (« it raises globals.bossDefeated itself and that alone arms
        ; the sequence »), et celui que le gomander du stage 2 fait deja.
        ; Sans lui, le stage ne finissait que par le combat de substitution :
        ; camera au bout de la carte, puis expiration d'un hold.
        lda   #1
        sta   globals.bossDefeated
        bra   @done
pilotDone
        rts
