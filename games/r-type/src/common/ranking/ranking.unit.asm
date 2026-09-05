;*******************************************************************************
; LE CLASSEMENT — l'état qui survit à tout, et les gestes qui l'entretiennent
;
; Trois choses vivent ici : la table des dix meilleurs scores, le score obtenu
; dans chaque stage de la partie en cours, et le rang que le dernier game over
; a décroché. Les écrans qui les montrent (STAGE SCORE, saisie des initiales,
; RANKING) viendront dans cette même unité — voir doc/plan-game-over-ranking.md.
;
; OÙ ELLE VIT, ET POURQUOI LÀ. Dans la queue de la demi-page de l'OST
; ($00 tranche 1, $51C0), c'est-à-dire de la RAM stable montée en permanence
; sous `OverlayMode`. Deux exigences s'y rencontrent :
;
;   - la table doit SURVIVRE à l'échange de scènes. Une partie finit dans un
;     stage, le classement s'écrit, puis la scène du title écrase la région du
;     stage : une table logée là serait perdue. Ici, rien ne la touche.
;   - le code doit rester atteignable quelle que soit la page en fenêtre
;     cartouche, puisque le moteur résident l'appelle depuis le game over.
;
; Cette place n'existait pas hier : les `<reserved objects.*>` comptaient
; 117 octets par objet là où l'overlay en met 63, et sur-réservaient 3 456
; octets que rien n'occupait (corrigé le 04/09/2026, voir to8.config.xml).
;
; ELLE N'EST CHARGÉE QU'UNE FOIS, par `scenes.boot`, présente dans toutes les
; compositions : la déduplication du loader fait que jamais une convergence ne
; la relit. C'est ce qui dispense d'un mot magique — le contenu initial est
; celui du binaire, les dix entrées par défaut de la borne, et il ne revient
; pas d'entre les morts à chaque écran.
;
; PAS DE SAUVEGARDE, comme la borne : le loader ne sait pas écrire, la table
; repart des défauts à chaque mise sous tension et survit aux parties tant que
; la machine reste allumée.
;
; LE FORMAT. Un score tient sur 3 octets, par CENTAINES de points et poids fort
; en tête — le format de `globals.score`, pour comparer et recopier sans
; conversion. Un nom fait 7 caractères, comme la borne. Une entrée fait donc
; 10 octets, et la table 100.
;*******************************************************************************

ranking.insert     EXPORT
ranking.reset      EXPORT
ranking.stageAdd   EXPORT
ranking.table      EXPORT
ranking.stage      EXPORT
ranking.rank       EXPORT
ranking.screen     EXPORT
text.recolor       EXPORT              ; réemployables : voir leurs notices
text.hiliteLine    EXPORT
ranking.digits7    EXPORT
ranking.dig        EXPORT

; Le stage courant moins un, tenu par le moteur résident : il traverse le
; changement de scène, donc il est le seul à savoir dans quel stage on meurt.
game.stage         EXTERNAL

; LA POLICE ET SES OUTILS vivent dans la page du HUD. L'ecran la monte le temps
; de peindre : son propre code est dans la demi-page video, toujours montee, il
; ne se perd donc pas en changeant la fenetre cartouche.
hud.drawStr        EXTERNAL
letter_addr        EXTERNAL
numbers_addr       EXTERNAL
DRAW_text_space    EXTERNAL
ScoreToDigits      EXTERNAL
hud.scoreWork      EXTERNAL
; L'effacement des tampons, et le relais de page.
checkpoint.clearData EXTERNAL
paged.call         EXTERNAL
; La palette : celle du stage. La police y prend les index 3 a 6, identiques
; sur les huit stages — le texte a donc le meme rendu partout.
Pal_stage          EXTERNAL
Pal_current        EXTERNAL
PalRefresh         EXTERNAL
PalUpdateNow       EXTERNAL
; La manette et la boite aux lettres des bruitages : la saisie ne lit que le
; port 0 et n'emploie que des sons deja portes.
joypad.readKbd     EXTERNAL
joypad.pressed.dpad EXTERNAL
joypad.held.dpad   EXTERNAL
joypad.pressed.fire EXTERNAL
soundFX.newSound   EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "gen/layout.asm"
        INCLUDE "engine/system/to8/controller/joypad.const.asm"
        INCLUDE "src/common/fx/soundfx/soundFX.const.asm"
        INCLUDE "src/common/state/variables.asm"

ranking.ENTRY  equ 10                  ; 3 octets de score + 7 de nom
ranking.SLOTS  equ 10                  ; les dix rangs
ranking.STAGES equ 16                  ; deux tours de huit stages

;-------------------------------------------------------------------------------
; ranking.insert — classer le score de la partie qui vient de finir
;
; sortie : [b] le rang obtenu, 1..10, ou 0 si le score n'entre pas
;          ranking.rank porte la même valeur
;
; L'ÉGALITÉ NE CLASSE PAS, comme la borne : il faut être strictement meilleur
; que l'entrée pour lui prendre sa place. Le dernier des dix est perdu.
;-------------------------------------------------------------------------------
ranking.insert
        ldx   #ranking.table
        lda   #1
        sta   ranking.rank
@scan
        ldd   globals.score            ; les deux octets de poids fort
        cmpd  ,x
        bhi   @insert
        bne   @next                    ; strictement moindre : rang suivant
        ldb   globals.score+2          ; égalité sur 16 bits : l'octet faible
        cmpb  2,x
        bhi   @insert
@next
        leax  ranking.ENTRY,x
        inc   ranking.rank
        lda   ranking.rank
        cmpa  #ranking.SLOTS+1
        blo   @scan
        clr   ranking.rank             ; battu par les dix : pas classé
        clrb
        rts
