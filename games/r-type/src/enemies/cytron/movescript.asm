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

; --- le decalage de repousse, par pose : un cercle de rayon 12 px arcade sur 16 directions. Cytron plante sa gomme DERRIERE lui -------------------------------------------
cytron.trail.tbl
	fdb   -12,0   ; pose 0
	fdb   -10,4   ; pose 1
	fdb   -8,8   ; pose 2
	fdb   -4,10   ; pose 3
	fdb   0,12   ; pose 4
	fdb   4,10   ; pose 5
	fdb   8,8   ; pose 6
	fdb   10,4   ; pose 7
	fdb   12,0   ; pose 8
	fdb   10,-4   ; pose 9
	fdb   8,-8   ; pose 10
	fdb   4,-10   ; pose 11
	fdb   0,-12   ; pose 12
	fdb   -4,-10   ; pose 13
	fdb   -8,-8   ; pose 14
	fdb   -10,-4   ; pose 15

