; LE PILOTE CYTRON, DERRIERE UN DRAPEAU. Il pesait ~1,6 Ko avec son script de
; mouvement arcade, et la page du banc n'avait plus que 129 octets de marge —
; les seize routines de run de quatre n'y entraient pas. L'objet COMPLET vit
; desormais dans games/r-type/src/enemies/cytron/ ; ce pilote n'etait qu'un
; banc de repousse. Le remettre a 1 pour rejouer shot_cytron.py.
PSCROLL_DEBUG equ 1                    ; compteurs de chemin + octet de carte
; PSCROLL_DEBUG_FEED equ 1             ; le journal de gravure de feedBand :
                                       ; startline par bande, adresses d'entree
                                       ; du blast, compteurs de chemin. ~350
                                       ; octets — a REACTIVER pour probe_couture
                                       ; et a couper ensuite, la page est juste
                                       ; (au-dela de ~15 Ko le game mode ne se
                                       ; charge plus du tout : PC part au
                                       ; moniteur, temoins muets, 23/08).
BENCH_CYTRON equ 0

;*******************************************************************************
; pscroll — le banc du champ de gommes persistant
;
; pscroll est le clone HORIZONTAL de mscroll : les gfx sont graves une fois
; dans un buffer de code et seul le delta est remis a jour. Ce banc fait
; defiler le VRAI champ de gommes du stage 4 de R-Type (la carte
; games/r-type/src/stages/04/terrain/level4_ball.bin, gravee en 33 routines
; par games/r-type/tools/gen_pscroll.py, dont le rendu est prouve au pixel).
;
; Ce qu'il exerce, et qui n'a jamais tourne :
;   - le ruban horizontal et son cisaillement map-fixe ;
;   - l'ordre INVERSE des emplacements (le chunk c peint la colonne 9-c) ;
;   - le choix de la paire de buffers sur le bit 0 de la camera (le 1 px) ;
;   - le feed d'une bande entrante, les quatre buffers.
;
; TOUT EST RESIDENT ICI : le game mode vit en page $01 a $6100, donc en RAM
; fixe. La gravure peut monter la page d'un buffer dans la fenetre cartouche
; sans se demonter elle-meme — c'est le point ouvert de l'etude, contourne
; par construction dans ce banc.
;
; Controles : gauche/droite deplacent la camera, A = rapide (2 px/trame),
; B = lent (0,5), rien = 1 px/trame. Sans manette, la camera derive seule
; vers la droite pour que le banc dise quelque chose.
;
; Temoins en $9C00 : $9C00 compteur de trames, $9C01 camera (mot),
; $9C03 la parite courante, $9C04 le nombre de gravures faites.
;*******************************************************************************

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.macro.asm"
        INCLUDE "engine/system/thomson/graphics/mode/gfxmode.macro.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/controller/joypad.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.macro.asm"

 opt c,ct

; --- la geometrie du champ, celle du stage 4 ---------------------------------
pscroll.BAND_LINES equ 180              ; 30 rangees de 6 lignes
field.MAP_W        equ 1152             ; largeur de la carte, en px
pscroll.MAP_WIDTH  equ field.MAP_W      ; le module verifie le budget avec
pscroll.MAX_SEAMS  equ 8                ; 1152 px / 160 = 7,2 coutures
field.VP_Y         equ 11               ; premiere ligne ecran du champ

; les quatre pages de buffer : plan 0 phase 0, plan 0 phase 1, plan 1 ph 0, ph 1
buf.PAGE0          equ 5
buf.PAGE1          equ 6
buf.PAGE2          equ 7
buf.PAGE3          equ 8