;                          (pas de ligne vide : elle fermerait la portée des @)
@insert
        ; X pointe l'entrée à occuper. Pousser vers le bas celles qui suivent,
        ; À REBOURS — une copie en avant écraserait sa propre source.
        pshs  x
        lda   #ranking.SLOTS
        suba  ranking.rank             ; entrées à pousser (0 si rang 10)
        beq   @write
        ldb   #ranking.ENTRY
        mul                            ; D = octets à déplacer
        tfr   d,y
        ldu   #ranking.table+ranking.SLOTS*ranking.ENTRY      ; après la fin
        ldx   #ranking.table+(ranking.SLOTS-1)*ranking.ENTRY  ; après l'avant-dernière
@shift
        lda   ,-x
        sta   ,-u
        leay  -1,y
        bne   @shift
@write
        puls  x
        ldd   globals.score
        std   ,x
        lda   globals.score+2
        sta   2,x
        leax  3,x
        lda   #' '                     ; le nom part vide : la saisie le remplira
        ldb   #7
@blank
        sta   ,x+
        decb
        bne   @blank
        ldb   ranking.rank
        rts

;-------------------------------------------------------------------------------
; ranking.reset — la table par stage repart à zéro
;
; entrée : [b] le premier stage du crédit, 0..15 — le récapitulatif du prochain
;              game over partira de là, comme la borne qui ne montre que les
;              stages joués depuis le dernier continue (relevé de l'auteur).
;
; Appelée au SEMIS D'UNE PARTIE FRAÎCHE et au CONTINUE ACCEPTÉ, là où le score
; repart de zéro : ces seize cases décrivent UN crédit, pas la machine.
;-------------------------------------------------------------------------------
ranking.reset
        stb   ranking.firstStage       ; B = le premier stage du crédit (0..15)
        ldx   #ranking.stage
        ldd   #0
@z      std   ,x++
        cmpx  #ranking.stage+ranking.STAGES*3
        blo   @z
        clr   ranking.rank
        rts

;-------------------------------------------------------------------------------
; ranking.stageAdd — cumuler une récompense dans la case du stage courant
;
; entrée : [d] la récompense, en centaines de points
;          game.stage = le stage courant moins un
;
; C'EST LE GESTE DE LA BORNE, et il vaut mieux que celui qu'il remplace.
; `update_current_stage_score` (arcade 0xE8BD) ajoute la MÊME récompense au
; score courant ET à la case du stage, à chaque point marqué. Ranger le score
; d'un stage à sa CLÔTURE, comme on le faisait d'abord, laissait à zéro le
; stage où le joueur MEURT — or c'est précisément celui-là que le
; récapitulatif montre après un game over, et un « 1 STAGE 0 » sous un total
; non nul n'a aucun sens (relevé par l'auteur, 04/09/2026).
;
; D et X sont rendus intacts : l'appelant est AwardScore, qui les tient.
;-------------------------------------------------------------------------------
ranking.stageAdd
        pshs  d,x
        ldb   game.stage
        cmpb  #ranking.STAGES
        bhs   @out                     ; hors table : on ne cumule rien
        lda   #3
        mul
        ldx   #ranking.stage
        leax  d,x                      ; X = la case du stage courant
        ldd   ,s                       ; la récompense, sauvée à l'entrée
        addd  1,x
        std   1,x
        bcc   @out
        inc   ,x                       ; la retenue vers l'octet de poids fort
@out    puls  d,x,pc


;-------------------------------------------------------------------------------
; ranking.screen — l'écran STAGE SCORE
;
; La géométrie est celle de la borne mise à l'échelle du portage : 0,75 en Y
; (16 px d'écart deviennent 12), et 10 px de décalage pour centrer les 180 px
; de terrain arcade dans nos 200. Les ancres sont donc y_arcade*0,75+10, plus
; trois lignes : la police écrit de U-120 à U+160, son point d'ancrage est au
; MILIEU du glyphe et non en haut.
;
; LES DEUX TAMPONS SONT PEINTS À L'IDENTIQUE. Rien n'arme d'échange ici (pas de
; `gfxlock.on`), donc le tampon affiché est celui que la séquence de mort a
; laissé — on ne sait pas lequel, et on n'a pas à le savoir.
;-------------------------------------------------------------------------------
ranking.SCR_TITLE equ $C000+37*40+10   ; « S T A G E   S C O R E », 21 cellules
ranking.SCR_LEFT  equ $C000+55*40+3    ; premier emplacement, colonne gauche
ranking.SCR_RIGHT equ $C000+55*40+22   ; premier emplacement, colonne droite
ranking.SCR_PITCH equ 12*40            ; 12 px entre deux lignes
ranking.SCR_ENTER equ $C000+163*40+8
ranking.SCR_NO    equ $C000+175*40+14   ; « NO.n » — reculé d'une cellule le
                                       ;   04/09 : deux cases vides le séparent
                                       ;   désormais de la première lettre
ranking.SCR_CELL  equ $C000+175*40+21  ; la première case de saisie

ranking.screen
        _GetCartPageB
        pshs  b                        ; la page de l'appelant, rendue en sortie
        ; LA PALETTE DE TRAVAIL : celle du stage — ses index 0 à 11 sont les
        ; mêmes sur les huit stages, la police y prend le blanc (3) et trois
        ; bleus (4 à 6) — plus DEUX ROUGES en 12 et 13, des entrées que rien
        ; de ces écrans n'emploie. Aucun rouge n'existe parmi les communs, et
        ; le curseur de saisie clignote blanc/rouge (décision auteur, 04/09).
        ldx   #Pal_stage
        ldu   #ranking.pal
