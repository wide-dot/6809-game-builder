# Modes graphiques : inventaire pour le 320×200 4 couleurs et le 320×200 16 couleurs à contraintes

Objectif : savoir ce qu'il faut changer, de la conception au programme de
test, pour que le moteur sache travailler dans deux modes de plus que le BM16 —
le 320×200 4 couleurs et le 320×200 16 couleurs « 2 couleurs par 8 pixels »
(mode 40 colonnes). Préalable à toute évaluation de portage (Bubble Bobble,
Ms. Pac-Man : 256 px de large à l'origine, qui tiennent en 320 mais pas en
160).

Méthode : lecture de la PR #46 (mode $26, fusionnée en `1be31e24c`) comme
gabarit, inventaire des hypothèses BM16 du moteur, de la chaîne d'outils et
des exemples, et vérification des faits matériels contre deux émulateurs
(toje `VideoModeDecoder`, MAME `thomson/to_video.cpp`). Rien n'a été modifié
dans le code. Une régression de la PR #46 a été constatée sous toje (§2.1).

## 1. Faits matériels établis

Les deux émulateurs concordent sur les trois points qui comptaient. Les skills
Thomson se contredisent sur le deuxième (le `SKILL.md` du skill vidéo décrit
`$41` comme un BM4 planaire à transcodage différent, `references/modes.md`
comme un 2 bits/pixel compacté) : c'est `modes.md` qui a raison.

| Mode | `$E7DC` | Pixels / octet | RAMA (`$C000`) | RAMB (`$A000`) | Couleurs |
|---|---|---|---|---|---|
| BM16 (actuel) | `$7B` | 2 | pixels 0-1 d'un groupe de 4 | pixels 2-3 | 16, entrées 0-15 |
| BM4 planaire | `$21` | 8 | bit de poids fort de l'index | bit de poids faible | 4, entrées 0-3 |
| BM4 « spécial » | `$41` | 4 | pixels 0-3 d'un groupe de 8 (bits 7-6 = le plus à gauche) | pixels 4-7 | 4, entrées 0-3 |
| 40 colonnes | `$00` | 8 | forme : 1 bit par pixel | attribut de l'octet de forme | 16, 2 par octet |

- **`$21`** : index = `RAMA<<1 | RAMB`, même adresse dans les deux plans (toje
  `deuxBitsParPixel`, MAME `c[rama][ramb]`). L'ordre de bits de
  `png2bin videomode="t1"` (bit fort vers le premier plan) est donc le bon.
- **`$41`** : TO8 / TO8D / TO9+ seulement (absent du TO9). Le transcodage
  `T=10` ne permute rien sur un index de 2 bits. **Même topologie d'octets que
  le BM16** : un couple (RAMA, RAMB) à une adresse couvre 8 pixels au lieu de
  4, RAMA d'abord. La galerie de toje l'étiquette « 160x200x4 » : c'est
  l'étiquette qui est fausse, le décodeur rend bien 320 px
  (`pixelsPerGpl($41) = 8`).
- **`$00`** : octet d'attribut `PpbvrBVR` à pastels inversés —
  forme = `((c>>3)&7) | ((~c&$40)>>3)`, fond = `(c&7) | ((~c&$80)>>4)` (toje
  `foreground`/`background` avec `t=0`). Les 16 entrées de palette TO8
  s'appliquent. Le « mode 32 » `$20` (quartets alignés) existe mais n'est pas
  documenté, et toje et MAME ne s'accordent pas sur son bit pastel : à écarter.

Partout : 40 octets par ligne et par plan, 200 lignes, double tampon par
`$E7DD`/`$E7E5` identique, palette de 16 mots `GR0B`. **gfxlock, WaitVBL, le
gestionnaire d'objets, la caméra, DisplaySprite, les listes de priorité,
BgBufferAlloc et les cellules de sauvegarde ne dépendent pas du mode.**

## 2. Ce que la PR #46 enseigne

### Le gabarit

La PR a suivi, dans l'ordre :

