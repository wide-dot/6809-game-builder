;*******************************************************************************
; SFX TESTER — ecouter chaque bruitage du corpus Master System de R-Type sur le
; YM2413, sur son instrument d'origine ou sur l'un des quinze instruments de
; la ROM du chip, pour CHOISIR. Voir readme.md.
;
; Deux modes :
;   - AUTO (au demarrage) : deroule les dix-neuf sons du jeu ; chaque son qui
;     joue sur l'instrument personnalise est rejoue sur les quinze presets.
;     C'est la sequence que la video enregistre.
;   - MANUEL : ESPACE joue, N/P son suivant/precedent (tout le corpus, 54),
;     I/U instrument suivant/precedent, A rebascule en auto.
;
; L'ecran est celui du moniteur (texte 40 colonnes, aucun mode video pose) :
; tout passe par PUTC, la page directe du moniteur ($60) tenue dans la boucle
; principale. Le pilote de bruitage tourne sous l'IRQ 50 Hz avec DP=$E7, la
; page des registres, comme dans le jeu.
;
; LE GAME MODE EST CHARGE EN $6300, PAS EN $6100 : les deux pages sous $6300
; appartiennent au moniteur, qui y tient sa page directe ET les tampons de son
; ecran texte. Charge en $6100, ce fichier voyait huit octets de code effaces
; a $6211 des la premiere impression — la routine d'avance automatique sautait
; son `ldb tester.sel` et rejouait indefiniment le premier son, sans rien
; afficher de plus. L'exemple mplus, qui lit lui aussi le clavier par le
; moniteur, charge en $6300 pour la meme raison.
;*******************************************************************************

 SECTION code

        INCLUDE "engine/system/to8/pack/std.asm"
        INCLUDE "engine/system/to8/pack/irq.asm"
        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/system/to8/monitor/monitor.macro.asm"
        INCLUDE "engine/system/thomson/monitor/monitor.macro.asm"

 opt c,ct

INSTR_ORIGINAL  equ $FF          ; l'instrument du bloc, tel quel
GAP             equ 25           ; trames de silence entre deux sons en auto
ROW_SOUND       equ 6
ROW_INSTR       equ 8
ROW_MODE        equ 10

; ------------------------------------------------------------------------------
init
        _glb.init
        _irq.init
        _irq.setRoutine #userIRQ
        _irq.set50Hz
        jsr   tester.ymInit
        _irq.on

        lda   #$60                       ; la page directe du moniteur
        tfr   a,dp
        ldx   #msg.screen
        jsr   monitor.print

        jsr   tester.autoFirst           ; premier son du jeu, instrument d'origine
        jsr   tester.show
        jsr   tester.play

; ------------------------------------------------------------------------------
mainLoop
        lda   tester.frame               ; une passe par trame
!       cmpa  tester.frame
        beq   <

        jsr   keyboard.read
        ldb   keyboard.pressed
        lbeq  @noKey
        cmpb  #' '
        beq   @play
        andb  #$DF                       ; majuscules
        cmpb  #'A'
        beq   @auto
        cmpb  #'N'
        beq   @next
        cmpb  #'P'
        beq   @prev
        cmpb  #'I'
        beq   @instrNext
        cmpb  #'U'
        beq   @instrPrev
        lbra  @noKey
@play   clr   tester.auto
        jsr   tester.show
        jsr   tester.play
        lbra  @noKey
@auto   lda   tester.auto
        eora  #1
        sta   tester.auto
        beq   @redraw
        jsr   tester.autoFirst
        jsr   tester.show
        jsr   tester.play
        lbra  @noKey
@next   clr   tester.auto
        ldb   tester.sel
        incb
        cmpb  #corpus.count
        blo   >
        clrb
!       stb   tester.sel
        bra   @redraw
@prev   clr   tester.auto
        ldb   tester.sel
        decb
        bpl   >
        ldb   #corpus.count-1
!       stb   tester.sel
        bra   @redraw
@instrNext
        clr   tester.auto
        ldb   tester.instr               ; $FF (origine) -> 0 -> ... -> 15 -> $FF
        incb
        cmpb  #16
        blo   >
        ldb   #INSTR_ORIGINAL
!       stb   tester.instr
        bra   @redraw
@instrPrev
        clr   tester.auto
        ldb   tester.instr
        cmpb  #INSTR_ORIGINAL
        bne   >
        ldb   #16
!       decb
        stb   tester.instr
@redraw jsr   tester.show
@noKey
        ; le deroule automatique : au bout du son + un silence, le suivant
        lda   tester.auto
        lbeq  mainLoop
        lda   tester.wait
        beq   @advance
        deca
        sta   tester.wait
        lbra  mainLoop
@advance
        jsr   tester.autoNext
        jsr   tester.show
        jsr   tester.play
        lbra  mainLoop