@pal    ldd   ,x++                     ; D = A:B — pas de compteur en B ici
        std   ,u++
        cmpu  #ranking.pal+32
        blo   @pal
        ldd   #$0E00                   ; 12 : rouge vif   (250,0,0)
        std   ranking.pal+24
        ldd   #$0400                   ; 13 : rouge sombre (158,0,0)
        std   ranking.pal+26
        ldd   #ranking.pal
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow
        _ram.data.set #2
        jsr   ranking.scr.clear2
        lda   #map.RAM_OVER_CART+common.hud.page
        _SetCartPageA                  ; la police, pour toute la suite
        jsr   ranking.scr.reveal       ; le texte apparaît, au rythme de la borne
        jsr   ranking.input
        jsr   ranking.tableScreen      ; puis le tableau des dix
        puls  b
        _SetCartPageB
        rts
;
; LA RÉVÉLATION, AU RYTHME DE LA BORNE (04/09/2026, relevé dans le code arcade)
;
;   `run_high_score_name_entry_setup` 0x1515 arme une ligne par stage, chacune
;   avec un compte à rebours `+0x20` valant 0x20 puis +8 par ligne ;
;   `run_high_score_row_render` 0x188E construit alors la ligne de 16 cases
;   (libellé de 8, une espace, 7 chiffres) et passe la main à
;   `run_high_score_row_tile_streamer` 0x18EB, qui écrit UNE case par trame ;
;   les chaînes fixes passent par `run_high_score_row_streamer` 0x19D3, qui en
;   écrit TROIS par trame.
;
; Ici, pas d'objets : un pilote de trame sans état par ligne. La case due se
; DÉDUIT du numéro de trame — la ligne i tient les trames 32+8i à 32+8i+15 —
; ce qui donne le chevauchement de la borne (deux lignes se remplissent en même
; temps) sans table d'objets. Chaque case est peinte DANS LES DEUX TAMPONS,
; comme le curseur de saisie : rien ne redessine derrière nous.
ranking.TITLE_N   equ 21                ; « S T A G E   S C O R E »
ranking.ENTER_N   equ 20                ; « ENTER YOUR INITIALS. »
ranking.BOT_N     equ 32                ; 20 + « NO.n » 5 + 7 tirets
ranking.RATE      equ 3                 ; cases par trame d'une chaîne fixe
ranking.ROW_START equ 32                ; trames avant la première ligne
ranking.ROW_STEP  equ 8                 ; une ligne de plus toutes les huit
ranking.ROW_N     equ 16                ; cases d'une ligne, une par trame

ranking.scr.clear2
        ldu   #$0000                   ; les deux tampons au noir
        lda   #map.RAM_OVER_CART+common.checkpoint.page
        ldx   #checkpoint.clearData
        jsr   paged.call
        _SwitchScreenBuffer
        ldu   #$0000
        lda   #map.RAM_OVER_CART+common.checkpoint.page
        ldx   #checkpoint.clearData
        jsr   paged.call
        _SwitchScreenBuffer
        rts

ranking.scr.reveal
        lda   game.stage               ; les lignes : les stages du crédit…
        cmpa  #ranking.STAGES-1
        blo   >
        lda   #ranking.STAGES-1
!       suba  ranking.firstStage
        inca
        inca                           ; …plus celle du TOTAL
        sta   ranking.scr.rows
        deca                           ; les textes du bas suivent la dernière
        ldb   #ranking.ROW_STEP        ;   ligne : 0x40 + 8*(lignes-1)
        mul
        addd  #64
        std   ranking.scr.bot
        addd  #(ranking.BOT_N+ranking.RATE-1)/ranking.RATE
        std   ranking.scr.end
        lda   ranking.rank             ; « NO.n », le rang de la partie
        jsr   ranking.tbl.rankLabel
        ldd   #0
        std   ranking.scr.f
@frame  _waitFrames #1
        jsr   ranking.scr.stepTitle
        jsr   ranking.scr.stepRows
        jsr   ranking.scr.stepBottom
        ldd   ranking.scr.f
        addd  #1
        std   ranking.scr.f
        cmpd  ranking.scr.end
        blo   @frame
        rts

ranking.scr.stepTitle
        lda   ranking.scr.f            ; le titre tient les sept premières
        bne   @out                     ;   trames : le poids fort suffit
        lda   ranking.scr.f+1
        cmpa  #(ranking.TITLE_N+ranking.RATE-1)/ranking.RATE
        bhs   @out
        ldb   #ranking.RATE
        mul                            ; B = la première case due
        ldx   #ranking.str.title
        ldu   #ranking.SCR_TITLE
        lda   #ranking.TITLE_N
        jmp   ranking.scr.emit3
@out    rts

; X = chaîne, U = début écran, B = première case due, A = cases de la chaîne
; -> jusqu'à trois cases peintes
ranking.scr.emit3
        sta   ranking.e.cnt
        stb   ranking.e.idx
        stx   ranking.e.src
        stu   ranking.e.dst
        ldb   #ranking.RATE
@loop   lda   ranking.e.idx
        cmpa  ranking.e.cnt
        bhs   @out
        pshs  b
        ldx   ranking.e.src
        lda   a,x                      ; le caractère
        ldu   ranking.e.dst
        ldb   ranking.e.idx
        leau  b,u
        jsr   ranking.scr.cell
        inc   ranking.e.idx
        puls  b
        decb
        bne   @loop
@out    rts

; A = caractère, U = adresse -> peint DANS LES DEUX TAMPONS
ranking.scr.cell
        pshs  a,u
        jsr   ranking.in.glyph
        _SwitchScreenBuffer
        puls  a,u
        jsr   ranking.in.glyph
        _SwitchScreenBuffer
        rts