1. **Encodeurs gfxcomp** (`encoder/onebpp/` : `bdraw1`, `draw1`, `clear1`) +
   validation explicite à la construction (largeur ≤ 320, `shift=0`,
   `planes=pointer`, index 0/1) + `OneBppTest` (10 tests, assertions sur l'asm
   généré) + `CACHE_VERSION` relevé.
2. **Runtime** en pack séparé (`background-erase-mode-1bpp/`) : copies de
   `CheckSpritesRefresh` et `DrawSprites`, drapeau de construction
   `CLEAR1BPP` dans l'`EraseSprites` partagé, plan choisi par un octet du jeu
   (`display_plane,x`).
3. **Scroll** rendu sélectif par plan (`vscroll.planes`).
4. **Doc** (`sprites.md`).
5. **Programme de test** `examples/layers` : démo autonome, témoins en `$9C00`,
   mesures par points d'arrêt toje, film AVI sans perte, détecteur de
   morsures `tools/bites.py`, journal `PASSATION.md`.

Les choix qui se transposent tels quels : x en **colonne d'octet** (8 px) avec
une marge de 108, code **ancré sur l'octet de référence du canevas** (boîtes
exactes, `center_offset = 0`), pré-décalages au pixel faits **côté jeu** par 8
PNG et un échange d'`image_set` (aucune modification de l'index), bitmap de
cellules sales au lieu des listes O(n²).

### Les dettes à solder avant de s'appuyer dessus

