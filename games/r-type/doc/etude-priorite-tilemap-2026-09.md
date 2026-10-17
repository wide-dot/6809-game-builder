# Le décor devant ou derrière les sprites : ce que fait la borne, ce que fait la v2

Étude du 08/09/2026. Point de départ : la cascade de mort du Gomander
explose *sous* le corps du boss, parce que la v2 peint la tilemap après les
sprites. Question posée : faut-il inverser l'ordre pendant cette séquence,
ou couper le rendu des sprites en deux plans — sans surcoût au runtime.

## 1. Le modèle arcade (Irem M72, source MAME `irem/m72_v.cpp`)

Deux plans de tuiles 8×8 en VRAM, 64×64 cellules, 4 octets par cellule
(mot 0 = numéro de tuile + miroirs, mot 1 = attributs) :

- **plan avant** (« foreground », Video RAM 1 en `0xD0000`) — c'est le plan
  que `re.arcade.r-type` exporte en `levelN_f.png`, la source de nos
  `in.png` (« plan AVANT du niveau », `tools/arcade_to_in.py`) ; le Gomander
  y est blitté (`gomander_helper_blit_recipe`) ;
- **plan arrière** (« background », Video RAM 2 en `0xD8000`) — export
  `levelN_b.png` ; au stage 2 c'est la texture grise qui remplit tout le
  fond. La v2 ne le porte pas : le ciel transparent de la carte est noir.

**La priorité est par CELLULE**, dans les bits 6-7 du mot d'attributs
(`tileinfo.group = (attr & 0x00C0) >> 6`). MAME peint : les tuiles « basses »
des deux plans, puis les tuiles « hautes », puis les sprites *sous* les
pixels marqués hauts. Les masques du plan avant :

| groupe | bits 7-6 | ce qui passe devant les sprites |
|---|---|---|
| 0 | 00 | rien — la tuile est entièrement derrière |
| 1 | 01 | les pens 8-15 seulement |
| 2, 3 | 1x | toute la tuile (pens 1-15) |

Ce que R-Type fait de cette liberté, compté sur les exports
`levelN_f_cellmeta.bin` (2 octets par cellule, le second = l'attribut) :

| stage | cellules | groupe 2 (devant) | groupe 0 (derrière) |
|---|---|---|---|
| 1 | 15 840 | 100 % | — |
| 2 | 11 520 | 100 % | — |
| 3 | 11 520 | 100 % | — |
| 4 | 11 520 | 100 % | — |
| 5 | 11 520 | 100 % | — |
| 6 | 11 520 | 50 % | 50 % |
| 7 | 11 520 | 73 % | 27 % |
| 8 | 7 440 | 58 % | 42 % |

Le groupe 1 n'apparaît nulle part. **Sur les stages 1 à 5, tout le plan
avant est devant les sprites** : le vaisseau passe derrière les parois, le
serpent sort de derrière le corps du Gomander. Les stages 6 à 8 mêlent les
deux, cellule par cellule.

## 2. Le geste de la mort du Gomander

`_arm_death_sequence` (40:A4CD) contient une boucle annotée « VRAM palette
poke » : `AND word, 0x000F` sur 0x480 mots à partir de `D000:1C02`, pas 4.
Ce sont les **mots d'attributs** de 1 152 cellules du plan avant (18 rangées
de 64, à partir de la rangée 28 de la VRAM). L'`AND 0xF` garde la banque de
palette et **efface les bits 6-7** : ces cellules passent du groupe 2 au
groupe 0 — **derrière les sprites**. La cascade (sprites) explose alors
par-dessus le corps. La même boucle tourne au jalon 0x1760 de
`_combat_join`, le chemin du timeout (40:A44C) : la fin de niveau se joue
toujours décor derrière.

C'est exactement l'inversion de priorité proposée : la borne la fait, d'un
coup, sur toute la zone, au moment où le boss meurt.

## 3. Ce que fait la v2 aujourd'hui

