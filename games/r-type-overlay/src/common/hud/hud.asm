; PALETTE-MIGREE — voir games/r-type/tools/palette-code.txt
; *****************************************************************************
; Render HUD on screen
; --------------------
;
; - nb of globals.lives
; - beam indicator
; - globals.score
;
; *****************************************************************************

; V2-DEVIATION: l'en-tete commun est porte par l'unite hote (hud.unit.asm),
; comme pour tout fichier v1 enveloppe.
;       INCLUDE "./objects/player1/player1.equ"
;
; V2-DEVIATION: les douze routines DRAW_Img_hud_* ont ete RETIREES de ce
; fichier (306 lignes). C'etait du code GENERE une fois puis colle — le
; .properties v1 le dit en toutes lettres (« used to generate code, should be
; commented because replaced by the code above »), ses lignes sprite etant
; commentees faute d'un encodeur au bon contrat d'appel.
;
; La v2 en a un : <encoder planes="offset"> rend U intact et atteint le second
; plan a distance fixe — ce dont ces routines ont besoin, l'appelant enchainant
; `jsr` puis `leau 1,u`. Les PNG redeviennent la source, et l'unite hote fait le
; pont de noms (DRAW_Img_hud_0 equ adr_hud_0_ND0).
;
; Mesure avant retrait, sur les douze sprites : HUIT identiques a l'octet a ce
; qui etait colle, QUATRE ne differant que par l'ordre de groupes d'ecriture
; disjoints (la recherche d'ordre de l'encodeur). Aucun ne diverge.

_beam_seg_extA MACRO                   ; outer lines of 8px
	std   $2001,u
	std   $2001+4*40,u
 ENDM

_beam_seg_extB MACRO                   ; outer lines of 8px
	std   ,u
	std   4*40,u
 ENDM

_beam_seg_midA MACRO                   ; middle lines of 8px
	std   $2001+1*40,u
	std   $2001+3*40,u
 ENDM

_beam_seg_midB MACRO                   ; middle lines of 8px
	std   1*40,u
	std   3*40,u
 ENDM

_beam_seg_intA MACRO                   ; inner line of 8px
	std   $2001+2*40,u
 ENDM

_beam_seg_intB MACRO                   ; inner line of 8px
	std   2*40,u
        leau  beam_m_size,u            ; move to next segment position
 ENDM

beam_m_start equ $BE3B                 ; beam render starting point
beam_m_size  equ 2                     ; number of byte for a segment

; ---------------------------------------------------------------------------
; HUD render entry point
; ---------------------------------------------------------------------------
; Draws the beam indicator (5 segments), then updates globals.lives (granting any
; extra life triggered by a globals.score threshold), then draws the current globals.score.
; Each segment of the beam is 8px; values in-between are rendered using
; Beam_mask to mask off the dark pixels of the last partial segment.
; ---------------------------------------------------------------------------

; V2-DEVIATION: le dispatch sur B disparait. paged.call ecrase B — la page
; d'origine y transite — et la v2 vise une routine paginee par SON SYMBOLE :
; l'unite exporte deux entrees la ou la v1 n'avait qu'un ObjID et une commande.
; Meme geste que le champ d'etoiles, qui en exporte trois.
; Cas de migration : docs/lang/en/migration/paged-routine.md
;        ; ObjID_hud entry - dispatch on B (hud.NORMAL = bottom HUD, hud.READOUT = score readout)
;        cmpb  #hud.READOUT
;        lbeq  hud.scoreReadout
hud.drawNormal

        ; display beam in 5 segments
        ldu   #beam_m_start

        ldb   player1+beam_value
	stb   @cnt
@loop_full_beam
        ldb   #0
@cnt    equ   *-1
        lbeq  @loop_black
        subb  #8
        bmi   @do_partial_beam
	stb   @cnt	
	ldd   #$4444
        _beam_seg_extA
        _beam_seg_extB
	ldd   #$5555
        _beam_seg_midA
        _beam_seg_midB
	ldd   #$6666
        _beam_seg_intA
        _beam_seg_intB
        cmpu  #beam_m_start+beam_m_size*5
        lbeq  @beam_end
        bra   @loop_full_beam
;
@do_partial_beam
        ldy   #Beam_mask
        lda   #4
        negb
        decb
        mul
        leay  d,y
        ldd   2,y
        anda  #$44
        andb  #$44
        _beam_seg_extA
        ldd   ,y
        anda  #$44
        andb  #$44
        _beam_seg_extB
        ldd   2,y
        anda  #$55
        andb  #$55
        _beam_seg_midA
        ldd   ,y
        anda  #$55
        andb  #$55
        _beam_seg_midB
        ldd   2,y
        anda  #$66
        andb  #$66
        _beam_seg_intA
        ldd   ,y
        anda  #$66
        andb  #$66
        _beam_seg_intB
        cmpu  #beam_m_start+beam_m_size*5
        beq   @beam_end
;
@loop_black
        ; complete the bar with black segments
	ldd   #$0000
        _beam_seg_extA
        _beam_seg_extB	
        _beam_seg_midA
        _beam_seg_midB
        _beam_seg_intA
        _beam_seg_intB
        cmpu  #beam_m_start+beam_m_size*5
        bne   @loop_black
@beam_end

        ; grant extra globals.lives on globals.score thresholds
        jsr   hud.checkExtraLife

        ; display globals.lives
        ldu   #$DE97
        jsr   DisplayLife

        ; display globals.score : 5 significant digits (score in hundreds) + "00"
        ldu   #$DE7D
        lda   globals.score              ; score == 0 ? (all 3 bytes)
        bne   @scoreShow
        ldd   globals.score+1
        bne   @scoreShow
        ldb   #6                          ; score==0 : 6 black tiles + "0"
@scoreZ jsr   DRAW_Img_hud_b
        leau  1,u
        decb
        bne   @scoreZ
        jmp   DRAW_Img_hud_0
@scoreShow
        lda   globals.score              ; scoreWork = globals.score
        sta   hud.scoreWork
        ldd   globals.score+1
        std   hud.scoreWork+1
        ldy   #hud.scoreDigits
        jsr   ScoreToDigits
        clr   counter_hdr_flag            ; significance flag (0 = still leading zeros)
        clr   hud.scoreDigPos
@scoreLoop
        ldx   #hud.scoreDigits
        ldb   hud.scoreDigPos
        lda   b,x                         ; A = current digit
        sta   hud.curDigit
        bne   @scoreSig
        tst   counter_hdr_flag
        bne   @scoreDraw                  ; already significant -> draw the 0
        jsr   DRAW_Img_hud_b              ; leading zero -> blank tile
        bra   @scoreAdv
@scoreSig
        inc   counter_hdr_flag
@scoreDraw
        lda   hud.curDigit
        asla
        ldx   #Img_Num
        jsr   [a,x]                       ; draw glyph for this digit
@scoreAdv
        leau  1,u
        inc   hud.scoreDigPos
        lda   hud.scoreDigPos
        cmpa  #5
        blo   @scoreLoop
        jsr   DRAW_Img_hud_0              ; trailing "00"
        leau  1,u
        jmp   DRAW_Img_hud_0

; ----------------------------------------------------
; hud.checkExtraLife
; ----------------------------------------------------
; Grants +1 life when the globals.score crosses one of the
; following displayed thresholds:
;   100000, 200000, 350000, 500000, 700000
; The on-screen globals.score is globals.score*100, so the values compared
; against the 'globals.score' variable are divided by 100:
;   1000, 2000, 3500, 5000, 7000
;
; State is tracked in globals.lifeUpIdx (0..5).
; It is auto-reset when globals.score is 0 (new game / restart),
; so no per-game-mode initialization is required.
;
; At most one threshold can be crossed per call (globals.score
; increments are always small enough in-game).
; ----------------------------------------------------
hud.checkExtraLife
        lda   globals.score              ; score == 0 ? (3 bytes)
        bne   @doCheck
        ldd   globals.score+1
        bne   @doCheck
        clr   globals.lifeUpIdx          ; new game: reset tracking
        rts
