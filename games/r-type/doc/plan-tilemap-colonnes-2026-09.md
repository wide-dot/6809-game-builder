# Plan — la tilemap en colonnes creuses (06/09/2026)

Objectif de l'auteur : gagner des cycles, et si possible de la place, sur
l'affichage de la tilemap. Idée : remplacer le parcours du rectangle écran
dans la carte dense (qui passe son temps à sauter les cases vides) par une
carte **en colonnes creuses** — une table d'entrées de colonnes, chaque
colonne listant ses seules cases pleines sous la forme (offset vidéo
précalculé, tuile). Le modèle actuel, son code moteur et ses plugins
restent : nouvelle routine moteur, nouveaux plugins de conversion.

## 1. Le profil du rendu actuel (stage 1, en jeu)

Outils : `tools/profile-stage.py` (toje, 100 trames à deux moments) et
`tools/symbolize-profile.py` (les listings du jeu). Relevé à l'ouverture du
stage 1 (caméra 68) : 34 boucles de jeu en 100 trames, **58 700 cycles par
boucle, trois trames**, 7 % d'attente. Par boucle :

| poste | cycles | part |
|---|---:|---:|
| blast d'effacement (`playfield.clearBlast`, 11-190) | 19 200 | 33 % |
| **`DrawTiles`** | **14 800** | **25 %** |
| masque du champ (`adr_playfield_mask_ND0`, chaque boucle) | 8 000 | 14 % |
| HUD | 2 200 | 4 % |
| objets, sprites, manette, divers | ~10 000 | 17 % |
| attente de la trame | 4 000 | 7 % |

