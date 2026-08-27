;******************************************************************************
; cytron — la table des variantes de mouvement
;
; Table arcade : segment de donnees 0x1000, offset 0x92AC, 16 entrees de
; 4 octets (script, puis octet de variante = nombre d'octets de deplacement
; consommes par trame). Le quartet HAUT du descripteur de spawn choisit
; l'entree.
;
; CE QUE PORTE LE PREMIER MOT : UN INDICE, PAS UNE ADRESSE.
; -------------------------------------------------------
; `moveByScript.initialize` attend dans X un DECALAGE dans la LUT de l'objet
; d'animation commun (`Ani_Asd_common`) — il fait `ldx anim.addr,x` ou
; anim.addr a ete posee par `moveByScript.register` depuis l'index d'objets,
; et il monte la page de cet objet avant de lire. Un script ne peut donc PAS
; vivre dans la page de l'ennemi : ni le pointeur, ni les segments que
; l'interprete relit ensuite (`runByFrameDrop` remonte la meme page a chaque
; tour). C'est la convention de tout le cast — pata-pata `ldx #anim_19ACE`,
; outslay `fdb anim_1A4E6`.
;
; Ce fichier portait au depart l'export brut de re.arcade.r-type
; (--extract-movescript) : la table SUIVIE d'une copie des scripts et de leurs
; segments, 1 453 etiquettes. Deux consequences, corrigees le 24/08/2026 :
;   - les seize entrees donnaient l'ADRESSE locale du script, que initialize
;     ajoutait a la base de la LUT — le pointeur obtenu tombait des kilo-octets
;     au-dela d'une table de 54 octets, et le cytron interpretait comme un
;     script ce qui trainait la (des deplacements minuscules, sur place) ;
;   - la copie etait un doublon exact de `src/common/fx/animation/script.asm`
;     (1 453 etiquettes communes, zero divergence, zero etiquette propre), soit
;     autant de page d'ennemi brulee pour rien.
; Les treize scripts distincts sont donc references dans la LUT commune
; (index.asm + index.equ, entrees 54 a 78) et la copie est supprimee.
;******************************************************************************

cytron.script.tbl
	fdb   anim_19D32   ; variante 0, 3 octets par trame
	fcb   3
	fcb   0
	fdb   anim_19D68   ; variante 1, 3 octets par trame
	fcb   3
	fcb   0
	fdb   anim_19DA4   ; variante 2, 3 octets par trame
	fcb   3
	fcb   0
	fdb   anim_19E0A   ; variante 3, 3 octets par trame
	fcb   3
	fcb   0
	fdb   anim_19E4E   ; variante 4, 3 octets par trame
	fcb   3
	fcb   0
	fdb   anim_19EF8   ; variante 5, 3 octets par trame
	fcb   3
	fcb   0
	fdb   anim_19F2E   ; variante 6, 3 octets par trame
	fcb   3
	fcb   0
	fdb   anim_19F7C   ; variante 7, 3 octets par trame
	fcb   3
	fcb   0
	fdb   anim_19FBC   ; variante 8, 3 octets par trame
	fcb   3
	fcb   0
	fdb   anim_19FDE   ; variante 9, 3 octets par trame
	fcb   3
	fcb   0
	fdb   anim_1A000   ; variante 10, 3 octets par trame
	fcb   3
	fcb   0
	fdb   anim_1A046   ; variante 11, 3 octets par trame
	fcb   3
	fcb   0
	fdb   anim_1A086   ; variante 12, 3 octets par trame
	fcb   3
	fcb   0
	fdb   anim_1A086   ; variante 13, 3 octets par trame
	fcb   3
	fcb   0
	fdb   anim_1A086   ; variante 14, 3 octets par trame
	fcb   3
	fcb   0
	fdb   anim_1A086   ; variante 15, 3 octets par trame
	fcb   3
	fcb   0