; le scene loader saute au premier octet : main doit etre emis en premier
main
        jsr   InitGlobals
        jsr   joypad.init
        _gfxmode.setBM16

        ; les deux tampons d'ecran : ce que le boot laisse est du bruit
        jsr   IrqOff
        _ram.data.set #2
        ldx   #$0000
        jsr   ClearInterlacedEvenDataMemory
        ldx   #$0000
        jsr   ClearInterlacedOddDataMemory
        _ram.data.set #3
        ldx   #$0000
        jsr   ClearInterlacedEvenDataMemory
        ldx   #$0000
        jsr   ClearInterlacedOddDataMemory

        ; la palette du stage 4
        ldd   #Pal_field
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow

        ; --- les parametres de la couche -----------------------------------
        lda   #map.RAM_OVER_CART+buf.PAGE0
        sta   pscroll.buf.page
        lda   #map.RAM_OVER_CART+buf.PAGE1
        sta   pscroll.buf.page+1
        lda   #map.RAM_OVER_CART+buf.PAGE2
        sta   pscroll.buf.page+2
        lda   #map.RAM_OVER_CART+buf.PAGE3
        sta   pscroll.buf.page+3
        ldd   #$0000                       ; les quatre buffers a $0000 de leur page
        std   pscroll.buf.address
        std   pscroll.buf.address+2
        std   pscroll.buf.address+4
        std   pscroll.buf.address+6
        ; La fin de bande : l'octet APRES la derniere ligne. Le blast empile
        ; vers le bas, donc sa premiere poussee peint la ligne d'avant.
        ldd   #$A000+(field.VP_Y+pscroll.BAND_LINES)*40
        std   pscroll.viewport.ram
        ldd   #field.MAP_W-160
        std   pscroll.camera.x.max

        ; le bitfield des gommes, en RAM FIXE : la mutation le lit ET l'ecrit,
        ; contrairement au feed qui grave depuis la carte de build. Il tient
        ; dans l'unite depuis que les tables generiques ont disparu.
        ldd   #field.map
        std   pscroll.map.address

        ; LA CAMERA DU BANC. pscroll n'a plus de defilement interne (24/08/2026)
        ; : dans le jeu c'est glb_camera_x_pos qui le pilote, et ici c'est ce
        ; banc — qui n'a pas de moteur, donc integre lui-meme sa vitesse. Le
        ; calcul est celui que le module portait, deplace tel quel : accumuler
        ; la vitesse 8.8 autant de fois que de trames perdues, ne prendre que
        ; la partie entiere, garder la fraction.

 IFNE BENCH_CYTRON
        jsr   bench.cytronReset
 ENDC

        ; --- la gravure initiale : dix bandes ------------------------------
        ldd   #0
        jsr   pscroll.init

        ; irq
        ldd   #userIRQ
        std   Irq_user_routine
        jsr   IrqInit
        lda   #255
        ldx   #Irq_one_frame
        jsr   IrqSync
        _gfxlock.init
        jsr   IrqOn

mainLoop
        jsr   joypad.read
        lda   joypad.held.dpad
        anda  #joypad.0.DPAD
        bne   @steer
        tst   demo.attract
        bne   @run                         ; personne n'a touche : derive seule
        ldd   #0
        std   ctrlspeedx
        bra   @apply
@steer  clr   demo.attract
        lda   joypad.held.fire
        ldx   #$0100                       ; 1 px/trame
        bita  #joypad.0.A
        beq   >
        ldx   #$0200                       ; rapide
!       bita  #joypad.0.B
        beq   >
        ldx   #$0080                       ; lent
!       stx   ctrlmag
        lda   joypad.held.dpad
        bita  #joypad.0.LEFT
        beq   @right
        ldd   ctrlmag
        _negd
        bra   @setx
@right  bita  #joypad.0.RIGHT
        beq   @zerox
        ldd   ctrlmag
        bra   @setx
@zerox  ldd   #0
@setx   std   ctrlspeedx
@apply
@run    jsr   bench.cameraStep             ; LA camera du banc -> camera.next
        _gfxlock.on
        ; move d'abord : il porte la camera et grave la bande qui entre AVANT
        ; que do ne la peigne. Dans l'autre ordre, do peignait la position du
        ; tour precedent — un decalage d'un tour entre le plan et la camera.
        jsr   pscroll.move                 ; s'y rendre, graver ce qui entre
        jsr   pscroll.do                   ; peindre la bande ou est la camera
        _gfxlock.off

        jsr   bench.smileyStep         ; la mire, tant qu'elle n'est pas finie

        ; --- L'EFFACEMENT EN MASSE : le banc le declenche a la demande ------
        ; --- LE CHAMP PLEIN : remplir la carte et TOUT regraver -------------
        ; La mire smiley servait a avoir un champ connu ; un champ PLEIN sert
        ; mieux : tout ecart a l'ecran est alors un effacement, et un seul.
        ; On ecrit la carte a $FF puis on rappelle pscroll.init, qui regrave
        ; les dix bandes depuis elle — c'est cher (~160 000 cycles) et c'est
        ; exactement ce qu'on veut entre deux essais.
        tst   bench.fill
        beq   >
        jsr   bench.fillRow            ; UNE rangee par tour, pas les trente
