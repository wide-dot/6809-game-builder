; -----------------------------------------------------------------------------
; Pellet Scroll (pscroll) — couche persistante a defilement HORIZONTAL
; -----------------------------------------------------------------------------
; wide-dot - Benoit Rousseau - 08/2026
; ---------------------------------------
; Clone de mscroll (engine/graphics/tilemap/mscroll/mscroll.asm) AMPUTE de sa
; moitie verticale. Etude : games/r-type/etude-pscroll-gommes-stage4.md
;
; LE CONTRAT : les gfx sont GRAVES dans un buffer de code persistant et seul
; le DELTA est remis a jour — ce que le scroll fait entrer, et (plus tard) les
; gommes ajoutees ou retirees. La bande entiere est repeinte chaque trame par
; stack blast, a cout CONSTANT, quel que soit l'etat du champ.
;
; CE QUE L'ABSENCE DE SCROLL VERTICAL SIMPLIFIE
; ---------------------------------------------
; 1. Le lien (rangee de carte -> ligne de buffer) est FIGE. Le feed connait sa
;    destination a la generation : pas de curseur a suivre, pas de cache de
;    rangee, pas de probleme de coin.
; 2. Pas de curseur vertical a suivre pour le CONTENU.
;
; CE QUI RESTE VRAI DE MSCROLL, ET QUE J'AVAIS CRU POUVOIR RETIRER
; ----------------------------------------------------------------
; ERREUR DU 22/08, TROUVEE PAR LE BANC : j'avais ecrit que le buffer n'avait
; pas besoin d'etre CYCLIQUE, la derive de cisaillement etant bornee a
; 7 lignes sur le niveau. C'est faux, et le banc l'a montre a la premiere
; bande non vide : `engraveColumn` recevait U = $4FF8, soit la ligne -1.
;
; Le cisaillement se compose de DEUX termes qui derivent ENSEMBLE avec la
; camera : le feed ecrit la colonne `n` lignes plus haut (n = coutures a
; gauche de la COLONNE, absolu) et le point d'entree porte l'index de couture
; de la CAMERA. Leur difference reste petite — c'est ce qui fait tenir
; l'image — mais leurs valeurs absolues, elles, montent sans fin. Et comme on
; nourrit des bandes situees DEVANT la camera, la difference passe a -1 des
; que la bande entrante appartient a la couture suivante : sur un buffer non
; cyclique, ca sort par le haut.
;
; C'est exactement pour ca que le buffer de mscroll est cyclique : le wrap
; absorbe la derive. Le cycle est donc REMIS (22/08, apres le banc) : jmp de
; rebouclage en fin de buffer, ligne de rangee prise modulo BUFFER_LINES, et
; sortie du blast repliee. La rangee A CHEVAL sur le bouclage — au plus une
; par colonne — ne peut pas se graver d'un trait : elle passe par un chemin
; lent qui relit les memes octets dans pscroll.row.data et reboucle ligne a
; ligne. Le chemin rapide (la routine cablee) sert tout le reste.
;
; LE RUBAN ET SA COUTURE (repris de mscroll, campagne du 20/08/2026)
; ------------------------------------------------------------------
; L'entree en milieu de ligne fait emprunter a chaque rangee ecran ses 4h
; premiers octets a la ligne de buffer suivante. La coupure est FIXE DANS LA
; CARTE — toujours sur les multiples de 160 px — d'ou la compensation : toute
; colonne situee apres n coutures est gravee n lignes plus haut, et le point
; d'entree porte l'index de couture de la camera. Rien n'est jamais re-nourri,
; l'image ne bouge pas.
;
; LE 1 PX
; -------
; En BM16 un octet porte 2 px : un pas de 2 px est un echange de zones
; ($A000 <-> $C000), un pas de 1 px est un decalage de QUARTET, donc une autre
; donnee. D'ou QUATRE buffers — deux plans x deux phases — et le bit 0 de la
; camera choisit la paire. Le blast ne coute pas un cycle de plus ; seul le
; feed est double.
;
; LES DONNEES
; -----------
; Les routines de gravure et les tables de colonne sont GENEREES par
; games/r-type/tools/gen_pscroll.py, qui prouve le rendu au pixel avant
; qu'une ligne de 6809 soit ecrite (28 598 400 px controles, 0 divergence).
; Une routine grave UNE RANGEE (6 lignes) x les 4 octets d'un plan ; la
; combinaison ne mentionne ni le plan ni la phase, d'ou 33 routines au lieu
; de 49.
;
; POINT OUVERT — OU VIT LE CODE DE GRAVURE (a trancher avant de faire tourner)
; ---------------------------------------------------------------------------
; Le blast monte la page du buffer dans la fenetre CARTOUCHE et y execute le
; code, S pointant l'ecran : c'est le montage de mscroll, il ne pose aucun
; probleme. La GRAVURE, elle, ecrit dans cette meme page — donc le code qui
; grave ne peut pas vivre dans la fenetre qu'il monte. Deux issues :
;   a) les 33 routines et la boucle sont RESIDENTES (page 1, RAM fixe) :
;      ~2 700 o, ce qui tient tout juste dans l'arene stage4.res (2 800) une
;      fois l'ancienne passe run-blast retiree. Les tables de colonne restent
;      paginees : on lit les 30 index dans un tampon resident de 30 octets
;      AVANT de monter la page du buffer ;
;   b) monter le buffer dans une autre fenetre que la cartouche pendant la
;      gravure — a verifier contre la carte memoire TO8 avant de s'y fier.
; (a) est la voie sure et c'est celle que je prendrais ; (b) demande une
; verification que je n'ai pas faite.
;
; PIEGES REPRIS DE clearblast/mscroll
; -----------------------------------
; - aucun bsr/rts tant que S est le pointeur d'ecriture ;
; - S dans la VRAM est legal, mais l'IRQ ecrit 12 octets juste sous la
;   position courante : garder $9FF4-$9FFF / $BFF4-$BFFF libres si la bande
;   part du haut de l'ecran ;
; - DP fait partie des octets pousses par le blast de clearblast — ici le
;   chunk pousse D et X seulement, DP n'est pas touche.
; -----------------------------------------------------------------------------

        opt   c

