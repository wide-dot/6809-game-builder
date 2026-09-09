;*******************************************************************************
; Le bouton de tir echantillonne sous IRQ, ses fronts VERROUILLES
;
; joypad.read / joypad.readKbd lisent le port une fois par tour de boucle et
; detectent le front contre la lecture precedente. A neuf images par seconde
; un tour dure 100 a 120 ms : un appui relache entre deux lectures est perdu,
; et tout appui est vu jusqu'a un tour plus tard. Les DIRECTIONS n'ont pas ce
; probleme — joypad.buffer.addDirection les enregistre a 50 Hz et le joueur
; rejoue un pas par entree — mais le tir, si.
;
; Ici le port est lu a CHAQUE trame 50 Hz (joypad.latch.sample, a appeler de
; l'IRQ a cote d'addDirection) : le front montant de chaque bouton est
; accumule dans joypad.latch.pressed jusqu'a ce que la boucle le consomme
; (joypad.latch.read), qui pose alors joypad.pressed/held/state exactement
; comme readKbd l'aurait fait — les consommateurs (joueur, force pod, bits,
; HUD) ne changent pas. Le clavier reste injecte en bouton B (KTEST), comme
; dans readKbd. `held` est l'etat de la derniere trame echantillonnee.
;
; LES APPUIS UN A UN (09/09/2026, decision auteur : ne pas penaliser le
; joueur quand le jeu ralentit). Un bit fond tous les appuis d'une fenetre
; de rendu en un seul tir. Ici chaque front du bouton A est aussi note avec
; LA TRAME ou il tombe (joypad.taps : l'octet bas de gfxlock.frame.count, le
; compteur d'IRQ, deja incremente pour cette trame quand l'IRQ nous appelle).
; Le joueur produit alors un tir par appui, ne a la position du vaisseau a
; cette trame-la (l'anneau de positions que le force pod suit en a une par
; trame) et en retard de (lastCount - F) trames — la bascule de tampons
; date de lastCount, c'est l'horloge du pas suivant du tir — que le tir
; rattrape a sa naissance. Compter les rangs depuis la LECTURE, comme la
; premiere version, laissait une trame d'ambiguite quand une IRQ tombait
; entre la bascule et la lecture (vecu : des tirs a 18 px au lieu de 12).
; Huit appuis au plus par fenetre.
;
; La prise du verrou masque l'IRQ le temps de quelques instructions : un
; front qui tomberait entre la lecture et l'effacement serait perdu sinon.
;
; FICHIER SANS SECTION, A INCLURE DANS L'UNITE QUI TIENT LA BOUCLE ET L'IRQ
; (r-type : src/stages/stage-main.asm, dans chaque main de stage) — pas dans
; le moteur resident, qui n'a plus un octet de marge devant le lecteur YMM
; (5 855 octets de $6100 a $77DF, vecu le 09/09/2026). Les octets
; joypad.state/held/pressed restent ceux de joypad.asm (moteur, via l'API) ;
; joypad.taps est EXPORTE par l'unite hote pour le joueur, qui le declare
; EXTERNAL — chaque main de stage l'exporte, alternatives a la meme
; destination. Suppose joypad.const.asm et map.const.asm deja inclus.
; Mesure : tools/fire_latch_probe.py et fire_burst_probe.py (games/r-type).
;*******************************************************************************

joypad.taps          EXPORT
joypad.taps.count    EXPORT

joypad.taps.MAX      equ   8

joypad.latch.prev    fdb   0            ; le dernier etat echantillonne (dpad, boutons)
joypad.latch.pressed fcb   0            ; les fronts de boutons depuis la derniere lecture
joypad.latch.taps    fill  0,joypad.taps.MAX ; la trame de chaque appui sur A
joypad.latch.tapCount fcb  0
; la copie que la boucle lit (l'IRQ remplit deja la fenetre suivante)
joypad.taps          fill  0,joypad.taps.MAX
joypad.taps.count    fcb   0

; Amorcer avec l'etat de repos du port — le meme geste que joypad.init : les
; lignes DAC se lisent a zero et, complementees, feraient un front fantome.
; Sert aussi de FLUSH : a rappeler a chaque reprise ou la boucle a cesse de
; lire le verrou alors que l'IRQ tournait (rechargement de checkpoint apres
; le menu « continue », vecu 09/09/2026) — un bouton encore tenu ne fait
; pas de front, et les appuis accumules ne deviennent pas des tirs.
joypad.latch.init
        ldd   map.MC6821.PRA1
        coma
        comb
        std   joypad.latch.prev
        clr   joypad.latch.pressed
        clr   joypad.latch.tapCount
        clr   joypad.taps.count
        rts

; Sous IRQ, une fois par trame 50 Hz. Detruit D.
joypad.latch.sample
        ldd   map.MC6821.PRA1          ; l'etat physique, complemente
        coma
        comb
        pshs  a                        ; le dpad de cote
        lda   map.MC6821.PRA           ; PIA systeme, KTEST en bit 0
        lsra                           ; bit 0 -> C
        bcc   >
        orb   #joypad.0.B              ; une touche = le bouton B
!       puls  a
        pshs  b                        ; l'etat des boutons
        eorb  joypad.latch.prev+1      ; ce qui a change...
        andb  ,s                       ; ... et qui est enfonce : les fronts montants
        pshs  b
        orb   joypad.latch.pressed
        stb   joypad.latch.pressed     ; accumules jusqu'a la lecture
        puls  b
        bitb  #joypad.0.A              ; un appui sur A : sa trame
        beq   >
        ldb   joypad.latch.tapCount
        cmpb  #joypad.taps.MAX
        bhs   >                        ; huit deja : les suivants se perdent
        ldx   #joypad.latch.taps
        lda   gfxlock.frame.count+1    ; l'octet bas du compteur d'IRQ
        sta   b,x
        incb
        stb   joypad.latch.tapCount
!       puls  b
        std   joypad.latch.prev
        rts

; Dans la boucle, a la place de joypad.readKbd : pose state/held/pressed.
; Detruit D, X et Y.
joypad.latch.read
        ldd   joypad.latch.prev        ; l'etat le plus recent
        sta   joypad.state.dpad        ; (les octets un a un : l'API du moteur
        stb   joypad.state.fire        ;  n'exporte pas les mots)
        lda   joypad.held.dpad         ; les fronts du dpad, comme joypad.read
        eora  joypad.state.dpad
        anda  joypad.state.dpad
        sta   joypad.pressed.dpad
        orcc  #$10                     ; prendre le verrou sans qu'une IRQ s'y glisse
        ldb   joypad.latch.pressed
        clr   joypad.latch.pressed
        stb   joypad.pressed.fire
        ldb   joypad.latch.tapCount
        stb   joypad.taps.count
        clr   joypad.latch.tapCount    ; (clr pose Z : tester B apres)
        tstb
        beq   >                        ; aucun appui : rien a recopier
        ldx   #joypad.latch.taps       ; les trames, dans l'ordre
        ldy   #joypad.taps
@copy   lda   ,x+
        sta   ,y+
        decb
        bne   @copy
!       andcc #$EF
        ldd   joypad.latch.prev
        sta   joypad.held.dpad
        stb   joypad.held.fire
        rts