ranking.scr.stepRows
        clr   ranking.scr.i
@row    lda   ranking.scr.i
        cmpa  ranking.scr.rows
        bhs   @out
        ldb   #ranking.ROW_STEP
        mul                            ; D = 8i
        addd  #ranking.ROW_START
        pshs  a,b
        ldd   ranking.scr.f
        subd  ,s++
        bmi   @next                    ; la ligne n'a pas commencé
        cmpd  #ranking.ROW_N
        bhs   @next                    ; elle est finie
        pshs  b                        ; LA CASE DUE, 0..15, TENUE SUR LA PILE :
        tstb                           ;   rowLabel et rowDigits écrasent B
        bne   >
        jsr   ranking.scr.rowLabel     ; sa case zéro : le libellé
!       ldb   ,s
        cmpb  #9
        bne   >
        jsr   ranking.scr.rowDigits    ; sa première case de chiffre
!       lda   ranking.scr.i
        jsr   ranking.scr.slotU        ; U = l'emplacement de la ligne
        puls  b
        leau  b,u
        jsr   ranking.scr.rowChar
        jsr   ranking.scr.cell
@next   inc   ranking.scr.i
        bra   @row
@out    rts

; DEUX TAMPONS SUFFISENT, ET AUCUN N'EST À PART. Deux lignes se remplissent en
; même temps, décalées de huit cases : quand l'une en est à ses CHIFFRES
; (cases 9 à 15) l'autre en est à son LIBELLÉ (0 à 7). Le libellé de l'une ne
; croise donc jamais celui de l'autre, ni les chiffres les chiffres — la chaîne
; de libellé et le tampon de chiffres déjà en place se partagent sans conflit.
; C'est le chevauchement de la borne, sans une ligne de RAM de plus. Le libellé
; du TOTAL écrase « NN STAGE » : il est la DERNIÈRE ligne, aucune ligne de
; stage ne le suit.
ranking.scr.rowLabel
        lda   ranking.scr.i
        inca
        cmpa  ranking.scr.rows
        bne   @stage
        ldy   #ranking.str.total
        ldx   #ranking.str.stage
        ldb   #8
@c      lda   ,y+
        sta   ,x+
        decb
        bne   @c
        rts
@stage  lda   ranking.firstStage
        adda  ranking.scr.i
        inca                           ; le numéro affiché : 1..16
        ldb   #' '
        cmpa  #10
        blo   >
        ldb   #'1'
        suba  #10
!       stb   ranking.str.stage
        adda  #'0'
        sta   ranking.str.stage+1
        rts

ranking.scr.rowDigits
        lda   ranking.scr.i
        inca
        cmpa  ranking.scr.rows
        bne   @sc
        ldx   #globals.score           ; la dernière ligne : le TOTAL
        bra   @conv
@sc     lda   ranking.firstStage
        adda  ranking.scr.i
        jsr   ranking.scr.stagePtr
@conv   jmp   ranking.digits7

; B = case 0..15 -> A = son caractère : libellé, espace, puis les chiffres
ranking.scr.rowChar
        cmpb  #8
        blo   @label
        beq   @space
        subb  #9
        ldx   #ranking.dig
        lda   b,x
        cmpa  #$FF
        bne   >
        lda   #' '-'0'                 ; un zéro de tête : une espace
!       adda  #'0'
        rts
@space  lda   #' '
        rts
@label  ldx   #ranking.str.stage
        lda   b,x
        rts

ranking.scr.stepBottom
        ldd   ranking.scr.f
        subd  ranking.scr.bot
        bmi   @out                     ; le bas n'a pas commencé
        tsta
        bne   @out
        lda   #ranking.RATE
        mul                            ; B = la première case due
        stb   ranking.e.idx
        ldb   #ranking.RATE
@loop   lda   ranking.e.idx
        cmpa  #ranking.BOT_N
        bhs   @out
        pshs  b
        jsr   ranking.scr.botCell
        inc   ranking.e.idx
        puls  b
        decb
        bne   @loop
@out    rts

; A = case 0..31 du bas : l'invite, puis « NO.n », puis les sept tirets
ranking.scr.botCell
        cmpa  #ranking.ENTER_N
        bhs   @no
        ldx   #ranking.str.enter
        ldu   #ranking.SCR_ENTER
        leau  a,u
        lda   a,x
        jmp   ranking.scr.cell
@no     suba  #ranking.ENTER_N
        cmpa  #5
        bhs   @dash
        ldx   #ranking.str.no2
        ldu   #ranking.SCR_NO
        leau  a,u
        lda   a,x
        jmp   ranking.scr.cell
@dash   suba  #5
        asla                           ; une cellule vide entre deux cases
        ldu   #ranking.SCR_CELL
        leau  a,u
        lda   #'-'
        jmp   ranking.scr.cell

; slot (A, 0..16) -> U. Les huit premiers à gauche, les neuf suivants à droite :
; le dix-septième est celui où le TOTAL tombe quand la partie a fait tout le
; tour, exactement comme la borne.
ranking.scr.slotU
        ldu   #ranking.SCR_LEFT
        cmpa  #8
        blo   >
        suba  #8
        ldu   #ranking.SCR_RIGHT
!       tsta
        beq   @done
        ldb   #ranking.SCR_PITCH/8     ; le pas tient sur un octet une fois /8
        mul
        aslb                           ; *8 : le pas complet, sur 16 bits
        rola
        aslb
        rola
        aslb
        rola
        leau  d,u