; constantes
; -----------------------------------------------------------------------------
pscroll.OPCODE_JMP_E  equ   $7E
pscroll.OPCODE_LDD_I  equ   $CC        ; ldd #imm
pscroll.OPCODE_LDX_I  equ   $8E        ; ldx #imm
pscroll.OPCODE_PSHS   equ   $34        ; pshs ...
pscroll.POSTB_DX      equ   $16        ; ... d,x  (b0000 0110 -> A,B,X)

pscroll.CHUNK_SIZE    equ   8          ; ldd#(3) ldx#(3) pshs(2) = 16 px
pscroll.CHUNKS_PER_LINE equ 10         ; 10 x 16 px = 160 px
pscroll.LINE_SIZE     equ   pscroll.CHUNKS_PER_LINE*pscroll.CHUNK_SIZE

 IFNDEF pscroll.BAND_LINES
pscroll.BAND_LINES    equ   180        ; le projet doit la definir
 ENDC
; Le buffer est CYCLIQUE : il lui suffit d'une ligne de plus que la bande (le
; jmp de sortie se pose une ligne sous la derniere peinte), le reste est de la
; marge de confort. La derive du cisaillement, elle, est absorbee par le
; bouclage — c'est la raison d'etre du cycle, voir l'en-tete.
pscroll.SEAM_PX       equ   160        ; la coupure du ruban, dans la carte
; Le biais de couture. Les positions se comptent EN DESCENDANT depuis lui :
; ligne d'une bande = BIAIS - coutures(bande), entree du blast = BIAIS -
; coutures(camera). Les deux restent dans [1..8], donc tout est positif et il
; n'y a AUCUN modulo a faire — ni piege signe possible.
pscroll.SEAM_BIAS     equ   8
; LE BIAIS DES RANGEES, distinct de celui de l'ENTREE. Le blast peint 180
; lignes a partir de pscroll.origin = SEAM_BIAS - coutures ; les rangees, elles,
; doivent commencer UNE LIGNE PLUS HAUT dans le buffer, sinon la derniere ligne
; de la rangee 29 tombe hors de la fenetre peinte (mesure du 23/08 : les 2 px
; de la ligne 190 manquaient, et manquaient seuls). Deux biais, deux roles : y
; toucher d'un seul cote deplace le champ, des deux cotes ne fait rien.
; LE BLAST NE PEINT PAS SA LIGNE D'ENTREE : il entre a la ligne pscroll.origin
; et la premiere ligne effectivement poussee est origin+1 (mesure du 23/08 :
; sans ce +1 tout le champ descend d'une ligne ET la derniere ligne de la
; rangee 29 tombe hors de la fenetre — les deux symptomes disparaissent
; ensemble). Les rangees commencent donc UNE LIGNE plus haut que l'entree.
pscroll.ROW_BIAS      equ   pscroll.SEAM_BIAS+1

 IFNDEF pscroll.BUFFER_LINES
; BAND + BIAIS : la derniere ligne gravee est BIAIS + 6*(ROWS-1) + 5, soit
; BIAIS + BAND - 1. Une colonne tient donc TOUJOURS d'un trait — le feed n'a
; aucun bouclage a gerer, et seul le run du blast en traverse un.
; MULTIPLE DE 4 OBLIGATOIRE. buildSkeleton ecrit le buffer par blocs de
; 64 octets (8 x pshs de 8) et s'arrete sur une EGALITE exacte avec le debut :
; si BUFFER_SIZE n'est pas multiple de 64, le cmps ne tombe jamais juste et le
; blast descend dans le reste de la page — machine morte, ecran fige (vecu le
; 23/08 en passant a 189 lignes). LINE_SIZE valant 80, il suffit que le nombre
; de lignes soit multiple de 4.
pscroll.BUFFER_LINES  equ   ((pscroll.BAND_LINES+pscroll.ROW_BIAS+3)/4)*4
 ENDC
pscroll.BUFFER_SIZE   equ   pscroll.BUFFER_LINES*pscroll.LINE_SIZE
pscroll.WRAP_OFF      equ   pscroll.BUFFER_SIZE   ; ou vit le jmp de rebouclage


; Le buffer PHYSIQUE fait BUFFER_SIZE + 3 : le jmp de rebouclage vit apres la
; derniere ligne.

; parametres, poses par le projet avant l'init
; -----------------------------------------------------------------------------
; Les quatre buffers : [plan][phase]. Plan 0 = zone $C000 en phase paire.
pscroll.buf.page      fill  0,4        ; pages des 4 buffers
pscroll.buf.address   fill  0,8        ; adresses des 4 buffers (fenetre cart.)
pscroll.data.page     fcb   0          ; page des routines de gravure + tables
pscroll.viewport.ram  fdb   0          ; fin de bande dans la zone $A000-$BFFF
pscroll.camera.x.max  fdb   0          ; largeur de carte - 160

