# Le gouger face à la borne : timings, compensation du frame drop, déplacements

Analyse du 08/09/2026. Retour de l'auteur : certains gougers sont fidèles à
la borne au pixel près, d'autres franchement décalés. Sources : base Ghidra
`maincpu` (6F89, 6FD0, 7048, 7106, F9F0, 1E6C, 1D89), tables 1000:9384 et
93BC ; `src/enemies/gouger/obj.asm` ; mesure de cadence du stage 2 sous
toje (`tools/fps_stages.py`).

## 1. Ce qui est vérifié fidèle

| point | borne | v2 | verdict |
|---|---|---|---|
| position de naissance | X = 0x2D0, Y = 0x178 / 0x098 | camera + 158 ; 15 / 183 (297 − 0,75·y) | exact |
| vitesses de plongée | ±1,5 ; ±2,0 px/trame (8.8) | ±144 ; ±384 (×0,375 / ×0,75, Y inversé) | exact |
| vitesses de reptation | ±0,375 ; ±0,5 | ±36 ; ±96 | exact |
| déclencheur compte à rebours | 128 / 384 / 512 trames, DEC par trame | soustraction du frame drop, plonge à ≤ 0 | exact au pas près |
| déclencheur « guet » | `set_direction_to` == 0x18/0x28/0x08/0x38 | `setDirectionTo` (port 1:1 de la routine, bandes mortes 8→6 et 8→3, test |dx|−|dy| mis à l'échelle) contre `gouger.Compass` | exact |
| point sondé | le CENTRE de l'objet (`probe_foreground_tile` lit la cellule de pos_x/pos_y, pas 64 px plus loin — le plate comment se trompe) | `terrainCollision.sensor` = x_pos/y_pos | exact |
| sens de « vide » | id == 0xFA0 → plongée, sinon reptation | B == 0 sur la carte de collision → plongée | exact sur ce stage : aucune cellule d'id dans [0xDFC, 0xFA0) dans le plan avant du stage 2 (compté sur l'export), la carte « solide pour le joueur » et « non vide pour le gouger » coïncident |
| animation | (anim & 0x3C) >> 1, un slot par 4 trames, 16 mots dont 8 répétés | (anim >> 2) & 7, compteur compensé | exact |
| recul | 0x17 trames, pas de déplacement, clignote une trame sur 4 | 23 trames compensées, pas de Move | exact |
| fenêtre de visibilité | ±20 px arcade autour du cadre | 0..159 × −6..204 | exact |
| verrou de défilement | pos_x += scroll_amount chaque trame | coordonnées playfield | équivalent |

## 2. Ce qui n'est pas fidèle : la granularité du pas sous frame drop

La borne, à chaque trame : sonde la cellule sous le centre, puis avance
d'UNE trame de vitesse. En plongée elle avance de 2 px arcade par trame sur
des cellules de 8 px : quatre lectures par cellule, aucune ne peut être
sautée.

La v2 (`gouger.Dive`) sonde UNE fois par trame RENDUE, puis avance de
`frameDrop.count` trames d'un coup (`gouger.Move` multiplie la vitesse).
Mesuré sur le stage 2 (9 000 trames, vaisseau immobile, invincible) :

| caméra | fps | drop moyen | drop max |
|---|---|---|---|
| 0..900 | 7,9 à 11,7 | 4,3 à 6,3 | 5 à 8 |
| salle du boss | 8,6 | 5,8 | 8 |

Écarts entre deux rendus : 4 (10 %), 5 (47 %), 6 (32 %), 7 (11 %), 8.

Donc, en plongée, un pas de rendu déplace le gouger de **7,5 à 12 px en Y**
et de **2,8 à 4,5 px en X**, sur des cellules de collision de **3 × 6 px**
(la cellule arcade 8 × 8 à notre échelle). **Chaque pas saute au moins une
rangée de cellules, et souvent une colonne.** Une corniche d'une cellule
d'épaisseur tombe entre deux lectures : le gouger la traverse et continue
sa plongée là où la borne se pose dessus et rampe. Une plate-forme de deux
cellules est touchée ou manquée selon la phase du pas — d'un essai à
l'autre, le même gouger fait deux choses différentes.