Depuis le passage en overlay, `DrawTiles` est **forcé à chaque boucle**
(`stage-main` pose `glb_camera_move` avant l'appel) : le blast a effacé le
champ, toutes les cases visibles sont repeintes, caméra bougée ou non. Il
parcourt 13 colonnes × 15 lignes = 195 cases.

Ce qu'il fait de ses 14 800 cycles, lu dans le code et recoupé avec les
compteurs par PC :

| | par case | cases | cycles | part |
|---|---:|---:|---:|---:|
| **sauter une case vide** (`empty_tile_loop` : `leau 3,u`, `leax`, `deca`, `ldb ,u`, `beq`) | ~28 | ~150 | **~4 300** | 29 % |
| enveloppe d'une case pleine (dépiler page+adresse, monter la page, calculer la destination, `jsr`, remonter la page de la carte, compter) | ~60 | ~45 | ~2 700 | 18 % |
| la tuile compilée elle-même (stage 1 : 79 instructions et ~234 cycles en moyenne, 366 au plus) | ~234 | ~45 | ~7 300 | 49 % |
| boucle de colonnes, préambule | | | ~500 | 4 % |

Les cartes sont creuses : **10 à 37 % de cases pleines** selon le stage
(stage 1 : 21 %, stage 4 : 10 %). Près de la moitié du temps de `DrawTiles`
est donc de la marche à vide et de l'enveloppe, pas du dessin. C'est
exactement ce que le format en colonnes supprime.

## 2. Le format proposé

```
map.cols                            ; la table d'entrées : COLS mots
        fdb   col0, col1, …         ;   -> la liste de la colonne, dans la page de la carte
col0    fcb   page                  ; une case pleine : la page de la tuile (+$60)
        fdb   offset                ;   son offset vidéo précalculé (ligne × 480)
        fdb   adresse               ;   la routine compilée
        …
        fcb   0                     ; fin de colonne : la page 0 n'existe pas
```

Cinq octets par case pleine, un terminateur par colonne, deux octets par
colonne. La boucle de rendu par colonne devient : base vidéo de la colonne
dans D, puis pour chaque entrée `ldb ,x+` (page, 0 = fin), `stb $E7E6`,
`ldd ,x++` (offset) + base → `glb_screen_location_1` et U, `jsr [,x++]`,
remonter la page de la carte. **Aucune case vide n'est visitée.**

Variante à 4 octets : un octet de LIGNE (0..14) à la place de l'offset, et
une table résidente de 15 mots (`ldb ,x+` / `ldd row.table,b`). Même coût
en cycles à un cycle près, 20 % de carte en moins, et la routine ne dépend
plus de la hauteur de tuile. À trancher : l'auteur a demandé l'offset
précalculé, qui laisse la porte ouverte à des tuiles de hauteurs
différentes ; la variante ligne est la plus compacte.

Le `Scroll` actuel avance `scroll_map_pos` de 45 octets (15 × 3) par
colonne franchie ; le nouveau avance de 2 (l'entrée de colonne). Le reste de
`Scroll` (vitesse 8.8, plafond, parité pair/impair, collision terrain) ne
change pas : c'est la même routine avec un pas paramétré, ou une copie.

## 3. Faisabilité et coût mémoire

Mesuré sur les seize cartes (`gen/stages/*/map/{even,odd}.bin`, 15
lignes, id 0 = vide), format à 4 octets par case pleine :

| stage / plan | colonnes | pleines | dense (3 o/case) | colonnes | gain |
|---|---:|---:|---:|---:|---:|
| 01 pair / impair | 132 | 420 / 465 | 5 940 | 2 076 / 2 256 | 65 / 62 % |
| 02 | 96 | 494 / 505 | 4 320 | 2 264 / 2 308 | 48 / 47 % |
| 03 | 96 | 196 / 212 | 4 320 | 1 072 / 1 136 | 75 / 74 % |
| 04 | 96 | 140 / 147 | 4 320 | 848 / 876 | 80 % |
| 05 | 96 | 528 / 528 | 4 320 | 2 400 | 44 % |
| 06 | 96 | 295 / 311 | 4 320 | 1 468 / 1 532 | 66 / 65 % |
| 07 | 96 | 423 / 486 | 4 320 | 1 980 / 2 232 | 54 / 48 % |
| 08 | 62 | 306 | 2 790 | 1 410 | 49 % |
| **total** | | | **69 300** | **27 668** | **60 %** |

Avec l'offset sur deux octets (5 o/case) : 33 030, soit 52 % de moins. La
colonne la plus pleine du corpus a 15 cases (stage 8), aucune carte n'est
dense : le format ne perd nulle part. Le stage 1 rend 7,5 Ko sur sa page de
cartes ($1F), qui porte aussi ses tuiles impaires.

Cycles attendus par boucle, stage 1 (45 pleines, 150 vides) : les 4 300 du
saut disparaissent, l'enveloppe tombe de ~60 à ~38 par case (−1 000), la
boucle de colonnes reste. **`DrawTiles` : 14 800 → ~9 500**, −5 300 par
boucle (−9 % de la boucle). Ce n'est pas une marche de trame à lui seul (la
boucle est à 58 700 pour un budget de 60 000 sur trois trames, la marche
des deux est à 40 000) ; c'est un gain net, et une place gagnée partout.

À noter, hors périmètre mais vu au profil : le masque du champ coûte
8 000 cycles par boucle au stage 1, chaque boucle, plus que la moitié des
tuiles.

## 4. Les impacts

**Moteur.** Nouvelle routine `DrawTilesCols` (et un `Scroll` à pas
paramétré) dans un nouveau fichier de
`engine/graphics/tilemap/horizontal-scroll/` ; l'ancienne reste. Le stage
choisit par son init (`scroll_map_even/odd` pointent la table de colonnes).

**Builder.** Un nouvel élément, `<tilecols>` (même contrat que `<tilemap>` :
carte leanscroll `.bin`, `tiles`, `variant`, section `.static` cuite contre
le placement des tuiles, EXTERNAL générés), qui émet les tables de colonnes.
`<leanscroll>` et ses `.bin` ne changent pas.

**Les animations de décor — le point qui coûte.** `tilemap.patch`,
`tilemap.anim`, `tilemap.stamp` et `<tilereset>` réécrivent des cases de 3
octets dans la carte dense, par rectangles, colonne par colonne. Une case
animée peut passer de vide à pleine et inversement : une liste creuse ne
peut pas être réécrite en place. Solution retenue pour l'analyse : **les
colonnes qu'un rectangle animé touche sont émises DENSES** — leurs 15
lignes présentes, les cases vides pointant une tuile nulle résidente (un
`rts`). Une entrée y garde alors une adresse fixe, `colonne + ligne × 5`, et
`tilemap.patch` ne change que de pas (5 au lieu de 3) et de calcul d'entrée
de colonne (la table, plus `colonne × 45`). Le builder connaît ces
rectangles : `<tilepatch>` et `<tilereset>` sont déclarés dans le même
répertoire, `<tilecols>` peut en dériver la liste des colonnes denses sans
rien faire redéclarer. Coût : stage 2 seul est concerné aujourd'hui (engulf
2×2, blink, quatre tubes, trois rectangles de reset) — une dizaine de
colonnes denses, ~750 octets, et les tuiles nulles de ces colonnes coûtent
~50 cycles chacune quand elles sont à l'écran. Les stamps (le battleship du
stage 3) passent par les mêmes primitives : leurs rectangles sont à déclarer
de la même façon, à vérifier avec le portage du stage 3.

