;*******************************************************************************
; brood — SQUELETTE, avec sa FICHE DE PORTAGE complete (relevee le 26/08/2026)
;
; Organisme FIXE monte sur la paroi, qui ouvre la gueule et crache des
; parasites ZOID. Deux lignes de wave au stage 2, une par orientation :
;   $06,$E0 octet $01 -> sol,     gueule vers le HAUT
;   $08,$B4 octet $00 -> plafond, gueule vers le BAS
; Alias v1 : baldur (la wave v1 ecrivait ObjID_baldur ; le catalog arcade et
; routines.yaml disent brood).
;
; FICHE DE PORTAGE (base Ghidra `maincpu`, subsystems brood et zoid)
; -------------------------------------------------------------------------
;   40:7d68 create_brood ............... le spawner
;   40:7dbb run_brood ................. entree, attend d'etre a l'ecran
;   40:7e18 .... settle    40:7e80 idle_a   40:7eeb spawn
;   40:7f49 idle_b         40:7fad exit_wait
;   40:7fff brood_destroyed   40:8022 brood_unload_silent
;   40:8058 create_zoid ............... la ponte, trois creneaux
;   40:8d85 run_zoid_egg   40:8dc6 hatch   40:8e15 parasite
;   40:8efa zoid_retarget  40:8ecc zoid_recoil_on_hit
;   1000:37de presets d'orientation   37e6 les poses ENTRELACEES
;   1000:3846 les boites par orientation
;   1000:3ee6 les seize destinations de rodage   3f6e la boite du zoid
;
; L'ORIENTATION N'EST PAS UNE VARIANTE COMME UNE AUTRE : le bit 0 de l'octet
; de wave choisit un MONTAGE, et il commande a la fois l'ordonnee de
; naissance, la rangee de poses et la boite de collision.
;   orientation 0 : y arcade 368 -> 21   (plafond, gueule en bas)
;   orientation 1 : y arcade 160 -> 177  (sol, gueule en haut)
; X est fixe a $02D0 comme le gouger — soit 158 chez nous.
;
; LES POSES SONT ENTRELACEES, et c'est ce qui rend la table lisible :
; brood_anim_frames_interleaved (1000:37e6) alterne les deux orientations,
;   [0] plafond ferme   [1] sol ferme     [2] plafond entrouvert  [3] sol ...
;   [6] plafond GUEULE OUVERTE            [7] sol GUEULE OUVERTE
; Nos huit PNG sortent de cette table meme (000_0137e6.png et suivants) :
; l'index d'image vaut donc directement `trame x 2 + orientation`. Rien a
; remapper — pour une fois.
;
; LES BOITES sont ASYMETRIQUES et differentes par orientation (1000:3846) :
;   plafond : x -24..+24  y -16..+32 arcade -> rayon 9 et 18, centre a -6
;   sol     : x -24..+24  y -32..+16        -> rayon 9 et 18, centre a +6
; L'axe Y arcade monte : le corps est du cote de la paroi dans les deux cas.
; Notre AABB portant un centre et des rayons, le decalage se pose sur cy.
;
; LA CHAINE DE PHASES. Chacune defile avec la carte, dessine, teste la
; collision, teste les PV (40) et fait descendre un compteur :
;   entree    attend x < $0270 (entre a l'ecran), puis compteur = 8
;   settle    DESCEND de compteur*4-2 px par trame, 8 trames — une chute qui
;             ralentit, l'organisme se pose sur la paroi. Puis compteur = $3F
;   idle_a    63 trames d'OUVERTURE de gueule : l'offset d'animation vaut
;             (-compteur & $30) x 1,5 et parcourt 0, 24, 48, 72
;   spawn     192 trames GUEULE OUVERTE, pose fixe ; create_zoid est appele a
;             chaque trame mais ne pond qu'a trois valeurs precises du
;             compteur — $C0, $80 et $40
;   idle_b    63 trames de FERMETURE, l'offset parcourt 72, 48, 24, 0
;   exit_wait defile jusqu'a x < $0130, puis retrait silencieux
; Mort : son 0x52, score $8700, grosse explosion gris-brun (40:e817).
;
; LA PONTE, ET SON PIEGE DE DIFFICULTE. Trois creneaux, mais le troisieme
; ($40) est conditionne a une difficulte non nulle. A la difficulte 0, celle
; du reste du cast, UN BROOD NE POND QUE DEUX ZOIDS. Le troisieme n'existe
; pas chez nous, et ce n'est pas une simplification.
;
; LE ZOID, trois phases et DEUX ANCRAGES — le cas que la skill signale :
;   oeuf      suit le decor (il lit 0x2ED0), avance sur un script de
;             deplacement, quatre poses tenues quatre trames. Il eclot a la
;             FIN DU SCRIPT ou au premier coup encaisse, ce qui arrive en
;             premier. Puis 31 trames d'eclosion.
;   eclosion  IMMOBILE, quatre poses tenues huit trames, index pris dans les
;             bits hauts du compte a rebours. Invulnerable : le resultat de
;             la collision est jete. A la fin : 4 PV, et il passe parasite.
;   parasite  NE SUIT PLUS LE DECOR — verifie sur les octets, son tick
;             n'ouvre pas sur `a1 d0 2e`. Il rode en coordonnees ECRAN, ce
;             que confirment ses seize destinations, toutes des positions
;             d'ecran. Vitesse 8.8, quatre poses tenues huit trames.
;
; LE RODAGE (zoid_retarget) est une jolie mecanique a un verrou :
;   . il tire une destination au hasard parmi seize, et pose
;     vx = (cible_x - x) << 1, vy de meme — soit un pas de delta/128 par
;     trame : il ARRIVE juste quand le compte a rebours de 128 trames expire.
;   . une fois sur quatre, il arme un verrou pour le PROCHAIN rodage, qui
;     visera alors le JOUEUR au lieu de la table. Le verrou est a un coup :
;     il se consomme et ne colle jamais.
; Soit environ trois rodages au hasard pour un rodage sur le joueur.
;
; CE QUI DEMANDERA UN ARBITRAGE
; - les sons (0x5D ponte, 0x57 coup, 0x52 mort) : aucun dans ce portage.
; - le clignotement de coup passe par une palette d'objet, globale chez nous :
;   meme choix que le serpent et le gouger, une image blanche ou rien.
; - `still-open` etait un dossier d'images VIDE, laisse par un export : retire.
;*******************************************************************************
brood.Object
        jmp   stage2.cast.stub          ; implementation vide : compter, rendre le slot