@done   rts
;
; A = slot (0..15) -> X = &ranking.stage[slot]
ranking.scr.stagePtr
        ldb   #3
        mul
        ldx   #ranking.stage
        leax  d,x
        rts
;
; X = trois octets de score -> sept chiffres peints à U, zéros de tête blanchis,
; U avancé de 7. La conversion est résidente et partagée avec le title.
ranking.scr.digits7
        jsr   ranking.digits7
        ldx   #ranking.dig
        ldb   #7
@d      lda   ,x+
        pshs  b,x
        cmpa  #$FF
        beq   @blank
        asla
        ldy   #numbers_addr
        jsr   [a,y]
        bra   @next
@blank  jsr   DRAW_text_space
@next   puls  b,x
        leau  1,u
        decb
        bne   @d
        rts



;-------------------------------------------------------------------------------
; ranking.input — la saisie des sept initiales
;
; L'alphabet et les gestes sont ceux de la borne (run_high_score_name_entry_input,
; 0x1660) : trente-quatre entrées — vingt-six lettres, six signes, RUB puis END —
; que gauche et droite font défiler en bouclant aux deux bouts, un bouton qui
; valide, une limite de temps, et la lettre en cours qui clignote.
;
; DEUX ÉCARTS ASSUMÉS. La borne fait clignoter la lettre en alternant DEUX
; palettes ; notre police écrit des index fixes, donc on alterne la lettre et le
; tiret de la case vide — le clignotement dit la même chose. Et les bruitages
; sont ceux du jeu, pas ceux de la borne : convertir les siens est un chantier à
; part.
;
; LES DEUX TAMPONS SONT PEINTS À CHAQUE FOIS, comme le reste de l'écran : rien
; n'arme d'échange, on ne sait pas lequel est affiché.
;-------------------------------------------------------------------------------
ranking.IN_LIMIT  equ 2048             ; trames — la limite de la borne ($800)
ranking.IN_REPEAT equ 12               ; trames tenues avant que ça défile seul
ranking.IN_BLINK  equ 8                ; demi-période du clignotement
ranking.IN_HOLD   equ 64               ; tenue de l'écran une fois le nom posé
ranking.ALPHA_RUB equ 32
ranking.ALPHA_END equ 33
ranking.ALPHA_NB  equ 34

ranking.input
        clr   ranking.in.cursor
        clr   ranking.in.alpha
        clr   ranking.in.hold
        clr   ranking.in.frame
        ldd   #ranking.IN_LIMIT
        std   ranking.in.timer
@loop
        _waitFrames #1
        inc   ranking.in.frame
        ldd   ranking.in.timer
        subd  #1
        std   ranking.in.timer
        lbeq  @finish                  ; le temps est écoulé
        lda   ranking.in.cursor
        cmpa  #7
        lbhs  @finish                  ; les sept lettres sont posées
        jsr   ranking.in.blink
        jsr   joypad.readKbd
        lda   joypad.pressed.fire
        anda  #joypad.0.FIRE
        bne   @commit
        lda   joypad.pressed.dpad      ; une pression franche défile d'un cran
        anda  #joypad.0.LEFT|joypad.0.RIGHT
        bne   @step
        lda   joypad.held.dpad         ; tenue : ça défile après le seuil
        anda  #joypad.0.LEFT|joypad.0.RIGHT
        beq   @noHold
        inc   ranking.in.hold
        ldb   ranking.in.hold
        cmpb  #ranking.IN_REPEAT
        blo   @loop
        clr   ranking.in.hold
        bra   @step
@noHold clr   ranking.in.hold
        bra   @loop
@step
        clr   ranking.in.hold
        bita  #joypad.0.RIGHT
        beq   @left
        lda   ranking.in.alpha
        inca
        cmpa  #ranking.ALPHA_NB
        blo   @setAlpha
        clra                           ; ça boucle, comme la borne
        bra   @setAlpha
@left
        lda   ranking.in.alpha
        bne   @dec
        lda   #ranking.ALPHA_NB
@dec    deca
@setAlpha
        sta   ranking.in.alpha
        ldd   #(soundFX.FireSound<<8)|1
        std   soundFX.newSound
        bra   @loop
@commit
        lda   ranking.in.alpha
        cmpa  #ranking.ALPHA_END
        beq   @finish
        cmpa  #ranking.ALPHA_RUB
        beq   @rub
        jsr   ranking.in.letter        ; A = le caractère choisi
        pshs  a
        jsr   ranking.in.store         ; il entre dans le nom
        puls  a
        jsr   ranking.in.paintCursor   ; et se fige dans sa case
        inc   ranking.in.cursor
        clr   ranking.in.alpha
        ldd   #(soundFX.BonusSound<<8)|1
        std   soundFX.newSound
        lbra  @loop
@rub
        lda   #'-'                     ; la case quittée redevient vide
        jsr   ranking.in.paintCursor
        clr   ranking.in.alpha
        lda   ranking.in.cursor
        beq   @rubStore
        deca
        sta   ranking.in.cursor
@rubStore
        lda   #' '                     ; et l'octet du nom avec elle
        jsr   ranking.in.store
        ldd   #(soundFX.BonusSound<<8)|1
        std   soundFX.newSound
        lbra  @loop
@finish
        lda   ranking.in.cursor        ; la case clignotante ne reste pas
        cmpa  #7                       ;   allumée sur un abandon
        bhs   @done
        lda   #'-'
        jsr   ranking.in.paintCursor
@done
        ldd   #(soundFX.ExtraLifeSound<<8)|1
        std   soundFX.newSound
        _waitFrames #ranking.IN_HOLD
        rts