`stage-main.asm` : `BuildSprites` puis `DrawTilesCols` — « le décor
par-dessus les sprites, ordre officiel depuis le 21/08/2026, sur TOUS les
stages ». C'est le groupe 2 partout : **juste pour les stages 1 à 5**, faux
pour la mort du Gomander (et le timeout), faux pour la moitié des cellules
des stages 6 à 8. Le stage 4 a déjà un « derrière » ad hoc : le champ de
gommes (`pscroll`) est peint en tête de trame, avant les sprites.

Le tilemap v2 est une table de colonnes creuses (`<tilecols>`, 5 octets par
cellule pleine : page, adresse, offset vidéo) ; `DrawTilesCols` = prologue
(page cartouche, position écran, compte de colonnes) puis une marche par
colonne visible. `BuildSprites` = prologue (bornes) puis huit rangs de 8 à 1.

## 4. Les solutions

### A. Un drapeau « décor derrière » — le geste arcade, coût nul — FAIT le 08/09/2026

Un octet résident (`tilemap.behind`, à côté de `glb_camera_move`). La boucle
le teste une fois par trame : levé, `DrawTilesCols` est appelé **avant**
`BuildSprites` ; baissé, après (l'ordre actuel). Un `tst` + un branchement,
et le code de dessin reste unique (une sous-routine `stage.frame.tiles`
appelée d'un des deux points).

Qui l'écrit : le Gomander à `ArmDeath` **et** à `Finish` (le timeout, comme
0x1760) ; l'init de stage le remet à zéro (checkpoint, stage suivant). Le
stage 1 ne s'en sert pas — le Dobkeratops est en sprites, pas en tuiles.

Ce que ça reproduit : les stages 1 à 5 tels que la borne (tout devant), et
leur fin (tout derrière). C'est la réponse au problème posé, et c'est la
seule chose à faire pour le stage 2.

### B. Deux listes par colonne — la priorité par cellule, pour les stages 6 à 8

L'attribut est déjà exporté (`levelN_f_cellmeta.bin`, bit 7 du second
octet). `<tilecols>` prendrait un masque par cellule (le format bitfield
des masques de collision, un bit par cellule 3×6, comme `--masque` de
`arcade_to_in.py`) et émettrait **deux tables de colonnes** : les cellules
« derrière » et les cellules « devant ». La boucle appelle `DrawTilesCols`
deux fois, avant et après `BuildSprites`, avec chacune des deux tables.

Coût runtime : un prologue de plus (~100 cycles) et un en-tête de colonne de
plus par colonne visible (8 colonnes, ~30 cycles chacune) — les cellules,
elles, sont dessinées une seule fois. Coût données : un mot de pointeur de
colonne et un terminateur de plus par colonne et par parité (~400 octets sur
une carte de 96 colonnes). Le drapeau A reste utile par-dessus : à la mort
du boss, tout passe « derrière » quelle que soit la liste.

À faire le jour où un stage 6-8 se porte ; rien ne le justifie sur 1-5.

### C. Couper `BuildSprites` par rang — rejeté

Peindre les tuiles entre deux rangs de sprites suppose que la priorité
soit une propriété des sprites. Sur la borne c'est une propriété des
**tuiles**, et devant une tuile de groupe 2 *tous* les sprites passent
derrière, l'explosion comme le vaisseau. Un tel découpage ne reproduirait
rien de l'arcade, et coûterait un second prologue de `BuildSprites` par
trame.

## 5. Hors périmètre

Le plan arrière (la texture grise du stage 2, les fonds des autres stages)
n'a pas de couche v2 : le noir du champ effacé tient lieu de fond. C'est le
seul écart visuel qui reste une fois A fait — il ne relève pas de la
priorité.

## 6. Sources

MAME `src/mame/irem/m72_v.cpp` (`m72_m81_get_tile_info`, `set_transmask`,
`screen_update`) et `m72.cpp` (carte mémoire `0xD0000`/`0xD8000`) ;
Ghidra `maincpu` 40:A4CD, 40:A44C, 40:E883 (`init_foreground_tilemap`),
40:EB20 ; exports `re.arcade.r-type/out/tiles/levelN_f_cellmeta.bin`,
`levelN_f.png`, `levelN_b.png` ; v2 `src/stages/stage-main.asm`,
`engine/graphics/tilemap/horizontal-scroll/scroll-columns.asm`,
`engine/graphics/sprite/overlay-mode/BuildSprites.asm`,
`tools/arcade_to_in.py`.

