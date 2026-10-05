# Étude — mscroll1 : le scroll multidirectionnel en 1 bpp

> 2026-10-05 — demandée par l'auteur pour un clone de Sonic 2 en 1 bpp
> (dépôt privé `wide-dot/sonic-2-mono`, son étude fondatrice
> `docs/study-1bpp.md`). Décisions de l'auteur : mode `$24`, le scroll du
> stage 3 de R-Type (mscroll) sans entrelacement ni fond fixe, développé
> dans l'engine, pas horizontal de 8 px d'abord, puis mesure.
> Code : `engine/graphics/tilemap/mscroll1/`, démonstrateur
> `examples/mscroll1`.

## TL;DR

`mscroll1` est un fork de `mscroll` pour un seul plan 1 bpp. La forme du
buffer de code ne change pas : une ligne 1 bpp de 320 px fait 40 octets,
exactement une ligne du buffer BM16 (10 chunks `ldd #/ldx #/pshs d,x`), et
un bloc Mega Drive 16×16 en 1 bpp (2 octets × 16 lignes) a exactement la
forme d'une tuile BM16 8×16 d'un plan : un opérande par ligne de buffer.
Slots, coutures, cisaillement : tout se lit pareil, en blocs de 16 px.

Ce qui change : un seul plan (un buffer, un tileset, une passe de blast vers
RAMA), le pas horizontal (8 px, il n'y a pas d'échange RAMA/RAMB en 1 bpp),
des colonnes sur 16 bits, une carte à deux niveaux comme sur Mega Drive
(layout → chunk 128×128 → bloc 16×16), et l'initialisation par le feed (plus
de buffer de départ généré).

Validé **à l'octet** sous toje sur tout l'écran, les deux tampons :
312 × 199 px exacts, les deux masques de `mscroll1.mask` (l'octet de
recouvrement à droite, la ligne du haut — §5) noirs. 9 trajets scriptés (diagonales, demi-vitesse,
16 px/trame, 12 lignes/trame) et une marche aléatoire de 200 trajets.
Mesuré : **25 i/s caméra arrêtée** (blast ≈ 31 k cycles pour 200 lignes),
**15,6 i/s en diagonale** à 6 px + 3 lignes par trame 50 Hz.

En route, deux défauts du mécanisme de couture, hérités du mscroll BM16 tel
quel, trouvés et corrigés ici (§4). Le banc BM16 ne pouvait pas les voir :
sa carte fait 256 px, la caméra plafonne à x = 96 et ne franchit jamais la
couture de 160 px.

## 1. Ce qui se reprend tel quel

- Le buffer cyclique de code, son curseur, le feed de rangées
  (`updategfx` / `copyBitmap`) et son cache de rangées, le point de sortie
  patché, la compensation de frame-drop 8.8, le mode `camera.impulse`.
- Le ruban horizontal : entrée au chunk `h`, sortie décalée d'autant.
- Le feed de colonne cadencé sur les bords masqués : à droite la colonne
  `edge+18` entre sous le masque droit, à gauche `edge-1` sous le masque
  gauche. `edge = (x+16)>>4`.
- Le format tile-major (16 mots consécutifs par bloc, ids prémultipliés
  par 32), la LUT de lignes `$A000 + ligne*2`.

## 2. Ce qui change

| | mscroll (BM16) | mscroll1 (1 bpp) |
|---|---|---|
| plans | 2 (RAMA + RAMB), deux passes | 1 (RAMA), une passe |
| slot | colonne de tuile 8×16 d'un plan | colonne de bloc 16×16 |
| décomposition | `x = 16h + 4bo + 2w` | `x = 32h + 8bo + r`, `r` (0-7) non rendu |
| pas horizontal | 2 px | **8 px** (la caméra rendue = `x` arrondi par défaut) |
| colonnes | octet (carte ≤ 2048 px) | mot (`divmod20` : slot = c mod 20, couture = c / 20) |
| carte | plate, ids 16 bits, stride puissance de 2 | **deux niveaux** : layout d'octets (stride ≤ 255) + table de chunks (128 o/chunk) |
| départ | buffer généré par le builder (`<mscroll output="start">`) | squelette + `mscroll1.init` (20 colonnes alimentées) |
| masques | 8 px de chaque bord | `mscroll1.mask` : l'octet 39 de chaque ligne (8 px) et la ligne du haut (§5) |

Le sous-octet n'existe pas en 1 bpp sur un plan : un octet couvre 8 px et
rien ne s'échange. Des pas de 4, 2 ou 1 px demanderaient 2, 4 ou 8 buffers de
phase pré-décalés (une page chacun) et multiplieraient d'autant le feed de
colonne, dont chaque octet mêlerait deux blocs. Décision : 8 px d'abord, puis
mesure.

La carte à deux niveaux : la tranche de rangée (`updateTileCache`) traverse au
plus 4 chunks, une recherche de layout par chunk traversé, puis des runs de
mots consécutifs ; la collecte d'une colonne (`feedTile`) traverse au plus 3
chunks, avec un pas de 16 octets dans un chunk. Layout et chunks dans une même
page, montée en espace cartouche.