C'est exactement la répartition observée : **un gouger dont la plongée ne
croise que du vide est fidèle** (les vitesses et les déclencheurs le sont) ;
**un gouger dont la trajectoire rencontre du décor** — corniche, paroi
d'en face, relief du sol — **dévie**, et d'autant plus que la cadence est
basse à cet instant.

Deux effets secondaires du même pas, plus petits :

- **la sortie de la paroi** : en reptation (0,375 px/trame en Y) le pas
  vaut 1,9 à 2,8 px, la sortie de la cellule solide est vue avec jusqu'à
  une demi-cellule de retard — la plongée part de 2 à 3 px plus loin ;
- **la transition vide → solide** en cours de plongée est vue avec jusqu'à
  12 px de retard quand elle n'est pas manquée : le gouger s'enfonce dans le
  décor avant de ramper.

Un troisième écart, indépendant du pas : **le retard de wave**. La wave
pose l'objet avec `wave_frame_drop` trames de retard sur l'instant arcade ;
l'outslay et le pata-pata le consomment à leur Init, le gouger non. Son
compte à rebours part donc jusqu'à 7 trames trop tard, et il naît à
camera + 158 de la trame rendue, soit ≤ 1 px trop à droite. Faible, mais
systématique.

## 3. Ce que ça coûterait de corriger

**Sous-diviser la phase B par trame de jeu** : une boucle de
`frameDrop.count` tours, chaque tour = une sonde puis un pas d'une trame
(vitesse brute, sans multiplication). C'est le tick arcade, à la trame
près. Coût : une sonde `terrainCollision.do` par trame de jeu au lieu d'une
par trame rendue — ~130 cycles la sonde (montage de page, table, masque),
soit ~800 cycles par gouger et par rendu au drop 6, ~2 400 pour trois
gougers en plongée simultanée : de l'ordre de 2 % d'une trame rendue à
8 images par seconde. Le compteur d'animation et le son de traînée suivent
naturellement (ils comptent déjà par trame de jeu).

**Variante économe** : sous-diviser par pas de 3 trames au plus (4,5 px en
Y, 1,7 en X, sous la cellule sur les deux axes) : plus aucune cellule
sautée, deux sondes par rendu, mais l'instant de transition garde ±3
trames d'imprécision. La borne, elle, est à la trame.

**Le retard de wave** : à l'Init, retrancher `wave_frame_drop` du compte à
rebours et avancer la position de `wave_frame_drop × scroll_vel` — ce que
font déjà les autres ennemis ; quelques instructions.

Recommandation : le pas par trame de jeu en phase B (et C pour la
cohérence, bien qu'elle ne déplace rien), plus le retard de wave. Rien à
toucher aux tables ni aux déclencheurs : ils sont justes.

## 4. Réalisation (08/09/2026, « corrige tous les écarts »)

- `gouger.Dive` : une boucle de `frameDrop.count` pas, chaque pas = sonde
  au centre puis une trame de vitesse (`gouger.n` = 1 dans `gouger.Move`),
  le compteur d'animation incrémenté par pas de reptation (7077 : INC par
  tick), la pose du dernier pas dessinée. Le recul, qui ne déplace rien,
  garde son compte compensé.
- `gouger.Init` : le retard de wave rattrapé — la position reculée de
  `wave_frame_drop × scroll_vel` (8.8 sur trois octets) et le compte à
  rebours amputé d'autant ; le guet n'a pas d'horloge.
- rtype_bench 7/7. Le reste (tables, déclencheurs, animation, recul,
  fenêtre) était déjà juste et n'a pas bougé.

## 5. Les écarts persistaient : reprise depuis le code, pas les plates (08/09/2026)

L'auteur voyait les mêmes écarts après §4 et demandait si l'analyse venait
des plates Ghidra ou du code. Réponse honnête : les phases du tick
(6fd0-7168), la sonde (1e6c) et les presets (1000:9384, hexdump) avaient
été lus dans le code ; mais la **solidité** — ce que la sonde appelle
« vide » — venait de la plate de `probe_foreground_tile` (« seuil 0xDFC,
0xFA0 seule cellule au-dessus au stage 4 »). Reprise de tout ce qui
n'avait pas été lu comme instructions :