; ------------------------------------------------------------------------------
; Le deroule auto : les sons du jeu (bit 1 des flags), dans l'ordre du corpus ;
; un son a instrument personnalise (bit 0) passe ensuite par les presets 1..15.
; ------------------------------------------------------------------------------
tester.autoFirst
        lda   #INSTR_ORIGINAL
        sta   tester.instr
        ldb   #corpus.count-1            ; autoNext part du suivant : se placer avant le premier
        stb   tester.sel
        bra   tester.autoNextSound
tester.autoNext
        ldb   tester.sel
        ldx   #corpus.flags
        lda   b,x
        anda  #1
        beq   tester.autoNextSound       ; pas d'instrument perso : son suivant
        lda   tester.instr
        cmpa  #INSTR_ORIGINAL
        bne   >
        lda   #0                         ; apres l'origine, le preset 1
!       inca
        cmpa  #16
        bhs   tester.autoNextSound
        sta   tester.instr
        rts
tester.autoNextSound
        lda   #INSTR_ORIGINAL
        sta   tester.instr
        ldb   tester.sel
@loop   incb
        cmpb  #corpus.count
        blo   >
        clrb
!       ldx   #corpus.flags
        lda   b,x
        bita  #2
        beq   @loop
        stb   tester.sel
        rts

; ------------------------------------------------------------------------------
; Jouer le son courant : le bloc est copie dans un tampon, l'instrument des
; commandes $30 remplace si demande, puis demande au pilote (son 0 = le tampon).
; ------------------------------------------------------------------------------
tester.play
        ldb   tester.sel
        ldx   #corpus.duration
        lda   b,x
        adda  #GAP
        sta   tester.wait
        ldx   #corpus.table
        aslb
        ldx   b,x                        ; X = le bloc
        ldu   #tester.buffer
        ldd   ,x++
        std   ,u++
        tsta
        beq   @done
        sta   @count
        ldb   tester.instr
        lslb
        lslb
        lslb
        lslb
        stb   @instr                     ; quartet haut = instrument, $F0 = origine
@copy   ldd   ,x                         ; registre, donnee
        cmpa  #$30
        bne   >
        pshs  b                          ; la donnee, que le test ne doit pas abimer
        ldb   tester.instr
        cmpb  #INSTR_ORIGINAL
        puls  b                          ; (puls ne touche pas CC)
        beq   >
        andb  #$0F                       ; le volume du bloc, l'instrument demande
        orb   #0
@instr  equ   *-1
!       std   ,u++
        lda   2,x
        sta   ,u+
        leax  3,x
        dec   @count
        bne   @copy
@done   ldd   #$007F                     ; son 0, priorite 127 : passe devant tout
        std   soundFX.newSound
        rts
@count  fcb   0

; ------------------------------------------------------------------------------
; L'ecran : trois lignes, reecrites entierement (le remplissage efface l'ancien)
; ------------------------------------------------------------------------------
tester.show
        ldx   #msg.sound
        jsr   monitor.print
        ldb   tester.sel
        ldx   #corpus.id
        ldb   b,x
        jsr   tester.printDec
        ldx   #msg.gap
        jsr   monitor.print
        ldb   tester.sel
        ldx   #corpus.name
        aslb
        ldx   b,x
        jsr   monitor.print
        ldx   #msg.pad
        jsr   monitor.print

        ldx   #msg.instr
        jsr   monitor.print
        ldb   tester.instr
        cmpb  #INSTR_ORIGINAL
        bne   >
        ldx   #msg.original
        jsr   monitor.print
        bra   @mode
!       jsr   tester.printDec
        ldx   #msg.gap
        jsr   monitor.print
        ldb   tester.instr
        ldx   #instr.name
        aslb
        ldx   b,x
        jsr   monitor.print
@mode   ldx   #msg.pad
        jsr   monitor.print
        ldx   #msg.mode
        jsr   monitor.print
        ldx   #msg.auto
        lda   tester.auto
        bne   >
        ldx   #msg.manual
!       jmp   monitor.print