; etat
; -----------------------------------------------------------------------------
pscroll.camera.x      fdb   0          ; position dans la carte, en px
pscroll.camera.speedx fdb   0          ; 8.8 signe, px/trame
pscroll.speedx        fdb   0          ; accumulateur de fraction
pscroll.window        fcb   0          ; base de la fenetre 16 px : x>>4
pscroll.edge16        fcb   0          ; bord de feed, en bandes de 16 px
pscroll.stretch       fcb   0          ; x / 160 : l'index de couture
pscroll.origin        fcb   0          ; ligne d'entree dans le buffer

; variables de travail — DANS LE MODULE, pas en page directe.
; dp_extreg ne reserve que 28 octets (engine/constants.asm) et le module en
; demande plus : la 24e variable ecrasait la zone temporaire du moteur, ce
; qui s'est vu a l'ecran. L'adressage etendu coute +1 cycle par acces, sur
; un poste qui pese 0,3 % de la trame.

pscroll.h             fcb   0
pscroll.w             fcb   0
pscroll.bo            fdb   0
pscroll.dest0         fdb   0
pscroll.dest1         fdb   0
pscroll.dest.current  fdb   0
pscroll.parity        fcb   0
pscroll.counter       fcb   0
pscroll.counter2      fcb   0
pscroll.slotbase      fdb   0
pscroll.seq           fdb   0
pscroll.savedS        fdb   0
pscroll.savedU        fdb   0
pscroll.band          fcb   0
pscroll.base          fdb   0
pscroll.line          fcb   0
pscroll.chunkoff      fdb   0
pscroll.startline     fcb   0
pscroll.tmpidx        fcb   0
pscroll.tmpcnt        fcb   0
pscroll.bufStart      fdb   0
pscroll.bufEnd        fdb   0
pscroll.hoff          fdb   0
pscroll.initcnt       fcb   0
; Ni SECTION ni EXPORT ici : c'est l'unite qui inclut ce fichier qui les
; fournit, comme pour mscroll (games/r-type/src/common/engine/mscroll.unit.asm).

; -----------------------------------------------------------------------------
; pscroll.buildSkeleton
; -----------------------------------------------------------------------------
; Ecrit les OPCODES des quatre buffers, PAR STACK BLAST. Un chunk fait 8 octets
; et le motif est toujours le meme : ldd #0 / ldx #0 / pshs d,x. L'ordre memoire
; montant d'un `pshs a,b,x,y,u` etant A B Xh Xl Yh Yl Uh Ul, cinq registres
; charges une fois suffisent a le poser — plus une seule ecriture d'octet.
;
; Ecrire les 60 160 octets un par un coutait ~420 000 cycles, soit 21 trames,
; A CHAQUE ouverture de stage ET A CHAQUE CHECKPOINT. Le blast les pose en
; ~107 000, soit 5 trames. Les immediats restent a zero : c'est la gravure des
; colonnes, juste apres, qui pose les valeurs par-dessus.
;
; Pieges de clearblast : aucun bsr/rts tant que S ecrit, S sauve et restaure.
; Les IRQ sont coupees a l'init, donc rien ne pousse sous S.
; -----------------------------------------------------------------------------
pscroll.buildSkeleton
        sts   pscroll.savedS          ; aucun bsr/rts tant que S ecrit
        clr   pscroll.counter
@buf    lda   pscroll.counter
        ldx   #pscroll.buf.page
        lda   a,x
        _SetCartPageA
        lda   pscroll.counter
        asla
        ldx   #pscroll.buf.address
        ldd   a,x
        std   pscroll.bufStart
        addd  #pscroll.BUFFER_SIZE
        std   pscroll.dest.current    ; le blast DESCEND : partir de la fin
        ldd   #(pscroll.OPCODE_LDD_I<<8)   ; a=$CC, b=immediat haut
        ldx   #pscroll.OPCODE_LDX_I        ; xh=immediat bas, xl=$8E
        ldy   #0                           ; les deux octets du second immediat
        ldu   #(pscroll.OPCODE_PSHS<<8)|pscroll.POSTB_DX
        lds   pscroll.dest.current
@chunk  pshs  a,b,x,y,u                ; 8 octets, l'ordre memoire montant est
        pshs  a,b,x,y,u                ; A B Xh Xl Yh Yl Uh Ul : exactement le
        pshs  a,b,x,y,u                ; motif d'un chunk. Deroule par 8 pour
        pshs  a,b,x,y,u                ; que le test de fin ne pese rien.
        pshs  a,b,x,y,u
        pshs  a,b,x,y,u
        pshs  a,b,x,y,u
        pshs  a,b,x,y,u
        cmps  pscroll.bufStart
        bne   @chunk
        lds   pscroll.savedS
        lda   pscroll.counter         ; le jmp de rebouclage, apres la
        asla                           ; derniere ligne
        ldx   #pscroll.buf.address
        ldd   a,x
        tfr   d,u
        leau  pscroll.BUFFER_SIZE,u
        lda   #pscroll.OPCODE_JMP_E
        sta   ,u+
        ldd   pscroll.bufStart
        std   ,u
        inc   pscroll.counter
        lda   pscroll.counter
        cmpa  #4
        blo   @buf
        rts

