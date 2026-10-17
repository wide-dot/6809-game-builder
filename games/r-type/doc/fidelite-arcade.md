# Fidélité arcade : le banc trace contre trace (16/10/2026)

Un boss porté est fidèle quand, aux mêmes entrées, il passe par les mêmes
états aux mêmes trames que la borne. Ce document décrit la méthode et les
outils qui le vérifient sans jugement visuel, et ce qu'il faut respecter dans
le code d'un portage pour que la vérification soit possible.

Clients : Bellmite, le boss du stage 5, puis le Compiler (stage 4), réécrit
1:1 le 16/10/2026 parce que ses déplacements divergeaient, puis l'essaim de
Dops (stage 6), Bronco (stage 7) et le Bydo core (stage 8), portés le même
jour : tous les boss sont désormais portés 1:1.

## Le constat qui rend la méthode possible

Pendant un combat de boss, la borne est **déterministe à l'octet**. Trois
mesures sur la trace MAME de Bellmite :

- **le générateur aléatoire.** `random_ax` (0x40:EDE9) est un registre à
  trois octets (0x2F28..2A). Chaque transition de cet état entre deux trames
  s'explique par les tirages de la famille du boss : 2 par satellite en
  orbite les trames où `compteur & 7 == 0`, 1 à 3 par changement de cap du
  noyau. Aucun autre objet ne tire pendant le combat ;
- **le réensemencement.** La boucle principale remet l'état à (5, 1, 3)
  quand le compteur global (0x2EB6) franchit un multiple de 512
  (0x40:021D). Au spawn de Bellmite, l'état vaut (5, 1, 3) : rien n'a tiré
  depuis le dernier multiple ;
- **le vaisseau.** Les satellites visent le joueur et choisissent le plus
  proche de lui. Épinglé sur un point fixe, il cesse d'être une entrée
  variable.

Même graine, même horloge, même vaisseau : la borne rejoue le même combat. Un
port qui calcule comme elle doit le rejouer au même octet.

## Ce que le portage doit respecter

1. **Calculer en repère arcade.** Positions 16.8, vitesses 8.8, seuils et
   tables recopiés tels quels, x vers la droite et y vers le **haut**. Seul le
   dessin convertit : `x_écran = 8 + ((x − 320) × 3) >> 3`,
   `y_écran = 297 − (y × 3) >> 2`. Les boss précédents convertissaient les
   vitesses en unités TO8 et l'arrondi dérivait ; c'est l'origine probable
   des écarts de déplacement du Compiler.
2. **Une trame arcade à la fois.** Une routine joue exactement une trame de
   jeu pour toute la famille, dans l'ordre de la liste arcade (priorités
   croissantes). Le rendu la joue `frameDrop.count` fois. Les cadences (toutes
   les 8 trames, une trame sur 4, périodes) gardent ainsi leur phase.
3. **Le générateur de la borne, privé.** Une copie de `random_ax` et de son
   réensemencement, tenue par le boss, avec une copie du compteur global
   semée depuis `gfxlock.frame.gameCount` au spawn.
4. **Des crochets nommés.** `<boss>.Seeded`, après la création et avant
   la première trame jouée : le banc y écrit l'horloge et la graine de la
   borne. `<boss>.Spawned`, quand les records existent : le banc y écrit les
   **résidus** de la borne (voir plus bas). `<boss>.Tick`, en tête de chaque
   trame arcade : le banc y injecte les dégâts d'un scénario. `<boss>.Sample`,
   à la fin de chaque rendu : le banc y relève l'état. Un boss dont les
   tirages ne se reproduisent pas (voir plus bas) a un cinquième crochet,
   `<boss>.Drawn`, sur le `rts` de sa routine de tirage. Un boss sans
   résidus de création n'a pas de `Spawned` : ses résidus s'écrivent à
   `Tick`.

## Les résidus d'un record recyclé

La première comparaison de Bellmite divergeait dès la trame 2 sur les
fractions de position : la borne ne remet pas à zéro les octets +3 et +7
d'un record qu'elle réalloue. Le noyau naissait avec x.frac = $46 et
y.frac = $F5, restes de l'occupant précédent, et ces fractions décalaient
d'un pixel les retenues de mouvement 66 trames plus tard. Ce sont des entrées
du combat au même titre que la graine : le port les pose à 0, le banc écrit
celles de la borne au crochet `Spawned`. Après cette injection, plus aucune
divergence.

