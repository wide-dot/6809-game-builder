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


 IFDEF WARSHIP_LOG_PAGE
; ---------------------------------------------------------------------------
; wlog — le journal de bord du pilote  (INSTRUMENTATION, a retirer avec le
; define WARSHIP_LOG_PAGE du to8.config.xml et la zone d'arene rendue)
;
; Un enregistrement PAR TRAME VIDEO depilee, pas par boucle de jeu : c'est la
; seule granularite ou l'etat du script se confronte a l'integrale arcade,
; qui est elle aussi par trame. L'anneau vit dans une page entiere ($16, la
; derniere page libre de l'arene ennemis, dont la zone est commentee tant que
; l'instrumentation est la) montee en fenetre cartouche — la meme fenetre que
; le script, d'ou le va-et-vient de page aux frontieres de segment (295 fois
; en 9536 trames : le cout est nul devant le releve).
;
; En-tete a la base de la page, puis 1008 enregistrements de 16 octets
; (20 secondes de jeu) : la sonde draine plus vite que ca et se sert du
; compteur d'ecritures pour detecter tout debordement.
;
;   +0  (2) gfxlock.frame.count de la boucle — l'horloge video 50 Hz
;   +2  (1) gfxlock.frameDrop.count — trames depilees par cette boucle
;   +3  (1) trames restant a depiler quand cet enregistrement est ecrit
;   +4  (2) pilot.cursor   — l'entree de script APRES l'avance eventuelle
;   +6  (2) pilot.counter  — trames restantes du segment courant
;   +8  (2) pilot.sx       — vitesse x 8.8 de CETTE trame
;   +10 (2) pilot.sy       — vitesse y 8.8 de CETTE trame
;   +12 (2) mscroll.camera.x — position de la couche a l'entree de la boucle
;   +14 (2) mscroll.camera.y
; ---------------------------------------------------------------------------
wlog.MAGIC    equ $57DB                 ; 'W' + $DB : la page est a nous
wlog.magic    equ $0000
wlog.wptr     equ $0002                 ; adresse d'ecriture courante
wlog.written  equ $0004                 ; enregistrements ecrits (mot, boucle)
wlog.START    equ $0100
wlog.END      equ $4000                 ; 1008 enregistrements de 16 octets

; la page log deja montee ; ecrase A, B, X
; NOTE : le '>' est OBLIGATOIRE sur chaque acces a l'en-tete. Les adresses
; sont < 256, et sans setdp lwasm les assemble en ADRESSAGE DIRECT — ce qui,
; DP valant $9F pendant le jeu, ecrirait dans le bloc dp au lieu de la page
; du journal. Le releve serait vide et la machine par terre.
wlog.init
        ldx   #wlog.START
        stx   >wlog.wptr
        ldd   #0
        std   >wlog.written
        ldd   #wlog.MAGIC
        std   >wlog.magic
        rts

; page log montee, U = OST du pilote, l'appel est un jsr donc les trames
; restantes poussees par la boucle sont a 2,s. Preserve U et S.
wlog.record
        ldx   >wlog.wptr
        ldd   gfxlock.frame.count
        std   ,x++
        lda   gfxlock.frameDrop.count
        sta   ,x+
        ldb   2,s
        stb   ,x+
        ldd   pilot.cursor,u
        std   ,x++
        ldd   pilot.counter,u
        std   ,x++
        ldd   pilot.sx,u
        std   ,x++
        ldd   pilot.sy,u
        std   ,x++
        ldd   mscroll.camera.x
        std   ,x++
        ldd   mscroll.camera.y
        std   ,x++
        cmpx  #wlog.END
        blo   >
        ldx   #wlog.START
!       stx   >wlog.wptr
        ldd   >wlog.written
        addd  #1
        std   >wlog.written
        rts
 ENDC

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
 IFDEF WARSHIP_LOG_PAGE
        lda   #map.RAM_OVER_CART+WARSHIP_LOG_PAGE
        _SetCartPageA
        jsr   wlog.init                ; RunObjects remonte pour l'objet suivant
 ENDC
        rts

pilotLive
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
 IFDEF WARSHIP_LOG_PAGE
        ; la page du JOURNAL occupe la fenetre pendant tout le depilage ; le
        ; script n'y est monte qu'aux frontieres de segment (voir plus bas)
!       lda   #map.RAM_OVER_CART+WARSHIP_LOG_PAGE
 ELSE
        ; la page du script, montee AVANT tout (le mount passe par A)
!       lda   #map.RAM_OVER_CART+stage3.camscript.page
 ENDC
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
 IFDEF WARSHIP_LOG_PAGE
        lda   #map.RAM_OVER_CART+stage3.camscript.page
        _SetCartPageA                  ; le script, le temps de lire l'entree
 ENDC
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
 IFDEF WARSHIP_LOG_PAGE
        lda   #map.RAM_OVER_CART+WARSHIP_LOG_PAGE
        _SetCartPageA                  ; retour au journal
 ENDC
@tick   stx   pilot.counter,u
 IFDEF WARSHIP_LOG_PAGE
        jsr   wlog.record              ; UNE ligne par trame video depilee
 ENDC
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
@end    equ   *
 IFDEF WARSHIP_LOG_PAGE
        lda   #map.RAM_OVER_CART+WARSHIP_LOG_PAGE
        _SetCartPageA
 ENDC
        leas  1,s                      ; le decompte n'a plus d'objet : les
                                       ; trames restantes sont a (0,0)
        lda   #2                       ; -> dormance (TODO : la sequence de
        sta   routine,u                ; fin arcade 0xc55d avec le combat)
        bra   @done
pilotDone
        rts
