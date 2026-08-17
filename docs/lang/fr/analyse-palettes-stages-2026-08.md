# Palettes dédiées des stages 2-8 — étude (17/08/2026)

Demande de l'auteur : créer les fichiers de palette dédiés aux stages 2-8, et
refaire la conversion depuis les plans arcade avec la réduction habituelle, en
optimisant les couleurs contre la **nouvelle** palette (12 communs + 4 index de
stage), vert des lots compris.

Tout ce qui suit est **mesuré** sur les `in.png` du dépôt et le config ; les
seules choses non mesurables ici sont marquées comme telles (le dépôt
d'extraction arcade n'est pas dans cet environnement de travail).

## 1. D'où on part

Les stages 2-8 n'ont **pas** de fichier de palette : leur `Pal_stage` sort de
`png2pal` sur `gen/stages/NN/map/even.png`, c'est-à-dire de la palette héritée
de leur `in.png`. Et ces `in.png` datent du monde d'avant : ils réaffectent des
emplacements **communs** (4, 6, 14, 15 matériels) à des teintes propres au
niveau — c'est exactement le défaut que `palette_usage.py` signale depuis le
15/08 (« GELÉ, VARIE → DÉFAUT » sur 7 index).

Relevé des teintes propres par stage (les autres index portent les couleurs
communes de l'ancienne palette, dont l'orange `F2AB00` et l'olive en 12) :

| stage | teintes propres (px) | + olive dans la carte | px opaques |
|---|---|---|---|
| 2 | `CCCCB8` 4395 · `B8A068` 8425 | 3337 | 207 360 |
| 3 | `CCCCB8` 1134 · `889060` 2338 · `A8B890` 3778 · `304020` 5028 | 332 | 207 360 |
| 4 | `CCCCB8` 1519 · `71C062` 12 678 · `207040` 17 088 | — | 207 360 |
| 5 | `F8C071` 7968 · `D09030` 4872 | 6576 | 207 360 |
| 6 | `CCCCB8` 5471 · `006060` 4109 · `003030` 1331 · `90A888` 5782 | — | 207 360 |
| 7 | `CCCCB8` 1845 · `68C8A0` 28 277 · `A84200` 2747 | 7004 | 207 360 |
| 8 | `CCCCB8` 179 · `B8A068` 1493 | 5819 | 133 920 |

`CCCCB8` revient partout : c'est le beige clair **des stages 2-8**, légèrement
différent du `CCC2AB` du stage 1. Deux stages seulement utilisent encore le
beige foncé `9E8F7A` dans leur carte au-delà du stage 4 (5 et 8).

## 2. Les contraintes de la nouvelle palette

* **Communs 0-11 gelés** : `000000 616161 A8A8A8 FAFAF2 00618F 009ECC 08D4EB
  610000 AC0000 CC5A3C F99B68 FAF261`. L'orange `F2AB00` n'existe plus — il
  devient le saumon `F99B68` (règle actée au groupe B). Les cartes 3, 6, 7 et 8
  en portent (289, 94, 474 et **4115** px) : seul le stage 8 en a assez pour
  que ça se voie.
* **L'olive `617A00` est gravée en 14** sur les stages dont un lot la porte.
  Mesuré sur `cast.const.asm` + les scènes de lot : patapata, scant, cancer et
  bug portent l'olive ; bink, pstaff, scantfire non ; **mid n'a aucune image**
  (squelette). D'où : 14 **gelé sur 1, 3, 4, 5, 7** — exactement la liste déjà
  actée — et **libre sur 2, 6, 8**.
* **Le vert clair `9ECC00` en 15 est une réservation du stage 1** (sprites à
  venir). Les autres stages disposent librement de leur case 15.
* Les sprites communs peignent 12-15 en magenta dans leurs PNG ; la vraie
  couleur vient de `Pal_stage`. Chaque stage peut donc mettre **ce qu'il veut**
  dans ses cases propres, y compris son `CCCCB8` à lui.

## 3. L'affectation par stage — et où ça coince

Cases propres disponibles : 12, 13, 15, plus 14 quand l'olive n'y est pas
gelée. L'olive de la carte va en 14 partout où elle apparaît (gelée ou pas :
c'est sa case dans la nouvelle palette).

| stage | à caser | cases libres | verdict |
|---|---|---|---|
| 2 | beige foncé, `CCCCB8`, olive, `B8A068` | 12 13 14 15 | **tient juste** (4/4) |
| 3 | `CCCCB8`, `889060`, `A8B890`, `304020` (+olive→14) | 12 13 15 | **déficit 1** |
| 4 | beige foncé, `CCCCB8`, `71C062`, `207040` (14 gelée par les lots) | 12 13 15 | **déficit 1** |
| 5 | beige foncé, `F8C071`, `D09030` (+olive→14) | 12 13 15 | tient (3/3) |
| 6 | `CCCCB8`, `006060`, `003030`, `90A888` | 12 13 14 15 | tient (4/4) |
| 7 | `CCCCB8`, `68C8A0`, `A84200` (+olive→14) | 12 13 15 | tient (3/3) |
| 8 | beige foncé, `CCCCB8`, olive, `B8A068` | 12 13 14 15 | **tient juste** (4/4) |

**Deux déficits, et un précédent qui les résout.** Dans les deux cas la sortie
la moins chère (px × distance RVB) est `CCCCB8 → A8A8A8`, le gris clair
commun : 3,2 M sur le stage 3 et 4,3 M sur le stage 4, contre 11,5 M pour
fusionner les deux verts du 3 et 14,7 M pour fusionner les beiges du 4. C'est
**la recette A** que l'auteur a déjà validée cinq fois sur les communs (« le
beige clair prend le gris clair ») — appliquée cette fois à la carte. À valider
sur planche malgré le précédent : règle 0 bis, une recette vaut pour SA
ressource.