**Le rechargement de checkpoint.** `checkpoint.load` recalcule
`scroll_map_pos` comme position × hauteur × 3 (checkpoint.unit.asm ~278) :
à faire passer par le pas du modèle en vigueur.

**Non impactés.** La collision terrain (bitmap à part, `scroll_tile_pos`),
la couche battleship `mscroll` (ses propres cartes, tile-major) et la couche
gommes `pscroll` (ses propres tampons), `hscroll`. Les deux plans pair/impair
gardent leur mécanique (une table de colonnes par plan).

**Docs.** `tilemaps.md` : une section « colonnes creuses » ; le cas de
migration n'a pas lieu (rien de v1 ici).

## 5. Les étapes

1. **Le banc d'abord** : `examples/tilescroll` porte déjà la chaîne complète
   (leanscroll → gfxcomp grid → tilemap, tuile poison, diagonale, patch 2×2).
   Y ajouter `<tilecols>` et `DrawTilesCols` en alternative, sur les mêmes
   mires : le rendu doit être identique au pixel (checksums VRAM comparés
   entre les deux moteurs), patch compris via les colonnes denses.
2. **Stage 1** : basculer ses deux cartes, mesurer au profil (`DrawTiles`
   attendu vers 9 500), vérifier le checkpoint.
3. **Stage 2** : le seul à animations aujourd'hui — les colonnes denses
   dérivées des `<tilepatch>`/`<tilereset>`, gomander et engulf rejoués.
4. Les six autres stages, le banc r-type de l'auteur, puis la doc.

## 6. Risques

- Une case peinte par une tuile nulle coûte plus qu'un saut (50 contre 28
  cycles) : borner les colonnes denses aux rectangles déclarés, jamais plus.
- Le format met la page de la tuile dans chaque entrée : une colonne dont
  les tuiles alternent de page paie un montage par case, comme aujourd'hui.
  Trier les entrées d'une colonne par page ne coûterait rien au builder et
  rendrait un `cmpb`/`beq` possible — à mesurer, pas à présumer.
- L'offset précalculé suppose une hauteur de tuile fixe par carte ; c'est le
  cas partout (12 px).

## Journal

### 06/09/2026 — étape 1 close : le banc `examples/tilescroll`

- `scroll-columns.asm` (`tilemap.null`, `ScrollCols`, `DrawTilesCols`),
  `tilemap.patch.sparse` + `tilemap.mode`, plugin `<tilecols>` (dense=,
  nulltile=, rowstep=), `to8-cols.config.xml` = le même exemple sur le
  moteur colonnes. **101 captures sur 101 identiques au pixel** au moteur
  dense, sur tout le défilement initial (caméra 1 → 144), les deux plans et
  l'animation du patch comprise (colonnes 4-5 denses).
- Enveloppe par case ramenée à 71 cycles (dense : 78) : liste parcourue par
  `pulu`, haut de colonne / delta / page de carte en immédiats
  auto-modifiés, pointeur de liste dans un slot de pile. Sur la mire pleine
  (24 × 8, 104 cases visibles) : DrawTiles 42 209 cycles, DrawTilesCols
  42 138 — parité sans une seule case vide, donc chaque vide est un gain
  net (~28 cycles).