;
; le clignotement : la lettre candidate, BLANCHE une demi-période et ROUGE
; l'autre (décision auteur, 04/09/2026 — l'alternance lettre/tiret d'avant
; lisait mal). La lettre est peinte puis recoloriée par table, dans les deux
; tampons : c'est `text.recolor`, écrit pour être réemployé ailleurs.
ranking.in.blink
        lda   ranking.in.alpha
        jsr   ranking.in.letter
        jsr   ranking.in.paintCursor
        ldx   #text.map.white
        lda   ranking.in.frame
        anda  #ranking.IN_BLINK
        beq   >
        ldx   #text.map.red
!       ldb   ranking.in.cursor
        jsr   ranking.in.cursorU       ; U = la case
        pshs  u,x
        jsr   text.recolor
        puls  u,x
        _SwitchScreenBuffer
        pshs  u,x
        jsr   text.recolor
        puls  u,x
        _SwitchScreenBuffer
        rts
;
; B = index de case (0..6) -> U = son adresse écran ; A préservé
ranking.in.cursorU
        aslb                           ; une cellule vide entre deux cases
        ldu   #ranking.SCR_CELL
        leau  b,u
        rts
;
; index d'alphabet (A) -> caractère (A)
ranking.in.letter
        ldx   #ranking.alpha
        lda   a,x
        rts
;
; peindre le caractère A dans la case du curseur, DANS LES DEUX TAMPONS
ranking.in.paintCursor
        ldb   ranking.in.cursor
        jsr   ranking.in.cursorU
        pshs  a,u
        jsr   ranking.in.glyph
        puls  a,u
        _SwitchScreenBuffer
        pshs  u
        jsr   ranking.in.glyph
        puls  u
        _SwitchScreenBuffer
        rts
;
; peindre le caractère A à l'adresse U. Les six signes que la police du HUD n'a
; pas sont dessinés par les glyphes générés plus bas ; tout le reste passe par
; sa table.
ranking.in.glyph
        cmpa  #'<'
        beq   @lt
        cmpa  #':'
        beq   @colon
        cmpa  #'-'
        beq   @dash
        cmpa  #','
        beq   @comma
        cmpa  #'>'
        beq   @gt
        cmpa  #'?'
        beq   @quest
        suba  #32
        asla
        ldx   #letter_addr
        jmp   [a,x]
@lt     jmp   DRAW_text_lt
@colon  jmp   DRAW_text_colon
@dash   jmp   DRAW_text_dash
@comma  jmp   DRAW_text_comma
@gt     jmp   DRAW_text_gt
@quest  jmp   DRAW_text_question
;
; ranger le caractère A dans le nom de l'entrée qu'on vient de classer
ranking.in.store
        pshs  a
        lda   ranking.rank
        deca
        ldb   #ranking.ENTRY
        mul
        ldx   #ranking.table+3         ; +3 : le nom suit les trois octets du score
        leax  d,x
        ldb   ranking.in.cursor
        abx
        puls  a
        sta   ,x
        rts

; L'ALPHABET, celui de la borne (ROM 0x1000:0B5C) : vingt-six lettres, six
; signes, puis RUB et END — deux commandes, pas des caractères.
ranking.alpha
        fcc   'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        fcc   '!?>.,-'
        fcc   '<:'
ranking.in.cursor fcb 0
ranking.in.alpha  fcb 0
ranking.in.hold   fcb 0
ranking.in.frame  fcb 0
ranking.in.timer  fdb 0


;-------------------------------------------------------------------------------
; ranking.digits7 — un score de trois octets en sept chiffres d'affichage
;
; entrée : [x] trois octets, centaines de points, poids fort en tête
; sortie : ranking.dig[0..6] — cinq chiffres significatifs puis les deux zéros
;          de la centaine. Les zéros de tête valent $FF, à blanchir au dessin,
;          et le blanchiment couvre SIX des sept : un score nul s'affiche « 0 »
;          et non « 000 ».
;
; ELLE EST RÉSIDENTE ET PARTAGÉE. L'écran de fin de partie et le tableau
; d'attract du title ont chacun leur police, dans leur page à eux, mais la
; conversion est la même : elle vit ici, ils dessinent chez eux. Le title ne
; savait faire que seize bits (`DisplayDigit`), ce qui plafonnait ses lignes à
; 6 553 500 points quand notre score en autorise 9 999 900.
;-------------------------------------------------------------------------------
ranking.digits7
        ldd   ,x
        std   ranking.dg.work
        lda   2,x
        sta   ranking.dg.work+2
        ldy   #ranking.dig
        ldx   #ranking.dg.pow
@digit  clr   ,y
@sub    ldd   ranking.dg.work+1
        subd  ,x
        std   ranking.dg.work+1
        lda   ranking.dg.work
        sbca  #0
        sta   ranking.dg.work
        bcs   @back                    ; passé sous zéro : un de trop
        inc   ,y
        bra   @sub
@back   ldd   ranking.dg.work+1        ; rendre ce qu'on a pris de trop
        addd  ,x
        std   ranking.dg.work+1
        lda   ranking.dg.work
        adca  #0
        sta   ranking.dg.work
        leay  1,y
        leax  2,x
        cmpx  #ranking.dg.pow+10
        blo   @digit
        clr   ranking.dig+5            ; les deux zéros de la centaine
        clr   ranking.dig+6
        ldx   #ranking.dig             ; les zéros de tête, jamais le dernier
        ldb   #6
@bl     lda   ,x
        bne   @out
        lda   #$FF
        sta   ,x+
        decb
        bne   @bl
@out    rts
ranking.dg.pow  fdb 10000,1000,100,10,1
ranking.dg.work fcb 0,0,0
ranking.dig     fcb 0,0,0,0,0,0,0


