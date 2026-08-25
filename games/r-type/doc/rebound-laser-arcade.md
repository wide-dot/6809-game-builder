# Le laser rebond de la borne — relevé Ghidra

*Second volet, 25/08/2026. Le premier est [l'état des lieux v2](rebound-laser-v2.md).
Source : base `maincpu`, sous-système `rebound_laser` (18 membres) via asm-ark.*

---

## 1. Vingt-quatre slots DÉDIÉS, jamais alloués

C'est le fait qui explique tout le reste. Chaque segment possède un slot
d'objet **permanent**, qui alterne entre deux gestionnaires de tick :

- au repos, le slot exécute son **entrée d'armement** (`instantiate_..._segment_N`),
  qui ne fait que tester le drapeau de chaîne et rendre la main ;
- armé, il exécute `create_...` puis `wait_pre_delay_...` puis le tick de vol.

Chaque entrée mémorise son propre gestionnaire de repos (`saved_idle` : 0x3BD6,
0x3BFE, 0x3C26… pour l'horizontal ; 0x3980, 0x39A6… pour la diagonale
haut-droite) afin d'y revenir au déchargement. Aucun `xref` n'appelle ces
routines : elles sont **posées dans le champ +0x00 des slots**, pas invoquées.

Trois lasers × huit segments = **24 slots réservés à vie** à cette seule arme.
La borne peut donc se payer huit segments : ils ne coûtent rien à personne
d'autre. C'est exactement le budget que notre portage a refusé — *« 8 sprites x
3 lasers = 24 sprites, too much left for enemies »*.

Le segment 1 vérifie la disponibilité de la chaîne en sondant **les sept
octets de vie suivants** (BP+0x27, pas de 0x20) : les huit slots d'une chaîne
sont **consécutifs**. S'ils sont tous libres il pose le drapeau `0x99` ; sinon
il tombe dans l'épilogue « not ready ». Les segments 2..8 ne s'arment que si ce
drapeau est posé.

## 2. Chaque segment vole SEUL

Il n'y a pas d'anneau d'historique. Chaque segment naît **au même point** — le
snap sur grille 8×8 de la position du pod, `(pos & ~7) + 4` — et attend son
`pre_delay` avant de partir :

| segment | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| pre_delay (trames) | 1 | 3 | 5 | 7 | 9 | 11 | 13 | 15 |

Deux trames d'écart : la chaîne se déploie d'un segment toutes les deux trames.
Pendant l'attente, le segment **suit le scroll** (`pos_x += scroll_amount`) et
sa boîte est parquée aux sentinelles — il ne peut rien toucher.

Comme la physique est déterministe et l'origine commune, un segment parti 2k
trames plus tard trace **exactement** la trajectoire de la tête, 2k trames
derrière. C'est ce que notre anneau rejoue : le résultat visible est le même,
pour bien moins cher. **L'anneau est une bonne idée, pas un écart de
comportement** — tant que la tête vit.

Au bout de son attente, le segment prend un slot de palette (id 0x3D), amorce
sa vie à **112 trames**, vérifie qu'il n'est pas né dans un mur, et passe au
tick de vol.

## 3. Les boîtes de collision — le vrai écart

C'est ici que notre portage a coupé. La borne n'arme pas une boîte par chaîne
mais **plusieurs par chaîne**, et elles ne sont pas au même endroit selon la
famille :

| famille | segments porteurs | potentiel |
|---|---|---|
| horizontal | **1** et **5** | 2 puis 1 |
| diagonal (les deux) | **1**, **4** et **7** | 2 puis 1 et 1 |

Les autres portent `damage_disabled = 1` et `damage_potential = 0` : ils ne
sont que du remplissage visuel. La plate note que les segments porteurs de
milieu de chaîne (4 et 7) « ressemblent visuellement à une cellule plus
brillante » — ils ont donc aussi une identité graphique.

Un segment porteur rafraîchit sa boîte **à chaque trame** depuis
`rebound_laser_aabb_extents` (ES:0x210C) ; quand son potentiel tombe à zéro il
bascule sur son explosion (4 trames).

## 4. L'intégrité de chaîne

Un segment **désarmé** teste, chaque trame, si le segment **précédent** (slot
BP−0x20) exécute encore le tick de vol. Sinon il se supprime. C'est ce qui fait
raccourcir la chaîne par l'avant quand un porteur meurt : les passagers
derrière lui tombent en cascade, jusqu'au porteur suivant qui, lui, survit et
continue avec sa propre boîte.

**Notre `InitExplosion` fait autre chose** : il promeut le troisième segment en
nouvelle tête, lui donne une boîte et recule son index d'anneau de huit octets.
C'est une invention v1 qui *approxime* le comportement arcade avec une seule
boîte au départ. Si on restaure les porteurs de milieu de chaîne, cette
promotion n'a plus de raison d'être — le segment 5 (ou 4 et 7) EST déjà la
nouvelle tête.

## 5. Le vol, et le rebond

Par trame : suivre le scroll, appliquer la vitesse de la direction
(`diagonal_rebound_laser_velocity_table` ES:0x2086, **±8 px sur les deux axes**),
et si la case est solide, tenter le rebond en **cascade de trois** :

1. essai à 90° **horaire** (dX1, dY1) → si libre : `dir += 2 mod 8`, image `image_cw` ;
2. sinon essai à 90° **anti-horaire** (dX2, dY2) → si libre : `dir += 6 mod 8`, image `image_ccw` ;
3. sinon **demi-tour** : les deux offsets appliqués, `dir += 4 mod 8`.

Chaque direction possède un enregistrement de 12 octets
`{dX1, dY1, image_cw, dX2, dY2, image_ccw}` dans
`diagonal_rebound_laser_bounce_table` (ES:0x2056).

**Notre `ReboundPresets` est cette table**, et la cascade de `RunDiagonalLaser`
est ce mécanisme, au 1:1. Les vitesses aussi : ±8 arcade donnent bien nos
(3, ±6) à l'échelle. Rien à reprendre ici.

Hors du bord droit du playfield (`pos_x > 0x2C0`) la sonde terrain est sautée :
pas de rebond hors champ.

## 6. Fin de vie

Trois causes : `is_visible_range` (hors écran), le compteur de 112 trames
épuisé, ou le potentiel consommé (→ explosion de 4 trames). Le compteur est
amorcé **à l'entrée en vol**, donc la chaîne entière dure 112 + 2×8 = 128
trames. Notre `112 + (childId+1)·2` amorcé à la naissance dit la même chose.

## 7. Son et palette

- **SFX 0x3B au tir**, joué par le **segment 2** seulement (horizontal comme
  diagonal) ;
- **SFX 0x3B au rebond**, joué par le segment 2 de chaque paire diagonale ;
- slot de palette 0x3D pris par chaque segment à l'entrée en vol.

Rien de tout cela n'est portable aujourd'hui (moteur audio non migré, pas de
palette par objet).

---

## 8. Tableau des écarts

| # | la borne | chez nous | nature |
|---|---|---|---|
| 1 | 8 segments par laser | **4** (palier fort) / **2** (faible) | **coupe assumée** — place dans le pool |
| 2 | boîtes sur 1 et 5 (horiz.), 1, 4 et 7 (diag.) | **une seule**, la tête | **coupe assumée** |
| 3 | 24 slots dédiés, jamais alloués | allocation dans le pool commun de 60 | contrainte moteur |
| 4 | chaque segment vole seul, décalé par `pre_delay` | les enfants rejouent l'anneau de la tête | **équivalent** tant que la tête vit ; moins cher |
| 5 | passager mort si son prédécesseur n'est plus en vol | idem, plus une promotion du 3ᵉ segment en tête | **invention v1** qui approxime les boîtes de milieu de chaîne |
| 6 | rebond CW → CCW → 180° | idem, table identique | fidèle |
| 7 | vitesses ±8 | 3 / ±6 | fidèle (échelle) |
| 8 | vie 112 trames par segment | 112 + (id+1)·2 | fidèle |
| 9 | snap sur grille 8×8, centre de tuile | `DIV3u`/`DIV6u` + 1 | fidèle |
| 10 | refus de naître dans un mur | idem | fidèle |
| 11 | palette par objet (0x3D) | absente | moteur |
| 12 | SFX 0x3B tir + rebond (segment 2) | absent | moteur |
| 13 | pas de fenêtre de collision réduite | `isInCollisionRange` | **ajout v2**, justifié dans le code |
| 14 | — | anneau limité à 16 entrées | **limite dure v2**, bloque les 8 segments |

## 9. Ce qui reste à établir

- **la longueur par palier de puissance côté borne.** Nos huit entrées
  d'armement sont fixes ; la variation « 2 ou 8 » de notre code vient du
  dispatch `[tier][type]` du pod. Il faut relever ce que la borne arme au
  palier faible : moins de segments, ou une autre arme.
- le potentiel exact du segment 1 diagonal (le relevé donne 2 pour
  l'horizontal ; à confirmer pour la diagonale).
- si les segments porteurs de milieu de chaîne ont bien un **imageset propre**
  (« cellule plus brillante ») ou seulement une boîte.
