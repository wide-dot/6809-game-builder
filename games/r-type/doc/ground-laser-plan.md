# Laser de sol — plan d'implémentation

*26/08/2026. Suite du [relevé arcade](ground-laser-arcade.md). Choix validés
avec l'auteur : **manager façon laser rebond**, et **fidélité arcade sur les
boîtes de collision** — une seule, sur la tête.*

---

## 1. La forme retenue

| | |
|---|---|
| par faisceau | **1 tête en OST** (elle marche, elle porte la boîte) + **5 records** |
| deux faisceaux | 2 OST + 10 records |
| rendu | **1 renderer groupé**, routine du même objet, comme `reboundmgr` |
| coût en slots | **3 OST** pour 12 cellules visibles |

La tête calcule, les records suivent : c'est le serpent, et c'est exactement
la moitié du travail déjà écrite pour le rebond.

## 2. La marche, réduite à une règle

Le relevé donne trois tables. Deux se compressent, ce qui fait tomber une
soixantaine d'octets de données et rend le code lisible.

**Quatre directions cardinales**, pas d'une cellule de terrain :

| code | 0 | 2 | 4 | 6 |
|---|---|---|---|---|
| | HAUT | GAUCHE | BAS | DROITE |
| pas arcade | (0,−8) | (−8,0) | (0,+8) | (+8,0) |
| **pas v2** | **(0,−6)** | **(−3,0)** | **(0,+6)** | **(+3,0)** |

**Quatre rotations**, et chacune tient en trois nombres :

| rotation | départ | virage au mur | virage de coin |
|---|---|---|---|
| 0 | HAUT | **+6** (horaire) | +2 |
| 2 | BAS | **+2** (anti-horaire) | −2 |
| 4 | HAUT | +2 | −2 |
| 6 | BAS | +6 | +2 |

Le faisceau A prend la rotation 0, le B la rotation 2 ; **le pod amarré à
l'arrière ajoute 4**, ce qui donne 4 et 6 — mêmes départs, virages inversés.
Les deux faisceaux tiennent la paroi de mains opposées, et l'amarrage arrière
échange les mains.

**Le virage de coin est TOUJOURS l'opposé du virage au mur** — c'est ce que la
table à `0x212C` dit une fois décodée, avec une seule exception : la ligne de
la direction de DÉPART de la rotation est l'identité (pas de virage). Tant que
le faisceau monte vers le plafond ou descend vers le sol, il ne suit pas de
coin ; une fois sur la surface, il l'épouse. Une table de 96 octets devient
deux constantes par rotation et un test.

Par tick de la tête, dans l'ordre :

1. suivre la caméra ;
2. avancer d'un pas dans la direction courante ;
3. sonder le décor au nouveau centre, **les deux plans** ;
4. **si solide** : défaire le pas, `direction += virage_mur` (mod 8) ;
5. **toujours** : sonder un pas dans `direction + virage_coin` ; **si libre**,
   adopter cette direction ;
6. écrire (x, y) dans l'anneau du faisceau.

## 3. Ce qu'on réutilise tel quel

| | |
|---|---|
| `reboundmgr` | le renderer groupé, les records, `RecPublish` et sa traversée d'imageset à deux niveaux |
| `terrainCollision.do` | la sonde ponctuelle : poser `sensor.x/y`, appeler, lire B |
| `obj_reboundlaser` | le patron de la tête : allocation, anneau, compensation de frame-drop |
| l'anneau du rebond | même idiome, écrit **par tick** et non par trame — c'est ce qui met l'échelonnement en ticks |

Le pas de 8 px de la borne **tombe exactement sur notre cellule de terrain
3×6** : la marche est « une cellule par pas », sans reste. Notre
`terrainCollision` teste déjà les deux plans, ce que fait la sonde arcade.

## 4. Les données v2

| | valeur | d'où |
|---|---|---|
| longueur de chaîne | **3** au palier 2, **6** au palier 3 | table de routage |
| potentiel de la tête | **2** au palier 2, **4** au palier 3 | `+0x17`, seule différence entre les deux routines d'armement |
| recul par cellule | **2 ticks** | file de deux de la borne |
| profondeur d'anneau | **12 entrées** minimum → **16**, deux anneaux | 6 cellules × 2 |
| entrée d'anneau | **x, y** (4 octets) | l'image se choisit à l'affichage |
| durée de vie | **112 trames** | `0x70` |
| boîte de la tête | rayons **(5, 9)** | extents 12×12, mêmes que le rebound |
| explosion | **4 images** | recette `0x21BC` |
| refus de naître | sonde au centre à la naissance | `create_ground_laser` |

## 5. Les étapes

### Étape 1 — l'unité et la tête qui marche — FAITE le 26/08/2026
Objet, dispatch, allocation des deux têtes depuis `ForcePodAttachedFire` sur
`globals.forcepodtype == 1`. La marche complète (§2), l'anneau écrit par tick,
le dessin par `DisplaySprite` — **sans records**, une seule cellule par
faisceau. C'est là que se juge la trajectoire, et elle se juge à l'œil : le
faisceau doit longer le relief sans décoller ni s'y enfoncer.

