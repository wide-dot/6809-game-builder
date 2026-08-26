;*******************************************************************************
; wick — SQUELETTE, avec sa FICHE DE PORTAGE complete (relevee le 26/08/2026)
;
; Le bestiaire le donne pour « voyage en groupe », « non agressif »,
; « une distraction au mauvais moment ». Les trois se lisent dans le code.
;
; LA LIGNE DE WAVE NE SPAWNE PAS UN WICK : elle spawne un EMETTEUR INVISIBLE
; qui en pond une nuee. Un seul spawn au stage 2 ($06,$54 = t 1620, camera 304).
;
; FICHE DE PORTAGE (base Ghidra `maincpu`, subsystem wick)
; -------------------------------------------------------------------------
;   40:875d create_wick_emitter ........ le spawner de l emetteur
;   40:8798 run_wick_emitter ........... son tick — INVISIBLE, sans collision
;   40:87ba wick_emitter_script_step ... la timeline de densite
;   40:8817 wick_emitter_spawn ......... pond UN wick
;   40:8861 run_wick ................... le wick visible, etat DERIVE
;   40:893e run_wick_aim_attack ........ etat PIQUE, terminal
;   1000:3afe timeline   3b12 difficultes   3b22 dispatch de pique
;   1000:3b2a vitesses de derive   3b32/3bb2 poses   3c12 l AABB
;
; L EMETTEUR. Ne se dessine pas, ne collisionne pas, ne suit PAS le decor —
; son tick ne lit pas 0x2ED0 (verifie sur les octets, pas sur les xrefs). Il
; reste donc a une abscisse ECRAN fixe pendant toute sa vie, et c est ce qui
; fait que ses wicks entrent toujours par le meme bord. Chez nous, ou les
; coordonnees sont monde, cela veut dire calculer le point de ponte a chaque
; emission — camera + 152 — plutot que de porter une position.
;   naissance (704, 288) arcade  ->  x = 152, y = 81
;   duree de vie $0600 = 1536 trames de jeu, puis retrait silencieux
;   periode d emission $40, salve 4, ancre Y des wicks $0130 -> 69
;
; LA TIMELINE DE DENSITE (1000:3afe), quatre mutations puis fin. Le seuil est
; le compteur de trames de l emetteur ; les deux bits de poids fort de
; l opcode choisissent la cible, les douze bas portent la valeur :
;   t=8    ancre Y      := $00D0 (208 arcade) -> 141
;   t=16   periode      := 36
;   t=64   salve        := 3
;   t=192  ancre Y      := $0110 (272 arcade) ->  93
; ATTENTION : le prereglage de DIFFICULTE est recharge a CHAQUE trame AVANT
; les mutations du script — le script se pose par-dessus le plancher, il ne
; le remplace pas. A la difficulte 0, celle du reste du cast : periode 36,
; salve 3. La periode posee par le ctor ($40) ne vit donc que 16 trames.
;
; LA PONTE (40:8817). L enfant nait a (x de l emetteur, y - 32 + rand[0..63]),
; le tirage evitant que la nuee s empile. L axe Y arcade monte : chez nous
;   y_enfant = y_emetteur + 24 - (rand[0..63] x 0,75)
; soit une dispersion de 48 px larges sous l ancre.
; LA REGLE DE SALVE, et c est elle qui fait le comportement : chaque ponte
; decremente le compte de salve ; au passage a zero SEULEMENT, le nouveau wick
; recoit un delai de pique tire dans [0..255]. Les autres recoivent ZERO et ne
; piqueront JAMAIS. Un wick sur trois pique, et c est le dernier de sa salve.
;
; L ETAT DERIVE (40:8861). Il suit le decor (il lit bien 0x2ED0).
;   X : defilement + vitesse propre, -1,5 px/trame arcade a la difficulte 0,
;       soit -0,5625 v2 — exactement la vitesse primaire du gouger.
;   Y : DEUX composantes qui s ajoutent —
;         . un rattrapage lent vers (ancre du parent + rand[-32..+31]) a
;           +/-0,0625 px/trame arcade (0,046875 v2)
;         . un CRENEAU de +/-0,25 px/trame arcade (0,1875 v2) commande par le
;           bit 6 d un compteur : amplitude ~32 px arcade (24 v2), periode
;           128 trames. C est l ondulation de tetard.
;   Poses : 4 images, tenues 4 trames, periode 16.
;
; L ETAT PIQUE (40:893e), TERMINAL — aucun retour a la derive. La vitesse est
; echantillonnee UNE FOIS dans wick_aim_motion_dispatch par (difficulte x 2 +
; direction) : ce n est pas un poursuivant, il part en ligne droite et ne
; corrige plus. La pose depend de la direction (selecteur par octant, 3b32).
;
; MORT : au premier coup (AABB 1000:3c12, rayon 8 arcade sur les deux axes ->
; 3 en X et 6 en Y), score $86E8 — le plus bas de la table —, son 0x54,
; explosion_special 40:e7a6.
;
; CE QUI DEMANDERA UN ARBITRAGE
; - 32 poses de 6x12 deja converties dans images/animation, mais le code n en
;   cite que 4 pour la derive : le reste sert aux huit directions du pique
;   (3b32). Voir combien la table en emploie reellement avant de tout compiler.
; - la difficulte : on prend la 0 comme le reste du cast, donc la timeline ne
;   change que l ancre Y et la salve — la periode qu elle pose EST le plancher.
; - les sons, comme partout dans ce portage : aucun.
;*******************************************************************************
wick.Object
        jmp   stage2.cast.stub          ; implementation vide : compter, rendre le slot