@doCheck
        ldb   globals.lifeUpIdx
        cmpb  #hud.nbExtraLifeThresholds
        bhs   @rts
        aslb
        ldx   #hud.extraLifeThresholds
        abx
        lda   globals.score              ; MSB != 0 -> score >= 65536 > any threshold
        bne   @grant
        ldd   globals.score+1
        cmpd  ,x
        blo   @rts
@grant  inc   globals.lives
        inc   globals.lifeUpIdx
@rts    rts

hud.nbExtraLifeThresholds equ 5
hud.extraLifeThresholds
        fdb   1000                     ; 100000
        fdb   2000                     ; 200000
        fdb   3500                     ; 350000
        fdb   5000                     ; 500000
        fdb   7000                     ; 700000

; ----------------------------------------------------
; Display the number of globals.lives on screen (mode 160x200x16)
;
; Draws 7 columns total: padding black tiles on the left
; followed by one life icon per remaining life. When
; 'globals.lives' is >= 7, the display is capped to 7 icons.
;
; INPUT
; -----
; register U : screen location in ram A ($C000-$DFFF)
;              (leftmost column of the globals.lives area)
; global     : globals.lives (1 byte)
; ----------------------------------------------------
DisplayLife
        ldb   globals.lives
	subb  #7
	bmi   >
	ldb   #7
	bra   @drawLifeFull ; cap when higher globals.lives count than displayable
!
	jsr   DRAW_Img_hud_b
	leau  1,u
	incb
	beq   @drawLife
	bra   <
@drawLife	
	ldb   globals.lives
!
	beq   @rts
@drawLifeFull
 	jsr   DRAW_Img_hud_life	
	leau  1,u
	decb
	bra   <
@rts	rts

; ----------------------------------------------------
; Draw a single "life" icon (4px wide) on screen
; (mode 160x200x16)
;
; INPUT
; -----
; register U : screen location in ram A ($C000-$DFFF)
; ----------------------------------------------------
; ----------------------------------------------------
; Display a n digit number on screen (mode 160x200x16)
;
; INPUT
; -----
; register B : number of digits (1-5)
; register X : value to display
; register U : screen location in ram A ($C000-$DFFF)
;
; display in 4px steps
; ----------------------------------------------------

; variables
counter_cur_digit equ dp_engine
counter_hdr_flag  equ dp_engine+1

DisplayDigit
        clr   counter_hdr_flag         ; flag used to skip left 0 at display
        stx   @d1
        decb
        aslb
        ldx   #Hud_1
        abx
        ldd   #0
@d1     equ   *-2
        ldy   #Img_Num
@loop   clr   counter_cur_digit        ; single digit counter
!       subd  ,x
        bcs   >
        inc   counter_cur_digit        ; inc digit counter
        bra   <
!       addd  ,x
        std   @d2
        tst   counter_cur_digit
        beq   >
        inc   counter_hdr_flag
!       tst   counter_hdr_flag
        bne   @digits                  ; branch if significant digit to display
        jsr   DRAW_Img_hud_b           ; black background
        bra   >
@digits ldb   counter_cur_digit
        aslb
        jsr   [b,y]
!       leau  1,u                      ; move coordinates to 4px right
        ldd   #0
@d2     equ   *-2
        leax  -2,x
        cmpx  #Hud_1
        bne   >
        inc   counter_hdr_flag
!       cmpx  #Hud_1-2
        bne   @loop
        rts

; ---------------------------------------------------------------------------
; for HUD counter
; ---------------------------------------------------------------------------

Hud_1           fdb   1				
Hud_10          fdb   10
Hud_100         fdb   100
Hud_1000        fdb   1000
Hud_10000       fdb   10000

; ---------------------------------------------------------------------------
; Diplay routines
; ---------------------------------------------------------------------------

Img_Num
        fdb   DRAW_Img_hud_0
        fdb   DRAW_Img_hud_1
        fdb   DRAW_Img_hud_2
        fdb   DRAW_Img_hud_3
        fdb   DRAW_Img_hud_4
        fdb   DRAW_Img_hud_5
        fdb   DRAW_Img_hud_6
        fdb   DRAW_Img_hud_7
        fdb   DRAW_Img_hud_8
        fdb   DRAW_Img_hud_9

; ----------------------------------------------------
; Draw a single blank (black) 4px-wide tile on screen
; (mode 160x200x16). Used both as background eraser and
; as padding by DisplayLife / DisplayDigit.
;
; INPUT
; -----
; register U : screen location in ram A ($C000-$DFFF)
; ----------------------------------------------------
; ---------------------------------------------------------------------------
; Beam partial-segment masks
; ---------------------------------------------------------------------------
; Bit masks used when the beam value is not a multiple of 8, to render the
; last (partially filled) segment of the beam bar. Each row describes the 4
; bytes of a segment:
;   RAMB: XH, XL   RAMA: XH, XL
; The parenthesized number indicates how many pixels of the segment are lit
; (from 7 down to 1). The selected row is later ANDed with the full-segment
; colour bytes: one byte stores two pixels (one nibble each), so $55 encodes
; two pixels of colour 5, $66 two pixels of colour 6 and $dd two pixels of
; colour $d. The mask zeroes out the pixels that must stay dark.
; ---------------------------------------------------------------------------

Beam_mask
        fcb $ff,$ff,$ff,$f0 ; (7) RAMB: XH, XL RAMA: XH, XL
        fcb $ff,$ff,$ff,$00 : (6)
        fcb $ff,$f0,$ff,$00 : (5)
        fcb $ff,$00,$ff,$00 : (4)
        fcb $ff,$00,$f0,$00 : (3)
        fcb $ff,$00,$00,$00 : (2)
        fcb $f0,$00,$00,$00 : (1)

; ===========================================================================
; STAGE SCORE READOUT (hud.READOUT) - arcade "score rollover" port
; ---------------------------------------------------------------------------
; Driven by main each frame during endstage phase 4 (double buffer). The 7 score
; digits spin through random glyphs and settle one by one as a master countdown
; crosses per-digit thresholds, like the arcade tick_score_rollover_dispatcher.
; Drawn centered, reusing the HUD digit glyphs (Img_Num / DRAW_Img_hud_*). Seeded
; from the stage score (globals.score - globals.stageScoreBase) the first frame
; after main.endstage.scoreArmed is set; raises main.endstage.scoreDone at 0.
; The bottom HUD is left untouched (preserved by the capped fade).
; ===========================================================================

READOUT_FRAMES equ 224          ; spin/settle master countdown (arcade 0xE0)
READOUT_HOLD   equ 150          ; final-score hold after settle, in frames (~3 s @ 50 Hz)
READOUT_BLANK  equ 10           ; settled-digit sentinel for a blanked leading zero
; on-screen layout (RAMA, 40 cells/line, 1 cell = one 4px glyph). Centered; tune later.
hud.line1U   equ $C000+52*40+5  ; "S T A G E   1   C L E A R E D" (29 cells), scanline 52, centered col 5
hud.line2U   equ $C000+92*40+10 ; "STAGE SCORE " label (12 chars) - scanline 92, col 10
hud.readoutU equ hud.line2U+12  ; the 7 score digits, right after the "STAGE SCORE " label

hud.scoreReadout
        lda   main.endstage.scoreArmed
        beq   @run
        clr   main.endstage.scoreArmed       ; first readout frame: seed digits + countdown
        clr   main.endstage.scoreDone
        jsr   hud.readout.seed
        lda   #READOUT_FRAMES
        sta   hud.readout.timer