Validée sous toje (stage 2) : la tête A longe le plafond, la B le sol, les
deux progressent à droite en épousant les crêtes. Deux exigences arcade que le
premier jet avait manquées, retrouvées au désassemblage :

- **hors carte = solide.** La sonde de la borne rend un id sous la sentinelle
  hors du tilemap ; notre `loadMap` indexe ses tables sans borne (`yOffset`
  y 11..190, `xOffset` 168 px à droite de la caméra) et lisait du code comme
  si c'était la carte — le faisceau traversait le plafond et s'évadait en y
  négatif. Le mur virtuel dans `gl.probe` corrige, et subsume le
  `is_visible_range` que la borne joue en queue de tick.
- **suivre la caméra** (`pos += scroll`, §2 point 1 — que l'implémentation
  avait sauté sur un contresens) : la borne colle ses cellules à l'écran. En
  coordonnées playfield, c'est un delta caméra par trame, mesuré sur la
  position gardée en OST (ce qui absorbe les trames sautées).

Le décodage §2 est conforme au dump brut des trois tables (`0x2114`, `0x2124`,
`0x212C` relues octet par octet) — la compression « coin = opposé du mur,
identité au départ » est exacte, y compris la sonde à un pas dans la
direction candidate.

### Étape 2 — les records et le renderer — FAITE le 26/08/2026
Les cinq suiveurs par faisceau deviennent des records lus à `−2k` ticks dans
l'anneau, publiés par le renderer groupé. **Test différentiel** : à trois
cellules, l'image doit être identique à la même scène jouée par trois têtes
indépendantes.

Réalisée en calque de `reboundmgr` : `groundmgr.asm` (2 chaînes × 6 slots,
`RecPublish` avec le parcours de parité, faux imageset → `DrawAll`, la tête
publiée par le même chemin que ses suiveurs), anneau de 16 entrées (x, y) par
faisceau écrit **par tick**, suiveur k à `−(2k+3)` entrées (deux ticks par
cellule, la file de deux de la borne), déploiement progressif, calage grille
3×6 à la naissance (idiome DIV3u/DIV6u du rebond), et cycle d'images inversé
sur le faisceau B (le NEG du bit +0x1D arcade). Validée sous toje : trois
volées, chaînes au sol et au plafond épousant le relief, re-tir fonctionnel.
Au lieu du test différentiel : slots relevés en mémoire (espacement exact
d'une cellule, cadre écran +48/+28 conforme) + jugement à l'œil.

Deux leçons de la mise au point :

- **La sélection d'anneau a coûté DEUX bugs, un par forme.** Par D :
  `lda subtype,u` après `ldd #ringA` détruit l'octet HAUT de l'adresse — la
  tête A écrivait ses positions sur le code du HUD (même page), qui les
  exécutait ; gel complet, et un anneau « vierge » au poste d'autopsie
  puisque le vrai tampon n'était jamais touché. Puis, corrigée par X mais
  avec le LDX placé ENTRE le `anda` et le `beq` : LDX pose Z selon la valeur
  chargée (jamais nulle), le `beq` n'était plus jamais pris et les deux
  têtes partageaient `ringB` — les suiveurs profonds du faisceau haut
  publiaient des restes du faisceau bas, d'où « plus d'éléments en bas »
  (observation auteur). La forme sûre : X chargé AVANT le test, les
  drapeaux du `anda` intacts au `beq`.
- La queue de déploiement de `reboundmgr.publishChain` éteint les slots
  depuis le premier suiveur manquant **jusqu'au slot de tête inclus** — la
  tête du rebond est probablement invisible pendant son déploiement.
  `groundmgr` s'arrête avant le slot de tête ; le rebond est à vérifier.

### Étape 3 — la longueur, la boîte, la mort — FAITE le 26/08/2026
Longueur par palier, potentiel 2/4, boîte AABB de la tête, explosion de quatre
images, et la chaîne qui se raccourcit derrière une tête morte.

La longueur par palier était déjà dans l'étape 2. Le reste : AABB (5,9) sur
la tête seule, ajoutée à l'Init après la sonde de naissance, potentiel 2/4
posé selon `globals.forcepodlevel` (le `+0x17` arcade), suivie chaque trame ;
quand le potentiel tombe à zéro la tête devient la routine `Explode` : la
vague remonte la chaîne d'une cellule par trame (la propagation arrière
arcade), chaque cellule joue les quatre images **à rebours** (le compte
`0x18` qui retranche 6 avant d'indexer), six trames chacune, positions
gelées ; à `e = 24 + GL.NSEG` tout s'éteint, `gl.gone` rend la boîte encore
armée et la chaîne. La mort par durée de vie ou sortie d'écran reste SANS
explosion, comme la borne.

Validation sous toje, sans ennemi complice : l'opérande du potentiel patché
en RAM (naissance à potentiel nul → explosion au pod, fin propre, re-tir
fonctionnel), puis vie raccourcie + mort détournée sur `gl.boom` (vague
visible le long des chaînes déployées, sol et plafond). Endurance trois
volées et banc des huit stages inchangés (7/8, stage 4 préexistant).

Deux notes :

- **V2-DEVIATION** : pas de suivi caméra pendant l'explosion — la borne
  laisse ses cellules collées à l'écran (elles dérivent sur le décor ~25
  trames) ; nos suiveurs lisent l'anneau en coordonnées carte, la vague
  reste donc collée au décor, d'un bloc.