; --- le decalage de repousse, par pose : un cercle de rayon 12 px arcade sur
; 16 directions. Cytron plante sa gomme DERRIERE lui, dans l'axe de sa pose —
; c'est ce decalage qui fait la TRAINEE, et donc la forme du trace.
;
; EN 8.8 EXACT, PHASE DE GRILLE COMPRISE (27/08/2026). L'arcade seme dans la
; cellule floor((position + decalage + phase)/8), ou la phase est l'alignement
; du spawn sur la grille de tuiles — etalonnee a +3 px arcade sur capture
; (ci/toje-bench/cytron_sim.py, 5/5 lignes de motif identiques ; les autres
; phases en font 4/5 ou moins). La version precedente de cette table etait
; arrondie au px v2 ENTIER : jusqu'a 1,3 px arcade d'erreur selon la pose, et
; pas de phase du tout — le motif gardait sa silhouette mais pas ses cellules.
;
; Ici chaque pose porte DEUX offsets 8.8 de 3 octets (sign-extended, poids
; fort en tete), 8 octets par pose :
;   Tx = dx_arcade * $60 + $120    ($60 = 0,375 px v2 par px arcade, EXACT ;
;                                   $2D0 - $300 = phase arcade + constante
;                                   camera du stage (etalonnage inverse toje)
;                                   MOINS UNE CELLULE : l'alignement absolu sur
;                                   la grille des gommes initiales, cale par
;                                   l'auteur (27/08) — le tout CUIT ici
;                                   pour ne rien couter a l'execution)
;   Ty = -dy_arcade * $C0 + $180   (l'axe y v2 est INVERSE, la negation est
;                                   cuite aussi — plus de _negd dans growTrail ;
;                                   $180 = l'ancrage y, fenetre [320..511])
; growTrail ajoute ces offsets a la position 8.8 COMPLETE (x_pos:x_sub) et ne
; tronque qu'apres : floor(v/768) = floor(floor(v/256)/3), la composition des
; floors est exacte, le chemin div3/div6 de pscroll.grow reste inchange.
;
; TABLE GENEREE — ne pas editer a la main :
;   python3 ci/toje-bench/cytron_sim.py --emit-table
; et le banc differentiel qui la prouve (0 divergence, 3230 pas, 18 subtypes) :
;   python3 ci/toje-bench/cytron_sim.py --check-v2
cytron.trail.tbl
 fcb $FF,$FB,$50,0,$00,$01,$80,0   ; pose  0 (arcade -12,  0) : x -1200  y  +384
 fcb $FF,$FC,$10,0,$FF,$FE,$80,0   ; pose  1 (arcade -10,  4) : x -1008  y  -384
 fcb $FF,$FC,$D0,0,$FF,$FB,$80,0   ; pose  2 (arcade  -8,  8) : x  -816  y -1152
 fcb $FF,$FE,$50,0,$FF,$FA,$00,0   ; pose  3 (arcade  -4, 10) : x  -432  y -1536
 fcb $FF,$FF,$D0,0,$FF,$F8,$80,0   ; pose  4 (arcade   0, 12) : x   -48  y -1920
 fcb $00,$01,$50,0,$FF,$FA,$00,0   ; pose  5 (arcade   4, 10) : x  +336  y -1536
 fcb $00,$02,$D0,0,$FF,$FB,$80,0   ; pose  6 (arcade   8,  8) : x  +720  y -1152
 fcb $00,$03,$90,0,$FF,$FE,$80,0   ; pose  7 (arcade  10,  4) : x  +912  y  -384
 fcb $00,$04,$50,0,$00,$01,$80,0   ; pose  8 (arcade  12,  0) : x +1104  y  +384
 fcb $00,$03,$90,0,$00,$04,$80,0   ; pose  9 (arcade  10, -4) : x  +912  y +1152
 fcb $00,$02,$D0,0,$00,$07,$80,0   ; pose 10 (arcade   8, -8) : x  +720  y +1920
 fcb $00,$01,$50,0,$00,$09,$00,0   ; pose 11 (arcade   4,-10) : x  +336  y +2304
 fcb $FF,$FF,$D0,0,$00,$0A,$80,0   ; pose 12 (arcade   0,-12) : x   -48  y +2688
 fcb $FF,$FE,$50,0,$00,$09,$00,0   ; pose 13 (arcade  -4,-10) : x  -432  y +2304
 fcb $FF,$FC,$D0,0,$00,$07,$80,0   ; pose 14 (arcade  -8, -8) : x  -816  y +1920
 fcb $FF,$FC,$10,0,$00,$04,$80,0   ; pose 15 (arcade -10, -4) : x -1008  y +1152

