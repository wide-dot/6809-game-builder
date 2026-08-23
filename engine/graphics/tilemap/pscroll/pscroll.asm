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
 IFNDEF pscroll.MAX_SEAMS
pscroll.MAX_SEAMS     equ   8          ; le projet devrait la definir
 ENDC
; LE BUDGET DE CISAILLEMENT — ET CE N'EST PAS DU GACHIS. Une bande est gravee a
; ROW_BIAS - (sa bande)/10 : ce compteur monte d'UNE LIGNE tous les 160 px
; DEPUIS LE DEBUT DU NIVEAU, donc le buffer porte autant de lignes de budget
; qu'il y a de coutures. Ca lie sa hauteur a la LONGUEUR DE LA CARTE.
;
; Le compteur POURRAIT etre pris modulo la hauteur — le buffer est cyclique et
; mscroll fait exactement ca — et le buffer tomberait a BAND_LINES+1. Mais
; alors une rangee par colonne tombe a cheval sur le rebouclage, et les
; routines cablees ecrivent leurs six lignes en aveugle depuis deux bases
; fixes : elles ne savent pas reboucler. Les deux sorties coutent plus cher que
; le budget :
;   - appeler la routine DEUX fois, a base et base-BUFFER_SIZE, en laissant les
;     moities hors buffer tomber dans un scratch : il en faut 5 lignes de
;     chaque cote, soit DIX — plus que les huit du budget ;
;   - un chemin lent ligne a ligne : 792 o de table, +3 % sur la mutation et
;     +23 % sur le pic du feed.
; Le budget grandit avec le niveau, le scratch non : le croisement est a
; ~1 600 px de carte. Le stage 4 en fait 1 152 — ARBITRAGE RENDU (auteur,
; 23/08) : on garde le budget, il est a la fois le plus rapide et le plus
; compact ici. Le SS13 de l'etude porte les trois chiffrages.
pscroll.SEAM_BIAS     equ   pscroll.MAX_SEAMS
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
; EXACTEMENT ce qu'il faut : la rangee 0 occupe les lignes startline..+5 avec
; startline = ROW_BIAS - coutures, et la rangee 29 finit a ROW_BIAS + 179.
; Aucun arrondi — buildSkeleton ecrit le reste hors de sa boucle deroulee.
pscroll.BUFFER_LINES  equ   pscroll.BAND_LINES+pscroll.ROW_BIAS
 ENDC
pscroll.BUFFER_SIZE   equ   pscroll.BUFFER_LINES*pscroll.LINE_SIZE
; DEUX GARDE-FOUS, parce que les deux se franchissent EN SILENCE : un buffer
; trop grand deborde sur la page voisine, un budget trop court rend startline
; negatif et le champ se grave hors du buffer.
 IFGT pscroll.BUFFER_SIZE+3-16384
        ERROR "pscroll : le buffer ne tient pas dans une page de 16 Ko — reduire pscroll.MAX_SEAMS ou la hauteur de bande"
 ENDC
 IFDEF pscroll.MAP_WIDTH
 IFLT pscroll.MAX_SEAMS-((pscroll.MAP_WIDTH/16-1)/pscroll.CHUNKS_PER_LINE)
        ERROR "pscroll : pscroll.MAX_SEAMS est trop court pour pscroll.MAP_WIDTH"
 ENDC
 ENDC
pscroll.WRAP_OFF      equ   pscroll.BUFFER_SIZE   ; ou vit le jmp de rebouclage
; Les chunks que la boucle deroulee de buildSkeleton ne peut pas couvrir : elle
; en pose huit a la fois, le buffer n'en fait pas forcement un multiple de huit.
pscroll.BLAST_REM     equ   pscroll.BUFFER_SIZE/pscroll.CHUNK_SIZE-(pscroll.BUFFER_SIZE/(8*pscroll.CHUNK_SIZE))*8


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
pscroll.blastrem      fcb   0          ; chunks restants du blast, hors boucle
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
        lda   #pscroll.BLAST_REM       ; les chunks en trop de CE buffer
        sta   pscroll.blastrem
        ldd   #(pscroll.OPCODE_LDD_I<<8)   ; a=$CC, b=immediat haut
        ldx   #pscroll.OPCODE_LDX_I        ; xh=immediat bas, xl=$8E
        ldy   #0                           ; les deux octets du second immediat
        ldu   #(pscroll.OPCODE_PSHS<<8)|pscroll.POSTB_DX
        lds   pscroll.dest.current
        ; LE RESTE D'ABORD. La boucle ci-dessous ecrit par blocs de 64 octets et
        ; s'arrete sur une EGALITE exacte avec le debut : si le buffer n'est pas
        ; un multiple de 64, le cmps ne tombe jamais juste et le blast descend
        ; dans le reste de la page. On ecrit donc d'abord les chunks en trop,
        ; un par un — le compteur vit en MEMOIRE parce que les cinq registres
        ; portent le motif et qu'aucun n'est libre.
        tst   pscroll.blastrem         ; tst et non lda : A porte le motif
        beq   @chunk
@reste  pshs  a,b,x,y,u
        dec   pscroll.blastrem
        bne   @reste
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
; Pose pscroll.phase.tbl : pour la phase p, le plan 0 est le buffer p et le
; plan 1 le buffer 2+p (index = plan*2 + phase). Deroule : ca tourne une fois.
pscroll.buildPhaseTable
        lda   pscroll.buf.page+0       ; phase 0
        sta   pscroll.phase.tbl+0
        lda   pscroll.buf.page+2
        sta   pscroll.phase.tbl+1
        ldd   pscroll.buf.address+0
        std   pscroll.phase.tbl+2
        ldd   pscroll.buf.address+4
        std   pscroll.phase.tbl+4
        lda   pscroll.buf.page+1       ; phase 1
        sta   pscroll.phase.tbl+pscroll.PHASE_SZ+0
        lda   pscroll.buf.page+3
        sta   pscroll.phase.tbl+pscroll.PHASE_SZ+1
        ldd   pscroll.buf.address+2
        std   pscroll.phase.tbl+pscroll.PHASE_SZ+2
        ldd   pscroll.buf.address+6
        std   pscroll.phase.tbl+pscroll.PHASE_SZ+4
        rts