À noter : les stages 2 et 8 tiennent **sans marge**. Toute retouche d'art qui
ajouterait une teinte y forcerait un arbitrage.

## 4. Refaire depuis l'arcade, ou remapper les `in.png` ?

Deux chemins mènent aux nouveaux `in.png` ; ils ne donnent pas la même chose.

**A. Remap des `in.png` actuels** (exécutable dans le dépôt, rejouable par le
ledger comme `stage1.map`). Chaque classe de pixels garde son sens, on ne fait
que renuméroter — sauf les fusions de déficit et l'orange. **Limite mesurable**
: les pixels que l'ancienne quantification a versés dans un commun ont perdu
leur RVB arcade. L'ancienne palette n'avait **pas de gris moyen-clair** : tout
ce qui ressemblait à `A8A8A8` est parti vers le beige, le gris foncé ou le
blanc, et un remap ne peut pas le récupérer.

**B. Reconversion depuis l'arcade** (la recette validée de
`leanscroll-06.txt` : réduction 3/8 × 3/4 au plus proche voisin, affectation
des cases libres par coût décroissant — rejouée sur le stage 5, elle retrouve
99,24 % des pixels du dépôt). En re-quantifiant contre les **nouveaux**
communs, les pixels proches de `A8A8A8` et de `F99B68` retrouvent leur vraie
maison. C'est le seul chemin qui exploite réellement la nouvelle palette, et
c'est celui que l'auteur propose. Il demande le dépôt
`re.arcade.r-type` (absent de cet environnement — l'auteur l'a).

**Recommandation : B**, avec A en repli pour un stage dont le plan arcade
manquerait. Dans les deux cas la sortie est un `in.png` commité + la commande
dans `tools/` (le pattern `leanscroll-06.txt` déjà en place).

## 5. Ce qu'il faut construire

1. **`arcade_to_in.py --pal-next`** : base = les 12 communs de `pal-next.png` ;
   cases attribuables = 13, 14, 16 PNG (12, 13, 15 matériel) + 15 PNG (14) si
   le stage n'est pas gelé olive ; l'olive `617A00` **épinglée en 14** dès que
   la source en approche ; l'affectation par coût inchangée. Le gel olive par
   stage se lit dans `cast.const.asm`, pas dans une liste écrite à la main.
2. **Les fichiers de palette dédiés** `src/stages/NN/palette/pal.png` : les 12
   communs + les 4 cases du stage. Générés depuis le `in.png` converti (une
   seule source de vérité), avec un garde-fou qui vérifie l'accord
   `pal.png` ↔ `in.png` au build. Le config bascule ses huit `png2pal
   Pal_stage` dessus — fini la palette dérivée du tileset généré.
3. **Planches** pour les deux déficits (3 et 4) et pour le stage 8 (l'orange →
   saumon y pèse 4115 px) ; les autres stages sont des renumérotations pures
   prouvables au pixel, comme le stage 1.
4. **Rejeu** : chaque conversion s'inscrit au ledger (commande + paramètres).
   La partie arcade s'exécute chez l'auteur ; le dépôt garde la commande et son
   résultat, comme aujourd'hui.

## 6. Ordre proposé

Stage 2 d'abord (déjà acté : le pire cas en nombre d'index dans les tuiles),
puis 8 (la planche orange), puis 3 et 4 (les planches de déficit), puis 5, 6,
7. Chaque stage : conversion → palette dédiée → build → lane → planche si
décision.

## 7. Deux constats de l'auteur sur planche, et ce qu'ils ont révélé (17/08/2026)

La première passe (§5-6) a été livrée en planche. L'auteur a relevé deux
défauts. Les deux viennent du **même endroit** : le critère d'attribution.

### 7.1 « Le boss du stage 8 devient gris »