;-------------------------------------------------------------------------------
; ranking.tableScreen — le tableau des dix, juste après la saisie
;
; Même mise en page que le tableau d'attract du title (titre ligne 6 colonne 14,
; rangs tous les 14 px depuis la ligne 36, score colonne 17, nom colonne 27) :
; les deux écrans se suivent à quelques secondes, ils doivent se ressembler.
;
; DEUX RENDUS, ET C'EST LA FORME DU JEU QUI L'IMPOSE. Le title dessine le sien
; avec des objets et sa propre police, dans sa page ; celui-ci vit dans l'unité
; résidente et emprunte la police du HUD, parce que la page du title n'est pas
; chargée quand un stage tourne. Ce qu'ils partagent — la table, la conversion
; des chiffres, la mise en page — est écrit une fois.
;
; L'ENTRÉE NOUVELLE EST RECOLORIÉE, comme la borne la peint dans une autre
; palette : la ligne est dessinée normalement, puis relue et chaque quartet non
; nul décalé de quatre. La police écrivant les index 3 à 6, la ligne passe sur
; 7 à 10 — les rouges et orangés COMMUNS aux huit palettes de stage. Pas une
; entrée de palette de plus, pas un glyphe de plus.
;-------------------------------------------------------------------------------
ranking.TBL_TITLE equ $C000+6*40+14    ; « R A N K I N G »
ranking.TBL_ROW0  equ $C000+36*40+11   ; « NO. n » du premier rang
ranking.TBL_PITCH equ 14*40
ranking.TBL_HOLD  equ 256              ; trames de tenue, ou un bouton

ranking.tableScreen
        _ram.data.set #2
        jsr   ranking.tbl.oneBuffer
        _SwitchScreenBuffer
        jsr   ranking.tbl.oneBuffer
        _SwitchScreenBuffer
        ldd   #ranking.TBL_HOLD
        std   ranking.in.timer
@hold   _waitFrames #1
        jsr   joypad.readKbd
        lda   joypad.pressed.fire
        anda  #joypad.0.FIRE
        bne   @out
        ldd   ranking.in.timer
        subd  #1
        std   ranking.in.timer
        bne   @hold
@out    rts
;
ranking.tbl.oneBuffer
        ldu   #$0000
        lda   #map.RAM_OVER_CART+common.checkpoint.page
        ldx   #checkpoint.clearData
        jsr   paged.call
        lda   #map.RAM_OVER_CART+common.hud.page
        _SetCartPageA
        ldu   #ranking.TBL_TITLE
        ldy   #ranking.str.ranking
        jsr   hud.drawStr
        clr   ranking.tbl.row
@row
        lda   ranking.tbl.row          ; U = le début de la ligne
        ldb   #ranking.TBL_PITCH/4
        mul
        aslb
        rola
        aslb
        rola
        ldu   #ranking.TBL_ROW0
        leau  d,u
        pshs  u
        lda   ranking.tbl.row          ; « NO. n »
        inca
        jsr   ranking.tbl.rankLabel
        ldy   #ranking.str.no2
        jsr   hud.drawStr
        ldu   ,s                       ; le score, colonne 17
        leau  6,u
        lda   ranking.tbl.row
        jsr   ranking.tbl.entry
        jsr   ranking.scr.digits7
        ldu   ,s                       ; le nom, colonne 27
        leau  16,u
        lda   ranking.tbl.row
        jsr   ranking.tbl.entry
        leax  3,x
        ldb   #7
@nm     lda   ,x+
        pshs  b,x
        jsr   ranking.in.glyph
        puls  b,x
        leau  1,u
        decb
        bne   @nm
        lda   ranking.tbl.row          ; l'entrée que la partie vient de poser
        inca
        cmpa  ranking.rank
        bne   @plain
        ldu   ,s
        ldb   #23                      ; « NO. n » plus le score plus le nom
        jsr   text.hiliteLine
@plain  puls  u
        inc   ranking.tbl.row
        lda   ranking.tbl.row
        cmpa  #ranking.SLOTS
        blo   @row
        rts
;
; A = rang (1..10) -> les deux cellules du numéro dans « NO. n »
ranking.tbl.rankLabel
        ldb   #' '
        cmpa  #10
        blo   >
        ldb   #'1'
        suba  #10
!       stb   ranking.str.no2+3
        adda  #'0'
        sta   ranking.str.no2+4
        rts
;
; A = rang 0-based -> X = &ranking.table[rang]
ranking.tbl.entry
        ldb   #ranking.ENTRY
        mul
        ldx   #ranking.table
        leax  d,x
        rts
;
; text.hiliteLine — une LIGNE de texte passée au rouge du classement
;
; entrée : [u] l'ancre de sa première cellule, [b] le nombre de cellules
;
; RÉSIDENTE ET PARTAGÉE : le tableau y met en valeur l'entrée que la partie
; vient de poser, et l'écran CONTINUE y met son « PUSH FIRE BUTTON » (décision
; auteur, 05/09/2026). La table reste privée, les appelants n'ont qu'un nom à
; connaître.
text.hiliteLine
        ldx   #text.map.hilite
@cell   pshs  b,x,u
        jsr   text.recolor
        puls  b,x,u
        leau  1,u
        decb
        bne   @cell
        rts