!
        tst   bench.rect
        beq   >
        jsr   pscroll.clearRect
        ; le temoin ne tombe qu'APRES l'execution. Il tombait avant : un
        ; effacement qui deborde de la trame laissait le pilote exterieur
        ; croire le travail fini, ecrire le rect suivant, et ECRASER les
        ; variables du rect encore en vol — 4 des 11 blocs du counter-air
        ; se perdaient ainsi (23/08). Aucun autre tour ne lit entre le jsr
        ; et le clr : le re-jeu est impossible.
        clr   bench.rect
!
        ; --- CYTRON : le pilote, porte de l'arcade --------------------------
        jsr   bench.cytronStep

        ; --- les temoins ---------------------------------------------------
        inc   $9C00
        ldd   pscroll.camera.x
        std   $9C01
        ldb   pscroll.camera.x+1
        andb  #1
        stb   $9C03

        _gfxlock.loop
        lbra  mainLoop

; C'est l'IRQ utilisateur qui fait avancer le double tampon : sans cet appel
; l'echange n'a jamais lieu et _gfxlock.loop attend indefiniment (une trame
; peinte, puis plus rien — vecu le 22/08).
userIRQ
        jsr   gfxlock.bufferSwap.check
        jmp   PalUpdateNow


; -----------------------------------------------------------------------------
; bench.cytronStep — un tour de cytron
; -----------------------------------------------------------------------------
; cytron.enable : 0 = muet ; 255 = il joue son script arcade ; 1..254 = autant
; de sondes UNIQUES a (cytron.col, cytron.row), sans bouger — c'est par la que
; tools/check_gum.py valide une mutation a la fois.
; -----------------------------------------------------------------------------
bench.cytronStep
        lda   cytron.enable
        lbeq  @rien
 IFNE BENCH_CYTRON
        cmpa  #255                     ; 255 = il joue son script arcade
        beq   @script
 ENDC
        ldb   cytron.row               ; le chemin du banc : une sonde, sur
        ldx   cytron.col               ; place. enable n'est decremente
        lbra  @sonde                   ; qu'APRES la mutation (voir bench.rect)                   ; portee longue : le decodeur s'etale
 IFNE BENCH_CYTRON
        ; --- le script arcade : `speed` octets de deplacement par trame -----
@script lda   cytron.speed
        sta   cytron.left
@byte   ldx   cytron.seg
        ldb   ,x+
        stx   cytron.seg
        rolb                           ; bit 7 : pose ?
        bcs   @image
        rolb                           ; bit 6
        bcs   @xneg
        rolb                           ; bit 5
        bcc   @ytest
        ldd   cytron.x                 ; x++
        addd  #cytron.STEP
        std   cytron.x
        bra   @ytest
@xneg   rolb                           ; bit 5
        bcc   @ytest
        ldd   cytron.x                 ; x--
        subd  #cytron.STEP
        std   cytron.x
@ytest  rolb                           ; bit 4
        bcs   @ypos
        rolb                           ; bit 3
        bcc   @fin
        ldd   cytron.y                 ; y--
        subd  #cytron.STEP
        std   cytron.y
        bra   @fin
@ypos   rolb                           ; bit 3
        bcc   @fin
        ldd   cytron.y                 ; y++
        addd  #cytron.STEP
        std   cytron.y
@fin    rolb                           ; bit 2 : fin de segment ?
        bcs   @suivant
@apres  dec   cytron.left
        bne   @byte
        bra   @place
@image  lsrb                           ; la pose ne consomme pas de deplacement
        stb   cytron.img               ; et ne termine pas le segment
        bra   @byte
        ; --- la commande suivante -------------------------------------------
@suivant
        ldx   cytron.script
        leax  2,x
        ldd   ,x
        beq   @finscript               ; 0 : fin de script
        stx   cytron.script
        cmpa  #$F0
        bne   @segment
        stb   cytron.speed             ; $F0nn : la vitesse change
        bra   @suivant
@segment
        std   cytron.seg
        bra   @apres
        ; L'ARCADE DECHARGE L'OBJET ICI (0x6A42, unload silencieux). Le banc,
        ; lui, le fait repartir : il n'a ni vague ni gestionnaire d'objets pour
        ; en faire naitre un autre, et une mire qui s'arrete ne montre rien.