; B = 0..255, en decimal sur trois chiffres (PUTC prend le caractere dans B,
; et rend X — monitor.print s'y fie — mais pas D : le reste est garde en pile)
tester.printDec
        lda   #100
        bsr   @digit
        lda   #10
        bsr   @digit
        addb  #'0'
        _monitor.jmp.putc
@digit  sta   tester.div
        clra
!       cmpb  tester.div
        blo   >
        subb  tester.div
        inca
        bra   <
!       pshs  b                          ; le reste, pour le chiffre suivant
        tfr   a,b
        addb  #'0'
        _monitor.jsr.putc
        puls  b,pc
tester.div fcb 0

; ------------------------------------------------------------------------------
; Le YM2413 a plat (la copie de engine/sound/ym2413.asm, en adressage etendu)
; ------------------------------------------------------------------------------
tester.ymInit
        ldd   #$200E
        stb   YM2413.A
        nop
        ldb   #0
        sta   YM2413.D                   ; note off des percussions
        lda   #$20
        brn   *
@c      exg   a,b
        exg   a,b
        sta   YM2413.A
        nop
        inca
        stb   YM2413.D
        cmpa  #$29
        bne   @c
        rts

; ------------------------------------------------------------------------------
userIRQ
        inc   tester.frame
        lda   #$E7                       ; la page des registres : le pilote ecrit <YM2413.A
        tfr   a,dp
        jmp   soundFX.playIRQ

; ------------------------------------------------------------------------------
tester.frame  fcb   0
tester.sel    fcb   0
tester.instr  fcb   INSTR_ORIGINAL
tester.auto   fcb   1
tester.wait   fcb   0

msg.screen    fcb   $0C                  ; efface l'ecran
              fcb   $1F,$40+2,$40+2
              fcc   "SFX TESTER - R-TYPE SUR YM2413"
              fcb   $1F,$40+13,$40+2
              fcc   "ESPACE JOUER  N/P SON  I/U INSTRUMENT"
              fcb   $1F,$40+14,$40+2
              fcc   "A AUTO/MANUEL  INSTRUMENT 0 = PERSO"
              fcb   $1F,$40+16,$40+2
              fcc   "SONS DU JEU, PUIS 15 PRESETS POUR CEUX"
              fcb   $1F,$40+17,$40+2
              fcc   "QUI JOUENT SUR L'INSTRUMENT PERS"
              fcb   'O'+$80
msg.sound     fcb   $1F,$40+ROW_SOUND,$40+2
              fcc   "SON  "
              fcb   ' '+$80
msg.instr     fcb   $1F,$40+ROW_INSTR,$40+2
              fcc   "INSTRUMENT  "
              fcb   ' '+$80
msg.mode      fcb   $1F,$40+ROW_MODE,$40+2
              fcc   "MODE  "
              fcb   ' '+$80
msg.gap       fcc   " "
              fcb   ' '+$80
msg.pad       fcc   "                  "
              fcb   ' '+$80
msg.original  fcc   "D'ORIGIN"
              fcb   'E'+$80
msg.auto      fcc   "AUTO  "
              fcb   ' '+$80
msg.manual    fcc   "MANUE"
              fcb   'L'+$80

; les instruments de la ROM du YM2413 (0 = le personnalise, registres $00-$07)
instr.name    fdb   in.0,in.1,in.2,in.3,in.4,in.5,in.6,in.7
              fdb   in.8,in.9,in.10,in.11,in.12,in.13,in.14,in.15
in.0   fcc "PERSONNALIS"
       fcb 'E'+$80
in.1   fcc "VIOLO"
       fcb 'N'+$80
in.2   fcc "GUITAR"
       fcb 'E'+$80
in.3   fcc "PIAN"
       fcb 'O'+$80
in.4   fcc "FLUT"
       fcb 'E'+$80
in.5   fcc "CLARINETT"
       fcb 'E'+$80
in.6   fcc "HAUTBOI"
       fcb 'S'+$80
in.7   fcc "TROMPETT"
       fcb 'E'+$80
in.8   fcc "ORGU"
       fcb 'E'+$80
in.9   fcc "CO"
       fcb 'R'+$80
in.10  fcc "SYNTH"
       fcb 'E'+$80
in.11  fcc "CLAVECI"
       fcb 'N'+$80
in.12  fcc "VIBRAPHON"
       fcb 'E'+$80
in.13  fcc "BASSE SYNTH"
       fcb 'E'+$80
in.14  fcc "BASSE ACOUSTIQU"
       fcb 'E'+$80
in.15  fcc "GUITARE ELECTRIQU"
       fcb 'E'+$80

; ------------------------------------------------------------------------------
; Le pilote de bruitage du jeu, tel quel, et ce qu'il attend de son hote :
; la boite aux lettres et la table des sons — ici un seul son, le tampon.
; ------------------------------------------------------------------------------
soundFX.curSound   fdb   $FF00
soundFX.newSound   fdb   $FF00
soundFX.soundTable fdb   tester.buffer
        INCLUDE "engine/sound/soundFX.asm"

tester.buffer      rmb   512

        INCLUDE "src/corpus.asm"

 ENDSECTION

        INCLUDE "engine/global/glb.init.asm"
        INCLUDE "engine/system/to8/irq/irq.asm"
        INCLUDE "engine/system/to8/controller/keyboard.asm"
        INCLUDE "engine/system/thomson/monitor/monitor.print.asm"