| point | source cette fois | verdict |
|---|---|---|
| `create_gouger` 6f89 | code | preset + +0x34, PV 10, palettes : rien sur la position ni les vitesses |
| `load_gouger_preset` f9f0, `load_motion_param_preset_4` fa40 | code + hexdump 1000:9384 | les 4×7 mots et les 4 déclencheurs = les tables v2, au mot près (vitesses ×0,375 / ×0,75, signe Y retourné) |
| `set_direction_to` 1d89-1e6b | code, les deux routines rejouées | compas horaire depuis le HAUT écran : 0x00 haut, 0x10 droite, 0x20 bas, 0x30 gauche. La v1 a bien retourné l'axe Y en portant ; bandes mortes 8→6/3 et cône 32/64→24/48 = ×0,75 exact. Les codes 0x18/0x28/0x08/0x38 désignent les mêmes directions écran des deux côtés |
| `move_x/y_pos_8_8` 672/689 | code | addition 8.8 signée avec report sur l'octet haut = `gouger.AddPos` |
| `is_visible_range` 1d6b | code | 300..723 × 124..403 → 0..159 × −6..204, = `gouger.Frame` |
| `probe_foreground_tile` 1e6c | code | cellule contenant le centre : col = (caméra + x − 320)/8, rangée = (383 − y)/8 — le point sondé était juste |
| **le test de la sonde** 7051 | code | `CMP AX,0xFA0 / JZ` : il plonge sur LA cellule vide et rampe sur **tout le reste** — pas « id < 0xDFC » |

**L'écart.** Le masque `level2_fc.bin` (identique à l'export
re.arcade.r-type, critère `t8Id < 0xDFC`) est celui du vaisseau. Au
stage 2, 245 cellules portent des ids 0xFA1..0xFB8 et 0xFFB..0xFFC : les
pointes claires des crocs du plafond (rangées 0-5, colonnes 97-116,
153-155, 177-195, 273-284, 305-307) et du sol (rangées 24-29). Traversables
pour le vaisseau, **solides pour le gouger** — et c'est précisément là
qu'il attend et rampe. Sondé sur la carte du vaisseau, il plongeait dès
la première pointe là où la borne rampe dessus jusqu'à la roche vide :
fidèle sur les gougers posés sur de la roche pleine, décalé sur ceux posés
sur une pointe. Vérifié par comparaison bit à bit du masque avec les ids
de `level2_f_tiles.bin` : 0 différence au critère 0xDFC, 245 au critère
0xFA0.

**Correction.** Un troisième plan de collision dans l'unité du stage 2
(`collisionMapGouger`, `level2_gouger.bin` = fc + ces 245 cellules,
généré par `tools/gen_gouger_mask.py`, 1 440 o — la région collision est
bornée par le stage 3, 7 091 o, rien ne bouge) ; `terrainCollision.planeOff`
passe à trois entrées ; le gouger sonde `gouger.PLANE` = 2. Les autres
appelants arcade de la sonde audités jusqu'ici (vaisseau, armes, cancer,
pow armor, bink) restent au seuil 0xDFC : la carte du vaisseau est juste
pour eux.