;-------------------------------------------------------------------------------
; text.recolor — recolorier UNE cellule de texte par table de correspondance
;
; entrée : [u] l'ancre de la cellule, la même que celle des glyphes (les huit
;              rangées vont de U-120 à U+160, sur les deux plans)
;          [x] une table de seize octets : l'index de couleur de sortie pour
;              chacun des seize d'entrée
; sortie : A, B, X, U détruits
;
; RÉSIDENTE ET RÉEMPLOYABLE (décision auteur, 04/09/2026) : un caractère déjà
; peint change de couleurs sans être redessiné ni connaître son glyphe. La
; police écrit les index 3 à 6 : une table n'a que ces quatre entrées à
; décider, le zéro du fond restant zéro. Le curseur de saisie l'emploie pour
; clignoter blanc/rouge, le tableau pour mettre en valeur l'entrée nouvelle.
;-------------------------------------------------------------------------------
text.recolor
        leau  -120,u                   ; la première des huit rangées
        ldb   #8
@row    lda   ,u
        bsr   text.recolor.byte
        sta   ,u
        lda   -$2000,u
        bsr   text.recolor.byte
        sta   -$2000,u
        leau  40,u
        decb
        bne   @row
        rts
;
; A = un octet, deux quartets -> chacun passé par la table X ; B préservé
text.recolor.byte
        pshs  b
        tfr   a,b
        lsra
        lsra
        lsra
        lsra
        lda   a,x                      ; le quartet haut
        asla
        asla
        asla
        asla
        andb  #$0F
        pshs  a
        lda   b,x                      ; le quartet bas
        ora   ,s+
        puls  b,pc

; Les tables : l'identité partout, sauf les quatre index de la police.
;
; La police dessine ses glyphes en DÉGRADÉ sur les index 3 à 6. Les deux
; premières tables les écrasent toutes les quatre sur une SEULE couleur : le
; caractère en cours de saisie doit être une masse pleine qui bat blanc puis
; rouge, pas un dégradé qui change de teinte (décision auteur, 05/09/2026).
; La troisième garde un dégradé, celui des rouges communs aux huit palettes de
; stage : c'est la mise en valeur d'une ligne entière, où le relief se lit.
;                  0 1 2 3  4  5  6 7 8 9 10 11 12 13 14 15
text.map.white fcb 0,1,2,3,3,3,3,7,8,9,10,11,12,13,14,15       ; blanc uni
text.map.red   fcb 0,1,2,12,12,12,12,7,8,9,10,11,12,13,14,15    ; rouge uni
text.map.hilite fcb 0,1,2,7,8,9,10,7,8,9,10,11,12,13,14,15      ; rouge dégradé

ranking.str.ranking fcc 'R A N K I N G'
                    fcb 0
ranking.str.no2     fcc 'NO. 1'
                    fcb 0
ranking.tbl.row     fcb 0
ranking.firstStage  fcb 0              ; le premier stage du crédit en cours
ranking.pal         fill 0,32          ; la palette de travail de ces écrans
ranking.scr.f       fdb 0              ; la trame courante de la révélation
ranking.scr.bot     fdb 0              ; celle où les textes du bas commencent
ranking.scr.end     fdb 0              ; celle où tout est peint
ranking.scr.rows    fcb 0              ; lignes de stage + celle du TOTAL
ranking.scr.i       fcb 0              ; la ligne examinée
ranking.e.idx       fcb 0
ranking.e.cnt       fcb 0
ranking.e.src       fdb 0
ranking.e.dst       fdb 0

; LES SIX GLYPHES QUE LA POLICE DU HUD N'A PAS — fichier GÉNÉRÉ par
; tools/gen_font_glyphs.py, commité à côté. Ils vivent ICI et non dans la
; police : seuls la ligne de saisie et son alphabet s'en servent, et l'arène
; des objets n'a pas 500 octets à donner. Le '-' dessine les cases vides ;
; le '<' sera RUB et le ':' END quand la saisie arrivera.
        INCLUDE "src/common/ranking/font-extra.asm"

; les chaînes. Les titres sont espacés comme ceux du title ; les lignes de
; score, elles, remplissent leurs seize cellules.
ranking.str.title  fcc 'S T A G E   S C O R E'
                   fcb 0
ranking.str.total  fcc 'TOTAL SC'
                   fcb 0
ranking.str.enter  fcc 'ENTER YOUR INITIALS.'
                   fcb 0
                   fcb 0
ranking.str.stage  fcc ' 1 STAGE'      ; les deux premiers octets sont écrits
                   fcb 0
ranking.scr.dig    fcb 0,0,0,0,0,0,0

;-------------------------------------------------------------------------------
; L'ÉTAT. Il est ici en DONNÉES, donc chargé du disque au boot : les dix
; entrées par défaut sont celles de la borne (ROM 0x1000:07AC), les mêmes que
; le tableau d'attract du title affichait en dur.
;-------------------------------------------------------------------------------
ranking.table
        fcb   0
        fdb   1745
        fcc   'ABIKO..'
        fcb   0
        fdb   1686
        fcc   'SUMITA '
        fcb   0
        fdb   1597
        fcc   'AKIO.O '
        fcb   0
        fdb   1179
        fcc   'SHINJI.'
        fcb   0
        fdb   1005
        fcc   'MISAKO!'
        fcb   0
        fdb   989
        fcc   'MASATO '
        fcb   0
        fdb   920
        fcc   'HAMA...'
        fcb   0
        fdb   800
        fcc   'KENT.K '
        fcb   0
        fdb   760
        fcc   'JIJEE..'
        fcb   0
        fdb   750
        fcc   'IREM . '

; Le score de chaque stage de la partie en cours. Seize, comme la borne : elle
; compte deux tours de huit. Les huit derniers dorment tant que le second tour
; n'existe pas.
ranking.stage
        fill  0,ranking.STAGES*3

; Le rang décroché par la dernière partie, 0 si elle n'a pas classé. C'est lui
; que l'écran de saisie affiche derrière « NO. » et que le tableau met en
; valeur.
ranking.rank
        fcb   0

 ENDSECTION
