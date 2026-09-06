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
ranking.em.on      EXPORT              ; l'emetteur de Pata-Pata (le banc l'arme)
text.recolor       EXPORT              ; réemployables : voir leurs notices
text.hiliteLine    EXPORT
ranking.digits7    EXPORT
ranking.dig        EXPORT

; Le stage courant moins un, tenu par le moteur résident : il traverse le
; changement de scène, donc il est le seul à savoir dans quel stage on meurt.
; L'INTERFACE DU MOTEUR (game.stage, paged.call, la palette, la manette, les
; bruitages, le verrou graphique, les sprites) : api.asm, comme un stage.
        INCLUDE "src/common/engine/api.asm"

; LA POLICE ET SES OUTILS vivent dans la page du HUD. L'ecran la monte le temps
; de peindre : son propre code est dans la demi-page video, toujours montee, il
; ne se perd donc pas en changeant la fenetre cartouche.
hud.drawStr        EXTERNAL
letter_addr        EXTERNAL
numbers_addr       EXTERNAL
DRAW_text_space    EXTERNAL
ScoreToDigits      EXTERNAL
hud.scoreWork      EXTERNAL
; L'effacement du champ, celui du stage (clearblast.asm), et sa fenetre.
playfield.clearBlastFull EXTERNAL     ; tout l'ecran : les Pata-Pata volent partout
; La palette : celle du stage. La police y prend les index 3 a 6, identiques
; sur les huit stages — le texte a donc le meme rendu partout.
Pal_stage          EXTERNAL
Pal_black          EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.macro.asm"
        INCLUDE "gen/layout.asm"
        INCLUDE "engine/system/to8/controller/joypad.const.asm"
        INCLUDE "src/common/fx/soundfx/soundFX.const.asm"
        INCLUDE "src/common/state/variables.asm"
        INCLUDE "src/common/objid-common.const.asm" ; ObjID_patapata, commun (32)

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
; CES ÉCRANS TOURNENT DANS LA BOUCLE DE JEU (05/09/2026) : à chaque trame le
; champ est effacé par le blast et l'écran REPEINT EN ENTIER dans le tampon de
; travail, que l'IRQ échange ensuite — voir ranking.frame. Un peintre par
; écran (ranking.painter), aucune peinture hors du verrou.
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
        ; bleus (4 à 6) — plus DEUX ROUGES en 13 et 14, des entrées que rien
        ; de ces écrans n'emploie. Aucun rouge n'existe parmi les communs, et
        ; le curseur de saisie clignote blanc/rouge (décision auteur, 04/09).
        ldx   #Pal_stage
        ldu   #ranking.pal