Mesuré. Le boss est en fin de niveau (x 1792..1983 du plan arrière, où la
teinte verte passe de ~700 px par bande de 64 à 6 603). Ses deux verts
dominants, `(136,136,80)` 1 981 px et `(96,96,56)` 1 886 px, tombaient tous
deux sur le **gris commun** `#616161`, à distance RGB 58 et 41. Les quatre
cases propres du stage étaient parties aux oranges de la zone de feu.

Cause : le coût se mesurait en **distance RGB euclidienne**, qui met sur le
même pied « un orange un peu faux » (l'orange garde sa teinte, il change de
ton) et « un vert qui devient gris » (la teinte est détruite). En chiffres :
l'orange `(248,80,0)` était à 75 de son plus proche commun, le vert
`(136,136,80)` à 58 — l'orange gagnait, alors que sa perte perceptive est bien
moindre.

Correctif : la métrique par défaut devient **CIE Lab, ΔE76**, qui sépare la
clarté de la chroma. Elle ne corrige pas que le stage 8 — écart moyen pondéré
sur les sept stages, plus bas = mieux :

| stage | 02 | 03 | 04 | 05 | 06 | 07 | 08 |
|---|---|---|---|---|---|---|---|
| RGB | 11,2 | 6,8 | 6,7 | 4,8 | 7,4 | 3,6 | 11,4 |
| Lab | **9,7** | **6,3** | **5,0** | **4,1** | **6,1** | **3,3** | **9,1** |

Effet sur le stage 8 : deux cases vertes (`136,136,80` et `64,64,16`), toute la
rampe verte reste verte. Ce que ça coûte, et c'est assumé : la rampe orange
perd un niveau, `(192,64,0)` glisse vers le rouge `#AC0000` (ΔE 15,9).

**Effet de bord mesuré, et le garde-fou qu'il a imposé.** En Lab, une teinte
isolée dans l'espace des couleurs voit son erreur amplifiée — au point qu'une
poussière peut rafler une case. Le magenta du stage 6 (89 px réduits, 0,04 %)
prenait la quatrième case devant un niveau de dégradé teal à 1 331 px. D'où
`--plancher`, part minimale pour prétendre à une case, à 0,1 % par défaut : le
premier prétendant légitime du corpus est 15 fois au-dessus.

### 7.2 « Le stage 3 doit prendre en compte en priorité le battleship de
l'autre plan »

Le plan arrière `level3_b.png` porte un **battleship** (boîte non noire
x 576..1167, y 16..191) que du code à part affichera hors tilemap. Il n'était
dans aucun calcul : la conversion ne regardait que `level3_f.png`. Résultat
mesuré — son vert de coque `(136,144,96)` sortait en tan `(184,152,96)`, son
vert sombre `(48,64,32)` en gris, et sa rampe jaune s'étalait sur le jaune
commun et l'olive. Un vaisseau vert-et-jaune rendu beige.

Deux mécanismes, parce qu'un seul ne suffit pas — les deux mesurés :

* **`--plan`** : un plan supplémentaire, avec boîte et poids, qui compte dans
  le **choix des couleurs** mais n'est jamais écrit dans l'`in.png`. Les deux
  ne servent pas le même but : la palette est celle du stage, l'`in.png` est
  celui de la tilemap. À poids 3 les deux verts du vaisseau prennent leurs
  cases, et le choix est stable de 2 à 5.
* **`--epingle`** : une case réservée avant le calcul. C'est le **seul** moyen
  d'exprimer une priorité que le nombre de pixels ne porte pas. La rampe jaune
  du vaisseau pèse ~1 200 px réduits contre 17 000 px de terrain : balayé de
  poids 1 à 5, aucun réglage ne la fait gagner. La demande de l'auteur (« vert
  et jaune avant tout ») n'est pas exprimable en poids, elle s'écrit.

Affectation obtenue : 13 = jaune `(208,192,0)`, 14 = vert moyen `(136,144,96)`,
15 = olive (gelée par les lots), 16 = vert sombre `(48,64,32)`.

**Ce que ça coûte, mesuré et assumé.** Les trois teintes du terrain — 71 % des
pixels opaques du plan avant — perdent leurs cases : beige clair → blanc
(ΔE 17), tan → vert moyen (19,3), brun → gris (18,9). C'est le prix direct de
la priorité demandée ; l'alternative chiffrée (garder le beige clair, laisser
les jaunes du vaisseau au jaune commun) coûtait 12 088 dE·px au vaisseau pour
en économiser 129 574 au terrain. Le ratio est de 10 contre 1 **en faveur du
terrain** — c'est bien un arbitrage d'auteur, pas un optimum, et il est écrit
comme tel dans le ledger.

## Annexe — pourquoi pas « olive partout en 14 dès qu'un lot l'exige » en dur

La liste 1-3-4-5-7 est vraie aujourd'hui parce que les scènes de cast la
rendent vraie. Le jour où une wave de stage 6 convoque un patapata, la liste
écrite à la main mentirait en silence. D'où la règle du §5 : l'outil lit le
cast, il ne connaît pas de liste.
