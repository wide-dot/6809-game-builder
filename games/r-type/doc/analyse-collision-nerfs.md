# Effacer la collision des nerfs optiques du Dobkeratops — analyse (02/09/2026)

Demande : comme sur l'arcade, retirer les bits de collision d'un œil et de son
nerf dès que son animation de disparition commence, indépendamment pour les
quatre systèmes. Analyse avant toute implémentation.

## 1. Ce que fait l'arcade

Chaque nerf est un objet (`run_dobkeratops_optical_nerves`). À sa mort il
appelle `probe_foreground_tile` pour obtenir l'adresse VRAM de la cellule
sous l'œil, puis bascule sur `dobkeratops_erase_optical_nerves`, qui parcourt
**une table de décalages par nerf** (`0x146CC`, `0x14754`, `0x147C6`,
`0x1482E`) : à chaque pas (un pas sur deux trames) il écrit la tuile vide
`0x0FA0` dans la cellule courante, puis avance de `(dx, dy)` — `dx` en
octets sur l'adresse basse, `dy` en lignes sur l'adresse haute. Sur l'arcade
les nerfs et les yeux **sont des tuiles de l'avant-plan** : effacer la tuile
retire d'un coup le dessin et la solidité. Le marqueur `0x8000` clôt la
table et décrémente le compte de nerfs vivants du parent.

Disposition de la VRAM (`probe_foreground_tile`) : une cellule de 8×8 px fait
**4 octets**, une ligne 64 cellules soit 256 octets, lignes de haut en bas.
Donc `dx/4` cellules, `dy` lignes.

## 2. Ce que nous avons

Les deux cartes de collision du stage 1 sont l'extraction arcade de la v1
(`level1_fc.png` / `level1_bc.png`), un bit par tuile de **3×6 px**, 66
octets par ligne, 30 lignes — et **la grille arcade de 8×8 coïncide avec la
nôtre colonne pour colonne et ligne pour ligne** (4224/8 = 1584/3 = 528,
240/8 = 180/6 = 30).

| Carte | Contenu | Mobile ? |
|---|---|---|
| fond, `level1_bc.bin` | le corps seul (le croissant, px 1476–1535, lignes 2–27) | oui : `bgByteOff`/`bgBitShift` décalent la lecture quand le boss avance |
| avant-plan, `level1_fc.bin` | plafond, sol, stalactites, **les quatre nerfs avec leurs yeux**, et le bloc des alvéoles à droite (px 1518–1583, lignes 6–23) | non |

Même répartition que l'arcade. Les nerfs sont donc **déjà solides chez nous**,
dans la carte d'avant-plan, à des positions absolues et fixes — et rien ne les
efface jamais : c'est ce qui manque.

Deux faits qui pèsent sur la solution :

- **La carte n'est pas rechargée au rejeu de checkpoint** ni au restart
  après GAME OVER (`checkpoint.reload` ne remet que les listes AABB à zéro).
  Un effacement doit donc être **réversible** quand le boss réapparaît.
- **La carte vit sur la page `collision` ($17)**, montée par la fenêtre
  cartouche, tandis qu'`eyemgr` s'exécute depuis sa propre page cartouche :
  il ne peut pas monter la carte sans se faire disparaître. L'écriture passe
  par du **code résident** — l'idiome du trampoline d'`eyemgr-res`.

## 3. Les tuiles de chaque nerf, tirées des tables arcade

Les quatre tables décodées (dx/4, dy) ont été projetées sur notre carte
d'avant-plan en cherchant, autour de chaque œil, le départ qui les fait
coïncider. Résultat sans ambiguïté : **chaque table tombe entièrement sur des
tuiles solides**, aucune dans les murs, aucun recouvrement entre nerfs, et ce
qui reste solide est exactement le plafond, le sol et le bloc des alvéoles.

| Nerf | Pas | Tuiles | Départ (col, ligne) | Étendue | Octets de carte | Bits |
|---|---|---|---|---|---|---|
| 0 | 67 | 62 | (488, 4) | cols 488–511, lignes 2–5 | 12 | 62 |
| 1 | 56 | 42 | (499, 12) | cols 499–511, lignes 8–15 | 12 | 42 |
| 2 | 51 | 40 | (499, 18) | cols 499–511, lignes 18–22 | 10 | 40 |
| 3 | 61 | 58 | (488, 24) | cols 488–511, lignes 24–27 | 12 | 58 |

```
cols 470..527 : chiffre = nerf, '#' = solide hors nerfs (murs, alveoles)
 2 |###.....................00.00000000000....###############.|
 3 |###..................00000000000000.000000#############...|
 4 |###...............000000...00000000..00000############....|
 5 |###...............000.........00000..00...############....|
 8 |.........................................1##############..|
 9 |....................................111111##############..|
10 |....................................111111##############..|
11 |....................................1111...#############..|
12 |.............................1111...111...................|
13 |.............................111...11.....................|
14 |..............................1111111.....................|
15 |..............................111111......................|
18 |.............................2222.....2222.#############..|
19 |.............................22222..222222##############..|
20 |................................2222222.22##############..|
21 |................................2222...222##############..|
22 |................................22.....222##############..|
24 |###...............33.......3333333333.....############....|
25 |###...............3333...3333.333333333.33############....|
26 |###.................3333333....333.3.33333#############...|
27 |###...................33333.....3333..33..###############.|
```

Les départs sont à 2–3 tuiles de nos positions d'yeux (`EMOffsets`), ce qui
est cohérent : l'arcade ancre sur la cellule sous le centre de l'œil, nos
offsets sont ceux de l'explosion.