@pal    ldd   ,x++                     ; D = A:B — pas de compteur en B ici
        std   ,u++
        cmpu  #ranking.pal+32
        blo   @pal
        ; EN 13 ET 14, PAS 12 (05/09/2026) : le Pata-Pata de l'ecran de saisie
        ; emploie l'index 12 de la palette du stage, ses deux rouges se logent
        ; au-dessus (l'art n'emploie ni 13 ni 14, seulement 15 au-dela).
        ldd   #$0E00                   ; 13 : rouge vif   (250,0,0)
        std   ranking.pal+26
        ldd   #$0400                   ; 14 : rouge sombre (158,0,0)
        std   ranking.pal+28
        ; LA PALETTE APRES LES TRAMES NOIRES (06/09/2026, releve de l'auteur) :
        ; installee avant, elle rendait visible une trame de l'ancien contenu
        ; des tampons (le stage et son HUD, que le noir de la mort cachait
        ; sous Pal_black) — des artefacts entre le GAME OVER et la saisie.
        ; loop.init purge et peint deux trames de noir d'abord.
        jsr   ranking.loop.init
        ldd   #ranking.pal
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow
        lda   #map.RAM_OVER_CART+common.hud.page
        _SetCartPageA                  ; la police, pour toute la suite
        jsr   ranking.glyphs.init      ; sa table, copiee chez nous
        jsr   ranking.scr.reveal       ; le texte apparaît, au rythme de la borne
        jsr   ranking.input
        jsr   ranking.tableScreen      ; puis le tableau des dix
        ; LE NOIR EN SORTIE (06/09/2026) : l'ecran suivant (CONTINUE) peint ses
        ; tampons avant de poser sa palette — sous la notre, ce qu'il peint se
        ; voyait une trame, suivi d'une trame noire. Sous Pal_black, rien ne
        ; se voit avant qu'il n'ait fini.
        ldd   #Pal_black
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow
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
; temps) sans table d'objets. Chaque trame repeint TOUT ce qui est dû jusqu'à
; la trame courante (le tampon de travail vient d'être effacé) ; la trame
; avance du frame-drop, donc le rythme de la borne tient à 25 images/s.
ranking.TITLE_N   equ 21                ; « S T A G E   S C O R E »
ranking.ENTER_N   equ 20                ; « ENTER YOUR INITIALS. »
ranking.BOT_N     equ 32                ; 20 + « NO.n » 5 + 7 tirets
ranking.RATE      equ 3                 ; cases par trame d'une chaîne fixe
ranking.ROW_START equ 32                ; trames avant la première ligne
ranking.ROW_STEP  equ 8                 ; une ligne de plus toutes les huit
ranking.ROW_N     equ 16                ; cases d'une ligne, une par trame

;-------------------------------------------------------------------------------
; LA BOUCLE DE JEU DE CES ECRANS — le modele est celui du stage (stage.frame) :
; le verrou s'ouvre, le champ est efface par le blast, l'ecran est REPEINT EN
; ENTIER dans le tampon de travail, la passe de sprites tourne (le pool est
; vide ici, elle ne coute rien), le verrou se ferme et l'IRQ echange les
; tampons a la trame suivante. C'est l'usage ordinaire du double buffering :
; chaque trame est complete, aucun tampon n'est « en retard ».
;
; Le temps est celui du jeu : `ranking.tick` rend les trames 50 Hz ecoulees
; depuis la boucle precedente (frame-drop), les calendriers avancent de ce
; pas — a 25 images par seconde le rythme de la borne est tenu quand meme.
;
; La logique d'un ecran (manette, compteurs) se fait ENTRE deux trames, pendant
; que l'IRQ echange les tampons : `ranking.frame` ne fait que peindre.
;-------------------------------------------------------------------------------
ranking.loop.init
        jsr   ranking.loop.purge       ; la purge du stage : le credit est fini,
                                       ;   rien de la partie ne survit — le
                                       ;   continue rechargera le checkpoint,
                                       ;   qui repart lui aussi d'un pool vide
        ; L'EFFACEMENT : tout l'ecran d'un blast (playfield.clearBlastFull —
        ; les Pata-Pata volent sur les 200 lignes, le titre du tableau est en
        ; ligne 6) ; le stage, lui, garde son entree champ 11-190, rien a
        ; rendre en sortie. Deux trames de noir complet d'abord, pour ce que
        ; le blast du stage n'effacait pas (son HUD, dans le tampon que la
        ; mort n'a pas noirci).
        ldx   #ranking.clear.window
        stx   ranking.clearer
        jsr   ranking.loop.black2
        clr   gfxlock.frameDrop.count  ; le premier tick vaut une trame
        rts
;
ranking.loop.black2
        ldx   #ranking.loop.black
        stx   ranking.painter
        jsr   ranking.frame
        jmp   ranking.frame
;
ranking.clear.window
        lda   #map.RAM_OVER_CART+common.overlay.page
        ldx   #playfield.clearBlastFull
        jmp   paged.call
;
ranking.loop.black
        ldu   #$0000
        lda   #map.RAM_OVER_CART+common.checkpoint.page
        ldx   #checkpoint.clearData
        jmp   paged.call