| # | Défaut | Constat | Où |
|---|---|---|---|
| 1 | **Régression BM16 : `examples/vscroll` n'affiche plus ses tuiles** | Vu sous toje : l'image d'avant la PR montre les tuiles qui défilent ; après rebuild, écran noir à la même trame. La nouvelle table d'adresses suppose un tileset linéaire ; ceux de `png2bin -vst` ont leurs moitiés de 8 Ko permutées (`tiles.0.bin` : premier octet non nul à 8192) | `vscroll.macro.asm` `_vscroll.setTileNb` ; `VerticalScrollTile.java:51-76` |
| 2 | `gen_dungeon.py` ne remet pas `outb` à zéro entre les plans : relancé, il produirait un `tiles.1.bin` faux | lecture | `examples/layers/tools/gen_dungeon.py:142-156` |
| 3 | `bdraw1` et `draw1` ne sont utilisés par aucune config : jamais exécutés sur machine | lecture | `examples/layers/to8.config.xml` (seul `clear1`) |
| 4 | L'index range `x_size` et `x1_offset` sur un octet, alors que le 1bpp accepte 320 px : aucun contrôle | lecture | `ImageSet.java:378-388` |
| 5 | Conversion « coordonnées de jeu → écran » recopiée en pixels dans un espace en octets (latent, non utilisé par la démo) | lecture | `CheckSpritesRefresh.asm` 1bpp `:263-276` |
| 6 | Rebouclage x négatif valable sur une seule ligne (marge de 108) | lecture | `DrawSprites.asm` 1bpp `:181-184` |
| 7 | Doc décalée : `CLR` décrit alors que le code fait `STD` de zéros ; Handlers/XSD listent encore « draw, bdraw, rle, zx0 » ; commentaire `setBM4` « 160x200x4c » | lecture | `ClearGenerator.java:18-35`, `sprites.md`, `Handlers.java:233,241`, `gfxmode.macro.asm` |
| 8 | Non-régression BM16 côté Java non démontrée (le corpus n'a pas été rejoué) — probablement identique, seul `Image.java` a bougé | lecture | `ci/build-corpus.sh` |

Le défaut des morsures (passe unique de `CheckSpritesRefresh`) est corrigé
dans le pack 1bpp mais **existe toujours en BM16**. Les deux bugs de géométrie
cités par la passation (`rora`/`rorb`, `x1_offset` lu avec le mauvais Y)
n'existaient que dans le portage 1bpp.

## 3. Le raccourci du 4 couleurs : `$41` est un BM16 recodé

Conséquence directe de §1 : en `$41`, un quartet BM16 couvre **deux pixels de
2 bits**. Une image 320×h en 4 couleurs a **exactement la même
représentation mémoire** qu'une image BM16 160×h dont chaque « pixel » vaut
`4·gauche + droite` :

```
octet RAMA $41 : [p0 p0][p1 p1][p2 p2][p3 p3]
octet RAMA BM16: [  q0 = 4·p0+p1  ][  q1 = 4·p2+p3  ]
```

D'où une voie où **ni le runtime, ni les scrolls, ni les encodeurs ne
changent** :

- un **adaptateur PNG** convertit le 320×h 4 couleurs en 160×h 16 couleurs
  (index BM16 = `4a+b+1`, 0 restant transparent) ;
- toute la chaîne BM16 s'applique ensuite : `bdraw`/`draw`/`rle`/`zx0`, index,
  `CheckSpritesRefresh`, `DrawSprites`, `XYToAddress`, le pré-décalage
  `SHIFT_1` (qui devient un pas de 2 px), `png2bin bm16`, `Mscroll`,
  `leanscroll`, `HorizontalScroll`, les tuiles compilées ;
- l'unité x du moteur reste 0..159, en **pas de 2 pixels** — la même finesse
  physique qu'un pixel BM16, qui fait déjà 2 pixels d'écran de large. Les
  collisions AABB 8 bits et les tables de `terrainCollision` restent valides.

La contrainte unique de cette voie : **la transparence va par paires de
pixels** (un quartet est transparent ou non). Pour un bord transparent au
pixel près, il faut un masque de 2 bits (`$C0/$30/$0C/$03`) dans les encodeurs :
c'est la phase 2, et c'est là que l'inventaire Java a mesuré le gros morceau
(jeu parallèle de `Pattern*` dans `draw/` et `bdraw/`).

Les écarts restants sont des opérations du moteur qui **fabriquent** des
pixels au lieu de copier des octets :

- **`pixel-fade`** : il efface des quartets, donc 2 px à la fois — le fondu
  marche, avec un tramage 2× plus large ;
- **`loadbar`** : il calcule `c·$11`, donc une couleur répétée par quartet.
  En `$41` il faut `c·$55` ;
- **`hscroll`** : la couleur de garde est un mot de quartets (`png2bin -hsc`) ;
- **`ClearInterlacedDataMemory`** : ne remplit les deux plans avec le même mot
  qu'avec la couleur 0, comme en BM16.

**Statut : déduit, pas encore vu sur machine.** C'est le premier
travail à faire (§6, étape 1) : une expérience courte au résultat
binaire.

### Et `$21` ?

`$21` a l'avantage de tourner aussi sur TO9. En revanche il ne réutilise que
le modèle du pack 1bpp, étendu à deux plans : x en colonne d'octet, et un
nouvel encodeur à masque par bit qui écrit les deux plans à la même adresse
(`LEAU -$2000,U` entre les deux). Les quatre scrolls BM16 sont à réécrire
(granularité 8 px, plus de bascule RAMA/RAMB), et la pile complète des
encodeurs aussi (le masque d'octet a 256 états, pas 4). **Recommandation :
`$41`**, puisque le moteur cible déjà le TO8 et que le TO9 n'est pas une cible
à ce jour.

## 4. Le 40 colonnes : une décision de conception d'abord

Le 40 colonnes partage la géométrie du 1bpp (forme = un plan 1 bit, x en
colonne d'octet), avec un plan d'attributs en plus. Ce qu'un sprite fait de
l'attribut ne se déduit pas du code : c'est le choix qui conditionne tout le
reste.

| Modèle | Le sprite écrit | Coût | Rendu |
|---|---|---|---|
| **A. Forme seule** | RAMA (encre, éventuellement fond opaque) | Encodeurs 1bpp quasi tels quels (ajouter un état « fond opaque » : masque AND + OR) | Le sprite prend les couleurs du décor case par case ; aucun « clash » écrit, mais un sprite monochrome dont la teinte dépend de la case |
| **B. Attribut fixe par sprite** | RAMA + l'attribut entier de chaque octet touché | Contrôle à la construction (≤ 2 couleurs par case, **pour chaque décalage**) ; sauvegarde des deux plans | Clash à la ZX Spectrum autour du sprite |
| **B'. Attribut partiel** | RAMA + bits 6-3 de l'attribut (`ANDA #$87 / ORA #fg`) | Comme B, plus un paramètre de construction « garder le fond » | Le fond du décor est conservé, seul l'encre change |
| **C. Décor sur attributs, sprites en forme** | Comme A, mais les tuiles fixent les attributs par zone | Discipline d'auteur sur les tuiles | Style Thomson classique |

Pour Ms. Pac-Man et Bubble Bobble, les sprites portent plusieurs couleurs
sur 8 pixels : seul **B/B'** les rend, avec un clash visible. A/C conviennent à
des sprites monochromes. **À trancher par l'auteur avant tout code.**

## 5. Inventaire, couche par couche

Légende : ✓ = rien à faire, ◐ = adaptation, ✗ = à écrire.

### 5.1 Affichage et infrastructure

| Élément | `$41` | `$00` (40 col) | Référence |
|---|---|---|---|
| Macro de mode | ◐ ajouter `_gfxmode.setBM4S` (`$41`), corriger le commentaire de `setBM4` | ✓ `set40C` existe | `engine/system/thomson/graphics/mode/gfxmode.macro.asm` |
| gfxlock, WaitVBL, échange de pages | ✓ | ✓ | `engine/graphics/buffer/gfxlock*`, `engine/graphics/vbl/WaitVBL.asm` |
| Palette (routines 16 mots) | ✓ (4 entrées utiles) | ✓ | `engine/palette/PalUpdateNow*.asm` |
| `png2pal` | ◐ `colors="4"` ; vérifier sur toje que l'entrée 0 est bien la couleur d'index 0 | ✓ | `Png2PalPlugin.java` |
| Effacement d'écran | ✓ couleur 0 | ◐ deux valeurs (forme, attribut) : `gfxlock.memset` le fait déjà | `ClearInterlacedDataMemory.asm`, `gfxlock.memset.asm:19-44` |
| `pixel-fade` | ◐ fonctionne, tramage ×2 | ✗ effacer des quartets d'attribut change les couleurs des cases, pas les pixels | `engine/graphics/fade/pixel-fade.asm` |
| `loadbar` | ◐ `c·$55` | ✗ bits de forme + attribut | `engine/graphics/loadbar/loadbar.asm` |
| Texte / HUD | — aucun module moteur ; R-Type a son HUD BM16 et ses messages 40 col (`bm4.drawChunbks.asm`, mal nommé : c'est un peintre forme + attribut 40 colonnes) | ◐ ce dernier est une base | `games/r-type/src/common/hud/` |

### 5.2 Sprites

| Élément | `$41` (voie adaptateur) | `$00` | Référence |
|---|---|---|---|
| Équates d'écran (`screen_width 160`, marge 48) | ✓ | ◐ celles du 1bpp (colonne 108..147) ; elles sont **dupliquées** dans `constants.asm` et `glb.const.asm` | `engine/constants.asm:134-139`, `engine/global/glb.const.asm:64-69`, `onebpp.const.asm` |
| `DRS_XYToAddress` | ✓ | ◐ forme `$C000+40y+col`, attribut `$A000+40y+col` (même colonne, pas de bascule) | `DrawSpritesExtEnc.asm:176-205` / 1bpp `:180-200` |
| Choix du variant (parité) | ✓ (pas de 2 px) | ◐ comme le 1bpp : décalages au pixel par 8 PNG et échange d'`image_set` côté jeu | `CheckSpritesRefresh.asm:242-281` / 1bpp `:299-315` |
| Boîte X, comparaison de mouvement | ✓ | ◐ boîte en octets du 1bpp, comparaison exacte | BM16 `:314-353, 386-389` / 1bpp `:350-383, 408-410` |
| Effacement | ✓ sauvegarde | ◐ sauvegarde des deux plans (B/B'), ou variante « clear » qui **réécrit l'attribut** au lieu de zéro | `EraseSprites.asm` (`CLEAR1BPP` `:213-230, 310-323`) |
| Morsures (passe unique) | ◐ rétroporter la bitmap de cellules sales (seule `CSR_dirty.locate` dépend du mode) — utile au BM16 actuel aussi | ✓ reprise du 1bpp | 1bpp `CheckSpritesRefresh.asm:44-117, 488-606` |
| Pack overlay | ✓ | ✗ entièrement BM16 (`#160`, `suba #48`, x/4) | `engine/graphics/sprite/overlay-mode/BuildSprites.asm` |
| `_sprite.cull` | ✓ | ◐ unité colonne | `engine/macros.asm:238-255` |

**Recommandation de structure** (avant d'ajouter un troisième pack par
copie) : extraire un fichier « géométrie » choisi à l'inclusion —
`XYToAddress`, choix du variant, boîte X + `locate` — et garder un seul
squelette CheckSpritesRefresh/DrawSprites, celui du 1bpp (bitmap + liste
différée). Aujourd'hui 200 lignes sur 240 de DrawSprites et ~300 sur 440 de
CheckSpritesRefresh sont communes entre les deux packs : un troisième pack par
copie triplerait la maintenance des correctifs.

### 5.3 Chaîne d'outils

| Élément | `$41` | `$00` | Référence |
|---|---|---|---|
| Adaptateur 4 couleurs → BM16 recodé | ✗ petit (attribut de `<image>`, ou étape Java avant `prepareImages`) ; refuser une paire mi-transparente | — | `Image.java` |
| Encodeurs à masque 2 bits | ✗ phase 2 (bords transparents au pixel) | — | `draw/PatternFinder.java:33`, `draw/pattern/*`, `bdraw/pattern/*` |
| Encodeurs forme | — | ◐ `RowCode` 1bpp + état « fond opaque » | `encoder/onebpp/` |
| Encodeur attribut + contrôle de clash | — | ✗ (modèle B/B') : ≤ 2 couleurs par case et par décalage, transcodage `PpbvrBVR`, couleur de « papier » pour les cases partielles | nouveau |
| Index | ✓ | ◐ contrôle de plage `x_size` ≤ 255, `x1_offset` ∈ [-128, 127] (dette #4) | `ImageSet.java` |
| Attribut de mode | ◐ `videomode` sur `<gfxcomp>` plutôt qu'un statique : `VideoMemory` (`linearbits`…) est lu puis ignoré, vestige d'un générateur paramétré inachevé | idem | `GfxcompPlugin.java:55-59, 93-97`, `setting/VideoMemory.java` |
| `png2bin` | ✓ via `bm16` après adaptateur ; `t1s` existe mais **déborde son tampon** (constaté à la lecture, non exécuté : tampon `line·h/2` pour `line·h` octets) | ✗ `t0` plante (`% 0`) et ne produit pas d'attributs | `Png2Bin.java:116-117, 165, 210` |
| `leanscroll`, `Mscroll`, `HorizontalScroll`, `-vst` | ✓ via adaptateur (pas de 2 px) | ✗ regroupement par 8 px, attributs, 8 pré-décalages | `LeanScroll.java:62-67`, `Mscroll.java`, `HorizontalScroll.java` |
| Petits défauts croisés | NPE sur un nom d'encodeur inconnu (`Image.java:199`) ; `checkPixelRange` laisse passer les index ≥ 128 (`:294`) ; `bdraw` avale les exceptions (`AssemblyGenerator.java:196-200`) | | |

### 5.4 Scrolls

| Moteur | `$41` | `$00` |
|---|---|---|
| `vscroll` (plein écran vertical) | ✓ après dette #1 | ◐ tuiles 16 px : forme + 2 attributs par ligne de tuile, générateur à écrire |
| `hscroll` (bande bouclée) | ✓ (bascule RAMA/RAMB = pas de 4 px) | ✗ pas de 8 px minimum, les attributs suivent |
| `mscroll` (multidirectionnel) | ✓ | ✗ |
| `pscroll` (R-Type stage 4) | ✓ (décalage de quartet = 2 px) | ✗ réécriture |
| `horizontal-scroll` + `tilemap-patch` (terrain R-Type) | ✓ | ✗ 8 cartes pré-décalées au lieu de 2 |
| `terrainCollision` | ✓ | ✗ tables indexées par un x écran 8 bits sur 160 px |

## 6. Programme de travail proposé

**Étape 0 — solder la PR #46** : dette #1 (choisir : générateur linéaire, ou
table d'adresses sélectionnable) et re-valider `examples/vscroll` sous toje ;
dettes #2, #4, #7 ; rejouer `ci/build-corpus.sh` pour acter l'identité BM16.

**Étape 1 — preuve `$41`** : prendre `examples/sprites`, convertir
ses PNG par un script Python (320×h 4 couleurs → 160×h, index `4a+b+1`),
remplacer `setBM16` par un `$41` écrit à la main et la palette par 4 entrées,
rebuild, capture toje. Attendu : sprites nets à 320 de large, déplacements par
pas de 2 px, morsures identiques au BM16. Si l'image est bonne, la voie §3 est
acquise et le reste du 4 couleurs devient de l'outillage.

**Étape 2 — `$41` outillé** : macro `setBM4S`, adaptateur dans gfxcomp
(attribut de mode, refus des paires mi-transparentes, tests JUnit comparant
octet pour octet l'image recodée à une image BM16 équivalente), `loadbar` et
`pixel-fade` paramétrés, doc. Programme de test `examples/bm4` sur le
modèle de `layers` : sprites + `vscroll` (ou `mscroll`) à 320 px, témoins
`$9C00` (marqueur, sprites dessinés, compteur de trames, tête de la liste de
cellules libres, LSB de caméra), mesure de cycles par points d'arrêt, film AVI
+ `bites.py`.

**Étape 3 — `$41` au pixel près** (si l'étape 1 montre que le pas de 2 px
gêne) : masques de 2 bits dans `draw`/`bdraw`, deux pré-décalages de plus
(slots d'index 2-3, ou échange d'`image_set` côté jeu comme le 1bpp).

**Étape 4 — refactor géométrie des sprites** (§5.2) : un squelette, trois
fichiers géométrie (BM16/`$41`, 1bpp, 40 colonnes), bitmap de cellules sales
rétroportée au BM16. Prérequis raisonnable du 40 colonnes plutôt qu'un
troisième pack copié.

**Étape 5 — 40 colonnes** : après la décision §4. Encodeurs forme (+ attribut
et contrôle de clash pour B/B'), géométrie, effacement à attribut, convertisseur
de tuiles et `vscroll`, programme de test `examples/col40` sur le même modèle,
avec en plus un témoin de clash (VRAM attributs relue et comparée à
l'attendu).

Pour chaque étape, la règle de la PR #46 et du dépôt : JUnit sur l'asm généré,
corpus BM16 byte-identique, validation sous toje (témoins + film sans perte),
journal de passation dans l'exemple.

## 7. Points ouverts

1. Mode 4 couleurs : `$41` (recommandé, TO8+ seulement) ou `$21` (TO9 aussi,
   tout à réécrire) ?
2. Modèle de couleur des sprites en 40 colonnes (§4).
3. Le pas de 2 px suffit-il pour les jeux visés ? Bubble Bobble arcade a
   256 px utiles : en `$41` ils occupent 128 unités de 2 px, ce qui laisse de la
   marge latérale, mais les déplacements de 1 px de l'arcade seront arrondis.
4. Faut-il garder les deux packs sprites, ou faire d'abord le refactor de
   l'étape 4 ?