@finscript
 IFNE BENCH_CYTRON
        jsr   bench.cytronReset
 ENDC
        bra   @place                   ; @place suit immediatement
        ; --- LA SONDE : position + le decalage de la pose --------------------
        ; Le decalage est en px arcade ; 8 px arcade = 1 cellule, donc x32 le
        ; met a l'echelle du 8.8 en cellules.
@place  ldb   cytron.img
        andb  #15
        aslb
        aslb                           ; x4 : deux mots par pose
        ldx   #cytron.trail.tbl
        abx
        ldd   ,x                       ; dx, en px arcade (signe)
        aslb
        rola
        aslb
        rola
        aslb
        rola
        aslb
        rola
        aslb
        rola                           ; x32 -> cellules 8.8
        addd  cytron.x
        sta   cytron.col+1             ; la partie entiere : l'index de cellule
        clr   cytron.col
        ldb   cytron.img
        andb  #15
        aslb
        aslb
        ldx   #cytron.trail.tbl
        abx
        ldd   2,x                      ; dy
        aslb
        rola
        aslb
        rola
        aslb
        rola
        aslb
        rola
        aslb
        rola
        addd  cytron.y
        sta   cytron.row
        ldb   cytron.row
        ldx   cytron.col
 ENDC
@sonde  tst   cytron.erase
        beq   >
        jsr   pscroll.clearCell
        bra   @compte
!       jsr   pscroll.setCell
@compte beq   >                        ; Z=1 : rien a faire (deja pleine/vide)
        inc   $9C06                    ; mutee — AVANT le compteur d'essais :
!       inc   $9C05                    ; `inc` ecrase le Z que la routine vient
        lda   cytron.enable            ; de poser (defaut du banc, 22/08)
        beq   @rien
        deca                           ; la sonde est consommee, maintenant
        sta   cytron.enable            ; qu'elle a eu lieu
@rien   rts

 IFNE BENCH_CYTRON
; Pose la variante jouee et la position de depart.
bench.cytronReset
        ldb   #cytron.VAR
        aslb
        aslb                           ; 4 octets par entree
        ldx   #cytron.script.tbl
        abx
        ldd   ,x                       ; le pointeur de script
        std   cytron.script
        lda   2,x                      ; les octets par trame
        sta   cytron.speed
        ldx   cytron.script
        ldd   ,x                       ; la premiere commande EST un segment
        std   cytron.seg
        ldd   #cytron.START_X*256
        std   cytron.x
        ldd   #cytron.START_Y*256
        std   cytron.y
        rts
 ENDC

; -----------------------------------------------------------------------------
; bench.fillDo — POSER UNE GOMME PARTOUT, par le vrai chemin
; -----------------------------------------------------------------------------
; PAS par la carte : le feed grave depuis les donnees GENEREES (les routines de
; colonne portent le niveau), pas depuis field.map — remplir la carte et
; rappeler pscroll.init redonne donc le niveau d'origine, pas un champ plein.
; On passe par setCell, qui est justement le chemin a exercer : il pose le bit
; ET grave les quatre buffers. Les cellules hors ruban sont refusees toutes
; seules, on peut donc balayer la carte entiere sans se soucier des bornes.
;
; ~11 500 appels, dont 1 620 font vraiment quelque chose : environ deux
; secondes. C'est un banc.
; -----------------------------------------------------------------------------
; UNE RANGEE PAR TOUR. Les trente d'un coup tenaient dans un seul tour de
; boucle — deux secondes, soit un debordement de plus de cent trames — et
; gfxlock n'en revenait pas : la boucle du banc s'arretait net, temoins geles
; (23/08). Une rangee coute ~4 trames, ce que la compensation absorbe.
; Le pilote pose bench.fill.row a 0 puis bench.fill a 1 ; le banc rend la main
; en effacant bench.fill quand les trente rangees sont posees.
bench.fillRow
        ldx   #0
bench.fillCol
        ldb   bench.fill.row
        pshs  x
        jsr   pscroll.setCell          ; hors ruban, il refuse tout seul
        puls  x
        leax  1,x
        cmpx  #pscroll.CELLS
        blo   bench.fillCol
        inc   bench.fill.row
        lda   bench.fill.row
        cmpa  #pscroll.ROWS
        blo   >
        clr   bench.fill               ; les trente rangees sont posees