## 3. Formats

- **Tileset** : blocs 16×16 tile-major, 32 octets par bloc (16 mots
  big-endian, bit 7 du premier octet = pixel le plus à gauche), ≤ 512 blocs,
  une page lue par la fenêtre data à `$A000 + id`. La fenêtre data présente
  les moitiés de 8 Ko d'une page inversées : un tileset de 8 Ko ou moins se
  charge à l'offset `$2000` de sa page ; au-delà, il faut écrire les moitiés
  permutées.
- **Carte** : le layout (un index de chunk par octet, rangées de
  `LAYOUT_STRIDE` octets), puis à `CHUNKS_OFFSET` la table de chunks
  (128 octets par chunk : 8 rangées de 8 ids, mots big-endian prémultipliés
  par 32). Hauteur multiple de 128, ≤ 3968 px ; largeur ≤ 32 K px.
- **Buffer** : `BUFFER_LINES` lignes de squelette (macros
  `_mscroll1.buffer.*`) et le `jmp` de bouclage.

Le démonstrateur génère tout (`tools/gen_mire.py`) : une mire de
8192×1024 px, 256 blocs distincts (règle horizontale sur la ligne 0, règle
pointillée sur la colonne 0, hachure à 45° de période 16, l'id du bloc en
8 bits au centre), 32 chunks pseudo-aléatoires, un layout de 64×8.

## 4. Les deux défauts de couture

### 4.1 Le biais du curseur : quand et dans quel sens

Le ruban fait qu'un slot d'une ligne de buffer peut tomber sur la ligne
d'écran suivante. En comptant les octets poussés depuis la fin de bande, le
slot `p` de la ligne de buffer `C+m` tombe à la colonne d'octet `2p + 4h + D`
(D = −bo) de la ligne d'écran `H−1−m`, plus une **retenue** quand ce nombre
dépasse 40. Comme `4h + D + xr/8 = 4(h+w)` et `h + w = 10·ceil(w/10)`
(`w` la fenêtre de 32 px), la retenue d'une colonne visible vaut :

    retenue(c) = ceil(w/10) − couture(c)        couture(c) = c / 20

Une colonne alimentée avec le biais de curseur `B_f` et un décalage `F_f`
(sa rangée de départ est `y − couture(c) + F_f`), puis affichée avec le biais
`B_d`, montre la rangée :

    y + s + 1 + B_f + F_f − B_d − ceil(w_d/10)

Ce que fait le mscroll BM16 : `F = 0` (cisaillement absolu), `B = +stretch`
avec `stretch = floor(x/largeur de couture)`. La rangée affichée vaut alors
`y + s + 1 + k_f − k_d − ceil(w_d/10)` : juste dans la première bande
(`ceil = 1`, `k = 0`), fausse d'une ligne par couture au-delà. Mesuré en
1 bpp avant correction : après la couture de 320 px, −1 sur tout l'écran,
puis −2 pour le contenu ancien une fois `w` passé à 11, 0 pour la seule
colonne alimentée après le franchissement — la formule prédit exactement ces
trois valeurs.

Le schéma juste, avec `S = ceil(w/10)` :

- le curseur porte **`−S`** (il recule d'une ligne quand `w` passe de `10k`
  à `10k+1`, soit à `x = 320k + 16`, pas à `x = 320k`) ;
- les feeds cisaillent **relativement à la caméra** : `couture(c) − S + 1`,
  0 pour les colonnes de la caméra, 1 pour celles au-delà de la couture
  suivante (les slots `0..seam.slots−1`, cuits à `id×32−2` dans le cache) ;
- le feed de rangées ne retranche plus rien (les colonnes de la caméra ne
  sont pas cisaillées).

La rangée affichée vaut alors `y + s` pour tout contenu, quel que soit le
moment où il a été écrit.

### 4.2 La rangée que personne n'alimente

Le buffer tient `BUFFER_LINES` = H+1 rangées. Déplacer le biais fait glisser
d'une rangée l'ensemble couvert, pour toutes les colonnes : une ligne de
buffer se retrouve appariée à une rangée jamais écrite. `S` monte (curseur
−1) : la ligne `cursor` doit porter `y + BUFFER_LINES − 1`, la rangée cachée
du bas, révélée au premier pas vers le bas. `S` descend (curseur +1) : la
ligne `cursor − 1` doit porter `y`, la ligne visible du haut.
`mscroll1.feedLine` la réécrit à chaque changement de `S`, par la même
mécanique que le feed de rangées (cache, cuisson, retouche de couture) :
un feed de rangée par couture franchie.

### 4.3 Et le BM16 ?

Les deux défauts sont dans la logique commune. Le mscroll BM16 (et donc la
couche cuirassé du stage 3 de R-Type) les porte probablement : un
franchissement de couture de 160 px y donnerait un décalage d'une ligne. **Non
vérifié ici** : `examples/mscroll/tools/diag_check.py` ne franchit jamais de
couture (carte de 256 px), et il échoue aujourd'hui dès la caméra x = 0
(7 764 cellules sur 8 000, rejoué le 05/10/2026 sur `master`), donc pour une
autre raison. À trancher avec l'auteur avant de toucher au BM16.