pscroll.init
        pshs  d
        jsr   pscroll.buildPhaseTable
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
        ; APRES avoir mis B a l'abri : mutate recoit la rangee DANS B et la
        ; cellule dans X. Poser sc.plans plus haut, dans setCell/clearCell,
        ; ecrasait B (ldd) et faisait tomber toutes les mutations sur la meme
        ; rangee — la mire se croyait deja pleine et rien ne s'effacait (23/08).
        ldd   #pscroll.mutate.plans    ; une cellule : le chemin ordinaire
        std   pscroll.sc.plans
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
        ldb   pscroll.sc.row           ; le terme de rangee de l'offset : il ne
        clra                           ; depend ni de la bande ni de la phase
        aslb
        rola
        ldx   #pscroll.rowbase.tbl
        ldd   d,x
        std   pscroll.sc.rowbase
        lda   #$FF                     ; appel isole : la geometrie est a faire
        sta   pscroll.sc.lastchunk
        lbsr  pscroll.mutate.tail
        andcc #$FB                     ; Z = 0 : le champ a change
        rts
@already
        orcc  #$04                     ; Z = 1 : rien a faire
        rts

; -----------------------------------------------------------------------------
; pscroll.mutate.tail — la geometrie et les deux phases
; -----------------------------------------------------------------------------
; input VAR : sc.row, sc.chunk, sc.px, sc.rowbase, sc.tbl, sc.lastchunk
;
; SORTIE DE MUTATE pour etre appelable EN LOT : dans un run de cellules
; voisines, la rangee et sa base de ligne ne changent pas, et la bande ne change
; qu'une cellule sur cinq — `geom` n'est donc refait que lorsque `sc.chunk`
; differe de `sc.lastchunk`. Un appelant isole pose $FF pour la forcer.
; -----------------------------------------------------------------------------
pscroll.mutate.tail
        ; -------------------------------------------------------------------
        ; LA GEOMETRIE NE SE CALCULE QU'UNE FOIS. Les deux phases ne different
        ; que par n0 = px et px-1 : le CAS change toujours (c'est case-1 mod
        ; 16, une soustraction), mais la bande, la couture, l'emplacement et
        ; la ligne ne changent QUE si px tombe pile sur un multiple de 16 —
        ; une fois sur seize. On calcule donc pour la phase 0, on appelle, et
        ; on ne refait la geometrie pour la phase 1 que dans ce cas la.
        ; Mesure du 23/08 : l'aiguillage passe de 828 a 645 cycles.
        ; -------------------------------------------------------------------
        lda   pscroll.sc.chunk         ; la bande a-t-elle change ?
        cmpa  pscroll.sc.lastchunk
        beq   @geomok
        sta   pscroll.sc.lastchunk
        ldb   pscroll.sc.chunk
        lbsr  pscroll.geom             ; -> sc.dst
@geomok ldb   pscroll.sc.px+1          ; PHASE 0 : le cas est px mod 16
        andb  #15
        ldx   #pscroll.phase.tbl
        jsr   [pscroll.sc.plans]
        ldd   pscroll.sc.px            ; PHASE 1 : n0 = px - 1
        subd  #1
        bmi   @fin                     ; avant le bord gauche : rien de plus
        andb  #15                      ; px etait-il pile sur la bande ?
        cmpb  #15
        bne   @meme                    ; non : meme bande, meme offset
        ldb   pscroll.sc.chunk         ; oui : la phase 1 est dans la bande
        decb                           ; PRECEDENTE
        stb   pscroll.sc.chunk
        lda   #$FF                     ; sc.dst ne decrira plus sc.chunk : le
        sta   pscroll.sc.lastchunk     ; lot devra refaire sa geometrie
        subb  pscroll.edge16           ; qui n'est peut-etre plus dans le ruban
        bcs   @fin
        ldb   pscroll.sc.chunk
        lbsr  pscroll.geom
@meme   ldb   pscroll.sc.px+1
        decb
        andb  #15
        ldx   #pscroll.phase.tbl+pscroll.PHASE_SZ
        jsr   [pscroll.sc.plans]
@fin    rts

; -----------------------------------------------------------------------------
; pscroll.mutate.plans — poser les deux plans d'une phase et graver
; -----------------------------------------------------------------------------
; input REG : [b] le cas 0..15, [x] l'entree de phase (pscroll.phase.tbl)
; input VAR : [pscroll.sc.dst] l'offset commun aux deux plans
;
; TOUT SORT D'UNE TABLE POSEE A L'INIT. Cette routine relisait sc.phase trois
; fois et refaisait l'indexation de buf.page/buf.address a chaque fois : 88
; cycles par phase, soit 176 des 599 de l'aiguillage — pour aller chercher
; quatre valeurs qui ne bougent plus depuis l'init. L'entree de phase les
; donne dans l'ordre ou l'interface des routines les attend, et les deux pages
; se posent d'un seul ldd/std parce qu'elles sont contigues des deux cotes.
; -----------------------------------------------------------------------------
pscroll.mutate.plans
        ldy   pscroll.sc.tbl           ; la table du chemin (ecriture/effacement)
        aslb
        ldy   b,y                      ; la routine du cas ; elle y reste
        ldd   ,x                       ; LES DEUX PAGES D'UN COUP : elles sont
        std   pscroll.wr.page0         ; contigues des deux cotes
        ldd   2,x
        addd  pscroll.sc.dst
        std   pscroll.wr.base0
        ldd   4,x
        addd  pscroll.sc.dst
        std   pscroll.wr.base1
        jmp   ,y                       ; la routine du cas ecrit les 3 px

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
        ; -LINE_SIZE : les routines de cellule attaquent le buffer avec DEUX
        ; bases a 240 octets d'ecart pour n'avoir que des offsets 8 bits (donc
        ; aucun leau entre les lignes). Leur base u est la ligne 1, pas la
        ; ligne 0 — et ce decalage ne coute rien, il vit dans cette constante.
        addd  #pscroll.ROW_BIAS*pscroll.LINE_SIZE+1-pscroll.LINE_SIZE
        std   pscroll.sc.dst
        rts


