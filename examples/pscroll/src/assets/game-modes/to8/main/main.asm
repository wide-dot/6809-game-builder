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

        ; la vitesse de derive, posee AVANT la boucle : le chemin « personne
        ; n'a touche » saute l'application, donc sans ca la camera reste a 0
        ldd   ctrlspeedx
        std   pscroll.camera.speedx

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
@apply  ldd   ctrlspeedx
        std   pscroll.camera.speedx
@run
        _gfxlock.on
        jsr   pscroll.do                   ; peindre la bande ou est la camera
        jsr   pscroll.move                 ; avancer, graver ce qui entre
        _gfxlock.off

        jsr   bench.smileyStep         ; la mire, tant qu'elle n'est pas finie

        ; --- CYTRON : la repousse, une cellule par trame --------------------
        ; run_cytron etape 5 (plate Ghidra 0x4069b4) : il sonde la cellule sous
        ; son centre et n'ecrit QUE si elle est vide. Ici le pilote est reduit a
        ; sa trajectoire : il rampe vers la droite le long d'une rangee, une
        ; cellule par trame, exactement comme l'arcade.
        ; L'INTERRUPTEUR DU BANC. 0 = le pilote se tait (on positionne la
        ; camera sans muter le champ) ; 255 = il rampe librement ; 1..254 =
        ; autant de tirs UNIQUES, sans avancer — c'est ce qui permet de valider
        ; UNE gomme a la fois, la seule methode qui prouve un positionnement.
        lda   cytron.enable
        lbeq  @nogum
        cmpa  #255
        beq   @libre
        deca
        sta   cytron.enable
        ldb   cytron.row
        ldx   cytron.col
        tst   cytron.erase             ; le banc exerce les DEUX chemins
        beq   >
        jsr   pscroll.clearCell
        bra   @compte
!       jsr   pscroll.setCell
@compte beq   >                        ; Z=1 : rien a faire (deja pleine/vide)
        inc   $9C06                    ; mutee — AVANT le compteur d'essais :
!       inc   $9C05                    ; `inc` ecrase le Z que la routine vient
        lbra  @nogum                   ; de poser (defaut du banc, 22/08)
@libre  ldb   cytron.row
        ldx   cytron.col
        jsr   pscroll.setCell
        beq   >                        ; Z=1 : la cellule etait deja pleine
        inc   $9C06                    ; temoin : celles qui ont pousse
!       inc   $9C05                    ; temoin : les repousses tentees
        ldx   cytron.col               ; il avance d'une cellule par trame
        leax  1,x
        cmpx  #pscroll.CELLS
        blo   >
        ldx   #0
!       stx   cytron.col
        ldd   cytron.px
        addd  #3
        std   cytron.px
        ; IL RESTE DANS LA FENETRE. L'arcade ne fait jamais ecrire cytron au
        ; dela du bord droit : le scroll fait apparaitre les colonnes neuves.
        ; Ici il avance 3 px/trame contre 1 a la camera, donc il sort — on le
        ; ramene d'un ruban (53 cellules = 159 px) autant de fois qu'il faut.
@wrap   ldd   pscroll.camera.x
        addd  #150
        cmpd  cytron.px
        bhi   >
        ldd   cytron.px
        subd  #159
        std   cytron.px
        ldx   cytron.col
        leax  -53,x
        stx   cytron.col
        bra   @wrap
!
@nogum

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

; --- cytron, reduit a ce que le banc doit valider -------------------------
; La rangee 14 traverse la grande salle en plein milieu du champ : le pilote
; y rampe et fait repousser ce qui manque. Les vraies routines (script de
; mouvement bit-packe, tir, collision, PV) viendront avec le portage complet.
cytron.col   fdb 260                   ; il demarre juste avant la salle
cytron.row   fcb 14
cytron.px    fdb 780                   ; 3 * cytron.col, tenu a jour
cytron.erase  fcb 0                    ; 0 = la gomme pousse, 1 = elle disparait
cytron.enable fcb 0                    ; 0 = muet, 255 = libre, n = n tirs
                                       ; (muet tant que le smiley se dessine)
smiley.row   fcb 0                     ; la rangee en cours ; H = fini
smiley.ptr   fdb 0
smiley.i     fcb 0
smiley.r     fcb 0                     ; la rangee de la mire (row modulo H)
smiley.PAUSE equ 150                   ; tours de boucle avant l'effacement
smiley.pause fcb smiley.PAUSE
smiley.loop  fcb 1                     ; 0 = un seul cycle puis silence
smiley.col0  fdb 4                     ; a la camera 0 : px 12..107, hors des
smiley.ROW0  equ 0                     ; 8 px de bord masques

demo.attract fcb 1                         ; 1 tant que rien n'a ete presse
ctrlmag      fdb $0100
ctrlspeedx   fdb $0000                     ; a l'arret tant que le smiley se dessine

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

; le champ de gommes d'origine : cytron le mute en place
field.map
        INCLUDEBIN "../../games/r-type/src/stages/04/terrain/level4_ball.bin"

 ENDSECTION

; un module v2 : il apporte sa propre section
        INCLUDE "engine/system/to8/controller/joypad.asm"