!       rts
bench.fill.row fcb 0

; --- LE SMILEY : la mire du chemin d'ECRITURE -----------------------------
; Une rangee par trame, cellule par cellule, par pscroll.setCell — le chemin
; exact de la repousse arcade. Un disque trace sur la grille de cellules doit
; apparaitre ROND (3 px sur 6 lignes = une cellule carree a l'ecran) ; les
; yeux et la bouche sont des CREUX, donc ils prouvent qu'une cellule vide le
; reste au milieu de voisines pleines.
;
; L'etat vit en variables : setCell ecrase tous les registres.
bench.smileyStep
        lda   smiley.row
        cmpa  #2*bench.smiley.H
        blo   >
        tst   smiley.loop              ; le cycle recommence, sauf si un banc
        beq   @fini                    ; demande le silence (check_gum)
        clr   smiley.row
        lda   #smiley.PAUSE
        sta   smiley.pause
@fini   rts
!       cmpa  #bench.smiley.H          ; premiere moitie = on dessine,
        blo   >                        ; seconde = on efface la meme mire
        bne   @efface                  ; pile a la bascule : on la laisse en
        lda   smiley.pause             ; place le temps de la regarder
        beq   @efface
        deca
        sta   smiley.pause
        rts
@efface lda   smiley.row
        suba  #bench.smiley.H
!       sta   smiley.r                 ; la rangee de la mire
        ldb   #bench.smiley.W/8        ; 4 octets par rangee
        mul
        addd  #bench.smiley
        std   smiley.ptr
        clr   smiley.i
@cell   lda   smiley.i
        lsra
        lsra
        lsra                           ; l'octet de la cellule
        ldx   smiley.ptr
        lda   a,x
        ldb   smiley.i
        andb  #7
        ldx   #pscroll.tbl.bit
        anda  b,x                      ; son bit
        beq   @next
        ldb   smiley.r
        addb  #smiley.ROW0
        ldx   smiley.col0              ; variable : un banc peut poser la mire
        lda   smiley.i                 ; au fond du niveau pour y mesurer
        leax  a,x
        lda   smiley.row               ; seconde moitie : on efface
        cmpa  #bench.smiley.H
        blo   @pousse
        jsr   pscroll.clearCell
        bra   @next
@pousse jsr   pscroll.setCell
@next   inc   smiley.i
        lda   smiley.i
        cmpa  #bench.smiley.W
        blo   @cell
        inc   smiley.row
        rts

; --- CYTRON, porte de l'arcade -------------------------------------------
; run_cytron (0x40:69B4). Ce que le banc porte, et pourquoi :
;
;   - LE SCRIPT DE MOUVEMENT, joue depuis les octets de la rom
;     (src/enemies/cytron/movescript.asm, exporte par re.arcade.r-type). Le
;     format est celui de move_by_script (0x40:F5C1), que la v2 embarque deja
;     sous le nom moveByScript ; le banc le decode ici en unites de CELLULE
;     parce que c'est la langue du champ de gommes — 8 px arcade = 1 cellule,
;     ce qui tombe juste : 8 x 0,375 = 3 px larges en X, 8 x 0,75 = 6 lignes
;     en Y, exactement la geometrie d'une cellule.
;
;   - LE DECALAGE DE REPOUSSE PAR POSE. La plate Ghidra dit « la cellule sous
;     le centre du corps » ; le code dit autre chose, et le code a raison :
;     il ajoute a la position un couple (dx,dy) lu dans une table indexee par
;     la POSE (0x1000:2D90). Cette table est un CERCLE DE RAYON 12 px sur
;     seize directions — cytron plante sa gomme DERRIERE lui, dans l'axe de sa
;     pose, pas sous son centre. C'est ce qui lui fait laisser une trainee.
;
;   - LA SONDE : une cellule par trame, et seulement si elle est vide. C'est
;     exactement ce que fait pscroll.setCell (cc.Z = 1 = deja pleine).
;
; Hors banc, faute de joueur et de gestionnaire d'objets : try_foe_fire, la
; collision, les PV et les deux morts. Ils viendront avec l'objet complet.
cytron.STEP  equ $0020                 ; 1 px arcade = 1/8 de cellule, en 8.8
cytron.VAR   equ 0                     ; la variante jouee par le banc
cytron.START_X equ 200                 ; ou il entre en scene, en cellules
cytron.START_Y equ 15
cytron.script fdb 0                    ; la commande courante
cytron.seg   fdb 0                     ; l'octet courant du segment
cytron.speed fcb 3                     ; octets de deplacement par trame
cytron.img   fcb 0                     ; la pose
cytron.x     fdb 0                     ; position, en CELLULES 8.8
cytron.y     fdb 0
cytron.left  fcb 0                     ; octets restants a lire cette trame
cytron.erase  fcb 0                    ; 0 = la gomme pousse, 1 = elle disparait
cytron.enable fcb 0                    ; 0 = muet, 255 = libre, n = n tirs
cytron.col   fdb 0                     ; la cellule sondee, pour les temoins
cytron.row   fcb 0
smiley.row   fcb 0                     ; la rangee en cours ; H = fini
smiley.ptr   fdb 0
smiley.i     fcb 0
smiley.r     fcb 0                     ; la rangee de la mire (row modulo H)
smiley.PAUSE equ 150                   ; tours de boucle avant l'effacement
smiley.pause fcb smiley.PAUSE
smiley.loop  fcb 1                     ; 0 = un seul cycle puis silence
smiley.col0  fdb 4                     ; a la camera 0 : px 12..107, hors des
smiley.ROW0  equ 0                     ; 8 px de bord masques

bench.rect   fcb 0                     ; 1 = joue pscroll.clearRect une fois
bench.fill   fcb 0                     ; 1 = champ plein + regravure complete
demo.attract fcb 1                         ; 1 tant que rien n'a ete presse
ctrlmag      fdb $0100
ctrlspeedx   fdb $0000                     ; a l'arret tant que le smiley se dessine

; -----------------------------------------------------------------------------
; bench.cameraStep — LA camera du banc
; -----------------------------------------------------------------------------
; pscroll ne defile plus tout seul : il va ou pscroll.camera.next dit. Dans le
; jeu c'est glb_camera_x_pos ; ici c'est ce banc, qui n'a pas de moteur et
; integre donc lui-meme sa vitesse. Le calcul vient TEL QUEL de l'ancien
; pscroll.move : accumuler la vitesse 8.8 une fois par trame perdue, ne
; consommer que la partie entiere, garder la fraction (l'octet haut de
; l'accumulateur est la partie entiere, il se remet a 0 — ou a $FF pour que
; l'emprunt joue quand on recule).
; -----------------------------------------------------------------------------
bench.cameraStep
        lda   gfxlock.frameDrop.count
        bne   >
        rts
!       sta   bench.cam.cnt
        ldd   bench.cam.frac
!       addd  ctrlspeedx
        dec   bench.cam.cnt
        bne   <
        std   bench.cam.frac
        ldb   bench.cam.frac           ; l'octet haut : la partie entiere
        bpl   >
        incb
!       sex
        addd  bench.cam.x
        std   bench.cam.x
        std   pscroll.camera.next
        ldb   bench.cam.frac
        bpl   >
        ldb   #$ff
        bra   @tail
!       clrb
@tail   stb   bench.cam.frac
        rts

bench.cam.x    fdb $0000                   ; position, en px de carte
bench.cam.frac fdb $0000                   ; accumulateur 8.8 (haut = entier)
bench.cam.cnt  fcb 0

;*******************************************************************************
; engine
;*******************************************************************************
        INCLUDE "engine/InitGlobals.asm"
        INCLUDE "engine/irq/Irq.asm"
        INCLUDE "engine/palette/PalUpdateNow.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.asm"
        INCLUDE "engine/graphics/clear/ClearInterlacedDataMemory.asm"
        INCLUDE "engine/graphics/tilemap/pscroll/pscroll.asm"
        INCLUDE "../../games/r-type/src/stages/04/pscroll-rows.asm"
        INCLUDE "src/assets/game-modes/to8/main/smiley.asm"
        ; les scripts de mouvement de cytron, exportes de la rom arcade
 IFNE BENCH_CYTRON
        INCLUDE "../../games/r-type/src/enemies/cytron/movescript.asm"
 ENDC

; le champ de gommes d'origine : cytron le mute en place
field.map
        INCLUDEBIN "../../games/r-type/src/stages/04/terrain/level4_ball.bin"

 ENDSECTION

; un module v2 : il apporte sa propre section
        INCLUDE "engine/system/to8/controller/joypad.asm"