## Quand le flux aléatoire est partagé : rejouer les tirages

Le constat de Bellmite — tous les tirages pendant le combat viennent du
boss — ne tient pas pour le Compiler : son combat fait naître le champ
d'étoiles, et `star_ctor` tire trois fois par étoile (724 étoiles sur un
combat). Le port ne fait pas naître ces étoiles de la même façon ; il ne
peut pas reproduire le flux, seulement SES tirages.

La trace MAME porte alors, trame par trame, l'adresse de retour de chaque
appel à `random_ax` (`PILOT_RNGLOG=1`, champ `rc`). L'état du générateur
avant et après chaque trame étant connu, la valeur que chaque appelant a
reçue se recalcule. La référence garde la liste des tirages de la famille
(`d` : appelant, AX). Côté TO8, chaque tirage passe par `cpl.Draw` ; le banc
s'arrête sur `compiler.Drawn` et écrit dans D la valeur de la borne. Il
compte les tirages en trop ou manquants : un port qui tire au mauvais
endroit ou au mauvais moment se voit là, avant même la comparaison d'état.

**Piège du crochet de tirage.** Une IRQ prise SUR l'instruction du crochet
y revient après son RTI : le même tirage arrête le banc deux fois, et le
second arrêt consommait le tirage suivant (vu à la trame 4379 : la paire de
lasers roulants naissait avec les vitesses de la paire d'après). Un vrai
tirage fait toujours avancer le générateur du port ; un arrêt dont la pile,
l'adresse de retour et l'état du générateur sont ceux de l'arrêt précédent
est ce doublon, et le banc l'ignore. Tester D ne suffit pas : la valeur
propre du port coïncide souvent avec celle de la borne (même graine, et le
champ d'étoiles ne tire que par intermittence).

## Quand la trajectoire est écrite dans le décor : vérifier la carte

L'essaim de Dops du stage 6 ne tire aucun nombre au hasard. Un Dop avance
sur une « voie » et tourne quand une sonde à trois pas devant lui touche une
tuile pleine : toute sa trajectoire se lit dans la carte de tuiles. Le port
n'est fidèle que si SA carte rend les mêmes réponses que la RAM de tuiles de
la borne, case par case.

La trace MAME en porte donc un vidage (`PILOT_TILEDUMP`, 16 Ko de RAM de
tuiles à l'ouverture de l'enregistrement, caméra imprimée). Le modèle
(`tools/fidelity/models/dopswarm_model.py`) rejoue tout le combat deux fois :
une fois en sondant ce vidage comme la borne sonde sa RAM, une fois en
sondant la carte de collision du TO8 (`--to8`). Les deux sont identiques à
la trace : la carte du stage 6 (`level6_fc.bin`, un bit par tuile arcade de
8×8) est juste dans l'arène — ses 48 dernières colonnes, à partir de la 335,
lignes alignées. C'est cette vérification, faite avant le 6809, qui autorise
le port à sonder la carte du TO8 en coordonnées arcade.

La carte vit dans la région de collision, dans la fenêtre cartouche d'où le
code de l'essaim s'exécute : le port ne peut pas la lire directement. Sa
tranche d'arène est assemblée dans le boss depuis le même fichier
(`INCLUDEBIN fichier,offset,longueur`, une ligne par rangée) : aucune copie de
l'asset, une seule source.

## Quand le trajet ne dépend que de la naissance : le précalculer

Les 45 Dops ordinaires et les 23 Newts de la wave du stage 6 sondent la carte
à chaque trame : trois sondes par Dop, une par Newt, une RAM de tuiles en
anneau à modéliser pour le Newt, qui regarde au-delà du bord droit. Portée
telle quelle, cette logique faisait tomber le stage à 5,88 img/s sur la
fenêtre g 1500-2000. Même avec un cache des réponses de sonde, on restait
à 6,69.

Or rien dans ces trajets n'est variable :
- aucun tirage aléatoire ;
- vitesse fixe par voie ou par phase ;
- carte fixe ;
- caméra du stage fonction de l'horloge seule (min(g/2, 2684)) ;
- trame de naissance fixée par la wave (file d'une création par trame), et
  après une reprise au checkpoint, par la wave relancée à 3200.

Le trajet d'un objet est donc une fonction de sa naissance et de son jeton,
comme la flotte de la fin (`profil-fin-2026-10.md`).
`tools/gen_stage6_paths.py` rejoue `run_dop` et `run_newt` hors ligne, avec
les modèles vérifiés contre la trace MAME. Il n'écrit que les CHANGEMENTS
(`src/stages/06/paths.asm`, un chemin par naissance) :
- `{trame absolue, voie ou phase}` à chaque virage, appliqué APRÈS le
  déplacement de la trame, comme à la borne ;
- `{trame, $FF}` quand `is_visible_range` lâche l'objet ;
- `{trame, phase + $80}` pour une GIGUE : un Newt coincé au bout d'un tuyau
  fait demi-tour à chaque trame, et sur place jusqu'à la fin du stage. Sans ce
  repli, 950 runs d'une trame ; le runtime fait la bascule lui-même après
  chaque pas jusqu'à l'entrée suivante.

Le générateur décode son propre format et le compare au modèle trame par
trame avant d'écrire : 806 entrées, 2,8 Ko. Au runtime, une trame = un pas et
une comparaison d'horloge, plus aucune sonde ; la carte de collision et le
code de sonde sortent de l'unité. La fenêtre passe à **8,63 img/s, la cadence
du stage sans aucun Dop ni Newt** : leur logique ne coûte plus rien de
mesurable.

Le précalcul paie une seconde fois. `create_newt` pose la partie entière de
y et LAISSE la fraction du dernier occupant de l'enregistrement. Le runtime
ne pouvait pas la connaître : c'était un écart documenté (96 rendus sur 133 à
1 px, 3 avec un virage décalé de 8 px). Cette fraction appartient à la partie
jouée, et le générateur porte celle de la partie de référence, relevée sur la
trace (un octet devant chaque chemin). Les Newts deviennent identiques à la
borne sous toje : 136 rendus, 0 écart. Les Dops aussi : 118 rendus, 0 écart.

Critères pour reconnaître un candidat :
- aucun tirage dans la logique de mouvement ;
- aucune entrée qui dépende du joueur dans le mouvement (viser le vaisseau
  au moment du TIR reste au runtime : le tir du Newt le fait) ;
- un environnement fonction de l'horloge seule ;
- une naissance déterminée par la wave, à vérifier aussi pour la reprise.

La mort par le joueur n'est pas un obstacle : elle arrête seulement le
chemin.

## Piège de trace : une trame de jeu sur deux trames vidéo

Quand la borne ralentit (Bronco crée neuf objets d'un coup), une trame de
jeu s'étale sur deux trames vidéo, et la première capture la prend à moitié
jouée : des segments créés, l'attaquant pas encore, le gestionnaire toujours
à son installation. La référence garde donc, pour chaque valeur du compteur,
la DERNIÈRE capture, et les appelants de `random_ax` de toutes ses captures.
Les références déjà écrites (Bellmite, Compiler, essaim) n'en changent pas.

## Les images : des cellules arcade, partagées et reprises

Une image arcade est faite de cellules (6 octets : décalage, tuile,
attributs). Le catalog décrit Bronco cellule par cellule quand une cellule
sert plusieurs poses : la tête de l'attaquant est commune à ses quatre bras,
celle du poursuivant à ses neuf jambes, et chacune n'est compilée qu'une
fois. Le convertisseur centre chaque cellule sur le point chaud (marge
transparente, gratuite pour un sprite compilé) : les cellules se dessinent
toutes à la position de l'objet. Avant de convertir, on cherche les codes de
tuile de l'objet dans tout le catalog : les débris de Bronco sont le
pursuer, le bug, le geld et le POW (à l'envers). Le bug, chargé au stage 7
avec sa palette, est repris tel quel ; le pursuer et le geld portent les
couleurs de leurs stages (cases 13-16) et sont reconvertis.

## Quand le boss peint le décor : les patchs du Bydo

La tête du Bydo core et ses tentacules ne sont pas des sprites : la borne
écrit des RECETTES DE TUILES dans la RAM du plan de fond (40:C335, 8×8
cellules {tuile, attribut} ; 40:C434, 7×6 tuiles à attribut fixe 0x81), avec
le bit de priorité — devant les sprites. Trois outils pour les reprendre :

- l'extracteur sait les dessiner (moteur `tile_block` du catalog,
  `cols`/`rows`/`attr`, palette de fond du stage : 0x140 au stage 8) ;
- `PILOT_BGDUMP=1` écrit, à chaque capture, la RAM du plan de fond et ses
  caméras (`bg<gc>.bin`) : on y retrouve la recette peinte et sa cellule
  (colonne 48, ligne 27 pour la tête, soit l'écran 8·(col−8), 8·(ligne−16)) ;
- `arcade_to_sprites.py --opaque` : sous un patch il n'y a rien, son index 0
  s'affiche NOIR ; le cadre est l'union exacte des recettes, jamais élargie.

Sur TO8 les patchs sont des images opaques dessinées APRÈS les tuiles (le
crochet `stage.frameFront` de `stage-main.asm`, opt-in), à leur place sur la
CARTE : leur x suit la caméra, pas le x arcade. Il faut donc que la caméra
TO8 s'arrête où celle de la borne s'arrête : 1 536 px arcade, 576 sur TO8
(corrélation de la capture arcade avec `map/in.png`). Le noyau lui-même
n'est qu'une horloge : sa chronologie (1000:6416) appelle les Win, la
bouche, les poses de la tête et l'arrêt du défilement.

## La fin du jeu : une horloge de wave qui suit le défilement

Après le Bydo core, la borne ne passe pas par un « stage cleared » : les
dernières entrées de la wave du stage 8 font la fin du jeu — le champ
d'étoiles ($0DE8), la flotte de 18 R-9 ($0F28, 40:FB10 ; le nom Ghidra
« floating score pickups » est faux), six palettes qui font scintiller les
vaisseaux ($0F78) et le directeur du générique ($1130, 40:EEAB). Piège : la
**horloge de wave suit le défilement**, pas le temps (elle s'arrête quand le
noyau fige le décor, repart à 0xC0 par trame à sa mort) ; ces créations
tombent donc à des trames arcade fixes après la mort du noyau, et le port les
pose comme telles depuis `ending.gc0` (la trame du fondu du décor, 16698
dans la trace : mort + 0x260).

Le texte est un plan de tuiles qui monte (0x2EC4/0x2EC6, 9 bits + fraction,
0,5 px par trame) : le directeur écrit des lignes de tilemap, le dessin les
place à `(8 (ligne − 16) − Y) mod 512`. `PILOT_PEEK` (liste d'adresses de la
RAM de jeu, un mot chacune par trame) a donné ces registres ; la référence
les compare avec le directeur et les vaisseaux. `PILOT_SNDLOG` (les commandes
audio de chaque trame) a montré la musique : 0x19 (boss) à l'arrêt du
défilement, 0x1A (« Like a Hero ») au nettoyage de la salle, rien d'autre
avant le stage suivant. Côté TO8 : le défilement repart sur la queue vide de
la carte (120 px ajoutés à `map/in.png`), le noyau lance le fondu palette du
décor à l'heure arcade, la voie `FADE_ENDING` de l'objet commun de fin
attend CE fondu, efface au noir (le vaisseau seul), puis rend la main
(`STATUS_ENDING`) ; le stage 8 joue la fin sans décor ni bandeau, et ne
passe au « bonus game » (stage 1, score gardé) qu'une fois le noir complet.
Les vaisseaux de la flotte ont leur variante décalée d'un pixel.

Le texte du générique est, sur la borne, au-dessus de tout (étoiles et
vaisseaux). Côté TO8, chaque ligne est UN
sprite compilé transparent (`tools/gen_ending.py` relit les glyphes du HUD
en simulant leur code et sort `images/lines/NN.png` ; gfxcomp : index 0
transparent, index n = couleur n − 1), dans son propre fichier
(`stage8.credits`, arène `stage8.foes`, 14,9 Ko), dessiné par la passe de
surimpression après les sprites, avant les colonnes noires. Mesuré sur
les 580 rendus de la séquence (code généré compté instruction par
instruction) : pire rendu 15 706 cycles contre 34 868 glyphe par glyphe,
moyenne 3 305 contre 7 303.

Le cadre : les deux colonnes de 8 px sont repeintes à chaque rendu
(`images/viewport`, 5 121 cycles : un `PSHU D,X` par ligne et par plan, la
colonne droite d'une ligne et la gauche de la suivante étant contiguës), à
la place du masque du jeu (8 049). Elles font entrer les vaisseaux : la
flotte n'est plus refusée dès qu'elle touche un bord, un vaisseau à cheval
sur le retour de ligne déborde dans la colonne de la ligne voisine, cachée.
Les bandes du haut et du bas font de même pour le texte : une ligne est
dessinée dès qu'elle mord sur le champ (son haut de la ligne 3 à la 191),
puis les lignes de bande qu'elle a couvertes sont remises au noir
(`credits.Band`, 100 cycles par ligne et par plan, seulement quand une
ligne est à cheval). Hors de là, rien ne dessine dans ces bandes — sauf UNE
chose, trouvée sous toje (point d'arrêt d'écriture sur la vidéo) :
l'effacement du champ (`playfield.clearBlast`) empile son noir avec S, de la
ligne 190 à la 11, et une IRQ qui tombe à la fin pose ses 12 octets de
registres sous S, octets 28 à 39 de la ligne 10. Le masque du jeu le cache
en jeu ; le cadre de la fin repeint ce bout de ligne.

La commande n'est pas le son. Mesuré sur la piste audio d'un enregistrement
MAME (17/10, de la mort du noyau au second tour) : 0x1A est posée 0x100
trames après la mort, mais le son s'ARRÊTE à +0x180 (fin de la phase 1 du
noyau, explosions comprises), un silence, et « Like a Hero » se TAIT quand
le noir qui suit ENJOY est complet (18 917 = le noir de 40:EF89 à 18 867 +
ses 48 trames), sans commande audio. Le port coupe à la fin de la phase 1
(`ending.music` $FF) et CALE LE MORCEAU PAR SA FIN (décision de l'auteur) :
notre arrangement YM2413 (adnz) n'est pas l'enregistrement de la borne, sa
dernière note est à la trame 1 976 à 50 Hz, d'où un départ à
`ending.T_MUSIC` = 2 219 − 1 976 = 243 sur l'horloge de la fin (entre les
étoiles et la flotte). Le caler sur le noyau le faisait partir en avance :
côté TO8 l'horloge de la fin ne démarre qu'après le fondu et l'effacement
au noir. Vérifié sur la capture TO8 : dernière note à 63,9 s, noir complet
à 64,0 s. Écart restant, de la machine : le chargement du stage 1 ajoute un
long noir silencieux que la borne n'a pas.

## Le second tour : la difficulté 2

La borne recalcule sa difficulté (0x2F2E) à chaque trame dans le tic du
joueur (40:2036) : `(second_loop ? 2 : DIP Hard ? 1 : 0) + (Force ≥ 2 ?
1 : 0)`, plafond 3 — le dernier terme lit le niveau de Force du joueur
(0x3E, son record +0x1E). `second_loop` (0x2F2D) recopie à chaque départ de
stage le compteur de tours du joueur (0x2F42), que la fin incrémente
(40:EE7B) — et le game over aussi (40:EFE3) : sur la borne, un continue
joue la suite en forme de second tour, et le continue n'est offert que si
ce compteur reste sous 2 (40:12c1). Mesuré sous MAME (DIP par défaut,
vaisseau sans Force, sonde jetable sur les états `stage<N>`) : 0 sur les
huit stages du premier tour, 2 dès le stage 1 du second, et le compteur de
stage de la borne passe à 9.

Le port tient le compteur dans `globals.loop` (semé avec la partie, avancé
par la fin du jeu et par le continue accepté ; la fin du premier tour
consomme le quota de continue, comme le compteur unique de la borne). Ce qui lit la difficulté
(Ghidra n'en voit pas toutes les lectures : un balayage des octets
`2e 2f` / `2d 2f` de la ROM en trouve 12 et 6 de plus) :

- déjà branché : presets de tir communs, Tabrok et ses missiles, P-Staff,
  Brood, Scant, Wick, Cancer ;
- branché le 16/10 : PV du noyau du Shell (6/10/25/40), PV et tir du Cytron
  (1000:9294 — à la difficulté 0 il ne tire PAS : le port tirait par le
  preset de sa variante), vitesse de la Geld (1, 1,5, 2, 3 px), cadence et
  vitesse des lasers et seuils des tourelles du Compiler, période et
  vitesses d'attaque de Bellmite (tables par difficulté régénérées par
  `gen_compiler.py` / `gen_bellmite.py`) ;
- au second tour seulement (`globals.loop`) : PV des Zoid (70), du réacteur
  de queue (250 : le potentiel d'une boîte est un octet signé plafonné à
  126, la boîte en porte 125 et une réserve la recharge), noyau du vaisseau
  (ouvert 64 trames, un feu toutes les 4), cadence (0x20) et salve
  (1000:414E, ~1,8 fois plus rapide) de l'Outslay ;
- les tourelles de proue du vaisseau RÉAPPARAISSENT (40:d6f5..d77b), aux
  deux tours : 256 trames après leur destruction, à 14 PV, en clignotant
  leurs 32 dernières trames ; au premier tour seulement une fois le maître
  âgé de 0x1C30 trames (son compteur +0x32, `warship.age0` chez nous) ;
- la fin du second tour ne dit pas « ENJOY THE BONUS GAME AGAIN » : le
  directeur attend 0x120 trames puis la borne passe au game over (40:EF5D)
  — chez nous le noir puis la séquence GAME OVER du corps de stage, sans
  continue.

- le numéro de stage EFFECTIF prend +8 au second tour (40:f0c9, 0x2FCD) :
  la case de score par stage (seize cases, une par stage des deux tours),
  les lignes du récapitulatif STAGE SCORE et le « STAGE n CLEARED »
  (1000:8BE0 : « 9 » à « 16 ») le lisent — `ranking.stageNo`, et
  `ranking.resetHere` pour le continue.

- le terme Force ≥ 2 : la difficulté est une fonction pure du tour et du
  niveau de Force (DIP par défaut), recalculée par `_difficulty.update`
  (variables.asm) là où l'un des deux change — semis de partie, ramassage,
  mort, fin du jeu, continue ; le noyau du vaisseau prend aussi sa forme
  rapide sur Force ≥ 2 (`core.Hard`, dddd/dfcc). Règle de l'auteur
  (16/10) : du 1:1 avec la borne tant que c'est techniquement possible.

Pas encore porté : Mid, Pursuer et Cheetah (les ennemis eux-mêmes ne le sont
pas) devront lire la difficulté. Le Mikun la lit depuis le 17/10/2026 : sa
vitesse de lancement vient de la table de la difficulté courante (1000:4284,
le pool du pique du wick).

Piège de banc relevé au passage : le Compiler a une trame AVEUGLE, gc0+1 —
ses résidus arcade sont écrits au Tick de la trame suivante. Tant qu'aucun
rendu ne tombait dessus, le banc disait IDENTIQUE ; un décalage de cadence
l'y a fait tomber. Le profil la déclare (`blind = 1`) et la comparaison
l'écarte en le disant.




Un écart assumé du port qui touche l'état du boss devient une ENTRÉE du
banc, comme la graine : la valeur de la borne est imposée, l'injection est
comptée et affichée. Le seul cas aujourd'hui est la mort d'un segment de
laser roulant du Compiler sur le décor. La borne garde ses chaînes de
gommes à l'écran pendant le combat et y perd ses segments ; le TO8 remplace
le décor par le champ d'étoiles et coupe ce plan de collision (décision du
28/08, `stage-main.asm`, `plainBackdrop`). Quand un segment manque à la
borne, et qu'il est le seul écart des segments, le banc le retire du port
(26 sur le combat sans tir). Un segment que le port perdrait seul resterait,
lui, une divergence.

## Les outils

| Étape | Outil | Sortie |
|---|---|---|
| Trace borne | `pilot/tools/trace_actors.lua` (fork MAME) : état d'entrée du stage, vaisseau épinglé, records de la famille à chaque trame | JSON Lines brut |
| Référence | `tools/fidelity/fidelity.py arcade <boss>` décode selon le profil du boss | `tools/fidelity/ref/<boss>.ref.jsonl.gz` (commitée ; `--check` la rejoue) |
| Spécification | `tools/fidelity/models/<boss>_model.py` : le boss en Python, routine par routine, vérifié contre la trace brute avant d'écrire une ligne de 6809 (Compiler) | `IDENTIQUE` ou la première divergence par champ |
| Trace TO8 | `tools/fidelity/fidelity.py to8 <boss> dist/to8.fd` : toje, saut par le cheat du title, graine écrite au spawn, relevé à chaque rendu | JSON Lines, même format |
| Verdict | `tools/fidelity/fidelity.py compare <boss>` : jointure sur l'horloge globale, comparaison champ par champ | première divergence de chaque champ et compte |

Les adresses viennent toutes du build courant (`.lwmap`, rapport
d'occupation) : aucun littéral.

Le vaisseau est épinglé en (512, 228) arcade, dont l'image TO8 est exacte :
(80, 126) en écran 0-base. Le port reconvertit la position du joueur en
unités arcade sans arrondi sur ce point (`x = 320 + 2v + (v·171 >> 8)`,
`y = w + (w·171 >> 9)`, exactes sur toute la plage).

## Un profil de boss

Le profil (classe Python dans `fidelity.py`) dit trois choses : les handlers
de tick qui forment la famille, comment décoder un record arcade en état
normalisé, et comment décoder la mémoire du port vers le même état. Les
états de la borne (adresse du handler) deviennent des numéros ; les champs
comparés sont ceux que le port tient en repère arcade.

## Les scénarios

Un scénario est une liste de coups `(trame après le spawn, cible)`. Côté
borne, le script Lua écrit l'octet de dégâts (+0x1F) de la cible avant la
trame ; côté TO8, le banc met le potentiel de sa boîte à zéro au crochet
`Tick` de la même trame. Le flash de coup n'est pas armé : la borne ne l'arme
que sur une vraie collision. `idle` est le combat sans tir (le boss sort par
son délai), `kill` tue 26 satellites puis le noyau.

| Scénario | Rendus TO8 comparés | Valeurs | Résultat (16/10/2026) |
|---|---|---|---|
| bellmite idle | 598 | 212 002 | identique |
| bellmite kill | 168 | 37 789 | identique |
| compiler idle | 1 684 | 87 478 | identique (26 morts de segments sur les gommes en entrée) |
| compiler kill | 328 | 11 416 | identique (gauche, bas puis droite, cascades jouées) |
| bydo idle | 1 776 | 21 361 | identique (combat complet, mort au délai 0x2000, phases et cascade : 440 tirages rejoués) |
| ending idle | 753 | 3 012 | identique (du fondu du noyau à la fin du directeur : 18 vaisseaux, directeur, défilement du texte) |

Les valeurs de l'essaim comptent l'état du gestionnaire et la liste des
Dops comme une valeur chacune : chaque rendu compare toutes les positions
16.8, les voies et les variantes des Dops vivants.

`compiler idle` va jusqu'au bout des scripts : les trois pièces atteignent
leur terminateur, l'orchestrateur joue sa séquence de 256 trames et
disparaît. `compiler kill` détruit une pièce toutes les 200 trames.

Bellmite tourne à 4 à 6 trames de jeu par rendu sur TO8 (8,5 images par
seconde en moyenne pendant le boss), le Compiler à 4,3 (11,6 images par
seconde).

## Les captures appariées

`--shots k1,k2,...` sur les deux commandes enregistre l'écran de la borne à
la trame k et celui du TO8 au rendu qui suit (à six trames près), pour juger
le dessin, que le banc ne compare pas.

## Piège de banc : ne jamais détourner le PC sans reposer la pile

`run_frames` s'arrête n'importe où, gestionnaire d'IRQ compris. Un PC posé
à ce moment-là laisse le fil principal tourner sur `Irq_sys_stack`, et
l'interruption suivante écrase ses cadres. Le symptôme imite un bug du jeu :
DKCONT rendait la main en $0005 au milieu du chargement du stage 5. Avant
tout saut, le banc repose S sur `glb_system_stack`, DP sur $9F et masque les
IRQ (CC = $D0).

## La méthode, dans l'ordre (leçon du Compiler)

1. Tracer la famille sous MAME, tirages compris.
2. Écrire le **modèle Python** routine par routine, adresse arcade en
   commentaire, et le faire tomber à `IDENTIQUE` contre la trace brute. C'est
   là que se trouvent les vraies règles (tempo double des segments de combat,
   pièces qui avancent en bloc, compteur de tir `(AX·4) & (seuil−1)`,
   résidus des records recyclés), en secondes et non en minutes de toje.
3. Traduire le modèle en 6809, mêmes noms, même ordre.
4. Profil du banc, référence, comparaison TO8 : les écarts restants sont
   des fautes de traduction, pas de compréhension.

## Ce que le banc ne couvre pas

- Les vrais tirs. Les dégâts sont injectés, pas visés : la collision du
  moteur (une passe par rendu au lieu d'une par trame) reste un écart assumé.
- Le dessin. Le banc compare des états, pas des pixels.