- Une explosion (18×36) dont le cadre déborde de l'écran est masquée
  entière par le cull de `RecPublish` — la règle du moteur pour tout
  sprite ; près du plafond ou du sol, certaines cellules de la vague
  disparaissent donc sans jouer leurs images.

Deux pièges d'outillage relevés pour la suite (mémoire toje) : un breakpoint
posé sur `$0000` accroche le dispatch de TOUS les objets dont l'unité est à
l'offset zéro de sa page — le poser, chasser, puis oublier de le retirer fige
tous les `run_frames` suivants et mime un crash du jeu ; et les offsets d'une
unité changent à chaque repack du layout (`gen/layout.asm` fait foi, jamais
une valeur notée la veille).

### Étape 4 — validation
Banc toje : deux faisceaux qui traversent un relief connu (le stage 1 a du
plafond et du sol), relevé de cadence contre la référence, slots libres en
vague dense.

## 6. Les deux décisions à prendre avant l'étape 1

### 6.1 Un identifiant d'objet — RÉGLÉ le 26/08/2026

L'espace d'identifiants est redécoupé sur des bornes rondes (décision auteur) :

```
   0..31    le préfixe COMMUN
  32..127   le spécifique de chaque ensemble co-chargeable
```

La base valait 30 et le commun était plein à l'octet près. Les **29 identifiants
spécifiques** des huit stages et du title ont glissé de deux, et les **cinq
tables d'index** de chacun ont reçu deux entrées de réserve. Restent **30 et
31 libres** : l'un pour la tête du laser de sol, l'autre pour la suite.

Deux effets de bord, tous deux réglés :

- **14 octets de plus par unité**, et le title débordait d'un octet. Le banc,
  la région `cast` et `common.mscroll` ont glissé de 16 dans la marge que
  `mscroll` avait au-dessus de lui : le plafond des unités passe de `$87E1`
  à `$87F1`.
- **Le garde-fou de densité n'existait que sur le stage 2.** Il est posé sur
  les neuf fichiers d'index — et il a mordu tout de suite, sur le repère de fin
  de `Ani_Asd_Index` du title. C'est exactement ce pour quoi il existe.

Le renderer, lui, ne coûte toujours rien : comme `reboundmgr`, ce sera une
**routine** de l'objet laser de sol, pas un objet à part.

### 6.2 L'art — RÉGLÉ le 26/08/2026

Il n'existait pas et ne sortait pas de l'amont : `out/sprites/` de
`re.arcade.r-type` ne contenait que des ennemis, aucun sprite d'arme du joueur.
Décision auteur : **étendre l'amont**, pas authorer.

Et il n'y avait **rien à coder** — le moteur `meta_sprite` du catalogue décode
déjà les rangées de six octets `(dx, dy, tuile, attributs)` que la borne passe
à `write_1_sprite_a`, et sa règle d'image `addr + 6·nb·f` est exactement le pas
de nos trois tables. Il manquait l'entrée de catalogue, ajoutée à
`data/catalog.yaml`.

Douze images sorties, converties en sprites TO8 par `arcade_to_sprites.py` :

| jeu | images | cadre arcade | TO8 | ancre |
|---|---|---|---|---|
| tête | 4 | 16×16 | **6×12** | −3, −6 |
| suiveur | 4 | 16×16 | **6×12** | −3, −6 |
| explosion | 4 | 48×48 | 18×36 | −9, −18 |

La cellule de 16 px de la borne donne 6×12 chez nous, et son pas de marche de
8 px donne (3, 6) : **une cellule de notre carte de collision**. Les cellules
d'une chaîne se touchent des deux côtés, comme sur la borne — c'est la même
coïncidence d'échelle vue deux fois.

Un piège relevé au passage : **la borne joue l'explosion à l'envers**. Son
compte à rebours part de `0x18` et retranche 6 avant d'indexer, donc elle lit
les rangées 3, 2, 1, 0. L'export les sort dans l'ordre du fichier.

Procédure et invocations : `tools/groundlaser-art.txt`.

## 7. Ce qu'on ne fait pas

- **Pas de boîte sur les suiveurs** — décision auteur, fidélité arcade. La
  borne n'en donne qu'à la tête, on fait pareil, même si l'outil pour faire
  autrement existe depuis le laser rebond.
- Slot de palette `0x3D` et SFX `0x3C` : hors de portée du moteur, comme pour
  les autres armes.
- Le type de laser **4**, qui route vers les mêmes routines que le 2 : à
  élucider au ramassage, pas ici.
