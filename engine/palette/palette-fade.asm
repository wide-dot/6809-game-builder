* ---------------------------------------------------------------------------
* palette.fade.to — fondu d'une palette de travail vers une palette CIBLE,
*                   trame par trame, par scrutation du VBL : aucune IRQ requise
* palette.fade    — le cas particulier d'une cible UNIE (une couleur)
* ---------------------------------------------------------------------------
*
* Repris du secteur de boot v1 (thomson-to8-game-engine,
* engine/boot/boot-fd.asm, PalFade/PalRun, commit 10b1d58c) et rendu
* autonome. La v1 le soudait au boot : palette du menu TO8 en dur, six
* couleurs groupees par plages d'entrees (le secteur faisait 256 octets), ses
* variables en page directe $62, une seule couleur d'arrivee. Ici : seize
* entrees pleines, avancees SUR PLACE vers seize cibles, une pile pour toute
* memoire — appelable d'ou l'on veut, au boot comme pendant une transition
* disque ou l'IRQ est coupee. Un fondu d'ENTREE est le meme geste : partir
* d'une palette de travail noire vers la palette de l'image.
* Cas de migration : docs/lang/en/migration/boot-palette-fade.md
*
* palette.fade.to
*   Entree : U = la palette de travail, 16 entrees de 2 octets
*                (GGGGRRRR, 0000BBBB — le format de l'EF9369 et de Pal_buffer),
*                en RAM : elle est modifiee sur place
*            X = la palette cible, meme format, lue seulement
*   Sortie : la palette de travail vaut la cible, et la gate array aussi.
*            A, B, X, Y, U detruits. DP intact (adressage etendu seulement).
*            Aucune variable globale.
*   Duree  : une trame par pas, autant de pas que la plus grande distance de
*            composante — 15 au plus, soit 300 ms a 50 Hz. Une palette deja
*            egale a la cible coute une trame (elle est ecrite une fois).
*
* palette.fade
*   Entree : U = la palette de travail ; A = cible vert|rouge, B = cible bleu.
*   La cible unie est depliee en seize entrees sur la pile (32 octets), puis
*   c'est palette.fade.to.
*
* Chaque trame, comme la v1 : attendre que le faisceau quitte l'ecran utile,
* laisser passer 40 lignes pour etre dans la bordure invisible — l'EF9369
* ecrit en plein ecran fait de la neige —, avancer chaque composante d'un
* cran vers sa cible, puis ecrire les seize entrees. On sort quand plus rien
* n'a bouge. Le pas est de 1/15 par composante : un fondu franc, sans table.
*
* Les registres viennent de map.const.asm de la machine (map.EF9369.A/.D,
* map.CF74021.SYS1) : inclure le bon avant ce fichier. Verifie sur TO8.
* ---------------------------------------------------------------------------
palette.fade
        ldx   #16
@fill   pshs  a,b                      ; une entree : A (vert|rouge) puis B (bleu)
        leax  -1,x
        bne   @fill
        tfr   s,x                      ; X = la cible, seize fois la meme couleur
        bsr   palette.fade.to
        leas  32,s
        rts

palette.fade.to
        pshs  u,x                      ; 0,s X ; 2,s U
        ldb   #$0F
        pshs  b                        ; le masque de composante : rouge d'abord
        clr   ,-s                      ; le temoin « quelque chose a bouge »
* trame de pile : 0,s bouge / 1,s masque / 2,s X cible / 4,s U travail
@frame
        clr   ,s
@vbl1   tst   map.CF74021.SYS1         ; le faisceau n'est pas dans l'ecran utile
        bpl   @vbl1                    ;   tant que le bit est a 0 on boucle
@vbl2   tst   map.CF74021.SYS1         ; le faisceau est dans l'ecran utile
        bmi   @vbl2                    ;   tant que le bit est a 1 on boucle
        ldx   #320                     ; 40 lignes x 8 cycles : la bordure
@border leax  -1,x
        bne   @border
* --- avancer les seize entrees d'un cran vers leur cible ---------------------
        ldu   4,s
        ldx   2,s
        ldy   #16
@entry
@gr     lda   ,u                       ; vert|rouge courant
        anda  1,s                      ;   la composante que le masque isole
        ldb   ,x                       ; sa cible
        andb  1,s
        pshs  b
        cmpa  ,s+                      ; courante contre cible
        beq   @grNext                  ;   egales : rien a faire
        bhi   @grDec
        lda   #$11                     ; l'increment : $01 (rouge) ou $10 (vert)
        anda  1,s
        adda  ,u
        bra   @grSave
@grDec  lda   #$11
        anda  1,s
        nega
        adda  ,u                       ; jamais de retenue vers l'autre nibble :
@grSave sta   ,u                       ;   on ne decremente qu'une composante > 0
        inc   ,s
@grNext com   1,s                      ; l'autre composante
        bmi   @gr                      ;   $F0 : seconde passe, le vert
* le bleu
        ldb   1,u
        cmpb  1,x
        beq   @bNext
        bhi   @bDec
        incb
        bra   @bSave
@bDec   decb
@bSave  stb   1,u
        inc   ,s
@bNext  leau  2,u
        leax  2,x
        leay  -1,y
        bne   @entry
* --- ecrire les seize entrees, encore dans la bordure -----------------------
        ldu   4,s
        clra
        sta   map.EF9369.A             ; index de couleur 0, auto-incremente
        ldy   #16
@write  ldd   ,u++
        sta   map.EF9369.D             ; vert et rouge
        stb   map.EF9369.D             ; bleu
        leay  -1,y
        bne   @write
        tst   ,s
        bne   @frame                   ; quelque chose a bouge : trame suivante
        leas  6,s
        rts

* ---------------------------------------------------------------------------
* palette.to8.monitor — la palette du menu du moniteur TO8, telle que la
* machine l'affiche a l'amorcage. Relevee par la v1 (boot-fd.asm, pal_from et
* pal_len : six couleurs et leurs plages d'entrees), depliee ici en seize
* entrees pour palette.fade. Donnee en RAM : un fondu la modifie sur place,
* la recopier si l'on veut la garder.
* ---------------------------------------------------------------------------
palette.to8.monitor
        fdb   $0000,$0000,$0000,$0000,$0000,$0000  ; 0-5   noir
        fdb   $F00F                                ; 6     turquoise (bordure)
        fdb   $FF0F                                ; 7     blanc
        fdb   $7707,$7707,$7707                    ; 8-10  gris (fond bas)
        fdb   $AA03                                ; 11    jaune (interieur de case)
        fdb   $330A,$330A,$330A,$330A              ; 12-15 mauve (fond TO8)