- **Bug builder trouvé en chemin** (LwObject.bakeStatic) : une référence
  interne restant DANS une section autre que la première (une table du
  `map` pointant ses propres lignes, comme `patch.tableEven` ou les
  pointeurs de colonnes de `<tilecols>`) était cuite avec la base de
  section comptée deux fois — `evalReloc` l'avait déjà repliée. Latent
  dans l'exemple committé (le patch lisait ses trames à `patch + taille du
  code`, sans dégât visible), fatal dès que le code grossit. Corpus avant/
  après : seules les deux images de tilescroll changent, les 87 autres sont
  identiques à l'octet — r-type n'y était pas exposé.
- Reste des étapes 2-4 inchangé ; la caméra du banc ne recule jamais
  (`Scroll` rend la main quand les deux tampons sont à la borne), les
  comparaisons se font donc depuis l'amorçage.

### 06/09/2026 (suite) — étape 2 : les huit stages sur le moteur colonnes

- Le moteur dense (`Scroll`/`DrawTiles`/`tilemap.patch.dense`, 476 o) n'est plus
  résident : `TILEMAP_DENSE_OFF` dans `src/common/engine/engine.asm` le laisse
  hors du binaire ; `scroll-map-buffered-even.asm` ne fournit plus que ses
  variables, `InitScroll` et les quatre pas auto-modifiés. `<tilecols>` remplace
  `<tilemap>` pour les 16 cartes ; chaque stage pose `stage.TILES_COLS`,
  stage-main appelle `ScrollCols`/`DrawTilesCols` et le checkpoint peint en
  colonnes. Le stage 2 déclare `dense="83-92"` (les rectangles animés engulf/
  blink/tubes/reset y tombent tous).
- **Deux bugs du moteur colonnes, trouvés par le stage 2 et corrigés :**
  1. `DrawTilesCols` montait la page de la tuile (`stb $E7E6`) AVANT de lire
     l'offset de la cellule, qui vit dans la page de la CARTE — l'offset
     revenait de la page tuile. Invisible dans `tilescroll` (carte et tuiles
     partageaient une page), fatal dès que les tuiles sont ailleurs. La page
     est désormais rangée puis remontée après lecture de l'offset (immédiat
     auto-modifié). `pulu d` écrasant B, la page devait de toute façon être
     sauvée avant.
  2. `tilemap.patch.sparse` calculait l'entrée de colonne par `lda col / asla /
     leay a,y` — `leay a,y` prend A pour un déplacement SIGNÉ 8 bits, donc une
     colonne ≥ 64 (col×2 ≥ 128) reculait Y avant la table. Le stage 2 patche à
     la colonne 84 : Y partait 88 octets trop bas, la restauration écrivait au
     hasard, la RAM et la pile étaient corrompues, le CPU s'enfuyait en VRAM.
     Corrigé en `ldb #2 / mul / leay d,y` (offset 16 bits).
- **Validation** : `examples/tilescroll` toujours identique au pixel (101/101,
  patch compris) ; `ci/toje-bench/rtype_bench.py` **7/7** — la chaîne réelle
  stages 1→2→3→4, avec la vague du stage 2 (C6) et le passage au stage 4 (C7).
  Stage 1 rendu à l'écran conforme au dense. Coût par appel mesuré sous toje à
  l'ouverture du stage 1 : DrawTiles dense ≈ 16 300–17 800 cycles, DrawTilesCols
  ≈ 11 400–13 300 — ~4 500 cycles/trame gagnés, davantage quand l'écran se vide.
  Corpus : seuls tilescroll, r-type et le banc ranking changent (moteur commun),
  les 87 autres images identiques à l'octet.
- Reste : `docs/lang/en/tilemaps.md` mentionne déjà le moteur ; profil complet
  in-game du stage 1 (boucle entière) et banc auteur à la demande.

### 06/09/2026 (suite) — le boss du stage 2 : une case vide n'est pas un zéro

Trouvé en filmant les stages 1 et 2 : au boss du stage 2, la masse centrale du
décor manquait, six colonnes sur dix. Log complet dans le recueil de session
(point d'arrêt sur `tilemap.patch`, colonnes relues en mémoire).

- **Ce que le log a écarté** : un seul rectangle est jamais posé au boss
  (`tube0`, colonne 85, plan pair), et le moteur DENSE donne exactement la même
  séquence — l'animation n'était pas la différence. La confrontation statique
  de l'assembleur généré au `.bin` source donne **0 désaccord sur 96 colonnes** :
  l'encodage `<tilecols>` n'était pas en cause non plus.
- **Le défaut** : relues en mémoire, les colonnes 84, 87, 88 et 91 s'arrêtaient
  à la ligne 6 et les colonnes 83 et 92 à la ligne 11 — exactement là où
  commencent `blink` (col 84, 8×9, ligne 6), `tube1` et `tube3` (ligne 11).
- **La cause** : dans la carte dense une case vide vaut page 0 et le moteur la
  saute ; dans une colonne creuse un zéro est **le terminateur de colonne**.
  `tilemap.patch.sparse` recopiait la case vide telle quelle et coupait la
  colonne, faisant disparaître tout ce qui était en dessous. Incompatibilité de
  convention entre le format des rectangles et celui des colonnes, pas une
  donnée fausse.
- **Le correctif** : une case vide garde la page de destination (le générateur
  en pose une valide dans chaque case d'une colonne dense) et reçoit
  `tilemap.null`. Après quoi les dix colonnes du boss listent leurs 15 cellules
  sur les deux plans et le décor redevient continu.
- Revalidé : tilescroll 101/101 au pixel, `rtype_bench` 7/7, corpus inchangé
  hors des trois projets qui embarquent le moteur.

**À retenir pour la suite** : tout ce qui ÉCRIT dans une carte en colonnes doit
traduire « case vide » en `tilemap.null`, jamais en page nulle. Cela vaut pour
`<tilepatch>`, `<tilereset>` et tout futur écrivain de carte.