## 4. Le format à stocker — proposition

Par nerf, la liste des **octets de carte touchés** avec, pour chacun, le
**masque des bits du nerf** dans cet octet :

```
nerve.clear.N        fcb   n                 ; nombre d'entrees
                     fdb   offset, fcb masque ; x n  (offset dans level1_fc.bin)
```

46 octets touchés en tout → **138 octets de tables**, plus quatre comptes.

Pourquoi le masque plutôt que l'octet résultant, contrairement à l'idée de
départ : les bits du nerf sont exactement ceux qu'on retire, donc **un seul
masque fait les deux gestes** — effacer par `ET NON`, restaurer par `OU` — et
la restauration au rejeu de checkpoint ne coûte rien de plus. Stocker
l'octet résultant obligerait à stocker aussi l'octet d'origine (le double),
ou à recharger la carte. Le coût des masques : deux instructions par entrée,
une cinquantaine de fois par nerf, une fois par nerf — négligeable.

**Où vivent les tables** : dans l'unité de collision du stage 1
(`src/stages/01/collision/`), donc **sur la même page que la carte** : le
code résident monte une page, lit la table et écrit la carte sans en changer.
Générées par un outil commité (`tools/gen_nerve_collision.py`) qui refait la
projection ci-dessus à partir de `level1_fc.bin` et des quatre tables arcade
transcrites — pas de valeurs à la main, et le jour où la carte change, les
tables suivent.

## 5. L'algorithme

- **Trampoline résident** `main.eyemgr.collision` dans `eyemgr-res`
  (B = numéro de nerf, A = 0 effacer / 1 restaurer) : sauve la page
  cartouche, monte `stage1.collision.page`, parcourt la table du nerf et
  applique `ET NON` ou `OU` sur chaque octet, restaure la page. Une trentaine
  d'octets résidents, l'arène `stage1.res` en a.
- **Effacement** : dans `Kill` d'`eyemgr`, au moment où le statut passe à 1
  — c'est le début de l'animation, comme demandé. Pas de synchronisation
  avec les morceaux qui tombent.
- **Restauration** : dans `Init` d'`eyemgr`, qui remet déjà tout à neuf à
  chaque apparition du boss (spawn, rejeu de checkpoint, restart) : les
  quatre nerfs sont restaurés, idempotent grâce au `OU`.
- **Rien à faire à la fin de l'animation** ni côté `ForceAll` (les morts
  forcées passent aussi par `Kill`).

Le décalage du boss (`bgByteOff`) ne concerne que la carte de fond : sans
objet ici.

## 6. Validation prévue

- Sonde toje au boss : lire les 46 octets avant, après `Kill` du nerf 0 (les
  bits du nerf 0 seuls à zéro, les autres intacts), après les quatre, puis
  après un rejeu de checkpoint (tous restaurés, carte identique à l'octet).
- Sonde de jeu : le vaisseau (ou un tir) traverse l'emplacement d'un nerf
  détruit, bute toujours sur les alvéoles et les murs.
- `rtype_bench` 7/7.

## 7. À confirmer avant de coder

1. Le masque (ET/OU) plutôt que l'octet résultant, pour la restauration —
   ou bien préfères-tu stocker les deux octets ?
2. Les tables dans l'unité de collision (même page que la carte), générées
   par un outil commité.
3. L'effacement au `Kill` (début de l'animation), la restauration à l'`Init`.

## 8. Réalisé (03/09/2026)

- `tools/gen_nerve_collision.py` rejoue les quatre tables arcade sur
  `level1_fc.bin` et écrit `src/stages/01/collision/nerve-collision.tables.asm`
  (46 entrées offset + masque, 138 octets, sur la page de la carte).
- `main.eyemgr.collision` (eyemgr-res, résident) : B = nerf, A = 0 efface
  par ET NON, sinon restaure par OU ; monte la page de la région `collision`
  (`collision.page`, équate du layout) et rend celle de l'appelant.
- `Kill` d'`eyemgr` efface au passage du statut à 1 ; `Init` restaure les
  quatre (rejeu de checkpoint, restart).

Deux pièges, tous deux trouvés à la sonde :

1. **Un symbole exporté par deux unités alternatives d'une même région fait
   dérailler le loader.** `collisionMapForeground` est exporté par les
   unités de collision des stages 1 et 4 (région `collision`) ; référencé
   depuis le résident, il restait « lié au chargement, plusieurs
   fournisseurs », et `linkData.symbol.search` bouclait sur une link data
   hors du pool au chargement du stage 1 (écran LOADING figé). Nommer le
   symbole par stage (`stage1.collisionMap`) : un seul fournisseur, le
   builder cuit la référence, plus aucune link data. À creuser côté loader.
2. **Un trampoline résident appelé par un objet doit rendre U** — c'est
   son pointeur d'OST. La première version l'écrasait : `inc routine,u` de
   l'`Init` écrivait dans le vide, l'objet restait en `Init` à chaque trame,
   les yeux ne s'armaient jamais — et `rtype_bench` passait quand même, le
   boss mourant par le timeout d'échappée.

Vérifié sous toje, à vitesse normale sur l'horloge de jeu : 202 bits de
nerfs au départ ; boîtes armées à `gameCount` 7601 ; impact forcé sur le
nerf 0 → `Kill` → 140 bits, ses 12 octets exactement à l'attendu ; timeout
de vie libre → les trois autres → 0 bit, chacun exact. Restauration par appel
direct du trampoline nerf par nerf : 62, 104, 144, 202, chaque état égal à
l'origine. `rtype_bench` 7/7.