@run
        ldb   hud.readout.timer               ; spin/settle countdown, frame-drop compensated
        beq   @holdPhase                      ; spin/settle done -> hold the final score
        subb  gfxlock.frameDrop.count
        bhi   @storeTimer                     ; still spinning (> 0, no underflow)
        clrb                                   ; spin/settle reached 0 this frame
        lda   #READOUT_HOLD                    ; arm the final-score hold (main loop keeps running)
        sta   hud.readout.holdTimer
@storeTimer
        stb   hud.readout.timer
        bra   @draw
@holdPhase
        ; spin/settle done: hold the settled score for READOUT_HOLD frames. The main loop keeps
        ; running (pod animates, ship pipeline) - we only set scoreDone when the hold expires.
        ldb   hud.readout.holdTimer
        beq   @draw                           ; hold already finished (scoreDone set) -> just draw
        subb  gfxlock.frameDrop.count
        bhi   @storeHold                      ; still holding
        clrb
        lda   #1
        sta   main.endstage.scoreDone          ; hold done -> the Tick may leave the level
@storeHold
        stb   hud.readout.holdTimer
@draw
        lda   game.stage                      ; le numero du stage COURANT :
        inca                                  ;   game.stage garde le dernier
        adda  #'0'                            ;   stage acheve (0 en stage 1)
        sta   hud.str.stageNum
        ldu   #hud.line1U                     ; "STAGE n CLEARED" (static; redrawn each frame so
        ldy   #hud.str.cleared                ;   both video buffers carry it)
        jsr   hud.drawStr
        ldu   #hud.line2U                     ; "STAGE SCORE " label
        ldy   #hud.str.score
        jsr   hud.drawStr
        clr   hud.readout.spun                ; "did any digit actually spin this frame" (arcade DI)
        ldu   #hud.readoutU                   ; leftmost score digit (RAMA)
        ldx   #0                              ; digit index 0..6
@digitLoop
        ldb   hud.readout.digits,x            ; settled value for this position
        cmpb  #10
        bhs   @blank                           ; blanked leading zero -> never spins, stays blank
        lda   hud.readout.timer               ; significant digit: spin while timer > threshold[i]
        cmpa  hud.readout.thresholds,x
        bls   @realDigit                       ; timer <= threshold -> settled (B = digits[x])
        inc   hud.readout.spun                  ; this digit spins this frame
        jsr   RandomNumber                      ; random glyph 0..9
        andb  #15
        cmpb  #10
        blo   @realDigit
        andb  #7                                ; clamp 10..15 -> 2..7 (arcade)
@realDigit
        aslb
        ldy   #numbers_addr                     ; title font digits (raccord avec les lettres)
        jsr   [b,y]                             ; DRAW_text_<digit> at U
        bra   @nextDigit
@blank
        jsr   DRAW_text_space
@nextDigit
        leau  1,u
        leax  1,x
        cmpx  #7
        blo   @digitLoop
        ; chime every 4th frame while at least one significant digit actually spun (arcade DI)
        lda   hud.readout.spun
        beq   @done
        ldb   gfxlock.frame.count+1
        andb  #3
        bne   @done
        ldd   #$0201                           ; soundFX queue: id 2 (BonusSound) << 8 | priority 1
        std   soundFX.newSound                 ; (inline - no soundFX macro include in this object)
@done   rts

; ---------------------------------------------------------------------------
; hud.drawStr - draw a 0-terminated uppercase string at U (RAMA) with the
; duplicated title font. Y = string ptr, U = screen dest. Each DRAW_text_X
; restores U (pshs/puls), so we advance leau 1,u per character.
; Trashes A,X,Y,U.
; ---------------------------------------------------------------------------
hud.drawStr
        ldx   #letter_addr
@l      lda   ,y+
        beq   @r
        suba  #32
        asla
        jsr   [a,x]
        leau  1,u
        bra   @l
@r      rts

; Le chiffre est PATCHE a chaque affichage depuis game.stage (courant - 1,
; pose par le handOver du stage precedent, remis a zero par le title) : le
; HUD est commun aux huit stages, la chaine ne peut pas porter un numero
; d'assemblage. La police a tous les chiffres (numbers_addr).
hud.str.cleared  fcc 'S T A G E   '
hud.str.stageNum fcc '1'
                 fcc '   C L E A R E D'
                 fcb 0
hud.str.score   fcc 'STAGE SCORE '
                fcb 0

; ---------------------------------------------------------------------------
; seed: stageScore = globals.score - globals.stageScoreBase, expand to 7 digits
; (5 significant MSB-first + the x100 trailing "00"), blank leading zeros.
; ---------------------------------------------------------------------------
hud.readout.seed
        ldd   globals.score+1            ; stageScore = score - base (24-bit)
        subd  globals.stageScoreBase+1
        std   hud.scoreWork+1
        lda   globals.score
        sbca  globals.stageScoreBase
        sta   hud.scoreWork
        bcc   >
        clr   hud.scoreWork              ; base > score -> clamp to 0
        clr   hud.scoreWork+1
        clr   hud.scoreWork+2
!       ldy   #hud.readout.digits
        jsr   ScoreToDigits              ; digits[0..4] = 5 significant digits
        ldx   #hud.readout.digits+5
        clr   ,x+                        ; digits[5] = 0 (x100 trailing zero)
        clr   ,x                         ; digits[6] = 0
        ldx   #hud.readout.digits        ; blank leading zeros (keep real digits[6])
        ldb   #6
@blank  lda   ,x
        bne   @blankDone
        lda   #READOUT_BLANK
        sta   ,x+
        decb
        bne   @blank
@blankDone
        rts

hud.readout.timer      fcb 0
hud.readout.holdTimer  fcb 0                  ; final-score hold countdown (after settle)
hud.readout.seedDigit  fcb 0
hud.readout.spun       fcb 0                  ; per-frame count of digits that spun (arcade DI)
hud.readout.digits     fcb 0,0,0,0,0,0,0      ; 7 settled digit values (0-9 or READOUT_BLANK)
hud.readout.thresholds fcb $10,$20,$30,$50,$70,$90,$A0
hud.readout.powers     fdb 10000,1000,100,10,1

; ScoreToDigits - expand 3-byte hud.scoreWork (hundreds, 0..99999) into 5 decimal
;                 digits (0..9) MSB-first at the buffer pointed by Y (Y += 5).
; INPUT : hud.scoreWork (3 bytes, MSB first), Y = output buffer
; CLOBBERS: A,B,X,Y,D,CC
ScoreToDigits
        ldx   #hud.readout.powers
@digit  clr   ,y
@sub    ldd   hud.scoreWork+1
        subd  ,x
        std   hud.scoreWork+1
        lda   hud.scoreWork
        sbca  #0
        sta   hud.scoreWork
        bcs   @subDone               ; borrow out of MSB -> value went negative
        inc   ,y
        bra   @sub
@subDone
        ldd   hud.scoreWork+1        ; undo last subtract (+= power)
        addd  ,x
        std   hud.scoreWork+1
        lda   hud.scoreWork
        adca  #0
        sta   hud.scoreWork
        leax  2,x
        leay  1,y
        cmpx  #hud.readout.powers+10
        blo   @digit
        rts

hud.scoreWork    fcb 0,0,0
hud.scoreDigits  fcb 0,0,0,0,0
hud.curDigit     fcb 0
hud.scoreDigPos  fcb 0