## 7. Réalisation de A (08/09/2026)

- `globals.tilesBehind` (+161 du bloc `globals`) ; la boucle de
  `stage-main.asm` le teste une fois par trame et appelle la sous-routine
  `stage.frame.tiles` avant ou après `BuildSprites` ; l'entrée de stage le
  remet à zéro.
- Le Gomander le lève à `ArmDeath` (a4ff) et à `Finish` (le timeout, a44c),
  le rend à son `Init` (checkpoint).
- Au passage : les globales +155 à +160 avaient été ajoutées sans agrandir
  le bloc réservé (taille $9B, donc +154 au plus) — elles vivaient dans le
  plancher de la pile, hors d'atteinte du pic mesuré (84). Le bloc passe à
  $A2 et la pile commence en $9E6D (131 octets).
- Vérifié sous toje : rtype_bench 7/7 ; sonde `tools/gomander_death_probe.py`
  identique au 1er passage (cascade +2, outslay 3 → 0, stage 3 atteint), et
  les captures montrent les explosions PAR-DESSUS le corps du boss.

## 8. La priorité par cellule, stage par stage (17/10/2026)

Relevé sur la ROM. L'attribut de chaque cellule est lu dans son
enregistrement de groupe de tuiles, avec le décodage de l'extracteur
BallField de re.arcade.r-type : au stage 6, ce décodage retrouve
`level6_f_cellmeta.bin` à 0 écart. Les cellules « pleines » sont celles qui
ont au moins un pixel opaque dans l'export du plan.

| stage | plan de la carte | devant (groupe 2) | derrière (groupe 0) |
|---|---|---|---|
| 1 à 5 | avant | toutes | — |
| 6 | avant | — | 1 842, toutes |
| 7 | avant | 1 970 (machinerie verte) | 1 240 (murs bleus des couloirs) |
| 8 | ARRIÈRE (le plan avant est vide) | 2 048 | 164 (le mur bleu du fond de la salle du noyau, les 8 dernières colonnes) |

La v2 peignait tout le décor après les sprites : c'était juste sur les
stages 1 à 5, faux sur tout le 6 (les tuyaux passaient par-dessus les Dops
et coupaient les Newts dans les captures de `tools/stage6_video.py`), et
faux sur les parties « derrière » des stages 7 et 8. Réalisé :

- **Stage 6** : `stage.TILES_BEHIND`. L'entrée du stage lève
  `globals.tilesBehind` (la solution A), et le décor passe sous les sprites
  du début à la fin. Coût nul.
- **Stages 7 et 8** : la solution B, par une autre voie que le §4. Le moteur
  est résident et n'a plus d'octet libre ; `DrawTilesCols` reste donc tel
  quel. `<tilecols behind=masque>` sort les cellules masquées dans une
  seconde table de même forme, `map.even.behind` / `map.odd.behind`.
  `stage.frame.tilesBack` (sous `stage.TILES_PRIO`) la donne à
  `DrawTilesCols` avant les sprites, à la place de la table de la parité
  courante. Coût estimé à ~350 cycles par trame, non mesuré ; ~600 octets
  de tables par stage.
- Les masques viennent de `tools/gen_tile_priority.py` (ROM + `in.png`, un
  octet par cellule de carte, `--check`). Une tuile TO8 de 12×12 couvre
  4×2 cellules arcade. Sur le plan pair, aucune ne mélange les deux
  priorités. Sur le plan impair, décalé d'un pixel, 10 (stage 7) et 12
  (stage 8) tuiles mélangent : ce sont des raccords d'un pixel de large,
  rangés à la majorité de leurs pixels. C'est le seul écart.
- La mort d'un boss (`globals.tilesBehind`) passe toujours par le §7 :
  table « derrière » puis table ordinaire, toutes deux avant les sprites.