;
; le pool vide, ses boites de collision avec (un Pata-Pata s'y inscrit)
ranking.loop.purge
        jsr   ManagedObjects_ClearAll
        jsr   Collision_ClearLists
        jsr   DisplaySprite_ClearAll
        jsr   EraseSprites_ClearAll
        jmp   InitDrawSprites
;
;
; une trame : ce que [ranking.painter] peint, sur un champ efface
ranking.frame
        _gfxlock.on
        jsr   RunObjects
        jsr   [ranking.clearer]
        lda   #map.RAM_OVER_CART+common.hud.page
        _SetCartPageA                  ; chaque objet monte SA page : la police
        jsr   [ranking.painter]        ;   se remonte avant de peindre
        jsr   BuildSprites
        _gfxlock.off
        _gfxlock.loop
        rts
;
; B = trames 50 Hz ecoulees depuis la boucle precedente, une au moins
ranking.tick
        ldb   gfxlock.frameDrop.count
        bne   >
        incb
!       rts
;
; ranking.dt <- B ; puis D = ranking.in.timer - dt, range (Z, N a jour)
ranking.timer.sub
        clra
        std   ranking.dt
        ldd   ranking.in.timer
        subd  ranking.dt
        std   ranking.in.timer
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
        jsr   ranking.scr.prepare      ; les lignes, une fois pour toutes
        ldd   #0
        std   ranking.scr.f
        ldx   #ranking.scr.paint
        stx   ranking.painter
@frame  jsr   ranking.frame
        jsr   ranking.tick
        clra
        addd  ranking.scr.f
        std   ranking.scr.f
        cmpd  ranking.scr.end
        blo   @frame
        rts
;
; tout ce qui est du a la trame ranking.scr.f — repeint chaque trame
ranking.scr.paint
        jsr   ranking.scr.stepTitle
        jsr   ranking.scr.stepRows
        jmp   ranking.scr.stepBottom

; D = trame relative (>= 0), ranking.e.cnt = le plafond
; -> B = cases dues d'une chaine fixe : trois par trame, plafonnees
ranking.scr.due
        tsta
        bne   @all
        lda   #ranking.RATE
        mul
        tsta
        bne   @all
        addb  #ranking.RATE
        bcs   @all
        cmpb  ranking.e.cnt
        blo   @out
@all    ldb   ranking.e.cnt
@out    rts
;
ranking.scr.stepTitle
        lda   #ranking.TITLE_N
        sta   ranking.e.cnt
        ldd   ranking.scr.f
        bsr   ranking.scr.due
        ldx   #ranking.str.title
        ldu   #ranking.SCR_TITLE
        jmp   ranking.scr.emitN

; L'EMETTEUR, A PLAT (06/09/2026) : X = chaine, U = ancre ecran, B = cases.
; Une espace n'est pas peinte — le blast vient de noircir le champ, et
; DRAW_text_space coutait seize ecritures de zero. Le glyphe garde U (pshs/
; puls), le dispatch ne touche que Y : rien a sauver dans la boucle.
ranking.scr.emitN
        tstb
        beq   @out
@loop   lda   ,x+
        cmpa  #' '
        beq   @skip
        jsr   ranking.in.glyph
@skip   leau  1,u
        decb
        bne   @loop
@out    rts

; A = caractère, U = adresse -> peint dans le tampon de travail
ranking.scr.cell
        jmp   ranking.in.glyph

; LES LIGNES DE SCORE, depuis les tables preparees a l'entree (scr.prepare) :
; le texte de chaque ligne (libelle, espace, sept chiffres) et son ancre.
; Par trame il ne reste que « combien de cases sont dues » et l'emetteur.
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
        blo   >
        ldd   #ranking.ROW_N-1         ; finie : toutes ses cases
!       incb                           ; B = les cases dues, 1..16
        pshs  b
        lda   ranking.scr.i
        ldb   #ranking.ROW_N
        mul
        ldx   #ranking.rowText
        leax  d,x                      ; X = le texte de la ligne
        lda   ranking.scr.i
        asla
        ldy   #ranking.rowU
        ldu   a,y                      ; U = son ancre
        puls  b
        jsr   ranking.scr.emitN
@next   inc   ranking.scr.i
        bra   @row
@out    rts

; LA PREPARATION, une fois par sequence : les lignes de score sont figees
; (le credit est fini), leurs textes et leurs ancres sont calcules ici —
; plus aucune conversion de score ni de `mul` d'ancre par trame.
ranking.scr.prepare
        clr   ranking.scr.i
@row    lda   ranking.scr.i
        cmpa  ranking.scr.rows
        bhs   @out
        ldb   #ranking.ROW_N
        mul
        ldx   #ranking.rowText
        leax  d,x                      ; X = le texte de la ligne, a ecrire
        pshs  x
        lda   ranking.scr.i
        inca
        cmpa  ranking.scr.rows
        bne   @stage
        ldy   #ranking.str.total       ; la derniere ligne : « TOTAL SC »
        bsr   ranking.scr.copy8
        ldx   #globals.score
        bra   @digits
@stage  ldy   #ranking.str.stageT      ; « NN STAGE »
        bsr   ranking.scr.copy8
        lda   ranking.firstStage
        adda  ranking.scr.i
        inca                           ; le numéro affiché : 1..16
        ldb   #' '
        cmpa  #10
        blo   >
        ldb   #'1'
        suba  #10
!       ldx   ,s
        stb   ,x
        adda  #'0'
        sta   1,x
        lda   ranking.firstStage
        adda  ranking.scr.i
        jsr   ranking.scr.stagePtr     ; X = les trois octets du stage
@digits jsr   ranking.digits7          ; -> ranking.dig, $FF pour un zero de tete
        puls  x
        lda   #' '
        sta   8,x                      ; la case 8 : l'espace
        leax  9,x
        ldy   #ranking.dig
        ldb   #7
@d      lda   ,y+
        cmpa  #$FF
        bne   >
        lda   #' '-'0'                 ; un zéro de tête : une espace
!       adda  #'0'
        sta   ,x+
        decb
        bne   @d
        lda   ranking.scr.i            ; l'ancre de la ligne
        jsr   ranking.scr.slotU
        lda   ranking.scr.i
        asla
        ldx   #ranking.rowU
        stu   a,x
        inc   ranking.scr.i
        lbra  @row
@out    rts
;
; huit octets de Y vers le texte de ligne en 0,s (X preserve par l'appelant)
ranking.scr.copy8
        ldx   2,s                      ; (le retour est en 0,s)
        ldb   #8
@c      lda   ,y+
        sta   ,x+
        decb
        bne   @c
        rts

; LE BAS : l'invite, puis « NO.n », puis les sept tirets — trois chaines,
; decoupees par le nombre de cases dues (0..32 dans la numerotation de la
; borne : 20 + 5 + 7).
ranking.scr.stepBottom
        ldd   ranking.scr.f
        subd  ranking.scr.bot
        bmi   @out                     ; le bas n'a pas commencé
        pshs  d
        lda   #ranking.BOT_N
        sta   ranking.e.cnt
        puls  d
        jsr   ranking.scr.due          ; B = les cases dues, 0..32
        stb   ranking.e.idx
        cmpb  #ranking.ENTER_N
        bls   >
        ldb   #ranking.ENTER_N
!       ldx   #ranking.str.enter
        ldu   #ranking.SCR_ENTER
        jsr   ranking.scr.emitN
        ldb   ranking.e.idx
        subb  #ranking.ENTER_N
        bls   @out
        cmpb  #5
        bls   >
        ldb   #5
!       ldx   #ranking.str.no2
        ldu   #ranking.SCR_NO
        jsr   ranking.scr.emitN
        ldb   ranking.e.idx
        subb  #ranking.ENTER_N+5
        bls   @out
        aslb                           ; n tirets = 2n-1 cases de « - - - »
        decb
        ldx   #ranking.str.dash
        ldu   #ranking.SCR_CELL
        jmp   ranking.scr.emitN
@out    rts

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
; L'ÉCRAN EST REPEINT À CHAQUE TRAME depuis l'état (le nom dans la table, le
; curseur, la lettre candidate) : la logique ne peint rien, elle change l'état.
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
        clr   ranking.in.done
        ldd   #ranking.IN_LIMIT
        std   ranking.in.timer
        ldx   #ranking.in.paint
        stx   ranking.painter
@loop
        jsr   ranking.frame
        jsr   ranking.tick
        pshs  b
        addb  ranking.in.frame         ; l'horloge du clignotement
        stb   ranking.in.frame
        ldb   ,s
        jsr   ranking.emit             ; les Pata-Pata du decor
        puls  b
        jsr   ranking.timer.sub
        lble  @finish                  ; le temps est écoulé
        lda   ranking.in.cursor
        cmpa  #7
        lbhs  @finish                  ; les sept lettres sont posées
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
        ldb   ranking.dt+1             ; tenue : les trames, pas les boucles
        addb  ranking.in.hold
        stb   ranking.in.hold
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
        ldd   #(soundFX.SmallExplosionSound<<8)|1   ; essai du 05/09 : la petite
        std   soundFX.newSound                      ;   explosion au lieu du tir
        bra   @loop
@commit
        lda   ranking.in.alpha
        cmpa  #ranking.ALPHA_END
        beq   @finish
        cmpa  #ranking.ALPHA_RUB
        beq   @rub
        jsr   ranking.in.letter        ; A = le caractère choisi
        jsr   ranking.in.store         ; il entre dans le nom : la trame
        inc   ranking.in.cursor        ;   suivante le peint depuis la table
        clr   ranking.in.alpha
        ldd   #(soundFX.BonusSound<<8)|1
        std   soundFX.newSound
        lbra  @loop
@rub
        clr   ranking.in.alpha         ; la case quittée redevient un tiret
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
        inc   ranking.in.done          ; la case clignotante ne reste pas
        ldd   #(soundFX.ExtraLifeSound<<8)|1 ;   allumée sur un abandon
        std   soundFX.newSound
        ldd   #ranking.IN_HOLD         ; la tenue : l'écran fini, quelques trames
        std   ranking.in.timer
@hold   jsr   ranking.frame
        jsr   ranking.tick
        pshs  b
        jsr   ranking.emit             ; ils volent encore pendant la tenue
        puls  b
        jsr   ranking.timer.sub
        bgt   @hold
        rts

; L'EMETTEUR DE PATA-PATA — arcade run_score_screen_patapata_emitter (0xFAE1),
; a l'instruction pres : toutes les huit trames un tirage ; decale d'un cran,
; son bit 5 dit s'il nait (une chance sur deux) et ses quatre bits bas donnent
; le prereglage d'ordonnee (0..15) ; le prereglage de tir est 0, la ligne vide
; de la table : ils ne tirent pas. L'objet est celui du jeu, il se pose seul au
; bord droit et vole son script. Ils vivent jusqu'au tableau, tenue comprise —
; la borne ne leve son drapeau qu'apres les 0x40 trames d'attente.
; entree : [b] les trames du tick
; ranking.em.on : arme par defaut depuis que le Pata-Pata est commun (06/09,
; id 32 partout, unite residente) ; un banc peut le couper.
ranking.emit
        tst   ranking.em.on
        beq   @out
        ; LE GENERATEUR DE LA BORNE, A L'IDENTIQUE (06/09/2026) : random_ax
        ; (0xEDE9) est un generateur a trois octets, a := b + c, que la boucle
        ; principale reensemence a (5, 1, 3) toutes les 512 trames — et
        ; l'emetteur, seul consommateur de cet ecran avec les deux tirages
        ; d'une naissance, en tire une SEQUENCE FIXE : 24 a 29 naissances par
        ; cycle, en rafales et creux, jamais dans les 80 premieres trames.
        ; Un tirage equiprobable en faisait 32 regulieres : l'ecran paraissait
        ; trop peuple (relevé de l'auteur).
        pshs  b
        clra
        addd  ranking.em.cycle         ; la trame dans le cycle de 512
        cmpd  #512
        blo   >
        subd  #512
        ldx   #$0501                   ; le reensemencement : (5, 1, 3)…
        stx   ranking.rng
        pshs  b
        ldb   #3                       ; (un seul octet : le suivant est deja
        stb   ranking.rng+2            ;   une autre variable)
        puls  b
        pshs  b
        ldb   #8                       ; …et la borne tire a cette trame meme
        stb   ranking.em.acc
        puls  b
!       std   ranking.em.cycle
        puls  b
        addb  ranking.em.acc
        stb   ranking.em.acc
        cmpb  #8
        blo   @out
        subb  #8
        stb   ranking.em.acc
        bsr   ranking.rnd              ; D = AX de la borne
        lsra
        rorb                           ; SHR AX,1
        bitb  #%00100000               ; TEST AL,0x20 : une chance sur deux
        beq   @out
        andb  #$0F                     ; AND AL,0xF : l'ordonnee
        pshs  b
        jsr   LoadObject_x             ; X = un emplacement libre, Z sinon
        puls  b                        ; (puls ne touche pas Z)
        beq   @out                     ; pool plein : la borne ne tire pas plus
        lda   #ObjID_patapata
        sta   id,x
        clra
        std   subtype_w,x              ; tir 0, ordonnee B
        clr   wave_frame_drop,x        ; ne a cette trame, rien a rattraper
        bsr   ranking.rnd              ; les deux tirages d'une naissance :
        bsr   ranking.rnd              ;   load_fire_preset, puis la phase
@out    rts                            ;   de battement (create_pata_pata)

; random_ax (0xEDE9) : D = c : (b + c), puis (a, b, c) <- (b + c, a, b)
ranking.rnd
        ldb   ranking.rng+1
        addb  ranking.rng+2            ; le nouvel a
        lda   ranking.rng+2            ; l'ancien c, le AH de la borne
        pshs  a
        lda   ranking.rng+1
        sta   ranking.rng+2            ; c <- b
        lda   ranking.rng
        sta   ranking.rng+1            ; b <- a
        stb   ranking.rng              ; a <- b + c
        puls  a
        rts

; L'ECRAN DE SAISIE, une trame : le STAGE SCORE au complet, puis les lettres
; posées (relues dans la table), puis la candidate qui clignote — BLANCHE une
; demi-période et ROUGE l'autre (décision auteur, 04/09/2026), peinte puis
; recoloriée par `text.recolor`. Les cases après le curseur gardent le tiret
; que le bas de l'écran vient de peindre.
ranking.in.paint
 IFDEF RANKING_TEXT_OFF
        rts                            ; EXPERIENCE (banc) : l'ecran sans texte,
 ENDC                                  ;   pour mesurer blasts + Pata-Pata seuls
        jsr   ranking.scr.paint        ; f a dépassé la fin : tout est dû
        clrb
@n      cmpb  ranking.in.cursor
        bhs   @cur
        pshs  b
        jsr   ranking.in.nameX         ; X = le nom dans la table
        lda   b,x
        jsr   ranking.in.cursorU
        jsr   ranking.in.glyph
        puls  b
        incb
        bra   @n
@cur    cmpb  #7
        bhs   @out                     ; les sept sont posées
        tst   ranking.in.done
        bne   @out                     ; abandon : le tiret reste
        lda   ranking.in.alpha
        jsr   ranking.in.letter
        jsr   ranking.in.cursorU       ; U = la case (B = le curseur)
        pshs  u
        jsr   ranking.in.glyph
        puls  u
        ldx   #text.map.white
        lda   ranking.in.frame
        anda  #ranking.IN_BLINK
        beq   >
        ldx   #text.map.red
!       jmp   text.recolor
@out    rts
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
; peindre le caractère A à l'adresse U. Les six signes que la police du HUD n'a
; pas sont dessinés par les glyphes générés plus bas ; tout le reste passe par
; sa table.
; LE DISPATCH PAR TABLE (06/09/2026) : ranking.glyphs, copie locale des
; entrees 32..90 de letter_addr faite a l'entree (ranking.glyphs.init), ou
; les six signes que la police n'a pas remplacent leurs cases. Quatre
; instructions, Y seul touche — l'ancienne cascade de six comparaisons en
; coutait quarante-cinq.
ranking.in.glyph
        suba  #32
        asla
        ldy   #ranking.glyphs
        jmp   [a,y]
;
; a appeler la page de la police montee : la table, puis les six signes
ranking.glyphs.init
        ldx   #letter_addr
        ldy   #ranking.glyphs
        ldb   #ranking.GLYPHS_N
@c      ldu   ,x++
        stu   ,y++
        decb
        bne   @c
        ldu   #DRAW_text_lt
        stu   ranking.glyphs+('<'-32)*2
        ldu   #DRAW_text_colon
        stu   ranking.glyphs+(':'-32)*2
        ldu   #DRAW_text_dash
        stu   ranking.glyphs+('-'-32)*2
        ldu   #DRAW_text_comma
        stu   ranking.glyphs+(','-32)*2
        ldu   #DRAW_text_gt
        stu   ranking.glyphs+('>'-32)*2
        ldu   #DRAW_text_question
        stu   ranking.glyphs+('?'-32)*2
        rts
;
; ranger le caractère A dans le nom de l'entrée qu'on vient de classer
ranking.in.store
        pshs  a
        jsr   ranking.in.nameX
        ldb   ranking.in.cursor
        abx
        puls  a
        sta   ,x
        rts
;
; X = le nom de l'entrée qu'on vient de classer ; A, B préservés
ranking.in.nameX
        pshs  a,b
        lda   ranking.rank
        deca
        ldb   #ranking.ENTRY
        mul
        ldx   #ranking.table+3         ; +3 : le nom suit les trois octets du score
        leax  d,x
        puls  a,b,pc

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
ranking.in.done   fcb 0                ; 1 : la saisie est close, plus de curseur
ranking.em.on     fcb 1                ; 1 : l'emetteur de Pata-Pata est arme
ranking.em.acc    fcb 0                ; les trames vers le prochain tirage
ranking.em.cycle  fdb 0                ; la trame dans le cycle de 512 de la borne
ranking.rng       fcb 5,1,3            ; l'etat de random_ax : a, b, c
ranking.painter   fdb 0                ; ce que ranking.frame peint
ranking.clearer   fdb 0                ; et comment il efface avant
ranking.dt        fdb 0                ; les trames du dernier tick


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
        jsr   ranking.loop.purge       ; game_tick_disable_flag : les Pata-Pata
                                       ;   s'en vont, le tableau n'en a pas
        ldx   #ranking.tbl.paint
        stx   ranking.painter
        ldd   #ranking.TBL_HOLD
        std   ranking.in.timer
@hold   jsr   ranking.frame
        jsr   ranking.tick
        jsr   ranking.timer.sub
        ble   @out
        jsr   joypad.readKbd
        lda   joypad.pressed.fire
        anda  #joypad.0.FIRE
        beq   @hold
@out    rts
;
; le tableau, une trame : titre, dix lignes, la nouvelle entrée surlignée
ranking.tbl.paint
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
text.map.red   fcb 0,1,2,13,13,13,13,7,8,9,10,11,12,13,14,15    ; rouge uni (13)
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
ranking.GLYPHS_N    equ 91-32          ; les codes 32..90, l'espace a Z
ranking.glyphs      fill 0,ranking.GLYPHS_N*2
ranking.rowText     fill 0,(ranking.STAGES+1)*ranking.ROW_N ; le texte des lignes
ranking.rowU        fill 0,(ranking.STAGES+1)*2             ; et leurs ancres
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
ranking.str.stage  fcc ' 1 STAGE'      ; reconstruit à chaque ligne : le TOTAL
                   fcb 0               ;   l'écrase, le gabarit le rétablit
ranking.str.stageT fcc '   STAGE'
                   fcb 0
ranking.str.dash   fcc '- - - - - - -'  ; les sept cases vides, espacees
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