; ===========================================================================
; L'ECRAN CONTINUE  (arcade : stage_cleared_flow @ 0x4012a7)
; ---------------------------------------------------------------------------
; Il vit ICI, avec le releve de fin de stage, parce qu'il n'a besoin de rien
; d'autre : la police du title dupliquee plus bas, `hud.drawStr`, et la meme
; convention de placement $C000 + ligne*40 + colonne. Un ecran de plus dans
; l'unite qui porte deja le seul autre ecran de texte du jeu.
;
; CE QUE FAIT L'ARCADE (releve au connecteur Ghidra) : `continue_prompt_gate`
; gele le tick, verifie le DIP « Allow Continue » et `stage_score_index >= 2`
; (un seul continue par joueur), puis affiche par un routeur de tuiles unique
; (0xED58) des enregistrements « palette | largeur | hauteur | destination |
; codes ASCII » :
;     0x0E06  palette 5, 16x1  " C O N T I N U E "  (pas de « ? » : la ROM
;                              n'en a pas, et notre police non plus)
;     0x0E1C  palette 6, 22x1  " I N S E R T   C O I N "
;     0x0E38  palette 6, 22x2  efface la ligne, puis " PUSH START BUTTON "
;     0x0E6A..0x1086  palette 5, 6x9 : les dix chiffres, dessines avec le
;                              CARACTERE 'O' ($4F) — pas le chiffre zero.
; Le decompte descend de 9 a 0, 0x3E ticks par chiffre, avec un bip par
; chiffre pris dans la table 0x0DDE.
;
; NOS ECARTS, tous decides avec l'auteur :
;   - free play : ni DIP, ni credits, ni « INSERT COIN », ni la phase piece
;     acceptee. Un seul ecran, « PUSH FIRE BUTTON » d'emblee. L'evenement
;     0xEC14 que le poll arcade repostait toutes les 8 trames n'etait pas un
;     clignotement mais la ligne d'etat des credits (« FREE PLAY » ou
;     « CREDIT nn ») : rien a porter.
;   - pas de bip par chiffre : la musique `sounds.continue.ymm` les integre.
;   - la limite arcade est la REGLE PAR DEFAUT : un continue par partie
;     (`game.continueUsed` compte les continues consommes, resident dans le
;     moteur, remis a zero en meme temps que `game.stage`). Le quota se regle
;     au build par le define `game.continue.MAX` — voir sa declaration plus
;     bas.
;   - les dix grilles sont BIT-PACKEES : 6 colonnes tiennent dans un octet,
;     9 rangees par chiffre, 90 octets pour les dix la ou l'arcade en depense
;     540 en grilles de caracteres.
;
; CE QU'IL REND : rien, au sens d'un registre — `paged.call` ecrase B. Le
; continue accepte REND SES VIES au joueur (`globals.lives`), et le test
; `tst globals.lives` que le corps de stage fait deja juste apres prend
; naturellement la branche de rechargement de checkpoint. Le refus laisse les
; vies negatives et le GAME OVER suit son cours. Aucune variable de statut.
;
; Il ne prend PAS le verrou de double tampon : rien ne bouge a l'ecran entre
; deux chiffres, et sans `gfxlock.off` aucun echange de tampon n'est arme —
; c'est la discipline de la sequence READY / GAME OVER juste a cote, qui
; peint elle aussi en absolu et attend a `_waitFrames`.
;
; Le score n'est PAS remis a zero, contrairement a l'arcade : sans table de
; classement il n'y a rien a proteger, et le HUD comme le seuil de vie
; supplementaire lisent ce compteur.
; ===========================================================================

; Trames par chiffre. L'arcade en met 0x3E a 55 Hz, soit 1,13 s ; on prend
; 60 trames — 1,20 s — pour que les DIX chiffres couvrent exactement la duree
; de `sounds.continue.ymm` : 529 200 echantillons a 44,1 kHz = 12,00 s = 600
; trames a 50 Hz. Decompte et morceau finissent donc ensemble, et le morceau
; n'est jamais coupe au milieu d'une phrase (decision auteur, 18/08).
CONTINUE_TICKS equ 60

; Le nombre de continues par partie, reglable au build sans toucher au code :
;     <define symbol="game.continue.MAX" value="N"/>   (cote target du config)
;   0   : pas de continue — l'ecran ne s'affiche jamais, GAME OVER direct ;
;   N   : quota par partie (`game.continueUsed` compte, GAME OVER le remet a 0) ;
;   $FF : infini — le compte disparait de l'assemblage, l'ecran revient toujours.
; Sans define, la regle arcade : un seul.
 IFNDEF game.continue.MAX
game.continue.MAX equ 1
 ENDC

; Placement : cellule = 1 octet = 4 px de large, glyphe haut de 8 lignes.
hud.cont.line1U equ $C000+48*40+12    ; "C O N T I N U E"  (15 cellules)
hud.cont.digitU equ $C000+72*40+17    ; le gros chiffre : 6 cellules x 9 rangees
hud.cont.line2U equ $C000+160*40+12   ; "PUSH FIRE BUTTON" (16 cellules)
hud.cont.line3U equ $C000+184*40+11   ; " F R E E   P L A Y" (18 cellules)

hud.continueScreen
 IFNE game.continue.MAX-$FF           ; $FF : infini, aucun compte a tenir
        lda   game.continueUsed
        cmpa  #game.continue.MAX      ; avec MAX=0 le test est toujours vrai :
        lbhs  hud.cont.refuse         ;   quota consomme, la partie est finie
 ENDC

        clr   hud.cont.keydown        ; le front clavier part desarme
        ; La musique du continue, commune aux huit stages : elle porte les bips
        ; de decompte que l'arcade jouait chiffre par chiffre (table 0x0DDE),
        ; d'ou l'absence de bruitage ici.
        ;
        ; ELLE NE BOUCLE PAS, et c'est structurel : le decompte dure exactement
        ; un passage (CONTINUE_TICKS ci-dessus), et un morceau qui boucle ne se
        ; termine jamais — donc personne ne pourrait ATTENDRE sa fin. Le refus
        ; passe par `hud.cont.musicWait` juste pour absorber le decalage des
        ; quelques trames que le decompte a prises en plus.
        ;
        ; Le joueur qui reprend, lui, la voit remplacee par celle du stage, que
        ; le rechargement de checkpoint relance (`ymm.restart`).
        ldx   #sounds.continue.ymm
        ldb   #ymm.NO_LOOP
        jsr   game.music.play
        ldx   #hud.cont.screenOn
        jsr   hud.cont.paintLines
        ldd   #Pal_stage              ; le texte doit se voir : l'ecran vient
        std   Pal_current             ;   d'etre noirci par le fondu de mort
        clr   PalRefresh
        jsr   PalUpdateNow

        ; DEUX TRAMES avant le premier chiffre : le morceau part sur son
        ; attaque, et le decompte visuel se cale dessus (reglage auteur au
        ; rendu, 18/08). Elles s'ajoutent aux 600 trames du decompte, donc le
        ; morceau finit deux trames avant le dernier chiffre — `musicWait` les
        ; absorbe sans rien attendre.
        _waitFrames #2
        ldb   #9                      ; le decompte, de 9 a 0
@digit  stb   hud.cont.digit
        lda   #9                      ; l'octet 9 rangees plus loin dans la table
        mul
        ldx   #hud.cont.digits
        leax  d,x
        jsr   hud.cont.paintDigit
        lda   #CONTINUE_TICKS
        sta   hud.cont.ticks
@frame  _waitFrames #1
        jsr   joypad.readKbd
        jsr   hud.cont.checkFire
        bne   hud.cont.accept
        dec   hud.cont.ticks
        bne   @frame
        ldb   hud.cont.digit
        decb
        bpl   @digit
        ; Le decompte est alle au bout sans reponse : pas de continue. On laisse
        ; d'abord le morceau finir sa phrase — il tombe a la meme trame a
        ; quelques unites pres, donc l'attente est nulle ou tres courte.
        jsr   hud.cont.musicWait
        bra   hud.cont.refuse