**Base Ghidra corrigée (08/09/2026)** : plate et eol de `run_gouger`
(plafond/sol = la variante du preset, pas le bit 15 ; 0xFA0 = vide →
plongée, tout autre id → reptation, test d'égalité), plate de
`probe_foreground_tile` (les DEUX conventions de solidité et les 245
cellules du stage 2), plate et 27 eol de `set_direction_to` (codes
horaires depuis le haut de l'écran : 0x00 N, 0x10 E, 0x20 S, 0x30 W — la
plate donnait E = 0x00 / N = 0x10 et les eol nommaient les sous-pas à
l'envers).

## 6. Le profil précalculé (08/09/2026, idée auteur)

Mesure d'abord, au compteur de cycles sous toje (`tools/gouger_cost_probe.py`,
un appel à la fois, page vérifiée — le profileur confond les pages) : la
plongée à un pas par trame de jeu coûtait 620 à 750 cycles la trame de jeu,
3 100 à 3 800 par trame rendue au drop 5-6, soit 4 % d'une trame à 10 images
par seconde et 11 % pour trois gougers. La moitié dans `gouger.AddPos` (deux
`mul` par axe pour multiplier par 1), ~240 dans la sonde (capteur, porte et
page de `terrainCollision.do`, tables de l'unité).

**L'observation qui change tout** : le gouger ne bouge pas dans le monde en
attente (verrou de défilement sur la borne, coordonnées playfield chez nous),
donc sa plongée part toujours de sa position de spawn, quel que soit le
déclencheur — compte à rebours ou guet du joueur. La carte est statique. La
suite de verdicts « vide → plongée, solide → reptation », trame de jeu par
trame de jeu, ne dépend que du gouger : 29 gougers, 29 suites fixes. Le
recul ne déplace pas, la mort interrompt : ni l'un ni l'autre ne change la
trajectoire.

**Réalisation.** `tools/gen_gouger_profiles.py` simule chaque gouger avec
l'arithmétique du runtime (positions 16.8, vitesses 8.8 des tables, sonde à
la cellule 3×6 de l'entier, rangée bornée à 0 comme la borne borne la
sienne) sur le masque `level2_gouger.bin`, et écrit
`src/stages/02/gouger-profiles.asm` : par gouger, l'abscisse de spawn
(caméra exacte de l'horodatage, 3/16 px par trame, + 158) puis des runs —
bit 7 = reptation, bits 0-6 = trames, 0 = fin. 238 octets, dans la région
du stage (lisible par le cast sans changer de page, `stage.gougerProfiles`
exporté). Le 4e octet du descripteur de wave, libre, porte l'index
(`sync_waves.py` numérote, le générateur réécrit). Le runtime :
`gouger.Init` prend x du profil (plus de « caméra d'alors moins retard ×
vitesse », qui pouvait tomber 1 px à gauche), `@plonge` pose le curseur,
`gouger.Dive` joue les trames du tour run par run — un déplacement par run
touché, `gouger.Move` multipliant par le nombre de trames (32 au plus, pour
que 384 × n reste sur quinze bits). Le compteur d'animation passe sur un
octet (la pose ne lit que ses bits 2-4), le curseur prend la place du
déclencheur, qui a servi.

**Ce qui disparaît** : la sonde à l'exécution, donc le troisième plan de
collision du stage 2 (1 440 o rendus à la page $17) et la troisième entrée
de `planeOff` ; `level2_gouger.bin` reste, comme entrée du générateur.

**Mesure après** : Hidden 70 cycles par trame de jeu (inchangé), Dive
**130 à 240 cycles par trame de jeu**, 770 à 1 200 par trame rendue — quatre
à cinq fois moins, et le coût ne dépend plus de la sonde mais du nombre de
runs touchés dans le tour (un, deux à la transition). Trois gougers en
plongée : ~3 % d'une trame rendue au lieu de 11 %. rtype_bench 7/7.

Les profils, lus dans la sortie du générateur : chaque gouger rampe 27 à
79 trames pour sortir de sa paroi, plonge 80 à 97, puis rampe dans la paroi
d'en face jusqu'à sortir du cadre. Deux profils portent la trace des
pointes de crocs qui ont motivé le §5 : le 18 (R43 P92 R9 P2 R77, une
pointe effleurée en bas) et le 20 (R38 P25 R44 P48, une pointe traversée
en rampant au milieu de la descente).

### 6.1 Le déplacement sans multiplication 8.8 (08/09/2026)

Où passaient les ~790 cycles d'une trame rendue en plongée, chemin exécuté
compté au désassembleur : dispatch et `Frame` ~175 (calage rendu, drop,
boîte, fenêtre), boucle du profil ~120, `Move` + 2 × `AddPos` ~275,
`Snap` 46, `Draw` + `Child` ~175. Une transition de run rappelle Move :
+330, d'où les 1 200.

`AddPos` multipliait les deux octets de la vitesse 8.8 par n (deux `mul`
et leur remue-ménage, 112 cycles par axe). Or les quatre vitesses sont des
multiples de puissances de deux — 144 = 9 << 4, 384 = 3 << 7, 36 = 9 << 2,
96 = 3 << 5 — et le signe est celui de la variante (bit 0 : x vers la
gauche, bit 1 : y vers le haut). `gouger.MovePrim` / `MoveTrail` font donc
UN `mul` 8 bits (9n ou 3n, n ≤ 32) puis des décalages fixes, et
`gouger.AddD` ajoute ou retranche le module sur la position 24 bits selon
`negX`/`negY`, posés une fois par rendu. Les tables de vitesses
disparaissent ; le générateur de profils porte les mêmes constantes et
vérifie la décomposition (assert), changer une vitesse c'est changer les
deux.

**Contrôle** : `tools/object_track_probe.py` relève à chaque trame rendue
la position 16.8 de chaque gouger avec l'horloge de jeu, et
`tools/gouger_track_check.py` la confronte à la simulation du générateur
(le départ de plongée retrouvé par la première position, puis
sim[k + Δt] pour chaque échantillon, x ou x + 1 pour le pixel de calage).
Sur 900 trames rendues : 17 plongées, toutes conformes échantillon par
échantillon — le runtime rejoue exactement ce que le générateur a simulé.

**Mesure** : Dive 671 à 717 cycles par trame rendue (985 à une transition),
134 à 197 par trame de jeu, contre 766 à 812 (1 199). rtype_bench 7/7.

## 7. Le wick, par contraste (09/09/2026)

Question posée : ses positions sont-elles déterministes ? **Non**, lu dans
le code (8817-893e) : y de naissance = ancre − 32 + rand[0..63] ; le
dernier de chaque salve reçoit un délai de pique rand[0..255] ; la cible
du rattrapage vertical est **retirée à chaque trame** (887d), ce qui fait
du rattrapage une marche aléatoire rappelée vers l'ancre ; et la direction
du pique vient du vaisseau à l'instant où le délai expire. Déterministes :
les instants de ponte, l'abscisse (défilement + vitesse constante) et le
créneau du bit 6. Un profil précalculé n'a pas de sens ici — pré-tirer
les aléas rendrait la nuée identique à chaque partie sans la rendre plus
fidèle. La v2 tire une fois par trame rendue au lieu d'une par trame de
jeu, écart assumé et noté dans la fiche.

**Ce qui a été fait** : les trois déplacements de la dérive passent aux
décalages, comme le gouger — dérive (9/18/21/24) << 4 selon la difficulté,
rattrapage 3 << 2, créneau 3 << 4, signes connus (`wick.AddAbs` /
`SubAbs`, pas borné à `wick.STRIDE` = 32). Le pique garde `wick.AddPos`,
ses vitesses sortent de tables quelconques. Mesure du wick visible en
dérive : 795 → 671 cycles par trame rendue (3 607 sur le tour où il
engage son pique ou explose).

**Contrôle** : `tools/object_track_probe.py` (relève à chaque `RunObjects`,
octets ext compris) et `tools/wick_track_check.py` — chaque pas est
déterministe même si la trajectoire ne l'est pas : x recule de 144 × d,
y bouge de ±48 × d (bit 6 de la phase, lue après l'avance) ± 12 × d, avec
d = l'avance du compteur d'animation du wick, qui est exactement le drop
du tour. 1 434 pas sur 1 434 conformes, 700 trames rendues.

Deux pièges rencontrés en chemin, corrigés avant la mesure : un `puls a`
qui restaurait la phase par-dessus l'octet haut du delta, et **`leax`
pose Z sur le 6809** (comme `leay` ; `leas`/`leau` non) — un test de bit
suivi d'un `leax` avant le branchement branchait toujours du même côté.
Le point de sondage par trame rendue est `RunObjects`, pas l'attente de
bascule : un rendu en retard saute l'attente et deux tours passaient
entre deux relevés.