; -----------------------------------------------------------------------------
; pscroll.setCameraX
; -----------------------------------------------------------------------------
; input REG : [d] position camera, en px de carte
; Pose la position, l'index de couture et le bord de feed SANS rien graver.
; -----------------------------------------------------------------------------
pscroll.setCameraX
        std   pscroll.camera.x
        bsr   pscroll.seamFind         ; pose pscroll.stretch
        lda   #pscroll.SEAM_BIAS       ; meme convention que la ligne des
        suba  pscroll.stretch          ; bandes : BIAIS - coutures
        sta   pscroll.origin           ; l'origine porte l'index de couture
        ldd   pscroll.camera.x
        addd  #8
        _lsrd
        _lsrd
        _lsrd
        _lsrd
        stb   pscroll.window
        stb   pscroll.edge16
        rts

; b = camera.x / 160 (l'index de couture). d detruit.
; Les PALIERS de couture. On ne divise plus la camera par 160 a chaque trame :
; on avance dans cette table, exactement comme le HUD avance dans ses seuils de
; vie supplementaire. L'index EST pscroll.stretch, et le franchissement se
; teste en une comparaison. La table couvre 4 160 px de carte.
pscroll.seam.tbl
        fdb   160,320,480,640,800,960,1120,1280,1440,1600,1760,1920,2080,2240
        fdb   2400,2560,2720,2880,3040,3200,3360,3520,3680,3840,4000,4160
        fdb   $7FFF                    ; sentinelle : jamais franchie

; Le palier de la position courante, par PARCOURS de la table. Reserve a
; l'initialisation et au checkpoint : en jeu, le franchissement est
; incremental (voir pscroll.move).
pscroll.seamFind
        ldx   #pscroll.seam.tbl
@f      ldd   ,x++
        cmpd  pscroll.camera.x
        bls   @f
        tfr   x,d                      ; x pointe apres le palier non franchi
        subd  #pscroll.seam.tbl+2
        lsra
        rorb                           ; /2 : l'index du palier
        stb   pscroll.stretch
        rts

; -----------------------------------------------------------------------------
; pscroll.init
; -----------------------------------------------------------------------------
; input REG : [d] position camera de depart
; Squelette, puis gravure des dix emplacements du ruban depuis la carte.
; Cout : la gravure de dix colonnes (~160 000 cycles) — a l'ouverture du stage
; et au checkpoint, jamais en jeu.
; -----------------------------------------------------------------------------
pscroll.init
        pshs  d
        jsr   pscroll.buildSkeleton    ; jsr et non bsr : le squelette a
        puls  d                        ; grossi, la portee courte ne suffit plus
        jsr   pscroll.setCameraX
        ; graver les dix bandes visibles : window .. window+9
        lda   #pscroll.CHUNKS_PER_LINE
        sta   pscroll.initcnt
        ldb   pscroll.window
@each   pshs  b
        jsr   pscroll.feedBand
        puls  b
        incb
        dec   pscroll.initcnt
        bne   @each
        rts

; -----------------------------------------------------------------------------
; pscroll.move
; -----------------------------------------------------------------------------
; Avance la camera de sa vitesse compensee, absorbe les franchissements de
; couture, et grave les bandes qui entrent.
; -----------------------------------------------------------------------------
pscroll.move
        lda   gfxlock.frameDrop.count
        bne   >
        rts
!       sta   pscroll.counter
        ldd   pscroll.speedx
!       addd  pscroll.camera.speedx
        dec   pscroll.counter
        bne   <
        std   pscroll.speedx
        ldb   pscroll.speedx
        bpl   >
        incb
!       sex
        addd  pscroll.camera.x
        bpl   >
        ldd   #0
!       cmpd  pscroll.camera.x.max
        ble   >
        ldd   pscroll.camera.x.max
!       std   pscroll.camera.x
        ldb   pscroll.speedx
        bpl   >
        ldb   #$ff
        bra   @tail
!       clrb
@tail   stb   pscroll.speedx
        ; --- la couture map-fixe : l'origine porte l'index de couture -------
        ; --- LES PALIERS DE COUTURE : on avance dans la table, on ne divise
        ; plus. L'index EST pscroll.stretch, et l'origine derive a contre-sens
        ; (elle reste dans [1..BIAIS], donc aucun repli a faire).
        ldb   pscroll.stretch          ; le palier SUIVANT est-il franchi ?
        aslb
        ldx   #pscroll.seam.tbl
        ldd   b,x
        cmpd  pscroll.camera.x
        bhi   @noup
        inc   pscroll.stretch          ; vers la droite : l'entree descend
        dec   pscroll.origin
        bra   @noseam
@noup   ldb   pscroll.stretch          ; le palier COURANT est-il repasse ?
        beq   @noseam
        decb
        aslb
        ldx   #pscroll.seam.tbl
        ldd   b,x
        cmpd  pscroll.camera.x
        bls   @noseam
        dec   pscroll.stretch          ; vers la gauche
        inc   pscroll.origin
@noseam
        ; --- la fenetre de 16 px, et les bandes qui entrent -----------------
        ldd   pscroll.camera.x
        addd  #8
        _lsrd
        _lsrd
        _lsrd
        _lsrd
        stb   pscroll.window
@floop  ldb   pscroll.window
        cmpb  pscroll.edge16
        beq   @done
        bhi   @right
        dec   pscroll.edge16           ; vers la gauche : la bande de gauche
        ldb   pscroll.edge16
        bra   @feed
@right  inc   pscroll.edge16           ; vers la droite : celle qui suit la
        ldb   pscroll.edge16           ; fenetre, prete avant d'etre vue
        addb  #pscroll.CHUNKS_PER_LINE-1
@feed   jsr   pscroll.feedBand
        bra   @floop
@done   rts

; -----------------------------------------------------------------------------
; pscroll.feedBand
; -----------------------------------------------------------------------------
; input REG : [b] index de bande de carte (0..CHUNKS-1)
;
; Grave la bande dans son emplacement de ruban (b mod 10), pour les quatre
; buffers. Sans scroll vertical la destination est connue d'avance : rangee r
; -> lignes 6r, decalees du cisaillement, le tout modulo le bouclage.
; -----------------------------------------------------------------------------
pscroll.feedBand
        cmpb  #pscroll.CHUNKS
        blo   >
        rts                            ; hors carte : rien a graver
!       stb   pscroll.band
        ; l'emplacement dans le ruban (b mod 10) et le nombre de coutures a
        ; gauche de la bande (b / 10)
        clra
@mod    cmpb  #pscroll.CHUNKS_PER_LINE
        blo   @modok
        subb  #pscroll.CHUNKS_PER_LINE
        inca
        bra   @mod
@modok  pshs  a                        ; a = coutures a gauche de la bande
        ; l'emplacement est INVERSE : le chunk c du code peint la colonne 9-c
        ; (S descend, le premier chunk ecrit les 16 px de droite)
        negb
        addb  #pscroll.CHUNKS_PER_LINE-1
        lda   #pscroll.CHUNK_SIZE
        mul
        std   pscroll.chunkoff
        ; la ligne de la rangee 0 : origin + coutures, MODULO le buffer.
        ; LE SENS. L'index de ligne du buffer croit VERS LE HAUT de l'ecran :
        ; le blast descend (S decroissant), donc la premiere ligne executee
        ; peint le BAS de la bande. « Une ligne plus haut » vaut donc +1, pas
        ; -1. Avec le signe inverse la compensation DOUBLAIT le cisaillement au
        ; lieu de l'annuler — couture visible a chaque multiple de 160 px,
        ; reperee a l'ecran par l'auteur le 22/08.
        ; LA LIGNE DE LA RANGEE 0 = LE NOMBRE DE COUTURES A GAUCHE DE LA BANDE,
        ; ET RIEN D'AUTRE. La position d'une bande dans le buffer doit etre
        ; fonction d'ELLE SEULE : gravee une fois, elle reste valable quand la
        ; camera avance. C'est l'ENTREE du blast qui absorbe la camera
        ; (pscroll.origin = couture de la camera). Melanger les deux — ce que
        ; faisait la version d'avant, origin +/- coutures — laissait un
        ; cisaillement d'une ligne a chaque multiple de 160 px, la couture
        ; reperee a l'ecran par l'auteur le 22/08.
        ;
        ; Le sens : dans une ligne de buffer, les chunks de GAUCHE s'affichent
        ; une ligne plus BAS que ceux de droite (le ruban emprunte a la ligne
        ; suivante). Les bandes d'apres la couture sont justement celles de
        ; gauche : les graver une ligne plus HAUT — index +1, l'index croissant
        ; vers le haut puisque le blast descend — annule exactement le
        ; cisaillement.
        ;
        ; Aucun modulo ici : le biais borne tout dans [2..9], et
        ; 9 + 6*29 + 5 = 188 < BUFFER_LINES (189).
        lda   #pscroll.ROW_BIAS
        suba  ,s+
        sta   pscroll.startline
        ; les quatre buffers
        clr   pscroll.counter
@buf    lda   pscroll.counter
        ldx   #pscroll.buf.page
        lda   a,x
        _SetCartPageA
        lda   pscroll.counter
        asla
        ldx   #pscroll.buf.address
        ldd   a,x
        std   pscroll.base
        ; la sequence de 30 index : ((bande*2 + plan)*2 + phase) = bande*4 + i,
        ; ou i = plan*2 + phase, l'ordre meme des quatre buffers.
        ; addb/adca et non addd : counter est un OCTET, un addd y lirait le
        ; voisin (bug du 22/08).
        ldb   pscroll.band
        lda   #4
        mul
        addb  pscroll.counter
        adca  #0
        aslb                           ; x2 : la table est en fdb
        rola
        ldx   #pscroll.col.tbl
        ldx   d,x
        stx   pscroll.seq
        bsr   pscroll.engraveColumn
        inc   pscroll.counter
        lda   pscroll.counter
        cmpa  #4
        blo   @buf
        rts

; -----------------------------------------------------------------------------
; pscroll.engraveColumn
; -----------------------------------------------------------------------------
; input VAR : [pscroll.base] buffer, [pscroll.startline] ligne de la rangee 0,
;             [pscroll.chunkoff] offset du chunk, [pscroll.seq] les 30 index
;             (0 = colonne entierement vide)
; -----------------------------------------------------------------------------
pscroll.engraveColumn
        lda   pscroll.startline       ; u = l'operande de la ligne 1 de la
        ldb   #pscroll.LINE_SIZE       ; rangee (et non la ligne 0) : la
        mul                            ; routine adresse -80/0/+80 autour de
        addd  pscroll.chunkoff        ; lui, et pose x = u+240 pour les trois
        addd  pscroll.base            ; lignes suivantes. Aucun offset ne
        addd  #1+pscroll.LINE_SIZE     ; depasse alors 80 : pas de 16 bits.
        tfr   d,u
        lda   #pscroll.ROWS
        sta   pscroll.counter2
@row    ldx   pscroll.seq             ; l'index de combinaison de la rangee
        beq   @idx0                    ; (0 = colonne vide -> le fond)
        ldb   ,x+
        stx   pscroll.seq
        bra   >
@idx0   clrb
!       aslb
        clra
        ldx   #pscroll.row.tbl
        ldx   d,x
        jsr   ,x                       ; 6 lignes ; u ne bouge plus
        leau  6*pscroll.LINE_SIZE,u    ; la rangee suivante, d'un trait
        dec   pscroll.counter2
        bne   @row
        rts

; -----------------------------------------------------------------------------
; pscroll.do
; -----------------------------------------------------------------------------
; Peint la bande a la position courante. A appeler entre _gfxlock.on et
; _gfxlock.off : ecrit dans le tampon arriere.
;
; La position se decompose comme hscroll/mscroll, avec un terme de plus :
;   x = 16*h + 4*bo + 2*w + parity
;       parity : choisit la PAIRE de buffers (le 1 px)
;       h      : chunk d'entree dans chaque ligne (0-9)
;       bo     : offset d'octet sur S (-2..1)
;       w      : echange des zones $A000 / $C000
; -----------------------------------------------------------------------------
pscroll.do
        ; --- la parite : elle choisit la paire de buffers ------------------
        ldb   pscroll.camera.x+1
        andb  #1
        stb   pscroll.parity
        ; --- h : l'ordre des emplacements est inverse, d'ou le complement --
        ldb   pscroll.window
@mod    cmpb  #pscroll.CHUNKS_PER_LINE
        blo   @modok
        subb  #pscroll.CHUNKS_PER_LINE
        bra   @mod
@modok  beq   >
        subb  #pscroll.CHUNKS_PER_LINE
        negb                           ; h = (10 - window mod 10) mod 10
!       stb   pscroll.h
        ; --- la partie fine : bo et w --------------------------------------
        ldb   pscroll.camera.x+1
        addb  #8
        andb  #$0F
        subb  #8                       ; -8..7
        tfr   b,a
        asra                           ; /2 : -4..3
        tfr   a,b
        andb  #1
        stb   pscroll.w
        asra                           ; /2 : offset d'octet -2..1
        tfr   a,b
        sex
        _negd                          ; convention camera : +x montre ce qui
                                       ; est a droite, l'inverse de la rotation
        std   pscroll.bo
        ; --- les deux destinations, selon w --------------------------------
        tst   pscroll.w
        bne   @w1
        addd  pscroll.viewport.ram     ; phase 0 : plan 0 -> $C000, plan 1 -> $A000
        std   pscroll.dest1
        addd  #$2000
        std   pscroll.dest0
        bra   @run
@w1     addd  pscroll.viewport.ram     ; phase 1 : les zones s'echangent, et le
        subd  #1                       ; plan 0 recule d'un octet pour que les
        std   pscroll.dest0           ; deux plans atterrissent a +2 px
        addd  #$2000+1
        std   pscroll.dest1
@run
        ; --- buffer du plan 1, puis du plan 0 ------------------------------
        ldd   pscroll.dest1
        std   pscroll.dest.current
        ldb   pscroll.parity
        addb  #2                       ; index = plan*2 + phase, plan 1
        bsr   pscroll.runBuffer
        ldd   pscroll.dest0
        std   pscroll.dest.current
        ldb   pscroll.parity          ; plan 0
        ; chute dans runBuffer : dernier appel, il rend la main a l'appelant

; -----------------------------------------------------------------------------
; pscroll.runBuffer
; -----------------------------------------------------------------------------
; input REG : [b] index de buffer (plan*2 + phase)
; input VAR : [pscroll.dest.current] S de depart, [pscroll.origin], [pscroll.h]
; -----------------------------------------------------------------------------
pscroll.runBuffer
        stb   pscroll.counter
        ldx   #pscroll.buf.page
        lda   b,x
        _SetCartPageA
        ldb   pscroll.counter
        aslb
        ldx   #pscroll.buf.address
        ldx   b,x                      ; x = base du buffer
        tfr   x,d
        addd  #pscroll.BUFFER_SIZE
        std   pscroll.bufEnd
        lda   pscroll.origin
        adda  #pscroll.BAND_LINES
        bcs   @cycle
        cmpa  #pscroll.BUFFER_LINES
        blo   >
@cycle  suba  #pscroll.BUFFER_LINES
!       ldb   #pscroll.LINE_SIZE
        mul
        leau  d,x
        ldb   pscroll.h
        aslb
        aslb
        aslb
        leau  b,u                      ; u = ou poser le jmp de sortie
        pulu  a,y                      ; sauver les 3 octets ecrases
        stu   pscroll.savedU
        pshs  a,y
        lda   #pscroll.OPCODE_JMP_E
        ldy   #@ret
        sta   -3,u
        sty   -2,u
        lda   pscroll.origin
        ldb   #pscroll.LINE_SIZE
        mul
        leax  d,x
        ldb   pscroll.h
        aslb
        aslb
        aslb
        leax  b,x                      ; x = point d'entree
        sts   pscroll.savedS
        lds   pscroll.dest.current
        jmp   ,x
@ret    lds   pscroll.savedS
        ldu   pscroll.savedU
        puls  a,x
        pshu  a,x                      ; restaurer les 3 octets
        rts


; -----------------------------------------------------------------------------
; pscroll.setCell — LA REPOUSSE (l'« add gum »)
; -----------------------------------------------------------------------------
; input REG : [x] colonne de cellule, [b] rangee
; sortie    : cc.Z = 1 si la cellule etait DEJA pleine (rien n'a ete fait)
;
; Contrat arcade — run_cytron etape 5, plate Ghidra 0x4069b4 : « probe the
; foreground cell at the body's centre ; if it reads exactly TILE_EMPTY (0xFA0)
; overwrite it with the green-ball tile (0x9F6) ». UNE cellule par trame,
; uniquement si elle est vide.
;
; ON NE CALCULE RIEN, ON AIGUILLE. Les 3 px d'une gomme tombent toujours de la
; meme facon : deux forment un octet PLEIN dans un plan, le troisieme est un
; quartet isole dans l'autre — donc lu, masque, reecrit, pour ne pas ecraser le
; pixel du voisin. Le cas ne depend que de (3*colonne - phase) mod 16 : SEIZE
; routines generees, prouvees contre le modele pixel (192 ecritures, 0
; divergence), et une table les designe.
;
; Une passe par phase. Le chunk se prend en coordonnee de PHASE (n0 = px -
; phase) : c'est ce que la premiere version ratait, en prenant le chunk sur le
; pixel de carte brut — l'octet vise dans le chunk s'en trouvait decale, d'ou
; les 4 px de trop vus a l'ecran.
; -----------------------------------------------------------------------------
pscroll.setCell
        ldy   #pscroll.wr.tbl          ; la gomme POUSSE
        clr   pscroll.sc.mode
        bra   pscroll.mutate
; -----------------------------------------------------------------------------
; pscroll.clearCell — L'EFFACEMENT
; -----------------------------------------------------------------------------
; input REG : [x] colonne de cellule, [b] rangee
; sortie    : cc.Z = 1 si la cellule etait DEJA vide (rien n'a ete fait)
;
; Exactement le meme chemin que la repousse : meme aiguillage par
; (3*colonne - phase) mod 16, memes masques — seule la table de routines
; change, et la valeur posee est le fond. Le masque est ce qui permet
; d'effacer une gomme COLLEE a une autre sans entamer sa voisine.
; -----------------------------------------------------------------------------
pscroll.clearCell
        ldy   #pscroll.er.tbl          ; la gomme DISPARAIT
        lda   #1
        sta   pscroll.sc.mode
pscroll.mutate
        sty   pscroll.sc.tbl
        stx   pscroll.sc.col
        stb   pscroll.sc.row
        ldd   pscroll.sc.col           ; le px de carte : 3 * colonne
        aslb
        rola
        addd  pscroll.sc.col
        std   pscroll.sc.px
        lsra                           ; sa bande
        rorb
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        stb   pscroll.sc.chunk         ; la bande, gardee pour la geometrie
        subb  pscroll.edge16           ; DANS LE RUBAN ? sinon on ne touche a
        lbcs  @already                 ; RIEN, bit compris (voir plus bas)
        cmpb  #pscroll.CHUNKS_PER_LINE
        lbhs  @already
        lda   pscroll.sc.row           ; l'octet du champ, et le masque du bit
        ldb   #pscroll.MAP_STRIDE
        mul
        addd  pscroll.map.address
        std   pscroll.sc.rowptr
        ldd   pscroll.sc.col
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        addd  pscroll.sc.rowptr
        tfr   d,x
        ldb   pscroll.sc.col+1
        andb  #7
        ldy   #pscroll.tbl.bit
        ldb   b,y
        tst   pscroll.sc.mode
        bne   @efface
        bitb  ,x
        lbne  @already                 ; deja pleine : rien a faire
        orb   ,x                       ; la gomme pousse
        stb   ,x
        bra   @suite
@efface bitb  ,x
        lbeq  @already                 ; deja vide : rien a faire
        comb
        andb  ,x                       ; la gomme disparait
        stb   ,x
@suite
        ; -------------------------------------------------------------------
        ; LA GEOMETRIE NE SE CALCULE QU'UNE FOIS. Les deux phases ne different
        ; que par n0 = px et px-1 : le CAS change toujours (c'est case-1 mod
        ; 16, une soustraction), mais la bande, la couture, l'emplacement et
        ; la ligne ne changent QUE si px tombe pile sur un multiple de 16 —
        ; une fois sur seize. On calcule donc pour la phase 0, on appelle, et
        ; on ne refait la geometrie pour la phase 1 que dans ce cas la.
        ; Mesure du 23/08 : l'aiguillage passe de 828 a 645 cycles.
        ; -------------------------------------------------------------------
        ldb   pscroll.sc.row           ; le terme de rangee de l'offset : il ne
        clra                           ; depend ni de la bande ni de la phase
        aslb
        rola
        ldx   #pscroll.rowbase.tbl
        ldd   d,x
        std   pscroll.sc.rowbase
        ldb   pscroll.sc.chunk
        lbsr  pscroll.geom             ; -> sc.dst
        ldb   pscroll.sc.px+1          ; PHASE 0 : le cas est px mod 16
        andb  #15
        clr   pscroll.sc.phase
        lbsr  pscroll.mutate.plans
        ldd   pscroll.sc.px            ; PHASE 1 : n0 = px - 1
        subd  #1
        bmi   @fin                     ; avant le bord gauche : rien de plus
        andb  #15                      ; px etait-il pile sur la bande ?
        cmpb  #15
        bne   @meme                    ; non : meme bande, meme offset
        ldb   pscroll.sc.chunk         ; oui : la phase 1 est dans la bande
        decb                           ; PRECEDENTE
        stb   pscroll.sc.chunk
        subb  pscroll.edge16           ; qui n'est peut-etre plus dans le ruban
        bcs   @fin
        ldb   pscroll.sc.chunk
        lbsr  pscroll.geom
@meme   ldb   pscroll.sc.px+1
        decb
        andb  #15
        inc   pscroll.sc.phase
        lbsr  pscroll.mutate.plans
@fin    andcc #$FB                     ; Z = 0 : le champ a change
        rts
@already
        orcc  #$04                     ; Z = 1 : rien a faire
        rts

; -----------------------------------------------------------------------------
; pscroll.mutate.plans — poser les deux plans d'une phase et graver
; -----------------------------------------------------------------------------
; input REG : [b] le cas, 0..15
; input VAR : [pscroll.sc.phase] la phase, [pscroll.sc.dst] l'offset commun
; -----------------------------------------------------------------------------
pscroll.mutate.plans
        aslb                           ; la routine du cas
        ldx   pscroll.sc.tbl           ; ecriture ou effacement
        ldx   b,x
        stx   pscroll.sc.rout
        ldb   pscroll.sc.phase         ; les deux plans : index = plan*2 + phase
        ldx   #pscroll.buf.page
        lda   b,x
        sta   pscroll.wr.page0
        addb  #2
        lda   b,x
        sta   pscroll.wr.page1
        ldb   pscroll.sc.phase
        aslb
        ldx   #pscroll.buf.address
        ldd   b,x
        addd  pscroll.sc.dst
        std   pscroll.wr.base0
        ldb   pscroll.sc.phase
        addb  #2
        aslb
        ldx   #pscroll.buf.address
        ldd   b,x
        addd  pscroll.sc.dst
        std   pscroll.wr.base1
        ldx   pscroll.sc.rout
        jmp   ,x                       ; la routine du cas ecrit les 3 px

; -----------------------------------------------------------------------------
; pscroll.geom — l'offset d'une mutation, pour une bande
; -----------------------------------------------------------------------------
; input REG : [b] la bande de carte
; input VAR : [pscroll.sc.rowbase] le terme de rangee
; sortie VAR: [pscroll.sc.dst]
;
; L'OFFSET EN DEUX ADDITIONS. Il valait ligne*80 + emplacement + 1, avec
; ligne = BIAIS - couture + 6*(29-rangee) + 5 : deux mul et une division par
; 10 faite en retranchant 10 jusqu'a passer dessous (12 cycles par dizaine,
; donc 84 pour la bande 71 — de plus en plus cher a mesure qu'on avance dans
; le niveau). Or ca se separe : le terme de RANGEE ne depend pas de la bande,
; le terme de BANDE ne depend pas de la rangee, et le biais est une constante
; d'instruction. Les deux tables sont engendrees avec le reste, et celle des
; bandes porte deja l'emplacement MOINS le cisaillement — une seule lecture.
; -----------------------------------------------------------------------------
pscroll.geom
        clra                           ; la bande, en mots (offset 16 bits :
        aslb                           ; la table depasse 127 octets)
        rola
        ldx   #pscroll.bandoff.tbl
        ldd   d,x                      ; emplacement - coutures*80
        addd  pscroll.sc.rowbase       ; le terme de rangee
        addd  #pscroll.ROW_BIAS*pscroll.LINE_SIZE+1
        std   pscroll.sc.dst
        rts


pscroll.tbl.bit  fcb   $80,$40,$20,$10,$08,$04,$02,$01
; LE BITFIELD DES GOMMES. CONTRAT : il doit etre ADRESSABLE quand setCell ou
; clearCell est appele — donc en RAM fixe, pas dans une page a monter. Il ne
; fait que MAP_STRIDE * ROWS octets (1 440 pour le stage 4) et la partie de
; jeu le lit et l'ecrit sans arret ; le monter a chaque mutation coutait un
; _SetCartPageA pour rien. Un projet qui le voudrait pagine monte sa page
; avant d'appeler.
pscroll.map.address   fdb   0          ; le bitfield des gommes, pose par le projet
pscroll.wr.page0      fcb   0          ; l'interface des routines d'ecriture
pscroll.wr.page1      fcb   0
pscroll.wr.base0      fdb   0
pscroll.wr.base1      fdb   0
pscroll.sc.col        fdb   0
pscroll.sc.row        fcb   0
pscroll.sc.rowptr     fdb   0
pscroll.sc.px         fdb   0
pscroll.sc.n0         fdb   0
pscroll.sc.phase      fcb   0
pscroll.sc.chunk      fcb   0
pscroll.sc.rowbase    fdb   0
pscroll.sc.dst        fdb   0
pscroll.sc.rout       fdb   0
pscroll.sc.tbl        fdb   0          ; la table du chemin en cours
pscroll.sc.mode       fcb   0          ; 0 = pousse, 1 = efface