## 5. Validation et masques

Relevé sur tout l'écran (EHZ, 40 trajets aléatoires et un balayage fin
de x), les octets faux tombent dans **deux zones, et deux seulement** :

- **le recouvrement, à cheval sur le retour de ligne** : quand
  x mod 16 ≥ 8, la fenêtre couvre 21 colonnes de blocs pour 20 slots ; un
  slot est montré aux deux bords. Dans le flux, ses deux octets se
  suivent : l'octet de gauche ferme la ligne d'écran n (octet 39), l'octet
  de droite ouvre la ligne n+1 (octet 0). Le slot tient la colonne
  `edge-1`, celle de gauche : l'octet 0 est juste, l'octet 39 montre la
  mauvaise colonne (il faudrait celle 320 px plus loin). Quand
  x mod 16 < 8, le retour de ligne tombe entre deux slots, rien n'est faux.
- **le trou du début du ruban** : le décalage d'octet de S (`D = −bo`)
  laisse les `D` premiers octets de la bande non écrits (D = 1 ou 2,
  x mod 32 dans 16..31) : octets 0-1 de la ligne du haut, restes du blast
  précédent dans ce tampon. À l'autre bout, D = −1 laisse l'octet 39 de la
  dernière ligne (déjà dans le masque de droite).

`mscroll1.mask` (après `mscroll1.do` et ce que le jeu dessine dans la
bande) noircit l'**octet 39 de chaque ligne** (une bande de 8 px, à
droite) et la **ligne du haut de la bande** (la zone tampon du ruban,
comme la ligne trash du stage 3 de R-Type, cachée là sous le HUD) :
reste une image de 312 × (hauteur − 1) px, exacte. ≈ 1,7 k cycles pour
200 lignes, sans effet mesurable sur la cadence (25,0 i/s à l'arrêt).
Le blast déborde aussi HORS de la bande, de 2 octets au plus (l'octet 39
de la ligne au-dessus si D = −1, les octets 0-1 de la ligne au-dessous si
D = 2) : invisibles avec une bande en ligne 0 (`$BFFF`, zone RAMB) qui
finit en ligne 199 (au-delà des 8000 octets affichés), à couvrir par le
jeu ailleurs.

- `tools/check.py dist/to8.fd` : 9 trajets scriptés, les **deux tampons**
  relus en tête de boucle principale (ailleurs le tampon arrière peut être
  à moitié dessiné, blasté mais pas encore masqué) et comparés au modèle
  `pixel(xr + p, y + s)` calculé par `gen_mire.py` : masques noirs, le
  reste exact partout. La sonde rend la fenêtre data à sa page d'origine
  après lecture : le jeu est arrêté n'importe où dans sa trame.
- `--random 80` : marche aléatoire graînée, vitesses jusqu'à 16 px et
  12 lignes par trame dans les deux sens, coutures franchies dans les deux
  sens, bouclage vertical, butées : exact.

## 6. Mesures (toje, 05/10/2026, sans sprite ni logique de jeu)

`tools/fps.py` et `tools/profile.py`.

| Caméra (par trame 50 Hz) | Cadence |
|---|---|
| arrêtée | 25,0 i/s |
| x 1 px | 23,4 i/s |
| x 4 px | 18,7 i/s |
| x 8 px | 16,7 i/s |
| y 2 lignes | 25,0 i/s |
| y 6 lignes | 16,6 i/s |
| diagonale 6 px / 3 lignes | 16,1 i/s |

Profil en diagonale 6/3 (15,6 i/s, ≈ 64 k cycles par trame rendue) : blast
≈ 31 k (≈ 155 cycles par ligne, comme prévu), feed de colonne ≈ 9,7 k par
colonne de 201 lignes (≈ 48 cycles par ligne), feed de rangées ≈ 12 k par
trame dont **5,5 k dans `updateTileCache`** (la carte à deux niveaux, et
deux tranches rechargées après chaque feed de colonne), attente gfxlock
≈ 7 k.

Pistes d'optimisation, dans l'ordre du gain attendu :

1. **Hauteur de fenêtre** : le blast est linéaire en lignes.
2. **`updateTileCache`** : ne charger la rangée du dessus que pour les
   `seam.slots` slots cuits (la seule chose que la retouche lit), et faire
   les runs sans incrémenter la colonne à chaque id.
3. Le feed de colonne à 48 cycles par ligne contre 37 en BM16.

## 7. Suite

- Côté jeu (`sonic-2-mono`) : générer EHZ dans ces formats depuis
  s2disasm (393 blocs 1 bpp distincts pour l'acte 1, une page ; 114 chunks),
  et piloter la caméra par la trajectoire de la démo EHZ pour mesurer aux
  vraies vitesses de Sonic.
- Côté engine : les sprites 1 bpp opaques (masque + encre), dessinés sans
  effacement puisque le blast repeint tout (à dessiner AVANT
  `mscroll1.mask`) ; un manuel `docs/lang/en/mscroll1.md` une fois l'API stabilisée.