; ---------------------------------------------------------------------------
; Le joueur reprend : la limite arcade se consomme, les vies reviennent au
; compte d'ouverture de partie (corps de stage : `ldb #2 / stb globals.lives`)
; et l'appelant retrouve un `globals.lives` positif.
; ---------------------------------------------------------------------------
hud.cont.accept
        ; La musique du continue reste armee en sortant : c'est le stage qui
        ; reprend la sienne, lui seul sait laquelle. Voir stage-main.asm.
        ; Le compte tourne aussi en continues infinis : il n'est alors jamais
        ; lu, et son bouclage a 256 est sans consequence.
        inc   game.continueUsed
        ldb   #2
        stb   globals.lives
        bra   hud.cont.leave

hud.cont.refuse
        ; Les vies restent negatives : GAME OVER suit chez l'appelant. On lui
        ; pose sa musique au passage — c'est le meme geste, et le chemin
        ; « continue deja consomme » passe ici sans avoir rien affiche.
        ldx   #sounds.gameover.ymm
        ldb   #ymm.NO_LOOP
        jsr   game.music.play

; L'ecran s'efface lui-meme avant de rendre la main — la suite repasse en
; 320x200 pour READY / GAME OVER, ou nos octets BM16 se reliraient en bouillie.
hud.cont.leave
        ldd   #Pal_black
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow
        ldx   #hud.cont.screenOff
        jsr   hud.cont.paintLines
        ldx   #hud.cont.blank
        jmp   hud.cont.paintDigit