; -----------------------------------------------------------------------------
; pscroll.clearRect — L'EFFACEMENT EN MASSE
; -----------------------------------------------------------------------------
; input VAR : pscroll.rect.c0/r0  le coin haut-gauche du bloc au DEPART
;             pscroll.rect.c1/r1  le meme coin a l'ARRIVEE
;             pscroll.rect.w/h    la taille du bloc, en cellules
;
; Efface la surface BALAYEE par le bloc entre les deux points. C'est le module
; qui fait la geometrie (arbitrage auteur, 23/08) : les armes passent un depart
; et une arrivee, elles ne portent pas de grille.
;
; Etiquettes explicites et non locales : une macro entre la reference a un
; @label et sa definition casse sa portee chez lwasm, et ce fichier en appelle
; (docs/lang/en/migration/local-labels-and-macros.md).
;
; POURQUOI UN BALAYAGE ET PAS N BLOCS. A 16 img/s une trame rendue couvre trois
; a quatre trames arcade. Rejouer le bloc arcade N fois couterait N fois son
; prix ; l'union de ces N blocs le long du deplacement est, rangee par rangee,
; un INTERVALLE — et un intervalle, ca s'efface d'un trait. L'effacement doit
; donc sortir de la boucle de frame-drop de l'arme : le tick se rejoue N fois
; pour le mouvement et la collision, et l'effacement est appele UNE fois, ici.
;
; La cartographie arcade (SS15 de l'etude) donne les formes a couvrir : bloc 4x4
; du Force Pod a chaque trame, bande 2 x (CX+1) du Wave Cannon, onze blocs 4x4
; du Counter-Air Laser. Les missiles et le tir simple du pod, eux, n'effacent
; qu'une cellule dans toute leur vie : ils restent sur pscroll.clearCell.
; -----------------------------------------------------------------------------
pscroll.clearRect
        ; --- les deux cas alignes, qui sont ceux du jeu ---------------------
        ; Le pod et le beam se deplacent a l'horizontale ; le vertical arrive
        ; avec les rebonds. Les traiter a part evite le parcours du segment.
        lda   pscroll.rect.r0
        cmpa  pscroll.rect.r1
        bne   pscroll.rect.notflat
        ; --- HORIZONTAL : toutes les rangees du bloc ont le meme intervalle
        ldd   pscroll.rect.c0
        cmpd  pscroll.rect.c1
        bls   >
        ldd   pscroll.rect.c1          ; le depart est a droite : on echange
!       std   pscroll.rect.a
        ldd   pscroll.rect.c0
        cmpd  pscroll.rect.c1
        bhs   >
        ldd   pscroll.rect.c1
!       addb  pscroll.rect.w
        adca  #0
        subd  #1
        std   pscroll.rect.b
        lda   pscroll.rect.r0
        sta   pscroll.rect.row
        lda   pscroll.rect.h
        sta   pscroll.rect.left
        jsr   pscroll.rect.prep        ; UNE fois : l'intervalle ne change pas
        bcs   pscroll.rect.hend        ; d'une rangee a l'autre
pscroll.rect.hloop
        jsr   pscroll.clearRow.go
        inc   pscroll.rect.row
        dec   pscroll.rect.left
        bne   pscroll.rect.hloop
pscroll.rect.hend
        rts

pscroll.rect.notflat
        ldd   pscroll.rect.c0
        cmpd  pscroll.rect.c1
        bne   pscroll.rect.oblique
        ; --- VERTICAL : une seule colonne d'intervalle, sur toutes les rangees
        ldd   pscroll.rect.c0
        std   pscroll.rect.a
        addb  pscroll.rect.w
        adca  #0
        subd  #1
        std   pscroll.rect.b
        lda   pscroll.rect.r0          ; la rangee la plus haute
        cmpa  pscroll.rect.r1
        bls   >
        lda   pscroll.rect.r1
!       sta   pscroll.rect.row
        lda   pscroll.rect.r0          ; le nombre de rangees balayees
        suba  pscroll.rect.r1
        bpl   >
        nega
!       adda  pscroll.rect.h
        sta   pscroll.rect.left
        jsr   pscroll.rect.prep        ; UNE fois, comme l'horizontal
        bcs   pscroll.rect.vend
pscroll.rect.vloop
        jsr   pscroll.clearRow.go
        inc   pscroll.rect.row
        dec   pscroll.rect.left
        bne   pscroll.rect.vloop
pscroll.rect.vend
        rts

pscroll.rect.oblique
        ; PAS D'OBLIQUE. Aucune arme du stage 4 n'en a besoin : le Force Pod et
        ; le Wave Cannon balaient a l'horizontale, les rebonds a la verticale,
        ; et les missiles n'effacent qu'une cellule (cf. SS15). L'escalier exact
        ; se rajoutera le jour ou une arme le demandera — un intervalle par
        ; rangee, pas une boite englobante.
        rts

; -----------------------------------------------------------------------------
; pscroll.clearRow — effacer l'intervalle [x..y] de la rangee A
; -----------------------------------------------------------------------------
; input REG : [a] la rangee, [x] la premiere cellule, [y] la derniere
; sortie    : cc.Z = 1 si rien n'a change
;
; Trois temps : borner sur la carte ET sur le ruban, effacer les bits, puis
; regraver. Le contournement est ici : si aucun bit ne change, on ne regrave
; rien — et ce test est par OCTET de carte, pas par cellule.
; -----------------------------------------------------------------------------
; L'intervalle est le MEME pour toutes les rangees d'un balayage aligne — et
; les deux cas du jeu le sont. Borner et chercher les bandes pleines une fois
; par rangee coutait ~90 cycles a chaque tour pour un resultat identique : la
; preparation est donc hoistee hors de la boucle (remarque auteur, 23/08 : le
; test des bandes couvertes ne doit pas couter plus que ce qu'il economise).
pscroll.clearRow
        sta   pscroll.rect.row
        stx   pscroll.rect.a
        sty   pscroll.rect.b
        jsr   pscroll.rect.prep
        lbcs  pscroll.clearRow.rien    ; l'intervalle est vide
        lbra  pscroll.clearRow.go

; -----------------------------------------------------------------------------
; pscroll.rect.prep — borner l'intervalle et reperer les bandes PLEINES
; -----------------------------------------------------------------------------
; input VAR : pscroll.rect.a / .b     sortie : cc.C = 1 si plus rien a faire
; Pose .a .b .n .m0 .m1 (m1 < m0 : aucune bande pleine, tout ira par cellule).
; -----------------------------------------------------------------------------
pscroll.rect.prep
        ; --- borner sur la carte
        ldd   pscroll.rect.a
        bpl   >
        clra                           ; a gauche de la carte
        clrb
        std   pscroll.rect.a
!       ldd   pscroll.rect.b
        cmpd  #pscroll.CELLS-1
        bls   >
        ldd   #pscroll.CELLS-1
        std   pscroll.rect.b
!       ldd   pscroll.rect.a
        cmpd  pscroll.rect.b
        bls   >
pscroll.rect.prepFail
        orcc  #$01                     ; C = 1 : plus rien a faire
        rts
!       ; --- borner sur le RUBAN. Une cellule hors fenetre n'est pas dans le
        ; buffer : l'y effacer poserait un bit que rien n'affiche, exactement
        ; le defaut corrige sur setCell le 23/08.
        ldd   pscroll.rect.a           ; la bande de la premiere cellule
        aslb
        rola
        addd  pscroll.rect.a
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        subb  pscroll.edge16
        bcc   >
        ldb   pscroll.edge16           ; a gauche du ruban : on remonte a son
        aslb                           ; premier bord
        clra
        ldx   #pscroll.chunkfirst.tbl
        ldd   d,x
        std   pscroll.rect.a
!       ldd   pscroll.rect.b           ; la bande de la derniere cellule
        aslb
        rola
        addd  pscroll.rect.b
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        subb  pscroll.edge16
        cmpb  #pscroll.CHUNKS_PER_LINE
        blo   >
        ldb   pscroll.edge16           ; a droite : on descend au dernier bord
        addb  #pscroll.CHUNKS_PER_LINE
        aslb
        clra
        ldx   #pscroll.chunkfirst.tbl
        ldd   d,x
        subd  #1
        std   pscroll.rect.b
!       ldd   pscroll.rect.a
        cmpd  pscroll.rect.b
        lbhi  pscroll.rect.prepFail
        ldd   pscroll.rect.b
        subd  pscroll.rect.a
        addd  #1
        std   pscroll.rect.n
        lda   #1                       ; m1 < m0 par defaut : aucune bande pleine
        sta   pscroll.rect.m0
        clr   pscroll.rect.m1
        cmpd  #pscroll.CLEAR_UNROLL
        lblo  pscroll.rect.prepEnd

; --- LES BANDES PLEINES ------------------------------------------------------
; Les bandes ENTIEREMENT couvertes par l'intervalle se vident d'un trait : le
; fond vaut 0, donc leur contenu de buffer n'est plus que des zeros. Les deux
; extremites, elles, restent par cellule — une bande couvre six cellules, un
; run n'en remplit une que s'il la couvre toute.
        ldd   pscroll.rect.a           ; m0 : premiere bande PLEINE
        lbsr  pscroll.chunkOf
        stb   pscroll.rect.m0
        aslb
        clra
        ldx   #pscroll.chunkfirst.tbl
        ldd   d,x
        cmpd  pscroll.rect.a
        bhs   >
        inc   pscroll.rect.m0          ; sa premiere cellule est avant a
!       ldd   pscroll.rect.b           ; m1 : derniere bande PLEINE
        lbsr  pscroll.chunkOf
        stb   pscroll.rect.m1
        incb
        aslb
        clra
        ldx   #pscroll.chunkfirst.tbl
        ldd   d,x
        subd  #1
        cmpd  pscroll.rect.b
        bls   >
        dec   pscroll.rect.m1          ; sa derniere cellule depasse b
!       andcc #$FE                     ; C = 0 : il reste du travail
pscroll.rect.prepEnd
        rts

; -----------------------------------------------------------------------------
; pscroll.clearRow.go — le travail d'UNE rangee, preparation deja faite
; -----------------------------------------------------------------------------
pscroll.clearRow.go
        clr   pscroll.rect.done
        ldb   pscroll.rect.row         ; le terme de rangee, pour la sequence
        clra
        aslb
        rola
        ldx   #pscroll.rowbase.tbl
        ldd   d,x
        std   pscroll.rect.rowbase
        lda   pscroll.rect.m1
        cmpa  pscroll.rect.m0
        lblo  pscroll.clearRow.cells   ; aucune bande pleine : tout par cellule

        ; les deux extremites, par cellule
        ldd   pscroll.rect.a
        std   pscroll.rect.cur
        lda   pscroll.rect.m0
        asla
        ldx   #pscroll.chunkfirst.tbl
        ldd   a,x                      ; premiere cellule de la premiere pleine
        std   pscroll.rect.mid0
        subd  pscroll.rect.a
        std   pscroll.rect.nleft
        lbsr  pscroll.clearRow.runCells
        lda   pscroll.rect.m1
        inca
        asla
        ldx   #pscroll.chunkfirst.tbl
        ldd   a,x                      ; premiere cellule apres la derniere
        std   pscroll.rect.cur         ; pleine : la queue commence la
        std   pscroll.rect.mid1
        ldd   pscroll.rect.b
        addd  #1
        subd  pscroll.rect.mid1
        std   pscroll.rect.nleft
        lbsr  pscroll.clearRow.runCells

        ; --- le milieu, bande par bande, COUPE AUX COUTURES -----------------
        ; Le cisaillement decale d'une ligne les bandes d'apres une couture :
        ; deux bandes d'un meme run n'y sont plus sur les memes lignes de
        ; buffer, et la sequence deroulee suppose le contraire. Le ruban n'en
        ; portant que dix, un run traverse au plus une couture.
        lda   pscroll.rect.m0
        sta   pscroll.rect.g0
pscroll.clearRow.group
        lda   pscroll.rect.g0          ; la couture de ce groupe
        ldx   #pscroll.seamof.tbl
        lda   a,x
        sta   pscroll.rect.seam
        ldx   #pscroll.seamlast.tbl
        lda   a,x
        sta   pscroll.rect.seamlast    ; sa derniere bande
        cmpa  pscroll.rect.m1
        bls   >
        lda   pscroll.rect.m1          ; le run s'arrete avant
!       sta   pscroll.rect.g1
        lbsr  pscroll.clearRow.zone
        lda   pscroll.rect.g1
        inca
        sta   pscroll.rect.g0
        cmpa  pscroll.rect.m1
        bls   pscroll.clearRow.group
        tst   pscroll.rect.done
        beq   pscroll.clearRow.rien
        andcc #$FB
        rts

pscroll.clearRow.cells
        ldd   pscroll.rect.n           ; UN RUN QUI A SA ROUTINE ? (4 ou 5)
        cmpd  #4
        blo   pscroll.clearRow.cellsGo
        cmpd  #pscroll.RUN_MAX
        bhi   pscroll.clearRow.cellsGo
        stb   pscroll.run.n
        ldx   pscroll.rect.a
        ldb   pscroll.rect.row
        lbsr  pscroll.clearRun
        bcs   pscroll.clearRow.cellsGo ; refuse : le chemin par cellule
        bne   >
        lbra  pscroll.clearRow.rien
!       inc   pscroll.rect.done
        andcc #$FB
        rts
pscroll.clearRow.cellsGo
        ldd   pscroll.rect.a
        std   pscroll.rect.cur
        ldd   pscroll.rect.n
        std   pscroll.rect.nleft
        lbsr  pscroll.clearRow.runCells
        tst   pscroll.rect.done
        beq   pscroll.clearRow.rien
        andcc #$FB                     ; Z = 0 : le champ a change
        rts
pscroll.clearRow.rien
        orcc  #$04
        rts

; -----------------------------------------------------------------------------
; pscroll.run.plans — poser les deux plans d'une phase, pour un RUN
; -----------------------------------------------------------------------------
; input REG : [b] le cas 0..15, [x] l'entree de phase
;
; Meme role que mutate.plans, mais les routines de run ont DEUX entrees par cas
; — une par plan — et ne contiennent que leur boucle de six lignes. Le montage
; de page, la base et le compteur sont identiques pour les seize cas : les
; repeter dans le code genere pesait plus que les ecritures elles-memes (472
; instructions contre 264 une fois sortis).
;
; La base part de la ligne du BAS (+80) et remonte de 80 par tour, ce qui garde
; tous les offsets dans -8..+4 — de l'indexe 5 bits, un octet et un cycle de
; moins que les 8 bits du deroule.
; -----------------------------------------------------------------------------
pscroll.run.plans
        ldy   pscroll.sc.tbl
        aslb
        aslb                           ; quatre octets par cas : deux entrees
        leay  b,y
        sty   pscroll.run.entry
        ldd   ,x                       ; les deux pages, d'un coup
        std   pscroll.wr.page0
        ldd   2,x
        addd  pscroll.sc.dst
        std   pscroll.wr.base0
        ldd   4,x
        addd  pscroll.sc.dst
        std   pscroll.wr.base1
        clr   pscroll.run.plane        ; les deux plans, meme montage
pscroll.run.pLoop
        lda   pscroll.run.plane        ; sa page (page0 et page1 sont voisines)
        ldx   #pscroll.wr.page0
        lda   a,x
        _SetCartPageA
        lda   pscroll.run.plane
        asla
        ldx   #pscroll.wr.base0        ; sa base : la ligne du BAS de la rangee
        ldu   a,x
        leau  pscroll.LINE_SIZE,u
        ldy   pscroll.run.entry        ; son entree, calculee AVANT de vider D :
        leay  a,y                      ; la routine veut D = 0
        lda   #pscroll.CELL_H
        sta   pscroll.run.lines
        clra                           ; D = 0 : le fond. A sert aussi aux
        clrb                           ; paires d'octets pleins (std)
        jsr   [,y]
        inc   pscroll.run.plane
        lda   pscroll.run.plane
        cmpa  #2
        blo   pscroll.run.pLoop
        rts

pscroll.run.entry fdb 0
pscroll.run.plane fcb 0

; -----------------------------------------------------------------------------
; pscroll.clearRun — effacer un RUN de cellules voisines d'un seul trait
; -----------------------------------------------------------------------------
; input REG : [x] la premiere cellule, [b] la rangee
; input VAR : [pscroll.run.n] sa longueur, 4 ou 5 — les deux que le jeu produit
;             (le bloc des armes a l'arret, et son union quand il balaye)
; input VAR : [pscroll.rect.rowbase] la base de ligne de la rangee
; sortie    : cc.C = 1 si la routine REFUSE (a l'appelant de faire autrement),
;             sinon cc.Z = 1 si le champ n'a pas change
;
; POURQUOI UNE ROUTINE PAR LONGUEUR. Une gomme fait 3 px larges et un octet en
; fait 2 : deux voisines partagent toujours un octet. Effacees une par une, cet
; octet se fait masquer DEUX fois — chacune preservant la moitie de l'autre —
; alors que dans un run il part en entier. Sur quatre cellules, 24 ecritures
; masquees et 24 pleines deviennent 4 masquees et 32 pleines, et il ne reste
; qu'un aiguillage au lieu de quatre.
;
; Le reste est celui d'une mutation ordinaire : meme cas (px mod 16), meme
; geometrie, meme mutate.tail — SEULE LA TABLE DE ROUTINES CHANGE. Les douze
; pixels tiennent dans deux bandes au plus (16 px la bande), et le decalage
; VOISIN de -8 les y suit, a deux conditions que la routine verifie :
;   - les deux bandes sont dans le ruban ;
;   - elles sont du meme cote d'une couture, sans quoi elles ne sont pas sur
;     les memes lignes de buffer et le -8 ne veut plus rien dire.
; Sinon elle refuse (C=1) et l'appelant reprend cellule par cellule.
;
; Les quatre cellules sont ecrites MEME SI certaines etaient deja vides : le
; fond vaut zero, y reecrire zero ne coute rien de plus et evite quatre tests.
; -----------------------------------------------------------------------------
pscroll.clearRun
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
        stb   pscroll.sc.chunk
        subb  pscroll.edge16           ; dans le ruban ?
        lbcs  pscroll.clearRun.no
        cmpb  #pscroll.CHUNKS_PER_LINE
        lbhs  pscroll.clearRun.no
        lda   #3                       ; la bande du DERNIER px du run :
        ldb   pscroll.run.n            ; 3 px par cellule, moins un
        mul
        subd  #1
        addd  pscroll.sc.px
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        stb   pscroll.run.last
        subb  pscroll.edge16
        lbcs  pscroll.clearRun.no
        cmpb  #pscroll.CHUNKS_PER_LINE
        lbhs  pscroll.clearRun.no
        ldx   #pscroll.seamof.tbl      ; meme cote de couture ?
        ldb   pscroll.sc.chunk
        lda   b,x
        ldb   pscroll.run.last
        cmpa  b,x
        lbne  pscroll.clearRun.no

        ; --- la carte : les quatre bits, et le champ a-t-il seulement change ?
        lda   pscroll.sc.row
        ldb   #pscroll.MAP_STRIDE
        mul
        addd  pscroll.map.address
        std   pscroll.sc.rowptr
        clr   pscroll.run.chg
        ldx   pscroll.sc.col
        lda   pscroll.run.n
        sta   pscroll.run.left
pscroll.clearRun.bit
        tfr   x,d
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        addd  pscroll.sc.rowptr
        tfr   d,y
        tfr   x,d
        andb  #7
        ldu   #pscroll.tbl.bit
        ldb   b,u
        bitb  ,y
        beq   >
        inc   pscroll.run.chg
        comb
        andb  ,y
        stb   ,y
!       leax  1,x
        dec   pscroll.run.left
        bne   pscroll.clearRun.bit
        tst   pscroll.run.chg
        beq   pscroll.clearRun.rien   ; les quatre etaient vides

        ldd   pscroll.rect.rowbase     ; la rangee, deja calculee par l'appelant
        std   pscroll.sc.rowbase
        ldb   pscroll.run.n            ; LA SEULE DIFFERENCE avec une mutation
        subb  #4                       ; est la table de routines
        aslb
        clra
        ldx   #pscroll.run.tbl
        ldd   d,x
        std   pscroll.sc.tbl
        ldd   #pscroll.run.plans
        std   pscroll.sc.plans
        lda   #$FF
        sta   pscroll.sc.lastchunk
        lbsr  pscroll.mutate.tail
        andcc #$FA                     ; C = 0 : la routine a fait le travail,
                                       ; Z = 0 : le champ a change
        rts
pscroll.clearRun.rien
        andcc #$FE
        orcc  #$04                     ; Z = 1 : rien n'a change
        rts
pscroll.clearRun.no
        orcc  #$01                     ; C = 1 : la routine refuse
        rts

pscroll.run.lines fcb 0                ; le compteur de lignes du run : en
                                       ; memoire, A servant au masquage
pscroll.run.n     fcb 0                ; la longueur du run en cours
pscroll.run.last  fcb 0
pscroll.run.chg   fcb 0
pscroll.run.left  fcb 0

; -----------------------------------------------------------------------------
; pscroll.chunkOf — la bande d'une cellule
; input REG : [d] la cellule    sortie : [b] la bande, a detruit
; -----------------------------------------------------------------------------
pscroll.chunkOf
        pshs  d
        aslb
        rola
        addd  ,s++                     ; 3 * cellule
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb                           ; / 16
        rts

; -----------------------------------------------------------------------------
; pscroll.clearRow.runCells — effacer nleft cellules a partir de cur
; -----------------------------------------------------------------------------
; -----------------------------------------------------------------------------
; pscroll.clearRow.runCells — un LOT de cellules voisines, sur une rangee
; -----------------------------------------------------------------------------
; C'est le chemin des extremites d'un run, et le seul chemin quand l'intervalle
; est trop court pour porter une bande pleine. Il fait le meme travail que N
; appels a clearCell, mais SORT DU LOT ce qui ne depend que de la rangee ou qui
; n'avance que d'un pas :
;   - le pointeur de carte de la rangee (une multiplication)
;   - la base de ligne (une table)
;   - le px de carte, qui avance de 3 par cellule au lieu d'etre remultiplie
;   - la geometrie de bande, refaite seulement quand la bande change, soit une
;     cellule sur cinq (sc.lastchunk)
; Mesure du 23/08 : voir l'etude. Le reste — les deux phases, les quatre
; buffers, les masques — est irreductible et reste tel quel.
; -----------------------------------------------------------------------------
pscroll.clearRow.runCells
        ldd   pscroll.rect.nleft
        lbeq  pscroll.clearRow.rcEnd
        lda   pscroll.rect.row         ; le pointeur de carte de la rangee
        sta   pscroll.sc.row
        ldb   #pscroll.MAP_STRIDE
        mul
        addd  pscroll.map.address
        std   pscroll.sc.rowptr
        ldb   pscroll.rect.row         ; sa base de ligne
        clra
        aslb
        rola
        ldx   #pscroll.rowbase.tbl
        ldd   d,x
        std   pscroll.sc.rowbase
        ldd   #pscroll.er.tbl          ; le lot n'efface que
        std   pscroll.sc.tbl
        ldd   #pscroll.mutate.plans
        std   pscroll.sc.plans
        lda   #1
        sta   pscroll.sc.mode
        lda   #$FF                     ; aucune geometrie encore calculee
        sta   pscroll.sc.lastchunk
        ldd   pscroll.rect.cur         ; le px de carte : 3 * colonne, UNE fois
        aslb
        rola
        addd  pscroll.rect.cur
        std   pscroll.sc.px
pscroll.clearRow.rcLoop
        ldd   pscroll.rect.cur
        std   pscroll.sc.col
        ldd   pscroll.sc.px            ; la bande
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        stb   pscroll.sc.chunk
        subb  pscroll.edge16           ; DANS LE RUBAN ?
        bcs   pscroll.clearRow.rcNext
        cmpb  #pscroll.CHUNKS_PER_LINE
        bhs   pscroll.clearRow.rcNext
        ldd   pscroll.sc.col           ; l'octet de carte et le masque du bit
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
        bitb  ,x
        beq   pscroll.clearRow.rcNext  ; deja vide : rien a faire
        comb
        andb  ,x                       ; la gomme disparait
        stb   ,x
        lbsr  pscroll.mutate.tail
        inc   pscroll.rect.done
pscroll.clearRow.rcNext
        ldd   pscroll.rect.cur
        addd  #1
        std   pscroll.rect.cur
        ldd   pscroll.sc.px            ; le px suit, il ne se recalcule pas
        addd  #3
        std   pscroll.sc.px
        ldd   pscroll.rect.nleft
        subd  #1
        std   pscroll.rect.nleft
        lbne  pscroll.clearRow.rcLoop
pscroll.clearRow.rcEnd
        rts

; -----------------------------------------------------------------------------
; pscroll.clearRow.zone — vider les bandes PLEINES g0..g1 d'un meme groupe
; -----------------------------------------------------------------------------
; Toutes les bandes du groupe partagent le cisaillement, donc les memes lignes
; de buffer : c'est ce qui autorise une seule entree dans la sequence deroulee.
;
; Deux temps : les bits de carte par MASQUE D'OCTET — et c'est la qu'est le
; contournement, si rien ne change on ne regrave rien — puis la sequence.
; -----------------------------------------------------------------------------
pscroll.clearRow.zone
        lda   pscroll.rect.g0          ; les cellules du groupe
        asla
        ldx   #pscroll.chunkfirst.tbl
        ldd   a,x
        std   pscroll.rect.ca
        lda   pscroll.rect.g1
        inca
        asla
        ldx   #pscroll.chunkfirst.tbl
        ldd   a,x
        subd  #1
        std   pscroll.rect.cb

        ; --- la carte, par masque d'octet
        lda   pscroll.rect.row
        ldb   #pscroll.MAP_STRIDE
        mul
        addd  pscroll.map.address
        std   pscroll.rect.mapptr
        ldd   pscroll.rect.ca          ; l'octet et le bit du premier
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        addd  pscroll.rect.mapptr
        std   pscroll.rect.bptr
        ldb   pscroll.rect.ca+1
        andb  #7
        ldx   #pscroll.mfrom
        lda   b,x
        sta   pscroll.rect.mA
        ldd   pscroll.rect.cb          ; l'octet et le bit du dernier
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        addd  pscroll.rect.mapptr
        subd  pscroll.rect.bptr
        stb   pscroll.rect.nbytes      ; octets - 1
        ldb   pscroll.rect.cb+1
        andb  #7
        ldx   #pscroll.mto
        lda   b,x
        sta   pscroll.rect.mB
        clr   pscroll.rect.chg
        ldx   pscroll.rect.bptr
        lda   pscroll.rect.mA
        tst   pscroll.rect.nbytes
        bne   pscroll.clearRow.zMulti
        anda  pscroll.rect.mB          ; un seul octet : les deux masques
pscroll.clearRow.zMulti
        ldb   pscroll.rect.nbytes
        incb
        stb   pscroll.rect.bleft
pscroll.clearRow.zByte
        ldb   ,x
        pshs  a
        anda  ,x                       ; ce qui change vraiment
        beq   pscroll.clearRow.zNoChg
        inc   pscroll.rect.chg
pscroll.clearRow.zNoChg
        puls  a                        ; le masque des cellules visees
        coma                           ; son complement : ce qui SURVIT
        pshs  a
        andb  ,s+                      ; l'octet, prive des cellules visees.
        stb   ,x+                      ; PAS `andb ,x` : la 6809 ne sait pas
                                       ; croiser A et B, le complement doit
                                       ; passer par la memoire. La version
                                       ; d'origine faisait `andb ,x+` — soit
                                       ; l'octet ET lui-meme — et reecrivait
                                       ; donc la carte INCHANGEE (23/08).
        dec   pscroll.rect.bleft
        beq   pscroll.clearRow.zDone
        lda   pscroll.rect.bleft       ; dernier octet ? sinon $FF
        cmpa  #1
        bne   pscroll.clearRow.zFull
        lda   pscroll.rect.mB
        bra   pscroll.clearRow.zByte
pscroll.clearRow.zFull
        lda   #$FF
        bra   pscroll.clearRow.zByte
pscroll.clearRow.zDone
        tst   pscroll.rect.chg
        lbeq  pscroll.clearRow.zRien   ; rien n'a change : rien a regraver
        inc   pscroll.rect.done

        ; --- la sequence deroulee : entree par la premiere bande, sortie patchee
        lda   pscroll.rect.seamlast
        suba  pscroll.rect.g0
        asla
        ldx   #pscroll.zrow.entry
        ldx   a,x
        stx   pscroll.rect.entry
        lda   pscroll.rect.seamlast
        suba  pscroll.rect.g1
        beq   pscroll.clearRow.zNoPatch ; la derniere bande est l'emplacement 0 :
        deca                            ; la sequence finit d'elle-meme
        asla
        ldx   #pscroll.zrow.entry
        ldx   a,x
        stx   pscroll.rect.patch
        lda   ,x
        sta   pscroll.rect.saved
        lda   #pscroll.OPCODE_RTS
        sta   ,x
        bra   pscroll.clearRow.zBufs
pscroll.clearRow.zNoPatch
        clr   pscroll.rect.patch
        clr   pscroll.rect.patch+1
pscroll.clearRow.zBufs
        lda   #pscroll.ROW_BIAS        ; la ligne du haut de la rangee
        suba  pscroll.rect.seam
        ldb   #pscroll.LINE_SIZE
        mul
        addd  pscroll.rect.rowbase
        std   pscroll.rect.lineoff
        clr   pscroll.rect.buf
pscroll.clearRow.zBuf
        lda   pscroll.rect.buf
        ldx   #pscroll.buf.page
        lda   a,x
        _SetCartPageA
        lda   pscroll.rect.buf
        asla
        ldx   #pscroll.buf.address
        ldd   a,x
        addd  pscroll.rect.lineoff
        tfr   d,u                      ; U : ligne du bas de la rangee
        subd  #2*pscroll.LINE_SIZE
        tfr   d,y                      ; Y : deux lignes plus haut
        subd  #2*pscroll.LINE_SIZE
        tfr   d,x                      ; X : deux de plus
        ldd   #0                       ; la donnee : le fond vaut zero
        jsr   [pscroll.rect.entry]
        inc   pscroll.rect.buf
        lda   pscroll.rect.buf
        cmpa  #4
        blo   pscroll.clearRow.zBuf
        ldx   pscroll.rect.patch       ; rendre l'octet patche
        beq   pscroll.clearRow.zRien
        lda   pscroll.rect.saved
        sta   ,x
pscroll.clearRow.zRien
        rts

pscroll.mfrom    fcb $FF,$7F,$3F,$1F,$0F,$07,$03,$01
pscroll.mto      fcb $80,$C0,$E0,$F0,$F8,$FC,$FE,$FF
pscroll.OPCODE_RTS equ $39
pscroll.rect.m0      fcb 0
pscroll.rect.m1      fcb 0
pscroll.rect.g0      fcb 0
pscroll.rect.g1      fcb 0
pscroll.rect.seam    fcb 0
pscroll.rect.seamlast fcb 0
pscroll.rect.mid0    fdb 0
pscroll.rect.mid1    fdb 0
pscroll.rect.ca      fdb 0
pscroll.rect.cb      fdb 0
pscroll.rect.mapptr  fdb 0
pscroll.rect.bptr    fdb 0
pscroll.rect.mA      fcb 0
pscroll.rect.mB      fcb 0
pscroll.rect.nbytes  fcb 0
pscroll.rect.bleft   fcb 0
pscroll.rect.chg     fcb 0
pscroll.rect.entry   fdb 0
pscroll.rect.patch   fdb 0
pscroll.rect.saved   fcb 0
pscroll.rect.lineoff fdb 0
pscroll.rect.rowbase fdb 0
pscroll.rect.buf     fcb 0

pscroll.RUN_MAX      equ 5             ; la plus longue routine de run generee
pscroll.CLEAR_UNROLL equ 8             ; le seuil des deux regimes : huit
                                       ; cellules garantissent une bande pleine
                                       ; quelle que soit leur position (six n'y
                                       ; suffisent que si elles tombent bien)
pscroll.rect.c0      fdb 0
pscroll.rect.r0      fcb 0
pscroll.rect.c1      fdb 0
pscroll.rect.r1      fcb 0
pscroll.rect.w       fcb 0
pscroll.rect.h       fcb 0
pscroll.rect.a       fdb 0
pscroll.rect.b       fdb 0
pscroll.rect.n       fdb 0
pscroll.rect.nleft   fdb 0
pscroll.rect.cur     fdb 0
pscroll.rect.row     fcb 0
pscroll.rect.left    fcb 0
pscroll.rect.done    fcb 0
; (rect.dc/dr/mins/maxs sont partis avec le parcours en escalier : 67 octets
; qu'aucune ligne ne lisait plus.)

pscroll.tbl.bit  fcb   $80,$40,$20,$10,$08,$04,$02,$01
; LE BITFIELD DES GOMMES. CONTRAT : il doit etre ADRESSABLE quand setCell ou
; clearCell est appele — donc en RAM fixe, pas dans une page a monter. Il ne
; fait que MAP_STRIDE * ROWS octets (1 440 pour le stage 4) et la partie de
; jeu le lit et l'ecrit sans arret ; le monter a chaque mutation coutait un
; _SetCartPageA pour rien. Un projet qui le voudrait pagine monte sa page
; avant d'appeler.
pscroll.map.address   fdb   0          ; le bitfield des gommes, pose par le projet
; L'ENTREE DE PHASE : les deux pages puis les deux adresses de buffer, dans
; l'ordre ou l'interface ci-dessous les attend. Posee une fois par pscroll.init.
pscroll.PHASE_SZ      equ   6
pscroll.phase.tbl     fill  0,2*pscroll.PHASE_SZ

pscroll.wr.page0      fcb   0          ; l'interface des routines d'ecriture
pscroll.wr.page1      fcb   0
pscroll.wr.base0      fdb   0
pscroll.wr.base1      fdb   0
pscroll.sc.col        fdb   0
pscroll.sc.row        fcb   0
pscroll.sc.rowptr     fdb   0
pscroll.sc.px         fdb   0
pscroll.sc.n0         fdb   0
pscroll.sc.chunk      fcb   0
pscroll.sc.rowbase    fdb   0
pscroll.sc.dst        fdb   0
pscroll.sc.tbl        fdb   0          ; la table du chemin en cours
pscroll.sc.mode       fcb   0          ; 0 = pousse, 1 = efface
pscroll.sc.plans      fdb   0          ; poser les plans : cellule ou run
pscroll.sc.lastchunk  fcb   $FF        ; la bande dont sc.dst est la geometrie
