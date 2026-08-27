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
; DEJA EN UNITES V2, ET ARRONDIE AU PLUS PROCHE (27/08/2026). growTrail
; convertissait a l'execution par decalages arithmetiques (x*3>>3, y*3>>2).
; Un decalage arithmetique arrondit vers -INFINI, pas vers zero : le cercle
; converti n'etait plus symetrique. Rayon 5 a gauche mais 4 a droite, 8 en bas
; mais 7 en haut — CINQ paires de poses opposees sur huit ne l'etaient plus.
; Le point de semis sautait donc d'une cellule entiere selon la direction du
; cytron, ce qui decale les segments les uns par rapport aux autres : sur un
; trace fait de lignes d'UNE cellule d'epaisseur, le motif se deforme en
; gardant sa silhouette (ecart avec l'arcade releve par l'auteur).
;
; La table est figee (16 entrees, jamais recalculees) : on la pose convertie.
; Les huit paires opposees le sont maintenant exactement, et growTrail n'a
; plus une seule division a faire.
cytron.trail.tbl
	fdb   -5,0     ; pose  0  (arcade -12,  0)
	fdb   -4,3     ; pose  1  (arcade -10,  4)
	fdb   -3,6     ; pose  2  (arcade  -8,  8)
	fdb   -2,8     ; pose  3  (arcade  -4, 10)
	fdb   0,9      ; pose  4  (arcade   0, 12)
	fdb   2,8      ; pose  5  (arcade   4, 10)
	fdb   3,6      ; pose  6  (arcade   8,  8)
	fdb   4,3      ; pose  7  (arcade  10,  4)
	fdb   5,0      ; pose  8  (arcade  12,  0)
	fdb   4,-3     ; pose  9  (arcade  10, -4)
	fdb   3,-6     ; pose 10  (arcade   8, -8)
	fdb   2,-8     ; pose 11  (arcade   4,-10)
	fdb   0,-9     ; pose 12  (arcade   0,-12)
	fdb   -2,-8    ; pose 13  (arcade  -4,-10)
	fdb   -3,-6    ; pose 14  (arcade  -8, -8)
	fdb   -4,-3    ; pose 15  (arcade -10, -4)