; ---------------------------------------------------------------------------
; hud.cont.gameOverWait — tenir GAME OVER a l'ecran jusqu'a la fin du morceau
;
; Le corps de stage affichait le message trois secondes (`_waitFrames #150`, la
; duree v1, quand aucune musique n'accompagnait le message). `sounds.gameover`
; en dure six et demie, et elle etait coupee net : c'est l'IRQ utilisateur qui
; appelle `_ymm.frame.play`, et `stage.gameOver` commence par `IrqOff`.
;
; L'attente vit ICI et pas dans le corps de stage pour deux raisons : le main
; d'un stage n'a que quelques octets de marge, et elle est la meme pour les
; huit. Elle y coute d'ailleurs MOINS que ce qu'elle remplace — trois
; instructions de `paged.call` contre les quinze octets de la macro d'attente.
;
; Le plancher de trois secondes est garde avant le sondage : si le morceau
; n'etait pas arme, le message ne doit pas passer en un eclair.
;
; `paged.call` est reentrant et nous sommes deja dedans (le stage nous a
; atteints par lui) : sa page d'origine vit sur la pile, pas dans un operande.
; Il ecrase B et les drapeaux, d'ou le `tsta` sur le retour de `ymm.playing`.
;
; `hud.cont.musicWait` est le sondage seul, partage avec la fin du decompte.
; Un morceau non arme, ou deja fini, le traverse en une trame — donc les deux
; appelants sont sûrs de rendre la main.
; ---------------------------------------------------------------------------
hud.cont.gameOverWait
        _waitFrames #150               ; le plancher v1 : trois secondes
hud.cont.musicWait
@wait   _waitFrames #1
        lda   #map.RAM_OVER_CART+engine.sound.ymm.page
        ldx   #ymm.playing
        jsr   paged.call
        tsta
        bne   @wait
        rts

; ---------------------------------------------------------------------------
; Les trois lignes de texte. X = table de trois paires (adresse ecran, chaine).
; `hud.drawStr` ecrase A, X, Y et U : la table et le compteur passent par la
; pile.
; ---------------------------------------------------------------------------
hud.cont.paintLines
        ldb   #3
@l      ldu   ,x++
        ldy   ,x++
        pshs  b,x
        jsr   hud.drawStr
        puls  b,x
        decb
        bne   @l
        rts

hud.cont.screenOn
        fdb   hud.cont.line1U,hud.cont.strTitle
        fdb   hud.cont.line2U,hud.cont.strPush
        fdb   hud.cont.line3U,hud.cont.strFree
hud.cont.screenOff
        fdb   hud.cont.line1U,hud.cont.strBlank
        fdb   hud.cont.line2U,hud.cont.strBlank
        fdb   hud.cont.line3U,hud.cont.strBlank

; ---------------------------------------------------------------------------
; Le gros chiffre. X = 9 octets de motif, un par rangee, bits 5..0 = colonnes
; 0..5. Chaque cellule est un glyphe de la police : 'O' ou l'espace, qui peint
; l'index 0 — c'est lui qui efface.
; ---------------------------------------------------------------------------
hud.cont.paintDigit
        ldu   #hud.cont.digitU
        lda   #9
        sta   hud.cont.rows
@row    ldb   ,x+
        aslb                          ; colonne 0 (bit 5) amenee en bit 7
        aslb
        lda   #6
        sta   hud.cont.cols
@cell   aslb                          ; la colonne courante part dans la retenue
        pshs  b
        bcc   @blank
        jsr   DRAW_text_o
        bra   @next
@blank  jsr   DRAW_text_space
@next   puls  b
        leau  1,u
        dec   hud.cont.cols
        bne   @cell
        leau  314,u                   ; rangee suivante : 8 lignes, moins les 6 cellules
        dec   hud.cont.rows
        bne   @row
        rts

; ---------------------------------------------------------------------------
; Le declencheur, copie de `title.checkStart` (v1 : Fire_Press) : boutons A et
; B des deux ports, PLUS le bit KTEST du PIA avec son propre front. Sans
; extension manette le port se lit tout « tenu » (vecu sous toje), donc le
; front clavier ne peut pas se deduire du seul `joypad.pressed.fire`.
; Sortie : Z=0 si le joueur reprend.
; ---------------------------------------------------------------------------
hud.cont.checkFire
        lda   joypad.pressed.fire
        anda  #joypad.x.A+joypad.x.B
        bne   @go
        lda   map.MC6821.PRA
        lsra
        bcs   @keyDown
        clr   hud.cont.keydown        ; touche relachee : le front se rearme
        clra                          ; Z=1 : on continue d'attendre
        rts
@keyDown
        tst   hud.cont.keydown
        bne   @held                   ; toujours tenue : elle a deja servi
        inc   hud.cont.keydown
        lda   #1                      ; Z=0 : le joueur reprend
        rts
@held   clra
@go     rts

hud.cont.digit   fcb 0                ; le chiffre affiche (9..0)
hud.cont.ticks   fcb 0                ; trames restantes sur ce chiffre
hud.cont.rows    fcb 0
hud.cont.cols    fcb 0
hud.cont.keydown fcb 0                ; front du declencheur clavier

; Les chaines sont espacees comme dans l'arcade (" C O N T I N U E "), sauf
; l'invite : la ROM ecrit « PUSH START BUTTON » d'un seul tenant, et la v1
; porte deja « PUSH FIRE BUTTON » mot pour mot dans le texte du title.
hud.cont.strTitle fcc 'C O N T I N U E'
                  fcb 0
hud.cont.strPush  fcc 'PUSH FIRE BUTTON'
                  fcb 0
; L'arcade la pose sous l'invite (enregistrement 0x878C, palette 5, 18x1 en
; $2B5C) quand `coinage_row_slot1` est nul — c'est-a-dire en free play, notre
; cas. La variante a credits (0x87B0 « C R E D I T » + cinq chiffres) n'a pas
; d'objet ici.
hud.cont.strFree  fcc ' F R E E   P L A Y'
                  fcb 0
hud.cont.strBlank fcc '                  '
                  fcb 0

; Les dix chiffres, releves dans la ROM arcade (0x0E6A..0x1086) et bit-packes :
; un octet par rangee, bits 5..0 = les six colonnes.
hud.cont.blank  fcb %000000,%000000,%000000,%000000,%000000,%000000,%000000,%000000,%000000
hud.cont.digits
        fcb   %011110,%100001,%100001,%100001,%100001,%100001,%100001,%100001,%011110   * 0
        fcb   %000100,%001100,%000100,%000100,%000100,%000100,%000100,%000100,%001110   * 1
        fcb   %011110,%100001,%100001,%000001,%001110,%010000,%100000,%100000,%111111   * 2
        fcb   %011110,%100001,%100001,%000001,%000110,%000001,%100001,%100001,%011110   * 3
        fcb   %000110,%001010,%010010,%100010,%100010,%100010,%111111,%000010,%000010   * 4
        fcb   %011111,%100000,%100000,%100000,%011110,%000001,%000001,%100001,%011110   * 5
        fcb   %011110,%100001,%100000,%100000,%011110,%100001,%100001,%100001,%011110   * 6
        fcb   %011110,%000001,%000001,%000001,%000010,%000100,%001000,%001000,%001000   * 7
        fcb   %011110,%100001,%100001,%100001,%011110,%100001,%100001,%100001,%011110   * 8
        fcb   %011110,%100001,%100001,%100001,%011110,%000001,%000001,%000001,%011110   * 9

; ===========================================================================
; STAGE-CLEARED FONT  (duplicated from objects/levels/00/text/text.asm)
; ---------------------------------------------------------------------------
; Full title-screen glyph set, copied here so the phase-4 STAGE CLEARED / STAGE
; SCORE text draws letters without depending on the title objects bank.
; letter_addr is indexed by (ASCII-32)*2; each DRAW_text_X draws one 4px-wide x
; ~8px-tall glyph at U (RAMA $C000-$DFFF), both banks via LEAU -$2000, the caller
; advancing leau 1,u per char. Same 4px scale as the HUD digits (DRAW_Img_hud_*).
; Object-local labels -> the title copy and this one do not clash at link.
; V2-DEVIATION (15/08/2026, decision auteur) : le fond des cellules peint
; l'INDEX 0, jamais le 15 — la copie v1 posait $F, noir sur la palette du
; title mais une couleur de jeu (saumon) sur celles des stages : des paves
; derriere chaque lettre du releve. L'index 0 est noir dans TOUTES les
; palettes (convention transparence/bordure). Transformation mecanique
; F->0 sur les immediats LDA des 104 glyphes, l'espace devenant tout noir
; (son role : effacer sous les chiffres qui tournent).
; ===========================================================================
letter_addr     fdb DRAW_text_space                * 32 = space
                fdb DRAW_text_exclam               * 33 = !
                fdb DRAW_text_space                * 34
                fdb DRAW_text_space                * 35
                fdb DRAW_text_space                * 36
                fdb DRAW_text_space                * 37
                fdb DRAW_text_space                * 38
                fdb DRAW_text_space                * 39
                fdb DRAW_text_space                * 40
                fdb DRAW_text_space                * 41
                fdb DRAW_text_space                * 42
                fdb DRAW_text_space                * 43
                fdb DRAW_text_space                * 44
                fdb DRAW_text_space                * 45
                fdb DRAW_text_dot                  * 46
                fdb DRAW_text_space                * 47
numbers_addr    fdb DRAW_text_0                    * 48 = 0                
                fdb DRAW_text_1                    * 49 = 1
                fdb DRAW_text_2                    * 50 = 2
                fdb DRAW_text_3                    * 51
                fdb DRAW_text_4                    * 52
                fdb DRAW_text_5                    * 53
                fdb DRAW_text_6                    * 54
                fdb DRAW_text_7                    * 55 = 7
                fdb DRAW_text_8                    * 56 = 8
                fdb DRAW_text_9                    * 57 = 9
                fdb DRAW_text_space                * 58
                fdb DRAW_text_space                * 59
                fdb DRAW_text_space                * 60
                fdb DRAW_text_space                * 61
                fdb DRAW_text_space                * 62
                fdb DRAW_text_space                * 63
                fdb DRAW_text_space                * 64
                fdb DRAW_text_a                    * 65 = A
                fdb DRAW_text_b                    * 66
                fdb DRAW_text_c                    * 67
                fdb DRAW_text_d                    * 68
                fdb DRAW_text_e                    * 69
                fdb DRAW_text_f                    * 70
                fdb DRAW_text_g                    * 71
                fdb DRAW_text_h                    * 72
                fdb DRAW_text_i                    * 73
                fdb DRAW_text_j                    * 74
                fdb DRAW_text_k                    * 75
                fdb DRAW_text_l                    * 76
                fdb DRAW_text_m                    * 77
                fdb DRAW_text_n                    * 78
                fdb DRAW_text_o                    * 79
                fdb DRAW_text_p                    * 80
                fdb DRAW_text_q                    * 81
                fdb DRAW_text_r                    * 82
                fdb DRAW_text_s                    * 83
                fdb DRAW_text_t                    * 84
                fdb DRAW_text_u                    * 85
                fdb DRAW_text_v                    * 86
                fdb DRAW_text_w                    * 87
                fdb DRAW_text_x                    * 88
                fdb DRAW_text_y                    * 89
                fdb DRAW_text_z                    * 90
                fdb DRAW_text_copy                 * 91 = [ (but used for (c) )

DRAW_text_dot
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$04

	STA 80,U
	LDA #$06

	STA 40,U
	LDA #$00

	STA ,U
	STA -40,U
	STA -80,U
	STA -120,U
	LEAU -40,U

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 80,U
	STA 40,U
	STA ,U
	STA -40,U
	STA -80,U
	STA -120,U
	LEAU -40,U

	STA -120,U
	puls u,pc
DRAW_text_z
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$05

	STA -80,U
	LDA #$00

	STA -120,U
	LDA #$50

	STA ,U
	LDA #$55
	STA -40,U
	LDA #$44
	STA 80,U
	LDA #$40

	STA 40,U
	LEAU -40,U

	LDA #$36
	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 40,U
	STA ,U
	STA -40,U
	LDA #$60

	STA -120,U
	LDA #$50

	STA -80,U
	LDA #$40

	STA 80,U
	LEAU -40,U

	LDA #$60

	STA -120,U
	puls u,pc

DRAW_text_3
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 40,U
	STA ,U
	LDA #$05

	STA -40,U
	LDA #$00

	STA -80,U
	STA -120,U
	LDA #$44
	STA 80,U
	LEAU -40,U

	LDA #$36
	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$60

	STA -120,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$40

	STA 80,U
	STA 40,U
	LEAU -40,U

	LDA #$60

	STA -120,U
	puls u,pc

DRAW_text_o
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$04

	STA 80,U
	LDA #$40

	STA 40,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$30

	STA -120,U
	LEAU -40,U

	LDA #$03

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 80,U
	LDA #$40

	STA 40,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	LDA #$00

	STA -120,U
	puls u,pc

DRAW_text_w
        pshs u
	LEAU 40,U

	LDA #$55
	STA ,U
	STA -40,U
	LDA #$50

	STA -80,U
	LDA #$40

	STA 80,U
	LDA #$44
	STA 40,U
	LDA #$00

	STA 120,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	LDA #$30

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$60

	STA -120,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$40

	STA 80,U
	STA 40,U
	LEAU -40,U

	LDA #$60

	STA -120,U
	puls u,pc

DRAW_text_b
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$44
	STA 80,U
	LDA #$40

	STA 40,U
	LDA #$60

	STA -120,U
	LDA #$50

	STA ,U
	LDA #$55
	STA -40,U
	LDA #$50

	STA -80,U
	LEAU -40,U

	LDA #$36
	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 80,U
	LDA #$00

	STA -40,U
	LDA #$60
	STA -120,U
	LDA #$50
	STA ,U
	STA -80,U
	LDA #$40
	STA 40,U
	LEAU -40,U

	LDA #$00

	STA -120,U
	puls u,pc

DRAW_text_i
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$04

	STA 80,U
	STA 40,U
	LDA #$05

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$06

	STA -120,U
	LEAU -40,U

	LDA #$03

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 80,U
	STA 40,U
	STA ,U
	STA -40,U
	STA -80,U
	STA -120,U
	LEAU -40,U

	STA -120,U
	puls u,pc

DRAW_text_5
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 40,U
	STA ,U
	LDA #$44
	STA 80,U
	LDA #$55
	STA -40,U
	LDA #$50

	STA -80,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	LDA #$36
	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$40

	STA 80,U
	STA 40,U
	LDA #$00

	STA 120,U
	STA -80,U
	STA -120,U
	LDA #$50

	STA ,U
	STA -40,U
	LEAU -40,U

	LDA #$60

	STA -120,U
	puls u,pc

DRAW_text_d
        pshs u
	LEAU 40,U

	LDA #$44
	STA 80,U
	LDA #$40

	STA 40,U
	LDA #$00

	STA 120,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	LDA #$36
	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 80,U
	LDA #$60

	STA -120,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$40

	STA 40,U
	LEAU -40,U

	LDA #$00

	STA -120,U
	puls u,pc

DRAW_text_q
        pshs u
	LEAU 40,U

	LDA #$54
	STA ,U
	LDA #$50

	STA -40,U
	STA -80,U
	LDA #$44
	STA 40,U
	LDA #$00

	STA 120,U
	LDA #$05

	STA 80,U
	LDA #$30

	STA -120,U
	LEAU -40,U

	LDA #$03

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$40

	STA 80,U
	STA 40,U
	LDA #$00

	STA 120,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	LDA #$00

	STA -120,U
	puls u,pc

DRAW_text_8
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$50

	STA ,U
	LDA #$55
	STA -40,U
	LDA #$50

	STA -80,U
	LDA #$44
	STA 80,U
	LDA #$40

	STA 40,U
	LDA #$30

	STA -120,U
	LEAU -40,U

	LDA #$03

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$40

	STA 80,U
	STA 40,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	STA -120,U
	puls u,pc

DRAW_text_2
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA -80,U
	STA -120,U
	LDA #$44
	STA 80,U
	LDA #$40

	STA 40,U
	LDA #$50

	STA ,U
	LDA #$55
	STA -40,U
	LEAU -40,U

	LDA #$36
	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 40,U
	STA ,U
	LDA #$40

	STA 80,U
	LDA #$50

	STA -40,U
	STA -80,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	STA -120,U
	puls u,pc

DRAW_text_n
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$40

	STA 80,U
	STA 40,U
	LDA #$60

	STA -120,U
	LDA #$54
	STA ,U
	LDA #$55
	STA -40,U
	STA -80,U
	LEAU -40,U

	LDA #$30

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$40

	STA 80,U
	STA 40,U
	LDA #$00

	STA 120,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	STA -120,U
	puls u,pc

DRAW_text_v
        pshs u
	LEAU 40,U

	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$40

	STA 80,U
	LDA #$44
	STA 40,U
	LDA #$00

	STA 120,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	LDA #$30

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 80,U
	STA 40,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	STA -120,U
	puls u,pc

DRAW_text_exclam
        pshs u
	LEAU 40,U

	LDA #$40

	STA 80,U
	LDA #$00

	STA 120,U
	STA 40,U
	LDA #$05

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$00

	STA -120,U
	LEAU -40,U

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$50
	STA -40,U
	STA -80,U
	LDA #$00

	STA 120,U
	STA 80,U
	STA 40,U
	STA ,U
	LDA #$60
	STA -120,U
	LEAU -40,U

	LDA #$30
	STA -120,U
	puls u,pc

DRAW_text_c
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$04

	STA 80,U
	LDA #$40

	STA 40,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$30

	STA -120,U
	LEAU -40,U

	LDA #$03

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$60

	STA -120,U
	LDA #$40

	STA 40,U
	LDA #$00

	STA ,U
	LDA #$00

	STA 120,U
	STA 80,U
	STA -40,U
	STA -80,U
	LEAU -40,U

	STA -120,U
	puls u,pc

DRAW_text_h
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$60

	STA -120,U
	LDA #$50

	STA ,U
	LDA #$55
	STA -40,U
	LDA #$50

	STA -80,U
	LDA #$40

	STA 80,U
	STA 40,U
	LEAU -40,U

	LDA #$30

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$40

	STA 80,U
	STA 40,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	STA -120,U
	puls u,pc

DRAW_text_4
        pshs u
	LEAU 40,U

	LDA #$60

	STA -120,U
	LDA #$55
	STA ,U
	LDA #$50

	STA -40,U
	STA -80,U
	LDA #$00

	STA 120,U
	STA 80,U
	STA 40,U
	LEAU -40,U

	LDA #$30

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$40

	STA 80,U
	STA 40,U
	LDA #$00

	STA 120,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	STA -120,U
	puls u,pc

DRAW_text_e
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$44
	STA 80,U
	LDA #$40

	STA 40,U
	LDA #$60

	STA -120,U
	LDA #$50

	STA ,U
	LDA #$55
	STA -40,U
	LDA #$50

	STA -80,U
	LEAU -40,U

	LDA #$36
	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 40,U
	STA -80,U
	STA -120,U
	LDA #$40
	STA 80,U
	LDA #$00
	STA ,U
	STA -40,U
	LEAU -40,U

	LDA #$60
	STA -120,U
	puls u,pc

DRAW_text_9
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 40,U
	STA ,U
	LDA #$44
	STA 80,U
	LDA #$55
	STA -40,U
	LDA #$50

	STA -80,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	LDA #$36
	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$40

	STA 80,U
	STA 40,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	STA -120,U
	puls u,pc

DRAW_text_p
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$60

	STA -120,U
	LDA #$50

	STA ,U
	LDA #$55
	STA -40,U
	LDA #$50

	STA -80,U
	LDA #$40

	STA 80,U
	STA 40,U
	LEAU -40,U

	LDA #$36
	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 80,U
	STA 40,U
	STA ,U
	STA -40,U
	LDA #$50

	STA -80,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	LDA #$00

	STA -120,U
	puls u,pc

DRAW_text_m
        pshs u
	LEAU 40,U

	LDA #$50

	STA ,U
	STA -40,U
	LDA #$55
	STA -80,U
	LDA #$40

	STA 80,U
	STA 40,U
	LDA #$00

	STA 120,U
	LDA #$66
	STA -120,U
	LEAU -40,U

	LDA #$30

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$40

	STA 80,U
	STA 40,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	STA -120,U
	puls u,pc

DRAW_text_x
        pshs u
	LEAU 40,U

	LDA #$60

	STA -120,U
	LDA #$40

	STA 80,U
	STA 40,U
	LDA #$55
	STA -80,U
	LDA #$00

	STA 120,U
	LDA #$05

	STA ,U
	STA -40,U
	LEAU -40,U

	LDA #$30

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA -40,U
	STA -80,U
	LDA #$40

	STA 80,U
	STA 40,U
	LDA #$60

	STA -120,U
	LDA #$50

	STA ,U
	LEAU -40,U

	LDA #$60

	STA -120,U
	puls u,pc

DRAW_text_1
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$04

	STA 80,U
	STA 40,U
	LDA #$05

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$06

	STA -120,U
	LEAU -40,U

	LDA #$03

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 80,U
	STA 40,U
	STA ,U
	STA -40,U
	STA -80,U
	STA -120,U
	LEAU -40,U

	STA -120,U
	puls u,pc

DRAW_text_copy
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$04

	STA 80,U
	LDA #$30

	STA -120,U
	LDA #$54
	STA ,U
	STA -40,U
	STA -80,U
	LDA #$40

	STA 40,U
	LEAU -40,U

	LDA #$03

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$04

	STA 40,U
	LDA #$05

	STA -40,U
	LDA #$06

	STA -120,U
	LDA #$55
	STA ,U
	STA -80,U
	LDA #$40

	STA 80,U
	LEAU -40,U

	LDA #$60

	STA -120,U
	puls u,pc

DRAW_text_u
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$04

	STA 80,U
	LDA #$40

	STA 40,U
	LDA #$60

	STA -120,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LEAU -40,U

	LDA #$30

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 80,U
	LDA #$40

	STA 40,U
	LDA #$60

	STA -120,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LEAU -40,U

	LDA #$60

	STA -120,U
	puls u,pc

DRAW_text_7
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 80,U
	STA 40,U
	STA ,U
	STA -40,U
	STA -80,U
	STA -120,U
	LEAU -40,U

	LDA #$36
	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$60

	STA -120,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$40

	STA 80,U
	STA 40,U
	LEAU -40,U

	LDA #$60

	STA -120,U
	puls u,pc

DRAW_text_k
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$40

	STA 80,U
	STA 40,U
	LDA #$55
	STA ,U
	LDA #$50

	STA -40,U
	STA -80,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	LDA #$30

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$50

	STA -40,U
	STA -80,U
	LDA #$40

	STA 80,U
	STA 40,U
	LDA #$00

	STA 120,U
	STA ,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	LDA #$00

	STA -120,U
	puls u,pc

DRAW_text_s
        pshs u
	LEAU 40,U

	LDA #$36
	STA -120,U
	LDA #$44
	STA 80,U
	LDA #$55
	STA -40,U
	LDA #$50

	STA -80,U
	LDA #$00

	STA 120,U
	STA 40,U
	STA ,U
	LEAU -40,U

	LDA #$03

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 80,U
	STA -40,U
	STA -80,U
	STA -120,U
	LDA #$50

	STA ,U
	LDA #$40

	STA 40,U
	LEAU -40,U

	LDA #$60

	STA -120,U
	puls u,pc

DRAW_text_f
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$50

	STA ,U
	LDA #$55
	STA -40,U
	LDA #$50

	STA -80,U
	LDA #$40

	STA 80,U
	STA 40,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	LDA #$36
	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 80,U
	STA 40,U
	STA ,U
	STA -40,U
	STA -80,U
	STA -120,U
	LEAU -40,U

	LDA #$60

	STA -120,U
	puls u,pc

DRAW_text_l
        pshs u
	LEAU 40,U

	LDA #$60

	STA -120,U
	LDA #$44
	STA 80,U
	LDA #$40

	STA 40,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$00

	STA 120,U
	LEAU -40,U

	LDA #$30

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 40,U
	STA ,U
	STA -40,U
	STA -80,U
	STA -120,U
	LDA #$40

	STA 80,U
	LEAU -40,U

	LDA #$00

	STA -120,U
	puls u,pc

DRAW_text_0
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$44
	STA 80,U
	LDA #$40

	STA 40,U
	LDA #$30

	STA -120,U
	LEAU -40,U

	LDA #$03

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$60

	STA -120,U
	LDA #$40

	STA 40,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$00

	STA 120,U
	STA 80,U
	LEAU -40,U

	LDA #$60

	STA -120,U
	puls u,pc

DRAW_text_y
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$04

	STA 80,U
	STA 40,U
	LDA #$05

	STA ,U
	STA -40,U
	LDA #$50

	STA -80,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	LDA #$30

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 80,U
	STA 40,U
	STA ,U
	STA -40,U
	LDA #$60

	STA -120,U
	LDA #$50

	STA -80,U
	LEAU -40,U

	LDA #$60

	STA -120,U
	puls u,pc

DRAW_text_a
        pshs u
	LEAU 40,U

	LDA #$40

	STA 80,U
	STA 40,U
	LDA #$00

	STA 120,U
	LDA #$03

	STA -120,U
	LDA #$55
	STA ,U
	LDA #$50

	STA -40,U
	STA -80,U
	LEAU -40,U

	LDA #$00

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$40
	STA 80,U
	STA 40,U
	LDA #$50
	STA ,U
	STA -40,U
	STA -80,U
	LDA #$60
	STA -120,U
	LEAU -40,U

	LDA #$30
	STA -120,U
	puls u,pc

DRAW_text_t
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$04

	STA 80,U
	STA 40,U
	LDA #$05

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$06

	STA -120,U
	LEAU -40,U

	LDA #$36
	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 80,U
	STA 40,U
	STA ,U
	STA -40,U
	STA -80,U
	STA -120,U
	LEAU -40,U

	LDA #$60

	STA -120,U
	puls u,pc

DRAW_text_space
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 80,U
	STA 40,U
	STA ,U
	STA -40,U
	STA -80,U
	STA -120,U
	LEAU -40,U

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA 80,U
	STA 40,U
	STA ,U
	STA -40,U
	STA -80,U
	STA -120,U
	LEAU -40,U

	STA -120,U
	puls u,pc

DRAW_text_6
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$44
	STA 80,U
	LDA #$40

	STA 40,U
	LDA #$50

	STA ,U
	LDA #$55
	STA -40,U
	LDA #$50

	STA -80,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	LDA #$36
	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA -80,U
	STA -120,U
	LDA #$40

	STA 80,U
	STA 40,U
	LDA #$50

	STA ,U
	STA -40,U
	LEAU -40,U

	LDA #$60

	STA -120,U
	puls u,pc

DRAW_text_j
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$04

	STA 80,U
	LDA #$00

	STA -40,U
	STA -80,U
	STA -120,U
	LDA #$50

	STA ,U
	LDA #$44
	STA 40,U
	LEAU -40,U

	LDA #$00

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$60

	STA -120,U
	LDA #$40

	STA 40,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$00

	STA 120,U
	STA 80,U
	LEAU -40,U

	LDA #$30

	STA -120,U
	puls u,pc

DRAW_text_r
        pshs u
	LEAU 40,U

	LDA #$00

	STA 120,U
	LDA #$60

	STA -120,U
	LDA #$55
	STA ,U
	STA -40,U
	LDA #$50

	STA -80,U
	LDA #$40

	STA 80,U
	STA 40,U
	LEAU -40,U

	LDA #$36
	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$00

	STA 120,U
	STA ,U
	STA -40,U
	LDA #$50

	STA -80,U
	LDA #$40

	STA 80,U
	STA 40,U
	LDA #$60

	STA -120,U
	LEAU -40,U

	LDA #$00

	STA -120,U
	puls u,pc

DRAW_text_g
        pshs u
	LEAU 40,U

	LDA #$30

	STA -120,U
	LDA #$40

	STA 40,U
	LDA #$50

	STA ,U
	STA -40,U
	STA -80,U
	LDA #$00

	STA 120,U
	LDA #$04

	STA 80,U
	LEAU -40,U

	LDA #$03

	STA -120,U

	LEAU -$2000,U
	LEAU 40,U

	LDA #$50

	STA ,U
	STA -40,U
	LDA #$40

	STA 80,U
	STA 40,U
	LDA #$00

	STA 120,U
	STA -80,U
	STA -120,U
	LEAU -40,U

	LDA #$60

	STA -120,U
	puls u,pc
